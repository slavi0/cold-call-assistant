// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'call_direction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CallDirectionAdapter extends TypeAdapter<CallDirection> {
  @override
  final int typeId = 11;

  @override
  CallDirection read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return CallDirection.outgoing;
      case 1:
        return CallDirection.incoming;
      default:
        return CallDirection.outgoing;
    }
  }

  @override
  void write(BinaryWriter writer, CallDirection obj) {
    switch (obj) {
      case CallDirection.outgoing:
        writer.writeByte(0);
        break;
      case CallDirection.incoming:
        writer.writeByte(1);
        break;
    }
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
