// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

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
    tempDir = await Directory.systemTemp.createTemp('habit_penguin_test');
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

  testWidgets('Navigation shows Habit Penguin tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await pumpFrames(tester, 12);

    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Penguin'), findsOneWidget);

    await tester.tap(find.text('Tasks').first);
    await pumpFrames(tester, 12);

    expect(find.byTooltip('Add Task'), findsOneWidget);
  });
}
