// GENERATED CODE — DO NOT EDIT BY HAND
// Hive type adapter for ContactModel.
// TypeId: 0

part of 'contact_model.dart';

class ContactModelAdapter extends TypeAdapter<ContactModel> {
  @override
  final int typeId = 0;

  @override
  ContactModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ContactModel(
      id: fields[0] as String,
      name: fields[1] as String,
      company: fields[2] as String?,
      phoneNumber: fields[3] as String?,
      email: fields[4] as String?,
      notes: fields[5] as String?,
      status: fields[6] as ContactStatus,
      createdAt: fields[7] as DateTime,
      updatedAt: fields[8] as DateTime,
      importedFromTableId: fields[9] as String?,
      // field[10] may be absent in records written before schema version 2.
      lastCalledAt: fields[10] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, ContactModel obj) {
    writer
      ..writeByte(11) // total number of fields
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.company)
      ..writeByte(3)
      ..write(obj.phoneNumber)
      ..writeByte(4)
      ..write(obj.email)
      ..writeByte(5)
      ..write(obj.notes)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.importedFromTableId)
      ..writeByte(10)
      ..write(obj.lastCalledAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// Hive type adapter for ContactStatus enum.
class ContactStatusAdapter extends TypeAdapter<ContactStatus> {
  @override
  final int typeId = 10;

  @override
  ContactStatus read(BinaryReader reader) {
    return ContactStatus.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, ContactStatus obj) {
    writer.writeByte(obj.index);
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
