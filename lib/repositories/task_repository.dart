import 'package:hive/hive.dart';

import '../models/habit_task.dart';

/// タスクデータへのアクセスを管理するRepository
/// Hiveへの直接アクセスをカプセル化し、ビジネスロジックを提供
class TaskRepository {
  TaskRepository(this._box);

  final Box<HabitTask> _box;

  /// すべてのタスクを取得
  List<HabitTask> getAllTasks() {
    final tasks = <HabitTask>[];
    for (var i = 0; i < _box.length; i++) {
      final task = _box.getAt(i);
      if (task != null) {
        tasks.add(task);
      }
    }
    return tasks;
  }

  /// インデックス指定でタスクを取得
  HabitTask? getTaskAt(int index) {
    return _box.getAt(index);
  }

  /// 未完了のタスクのみを取得（インデックス付き）
  List<MapEntry<int, HabitTask>> getOpenTasksWithIndex() {
    final openTasks = <MapEntry<int, HabitTask>>[];
    for (var i = 0; i < _box.length; i++) {
      final task = _box.getAt(i);
      if (task == null || task.isCompleted) continue;
      openTasks.add(MapEntry(i, task));
    }
    return openTasks;
  }

  /// 完了済みタスクのみを取得
  List<HabitTask> getCompletedTasks() {
    final completed = <HabitTask>[];
    for (var i = 0; i < _box.length; i++) {
      final task = _box.getAt(i);
      if (task != null && task.isCompleted) {
        completed.add(task);
      }
    }
    // 完了日時の降順でソート
    completed.sort((a, b) {
      final aDate = a.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return completed;
  }

  /// 指定日にアクティブなタスクを取得（インデックス付き）
  List<MapEntry<int, HabitTask>> getActiveTasksOn(
    DateTime date, {
    bool includeCompleted = false,
  }) {
    final activeTasks = <MapEntry<int, HabitTask>>[];
    for (var i = 0; i < _box.length; i++) {
      final task = _box.getAt(i);
      if (task == null) continue;
      if (!includeCompleted && task.isCompleted) continue;
      if (task.isActiveOn(date)) {
        activeTasks.add(MapEntry(i, task));
      }
    }
    return activeTasks;
  }

  /// 新しいタスクを追加
  Future<void> addTask(HabitTask task) async {
    await _box.add(task);
  }

  /// タスクを更新（既存のHiveObjectの場合）
  Future<void> updateTask(HabitTask task) async {
    await task.save();
  }

  /// インデックス指定でタスクを削除
  Future<void> deleteTaskAt(int index) async {
    await _box.deleteAt(index);
  }

  /// タスクを完了にする
  Future<void> completeTask(int index, {required int xpGained}) async {
    final task = _box.getAt(index);
    if (task == null || task.isCompleted) {
      return;
    }

    task
      ..isCompleted = true
      ..completedAt = DateTime.now()
      ..completionXp = xpGained;
    await task.save();
  }

  /// タスクの総数を取得
  int get taskCount => _box.length;

  /// Boxを取得（状態変化監視用）
  Box<HabitTask> get box => _box;
}
