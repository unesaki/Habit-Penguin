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
import 'package:habit_penguin/providers/providers.dart';
import 'package:habit_penguin/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late NotificationService notificationService;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('habit_penguin_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(HabitTaskAdapter());
    }
    await Hive.openBox<HabitTask>('tasks');
    await Hive.openBox('appState');
  });

  setUp(() async {
    notificationService = NotificationService.test();
    await Hive.box('appState')
        .put('hasCompletedOnboarding', true);
  });

  tearDown(() async {
    await Hive.box<HabitTask>('tasks').clear();
    await Hive.box('appState').clear();
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
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

  testWidgets('Navigation shows Habit Penguin tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Habit Penguin'), findsWidgets);
    expect(find.byType(BottomNavigationBar), findsOneWidget);

    await tester.tap(find.text('Tasks'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('今日のタスク'), findsOneWidget);
  });
}
