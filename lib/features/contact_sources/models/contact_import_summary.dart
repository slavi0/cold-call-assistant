/// An immutable summary of a single contact import operation.
///
/// Returned by [ContactImportService.importRows] and stored on
/// [ContactImportProvider.lastSummary] so [ImportSummaryScreen] can
/// display the results after the import completes.
class ContactImportSummary {
  const ContactImportSummary({
    required this.sourceDisplayName,
    required this.imported,
    required this.skipped,
    required this.failed,
    required this.errors,
    required this.totalRows,
    required this.completedAt,
  });

  /// The user-facing name of the source that was imported from.
  final String sourceDisplayName;

  /// Number of contacts successfully created in the local database.
  final int imported;

  /// Number of rows skipped because a matching contact already existed locally.
  final int skipped;

  /// Number of rows that could not be imported (missing required fields, etc.).
  final int failed;

  /// Human-readable error descriptions for each failed row.
  final List<String> errors;

  /// Total data rows read from the source (header row excluded).
  final int totalRows;

  /// Timestamp when the import finished.
  final DateTime completedAt;

  /// True if any rows failed (used to tint the summary icon).
  bool get hasErrors => failed > 0;

  /// True if the import processed at least one row (success or skipped).
  bool get isSuccess => imported > 0 || skipped > 0;
}
