import 'package:flutter/foundation.dart';
import '../models/contact_model.dart';
import '../services/contact_service.dart';
import '../../../core/exceptions/app_exception.dart';

/// Manages the contact list state for the contacts feature.
///
/// Responsible for loading contacts from [ContactService] and exposing them
/// to the UI layer. Does not interact with Hive directly.
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
}
