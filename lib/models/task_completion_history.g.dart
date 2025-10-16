// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_completion_history.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaskCompletionHistoryAdapter extends TypeAdapter<TaskCompletionHistory> {
  @override
  final int typeId = 1;

  @override
  TaskCompletionHistory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaskCompletionHistory(
      taskKey: fields[0] as int,
      completedAt: fields[1] as DateTime,
      earnedXp: fields[2] as int,
      notes: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TaskCompletionHistory obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.taskKey)
      ..writeByte(1)
      ..write(obj.completedAt)
      ..writeByte(2)
      ..write(obj.earnedXp)
      ..writeByte(3)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskCompletionHistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
