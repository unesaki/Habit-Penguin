import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../models/habit_task.dart';
import '../repositories/task_repository.dart';
import '../services/xp_service.dart';

/// TaskRepositoryのプロバイダー
/// Hiveのtasksボックスからリポジトリを生成
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final box = Hive.box<HabitTask>('tasks');
  return TaskRepository(box);
});

/// XpServiceのプロバイダー
/// HiveのappStateボックスからサービスを生成
final xpServiceProvider = Provider<XpService>((ref) {
  final box = Hive.box('appState');
  return XpService(box);
});

/// 現在のXPを監視するプロバイダー
/// XpServiceの変化を検知して自動的に更新される
final currentXpProvider = StreamProvider<int>((ref) {
  final xpService = ref.watch(xpServiceProvider);

  return Stream.periodic(const Duration(milliseconds: 100))
      .asyncMap((_) => xpService.getCurrentXp())
      .distinct();
});

/// すべてのタスクを取得するプロバイダー
final allTasksProvider = StreamProvider<List<HabitTask>>((ref) {
  final repository = ref.watch(taskRepositoryProvider);

  return Stream.periodic(const Duration(milliseconds: 100))
      .asyncMap((_) => repository.getAllTasks())
      .distinct((prev, next) => prev.length == next.length);
});

/// 未完了タスク（インデックス付き）を取得するプロバイダー
final openTasksProvider =
    StreamProvider<List<MapEntry<int, HabitTask>>>((ref) {
  final repository = ref.watch(taskRepositoryProvider);

  return Stream.periodic(const Duration(milliseconds: 100))
      .asyncMap((_) => repository.getOpenTasksWithIndex())
      .distinct((prev, next) => prev.length == next.length);
});

/// 完了済みタスクを取得するプロバイダー
final completedTasksProvider = StreamProvider<List<HabitTask>>((ref) {
  final repository = ref.watch(taskRepositoryProvider);

  return Stream.periodic(const Duration(milliseconds: 100))
      .asyncMap((_) => repository.getCompletedTasks())
      .distinct((prev, next) => prev.length == next.length);
});

/// 今日アクティブなタスクを取得するプロバイダー
final todayActiveTasksProvider =
    StreamProvider<List<MapEntry<int, HabitTask>>>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  final today = DateTime.now();

  return Stream.periodic(const Duration(milliseconds: 100))
      .asyncMap((_) => repository.getActiveTasksOn(today))
      .distinct((prev, next) => prev.length == next.length);
});
