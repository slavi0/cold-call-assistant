import 'package:flutter/foundation.dart';

import '../models/contact_import_summary.dart';
import '../models/contact_source.dart';
import '../services/contact_import_service.dart';
import '../services/google_sheets_integration.dart';
import '../../contacts/providers/contact_provider.dart';
import '../../../core/exceptions/app_exception.dart';

/// Manages the contact import workflow.
///
/// Responsibilities:
/// - Orchestrating the full import: sign-in check → read rows → import rows →
///   reload local contact list.
/// - Exposing live progress (processedRows / totalRows) for the UI.
/// - Storing the [ContactImportSummary] for display after the import completes.
///
/// [ContactProvider] is passed into [importFromSource] at call-time rather than
/// injected in the constructor. This avoids a circular dependency and keeps the
/// provider tree ordering flexible.
class ContactImportProvider extends ChangeNotifier {
  ContactImportProvider({
    GoogleSheetsIntegration? sheetsIntegration,
    ContactImportService? importService,
  })  : _sheets = sheetsIntegration ?? GoogleSheetsIntegration(),
        _importService = importService ?? ContactImportService();

  final GoogleSheetsIntegration _sheets;
  final ContactImportService _importService;

  // ── State ──────────────────────────────────────────────────────────────────

  bool _isImporting = false;
  bool get isImporting => _isImporting;

  /// Rows processed so far. Used for a live progress indicator.
  int _processedRows = 0;
  int get processedRows => _processedRows;

  /// Total rows read from the source. Available once the read step completes.
  int _totalRows = 0;
  int get totalRows => _totalRows;

  /// The summary from the most recent import. Null before the first import.
  ContactImportSummary? _lastSummary;
  ContactImportSummary? get lastSummary => _lastSummary;

  /// Set when an import fails at the source-read or auth level (before
  /// row-level processing begins). Row-level failures appear in [lastSummary].
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ── Import ─────────────────────────────────────────────────────────────────

  /// Runs a complete import from [source].
  ///
  /// Steps:
  /// 1. Read rows from Google Sheets via [GoogleSheetsIntegration].
  /// 2. Process and save rows via [ContactImportService].
  /// 3. Reload [contactProvider] so imported contacts appear immediately.
  ///
  /// Returns the [ContactImportSummary] on success, or null if the operation
  /// failed before row processing could begin (auth error, network error, etc.).
  Future<ContactImportSummary?> importFromSource({
    required GoogleSheetsSource source,
    required ContactProvider contactProvider,
  }) async {
    _isImporting = true;
    _processedRows = 0;
    _totalRows = 0;
    _errorMessage = null;
    _lastSummary = null;
    notifyListeners();

    try {
      // ── Step 1: Read rows from Google Sheets ──────────────────────────────
      final rows = await _sheets.readRows(source);
      _totalRows = rows.length;
      notifyListeners();

      // ── Step 2: Import rows into local database ────────────────────────────
      final summary = await _importService.importRows(
        rows: rows,
        source: source,
        onProgress: (processed, total) {
          _processedRows = processed;
          notifyListeners();
        },
      );

      _lastSummary = summary;

      // ── Step 3: Reload contacts if any were added ──────────────────────────
      if (summary.imported > 0) {
        await contactProvider.reload();
      }

      return summary;
    } on GoogleSheetsException catch (e) {
      _errorMessage = e.message;
      return null;
    } on AppException catch (e) {
      _errorMessage = e.message;
      return null;
    } catch (e) {
      _errorMessage = 'Import failed: ${e.toString()}';
      return null;
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }
}
