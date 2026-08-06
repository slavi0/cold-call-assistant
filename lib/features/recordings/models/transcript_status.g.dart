// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcript_status.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TranscriptStatusAdapter extends TypeAdapter<TranscriptStatus> {
  @override
  final int typeId = 13;

  @override
  TranscriptStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TranscriptStatus.none;
      case 1:
        return TranscriptStatus.pending;
      case 2:
        return TranscriptStatus.completed;
      case 3:
        return TranscriptStatus.failed;
      default:
        return TranscriptStatus.none;
    }
  }

  @override
  void write(BinaryWriter writer, TranscriptStatus obj) {
    switch (obj) {
      case TranscriptStatus.none:
        writer.writeByte(0);
        break;
      case TranscriptStatus.pending:
        writer.writeByte(1);
        break;
      case TranscriptStatus.completed:
        writer.writeByte(2);
        break;
      case TranscriptStatus.failed:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranscriptStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
