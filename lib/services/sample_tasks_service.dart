import 'package:flutter/material.dart';
import '../models/habit_task.dart';
import '../repositories/task_repository.dart';

/// サンプルタスクを作成するサービス
class SampleTasksService {
  SampleTasksService(this._repository);

  final TaskRepository _repository;

  /// 日本語のサンプルタスクを作成
  Future<void> createSampleTasksJa() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final sampleTasks = [
      HabitTask(
        name: '朝の散歩',
        iconCodePoint: Icons.directions_walk.codePoint,
        reminderEnabled: true,
        difficulty: TaskDifficulty.easy,
        scheduledDate: today,
        repeatStart: today,
        reminderTime: const TimeOfDay(hour: 7, minute: 0),
      ),
      HabitTask(
        name: '読書 30分',
        iconCodePoint: Icons.menu_book.codePoint,
        reminderEnabled: true,
        difficulty: TaskDifficulty.normal,
        scheduledDate: today,
        repeatStart: today,
        reminderTime: const TimeOfDay(hour: 20, minute: 0),
      ),
      HabitTask(
        name: '水を8杯飲む',
        iconCodePoint: Icons.local_drink.codePoint,
        reminderEnabled: false,
        difficulty: TaskDifficulty.easy,
        scheduledDate: today,
        repeatStart: today,
      ),
      HabitTask(
        name: '筋トレ',
        iconCodePoint: Icons.fitness_center.codePoint,
        reminderEnabled: true,
        difficulty: TaskDifficulty.hard,
        scheduledDate: today,
        repeatStart: today,
        reminderTime: const TimeOfDay(hour: 18, minute: 0),
      ),
    ];

    for (final task in sampleTasks) {
      await _repository.addTask(task);
    }
  }

  /// 英語のサンプルタスクを作成
  Future<void> createSampleTasksEn() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final sampleTasks = [
      HabitTask(
        name: 'Morning Walk',
        iconCodePoint: Icons.directions_walk.codePoint,
        reminderEnabled: true,
        difficulty: TaskDifficulty.easy,
        scheduledDate: today,
        repeatStart: today,
        reminderTime: const TimeOfDay(hour: 7, minute: 0),
      ),
      HabitTask(
        name: 'Read for 30min',
        iconCodePoint: Icons.menu_book.codePoint,
        reminderEnabled: true,
        difficulty: TaskDifficulty.normal,
        scheduledDate: today,
        repeatStart: today,
        reminderTime: const TimeOfDay(hour: 20, minute: 0),
      ),
      HabitTask(
        name: 'Drink 8 glasses of water',
        iconCodePoint: Icons.local_drink.codePoint,
        reminderEnabled: false,
        difficulty: TaskDifficulty.easy,
        scheduledDate: today,
        repeatStart: today,
      ),
      HabitTask(
        name: 'Workout',
        iconCodePoint: Icons.fitness_center.codePoint,
        reminderEnabled: true,
        difficulty: TaskDifficulty.hard,
        scheduledDate: today,
        repeatStart: today,
        reminderTime: const TimeOfDay(hour: 18, minute: 0),
      ),
    ];

    for (final task in sampleTasks) {
      await _repository.addTask(task);
    }
  }
}
