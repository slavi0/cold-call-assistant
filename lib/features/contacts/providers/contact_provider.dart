import 'package:flutter/foundation.dart';
import '../models/contact_model.dart';
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

  List<ContactModel> _contacts = [];
  List<ContactModel> get contacts => List.unmodifiable(_contacts);

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
  /// All screens watching this provider will automatically reflect the change.
  Future<void> updateContact(ContactModel updated) async {
    try {
      await _service.update(updated);
      await reload();
    } on AppException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    }
  }
}
