import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:habit_penguin/main.dart';
import 'package:habit_penguin/models/habit_task.dart';
import 'package:habit_penguin/models/task_completion_history.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

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
  });

  tearDown(() async {
    await Hive.box<HabitTask>('tasks').clear();
    await Hive.box<TaskCompletionHistory>('completion_history').clear();
    await Hive.box('appState').clear();
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('MainScreen Navigation', () {
    testWidgets('shows bottom navigation with three tabs', (tester) async {
      await tester.pumpWidget(const HabitPenguinApp());
      await tester.pumpAndSettle();

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Penguin'), findsOneWidget);
    });

    testWidgets('starts on Home tab', (tester) async {
      await tester.pumpWidget(const HabitPenguinApp());
      await tester.pumpAndSettle();

      expect(find.text('今日のクエスト'), findsOneWidget);
    });

    testWidgets('switches to Tasks tab when tapped', (tester) async {
      await tester.pumpWidget(const HabitPenguinApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      expect(find.text('今日のタスク'), findsOneWidget);
    });

    testWidgets('switches to Penguin tab when tapped', (tester) async {
      await tester.pumpWidget(const HabitPenguinApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Penguin'));
      await tester.pumpAndSettle();

      expect(find.textContaining('ペンギンルーム'), findsOneWidget);
    });
  });

  group('Home Tab', () {
    testWidgets('shows empty state when no tasks', (tester) async {
      await tester.pumpWidget(const HabitPenguinApp());
      await tester.pumpAndSettle();

      expect(find.textContaining('今日のタスク'), findsOneWidget);
    });

    testWidgets('displays XP information', (tester) async {
      await tester.pumpWidget(const HabitPenguinApp());
      await tester.pumpAndSettle();

      expect(find.textContaining('XP'), findsWidgets);
      expect(find.textContaining('Lv'), findsWidgets);
    });

    testWidgets('shows penguin animation', (tester) async {
      await tester.pumpWidget(const HabitPenguinApp());
      await tester.pumpAndSettle();

      // AnimatedPenguinのImageが存在するかチェック
      expect(find.byType(Image), findsWidgets);
    });
  });

  group('Tasks Tab', () {
    testWidgets('shows add task button', (tester) async {
      await tester.pumpWidget(const HabitPenguinApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('opens task form when add button is tapped', (tester) async {
      await tester.pumpWidget(const HabitPenguinApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('新しいタスク'), findsOneWidget);
      expect(find.text('タスク名'), findsOneWidget);
    });

    testWidgets('shows empty state message when no tasks', (tester) async {
      await tester.pumpWidget(const HabitPenguinApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      expect(find.textContaining('タスクがありません'), findsOneWidget);
    });

    testWidgets('shows completed tasks section', (tester) async {
      await tester.pumpWidget(const HabitPenguinApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      expect(find.text('完了済み'), findsOneWidget);
    });
  });

  group('Task Form', () {
    testWidgets('requires task name', (tester) async {
      await tester.pumpWidget(const HabitPenguinApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Try to save without entering name
      await tester.tap(find.text('タスクを作成'));
      await tester.pumpAndSettle();

      expect(find.text('タスク名を入力してください'), findsOneWidget);
    });

    testWidgets('shows difficulty selector', (tester) async {
      await tester.pumpWidget(const HabitPenguinApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('Easy'), findsOneWidget);
      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);
    });

    testWidgets('shows icon selector', (tester) async {
      await tester.pumpWidget(const HabitPenguinApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('アイコン'), findsOneWidget);
      // Multiple icon options should be visible
      expect(find.byType(Icon), findsWidgets);
    });

    testWidgets('shows repeating task toggle', (tester) async {
      await tester.pumpWidget(const HabitPenguinApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('繰り返しタスク'), findsOneWidget);
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('shows reminder toggle', (tester) async {
      await tester.pumpWidget(const HabitPenguinApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('通知を受け取る'), findsOneWidget);
    });

    testWidgets('can close form with back button', (tester) async {
      await tester.pumpWidget(const HabitPenguinApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('新しいタスク'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('新しいタスク'), findsNothing);
      expect(find.text('今日のタスク'), findsOneWidget);
    });
  });

  group('Penguin Tab', () {
    testWidgets('shows under construction message', (tester) async {
      await tester.pumpWidget(const HabitPenguinApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Penguin'));
      await tester.pumpAndSettle();

      expect(find.textContaining('準備中'), findsOneWidget);
    });
  });
}
