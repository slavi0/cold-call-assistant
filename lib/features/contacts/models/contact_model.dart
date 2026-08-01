import 'package:hive/hive.dart';
import 'contact_status.dart';

part 'contact_model.g.dart';

/// Represents a sales prospect imported from an Excel spreadsheet.
///
/// Design notes vs. original proposal:
/// - [recordings] was removed — recordings belong to individual [CallModel]s,
///   not to the contact. Access them via contact.calls[n].recording.
/// - [company] added — essential CRM field; cold calls are usually to businesses.
/// - [status] added — enables pipeline tracking (new → contacted → converted).
/// - [createdAt]/[updatedAt] added — required for sorting imports and for
///   future Supabase sync (server needs to know which record is newer).
/// - [importedFromTableId] added — links contact back to its Excel import batch.
@HiveType(typeId: 0)
class ContactModel extends HiveObject {
  ContactModel({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.company,
    this.phoneNumber,
    this.email,
    this.notes,
    this.status = ContactStatus.newContact,
    this.importedFromTableId,
  });

  /// RFC-4122 UUID. Using UUIDs instead of auto-increment ints makes
  /// Supabase migration straightforward — no ID remapping needed.
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  /// The company or organisation this person belongs to.
  /// Optional because individual consumers may be imported without a company.
  @HiveField(2)
  String? company;

  @HiveField(3)
  String? phoneNumber;

  @HiveField(4)
  String? email;

  /// Free-form notes about this contact (overall relationship notes).
  /// Call-specific notes live on [CallModel.notes] instead.
  @HiveField(5)
  String? notes;

  @HiveField(6)
  ContactStatus status;

  @HiveField(7)
  final DateTime createdAt;

  /// Updated every time any field on this contact changes.
  /// Required for conflict resolution when migrating to Supabase.
  @HiveField(8)
  DateTime updatedAt;

  /// The ID of the [ExcelTableModel] this contact was imported from.
  /// Null if the contact was created manually.
  @HiveField(9)
  String? importedFromTableId;

  /// Creates a copy of this model with updated fields.
  /// Used by providers to update state immutably.
  ContactModel copyWith({
    String? name,
    String? company,
    String? phoneNumber,
    String? email,
    String? notes,
    ContactStatus? status,
    DateTime? updatedAt,
    String? importedFromTableId,
  }) {
    return ContactModel(
      id: id,
      name: name ?? this.name,
      company: company ?? this.company,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      importedFromTableId: importedFromTableId ?? this.importedFromTableId,
    );
  }

  /// Serializes to a plain Map for future Supabase upsert calls.
  /// Keeping this in the model means the service only calls [toMap()]
  /// without knowing the internal structure.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'company': company,
      'phone_number': phoneNumber,
      'email': email,
      'notes': notes,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'imported_from_table_id': importedFromTableId,
    };
  }
}
