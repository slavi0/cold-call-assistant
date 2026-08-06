import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

import '../models/contact_field.dart';
import '../models/contact_source.dart';
import '../../../core/exceptions/app_exception.dart';

/// Handles all communication with the Google Sheets API.
///
/// This is the ONLY class in the codebase that imports [google_sign_in] or
/// [googleapis]. All code outside this class sees only Dart types
/// ([ContactField] maps) and [GoogleSheetsException] — never any Google API
/// types. This isolation means the provider that powers the sign-in button and
/// the one that triggers imports can remain completely unaware of OAuth details.
///
/// ## Authentication
/// OAuth 2.0 via [GoogleSignIn] (v6). The user signs in interactively once;
/// the package caches the token and refreshes it transparently on subsequent
/// calls. Authentication state survives app restarts via the silent sign-in.
///
/// ## Why one instance must be shared
/// [GoogleSignIn] stores auth state in its instance. Create exactly ONE
/// [GoogleSheetsIntegration] in [main.dart] and inject it into every provider
/// that needs it so they share the same authenticated session.
class GoogleSheetsIntegration {
  GoogleSheetsIntegration() {
    _googleSignIn = GoogleSignIn(
      scopes: [SheetsApi.spreadsheetsScope],
      // serverClientId = Web Application OAuth client ID from Google Cloud
      // Console. Required so the package can obtain an ID token that
      // identifies your application to Google's servers.
      serverClientId: _webClientId,
    );
  }

  /// Replace this value with the Web Application OAuth Client ID from your
  /// Google Cloud Console project (APIs & Services → Credentials).
  static const _webClientId =
      '1063846340238-s831ti24qrvjhp1da3oksm8adqnplhau.apps.googleusercontent.com';

  late final GoogleSignIn _googleSignIn;

  // ── Authentication ─────────────────────────────────────────────────────────

  /// The currently signed-in Google account, or null if not authenticated.
  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  /// True if a user is currently signed in.
  bool get isSignedIn => _googleSignIn.currentUser != null;

  /// Triggers the interactive Google Sign-In flow.
  ///
  /// Returns the signed-in [GoogleSignInAccount], or null if the user
  /// dismissed the sign-in dialog.
  Future<GoogleSignInAccount?> signIn() async {
    try {
      return await _googleSignIn.signIn();
    } catch (e) {
      throw GoogleSheetsException(
        'Sign-in failed: ${_friendlyError(e)}',
        cause: e,
      );
    }
  }

