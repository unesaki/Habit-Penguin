import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:habit_penguin/models/habit_task.dart';
import 'package:habit_penguin/services/xp_service.dart';

void main() {
  late Directory tempDir;
  late Box appStateBox;
  late XpService xpService;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('xp_service_test');
    Hive.init(tempDir.path);
    appStateBox = await Hive.openBox('appState');
    xpService = XpService(appStateBox);
  });

  tearDown(() async {
    await appStateBox.clear();
    await appStateBox.close();
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  group('XpService', () {
    group('calculateXpForDifficulty', () {
      test('returns correct XP for easy task', () {
        expect(xpService.calculateXpForDifficulty(TaskDifficulty.easy), 5);
      });

      test('returns correct XP for normal task', () {
        expect(xpService.calculateXpForDifficulty(TaskDifficulty.normal), 30);
      });

      test('returns correct XP for hard task', () {
        expect(xpService.calculateXpForDifficulty(TaskDifficulty.hard), 50);
      });
    });

    group('XP management', () {
      test('starts with 0 XP', () {
        expect(xpService.getCurrentXp(), 0);
      });

      test('adds XP correctly', () async {
        await xpService.addXp(50);
        expect(xpService.getCurrentXp(), 50);

        await xpService.addXp(30);
        expect(xpService.getCurrentXp(), 80);
      });

      test('allows setting XP directly', () async {
        await xpService.setXp(100);
        expect(xpService.getCurrentXp(), 100);

        await xpService.setXp(50);
        expect(xpService.getCurrentXp(), 50);
      });
    });

    group('Level calculation', () {
      test('level 1 at 0-99 XP', () async {
        await xpService.setXp(0);
        expect(xpService.calculateLevel(), 1);

        await xpService.setXp(50);
        expect(xpService.calculateLevel(), 1);

        await xpService.setXp(99);
        expect(xpService.calculateLevel(), 1);
      });

      test('level 2 at 100-199 XP', () async {
        await xpService.setXp(100);
        expect(xpService.calculateLevel(), 2);

        await xpService.setXp(150);
        expect(xpService.calculateLevel(), 2);

        await xpService.setXp(199);
        expect(xpService.calculateLevel(), 2);
      });

      test('level 5 at 400 XP', () async {
        await xpService.setXp(400);
        expect(xpService.calculateLevel(), 5);
      });

      test('level 10 at 900 XP', () async {
        await xpService.setXp(900);
        expect(xpService.calculateLevel(), 10);
      });
    });
  });
}
