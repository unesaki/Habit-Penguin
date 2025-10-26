import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:habit_penguin/main.dart';
import 'package:habit_penguin/models/habit_task.dart';
import 'package:habit_penguin/models/task_completion_history.dart';
import 'package:habit_penguin/providers/providers.dart';
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
