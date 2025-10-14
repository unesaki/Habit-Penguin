import 'package:flutter_test/flutter_test.dart';
import 'package:habit_penguin/models/task_completion_history.dart';

void main() {
  group('TaskCompletionHistory', () {
    group('completedDate', () {
      test('returns date without time', () {
        final history = TaskCompletionHistory(
          taskKey: 0,
          completedAt: DateTime(2025, 6, 15, 14, 30, 45),
          earnedXp: 30,
        );

        final date = history.completedDate;
        expect(date.year, 2025);
        expect(date.month, 6);
        expect(date.day, 15);
        expect(date.hour, 0);
        expect(date.minute, 0);
        expect(date.second, 0);
      });
    });

    group('isOnDate', () {
      test('returns true for same date', () {
        final history = TaskCompletionHistory(
          taskKey: 0,
          completedAt: DateTime(2025, 6, 15, 14, 30),
          earnedXp: 30,
        );

        expect(history.isOnDate(DateTime(2025, 6, 15)), true);
      });

      test('returns true ignoring time component', () {
        final history = TaskCompletionHistory(
          taskKey: 0,
          completedAt: DateTime(2025, 6, 15, 8, 0),
          earnedXp: 30,
        );

        expect(history.isOnDate(DateTime(2025, 6, 15, 20, 0)), true);
      });

      test('returns false for different date', () {
        final history = TaskCompletionHistory(
          taskKey: 0,
          completedAt: DateTime(2025, 6, 15, 14, 30),
          earnedXp: 30,
        );

        expect(history.isOnDate(DateTime(2025, 6, 16)), false);
      });

      test('returns false for same day different month', () {
        final history = TaskCompletionHistory(
          taskKey: 0,
          completedAt: DateTime(2025, 6, 15),
          earnedXp: 30,
        );

        expect(history.isOnDate(DateTime(2025, 7, 15)), false);
      });

      test('returns false for same day/month different year', () {
        final history = TaskCompletionHistory(
          taskKey: 0,
          completedAt: DateTime(2025, 6, 15),
          earnedXp: 30,
        );

        expect(history.isOnDate(DateTime(2024, 6, 15)), false);
      });
    });

    group('notes', () {
      test('can be null', () {
        final history = TaskCompletionHistory(
          taskKey: 0,
          completedAt: DateTime.now(),
          earnedXp: 30,
        );

        expect(history.notes, null);
      });

      test('can store notes', () {
        final history = TaskCompletionHistory(
          taskKey: 0,
          completedAt: DateTime.now(),
          earnedXp: 30,
          notes: 'Felt great today!',
        );

        expect(history.notes, 'Felt great today!');
      });
    });

    group('data integrity', () {
      test('preserves taskKey', () {
        final history = TaskCompletionHistory(
          taskKey: 42,
          completedAt: DateTime.now(),
          earnedXp: 30,
        );

        expect(history.taskKey, 42);
      });

      test('preserves completedAt timestamp', () {
        final timestamp = DateTime(2025, 6, 15, 14, 30, 45);
        final history = TaskCompletionHistory(
          taskKey: 0,
          completedAt: timestamp,
          earnedXp: 30,
        );

        expect(history.completedAt, timestamp);
      });

      test('preserves earned XP amount', () {
        final history = TaskCompletionHistory(
          taskKey: 0,
          completedAt: DateTime.now(),
          earnedXp: 50,
        );

        expect(history.earnedXp, 50);
      });
    });
  });
}
