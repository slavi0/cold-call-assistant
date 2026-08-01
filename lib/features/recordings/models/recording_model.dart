import 'package:hive/hive.dart';
import 'transcript_status.dart';

part 'recording_model.g.dart';

/// Represents an audio recording linked to a [CallModel].
///
/// Design notes vs. original proposal:
/// - [callId] added — explicit back-reference; needed when loading a recording
///   independently (e.g., the transcription service only has the recording ID).
/// - [mp3File] renamed to [filePath] — the file format depends on the device
///   (iOS records .m4a, Android may record .aac). The model is format-agnostic.
///   [filePath] is the absolute local path on device returned by path_provider.
/// - [duration] kept on Recording (not only on Call) — the recording may start
///   after the call begins (user taps record mid-call), so its duration can
///   differ from the call's duration.
/// - [transcript] kept nullable — explicitly [String?] since it may not yet exist.
/// - [transcriptStatus] added — distinguishes "never transcribed" from
///   "transcription in progress" from "transcription failed". Without this,
///   the UI has no clean way to show AI processing state.
/// - [transcribedAt] added — lets the UI show "transcribed 2h ago" and provides
///   an audit timestamp for future sync.
@HiveType(typeId: 2)
class RecordingModel extends HiveObject {
  RecordingModel({
    required this.id,
    required this.callId,
    required this.startTime,
    required this.durationSeconds,
    required this.filePath,
    this.transcript,
    this.transcriptStatus = TranscriptStatus.none,
    this.transcribedAt,
  });

  @HiveField(0)
  final String id;

  /// Foreign key to the owning [CallModel].
  @HiveField(1)
  final String callId;

  @HiveField(2)
  final DateTime startTime;

  /// Length of the audio in seconds.
  @HiveField(3)
  final int durationSeconds;

  /// Absolute local file path to the audio file on this device.
  /// Resolved via path_provider at import/record time.
  /// Format is platform-dependent and intentionally not encoded in this field.
  @HiveField(4)
  final String filePath;

  /// The AI-generated transcript text. Null until transcription completes.
  @HiveField(5)
  String? transcript;

  @HiveField(6)
  TranscriptStatus transcriptStatus;

  /// When transcription finished. Used for display ("transcribed 2h ago")
  /// and future Supabase sync ordering.
  @HiveField(7)
  DateTime? transcribedAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'call_id': callId,
      'start_time': startTime.toIso8601String(),
      'duration_seconds': durationSeconds,
      'file_path': filePath,
      'transcript': transcript,
      'transcript_status': transcriptStatus.name,
      'transcribed_at': transcribedAt?.toIso8601String(),
    };
  }
}
