import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../contacts/models/contact_model.dart';
import '../../contacts/models/sync_status.dart';
import '../../contacts/services/contact_service.dart';
import '../models/contact_source.dart';
import '../services/contact_source_service.dart';
import '../services/sync_adapter.dart';
import '../../../core/exceptions/app_exception.dart';

/// Orchestrates the background synchronization lifecycle.
///
/// ## Architecture
///
/// [SyncProvider] is the sync *engine*. It knows nothing about Google Sheets
/// or any other integration — it speaks only to [SyncAdapter] implementations
/// through the [SyncAdapter.pushUpdate] interface. Adding a new integration
/// (HubSpot, Salesforce, Supabase, etc.) requires only a new [SyncAdapter]
/// class; [SyncProvider] is never touched.
///
/// ## Sync triggers
///
/// 1. **Immediate** (via [enqueue]) — called by [ContactProvider.updateContact]
///    right after every local save. The contact is added to the pending set
///    and the queue is flushed immediately (fire-and-forget).
/// 2. **App startup** — [start] re-queues any contacts that were
///    [SyncStatus.pendingSync] or stuck in [SyncStatus.syncing] when
///    the previous session ended.
/// 3. **Periodic safety net** — every 5 minutes, the periodic timer flushes
///    the queue for items that may have been missed (e.g., network restored).
///
/// ## Retry & backoff
///
/// ```
/// Attempt 1 → wait 30 s
/// Attempt 2 → wait 2 min
/// Attempt 3 → wait 10 min
/// Attempt 4 → wait 1 h
/// Attempt 5+ → SyncStatus.failed (manual retry required)
/// ```
///
/// [ContactModel.syncRetryCount] is persisted in Hive, so the backoff state
/// survives app restarts. Re-editing a contact resets the count to 0.
///
/// ## Conflict strategy: local wins
///
/// When a contact is synced, its current local values are written to the
/// external source unconditionally. If the spreadsheet was edited at the same
/// time, the local value wins. This is the correct strategy for the cold-call
/// workflow: the phone (local) has the most current information about the call.
///
/// ## Deduplication
///
/// The pending queue is a [Set]. Enqueueing the same contact ID multiple times
/// while it is already pending or syncing causes no duplicate API calls.
///
/// ## Cross-provider communication
///
/// [SyncProvider] does not import [ContactProvider]. Instead, it receives a
/// [VoidCallback] ([onSyncStatusChanged]) that [ContactProvider.reload] is
/// bound to in [main.dart]. This avoids circular dependencies and keeps the
/// two providers loosely coupled.
class SyncProvider extends ChangeNotifier {
  SyncProvider({
    required List<SyncAdapter> adapters,
    required ContactService contactService,
    required ContactSourceService contactSourceService,
    this.onSyncStatusChanged,
  })  : _adapters = adapters,
        _contactService = contactService,
        _contactSourceService = contactSourceService;

  final List<SyncAdapter> _adapters;
  final ContactService _contactService;
  final ContactSourceService _contactSourceService;

  /// Called whenever a contact's [SyncStatus] changes in Hive.
  ///
  /// In [main.dart] this is bound to `() => contactProvider.reload()` so
  /// the UI immediately reflects the new sync badge.
  final VoidCallback? onSyncStatusChanged;

  // ── Queue ──────────────────────────────────────────────────────────────────

  /// IDs of contacts waiting to be synced.
  /// Using [Set] provides O(1) deduplication — adding the same ID twice is free.
  final Set<String> _queue = {};

  /// Prevents concurrent [_processQueue] runs.
  bool _isProcessing = false;

  Timer? _periodicTimer;

  // ── UI-facing state ────────────────────────────────────────────────────────

  bool _isSyncing = false;

  /// True while at least one sync operation is in progress.
  bool get isSyncing => _isSyncing;

  int _pendingCount = 0;

  /// Number of contacts currently waiting for sync or actively syncing.
  int get pendingCount => _pendingCount;

  String? _lastErrorMessage;

