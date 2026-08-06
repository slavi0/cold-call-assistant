import '../models/contact_field.dart';
import '../models/contact_source.dart';
import '../../contacts/models/contact_model.dart';
import '../../contacts/models/contact_status.dart';
import 'google_sheets_integration.dart';
import 'sync_adapter.dart';
import '../../../core/exceptions/app_exception.dart';

/// Implements [SyncAdapter] for Google Sheets.
///
/// ## Contact matching strategy: normalized phone number
///
/// Every push operation scans the phone-number column of the configured
/// worksheet and finds the row whose phone value, after stripping all
/// non-digit characters, matches the local contact's phone number.
///
/// **Why phone number instead of row index?**
/// - Row index breaks when someone inserts or reorders rows in the sheet.
/// - Phone number is stable even after reordering, because it represents the
///   actual identity of the contact in the cold-call workflow.
/// - Phase 2 deduplication guarantees that no two local contacts share the
///   same phone number, so the match is always unique.
///
/// **Known limitation**: if the phone number is corrected in the spreadsheet
/// after import, the sync will fail to find the row and report a [SyncException].
/// The local data is never lost — the failure is retried per the backoff schedule.
///
/// ## Fields synced back to the sheet
///
/// Only [ContactField.status] and [ContactField.notes] are written back.
/// These are the only fields the app allows the user to edit.
/// Name, phone, email, and company are read-only from the app's perspective —
/// writing them back would risk overwriting corrections made in the sheet.
///
/// If a field is not present in [GoogleSheetsSource.columnMapping], it is
/// silently skipped (the column simply was not mapped by the user).
class GoogleSheetsSyncAdapter implements SyncAdapter {
  const GoogleSheetsSyncAdapter({
    required GoogleSheetsIntegration sheetsIntegration,
  }) : _sheets = sheetsIntegration;

  final GoogleSheetsIntegration _sheets;

  /// Non-digit regex used for phone number normalization.
  static final _nonDigit = RegExp(r'[^\d]');

  @override
  String get adapterId => GoogleSheetsSource.typeKey;

  @override
  Future<bool> isAvailable() async {
    // Simple availability check — we can extend this to also test connectivity
    // in a future phase (e.g., using the connectivity_plus package).
    return _sheets.isSignedIn;
  }

  @override
  Future<void> pushUpdate({
    required ContactModel contact,
    required ContactSource source,
  }) async {
    final sheetsSource = source as GoogleSheetsSource;

    // ── Validate prerequisites ─────────────────────────────────────────────
    final phone = contact.phoneNumber?.trim() ?? '';
    if (phone.isEmpty) {
      throw const SyncException(
        'Contact has no phone number. '
        'Cannot locate its row in the spreadsheet.',
      );
    }

    final phoneColumn = sheetsSource.columnMapping[ContactField.phoneNumber];
    if (phoneColumn == null) {
      throw const SyncException(
        'No phone number column is configured in this source mapping. '
        'Open the source settings and map the "Phone Number" column.',
      );
    }

    // ── Locate the row in the sheet ────────────────────────────────────────
    final normalizedPhone = _normalizePhone(phone);
    final rowNumber = await _sheets.findRowByPhone(
      source: sheetsSource,
      normalizedPhone: normalizedPhone,
      phoneColumn: phoneColumn,
    );

    if (rowNumber == null) {
      throw SyncException(
        'Could not find a row matching phone number "${contact.phoneNumber}" '
        'in worksheet "${sheetsSource.worksheetName}". '
        'The row may have been deleted from the spreadsheet.',
      );
    }

    // ── Build cell updates ─────────────────────────────────────────────────
    final updates = _buildCellUpdates(
      contact: contact,
      source: sheetsSource,
      rowNumber: rowNumber,
    );

    if (updates.isEmpty) {
      // Nothing to write — neither status nor notes column is mapped.
      return;
    }

    // ── Write to the sheet ─────────────────────────────────────────────────
    await _sheets.updateCells(source: sheetsSource, updates: updates);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Strips all non-digit characters for consistent phone number comparison.
  ///
  /// Examples:
  /// - '+33 1 77 45 53 29'  →  '33177455329'
  /// - '06 00 / 07 00'      →  '0600 0700'  →  '06000700'
  static String _normalizePhone(String phone) =>
      phone.replaceAll(_nonDigit, '');

  /// Builds the A1-notation range → value map for the cells to update.
  ///
  /// Only [ContactField.status] and [ContactField.notes] are included.
  /// Both are only written if they are present in [source.columnMapping].
  Map<String, String> _buildCellUpdates({
    required ContactModel contact,
    required GoogleSheetsSource source,
    required int rowNumber,
  }) {
    final updates = <String, String>{};

    // Fields the app actually edits — the only ones we write back.
    // Adding a future editable field (e.g., "nextCallDate") is a one-line
    // addition here; no changes to SyncProvider or SyncAdapter are needed.
    const writableFields = [ContactField.status, ContactField.notes];

    for (final field in writableFields) {
      final column = source.columnMapping[field];
      if (column == null) continue; // Field not mapped — skip gracefully.

      final value = switch (field) {
        ContactField.status => contact.status.displayLabel,
        ContactField.notes => contact.notes ?? '',
        _ => null,
      };
      if (value == null) continue;

      // A1 notation: 'SheetName'!B5
      final range = "'${source.worksheetName}'!${column.toUpperCase()}$rowNumber";
      updates[range] = value;
    }

    return updates;
  }
}
