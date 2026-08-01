/// Tracks the lifecycle of AI transcription for a recording.
///
/// Stored explicitly rather than derived from [RecordingModel.transcript]
/// being null/non-null so that the UI can distinguish between
/// "never requested" and "requested but in progress".
enum TranscriptStatus {
  /// No transcription has been requested.
  none,

  /// Transcription has been requested and is in progress.
  pending,

  /// Transcription completed successfully.
  completed,

  /// Transcription was attempted but failed.
  failed,
}
