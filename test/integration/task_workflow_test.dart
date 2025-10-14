import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:habit_penguin/main.dart';
import 'package:habit_penguin/models/habit_task.dart';
import 'package:habit_penguin/models/task_completion_history.dart';

/// インテグレーションテスト: タスクのライフサイクル全体をテスト
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

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
  });

  tearDown(() async {
    await Hive.box<HabitTask>('tasks').clear();
    await Hive.box<TaskCompletionHistory>('completion_history').clear();
    await Hive.box('appState').clear();
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('Task Creation Workflow', () {
    testWidgets('creates a one-time task successfully', (tester) async {
      await tester.pumpWidget(const HabitPenguinApp());
      await tester.pumpAndSettle();

      // Navigate to Tasks tab
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      // Open task form
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Enter task name
      await tester.enterText(find.byType(TextFormField), 'Morning Exercise');
      await tester.pumpAndSettle();

      // Select difficulty (Hard)
      await tester.tap(find.text('Hard'));
      await tester.pumpAndSettle();

      // Select date (tap on date row)
      await tester.tap(find.text('未選択').first);
      await tester.pumpAndSettle();

      // Confirm date picker (tap OK)
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Save task
      await tester.tap(find.text('タスクを作成'));
      await tester.pumpAndSettle();

      // Verify task appears in list
      expect(find.text('Morning Exercise'), findsOneWidget);

      // Verify persistence
      final tasksBox = Hive.box<HabitTask>('tasks');
      expect(tasksBox.length, 1);
      expect(tasksBox.getAt(0)?.name, 'Morning Exercise');
      expect(tasksBox.getAt(0)?.difficulty, TaskDifficulty.hard);
    });

    testWidgets('creates a repeating task successfully', (tester) async {
      await tester.pumpWidget(const HabitPenguinApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Enter task name
      await tester.enterText(find.byType(TextFormField), 'Daily Meditation');
      await tester.pumpAndSettle();

      // Enable repeating toggle
      final repeatingSwitch = find.ancestor(
        of: find.text('繰り返しタスク'),
        matching: find.byType(Row),
      );
      await tester.tap(find.descendant(
        of: repeatingSwitch,
        matching: find.byType(Switch),
      ));
      await tester.pumpAndSettle();

      // Select start date
      await tester.tap(find.text('未選択').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Select end date
      await tester.tap(find.text('未選択').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Save task
      await tester.tap(find.text('タスクを作成'));
      await tester.pumpAndSettle();

      // Verify task appears
      expect(find.text('Daily Meditation'), findsOneWidget);

      // Verify it's a repeating task
      final tasksBox = Hive.box<HabitTask>('tasks');
      expect(tasksBox.getAt(0)?.isRepeating, true);
    });
  });

  group('Task Completion and XP Workflow', () {
    testWidgets('completes task and gains XP', (tester) async {
      await tester.pumpWidget(const HabitPenguinApp());
      await tester.pumpAndSettle();

      // Create a task first
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'Test Task');
      await tester.pumpAndSettle();

      // Select Easy difficulty (5 XP)
      await tester.tap(find.text('Easy'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('未選択').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('タスクを作成'));
      await tester.pumpAndSettle();

      // Get initial XP
      final appStateBox = Hive.box('appState');
      final initialXp = appStateBox.get('currentXp', defaultValue: 0) as int;

      // Complete the task (tap checkbox)
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // Verify XP dialog appears
      expect(find.text('クエスト達成！'), findsOneWidget);
      expect(find.textContaining('5 XP'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

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
      await tester.pumpWidget(const HabitPenguinApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      // Create Hard task (50 XP)
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'Hard Task');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hard'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('未選択').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('タスクを作成'));
      await tester.pumpAndSettle();

      // Complete task
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // Verify 50 XP awarded
      expect(find.textContaining('50 XP'), findsOneWidget);

      final appStateBox = Hive.box('appState');
      final xp = appStateBox.get('currentXp', defaultValue: 0) as int;
      expect(xp, 50);
    });
  });

  group('Repeating Task Workflow', () {
    testWidgets('repeating task can be completed multiple times',
        (tester) async {
      await tester.pumpWidget(const HabitPenguinApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      // Create repeating task
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'Daily Task');
      await tester.pumpAndSettle();

      final repeatingSwitch = find.ancestor(
        of: find.text('繰り返しタスク'),
        matching: find.byType(Row),
      );
      await tester.tap(find.descendant(
        of: repeatingSwitch,
        matching: find.byType(Switch),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('未選択').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('未選択').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('タスクを作成'));
      await tester.pumpAndSettle();

      // Complete task
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Verify task moved to completed
      expect(find.text('Daily Task'), findsOneWidget);

      // Verify completion history
      final historyBox = Hive.box<TaskCompletionHistory>('completion_history');
      expect(historyBox.length, 1);

      // Verify task still exists (not deleted)
      final tasksBox = Hive.box<HabitTask>('tasks');
      expect(tasksBox.length, 1);
    });
  });

  group('Task Deletion Workflow', () {
    testWidgets('deletes task successfully', (tester) async {
      await tester.pumpWidget(const HabitPenguinApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      // Create task
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'Task to Delete');
      await tester.pumpAndSettle();

      await tester.tap(find.text('未選択').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('タスクを作成'));
      await tester.pumpAndSettle();

      // Delete task (long press to show delete option)
      await tester.longPress(find.text('Task to Delete'));
      await tester.pumpAndSettle();

      // Confirm deletion
      await tester.tap(find.text('削除'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('削除').last);
      await tester.pumpAndSettle();

      // Verify task is deleted
      expect(find.text('Task to Delete'), findsNothing);

      final tasksBox = Hive.box<HabitTask>('tasks');
      expect(tasksBox.length, 0);
    });
  });

  group('Data Persistence', () {
    testWidgets('tasks persist across app restarts', (tester) async {
      // Create task
      await tester.pumpWidget(const HabitPenguinApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'Persistent Task');
      await tester.pumpAndSettle();

      await tester.tap(find.text('未選択').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('タスクを作成'));
      await tester.pumpAndSettle();

      // Simulate app restart by creating new widget
      await tester.pumpWidget(const HabitPenguinApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      // Verify task still exists
      expect(find.text('Persistent Task'), findsOneWidget);
    });

    testWidgets('XP persists across app restarts', (tester) async {
      // Earn some XP
      await tester.pumpWidget(const HabitPenguinApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'XP Task');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hard'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('未選択').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('タスクを作成'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Get XP amount
      final appStateBox = Hive.box('appState');
      final xp = appStateBox.get('currentXp', defaultValue: 0) as int;
      expect(xp, 50);

      // Restart app
      await tester.pumpWidget(const HabitPenguinApp());
      await tester.pumpAndSettle();

      // Verify XP is still there
      final persistedXp = appStateBox.get('currentXp', defaultValue: 0) as int;
      expect(persistedXp, 50);
    });
  });
}
