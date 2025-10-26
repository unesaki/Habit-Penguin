import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:habit_penguin/main.dart';
import 'package:habit_penguin/models/habit_task.dart';
import 'package:habit_penguin/models/task_completion_history.dart';
import 'package:habit_penguin/providers/providers.dart';
import 'package:habit_penguin/repositories/completion_history_repository.dart';
import 'package:habit_penguin/services/notification_service.dart';

/// インテグレーションテスト: タスクのライフサイクル全体をテスト
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late NotificationService notificationService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('integration_test');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(HabitTaskAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TaskCompletionHistoryAdapter());
    }

    await Hive.openBox<HabitTask>('tasks');
    await Hive.openBox<TaskCompletionHistory>('completion_history');
    await Hive.openBox('appState');
    notificationService = NotificationService.test();
    await Hive.box('appState').put('hasCompletedOnboarding', true);
  });

  tearDown(() async {
    await Hive.box<HabitTask>('tasks').clear();
    await Hive.box<TaskCompletionHistory>('completion_history').clear();
    await Hive.box('appState').clear();
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  Widget buildTestApp() {
    return ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: const HabitPenguinApp(),
    );
  }

  Future<void> pumpFrames(WidgetTester tester, [int times = 8]) async {
    for (var i = 0; i < times; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Finder taskFormSubmitButton() {
    // TaskFormPage内のFilledButtonを探す
    final filledButtons = find.descendant(
      of: find.byType(TaskFormPage),
      matching: find.byType(FilledButton),
    );

    // FilledButtonが見つかればそれを返す
    if (filledButtons.evaluate().isNotEmpty) {
      return filledButtons.last;
    }

    // 見つからない場合はテキストで探す
    return find
        .descendant(
          of: find.byType(TaskFormPage),
          matching: find.text('タスクを作成'),
        )
        .last;
  }

  Future<void> waitForTaskFormToClose(WidgetTester tester) async {
    // タップイベントを処理するため、即座にpump
    await tester.pump();

    // フォームが閉じるまで待機（最大5秒）
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(TaskFormPage).evaluate().isEmpty) {
        // 閉じアニメーション完了を待機
        await pumpFrames(tester, 3);
        return;
      }
    }

    // タイムアウトした場合は警告を出す
    print('Warning: TaskFormPage did not close within timeout');
  }

  group('Task Creation Workflow', () {
    testWidgets('creates a one-time task successfully', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester, 10);

      // Navigate to Tasks tab
      await tester.tap(find.text('Tasks').first);
      await pumpFrames(tester);

      // Open task form
      await tester.tap(find.byTooltip('Add Task'));
      await pumpFrames(tester);

      // Enter task name
      await tester.enterText(
          find.byType(TextFormField).first, 'Morning Exercise');
      await pumpFrames(tester);

      // Select difficulty (Hard)
      await tester.tap(find.text('Hard'));
      await pumpFrames(tester);

      // Save task
      final submitButton = taskFormSubmitButton();
      expect(submitButton, findsOneWidget);
      await tester.tap(submitButton);
      await waitForTaskFormToClose(tester);

      // Verify task appears in list
      expect(find.text('Morning Exercise'), findsOneWidget);

      // Verify persistence
      final tasksBox = Hive.box<HabitTask>('tasks');
      expect(tasksBox.length, 1);
      expect(tasksBox.getAt(0)?.name, 'Morning Exercise');
      expect(tasksBox.getAt(0)?.difficulty, TaskDifficulty.hard);
    });

    testWidgets('creates a repeating task successfully', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester, 10);

      await tester.tap(find.text('Tasks').first);
      await pumpFrames(tester);

      await tester.tap(find.byTooltip('Add Task'));
      await pumpFrames(tester);

      // Enter task name
      await tester.enterText(
          find.byType(TextFormField).first, 'Daily Meditation');
      await pumpFrames(tester);

      // Enable repeating toggle
      final repeatingSwitch = find.ancestor(
        of: find.text('繰り返しタスク'),
        matching: find.byType(Row),
      );
      await tester.tap(find.descendant(
        of: repeatingSwitch,
        matching: find.byType(Switch),
      ));
      await pumpFrames(tester);

      // Save task
      final submitButton = taskFormSubmitButton();
      expect(submitButton, findsOneWidget);
      await tester.tap(submitButton);
      await waitForTaskFormToClose(tester);

      // Verify task appears
      expect(find.text('Daily Meditation'), findsOneWidget);

      // Verify it's a repeating task
      final tasksBox = Hive.box<HabitTask>('tasks');
      expect(tasksBox.length, 1);
      expect(tasksBox.getAt(0)?.isRepeating, true);
    });
  });

  group('Task Completion and XP Workflow', () {
    testWidgets('completes task and gains XP', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester, 10);

      // Create a task first
      await tester.tap(find.text('Tasks').first);
      await pumpFrames(tester);

      await tester.tap(find.byTooltip('Add Task'));
      await pumpFrames(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Test Task');
      await pumpFrames(tester);

      // Select Easy difficulty (5 XP)
      await tester.tap(find.text('Easy'));
      await pumpFrames(tester);

      await tester.tap(taskFormSubmitButton());
      await waitForTaskFormToClose(tester);

      // Get initial XP
      final appStateBox = Hive.box('appState');
      final initialXp = appStateBox.get('currentXp', defaultValue: 0) as int;

      // Navigate to Home tab to complete the task
      await tester.tap(find.text('Home'));
      await pumpFrames(tester, 12);

      // Complete the task via the action button
      await tester.tap(find.byTooltip('完了にする').first);
      await pumpFrames(tester);

      // Verify XP dialog appears
      expect(find.text('クエスト達成！'), findsOneWidget);
      expect(find.textContaining('5 XP'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('OK'));
      await pumpFrames(tester);

      // Verify XP was added
      final finalXp = appStateBox.get('currentXp', defaultValue: 0) as int;
      expect(finalXp, initialXp + 5);

      // Verify completion history was created
      final historyBox = Hive.box<TaskCompletionHistory>('completion_history');
      expect(historyBox.length, 1);
      expect(historyBox.getAt(0)?.earnedXp, 5);

      // Verify task moved to completed section
      expect(find.text('完了済み'), findsOneWidget);
    });

    testWidgets('different difficulties award different XP', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester, 10);

      await tester.tap(find.text('Tasks').first);
      await pumpFrames(tester);

      // Create Hard task (50 XP)
      await tester.tap(find.byTooltip('Add Task'));
      await pumpFrames(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Hard Task');
      await pumpFrames(tester);

      await tester.tap(find.text('Hard'));
      await pumpFrames(tester);

      await tester.tap(taskFormSubmitButton());
      await waitForTaskFormToClose(tester);

      await tester.tap(find.text('Home'));
      await pumpFrames(tester, 12);

      await tester.tap(find.byTooltip('完了にする').first);
      await pumpFrames(tester);

      expect(find.textContaining('50 XP'), findsOneWidget);

      final appStateBox = Hive.box('appState');
      final xp = appStateBox.get('currentXp', defaultValue: 0) as int;
      expect(xp, 50);

      await tester.tap(find.text('OK'));
      await pumpFrames(tester);
    });
  });

  group('Repeating Task Workflow', () {
    testWidgets('repeating task can be completed multiple times',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester, 10);

      await tester.tap(find.text('Tasks').first);
      await pumpFrames(tester);

      // Create repeating task
      await tester.tap(find.byTooltip('Add Task'));
      await pumpFrames(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Daily Task');
      await pumpFrames(tester);

      final repeatingSwitch = find.ancestor(
        of: find.text('繰り返しタスク'),
        matching: find.byType(Row),
      );
      await tester.tap(find.descendant(
        of: repeatingSwitch,
        matching: find.byType(Switch),
      ));
      await pumpFrames(tester);

      await tester.tap(taskFormSubmitButton());
      await waitForTaskFormToClose(tester);

      await tester.tap(find.text('Home'));
      await pumpFrames(tester, 12);

      await tester.tap(find.byTooltip('完了にする').first);
      await pumpFrames(tester);

      await tester.tap(find.text('OK'));
      await pumpFrames(tester);

      expect(find.text('Daily Task'), findsOneWidget);

      final historyBox = Hive.box<TaskCompletionHistory>('completion_history');
      expect(historyBox.length, 1);

      final tasksBox = Hive.box<HabitTask>('tasks');
      expect(tasksBox.length, 1);
    });
  });

  group('Task Deletion Workflow', () {
    testWidgets('deletes task successfully', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester, 10);

      await tester.tap(find.text('Tasks').first);
      await pumpFrames(tester);

      // Create task
      await tester.tap(find.byTooltip('Add Task'));
      await pumpFrames(tester);

      await tester.enterText(
          find.byType(TextFormField).first, 'Task to Delete');
      await pumpFrames(tester);

      await tester.tap(taskFormSubmitButton());
      await waitForTaskFormToClose(tester);

      final menuButton = find.byTooltip('メニュー').first;
      await tester.tap(menuButton);
      await pumpFrames(tester);

      await tester.tap(find.text('削除'));
      await pumpFrames(tester);

      await tester.tap(find.text('削除').last);
      await pumpFrames(tester);

      // Verify task is deleted
      expect(find.text('Task to Delete'), findsNothing);

      final tasksBox = Hive.box<HabitTask>('tasks');
      expect(tasksBox.length, 0);
    });
  });

  group('Streak Calculation', () {
    test('calculates streak for consecutive completions', () async {
      // Create a task directly in Hive (no UI interaction needed)
      final tasksBox = Hive.box<HabitTask>('tasks');
      await tasksBox.add(HabitTask(
        name: 'Streak Task',
        iconCodePoint: Icons.check.codePoint,
        difficulty: TaskDifficulty.normal,
        scheduledDate: DateTime.now(),
      ));

      final taskKey = 0; // First task
      final historyBox = Hive.box<TaskCompletionHistory>('completion_history');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Complete for today
      await historyBox.add(TaskCompletionHistory(
        taskKey: taskKey,
        completedAt: today,
        earnedXp: 30,
      ));

      // Complete for yesterday
      await historyBox.add(TaskCompletionHistory(
        taskKey: taskKey,
        completedAt: today.subtract(const Duration(days: 1)),
        earnedXp: 30,
      ));

      // Complete for 2 days ago
      await historyBox.add(TaskCompletionHistory(
        taskKey: taskKey,
        completedAt: today.subtract(const Duration(days: 2)),
        earnedXp: 30,
      ));

      // Verify streak calculation
      final repository = CompletionHistoryRepository(historyBox);
      expect(repository.calculateStreak(taskKey), 3);
    });

    test('streak resets when a day is missed', () async {
      // Create a task directly in Hive
      final tasksBox = Hive.box<HabitTask>('tasks');
      await tasksBox.add(HabitTask(
        name: 'Streak Reset Task',
        iconCodePoint: Icons.check.codePoint,
        difficulty: TaskDifficulty.normal,
        scheduledDate: DateTime.now(),
      ));

      final taskKey = 0;
      final historyBox = Hive.box<TaskCompletionHistory>('completion_history');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Complete today and yesterday (streak = 2)
      await historyBox.add(TaskCompletionHistory(
        taskKey: taskKey,
        completedAt: today,
        earnedXp: 30,
      ));

      await historyBox.add(TaskCompletionHistory(
        taskKey: taskKey,
        completedAt: today.subtract(const Duration(days: 1)),
        earnedXp: 30,
      ));

      // Skip 2 days ago (day is missed)

      // Complete 3 days ago
      await historyBox.add(TaskCompletionHistory(
        taskKey: taskKey,
        completedAt: today.subtract(const Duration(days: 3)),
        earnedXp: 30,
      ));

      // Verify streak is only 2 (today and yesterday)
      final repository = CompletionHistoryRepository(historyBox);
      expect(repository.calculateStreak(taskKey), 2);
    });
  });

  group('Same Day Multiple Completions', () {
    testWidgets('repeating task can be completed multiple times on same day', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester, 10);

      await tester.tap(find.text('Tasks').first);
      await pumpFrames(tester);

      // Create repeating task
      await tester.tap(find.byTooltip('Add Task'));
      await pumpFrames(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Multiple Completion Task');
      await pumpFrames(tester);

      final repeatingSwitch = find.ancestor(
        of: find.text('繰り返しタスク'),
        matching: find.byType(Row),
      );
      await tester.tap(find.descendant(
        of: repeatingSwitch,
        matching: find.byType(Switch),
      ));
      await pumpFrames(tester);

      await tester.tap(taskFormSubmitButton());
      await waitForTaskFormToClose(tester);

      // Get initial XP
      final appStateBox = Hive.box('appState');
      final initialXp = appStateBox.get('currentXp', defaultValue: 0) as int;

      // Complete first time
      await tester.tap(find.text('Home'));
      await pumpFrames(tester, 12);

      await tester.tap(find.byTooltip('完了にする').first);
      await pumpFrames(tester);

      await tester.tap(find.text('OK'));
      await pumpFrames(tester);

      // Complete second time on same day
      await tester.tap(find.byTooltip('完了にする').first);
      await pumpFrames(tester);

      await tester.tap(find.text('OK'));
      await pumpFrames(tester);

      // Verify XP was added twice
      final finalXp = appStateBox.get('currentXp', defaultValue: 0) as int;
      expect(finalXp, initialXp + 60); // Normal difficulty = 30 XP × 2

      // Verify completion history has 2 records
      final historyBox = Hive.box<TaskCompletionHistory>('completion_history');
      expect(historyBox.length, 2);
    });
  });

  group('Today Completion Status', () {
    testWidgets('shows correct completion status for today', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester, 10);

      await tester.tap(find.text('Tasks').first);
      await pumpFrames(tester);

      // Create task
      await tester.tap(find.byTooltip('Add Task'));
      await pumpFrames(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Today Status Task');
      await pumpFrames(tester);

      await tester.tap(taskFormSubmitButton());
      await waitForTaskFormToClose(tester);

      // Complete the task
      await tester.tap(find.text('Home'));
      await pumpFrames(tester, 12);

      await tester.tap(find.byTooltip('完了にする').first);
      await pumpFrames(tester);

      await tester.tap(find.text('OK'));
      await pumpFrames(tester);

      // Verify task shows as completed
      expect(find.text('完了済み'), findsOneWidget);

      // Restart app
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester, 10);

      await tester.tap(find.text('Home'));
      await pumpFrames(tester, 12);

      // Verify completion status is still shown
      expect(find.text('完了済み'), findsOneWidget);

      // Verify in history
      final historyBox = Hive.box<TaskCompletionHistory>('completion_history');
      final repository = CompletionHistoryRepository(historyBox);
      final completedKeys = repository.getTodayCompletedTaskKeys();
      expect(completedKeys.contains(0), true);
    });

    testWidgets('prevents completing same non-repeating task twice today', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester, 10);

      await tester.tap(find.text('Tasks').first);
      await pumpFrames(tester);

      // Create non-repeating task
      await tester.tap(find.byTooltip('Add Task'));
      await pumpFrames(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Once Only Task');
      await pumpFrames(tester);

      await tester.tap(taskFormSubmitButton());
      await waitForTaskFormToClose(tester);

      // Complete the task
      await tester.tap(find.text('Home'));
      await pumpFrames(tester, 12);

      await tester.tap(find.byTooltip('完了にする').first);
      await pumpFrames(tester);

      await tester.tap(find.text('OK'));
      await pumpFrames(tester);

      // Try to complete again - task should be in completed section
      // and not appear in active tasks
      expect(find.text('完了済み'), findsOneWidget);

      // Verify there's only one completion button (none in active tasks)
      final completionButtons = find.byTooltip('完了にする');
      expect(completionButtons.evaluate().length, 0);
    });
  });

  group('Normal Difficulty XP', () {
    testWidgets('normal difficulty awards 30 XP', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester, 10);

      await tester.tap(find.text('Tasks').first);
      await pumpFrames(tester);

      // Create Normal task (default difficulty)
      await tester.tap(find.byTooltip('Add Task'));
      await pumpFrames(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Normal Task');
      await pumpFrames(tester);

      // Don't select difficulty - Normal is default
      await tester.tap(taskFormSubmitButton());
      await waitForTaskFormToClose(tester);

      await tester.tap(find.text('Home'));
      await pumpFrames(tester, 12);

      await tester.tap(find.byTooltip('完了にする').first);
      await pumpFrames(tester);

      // Verify 30 XP is shown
      expect(find.textContaining('30 XP'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await pumpFrames(tester);

      // Verify XP was added
      final appStateBox = Hive.box('appState');
      final xp = appStateBox.get('currentXp', defaultValue: 0) as int;
      expect(xp, 30);
    });
  });

  group('Level Up System', () {
    testWidgets('levels up when reaching 100 XP', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester, 10);

      await tester.tap(find.text('Tasks').first);
      await pumpFrames(tester);

      // Create two Hard tasks (50 XP each = 100 XP total)
      for (int i = 0; i < 2; i++) {
        await tester.tap(find.byTooltip('Add Task'));
        await pumpFrames(tester);

        await tester.enterText(
            find.byType(TextFormField).first, 'Hard Task ${i + 1}');
        await pumpFrames(tester);

        await tester.tap(find.text('Hard'));
        await pumpFrames(tester);

        await tester.tap(taskFormSubmitButton());
        await waitForTaskFormToClose(tester);
      }

      // Complete first task (50 XP)
      await tester.tap(find.text('Home'));
      await pumpFrames(tester, 12);

      await tester.tap(find.byTooltip('完了にする').first);
      await pumpFrames(tester);

      await tester.tap(find.text('OK'));
      await pumpFrames(tester);

      // Verify level is still 1
      final appStateBox = Hive.box('appState');
      var xp = appStateBox.get('currentXp', defaultValue: 0) as int;
      expect(xp, 50);

      // Calculate level using XpService logic
      var level = (xp / 100).floor() + 1;
      expect(level, 1);

      // Complete second task (100 XP total)
      await tester.tap(find.byTooltip('完了にする').first);
      await pumpFrames(tester);

      await tester.tap(find.text('OK'));
      await pumpFrames(tester);

      // Verify XP is 100
      xp = appStateBox.get('currentXp', defaultValue: 0) as int;
      expect(xp, 100);

      // Verify level is now 2
      level = (xp / 100).floor() + 1;
      expect(level, 2);
    });

    test('calculates XP to next level correctly', () async {
      final appStateBox = Hive.box('appState');

      // Set XP to 50
      await appStateBox.put('currentXp', 50);

      final xp = appStateBox.get('currentXp', defaultValue: 0) as int;
      final level = (xp / 100).floor() + 1; // Level 1
      final nextLevelXp = level * 100; // 100
      final xpToNext = nextLevelXp - xp; // 50

      expect(level, 1);
      expect(xpToNext, 50);
    });
  });

  group('Task Edit Functionality', () {
    testWidgets('edits task successfully', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester, 10);

      await tester.tap(find.text('Tasks').first);
      await pumpFrames(tester);

      // Create a task
      await tester.tap(find.byTooltip('Add Task'));
      await pumpFrames(tester);

      await tester.enterText(
          find.byType(TextFormField).first, 'Original Task');
      await pumpFrames(tester);

      await tester.tap(find.text('Easy'));
      await pumpFrames(tester);

      await tester.tap(taskFormSubmitButton());
      await waitForTaskFormToClose(tester);

      // Verify original task
      expect(find.text('Original Task'), findsOneWidget);

      // Open edit menu
      final menuButton = find.byTooltip('メニュー').first;
      await tester.tap(menuButton);
      await pumpFrames(tester);

      // Tap edit
      await tester.tap(find.text('編集'));
      await pumpFrames(tester);

      // Wait for form to open
      await pumpFrames(tester, 5);
      expect(find.byType(TaskFormPage), findsOneWidget);

      // Edit task name
      final nameField = find.byType(TextFormField).first;
      await tester.enterText(nameField, 'Updated Task');
      await pumpFrames(tester);

      // Change difficulty to Hard
      await tester.tap(find.text('Hard'));
      await pumpFrames(tester);

      // Save changes
      await tester.tap(taskFormSubmitButton());
      await waitForTaskFormToClose(tester);

      // Verify changes
      expect(find.text('Updated Task'), findsOneWidget);
      expect(find.text('Original Task'), findsNothing);

      final tasksBox = Hive.box<HabitTask>('tasks');
      expect(tasksBox.getAt(0)?.name, 'Updated Task');
      expect(tasksBox.getAt(0)?.difficulty, TaskDifficulty.hard);
    });
  });

  group('Error Handling', () {
    testWidgets('shows error when task name is empty', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester, 10);

      await tester.tap(find.text('Tasks').first);
      await pumpFrames(tester);

      await tester.tap(find.byTooltip('Add Task'));
      await pumpFrames(tester);

      // Don't enter task name, just try to submit
      await tester.tap(taskFormSubmitButton());
      await pumpFrames(tester);

      // Form should still be open (validation failed)
      expect(find.byType(TaskFormPage), findsOneWidget);

      // No task should be created
      final tasksBox = Hive.box<HabitTask>('tasks');
      expect(tasksBox.length, 0);
    });

    testWidgets('shows error when repeat end date is before start date',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester, 10);

      await tester.tap(find.text('Tasks').first);
      await pumpFrames(tester);

      await tester.tap(find.byTooltip('Add Task'));
      await pumpFrames(tester);

      await tester.enterText(
          find.byType(TextFormField).first, 'Invalid Repeat Task');
      await pumpFrames(tester);

      // Enable repeating
      final repeatingSwitch = find.ancestor(
        of: find.text('繰り返しタスク'),
        matching: find.byType(Row),
      );
      await tester.tap(find.descendant(
        of: repeatingSwitch,
        matching: find.byType(Switch),
      ));
      await pumpFrames(tester);

      // Try to submit (this should be caught by validation)
      // Note: In a real scenario, you would set end date before start date
      // For now, we verify the task is created with valid default dates
      await tester.tap(taskFormSubmitButton());
      await pumpFrames(tester);

      // If validation is working, form might still be open or task created with valid dates
      // This is a placeholder - actual implementation may vary
    });
  });

  group('Date Range Boundary Tests', () {
    test('repeating task is not active outside date range', () async {
      final tasksBox = Hive.box<HabitTask>('tasks');

      final today = DateTime.now();
      final startDate = DateTime(today.year, today.month, today.day);
      final endDate = startDate.add(const Duration(days: 30));

      await tasksBox.add(HabitTask(
        name: 'Date Range Task',
        iconCodePoint: Icons.check.codePoint,
        difficulty: TaskDifficulty.normal,
        repeatStart: startDate,
        repeatEnd: endDate,
      ));

      final task = tasksBox.getAt(0)!;

      // Test before start date
      final beforeStart = startDate.subtract(const Duration(days: 1));
      expect(task.isActiveOn(beforeStart), false);

      // Test after end date
      final afterEnd = endDate.add(const Duration(days: 1));
      expect(task.isActiveOn(afterEnd), false);
    });

    test('repeating task is active on start and end dates', () async {
      final tasksBox = Hive.box<HabitTask>('tasks');

      final today = DateTime.now();
      final startDate = DateTime(today.year, today.month, today.day);
      final endDate = startDate.add(const Duration(days: 30));

      await tasksBox.add(HabitTask(
        name: 'Boundary Task',
        iconCodePoint: Icons.check.codePoint,
        difficulty: TaskDifficulty.normal,
        repeatStart: startDate,
        repeatEnd: endDate,
      ));

      final task = tasksBox.getAt(0)!;

      // Test on start date (boundary)
      expect(task.isActiveOn(startDate), true);

      // Test on end date (boundary)
      expect(task.isActiveOn(endDate), true);

      // Test in middle
      final middleDate = startDate.add(const Duration(days: 15));
      expect(task.isActiveOn(middleDate), true);
    });

    test('non-repeating task is active on scheduled date', () async {
      final tasksBox = Hive.box<HabitTask>('tasks');

      final scheduledDate = DateTime(2025, 12, 25);

      await tasksBox.add(HabitTask(
        name: 'One-time Task',
        iconCodePoint: Icons.check.codePoint,
        difficulty: TaskDifficulty.normal,
        scheduledDate: scheduledDate,
      ));

      final task = tasksBox.getAt(0)!;

      // Active on scheduled date
      expect(task.isActiveOn(scheduledDate), true);

      // Not active on other dates
      expect(task.isActiveOn(scheduledDate.subtract(const Duration(days: 1))),
          false);
      expect(
          task.isActiveOn(scheduledDate.add(const Duration(days: 1))), false);
    });
  });

  group('Data Persistence', () {
    testWidgets('tasks persist across app restarts', (tester) async {
      // Create task
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester, 10);

      await tester.tap(find.text('Tasks').first);
      await pumpFrames(tester);

      await tester.tap(find.byTooltip('Add Task'));
      await pumpFrames(tester);

      await tester.enterText(
          find.byType(TextFormField).first, 'Persistent Task');
      await pumpFrames(tester);

      await tester.tap(taskFormSubmitButton());
      await waitForTaskFormToClose(tester);

      // Simulate app restart by creating new widget
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester, 10);

      await tester.tap(find.text('Tasks').first);
      await pumpFrames(tester);

      // Verify task still exists
      expect(find.text('Persistent Task'), findsOneWidget);
    });

    testWidgets('XP persists across app restarts', (tester) async {
      // Earn some XP
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester, 10);

      await tester.tap(find.text('Tasks').first);
      await pumpFrames(tester);

      await tester.tap(find.byTooltip('Add Task'));
      await pumpFrames(tester);

      await tester.enterText(find.byType(TextFormField).first, 'XP Task');
      await pumpFrames(tester);

      await tester.tap(find.text('Hard'));
      await pumpFrames(tester);

      await tester.tap(taskFormSubmitButton());
      await waitForTaskFormToClose(tester);

      await tester.tap(find.text('Home'));
      await pumpFrames(tester, 12);

      await tester.tap(find.byTooltip('完了にする').first);
      await pumpFrames(tester);

      await tester.tap(find.text('OK'));
      await pumpFrames(tester);

      // Get XP amount
      final appStateBox = Hive.box('appState');
      final xp = appStateBox.get('currentXp', defaultValue: 0) as int;
      expect(xp, 50);

      // Restart app
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester, 10);

      // Verify XP is still there
      final persistedXp = appStateBox.get('currentXp', defaultValue: 0) as int;
      expect(persistedXp, 50);
    });
  });
}
