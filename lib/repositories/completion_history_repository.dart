import 'package:hive/hive.dart';

import '../models/task_completion_history.dart';

/// 完了履歴データへのアクセスを管理するRepository
class CompletionHistoryRepository {
  CompletionHistoryRepository(this._box);

  final Box<TaskCompletionHistory> _box;

  /// すべての完了履歴を取得
  List<TaskCompletionHistory> getAllHistory() {
    final history = <TaskCompletionHistory>[];
    for (var i = 0; i < _box.length; i++) {
      final record = _box.getAt(i);
      if (record != null) {
        history.add(record);
      }
    }
    return history;
  }

  /// 特定のタスクの完了履歴を取得
  List<TaskCompletionHistory> getHistoryForTask(int taskKey) {
    return getAllHistory().where((record) => record.taskKey == taskKey).toList()
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
  }

  /// 特定の日付の完了履歴を取得
  List<TaskCompletionHistory> getHistoryForDate(DateTime date) {
    return getAllHistory().where((record) => record.isOnDate(date)).toList()
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
  }

  /// 特定のタスクが特定の日に完了されているか確認
  bool isTaskCompletedOnDate(int taskKey, DateTime date) {
    return getAllHistory().any(
      (record) => record.taskKey == taskKey && record.isOnDate(date),
    );
  }

  /// 今日完了されたタスクのキーのリストを取得
  Set<int> getTodayCompletedTaskKeys() {
    final today = DateTime.now();
    return getAllHistory()
        .where((record) => record.isOnDate(today))
        .map((record) => record.taskKey)
        .toSet();
  }

  /// 期間内の完了履歴を取得
  List<TaskCompletionHistory> getHistoryInRange(
    DateTime startDate,
    DateTime endDate,
  ) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    return getAllHistory()
        .where(
          (record) =>
              !record.completedAt.isBefore(start) &&
              !record.completedAt.isAfter(end),
        )
        .toList()
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
  }

  /// 完了履歴を追加
  Future<void> addCompletion(TaskCompletionHistory completion) async {
    await _box.add(completion);
  }

  /// 完了履歴を削除（インデックス指定）
  Future<void> deleteAt(int index) async {
    await _box.deleteAt(index);
  }

  /// 特定のタスクの今日の完了記録を削除（アンドゥ用）
  Future<bool> deleteTodayCompletionForTask(int taskKey) async {
    final today = DateTime.now();
    for (var i = 0; i < _box.length; i++) {
      final record = _box.getAt(i);
      if (record != null &&
          record.taskKey == taskKey &&
          record.isOnDate(today)) {
        await _box.deleteAt(i);
        return true;
      }
    }
    return false;
  }

  /// 特定のタスクのすべての完了履歴を削除
  Future<void> deleteAllForTask(int taskKey) async {
    final toDelete = <int>[];
    for (var i = 0; i < _box.length; i++) {
      final record = _box.getAt(i);
      if (record != null && record.taskKey == taskKey) {
        toDelete.add(i);
      }
    }
    // 後ろから削除（インデックスのずれを防ぐ）
    for (final index in toDelete.reversed) {
      await _box.deleteAt(index);
    }
  }

  /// タスクの並び替え後にタスクキーを更新
  Future<void> updateTaskKeyAfterReorder(int oldKey, int newKey) async {
    for (var i = 0; i < _box.length; i++) {
      final record = _box.getAt(i);
      if (record != null && record.taskKey == oldKey) {
        record.taskKey = newKey;
        await record.save();
      }
    }
  }

  /// ストリーク（連続達成日数）を計算
  int calculateStreak(int taskKey) {
    final history = getHistoryForTask(taskKey);
    if (history.isEmpty) return 0;

    // 日付のみのセットに変換（時刻は無視）
    final completedDates = history.map((h) => h.completedDate).toSet().toList()
      ..sort((a, b) => b.compareTo(a));

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // 今日または昨日から始まっていなければストリークは0
    final latestDate = completedDates.first;
    final yesterday = todayDate.subtract(const Duration(days: 1));

    if (latestDate != todayDate && latestDate != yesterday) {
      return 0;
    }

    // 連続日数をカウント
    var streak = 0;
    var currentDate = latestDate;

    for (final date in completedDates) {
      if (date == currentDate) {
        streak++;
        currentDate = currentDate.subtract(const Duration(days: 1));
      } else if (date.isBefore(currentDate)) {
        // 日付が飛んでいる
        break;
      }
    }

    return streak;
  }

  /// 最大ストリークを計算
  int calculateMaxStreak(int taskKey) {
    final history = getHistoryForTask(taskKey);
    if (history.isEmpty) return 0;

    final completedDates = history.map((h) => h.completedDate).toSet().toList()
      ..sort();

    var maxStreak = 1;
    var currentStreak = 1;

    for (var i = 1; i < completedDates.length; i++) {
      final diff = completedDates[i].difference(completedDates[i - 1]).inDays;

      if (diff == 1) {
        currentStreak++;
        maxStreak = currentStreak > maxStreak ? currentStreak : maxStreak;
      } else {
        currentStreak = 1;
      }
    }

    return maxStreak;
  }

  /// 完了率を計算（期間内）
  double calculateCompletionRate(int taskKey, DateTime start, DateTime end) {
    final history = getHistoryInRange(start, end)
        .where((record) => record.taskKey == taskKey)
        .toList();

    final totalDays = end.difference(start).inDays + 1;
    final completedDays = history.map((h) => h.completedDate).toSet().length;

    return totalDays > 0 ? completedDays / totalDays : 0.0;
  }

  /// Boxを取得（状態変化監視用）
  Box<TaskCompletionHistory> get box => _box;
}
