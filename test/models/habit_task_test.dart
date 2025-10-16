import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_penguin/models/habit_task.dart';

void main() {
  group('HabitTask', () {
    group('isRepeating', () {
      test('returns true when repeat dates are set', () {
        final task = HabitTask(
          name: 'Test Task',
          iconCodePoint: Icons.check.codePoint,
          repeatStart: DateTime(2025, 1, 1),
          repeatEnd: DateTime(2025, 12, 31),
        );

        expect(task.isRepeating, true);
      });

      test('returns false when only scheduledDate is set', () {
        final task = HabitTask(
          name: 'Test Task',
          iconCodePoint: Icons.check.codePoint,
          scheduledDate: DateTime(2025, 1, 15),
        );

        expect(task.isRepeating, false);
      });

      test('returns false when no dates are set', () {
        final task = HabitTask(
          name: 'Test Task',
          iconCodePoint: Icons.check.codePoint,
        );

        expect(task.isRepeating, false);
      });
    });

    group('isActiveOn', () {
      test('repeating task is active within date range', () {
        final task = HabitTask(
          name: 'Test Task',
          iconCodePoint: Icons.check.codePoint,
          repeatStart: DateTime(2025, 1, 1),
          repeatEnd: DateTime(2025, 12, 31),
        );

        expect(task.isActiveOn(DateTime(2025, 6, 15)), true);
      });

      test('repeating task is active on start date', () {
        final task = HabitTask(
          name: 'Test Task',
          iconCodePoint: Icons.check.codePoint,
          repeatStart: DateTime(2025, 1, 1),
          repeatEnd: DateTime(2025, 12, 31),
        );

        expect(task.isActiveOn(DateTime(2025, 1, 1)), true);
      });

      test('repeating task is active on end date', () {
        final task = HabitTask(
          name: 'Test Task',
          iconCodePoint: Icons.check.codePoint,
          repeatStart: DateTime(2025, 1, 1),
          repeatEnd: DateTime(2025, 12, 31),
        );

        expect(task.isActiveOn(DateTime(2025, 12, 31)), true);
      });

      test('repeating task is not active before start date', () {
        final task = HabitTask(
          name: 'Test Task',
          iconCodePoint: Icons.check.codePoint,
          repeatStart: DateTime(2025, 1, 1),
          repeatEnd: DateTime(2025, 12, 31),
        );

        expect(task.isActiveOn(DateTime(2024, 12, 31)), false);
      });

      test('repeating task is not active after end date', () {
        final task = HabitTask(
          name: 'Test Task',
          iconCodePoint: Icons.check.codePoint,
          repeatStart: DateTime(2025, 1, 1),
          repeatEnd: DateTime(2025, 12, 31),
        );

        expect(task.isActiveOn(DateTime(2026, 1, 1)), false);
      });

      test('one-time task is active on scheduled date', () {
        final task = HabitTask(
          name: 'Test Task',
          iconCodePoint: Icons.check.codePoint,
          scheduledDate: DateTime(2025, 6, 15),
        );

        expect(task.isActiveOn(DateTime(2025, 6, 15)), true);
      });

      test('one-time task ignores time component', () {
        final task = HabitTask(
          name: 'Test Task',
          iconCodePoint: Icons.check.codePoint,
          scheduledDate: DateTime(2025, 6, 15, 10, 30),
        );

        expect(task.isActiveOn(DateTime(2025, 6, 15, 18, 45)), true);
      });

      test('one-time task is not active on different date', () {
        final task = HabitTask(
          name: 'Test Task',
          iconCodePoint: Icons.check.codePoint,
          scheduledDate: DateTime(2025, 6, 15),
        );

        expect(task.isActiveOn(DateTime(2025, 6, 16)), false);
      });

      test('task with no schedule returns true (active any day)', () {
        final task = HabitTask(
          name: 'Test Task',
          iconCodePoint: Icons.check.codePoint,
        );

        expect(task.isActiveOn(DateTime(2025, 6, 15)), true);
      });
    });

    group('copyWith', () {
      test('creates copy with updated name', () {
        final original = HabitTask(
          name: 'Original',
          iconCodePoint: Icons.check.codePoint,
          difficulty: TaskDifficulty.normal,
        );

        final copy = original.copyWith(name: 'Updated');

        expect(copy.name, 'Updated');
        expect(copy.iconCodePoint, original.iconCodePoint);
        expect(copy.difficulty, original.difficulty);
      });

      test('creates copy with updated difficulty', () {
        final original = HabitTask(
          name: 'Test',
          iconCodePoint: Icons.check.codePoint,
          difficulty: TaskDifficulty.normal,
        );

        final copy = original.copyWith(difficulty: TaskDifficulty.hard);

        expect(copy.difficulty, TaskDifficulty.hard);
        expect(copy.name, original.name);
      });

      test('creates copy with updated reminder time', () {
        final original = HabitTask(
          name: 'Test',
          iconCodePoint: Icons.check.codePoint,
        );

        final copy = original.copyWith(
          reminderTime: const TimeOfDay(hour: 9, minute: 0),
        );

        expect(copy.reminderTime, const TimeOfDay(hour: 9, minute: 0));
      });

      test('switches from one-time to repeating', () {
        final original = HabitTask(
          name: 'Test',
          iconCodePoint: Icons.check.codePoint,
          scheduledDate: DateTime(2025, 6, 15),
        );

        final copy = original.copyWith(
          isRepeating: true,
          repeatStart: DateTime(2025, 1, 1),
          repeatEnd: DateTime(2025, 12, 31),
        );

        expect(copy.isRepeating, true);
        expect(copy.scheduledDate, null);
        expect(copy.repeatStart, DateTime(2025, 1, 1));
        expect(copy.repeatEnd, DateTime(2025, 12, 31));
      });

      test('switches from repeating to one-time', () {
        final original = HabitTask(
          name: 'Test',
          iconCodePoint: Icons.check.codePoint,
          repeatStart: DateTime(2025, 1, 1),
          repeatEnd: DateTime(2025, 12, 31),
        );

        final copy = original.copyWith(
          isRepeating: false,
          scheduledDate: DateTime(2025, 6, 15),
        );

        expect(copy.isRepeating, false);
        expect(copy.scheduledDate, DateTime(2025, 6, 15));
        expect(copy.repeatStart, null);
        expect(copy.repeatEnd, null);
      });
    });
  });

  group('TaskDifficulty', () {
    test('has three difficulty levels', () {
      expect(TaskDifficulty.values.length, 3);
      expect(TaskDifficulty.values, [
        TaskDifficulty.easy,
        TaskDifficulty.normal,
        TaskDifficulty.hard,
      ]);
    });
  });
}
