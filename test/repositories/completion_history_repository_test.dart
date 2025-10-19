import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:habit_penguin/models/task_completion_history.dart';
import 'package:habit_penguin/repositories/completion_history_repository.dart';

void main() {
  late Directory tempDir;
  late Box<TaskCompletionHistory> historyBox;
  late CompletionHistoryRepository repository;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('history_test');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TaskCompletionHistoryAdapter());
    }

    historyBox =
        await Hive.openBox<TaskCompletionHistory>('completion_history');
    repository = CompletionHistoryRepository(historyBox);
  });

  tearDown(() async {
    await historyBox.clear();
    await historyBox.close();
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  group('CompletionHistoryRepository', () {
    group('Basic operations', () {
      test('adds completion history', () async {
        final history = TaskCompletionHistory(
          taskKey: 0,
          completedAt: DateTime.now(),
          earnedXp: 30,
        );

        await repository.addCompletion(history);
        final all = repository.getAllHistory();

        expect(all.length, 1);
        expect(all.first.taskKey, 0);
        expect(all.first.earnedXp, 30);
      });

      test('retrieves history for specific task', () async {
        await repository.addCompletion(TaskCompletionHistory(
          taskKey: 0,
          completedAt: DateTime.now(),
          earnedXp: 30,
        ));
        await repository.addCompletion(TaskCompletionHistory(
          taskKey: 1,
          completedAt: DateTime.now(),
          earnedXp: 50,
        ));
        await repository.addCompletion(TaskCompletionHistory(
          taskKey: 0,
          completedAt: DateTime.now().subtract(const Duration(days: 1)),
          earnedXp: 30,
        ));

        final task0History = repository.getHistoryForTask(0);
        expect(task0History.length, 2);
        expect(task0History.every((h) => h.taskKey == 0), true);
      });
    });

    group('Completion checking', () {
      test('returns false when task not completed today', () {
        expect(repository.isTaskCompletedOnDate(0, DateTime.now()), false);
      });

      test('returns true when task completed today', () async {
        await repository.addCompletion(TaskCompletionHistory(
          taskKey: 0,
          completedAt: DateTime.now(),
          earnedXp: 30,
        ));

        expect(repository.isTaskCompletedOnDate(0, DateTime.now()), true);
      });

      test('returns false for different date', () async {
        await repository.addCompletion(TaskCompletionHistory(
          taskKey: 0,
          completedAt: DateTime.now().subtract(const Duration(days: 1)),
          earnedXp: 30,
        ));

        expect(repository.isTaskCompletedOnDate(0, DateTime.now()), false);
      });

      test('gets today completed task keys', () async {
        await repository.addCompletion(TaskCompletionHistory(
          taskKey: 0,
          completedAt: DateTime.now(),
          earnedXp: 30,
        ));
        await repository.addCompletion(TaskCompletionHistory(
          taskKey: 2,
          completedAt: DateTime.now(),
          earnedXp: 50,
        ));
        await repository.addCompletion(TaskCompletionHistory(
          taskKey: 1,
          completedAt: DateTime.now().subtract(const Duration(days: 1)),
          earnedXp: 30,
        ));

        final completed = repository.getTodayCompletedTaskKeys();
        expect(completed, {0, 2});
      });
    });

    group('Streak calculation', () {
      test('returns 0 for task with no history', () {
        expect(repository.calculateStreak(0), 0);
      });

      test('returns 1 for task completed today only', () async {
        await repository.addCompletion(TaskCompletionHistory(
          taskKey: 0,
          completedAt: DateTime.now(),
          earnedXp: 30,
        ));

        expect(repository.calculateStreak(0), 1);
      });

      test('returns 0 if last completion was 2+ days ago', () async {
        await repository.addCompletion(TaskCompletionHistory(
          taskKey: 0,
          completedAt: DateTime.now().subtract(const Duration(days: 2)),
          earnedXp: 30,
        ));

        expect(repository.calculateStreak(0), 0);
      });

      test('counts consecutive days correctly', () async {
        final now = DateTime.now();

        // Today
        await repository.addCompletion(TaskCompletionHistory(
          taskKey: 0,
          completedAt: now,
          earnedXp: 30,
        ));

        // Yesterday
        await repository.addCompletion(TaskCompletionHistory(
          taskKey: 0,
          completedAt: now.subtract(const Duration(days: 1)),
          earnedXp: 30,
        ));

        // 2 days ago
        await repository.addCompletion(TaskCompletionHistory(
          taskKey: 0,
          completedAt: now.subtract(const Duration(days: 2)),
          earnedXp: 30,
        ));

        expect(repository.calculateStreak(0), 3);
      });

      test('streak breaks on missing day', () async {
        final now = DateTime.now();

        await repository.addCompletion(TaskCompletionHistory(
          taskKey: 0,
          completedAt: now,
          earnedXp: 30,
        ));

        await repository.addCompletion(TaskCompletionHistory(
          taskKey: 0,
          completedAt: now.subtract(const Duration(days: 1)),
          earnedXp: 30,
        ));

        // Skip day 2

        await repository.addCompletion(TaskCompletionHistory(
          taskKey: 0,
          completedAt: now.subtract(const Duration(days: 3)),
          earnedXp: 30,
        ));

        expect(repository.calculateStreak(0), 2);
      });

      test('handles multiple completions on same day', () async {
        final now = DateTime.now();

        await repository.addCompletion(TaskCompletionHistory(
          taskKey: 0,
          completedAt: now,
          earnedXp: 30,
        ));

        // Another completion same day
        await repository.addCompletion(TaskCompletionHistory(
          taskKey: 0,
          completedAt: now.add(const Duration(hours: 2)),
          earnedXp: 30,
        ));

        await repository.addCompletion(TaskCompletionHistory(
          taskKey: 0,
          completedAt: now.subtract(const Duration(days: 1)),
          earnedXp: 30,
        ));

        expect(repository.calculateStreak(0), 2);
      });
    });

    group('Max streak calculation', () {
      test('returns 0 for task with no history', () {
        expect(repository.calculateMaxStreak(0), 0);
      });

      test('returns current streak if it is the max', () async {
        final now = DateTime.now();

        for (int i = 0; i < 5; i++) {
          await repository.addCompletion(TaskCompletionHistory(
            taskKey: 0,
            completedAt: now.subtract(Duration(days: i)),
            earnedXp: 30,
          ));
        }

        expect(repository.calculateMaxStreak(0), 5);
      });

      test('returns historical max even if current streak is lower', () async {
        final now = DateTime.now();

        // Current streak: 2 days
        await repository.addCompletion(TaskCompletionHistory(
          taskKey: 0,
          completedAt: now,
          earnedXp: 30,
        ));
        await repository.addCompletion(TaskCompletionHistory(
          taskKey: 0,
          completedAt: now.subtract(const Duration(days: 1)),
          earnedXp: 30,
        ));

        // Gap

        // Historical streak: 4 days
        for (int i = 5; i < 9; i++) {
          await repository.addCompletion(TaskCompletionHistory(
            taskKey: 0,
            completedAt: now.subtract(Duration(days: i)),
            earnedXp: 30,
          ));
        }

        expect(repository.calculateMaxStreak(0), 4);
      });
    });

    group('Deletion', () {
      test('deletes today completion for task', () async {
        await repository.addCompletion(TaskCompletionHistory(
          taskKey: 0,
          completedAt: DateTime.now(),
          earnedXp: 30,
        ));

        expect(repository.isTaskCompletedOnDate(0, DateTime.now()), true);

        final deleted = await repository.deleteTodayCompletionForTask(0);
        expect(deleted, true);
        expect(repository.isTaskCompletedOnDate(0, DateTime.now()), false);
      });

      test('returns false when no today completion to delete', () async {
        final deleted = await repository.deleteTodayCompletionForTask(0);
        expect(deleted, false);
      });

      test('deletes all history for task', () async {
        final now = DateTime.now();

        await repository.addCompletion(TaskCompletionHistory(
          taskKey: 0,
          completedAt: now,
          earnedXp: 30,
        ));
        await repository.addCompletion(TaskCompletionHistory(
          taskKey: 0,
          completedAt: now.subtract(const Duration(days: 1)),
          earnedXp: 30,
        ));
        await repository.addCompletion(TaskCompletionHistory(
          taskKey: 1,
          completedAt: now,
          earnedXp: 50,
        ));

        expect(repository.getHistoryForTask(0).length, 2);

        await repository.deleteAllForTask(0);

        expect(repository.getHistoryForTask(0).length, 0);
        expect(repository.getHistoryForTask(1).length, 1);
      });
    });
  });
}
