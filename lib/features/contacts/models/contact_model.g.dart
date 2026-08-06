// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contact_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

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
      createdAt: fields[7] as DateTime,
      updatedAt: fields[8] as DateTime,
      company: fields[2] as String?,
      phoneNumber: fields[3] as String?,
      email: fields[4] as String?,
      notes: fields[5] as String?,
      status: fields[6] as ContactStatus,
      importedFromTableId: fields[9] as String?,
      lastCalledAt: fields[10] as DateTime?,
      syncStatus: fields[11] as SyncStatus,
      syncRetryCount: fields[12] as int,
      rawSourcePhoneNumber: fields[13] as String?,
      phoneCountry: fields[14] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ContactModel obj) {
    writer
      ..writeByte(15)
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
      ..write(obj.lastCalledAt)
      ..writeByte(11)
      ..write(obj.syncStatus)
      ..writeByte(12)
      ..write(obj.syncRetryCount)
      ..writeByte(13)
      ..write(obj.rawSourcePhoneNumber)
      ..writeByte(14)
      ..write(obj.phoneCountry);
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