  /// The most recent sync failure message, for display in error UI.
  String? get lastErrorMessage => _lastErrorMessage;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Starts the sync engine.
  ///
  /// Should be called once, immediately after the provider is created
  /// (typically in [initState] of the root [StatefulWidget]).
  ///
  /// Steps:
  /// 1. Resets contacts stuck in [SyncStatus.syncing] (from a crash).
  /// 2. Re-queues all [SyncStatus.pendingSync] contacts from the previous session.
  /// 3. Starts the 5-minute periodic safety-net timer.
  Future<void> start() async {
    await _resetStuckContacts();
    _loadPendingFromStorage();
    _periodicTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _flushQueue(),
    );
  }

  /// Stops the periodic timer. Call from [State.dispose] of the root widget.
  void stop() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Enqueues [contactId] for immediate synchronization.
  ///
  /// Adds the ID to the pending [Set] (deduplicating automatically) and
  /// then starts processing the queue right away — fire-and-forget.
  ///
  /// Called by [ContactProvider] after every successful [ContactService.update].
  void enqueue(String contactId) {
    _queue.add(contactId);
    _updatePendingCount();
    _flushQueue();
  }

  /// Resets all [SyncStatus.failed] contacts to [SyncStatus.pendingSync] and
  /// re-queues them for immediate synchronization.
  ///
  /// Called when the user taps a "Retry sync" button in the UI.
  Future<void> retryFailed() async {
    final failedContacts = _contactService
        .getAll()
        .where((c) => c.syncStatus == SyncStatus.failed)
        .toList();

    for (final contact in failedContacts) {
      // Reset the retry count so the backoff schedule starts fresh.
      await _contactService.update(
        contact.copyWith(
          syncStatus: SyncStatus.pendingSync,
          syncRetryCount: 0,
        ),
      );
      _queue.add(contact.id);
    }

    _updatePendingCount();
    onSyncStatusChanged?.call();
    _flushQueue();
  }

  // ── Queue processing ───────────────────────────────────────────────────────

  /// Triggers queue processing if not already running.
  void _flushQueue() {
    if (_isProcessing || _queue.isEmpty) return;
    // unawaited — processing runs in the background; the caller returns
    // immediately, keeping the UI thread unblocked.
    unawaited(_processQueue());
  }

  Future<void> _processQueue() async {
    _isProcessing = true;

    while (_queue.isNotEmpty) {
      // Take one item at a time so new enqueues during processing are
      // picked up in the same run (no item is left behind).
      final id = _queue.first;
      _queue.remove(id);
      await _syncContact(id);
    }

    _isProcessing = false;
    _updatePendingCount();
    notifyListeners();
  }

  // ── Per-contact sync logic ─────────────────────────────────────────────────

  Future<void> _syncContact(String contactId) async {
    // Always read from Hive — never use a stale in-memory reference.
    // This ensures we sync the very latest version of the contact, even if
    // the user edited it again while the queue was being processed.
    final contact = _contactService.getById(contactId);
    if (contact == null) return; // Deleted between enqueue and now.

    // Contacts without a source have nothing to sync.
    if (contact.importedFromTableId == null) return;

    // Resolve the source configuration.
    final source = _contactSourceService.findById(contact.importedFromTableId!);
    if (source == null) {
      // The source was deleted. Mark as noSource so we stop trying.
      await _writeSyncStatus(
        contact,
        SyncStatus.noSource,
        syncRetryCount: 0,
      );
      return;
    }

    // Find the adapter for this source type.
    final adapter = _adapterFor(source);
    if (adapter == null) {
      // No adapter registered for this source type — skip silently.
      // This can happen if a source type was removed from the app binary.
      return;
    }

    // Check adapter availability (signed in, network reachable, etc.).
    if (!await adapter.isAvailable()) {
      // Leave as pendingSync — the periodic timer will retry later.
      return;
    }

    // Mark as actively syncing.
    await _writeSyncStatus(contact, SyncStatus.syncing);
    _isSyncing = true;
    notifyListeners();
    onSyncStatusChanged?.call();

    try {
      await adapter.pushUpdate(contact: contact, source: source);

      // Success: clear failure state.
      await _writeSyncStatus(
        contact,
        SyncStatus.synced,
        syncRetryCount: 0,
      );
      _lastErrorMessage = null;
    } catch (e) {
      await _handleFailure(contact, e);
    } finally {
      // Recompute _isSyncing: still true if more items are queued.
      _isSyncing = _queue.isNotEmpty;
      notifyListeners();
      onSyncStatusChanged?.call();
    }
  }

  Future<void> _handleFailure(ContactModel contact, Object error) async {
    final newRetryCount = contact.syncRetryCount + 1;
    _lastErrorMessage = _describe(error);

    if (newRetryCount > maxRetries) {
      // Retry limit reached — stop automatically. User must retry manually.
      await _writeSyncStatus(
        contact,
        SyncStatus.failed,
        syncRetryCount: newRetryCount,
      );
      notifyListeners();
      return;
    }

    // Schedule the next retry after an exponential backoff delay.
    await _writeSyncStatus(
      contact,
      SyncStatus.pendingSync,
      syncRetryCount: newRetryCount,
    );

    final delay = _backoffDelay(newRetryCount);
    Timer(delay, () => enqueue(contact.id));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  SyncAdapter? _adapterFor(ContactSource source) {
    try {
      return _adapters.firstWhere((a) => a.adapterId == source.type);
    } catch (_) {
      return null;
    }
  }

  /// Writes [status] (and optionally [syncRetryCount]) to Hive.
  Future<void> _writeSyncStatus(
    ContactModel contact,
    SyncStatus status, {
    int? syncRetryCount,
  }) async {
    try {
      await _contactService.update(
        contact.copyWith(
          syncStatus: status,
          syncRetryCount: syncRetryCount,
        ),
      );
    } catch (_) {
      // Writing sync status to Hive is best-effort. If it fails (extremely
      // rare), the contact will remain in its previous state. It will be
      // re-processed on the next app startup or periodic run.
    }
  }

  void _updatePendingCount() {
    _pendingCount = _contactService
        .getAll()
        .where((c) =>
            c.syncStatus == SyncStatus.pendingSync ||
            c.syncStatus == SyncStatus.syncing)
        .length;
    notifyListeners();
  }

  /// On startup, contacts stuck in [SyncStatus.syncing] indicate the app
  /// crashed mid-sync in the previous session. Reset them to [pendingSync]
  /// so they are re-queued and processed normally.
  Future<void> _resetStuckContacts() async {
    final stuck = _contactService
        .getAll()
        .where((c) => c.syncStatus == SyncStatus.syncing)
        .toList();
    for (final contact in stuck) {
      await _writeSyncStatus(contact, SyncStatus.pendingSync);
    }
  }

  /// Re-queues all contacts that were [pendingSync] when the app last exited.
  ///
  /// Does NOT re-queue [failed] contacts automatically — those require an
  /// explicit user action via [retryFailed] to avoid surprise API calls after
  /// a repeated failure.
  void _loadPendingFromStorage() {
    final pending = _contactService
        .getAll()
        .where((c) => c.syncStatus == SyncStatus.pendingSync)
        .map((c) => c.id)
        .toList();

    if (pending.isEmpty) return;

    _queue.addAll(pending);
    _updatePendingCount();
    _flushQueue();
  }

  // ── Retry backoff schedule ─────────────────────────────────────────────────

  /// Maximum number of sync attempts before a contact is marked [SyncStatus.failed].
  static const maxRetries = 4;

  static Duration _backoffDelay(int attempt) {
    return switch (attempt) {
      1 => const Duration(seconds: 30),
      2 => const Duration(minutes: 2),
      3 => const Duration(minutes: 10),
      _ => const Duration(hours: 1),
    };
  }

  static String _describe(Object error) {
    if (error is AppException) return error.message;
    final msg = error.toString();
    return msg.length > 200 ? '${msg.substring(0, 200)}…' : msg;
  }
}
