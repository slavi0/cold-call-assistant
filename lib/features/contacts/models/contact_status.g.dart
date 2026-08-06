// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contact_status.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ContactStatusAdapter extends TypeAdapter<ContactStatus> {
  @override
  final int typeId = 10;

  @override
  ContactStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ContactStatus.interested;
      case 1:
        return ContactStatus.notInterested;
      case 2:
        return ContactStatus.actionRequired;
      case 3:
        return ContactStatus.callLater;
      case 4:
        return ContactStatus.didntPickUp;
      case 5:
        return ContactStatus.doesntExist;
      default:
        return ContactStatus.interested;
    }
  }

  @override
  void write(BinaryWriter writer, ContactStatus obj) {
    switch (obj) {
      case ContactStatus.interested:
        writer.writeByte(0);
        break;
      case ContactStatus.notInterested:
        writer.writeByte(1);
        break;
      case ContactStatus.actionRequired:
        writer.writeByte(2);
        break;
      case ContactStatus.callLater:
        writer.writeByte(3);
        break;
      case ContactStatus.didntPickUp:
        writer.writeByte(4);
        break;
      case ContactStatus.doesntExist:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
