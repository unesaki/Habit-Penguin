import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

/// Hive-backed representation of a single habit task.
class HabitTask extends HiveObject {
  HabitTask({
    required this.name,
    required this.iconCodePoint,
    this.reminderEnabled = false,
    this.difficulty = TaskDifficulty.normal,
    this.scheduledDate,
    this.repeatStart,
    this.repeatEnd,
    this.isCompleted = false,
    this.completedAt,
    this.completionXp,
  });

  String name;
  int iconCodePoint;
  bool reminderEnabled;
  TaskDifficulty difficulty;
  DateTime? scheduledDate;
  DateTime? repeatStart;
  DateTime? repeatEnd;
  bool isCompleted;
  DateTime? completedAt;
  int? completionXp;

  IconData get iconData => IconData(iconCodePoint, fontFamily: 'MaterialIcons');

  bool get isRepeating => repeatStart != null && repeatEnd != null;

  bool isActiveOn(DateTime date) {
    if (isCompleted) {
      return false;
    }
    final dateOnly = DateTime(date.year, date.month, date.day);
    if (isRepeating && repeatStart != null && repeatEnd != null) {
      final start = DateTime(
        repeatStart!.year,
        repeatStart!.month,
        repeatStart!.day,
      );
      final end = DateTime(repeatEnd!.year, repeatEnd!.month, repeatEnd!.day);
      return !dateOnly.isBefore(start) && !dateOnly.isAfter(end);
    }
    if (scheduledDate == null) {
      return true;
    }
    final scheduled = DateTime(
      scheduledDate!.year,
      scheduledDate!.month,
      scheduledDate!.day,
    );
    return scheduled == dateOnly;
  }

  HabitTask copyWith({
    String? name,
    int? iconCodePoint,
    bool? reminderEnabled,
    TaskDifficulty? difficulty,
    DateTime? scheduledDate,
    DateTime? repeatStart,
    DateTime? repeatEnd,
    bool? isRepeating,
    bool? isCompleted,
    DateTime? completedAt,
    int? completionXp,
  }) {
    final shouldRepeat = isRepeating ?? this.isRepeating;
    return HabitTask(
      name: name ?? this.name,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      difficulty: difficulty ?? this.difficulty,
      scheduledDate: shouldRepeat
          ? null
          : (scheduledDate ?? this.scheduledDate),
      repeatStart: shouldRepeat ? (repeatStart ?? this.repeatStart) : null,
      repeatEnd: shouldRepeat ? (repeatEnd ?? this.repeatEnd) : null,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      completionXp: completionXp ?? this.completionXp,
    );
  }
}

enum TaskDifficulty { easy, normal, hard }

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

    DateTime? readDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    final reminderRaw = fields[2];
    final difficultyIndex = fields[3] as int?;

    return HabitTask(
      name: (fields[0] ?? '') as String,
      iconCodePoint: (fields[1] ?? Icons.check_circle.codePoint) as int,
      reminderEnabled: reminderRaw is bool ? reminderRaw : false,
      difficulty: switch (difficultyIndex) {
        0 => TaskDifficulty.easy,
        2 => TaskDifficulty.hard,
        _ => TaskDifficulty.normal,
      },
      scheduledDate: readDate(fields[4]),
      repeatStart: readDate(fields[5]),
      repeatEnd: readDate(fields[6]),
      isCompleted: (fields[7] as bool?) ?? false,
      completedAt: readDate(fields[8]),
      completionXp: (fields[9] as int?) ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, HabitTask obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.iconCodePoint)
      ..writeByte(2)
      ..write(obj.reminderEnabled)
      ..writeByte(3)
      ..write(obj.difficulty.index)
      ..writeByte(4)
      ..write(obj.scheduledDate)
      ..writeByte(5)
      ..write(obj.repeatStart)
      ..writeByte(6)
      ..write(obj.repeatEnd)
      ..writeByte(7)
      ..write(obj.isCompleted)
      ..writeByte(8)
      ..write(obj.completedAt)
      ..writeByte(9)
      ..write(obj.completionXp ?? 0);
  }
}
