import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/recording_model.dart';
import '../models/transcript_status.dart';
import '../../../core/exceptions/app_exception.dart';

/// Handles all persistence operations for [RecordingModel].
///
/// Supabase migration path:
/// Replace Hive calls with Supabase client calls. Method signatures stay the same.
class RecordingService {
  static const _boxName = 'recordings';
  final _uuid = const Uuid();

  Box<RecordingModel> get _box => Hive.box<RecordingModel>(_boxName);

  static Future<void> openBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<RecordingModel>(_boxName);
    }
  }

  /// Returns the recording for a given [callId], or null if none exists.
  RecordingModel? getByCallId(String callId) {
    return _box.values.cast<RecordingModel?>().firstWhere(
          (r) => r?.callId == callId,
          orElse: () => null,
        );
  }

  /// Returns a single recording by [id], or null if not found.
  RecordingModel? getById(String id) {
    return _box.values.cast<RecordingModel?>().firstWhere(
          (r) => r?.id == id,
          orElse: () => null,
        );
  }

  /// Returns all recordings that are awaiting transcription.
  List<RecordingModel> getPendingTranscriptions() {
    return _box.values
        .where((r) => r.transcriptStatus == TranscriptStatus.pending)
        .toList();
  }

  /// Creates and persists a new recording linked to a call.
  Future<RecordingModel> create({
    required String callId,
    required DateTime startTime,
    required int durationSeconds,
    required String filePath,
  }) async {
    try {
      final recording = RecordingModel(
        id: _uuid.v4(),
        callId: callId,
        startTime: startTime,
        durationSeconds: durationSeconds,
        filePath: filePath,
      );
      await _box.put(recording.id, recording);
      return recording;
    } catch (e) {
      throw StorageException('Failed to save recording.', cause: e);
    }
  }

  /// Saves a completed transcript onto an existing recording.
  ///
  /// Sets [transcriptStatus] to [TranscriptStatus.completed] and records
  /// the [transcribedAt] timestamp.
  Future<RecordingModel> saveTranscript({
    required String recordingId,
    required String transcript,
  }) async {
    final recording = getById(recordingId);
    if (recording == null) {
      throw const NotFoundException('Recording not found.');
    }
    try {
      recording.transcript = transcript;
      recording.transcriptStatus = TranscriptStatus.completed;
      recording.transcribedAt = DateTime.now();
      await recording.save(); // HiveObject convenience method
      return recording;
    } catch (e) {
      throw StorageException('Failed to save transcript.', cause: e);
    }
  }

  /// Marks a recording's transcription as failed.
  Future<void> markTranscriptFailed(String recordingId) async {
    final recording = getById(recordingId);
    if (recording == null) {
      throw const NotFoundException('Recording not found.');
    }
    try {
      recording.transcriptStatus = TranscriptStatus.failed;
      await recording.save();
    } catch (e) {
      throw StorageException('Failed to update transcript status.', cause: e);
    }
  }

  /// Deletes a recording by [id]. No-op if it does not exist.
  Future<void> delete(String id) async {
    try {
      await _box.delete(id);
    } catch (e) {
      throw StorageException('Failed to delete recording.', cause: e);
    }
  }
}
