// GENERATED CODE — DO NOT EDIT BY HAND
// Hive type adapter for CallModel.
// TypeId: 1

part of 'call_model.dart';

class CallModelAdapter extends TypeAdapter<CallModel> {
  @override
  final int typeId = 1;

  @override
  CallModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CallModel(
      id: fields[0] as String,
      contactId: fields[1] as String,
      startTime: fields[2] as DateTime,
      endTime: fields[3] as DateTime?,
      direction: fields[4] as CallDirection,
      outcome: fields[5] as CallOutcome,
      notes: fields[6] as String?,
      recordingId: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CallModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.contactId)
      ..writeByte(2)
      ..write(obj.startTime)
      ..writeByte(3)
      ..write(obj.endTime)
      ..writeByte(4)
      ..write(obj.direction)
      ..writeByte(5)
      ..write(obj.outcome)
      ..writeByte(6)
      ..write(obj.notes)
      ..writeByte(7)
      ..write(obj.recordingId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CallModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// Hive type adapter for CallDirection enum.
class CallDirectionAdapter extends TypeAdapter<CallDirection> {
  @override
  final int typeId = 11;

  @override
  CallDirection read(BinaryReader reader) {
    return CallDirection.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, CallDirection obj) {
    writer.writeByte(obj.index);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CallDirectionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// Hive type adapter for CallOutcome enum.
class CallOutcomeAdapter extends TypeAdapter<CallOutcome> {
  @override
  final int typeId = 12;

  @override
  CallOutcome read(BinaryReader reader) {
    return CallOutcome.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, CallOutcome obj) {
    writer.writeByte(obj.index);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CallOutcomeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
