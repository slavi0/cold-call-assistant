import 'package:hive/hive.dart';

part 'excel_table_model.g.dart';

/// Represents a single Excel spreadsheet that was imported into the app.
///
/// Designed with extensibility in mind — new fields can be added via
/// new [HiveField] indices without breaking existing stored data.
///
/// Design notes vs. original proposal:
/// - [link] renamed to [filePath] and made nullable — stores the absolute local
///   path to the original .xlsx file if the user chose to keep it. Null if the
///   file was not retained after import.
/// - [importedAt] added — when was this import done? Required for history sorting.
/// - [rowCount] added — how many contact rows were in the spreadsheet? Useful
///   summary metadata without loading every contact record.
@HiveType(typeId: 3)
class ExcelTableModel extends HiveObject {
  ExcelTableModel({
    required this.id,
    required this.name,
    required this.importedAt,
    this.filePath,
    this.rowCount,
  });

  @HiveField(0)
  final String id;

  /// A human-readable label for this import (e.g. "Q3 Leads - July 2026").
  /// Defaults to the original filename but can be renamed by the user.
  @HiveField(1)
  String name;

  /// Absolute path to the retained .xlsx file on device. Nullable because
  /// the user may not keep the file after import, or the file may have
  /// been deleted externally.
  @HiveField(2)
  String? filePath;

  /// When the import was performed.
  @HiveField(3)
  final DateTime importedAt;

  /// Number of contact rows found in the spreadsheet.
  /// Stored to avoid counting DB records for a simple summary display.
  @HiveField(4)
  int? rowCount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'file_path': filePath,
      'imported_at': importedAt.toIso8601String(),
      'row_count': rowCount,
    };
  }
}
