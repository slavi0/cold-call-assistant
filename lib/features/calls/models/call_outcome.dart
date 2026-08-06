import 'package:hive/hive.dart';

part 'call_outcome.g.dart';

/// The result of a call attempt.
///
/// Stored on every Call so that providers and views can filter
/// and aggregate outcomes (e.g. "how many calls went to voicemail this week")
/// without re-processing raw call data.
///
/// Never reorder or remove values — stored by @HiveField index.
@HiveType(typeId: 12)
enum CallOutcome {
  /// The call connected and a conversation happened.
  @HiveField(0)
  completed,

  /// The phone rang but nobody answered.
  @HiveField(1)
  noAnswer,

  /// A voicemail was left.
  @HiveField(2)
  leftVoicemail,

  /// The line was busy.
  @HiveField(3)
  busy,

  /// The call failed due to a technical error (bad number, network issue, etc.).
  @HiveField(4)
  failed,
}
