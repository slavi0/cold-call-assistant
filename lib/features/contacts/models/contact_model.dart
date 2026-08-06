import 'package:hive/hive.dart';
import 'contact_status.dart';
import 'sync_status.dart';

part 'contact_model.g.dart';

/// Represents a sales prospect imported from an Excel spreadsheet.
///
/// Design notes vs. original proposal:
/// - [recordings] was removed — recordings belong to individual [CallModel]s,
///   not to the contact. Access them via contact.calls[n].recording.
/// - [company] added — essential CRM field; cold calls are usually to businesses.
/// - [status] added — tracks post-call outcome set during post-call review.
/// - [createdAt]/[updatedAt] added — required for sorting imports and for
///   future Supabase sync (server needs to know which record is newer).
/// - [lastCalledAt] added — records when the contact was last reached;
///   set automatically when the post-call review is submitted.
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
    this.status = ContactStatus.callLater,
    this.importedFromTableId,
    this.lastCalledAt,
    this.syncStatus = SyncStatus.noSource,
    this.syncRetryCount = 0,
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

  /// Free-form notes about this contact set during post-call review.
  /// Call-specific notes live on [CallModel.notes] instead.
  @HiveField(5)
  String? notes;

  /// Post-call status set by the salesperson after each call attempt.
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

  /// The timestamp of the last call placed to this contact.
  ///
  /// Set automatically when the post-call review is submitted. Null if this
  /// contact has never been called. Useful for CRM sorting and for displaying
  /// "last called" context in the UI without reading every [CallModel].
  @HiveField(10)
  DateTime? lastCalledAt;

  // ── Sync state ─────────────────────────────────────────────────────────────
  //
  // These two fields are appended after all original fields so that existing
  // Hive records (written before Phase 3) can still be read without a
  // migration. Hive's generated reader maps fields by their @HiveField index,
  // not by position, so missing fields receive their constructor defaults.

  /// Whether this contact's local state has been pushed to its origin source.
  ///
  /// Set to [SyncStatus.synced] immediately after import (the contact just
  /// came from the sheet). Changed to [SyncStatus.pendingSync] whenever
  /// [ContactProvider.updateContact] is called. [SyncProvider] transitions
  /// through [SyncStatus.syncing] → [SyncStatus.synced] or [SyncStatus.failed].
  @HiveField(11)
  SyncStatus syncStatus;

  /// Number of consecutive sync failures for this contact.
  ///
  /// Reset to 0 when:
  /// - A sync succeeds ([SyncStatus.synced]).
  /// - The user edits the contact again (re-edit = fresh start).
  ///
  /// Used by [SyncProvider] to determine the next backoff delay and whether
  /// the maximum retry limit has been reached.
  @HiveField(12)
  int syncRetryCount;

  /// Creates a copy of this model with updated fields.
  /// Used by providers to update state immutably.
  ///
  /// Note: passing null for a nullable field keeps the existing value.
  /// To clear a nullable field, pass an explicit empty/sentinel value.
  ContactModel copyWith({
    String? name,
    String? company,
    String? phoneNumber,
    String? email,
    String? notes,
    ContactStatus? status,
    DateTime? updatedAt,
    String? importedFromTableId,
    DateTime? lastCalledAt,
    SyncStatus? syncStatus,
    int? syncRetryCount,
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
      lastCalledAt: lastCalledAt ?? this.lastCalledAt,
      syncStatus: syncStatus ?? this.syncStatus,
      syncRetryCount: syncRetryCount ?? this.syncRetryCount,
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
      'last_called_at': lastCalledAt?.toIso8601String(),
      'sync_status': syncStatus.name,
      'sync_retry_count': syncRetryCount,
    };
  }
}
