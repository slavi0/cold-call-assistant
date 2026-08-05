/// Represents a mappable property on [ContactModel].
///
/// Every value here corresponds to a field that can be populated from an
/// external contact source (e.g., a Google Sheets column). The enum is the
/// single source of truth for which fields are importable.
///
/// ## Extensibility
/// The column-mapping UI in [GoogleSheetsConfigScreen] renders dynamically
/// from [ContactField.values], so adding a new field here automatically
/// adds it to the mapping form — no UI changes needed.
enum ContactField {
  name,
  phoneNumber,
  email,
  company,
  notes,
  status,
}

/// Extension providing display labels and metadata for each [ContactField].
extension ContactFieldMeta on ContactField {
  /// Human-readable label shown in the column mapping UI.
  String get displayLabel {
    switch (this) {
      case ContactField.name:
        return 'Name';
      case ContactField.phoneNumber:
        return 'Phone Number';
      case ContactField.email:
        return 'Email';
      case ContactField.company:
        return 'Company';
      case ContactField.notes:
        return 'Notes';
      case ContactField.status:
        return 'Status';
    }
  }

  /// Whether this field must be mapped for an import to be valid.
  ///
  /// Name and phone number are the minimum viable fields for the cold-call
  /// workflow. All other fields are optional enrichments.
  bool get isRequired {
    switch (this) {
      case ContactField.name:
      case ContactField.phoneNumber:
        return true;
      case ContactField.email:
      case ContactField.company:
      case ContactField.notes:
      case ContactField.status:
        return false;
    }
  }
}
