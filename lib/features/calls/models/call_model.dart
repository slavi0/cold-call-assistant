import 'package:hive/hive.dart';
import 'call_direction.dart';
import 'call_outcome.dart';

part 'call_model.g.dart';

/// Represents a single phone call made to or received from a [ContactModel].
///
/// Design notes vs. original proposal:
/// - [contactId] added — a Call without a reference to its Contact is an orphan.
///   Stored as a String ID rather than an embedded object to avoid Hive nesting
///   complexity and to mirror how a Supabase foreign key would work.
/// - [outcome] added — core CRM value; useless without knowing what happened.
/// - [direction] added — distinguishes outgoing cold calls from inbound callbacks.
/// - [notes] added — salespeople take notes after each call; these are
///   call-specific, not contact-level.
/// - [endTime] replaces [duration] — duration is computed from startTime/endTime.
///   Storing a raw duration int risks stale data if the app crashes mid-call.
/// - [recordingId] added as nullable String — the recording is a separate entity
///   stored in its own Hive box; the Call just holds the reference.
@HiveType(typeId: 1)
class CallModel extends HiveObject {
  CallModel({
    required this.id,
    required this.contactId,
    required this.startTime,
    required this.direction,
    required this.outcome,
    this.endTime,
    this.notes,
    this.recordingId,
  });

  @HiveField(0)
  final String id;

  /// Foreign key to the owning [ContactModel].
  @HiveField(1)
  final String contactId;

  @HiveField(2)
  final DateTime startTime;

  /// Null if the call is still in progress or was never properly ended.
  @HiveField(3)
  DateTime? endTime;

  @HiveField(4)
  final CallDirection direction;

  @HiveField(5)
  CallOutcome outcome;

  /// Call-specific notes (e.g. "prospect interested, call back Thursday").
  @HiveField(6)
  String? notes;

  /// ID of the associated [RecordingModel], if a recording was made.
  /// Null means no recording exists for this call.
  @HiveField(7)
  String? recordingId;

  /// Computed duration. Null if the call has no [endTime].
  Duration? get duration => endTime?.difference(startTime);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'contact_id': contactId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'direction': direction.name,
      'outcome': outcome.name,
      'notes': notes,
      'recording_id': recordingId,
    };
  }
}
