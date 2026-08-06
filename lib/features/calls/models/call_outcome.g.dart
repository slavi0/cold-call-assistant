// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'call_outcome.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CallOutcomeAdapter extends TypeAdapter<CallOutcome> {
  @override
  final int typeId = 12;

  @override
  CallOutcome read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return CallOutcome.completed;
      case 1:
        return CallOutcome.noAnswer;
      case 2:
        return CallOutcome.leftVoicemail;
      case 3:
        return CallOutcome.busy;
      case 4:
        return CallOutcome.failed;
      default:
        return CallOutcome.completed;
    }
  }

  @override
  void write(BinaryWriter writer, CallOutcome obj) {
    switch (obj) {
      case CallOutcome.completed:
        writer.writeByte(0);
        break;
      case CallOutcome.noAnswer:
        writer.writeByte(1);
        break;
      case CallOutcome.leftVoicemail:
        writer.writeByte(2);
        break;
      case CallOutcome.busy:
        writer.writeByte(3);
        break;
      case CallOutcome.failed:
        writer.writeByte(4);
        break;
    }
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
