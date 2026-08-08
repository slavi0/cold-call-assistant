import 'package:flutter/foundation.dart';
import '../models/contact_model.dart';
import '../models/sync_status.dart';
import '../services/contact_service.dart';
import '../../../core/exceptions/app_exception.dart';

/// Manages the contact list state for the contacts feature.
///
/// Acts as the single source of truth for contact data. All screens read
/// contacts via this provider rather than holding their own local copies,
/// so edits (e.g. from [PostCallReviewScreen]) are immediately visible
/// on every screen that watches this provider.
///
/// Does not interact with Hive directly — delegates to [ContactService].
class ContactProvider extends ChangeNotifier {
  ContactProvider({ContactService? service})
      : _service = service ?? ContactService();

  final ContactService _service;

  // Callback wired by main.dart to SyncProvider.enqueue — avoids a direct
  // dependency on contact_sources from the contacts feature.
  void Function(String contactId)? _onContactUpdated;

  /// Called once in [main.dart] after both [ContactProvider] and [SyncProvider]
  /// are created, to wire the sync trigger without creating circular imports.
  void setSyncCallback(void Function(String contactId) callback) {
    _onContactUpdated = callback;
  }

  List<ContactModel> _contacts = [];
  List<ContactModel> get contacts => List.unmodifiable(_contacts);

  /// Returns all contacts belonging to a specific [sourceId].
  ///
  /// Filters the in-memory contact list by [ContactModel.importedFromTableId].
  /// Retains the original sequential creation ordering.
  List<ContactModel> getContactsForSource(String sourceId) {
    return _contacts
        .where((c) => c.importedFromTableId == sourceId)
        .toList();
  }

  /// Returns the total number of contacts imported from [sourceId].
  int getContactCountForSource(String sourceId) {
    return _contacts
        .where((c) => c.importedFromTableId == sourceId)
        .length;
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Seeds demo data on first launch, then loads all contacts.
  ///
  /// Should be called once at app startup after Hive boxes are open.
  Future<void> seedAndLoad() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.seedDummyContactsIfEmpty();
      await _service.autoPopulateMissingCountries();
      _contacts = _service.getAll();
    } on AppException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Failed to load contacts.';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Reloads the contact list from storage.
  ///
  /// Call after creating, updating, or deleting a contact.
  Future<void> reload() async {
    try {
      _contacts = _service.getAll();
      notifyListeners();
    } on AppException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    }
  }

  /// Returns the contact with [id] from the in-memory list, or null if not found.
  ///
  /// Screens use this instead of storing a local copy of the model so that
  /// edits made elsewhere are always reflected without a page reload.
  ContactModel? findById(String id) {
    try {
      return _contacts.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Persists [updated] via [ContactService] and refreshes the in-memory list.
  ///
  /// If [updated] was imported from a contact source ([ContactModel.importedFromTableId]
  /// is non-null), the contact is automatically marked [SyncStatus.pendingSync]
  /// and queued for immediate background synchronization via [_onContactUpdated].
  /// The user does not wait for the sync — the local save completes first.
  ///
  /// If the contact's previous sync had failed, editing it resets
  /// [syncRetryCount] to 0 so the backoff schedule starts fresh.
  Future<void> updateContact(ContactModel updated) async {
    try {
      // Determine the correct sync status before saving.
      final syncStatus = updated.importedFromTableId != null
          ? SyncStatus.pendingSync
          : SyncStatus.noSource;

      final withSync = updated.copyWith(
        syncStatus: syncStatus,
        // Reset retry count when the user edits the contact — fresh retries
        // even if previous attempts had reached the failure limit.
        syncRetryCount: 0,
      );

      await _service.update(withSync);
      await reload();

      // Fire the sync callback after the local save. The callback is
      // SyncProvider.enqueue, which starts an immediate background push.
      if (syncStatus == SyncStatus.pendingSync) {
        _onContactUpdated?.call(withSync.id);
      }
    } on AppException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    }
  }
}
