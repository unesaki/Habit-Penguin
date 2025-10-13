// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:habit_penguin/main.dart';
import 'package:habit_penguin/models/habit_task.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('habit_penguin_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(HabitTaskAdapter());
    }
    await Hive.openBox<HabitTask>('tasks');
    await Hive.openBox('appState');
  });

  tearDown(() async {
    await Hive.box<HabitTask>('tasks').clear();
    await Hive.box('appState').clear();
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  testWidgets('Navigation shows Habit Penguin tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HabitPenguinApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Habit Penguin'), findsWidgets);
    expect(find.byType(BottomNavigationBar), findsOneWidget);

    await tester.tap(find.text('Tasks'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('今日のタスク'), findsOneWidget);
  });
}
