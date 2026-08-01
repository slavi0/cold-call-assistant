import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/contact_model.dart';
import '../models/contact_status.dart';
import '../../../core/exceptions/app_exception.dart';

/// Handles all persistence operations for [ContactModel].
///
/// This is the ONLY place in the codebase that interacts with the Hive box
/// for contacts. Providers call this service; they never touch Hive directly.
///
/// Supabase migration path:
/// Replace the Hive calls inside each method with Supabase client calls.
/// The method signatures (and therefore all providers) stay unchanged.
class ContactService {
  static const _boxName = 'contacts';
  final _uuid = const Uuid();

  Box<ContactModel> get _box => Hive.box<ContactModel>(_boxName);

  /// Opens the Hive box. Must be called once during app startup before any
  /// other method on this service is used.
  static Future<void> openBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<ContactModel>(_boxName);
    }
  }

  /// Returns all stored contacts, ordered by [createdAt] descending.
  List<ContactModel> getAll() {
    final contacts = _box.values.toList();
    contacts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return contacts;
  }

  /// Returns a single contact by [id], or null if not found.
  ContactModel? getById(String id) {
    return _box.values.cast<ContactModel?>().firstWhere(
          (c) => c?.id == id,
          orElse: () => null,
        );
  }

  /// Returns all contacts imported from a specific [ExcelTableModel].
  List<ContactModel> getByTableId(String tableId) {
    return _box.values
        .where((c) => c.importedFromTableId == tableId)
        .toList();
  }

  /// Returns all contacts with a given [status].
  List<ContactModel> getByStatus(ContactStatus status) {
    return _box.values.where((c) => c.status == status).toList();
  }

  /// Persists a new contact. Generates its ID automatically.
  ///
  /// Returns the created [ContactModel].
  Future<ContactModel> create({
    required String name,
    String? company,
    String? phoneNumber,
    String? email,
    String? notes,
    String? importedFromTableId,
    ContactStatus status = ContactStatus.newContact,
  }) async {
    try {
      final now = DateTime.now();
      final contact = ContactModel(
        id: _uuid.v4(),
        name: name,
        company: company,
        phoneNumber: phoneNumber,
        email: email,
        notes: notes,
        status: status,
        createdAt: now,
        updatedAt: now,
        importedFromTableId: importedFromTableId,
      );
      await _box.put(contact.id, contact);
      return contact;
    } catch (e) {
      throw StorageException('Failed to save contact.', cause: e);
    }
  }

  /// Updates an existing contact. Throws [NotFoundException] if not found.
  Future<ContactModel> update(ContactModel updated) async {
    if (!_box.containsKey(updated.id)) {
      throw const NotFoundException('Contact not found.');
    }
    try {
      final withTimestamp = updated.copyWith(updatedAt: DateTime.now());
      await _box.put(withTimestamp.id, withTimestamp);
      return withTimestamp;
    } catch (e) {
      throw StorageException('Failed to update contact.', cause: e);
    }
  }

  /// Deletes a contact by [id]. No-op if the contact does not exist.
  Future<void> delete(String id) async {
    try {
      await _box.delete(id);
    } catch (e) {
      throw StorageException('Failed to delete contact.', cause: e);
    }
  }

  /// Seeds 10 dummy contacts into the box if it is currently empty.
  ///
  /// Called once at app startup so the app launches with usable data without
  /// requiring the user to import an Excel file first.
  /// All contacts share the same demo phone number and differ only by name,
  /// which is sufficient for testing the calling workflow.
  Future<void> seedDummyContactsIfEmpty() async {
    if (_box.isNotEmpty) return;

    const demoPhone = '+33177455329';
    const demoNames = [
      'Alice Martin',
      'Bob Dupont',
      'Clara Fontaine',
      'David Leclerc',
      'Eva Rousseau',
      'François Bernard',
      'Grace Morel',
      'Hugo Petit',
      'Isabelle Girard',
      'Julien Lambert',
    ];

    try {
      final now = DateTime.now();
      for (final name in demoNames) {
        final contact = ContactModel(
          id: _uuid.v4(),
          name: name,
          phoneNumber: demoPhone,
          createdAt: now,
          updatedAt: now,
          status: ContactStatus.newContact,
        );
        await _box.put(contact.id, contact);
      }
    } catch (e) {
      throw StorageException('Failed to seed dummy contacts.', cause: e);
    }
  }
}
