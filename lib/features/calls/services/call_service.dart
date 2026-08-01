import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/call_model.dart';
import '../models/call_direction.dart';
import '../models/call_outcome.dart';
import '../../../core/exceptions/app_exception.dart';

/// Handles all persistence operations for [CallModel].
///
/// Supabase migration path:
/// Replace Hive calls with Supabase client calls. Method signatures stay the same.
class CallService {
  static const _boxName = 'calls';
  final _uuid = const Uuid();

  Box<CallModel> get _box => Hive.box<CallModel>(_boxName);

  static Future<void> openBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<CallModel>(_boxName);
    }
  }

  /// Returns all calls for a given contact, ordered by [startTime] descending.
  List<CallModel> getByContactId(String contactId) {
    final calls = _box.values.where((c) => c.contactId == contactId).toList();
    calls.sort((a, b) => b.startTime.compareTo(a.startTime));
    return calls;
  }

  /// Returns a single call by [id], or null if not found.
  CallModel? getById(String id) {
    return _box.values.cast<CallModel?>().firstWhere(
          (c) => c?.id == id,
          orElse: () => null,
        );
  }

  /// Returns the call that references a given [recordingId], or null.
  CallModel? getByRecordingId(String recordingId) {
    return _box.values.cast<CallModel?>().firstWhere(
          (c) => c?.recordingId == recordingId,
          orElse: () => null,
        );
  }

  /// Creates and persists a new call.
  Future<CallModel> create({
    required String contactId,
    required DateTime startTime,
    required CallDirection direction,
    required CallOutcome outcome,
    DateTime? endTime,
    String? notes,
    String? recordingId,
  }) async {
    try {
      final call = CallModel(
        id: _uuid.v4(),
        contactId: contactId,
        startTime: startTime,
        direction: direction,
        outcome: outcome,
        endTime: endTime,
        notes: notes,
        recordingId: recordingId,
      );
      await _box.put(call.id, call);
      return call;
    } catch (e) {
      throw StorageException('Failed to save call.', cause: e);
    }
  }

  /// Updates an existing call. Throws [NotFoundException] if not found.
  Future<CallModel> update(CallModel updated) async {
    if (!_box.containsKey(updated.id)) {
      throw const NotFoundException('Call not found.');
    }
    try {
      await _box.put(updated.id, updated);
      return updated;
    } catch (e) {
      throw StorageException('Failed to update call.', cause: e);
    }
  }

  /// Deletes a call by [id]. No-op if it does not exist.
  Future<void> delete(String id) async {
    try {
      await _box.delete(id);
    } catch (e) {
      throw StorageException('Failed to delete call.', cause: e);
    }
  }

  /// Deletes all calls belonging to a contact.
  /// Used when a contact is deleted — avoids orphaned call records.
  Future<void> deleteByContactId(String contactId) async {
    try {
      final keys = _box.values
          .where((c) => c.contactId == contactId)
          .map((c) => c.id)
          .toList();
      await _box.deleteAll(keys);
    } catch (e) {
      throw StorageException('Failed to delete calls for contact.', cause: e);
    }
  }
}
