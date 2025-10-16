// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'advanced_notification_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AdvancedNotificationSettingsAdapter
    extends TypeAdapter<AdvancedNotificationSettings> {
  @override
  final int typeId = 4;

  @override
  AdvancedNotificationSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AdvancedNotificationSettings(
      taskId: fields[0] as int,
      reminderTimes: (fields[1] as List?)?.cast<TimeOfDay>(),
      enabledWeekdays: (fields[2] as List?)?.cast<int>(),
      customSound: fields[3] as String?,
      vibrationPattern: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AdvancedNotificationSettings obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.taskId)
      ..writeByte(1)
      ..write(obj.reminderTimes)
      ..writeByte(2)
      ..write(obj.enabledWeekdays)
      ..writeByte(3)
      ..write(obj.customSound)
      ..writeByte(4)
      ..write(obj.vibrationPattern);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdvancedNotificationSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
