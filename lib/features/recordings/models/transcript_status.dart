import 'package:hive/hive.dart';

part 'transcript_status.g.dart';

/// Tracks the lifecycle of AI transcription for a recording.
///
/// Stored explicitly rather than derived from [RecordingModel.transcript]
/// being null/non-null so that the UI can distinguish between
/// "never requested" and "requested but in progress".
///
/// Never reorder or remove values — stored by @HiveField index.
@HiveType(typeId: 13)
enum TranscriptStatus {
  /// No transcription has been requested.
  @HiveField(0)
  none,

  /// Transcription has been requested and is in progress.
  @HiveField(1)
  pending,

  /// Transcription completed successfully.
  @HiveField(2)
  completed,

  /// Transcription was attempted but failed.
  @HiveField(3)
  failed,
}
