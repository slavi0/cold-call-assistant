import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:uuid/uuid.dart';

import '../models/contact_source.dart';
import '../models/contact_source_test_result.dart';
import '../services/contact_source_service.dart';
import '../services/google_sheets_integration.dart';
import '../../contacts/services/contact_service.dart';
import '../../../core/exceptions/app_exception.dart';
import 'sync_provider.dart';

/// Manages the list of configured contact sources and Google Sign-In state.
///
/// Acts as the single source of truth for:
/// - The list of saved [ContactSource] configurations.
/// - Whether the user is signed in to Google (shared state with
///   [ContactImportProvider] via the injected [GoogleSheetsIntegration]).
/// - The result and error message from the last "Test Connection" call.
///
/// ## Sign-in sharing
/// A single [GoogleSheetsIntegration] instance is created in [main.dart] and
/// injected into both this provider and [ContactImportProvider]. Both providers
/// therefore share the same OAuth session — signing in from the settings screen
/// immediately makes the import button functional.
class ContactSourceProvider extends ChangeNotifier {
  ContactSourceProvider({
    ContactSourceService? service,
    GoogleSheetsIntegration? sheetsIntegration,
  })  : _service = service ?? ContactSourceService(),
        _sheets = sheetsIntegration ?? GoogleSheetsIntegration();

  final ContactSourceService _service;
  final GoogleSheetsIntegration _sheets;
  final _uuid = const Uuid();

  // ── Sources ────────────────────────────────────────────────────────────────

  List<ContactSource> _sources = [];

  /// The current list of configured contact sources.
  List<ContactSource> get sources => List.unmodifiable(_sources);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ── Google auth state ──────────────────────────────────────────────────────

  GoogleSignInAccount? _googleAccount;

  /// The currently signed-in Google account, or null.
  GoogleSignInAccount? get googleAccount => _googleAccount;

  bool get isSignedInToGoogle => _googleAccount != null;

  /// Email of the signed-in Google account for display in the UI.
  String? get googleAccountEmail => _googleAccount?.email;

  bool _isSigningIn = false;
  bool get isSigningIn => _isSigningIn;

  // ── Test Connection state ──────────────────────────────────────────────────

  bool _isTesting = false;
  bool get isTesting => _isTesting;

  /// User-facing error description when [testSource] returns
  /// [ContactSourceTestResult.failed]. Null on success.
  String? _testErrorMessage;
  String? get testErrorMessage => _testErrorMessage;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Loads all configured sources and attempts a silent Google Sign-In to
  /// restore the user's previous session without prompting.
  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _sources = _service.loadAll();
    } on AppException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'Failed to load contact sources.';
    }

    // Restore previous session silently — never prompts the user.
    _googleAccount = await _sheets.signInSilently();

    _isLoading = false;
    notifyListeners();
  }

  /// Synchronously loads all configured sources from storage without
  /// attempting a Google Sign-In. For use in unit tests only.
  @visibleForTesting
  void loadSync() {
    try {
      _sources = _service.loadAll();
    } on AppException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'Failed to load contact sources.';
    }
    notifyListeners();
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────

  /// Persists [source] as a new entry and adds it to [sources].
  Future<void> addSource(ContactSource source) async {
    _errorMessage = null;
    try {
      await _service.save(source);
      _sources = [..._sources, source];
      notifyListeners();
    } on AppException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    }
  }

  /// Persists the updated [source] and replaces the matching entry in [sources].
  Future<void> updateSource(ContactSource source) async {
    _errorMessage = null;
    try {
      await _service.save(source);
      _sources = _sources
          .map((s) => s.id == source.id ? source : s)
          .toList();
      notifyListeners();
    } on AppException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    }
  }

  /// Removes the source with [id] from storage and [sources].
  ///
  /// **Deprecated internal path** — this only deletes the source config.
  /// Prefer [deleteSourceWithContacts] which also removes imported contacts
  /// and cancels pending sync operations.
  Future<void> removeSource(String id) async {
    _errorMessage = null;
    try {
      await _service.delete(id);
      _sources = _sources.where((s) => s.id != id).toList();
      notifyListeners();
    } on AppException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    }
  }

  /// Deletes [source], all of its locally imported contacts, and cancels any
  /// pending sync operations — in that order — as a single logical operation.
  ///
  /// **The external source (Google Sheet, CRM, etc.) is never modified.**
  /// Only local Hive data is removed.
  ///
  /// Steps:
  /// 1. [syncProvider.cancelPendingForSource] — purges the in-memory sync
  ///    queue so no enqueued or backoff-scheduled operation can push to the
  ///    external source after deletion.
  /// 2. [contactService.deleteAllForSource] — batch-deletes every contact
  ///    whose [ContactModel.importedFromTableId] matches [source.id].
  /// 3. [_service.delete] — removes the source configuration from Hive.
  /// 4. Refreshes [sources] and notifies listeners.
  ///
  /// On failure [errorMessage] is set and the operation is rolled back as far
  /// as possible (if step 3 fails the contacts are already deleted, but the
  /// source config is preserved so the user can retry).
  Future<void> deleteSourceWithContacts(
    ContactSource source,
    ContactService contactService,
    SyncProvider syncProvider,
  ) async {
    _errorMessage = null;
    try {
      // Step 1: Cancel any queued sync for these contacts first.
      syncProvider.cancelPendingForSource(source.id);

      // Step 2: Delete locally imported contacts.
      await contactService.deleteAllForSource(source.id);

      // Step 3: Delete the source configuration.
      await _service.delete(source.id);

      // Step 4: Refresh in-memory list.
      _sources = _sources.where((s) => s.id != source.id).toList();
      notifyListeners();
    } on AppException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _errorMessage = 'Failed to delete source: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  // ── Utilities ──────────────────────────────────────────────────────────────

  /// Generates a new RFC-4122 UUID for use as a source ID.
  String generateId() => _uuid.v4();

  // ── Authentication ─────────────────────────────────────────────────────────

  /// Triggers the interactive Google Sign-In dialog.
  Future<void> signInToGoogle() async {
    _isSigningIn = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _googleAccount = await _sheets.signIn();
    } on GoogleSheetsException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Sign-in failed. Please try again.';
    }

    _isSigningIn = false;
    notifyListeners();
  }

  /// Signs the user out and clears all cached Google credentials.
  Future<void> signOutFromGoogle() async {
    await _sheets.signOut();
    _googleAccount = null;
    notifyListeners();
  }

  // ── Connection Testing ─────────────────────────────────────────────────────

  /// Tests the connection to [source] and returns the outcome.
  ///
  /// On failure, [testErrorMessage] is set to a user-displayable description.
  /// The switch is exhaustive — adding a new [ContactSource] subtype will
  /// produce a compile error here until its test logic is implemented.
  Future<ContactSourceTestResult> testSource(ContactSource source) async {
    _isTesting = true;
    _testErrorMessage = null;
    notifyListeners();

    ContactSourceTestResult result;
    try {
      await switch (source) {
        GoogleSheetsSource() => _sheets.validateSource(source),
      };
      result = ContactSourceTestResult.success;
    } on GoogleSheetsException catch (e) {
      _testErrorMessage = e.message;
      result = ContactSourceTestResult.failed;
    } catch (e) {
      _testErrorMessage = 'Unexpected error: ${e.toString()}';
      result = ContactSourceTestResult.failed;
    }

    _isTesting = false;
    notifyListeners();
    return result;
  }
}
