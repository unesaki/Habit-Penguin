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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late NotificationService notificationService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('widget_test');
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

  Future<void> pumpFrames(WidgetTester tester, [int times = 6]) async {
    for (var i = 0; i < times; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  group('MainScreen Navigation', () {
    testWidgets('shows bottom navigation with three tabs', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester, 12);

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Penguin'), findsOneWidget);
    });

    testWidgets('starts on Home tab', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester);

      expect(find.text('おかえり！'), findsOneWidget);
    });

    testWidgets('switches to Tasks tab when tapped', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester);

      await tester.tap(find.text('Tasks').first);
      await pumpFrames(tester);

      expect(find.text('今日のタスク'), findsOneWidget);
    });

    testWidgets('switches to Penguin tab when tapped', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester);

      await tester.tap(find.text('Penguin').first);
      await pumpFrames(tester);

      expect(find.textContaining('ペンギンルーム'), findsOneWidget);
    });
  });

  group('Home Tab', () {
    testWidgets('shows empty state when no tasks', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester);

      expect(find.text('今日のタスク'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows create task callout', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester, 12);

      expect(find.text('今日のタスクを作成しよう'), findsOneWidget);
    });

    testWidgets('shows penguin animation', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester);

      // AnimatedPenguinのImageが存在するかチェック
      expect(find.byType(Image), findsWidgets);
    });
  });

  group('Tasks Tab', () {
    testWidgets('shows add task button', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester);

      await tester.tap(find.text('Tasks').first);
      await pumpFrames(tester);

      expect(find.byTooltip('Add Task'), findsOneWidget);
    });

    testWidgets('opens task form when add button is tapped', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester);

      await tester.tap(find.text('Tasks').first);
      await pumpFrames(tester);

      await tester.tap(find.byTooltip('Add Task'));
      await pumpFrames(tester, 12);

      expect(find.text('タスクを作成'), findsAtLeastNWidgets(1));
      expect(find.text('タスク名'), findsOneWidget);
    });

    testWidgets('shows empty state message when no tasks', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester);

      await tester.tap(find.text('Tasks').first);
      await pumpFrames(tester);

      expect(
        find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_EmptyStateWidget',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.add_task), findsOneWidget);
    });

    testWidgets('shows completed tasks section', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester);

      await tester.tap(find.text('Tasks').first);
      await pumpFrames(tester);

      expect(find.text('完了済み'), findsOneWidget);
    });
  });

  group('Task Form', () {
    testWidgets('requires task name', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester);

      await tester.tap(find.text('Tasks').first);
      await pumpFrames(tester);

      await tester.tap(find.byTooltip('Add Task'));
      await pumpFrames(tester, 12);

      expect(find.text('タスクを作成'), findsWidgets);

      // Try to save without entering name
      await tester.tap(find.text('タスクを作成').last);
      await pumpFrames(tester);

      final tasksBox = Hive.box<HabitTask>('tasks');
      expect(tasksBox.isEmpty, isTrue);
    });

    testWidgets('shows difficulty selector', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester);

      await tester.tap(find.text('Tasks').first);
      await pumpFrames(tester);

      await tester.tap(find.byTooltip('Add Task'));
      await pumpFrames(tester, 12);

      expect(find.text('Easy'), findsOneWidget);
      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);
    });

    testWidgets('shows icon selector', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester);

      await tester.tap(find.text('Tasks').first);
      await pumpFrames(tester);

      await tester.tap(find.byTooltip('Add Task'));
      await pumpFrames(tester, 12);

      expect(find.text('アイコン'), findsOneWidget);
      // Multiple icon options should be visible
      expect(find.byType(Icon), findsWidgets);
    });

    testWidgets('shows repeating task toggle', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester);

      await tester.tap(find.text('Tasks').first);
      await pumpFrames(tester);

      await tester.tap(find.byTooltip('Add Task'));
      await pumpFrames(tester, 12);

      expect(find.text('繰り返しタスク'), findsOneWidget);
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('shows reminder toggle', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester);

      await tester.tap(find.text('Tasks').first);
      await pumpFrames(tester);

      await tester.tap(find.byTooltip('Add Task'));
      await pumpFrames(tester);

      expect(find.text('通知を受け取る'), findsOneWidget);
    });

    testWidgets('can close form with back button', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester);

      await tester.tap(find.text('Tasks').first);
      await pumpFrames(tester);

      await tester.tap(find.byTooltip('Add Task'));
      await pumpFrames(tester);

      expect(find.text('タスクを作成'), findsWidgets);

      await tester.pageBack();
      await pumpFrames(tester, 12);

      expect(find.byType(TaskFormPage), findsNothing);
      expect(find.text('今日のタスク'), findsAtLeastNWidgets(1));
    });
  });

  group('Penguin Tab', () {
    testWidgets('shows under construction message', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester);

      await tester.tap(find.text('Penguin').first);
      await pumpFrames(tester);

      expect(find.textContaining('準備中'), findsOneWidget);
    });
  });
}
