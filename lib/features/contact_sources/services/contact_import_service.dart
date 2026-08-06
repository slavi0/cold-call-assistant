import '../models/contact_field.dart';
import '../models/contact_import_summary.dart';
import '../models/contact_source.dart';
import '../../contacts/models/sync_status.dart';
import '../../contacts/services/contact_service.dart';
import '../../../core/exceptions/app_exception.dart';

/// Converts [ContactField] data rows into [ContactModel] records and persists
/// them using [ContactService].
///
/// ## Duplicate detection strategy
/// A row is considered a duplicate if an existing contact in the local database
/// has the **same trimmed phone number string**. This is the correct strategy
/// for a cold-call workflow: the phone number is the actionable identity, and
/// placing two calls to the same number must be avoided.
///
/// Fallback: if a row has no phone number, the name is compared
/// case-insensitively (trimmed). If it matches an existing contact, the row
/// is skipped.
///
/// On duplicate detection, the existing contact is NOT modified. Any post-call
/// data (notes, status, call history) that the salesperson recorded after the
/// original import is fully preserved.
///
/// ## Multi-phone strings
/// Phone numbers are stored as-is. A value like "0600 123 456 / 0700 789 012"
/// is treated as a single string and compared by exact trimmed-string equality.
/// This is the correct behaviour for this application — the source data is
/// trusted to be correct.
///
/// ## Performance
/// Rows are processed in configurable batches (default 100). After each batch,
/// [Future.delayed] yields control back to the event loop so the UI remains
/// responsive during large imports.
class ContactImportService {
  ContactImportService({ContactService? contactService})
      : _contactService = contactService ?? ContactService();

  final ContactService _contactService;

  /// Number of rows processed per batch before yielding to the event loop.
  static const _batchSize = 100;

  /// Processes [rows] from a [GoogleSheetsSource] and imports new contacts.
  ///
  /// [onProgress] is called after each batch with `(processedSoFar, totalRows)`
  /// so the UI can display a live progress count.
  ///
  /// Returns a [ContactImportSummary] describing the full outcome.
  Future<ContactImportSummary> importRows({
    required List<Map<ContactField, String>> rows,
    required GoogleSheetsSource source,
    void Function(int processed, int total)? onProgress,
  }) async {
    var imported = 0;
    var skipped = 0;
    var failed = 0;
    final errors = <String>[];

    // Build deduplication sets from a single snapshot of existing contacts.
    // Taking the snapshot once avoids N repeated database reads during import.
    final existingPhones = <String>{};
    final existingNames = <String>{};

    for (final contact in _contactService.getAll()) {
      final phone = contact.phoneNumber?.trim() ?? '';
      if (phone.isNotEmpty) existingPhones.add(phone);
      existingNames.add(contact.name.trim().toLowerCase());
    }

    var processed = 0;
    final total = rows.length;

    for (var batchStart = 0; batchStart < total; batchStart += _batchSize) {
      final batchEnd = (batchStart + _batchSize).clamp(0, total);
      final batch = rows.sublist(batchStart, batchEnd);

      for (final row in batch) {
        processed++;

        // Add 1 to processed count to get the approximate source row number.
        // When a header row was skipped, the first data row is source row 2.
        final sourceRowNumber = processed + (source.hasHeaderRow ? 1 : 0);

        final name = row[ContactField.name]?.trim() ?? '';
        final phone = row[ContactField.phoneNumber]?.trim() ?? '';

        // ── Validate required fields ─────────────────────────────────────────
        if (name.isEmpty && phone.isEmpty) {
          failed++;
          errors.add('Row $sourceRowNumber: Missing both name and phone number.');
          continue;
        }

        // ── Duplicate detection ──────────────────────────────────────────────
        if (phone.isNotEmpty && existingPhones.contains(phone)) {
          skipped++;
          continue;
        }
        if (phone.isEmpty && existingNames.contains(name.toLowerCase())) {
          skipped++;
          continue;
        }

        // ── Persist ──────────────────────────────────────────────────────────
        try {
          await _contactService.create(
            name: name.isNotEmpty ? name : 'Unknown',
            phoneNumber: phone.isNotEmpty ? phone : null,
            email: row[ContactField.email]?.trim(),
            company: row[ContactField.company]?.trim(),
            notes: row[ContactField.notes]?.trim(),
            // Source ID is stored so contacts can be traced back to their
            // origin and synced back after edits.
            importedFromTableId: source.id,
            // Mark as already synced — the data just came from the sheet,
            // so there is nothing to push back until the user edits the contact.
            syncStatus: SyncStatus.synced,
          );

          // Update the in-memory dedup sets so subsequent rows in the same
          // import run do not create duplicates of contacts just added.
          if (phone.isNotEmpty) existingPhones.add(phone);
          if (name.isNotEmpty) existingNames.add(name.toLowerCase());

          imported++;
        } on AppException catch (e) {
          failed++;
          errors.add('Row $sourceRowNumber ($name): ${e.message}');
        } catch (e) {
          failed++;
          errors.add('Row $sourceRowNumber ($name): Unexpected error.');
        }
      }

      // Notify the UI of progress and yield to the event loop after each batch.
      onProgress?.call(processed, total);
      await Future.delayed(Duration.zero);
    }

    return ContactImportSummary(
      sourceDisplayName: source.displayName,
      imported: imported,
      skipped: skipped,
      failed: failed,
      errors: List.unmodifiable(errors),
      totalRows: total,
      completedAt: DateTime.now(),
    );
  }
}
