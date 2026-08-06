import 'package:hive/hive.dart';

part 'sync_status.g.dart';

/// Tracks whether a contact's local changes have been pushed to its origin source.
///
/// Serialized by [HiveField] index — never reorder or remove values.
/// Append new values at the end to preserve backward compatibility.
///
/// ## Lifecycle
/// ```
/// (import)        → synced
/// (user edit)     → pendingSync
/// (engine starts) → syncing
/// (API success)   → synced
/// (API failure)   → pendingSync (retrying) / failed (limit reached)
/// ```
///
/// Contacts created manually (no [ContactModel.importedFromTableId]) stay
/// [noSource] permanently and are never touched by [SyncProvider].
@HiveType(typeId: 14)
enum SyncStatus {
  /// This contact has no linked source (created manually or pre-Phase-2 import).
  ///
  /// [SyncProvider] will not process contacts in this state. To enable sync
  /// for a manually-created contact in the future, set [importedFromTableId]
  /// and change this to [pendingSync].
  @HiveField(0)
  noSource,

  /// All local changes have been successfully pushed to the external source.
  @HiveField(1)
  synced,

  /// The contact has been edited locally and the source has not been updated yet.
  ///
  /// [SyncProvider] will pick this up immediately on the next [SyncProvider.enqueue]
  /// call, or on the next periodic safety-net run.
  @HiveField(2)
  pendingSync,

  /// A sync is actively in progress for this contact right now.
  ///
  /// If the app restarts while a contact is in this state (e.g., crash mid-sync),
  /// [SyncProvider.start] resets it to [pendingSync] and re-queues it.
  @HiveField(3)
  syncing,

  /// The last sync attempt failed and the retry limit ([SyncProvider.maxRetries])
  /// has been reached.
  ///
  /// Recovery options:
  /// - Call [SyncProvider.retryFailed] to reset and re-queue all failed contacts.
  /// - Edit the contact again — [ContactProvider.updateContact] resets the retry
  ///   count and marks the contact [pendingSync].
  @HiveField(4)
  failed,
}

/// Human-readable labels for each [SyncStatus] value.
extension SyncStatusLabel on SyncStatus {
  String get displayLabel {
    switch (this) {
      case SyncStatus.noSource:
        return 'No Source';
      case SyncStatus.synced:
        return 'Synced';
      case SyncStatus.pendingSync:
        return 'Pending Sync';
      case SyncStatus.syncing:
        return 'Syncing…';
      case SyncStatus.failed:
        return 'Sync Failed';
    }
  }
}
