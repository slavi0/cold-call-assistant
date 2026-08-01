import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/excel_table_model.dart';
import '../../../core/exceptions/app_exception.dart';

/// Handles all persistence operations for [ExcelTableModel].
///
/// Supabase migration path:
/// Replace Hive calls with Supabase client calls. Method signatures stay the same.
class ExcelTableService {
  static const _boxName = 'excel_tables';
  final _uuid = const Uuid();

  Box<ExcelTableModel> get _box => Hive.box<ExcelTableModel>(_boxName);

  static Future<void> openBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<ExcelTableModel>(_boxName);
    }
  }

  /// Returns all stored import records, newest first.
  List<ExcelTableModel> getAll() {
    final tables = _box.values.toList();
    tables.sort((a, b) => b.importedAt.compareTo(a.importedAt));
    return tables;
  }

  /// Returns a single import record by [id], or null if not found.
  ExcelTableModel? getById(String id) {
    return _box.values.cast<ExcelTableModel?>().firstWhere(
          (t) => t?.id == id,
          orElse: () => null,
        );
  }

  /// Persists a new import record.
  Future<ExcelTableModel> create({
    required String name,
    String? filePath,
    int? rowCount,
  }) async {
    try {
      final table = ExcelTableModel(
        id: _uuid.v4(),
        name: name,
        filePath: filePath,
        importedAt: DateTime.now(),
        rowCount: rowCount,
      );
      await _box.put(table.id, table);
      return table;
    } catch (e) {
      throw StorageException('Failed to save import record.', cause: e);
    }
  }

  /// Updates the name or metadata of an existing import record.
  Future<ExcelTableModel> update(ExcelTableModel updated) async {
    if (!_box.containsKey(updated.id)) {
      throw const NotFoundException('Import record not found.');
    }
    try {
      await _box.put(updated.id, updated);
      return updated;
    } catch (e) {
      throw StorageException('Failed to update import record.', cause: e);
    }
  }

  /// Deletes an import record by [id]. Does NOT delete associated contacts —
  /// that cascade must be handled by the provider to keep services independent.
  Future<void> delete(String id) async {
    try {
      await _box.delete(id);
    } catch (e) {
      throw StorageException('Failed to delete import record.', cause: e);
    }
  }
}
