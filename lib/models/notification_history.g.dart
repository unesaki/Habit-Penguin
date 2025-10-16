// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_history.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NotificationHistoryAdapter extends TypeAdapter<NotificationHistory> {
  @override
  final int typeId = 3;

  @override
  NotificationHistory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NotificationHistory(
      taskId: fields[0] as int,
      taskName: fields[1] as String,
      sentAt: fields[2] as DateTime,
      tapped: fields[3] as bool,
      tappedAt: fields[4] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, NotificationHistory obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.taskId)
      ..writeByte(1)
      ..write(obj.taskName)
      ..writeByte(2)
      ..write(obj.sentAt)
      ..writeByte(3)
      ..write(obj.tapped)
      ..writeByte(4)
      ..write(obj.tappedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationHistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
