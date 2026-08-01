/// The result of a call attempt.
///
/// Stored on every Call so that providers and views can filter
/// and aggregate outcomes (e.g. "how many calls went to voicemail this week")
/// without re-processing raw call data.
enum CallOutcome {
  /// The call connected and a conversation happened.
  completed,

  /// The phone rang but nobody answered.
  noAnswer,

  /// A voicemail was left.
  leftVoicemail,

  /// The line was busy.
  busy,

  /// The call failed due to a technical error (bad number, network issue, etc.).
  failed,
}
