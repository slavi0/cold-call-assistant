// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'call_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

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
      direction: fields[4] as CallDirection,
      outcome: fields[5] as CallOutcome,
      endTime: fields[3] as DateTime?,
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
