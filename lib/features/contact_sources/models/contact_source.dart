import 'dart:convert';
import 'contact_field.dart';

/// The base sealed class for all contact source configurations.
///
/// A contact source represents the configuration required to import contacts
/// from an external system (Google Sheets, HubSpot, CSV, etc.). This phase
/// stores configuration only — the actual import logic lives in a separate
/// service that will be added in Phase 2.
///
/// ## Why sealed?
/// Using a sealed class enforces exhaustive handling at every switch site.
/// When a new provider is added (e.g., [HubSpotSource]), the Dart compiler
/// flags every switch as incomplete until the new case is handled. This
/// makes adding providers safe and discoverable.
///
/// ## How to add a new provider
/// 1. Create `final class MySource extends ContactSource { ... }` in this file.
/// 2. Add a `case MySource.typeKey` to [ContactSource.fromJson].
/// 3. Handle the new subtype wherever a `switch (source)` exists —
///    the compiler will list every site that needs updating.
/// 4. No other files need to change.
sealed class ContactSource {
  const ContactSource({
    required this.id,
    required this.displayName,
  });

  /// RFC-4122 UUID. Uniquely identifies this source configuration.
  /// Multiple Google Sheets sources can co-exist if a user has several
  /// spreadsheets (e.g., one per campaign).
  final String id;

  /// User-facing label for this source (e.g. "Q3 Leads – Google Sheets").
  final String displayName;

  /// The type discriminator written into JSON during serialization.
  /// Must match the `case` in [ContactSource.fromJson].
  String get type;

  /// Serializes this configuration to a JSON-compatible map.
  Map<String, dynamic> toJson();

  /// Serializes to a raw JSON string for Hive persistence.
  String toJsonString() => jsonEncode(toJson());

  /// Deserializes a [ContactSource] from a JSON map.
  ///
  /// Uses the [type] discriminator field to select the correct subtype.
  /// Throws [FormatException] if the type is not recognized — this protects
  /// against reading stale data after a source type is removed.
  factory ContactSource.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    return switch (type) {
      GoogleSheetsSource.typeKey => GoogleSheetsSource._fromJson(json),
      _ => throw FormatException('Unknown contact source type: $type'),
    };
  }

  /// Convenience wrapper: deserializes from a raw JSON string.
  factory ContactSource.fromJsonString(String jsonString) {
    return ContactSource.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// A contact source backed by a Google Sheets spreadsheet.
///
/// [spreadsheetUrl] and [worksheetName] identify the data location.
/// [columnMapping] maps each [ContactField] to a spreadsheet column letter
/// (e.g., 'A', 'B'). Fields without a mapping entry are skipped during import.
///
/// Phase 2 will add a [GoogleSheetsService] that uses these values together
/// with the Sheets API to fetch and map rows into [ContactModel] objects.
final class GoogleSheetsSource extends ContactSource {
  const GoogleSheetsSource({
    required super.id,
    required super.displayName,
    required this.spreadsheetUrl,
    required this.worksheetName,
    required this.columnMapping,
    this.hasHeaderRow = true,
  });

  /// The JSON type key written to and read from persisted data.
  static const typeKey = 'google_sheets';

  /// Full URL of the Google Sheets document.
  /// Example: https://docs.google.com/spreadsheets/d/SPREADSHEET_ID/edit
  final String spreadsheetUrl;

  /// The name of the worksheet tab to read from (e.g., 'Sheet1', 'Leads').
  final String worksheetName;

  /// Whether the first row of [worksheetName] is a header row.
  ///
  /// When true, [GoogleSheetsIntegration.readRows] skips row 1 during import.
  /// Defaults to true for backward compatibility with pre-Phase-2 stored configs.
  final bool hasHeaderRow;

  /// Maps each [ContactField] to a spreadsheet column identifier (e.g., 'A').
  ///
  /// Only fields present in this map are imported. Required fields
  /// ([ContactField.isRequired]) should always have entries.
  final Map<ContactField, String> columnMapping;

  @override
  String get type => typeKey;

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'id': id,
      'displayName': displayName,
      'spreadsheetUrl': spreadsheetUrl,
      'worksheetName': worksheetName,
      'hasHeaderRow': hasHeaderRow,
      // Serialize enum keys by their .name string so the JSON is readable
      // and forward-compatible with new enum values.
      'columnMapping': columnMapping.map(
        (field, column) => MapEntry(field.name, column),
      ),
    };
  }

  factory GoogleSheetsSource._fromJson(Map<String, dynamic> json) {
    final rawMapping =
        (json['columnMapping'] as Map<String, dynamic>?) ?? const {};

    // Deserialize only recognized field names; unknown entries are silently
    // skipped for forward-compatibility when fields are removed.
    final columnMapping = <ContactField, String>{};
    for (final entry in rawMapping.entries) {
      final field = ContactField.values.cast<ContactField?>().firstWhere(
            (f) => f?.name == entry.key,
            orElse: () => null,
          );
      if (field != null && entry.value is String) {
        columnMapping[field] = entry.value as String;
      }
    }

    return GoogleSheetsSource(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      spreadsheetUrl: json['spreadsheetUrl'] as String,
      worksheetName: json['worksheetName'] as String,
      // Default true for backward compatibility with pre-Phase-2 stored configs.
      hasHeaderRow: json['hasHeaderRow'] as bool? ?? true,
      columnMapping: columnMapping,
    );
  }

  /// Returns a copy of this source with the given fields replaced.
  GoogleSheetsSource copyWith({
    String? displayName,
    String? spreadsheetUrl,
    String? worksheetName,
    Map<ContactField, String>? columnMapping,
    bool? hasHeaderRow,
  }) {
    return GoogleSheetsSource(
      id: id,
      displayName: displayName ?? this.displayName,
      spreadsheetUrl: spreadsheetUrl ?? this.spreadsheetUrl,
      worksheetName: worksheetName ?? this.worksheetName,
      columnMapping: columnMapping ?? Map.from(this.columnMapping),
      hasHeaderRow: hasHeaderRow ?? this.hasHeaderRow,
    );
  }
}
