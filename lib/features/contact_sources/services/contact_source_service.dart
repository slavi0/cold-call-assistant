import 'package:hive_flutter/hive_flutter.dart';
import '../models/contact_source.dart';
import '../../../core/exceptions/app_exception.dart';

/// Handles persistence of [ContactSource] configurations in a Hive box.
///
/// Each configuration is stored as a raw JSON string, keyed by the source's
/// [ContactSource.id]. Using raw JSON (rather than Hive type adapters) means:
/// - Adding a new source type requires zero Hive changes.
/// - Serialization logic lives in the model, not in generated code.
/// - The schema can evolve without Hive version bumps.
///
/// This is the ONLY place in the codebase that reads from or writes to the
/// [_boxName] Hive box. Providers call this service; they never touch Hive.
class ContactSourceService {
  static const _boxName = 'contact_sources';

  Box<String> get _box => Hive.box<String>(_boxName);

  /// Opens the Hive box. Must be called once during app startup before any
  /// other method on this service is used.
  static Future<void> openBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<String>(_boxName);
    }
  }

  /// Loads and deserializes all stored contact source configurations.
  ///
  /// Entries with unknown type discriminators are silently skipped.
  /// This ensures the app remains functional when a source type is removed
  /// in a future version (forward-compatibility).
  List<ContactSource> loadAll() {
    try {
      final sources = <ContactSource>[];
      for (final jsonString in _box.values) {
        try {
          sources.add(ContactSource.fromJsonString(jsonString));
        } on FormatException {
          // Skip entries with unrecognized type discriminators rather than
          // crashing the entire source list.
        }
      }
      return sources;
    } catch (e) {
      throw StorageException('Failed to load contact sources.', cause: e);
    }
  }

  /// Persists a [ContactSource], creating or overwriting the entry for its ID.
  Future<void> save(ContactSource source) async {
    try {
      await _box.put(source.id, source.toJsonString());
    } catch (e) {
      throw StorageException('Failed to save contact source.', cause: e);
    }
  }

  /// Deletes the contact source with [id]. No-op if it does not exist.
  Future<void> delete(String id) async {
    try {
      await _box.delete(id);
    } catch (e) {
      throw StorageException('Failed to delete contact source.', cause: e);
    }
  }
}