  /// Silently restores the previous sign-in session if available.
  ///
  /// Called once at app startup so returning users are automatically
  /// authenticated without a prompt. Returns null on any failure.
  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (_) {
      // Silent failure is intentionally swallowed — the user will be prompted
      // to sign in manually when they next trigger a Sheets operation.
      return null;
    }
  }

  /// Signs the user out and clears all cached credentials.
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  // ── Validation ─────────────────────────────────────────────────────────────

  /// Validates a [GoogleSheetsSource] configuration by verifying:
  ///
  /// 1. The spreadsheet URL is a valid Google Sheets URL.
  /// 2. The user is signed in.
  /// 3. The spreadsheet exists and the user has access.
  /// 4. The specified worksheet tab exists.
  /// 5. Each configured column letter falls within the sheet's column range.
  ///
  /// Throws [GoogleSheetsException] with a user-displayable message on any
  /// failure. Never throws generic exceptions to callers.
  Future<void> validateSource(GoogleSheetsSource source) async {
    _requireSignedIn();

    final spreadsheetId = _extractSpreadsheetId(source.spreadsheetUrl);
    if (spreadsheetId == null) {
      throw const GoogleSheetsException(
        'The URL does not look like a Google Sheets link.\n'
        'It should contain "/spreadsheets/d/".',
      );
    }

    final client = await _googleSignIn.authenticatedClient();
    if (client == null) {
      throw const GoogleSheetsException(
        'Authentication expired. Please sign out and sign in again.',
      );
    }

    try {
      final api = SheetsApi(client);

      // ── Step 1: Verify spreadsheet exists and user has access ──────────────
      final spreadsheet = await api.spreadsheets.get(
        spreadsheetId,
        $fields: 'sheets.properties.title',
      );

      // ── Step 2: Verify worksheet tab exists ────────────────────────────────
      final availableTabs = (spreadsheet.sheets ?? [])
          .map((s) => s.properties?.title ?? '')
          .where((t) => t.isNotEmpty)
          .toList();

      if (!availableTabs.contains(source.worksheetName)) {
        final tabList = availableTabs.isEmpty
            ? 'No tabs found.'
            : 'Available tabs: ${availableTabs.join(", ")}';
        throw GoogleSheetsException(
          'Worksheet "${source.worksheetName}" was not found.\n$tabList',
        );
      }

      // ── Step 3: Verify each mapped column is within the sheet's range ──────
      if (source.columnMapping.isNotEmpty) {
        final headerRange = '${source.worksheetName}!A1:ZZZ1';
        final headerResp = await api.spreadsheets.values.get(
          spreadsheetId,
          headerRange,
        );
        final firstRow = headerResp.values?.firstOrNull ?? const [];
        final columnCount = firstRow.length;

        // Only check if the sheet has at least one row — an empty sheet would
        // fail even for column A, which is a confusing error.
        if (columnCount > 0) {
          for (final entry in source.columnMapping.entries) {
            final idx = _columnLetterToIndex(entry.value);
            if (idx >= columnCount) {
              throw GoogleSheetsException(
                'Column "${entry.value}" (${entry.key.displayLabel}) does not '
                'exist in "${source.worksheetName}". '
                'The sheet has $columnCount column(s).',
              );
            }
          }
        }
      }
    } on GoogleSheetsException {
      rethrow;
    } on DetailedApiRequestError catch (e) {
      throw _mapApiError(e);
    } catch (e) {
      if (_isNetworkError(e)) {
        throw const GoogleSheetsException(
          'Network error. Check your internet connection and try again.',
        );
      }
      throw GoogleSheetsException(
        'Unexpected error: ${_friendlyError(e)}',
        cause: e,
      );
    } finally {
      client.close();
    }
  }

  // ── Data Reading ───────────────────────────────────────────────────────────

  /// Reads all data rows from the configured worksheet and maps each cell
  /// to its [ContactField] using [GoogleSheetsSource.columnMapping].
  ///
  /// If [GoogleSheetsSource.hasHeaderRow] is true, the first row is skipped.
  /// Empty rows (no name or phone number) are also skipped.
  ///
  /// Returns an empty list if the sheet has no data rows.
  /// Throws [GoogleSheetsException] on any API or network error.
  Future<List<Map<ContactField, String>>> readRows(
    GoogleSheetsSource source,
  ) async {
    _requireSignedIn();

    final spreadsheetId = _extractSpreadsheetId(source.spreadsheetUrl);
    if (spreadsheetId == null) {
      throw const GoogleSheetsException('Invalid spreadsheet URL.');
    }

    final client = await _googleSignIn.authenticatedClient();
    if (client == null) {
      throw const GoogleSheetsException(
        'Authentication expired. Please sign out and sign in again.',
      );
    }

    try {
      final api = SheetsApi(client);

      // Fetch every column in the worksheet up to ZZZ so no data is missed.
      final range = '${source.worksheetName}!A:ZZZ';
      final response = await api.spreadsheets.values.get(spreadsheetId, range);

      final allRows = response.values ?? [];
      if (allRows.isEmpty) return const [];

      // Optionally skip the first row when the sheet has a header.
      final dataRows = (source.hasHeaderRow && allRows.length > 1)
          ? allRows.sublist(1)
          : allRows;

      return _mapRowsToFields(dataRows, source.columnMapping);
    } on GoogleSheetsException {
      rethrow;
    } on DetailedApiRequestError catch (e) {
      throw _mapApiError(e);
    } catch (e) {
      if (_isNetworkError(e)) {
        throw const GoogleSheetsException(
          'Network error. Check your internet connection and try again.',
        );
      }
      throw GoogleSheetsException(
        'Failed to read spreadsheet: ${_friendlyError(e)}',
        cause: e,
      );
    } finally {
      client.close();
    }
  }

  // ── Data Writing ────────────────────────────────────────────────────────────

  /// Scans the phone column of [source.worksheetName] for a row whose value
  /// normalizes to [normalizedPhone] (digits only).
  ///
  /// Returns the **1-based spreadsheet row number** of the first match, or
  /// null if no match is found.
  ///
  /// Only [phoneColumn] is fetched — the entire row is not read — to minimize
  /// API quota consumption during sync runs.
  Future<int?> findRowByPhone({
    required GoogleSheetsSource source,
    required String normalizedPhone,
    required String phoneColumn,
  }) async {
    _requireSignedIn();

    final spreadsheetId = _extractSpreadsheetId(source.spreadsheetUrl);
    if (spreadsheetId == null) {
      throw const GoogleSheetsException('Invalid spreadsheet URL.');
    }

    final client = await _googleSignIn.authenticatedClient();
    if (client == null) {
      throw const GoogleSheetsException(
        'Authentication expired. Please sign out and sign in again.',
      );
    }

    try {
      final api = SheetsApi(client);

      // Read only the phone column to minimise data transfer.
      final col = phoneColumn.toUpperCase();
      final range = '${source.worksheetName}!$col:$col';
      final response = await api.spreadsheets.values.get(spreadsheetId, range);
      final rows = response.values ?? [];

      // Row 1 is the header when hasHeaderRow is true; data starts at row 2.
      // Without a header, data starts at row 1.
      final headerOffset = source.hasHeaderRow ? 1 : 0;

      for (int i = headerOffset; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;
        final cellPhone = row[0].toString();
        // Normalize the cell value the same way the contact's phone is normalized.
        final normalizedCell = cellPhone.replaceAll(RegExp(r'[^\d]'), '');
        if (normalizedCell == normalizedPhone) {
          // Convert 0-based list index to 1-based spreadsheet row number.
          return i + 1;
        }
      }

      return null; // No matching row found.
    } on GoogleSheetsException {
      rethrow;
    } on DetailedApiRequestError catch (e) {
      throw _mapApiError(e);
    } catch (e) {
      if (_isNetworkError(e)) {
        throw const GoogleSheetsException(
          'Network error. Check your internet connection and try again.',
        );
      }
      throw GoogleSheetsException(
        'Failed to scan phone column: ${_friendlyError(e)}',
        cause: e,
      );
    } finally {
      client.close();
    }
  }

  /// Updates specific cells in [source.worksheetName] using a single
  /// batchUpdate API call.
  ///
  /// [updates] maps A1-notation ranges (e.g., `'Sheet1'!B5`) to new values.
  /// Only the specified cells are overwritten — all other columns and rows
  /// in the worksheet are left untouched, preserving existing formatting.
  ///
  /// Uses `USER_ENTERED` input so Google Sheets applies its own parsing
  /// (dates, numbers, currency) the same way a human would type the value.
  Future<void> updateCells({
    required GoogleSheetsSource source,
    required Map<String, String> updates,
  }) async {
    if (updates.isEmpty) return;

    _requireSignedIn();

    final spreadsheetId = _extractSpreadsheetId(source.spreadsheetUrl);
    if (spreadsheetId == null) {
      throw const GoogleSheetsException('Invalid spreadsheet URL.');
    }

    final client = await _googleSignIn.authenticatedClient();
    if (client == null) {
      throw const GoogleSheetsException(
        'Authentication expired. Please sign out and sign in again.',
      );
    }

    try {
      final api = SheetsApi(client);

      final data = updates.entries
          .map((e) => ValueRange(range: e.key, values: [
                [e.value]
              ]))
          .toList();

      await api.spreadsheets.values.batchUpdate(
        BatchUpdateValuesRequest(
          // USER_ENTERED: Sheets parses values as if a human typed them,
          // applying date/number formatting automatically.
          valueInputOption: 'USER_ENTERED',
          data: data,
        ),
        spreadsheetId,
      );
    } on GoogleSheetsException {
      rethrow;
    } on DetailedApiRequestError catch (e) {
      throw _mapApiError(e);
    } catch (e) {
      if (_isNetworkError(e)) {
        throw const GoogleSheetsException(
          'Network error. Check your internet connection and try again.',
        );
      }
      throw GoogleSheetsException(
        'Failed to update cells: ${_friendlyError(e)}',
        cause: e,
      );
    } finally {
      client.close();
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────────

  void _requireSignedIn() {
    if (!isSignedIn) {
      throw const GoogleSheetsException(
        'Please sign in with your Google account first.',
      );
    }
  }

  /// Extracts the spreadsheet ID from a Google Sheets URL.
  ///
  /// Handles both `/edit` and bare `/d/{ID}` URL formats.
  static String? _extractSpreadsheetId(String url) {
    final match = RegExp(
      r'https://docs\.google\.com/spreadsheets/d/([a-zA-Z0-9_-]+)',
    ).firstMatch(url.trim());
    return match?.group(1);
  }

  /// Converts a column letter string (e.g., 'A', 'B', 'AA') to a 0-based
  /// column index using base-26 arithmetic.
  ///
  /// 'A' → 0, 'B' → 1, 'Z' → 25, 'AA' → 26, 'AB' → 27.
  static int _columnLetterToIndex(String letter) {
    letter = letter.toUpperCase().trim();
    var result = 0;
    for (final codeUnit in letter.codeUnits) {
      result = result * 26 + (codeUnit - 65 /* 'A' */ + 1);
    }
    return result - 1;
  }

  /// Maps raw Sheets rows into [ContactField] keyed maps.
  ///
  /// Rows that contain no name and no phone number value are dropped — they
  /// are assumed to be spacer or section-divider rows in the spreadsheet.
  static List<Map<ContactField, String>> _mapRowsToFields(
    List<List<Object?>> rows,
    Map<ContactField, String> columnMapping,
  ) {
    final result = <Map<ContactField, String>>[];

    for (final row in rows) {
      final mapped = <ContactField, String>{};

      for (final entry in columnMapping.entries) {
        final idx = _columnLetterToIndex(entry.value);
        if (idx < row.length) {
          final cell = row[idx]?.toString().trim() ?? '';
          if (cell.isNotEmpty) {
            mapped[entry.key] = cell;
          }
        }
      }

      // Skip rows with no usable identity data.
      if (mapped.containsKey(ContactField.name) ||
          mapped.containsKey(ContactField.phoneNumber)) {
        result.add(mapped);
      }
    }

    return result;
  }

  /// Converts a [DetailedApiRequestError] into a user-friendly [GoogleSheetsException].
  static GoogleSheetsException _mapApiError(DetailedApiRequestError e) {
    switch (e.status) {
      case 400:
        return GoogleSheetsException(
          'Invalid request. Check your spreadsheet URL and worksheet name.',
          cause: e,
        );
      case 403:
        return const GoogleSheetsException(
          'Access denied. Make sure the spreadsheet is shared with your '
          'signed-in Google account.',
        );
      case 404:
        return const GoogleSheetsException(
          'Spreadsheet not found. Please check the URL.',
        );
      case 429:
        return const GoogleSheetsException(
          'Too many requests. Please wait a moment and try again.',
        );
      default:
        return GoogleSheetsException(
          'Google Sheets error (${e.status}): ${e.message ?? e.toString()}',
          cause: e,
        );
    }
  }

  static bool _isNetworkError(Object e) {
    final msg = e.toString();
    return msg.contains('SocketException') ||
        msg.contains('Failed host lookup') ||
        msg.contains('Connection refused') ||
        msg.contains('Network is unreachable');
  }

  static String _friendlyError(Object e) {
    final msg = e.toString();
    // Trim verbose stack trace noise from some error types.
    return msg.length > 200 ? '${msg.substring(0, 200)}…' : msg;
  }
}
