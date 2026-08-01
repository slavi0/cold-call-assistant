// GENERATED CODE — DO NOT EDIT BY HAND
// Hive type adapter for ExcelTableModel.
// TypeId: 3

part of 'excel_table_model.dart';

class ExcelTableModelAdapter extends TypeAdapter<ExcelTableModel> {
  @override
  final int typeId = 3;

  @override
  ExcelTableModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExcelTableModel(
      id: fields[0] as String,
      name: fields[1] as String,
      filePath: fields[2] as String?,
      importedAt: fields[3] as DateTime,
      rowCount: fields[4] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, ExcelTableModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.filePath)
      ..writeByte(3)
      ..write(obj.importedAt)
      ..writeByte(4)
      ..write(obj.rowCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExcelTableModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
