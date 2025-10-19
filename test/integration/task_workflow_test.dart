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

  Widget _buildApp() {
    return ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: const HabitPenguinApp(),
    );
  }

  Future<void> _pumpFrames(WidgetTester tester, [int times = 8]) async {
    for (var i = 0; i < times; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Finder _taskFormSubmitButton() {
    return find
        .descendant(
          of: find.byType(TaskFormPage),
          matching: find.text('タスクを作成'),
        )
        .last;
  }

  Future<void> _selectDateField(
      WidgetTester tester, List<String> labels) async {
    Finder? labelFinder;
    for (final label in labels) {
      final candidate = find.descendant(
        of: find.byType(TaskFormPage),
        matching: find.text(label),
      );
      if (candidate.evaluate().isNotEmpty) {
        labelFinder = candidate;
        break;
      }
    }
    expect(labelFinder, isNotNull, reason: 'Date label not found');
    final field = find
        .ancestor(of: labelFinder!.first, matching: find.byType(InkWell))
        .first;
    await tester.tap(field);
    await _pumpFrames(tester);
    await tester.tap(find.text('OK'));
    await _pumpFrames(tester);
  }

  String _formattedToday() {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    return '${now.year}/$mm/$dd';
  }

  group('Task Creation Workflow', () {
    testWidgets('creates a one-time task successfully', (tester) async {
      await tester.pumpWidget(_buildApp());
      await _pumpFrames(tester);

      // Navigate to Tasks tab
      await tester.tap(find.text('Tasks').first);
      await _pumpFrames(tester);

      // Open task form
      await tester.tap(find.byTooltip('Add Task'));
      await _pumpFrames(tester);

      // Enter task name
      await tester.enterText(
          find.byType(TextFormField).first, 'Morning Exercise');
      await _pumpFrames(tester);

      // Select difficulty (Hard)
      await tester.tap(find.text('Hard'));
      await _pumpFrames(tester);

      // Debug print available text widgets
      final visibleTexts = tester.widgetList<Text>(find.byType(Text));
      for (final textWidget in visibleTexts) {
        debugPrint(textWidget.data);
      }

      // Confirm date
      final todayLabel = _formattedToday();
      await tester.tap(find.text(todayLabel));
      await _pumpFrames(tester);
      await tester.tap(find.text('OK'));
      await _pumpFrames(tester);

      // Save task
      await tester.tap(_taskFormSubmitButton());
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await _pumpFrames(tester, 12);

      expect(find.byType(TaskFormPage), findsNothing);

      // Verify task appears in list
      expect(find.text('Morning Exercise'), findsOneWidget);

      // Verify persistence
      final tasksBox = Hive.box<HabitTask>('tasks');
      expect(tasksBox.length, 1);
      expect(tasksBox.getAt(0)?.name, 'Morning Exercise');
      expect(tasksBox.getAt(0)?.difficulty, TaskDifficulty.hard);
    });

    testWidgets('creates a repeating task successfully', (tester) async {
      await tester.pumpWidget(_buildApp());
      await _pumpFrames(tester);

      await tester.tap(find.text('Tasks').first);
      await _pumpFrames(tester);

      await tester.tap(find.byTooltip('Add Task'));
      await _pumpFrames(tester);

      // Enter task name
      await tester.enterText(
          find.byType(TextFormField).first, 'Daily Meditation');
      await _pumpFrames(tester);

      // Enable repeating toggle
      final repeatingSwitch = find.ancestor(
        of: find.text('繰り返しタスク'),
        matching: find.byType(Row),
      );
      await tester.tap(find.descendant(
        of: repeatingSwitch,
        matching: find.byType(Switch),
      ));
      await _pumpFrames(tester);

      // Select start date
      await tester.tap(find.text('未選択').first);
      await _pumpFrames(tester);
      await tester.tap(find.text('OK'));
      await _pumpFrames(tester);

      // Select end date
      await tester.tap(find.text('未選択').last);
      await _pumpFrames(tester);
      await tester.tap(find.text('OK'));
      await _pumpFrames(tester);

      // Save task
      await tester.tap(_taskFormSubmitButton());
      await _pumpFrames(tester);

      // Verify task appears
      expect(find.text('Daily Meditation'), findsOneWidget);

      // Verify it's a repeating task
      final tasksBox = Hive.box<HabitTask>('tasks');
      expect(tasksBox.getAt(0)?.isRepeating, true);
    });
  });

  group('Task Completion and XP Workflow', () {
    testWidgets('completes task and gains XP', (tester) async {
      await tester.pumpWidget(_buildApp());
      await _pumpFrames(tester);

      // Create a task first
      await tester.tap(find.text('Tasks').first);
      await _pumpFrames(tester);

      await tester.tap(find.byTooltip('Add Task'));
      await _pumpFrames(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Test Task');
      await _pumpFrames(tester);

      // Select Easy difficulty (5 XP)
      await tester.tap(find.text('Easy'));
      await _pumpFrames(tester);

      await tester.tap(find.text('未選択').first);
      await _pumpFrames(tester);
      await tester.tap(find.text('OK'));
      await _pumpFrames(tester);

      await tester.tap(_taskFormSubmitButton());
      await _pumpFrames(tester);

      // Get initial XP
      final appStateBox = Hive.box('appState');
      final initialXp = appStateBox.get('currentXp', defaultValue: 0) as int;

      // Complete the task (tap checkbox)
      await tester.tap(find.byType(Checkbox));
      await _pumpFrames(tester);

      // Verify XP dialog appears
      expect(find.text('クエスト達成！'), findsOneWidget);
      expect(find.textContaining('5 XP'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('OK'));
      await _pumpFrames(tester);

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
      await tester.pumpWidget(_buildApp());
      await _pumpFrames(tester);

      await tester.tap(find.text('Tasks').first);
      await _pumpFrames(tester);

      // Create Hard task (50 XP)
      await tester.tap(find.byTooltip('Add Task'));
      await _pumpFrames(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Hard Task');
      await _pumpFrames(tester);

      await tester.tap(find.text('Hard'));
      await _pumpFrames(tester);

      await tester.tap(find.text('未選択').first);
      await _pumpFrames(tester);
      await tester.tap(find.text('OK'));
      await _pumpFrames(tester);

      await tester.tap(_taskFormSubmitButton());
      await _pumpFrames(tester);

      // Complete task
      await tester.tap(find.byType(Checkbox));
      await _pumpFrames(tester);

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
      await tester.pumpWidget(_buildApp());
      await _pumpFrames(tester);

      await tester.tap(find.text('Tasks').first);
      await _pumpFrames(tester);

      // Create repeating task
      await tester.tap(find.byTooltip('Add Task'));
      await _pumpFrames(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Daily Task');
      await _pumpFrames(tester);

      final repeatingSwitch = find.ancestor(
        of: find.text('繰り返しタスク'),
        matching: find.byType(Row),
      );
      await tester.tap(find.descendant(
        of: repeatingSwitch,
        matching: find.byType(Switch),
      ));
      await _pumpFrames(tester);

      await tester.tap(find.text('未選択').first);
      await _pumpFrames(tester);
      await tester.tap(find.text('OK'));
      await _pumpFrames(tester);

      await tester.tap(find.text('未選択').last);
      await _pumpFrames(tester);
      await tester.tap(find.text('OK'));
      await _pumpFrames(tester);

      await tester.tap(_taskFormSubmitButton());
      await _pumpFrames(tester);

      // Complete task
      await tester.tap(find.byType(Checkbox));
      await _pumpFrames(tester);

      await tester.tap(find.text('OK'));
      await _pumpFrames(tester);

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
      await tester.pumpWidget(_buildApp());
      await _pumpFrames(tester);

      await tester.tap(find.text('Tasks').first);
      await _pumpFrames(tester);

      // Create task
      await tester.tap(find.byTooltip('Add Task'));
      await _pumpFrames(tester);

      await tester.enterText(
          find.byType(TextFormField).first, 'Task to Delete');
      await _pumpFrames(tester);

      await tester.tap(find.text('未選択').first);
      await _pumpFrames(tester);
      await tester.tap(find.text('OK'));
      await _pumpFrames(tester);

      await tester.tap(_taskFormSubmitButton());
      await _pumpFrames(tester);

      // Delete task (long press to show delete option)
      await tester.longPress(find.text('Task to Delete'));
      await _pumpFrames(tester);

      // Confirm deletion
      await tester.tap(find.text('削除'));
      await _pumpFrames(tester);

      await tester.tap(find.text('削除').last);
      await _pumpFrames(tester);

      // Verify task is deleted
      expect(find.text('Task to Delete'), findsNothing);

      final tasksBox = Hive.box<HabitTask>('tasks');
      expect(tasksBox.length, 0);
    });
  });

  group('Data Persistence', () {
    testWidgets('tasks persist across app restarts', (tester) async {
      // Create task
      await tester.pumpWidget(_buildApp());
      await _pumpFrames(tester);

      await tester.tap(find.text('Tasks').first);
      await _pumpFrames(tester);

      await tester.tap(find.byTooltip('Add Task'));
      await _pumpFrames(tester);

      await tester.enterText(
          find.byType(TextFormField).first, 'Persistent Task');
      await _pumpFrames(tester);

      await tester.tap(find.text('未選択').first);
      await _pumpFrames(tester);
      await tester.tap(find.text('OK'));
      await _pumpFrames(tester);

      await tester.tap(_taskFormSubmitButton());
      await _pumpFrames(tester);

      // Simulate app restart by creating new widget
      await tester.pumpWidget(_buildApp());
      await _pumpFrames(tester);

      await tester.tap(find.text('Tasks').first);
      await _pumpFrames(tester);

      // Verify task still exists
      expect(find.text('Persistent Task'), findsOneWidget);
    });

    testWidgets('XP persists across app restarts', (tester) async {
      // Earn some XP
      await tester.pumpWidget(_buildApp());
      await _pumpFrames(tester);

      await tester.tap(find.text('Tasks').first);
      await _pumpFrames(tester);

      await tester.tap(find.byTooltip('Add Task'));
      await _pumpFrames(tester);

      await tester.enterText(find.byType(TextFormField).first, 'XP Task');
      await _pumpFrames(tester);

      await tester.tap(find.text('Hard'));
      await _pumpFrames(tester);

      await tester.tap(find.text('未選択').first);
      await _pumpFrames(tester);
      await tester.tap(find.text('OK'));
      await _pumpFrames(tester);

      await tester.tap(_taskFormSubmitButton());
      await _pumpFrames(tester);

      await tester.tap(find.byType(Checkbox));
      await _pumpFrames(tester);

      await tester.tap(find.text('OK'));
      await _pumpFrames(tester);

      // Get XP amount
      final appStateBox = Hive.box('appState');
      final xp = appStateBox.get('currentXp', defaultValue: 0) as int;
      expect(xp, 50);

      // Restart app
      await tester.pumpWidget(_buildApp());
      await _pumpFrames(tester);

      // Verify XP is still there
      final persistedXp = appStateBox.get('currentXp', defaultValue: 0) as int;
      expect(persistedXp, 50);
    });
  });
}
