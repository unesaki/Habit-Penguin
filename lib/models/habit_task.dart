import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

/// Hive-backed representation of a single habit task.
class HabitTask extends HiveObject {
  HabitTask({
    required this.name,
    required this.iconCodePoint,
    this.reminderEnabled = false,
  });

  String name;
  int iconCodePoint;
  bool reminderEnabled;

  IconData get iconData => IconData(iconCodePoint, fontFamily: 'MaterialIcons');

  HabitTask copyWith({
    String? name,
    int? iconCodePoint,
    bool? reminderEnabled,
  }) {
    return HabitTask(
      name: name ?? this.name,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    );
  }
}

class HabitTaskAdapter extends TypeAdapter<HabitTask> {
  @override
  final int typeId = 0;

  @override
  HabitTask read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < fieldCount; i++) {
      final key = reader.readByte();
      fields[key] = reader.read();
    }
    final storedReminder = fields[2];
    return HabitTask(
      name: fields[0] as String,
      iconCodePoint: fields[1] as int,
      reminderEnabled: storedReminder is bool ? storedReminder : false,
    );
  }

  @override
  void write(BinaryWriter writer, HabitTask obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.iconCodePoint)
      ..writeByte(2)
      ..write(obj.reminderEnabled);
  }
}
