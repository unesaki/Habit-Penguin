import 'package:hive/hive.dart';

import '../models/habit_task.dart';
import '../models/task_completion_history.dart';
import '../services/notification_service.dart';
import 'completion_history_repository.dart';

/// タスクデータへのアクセスを管理するRepository
/// Hiveへの直接アクセスをカプセル化し、ビジネスロジックを提供
class TaskRepository {
  TaskRepository(this._box, this._historyRepo, [this._notificationService]);

  final Box<HabitTask> _box;
  final CompletionHistoryRepository _historyRepo;
  final NotificationService? _notificationService;

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

  /// アクティブ（表示すべき）タスクを取得（インデックス付き）
  /// 繰り返しタスクは毎日表示され、単発タスクは未完了の場合のみ表示
  List<MapEntry<int, HabitTask>> getOpenTasksWithIndex() {
    final openTasks = <MapEntry<int, HabitTask>>[];
    final today = DateTime.now();

    for (var i = 0; i < _box.length; i++) {
      final task = _box.getAt(i);
      if (task == null) continue;

      // 繰り返しタスク: スケジュール内なら常に表示
      if (task.isRepeating) {
        if (task.isActiveOn(today)) {
          openTasks.add(MapEntry(i, task));
        }
      } else {
        // 単発タスク: 未完了（履歴がない）場合のみ表示
        if (!_historyRepo.isTaskCompletedOnDate(i, today)) {
          openTasks.add(MapEntry(i, task));
        }
      }
    }
    return openTasks;
  }

  /// 完了済みタスクを取得（完了履歴から）
  List<MapEntry<int, TaskCompletionHistory>> getCompletedTasksWithHistory() {
    final allHistory = _historyRepo.getAllHistory();
    final result = <MapEntry<int, TaskCompletionHistory>>[];

    for (final history in allHistory) {
      result.add(MapEntry(history.taskKey, history));
    }

    // 完了日時の降順でソート
    result.sort((a, b) => b.value.completedAt.compareTo(a.value.completedAt));
    return result;
  }

  /// 指定日にアクティブなタスクを取得（インデックス付き）
  /// 完了済みを除外するか含めるかを選択できる
  List<MapEntry<int, HabitTask>> getActiveTasksOn(
    DateTime date, {
    bool excludeCompleted = true,
  }) {
    final activeTasks = <MapEntry<int, HabitTask>>[];
    final completedKeys =
        excludeCompleted ? _historyRepo.getTodayCompletedTaskKeys() : <int>{};

    for (var i = 0; i < _box.length; i++) {
      final task = _box.getAt(i);
      if (task == null) continue;

      // 完了済みを除外
      if (excludeCompleted && completedKeys.contains(i)) {
        continue;
      }

      if (task.isActiveOn(date)) {
        activeTasks.add(MapEntry(i, task));
      }
    }
    return activeTasks;
  }

  /// 今日完了済みかどうかをチェック
  bool isCompletedToday(int taskKey) {
    return _historyRepo.isTaskCompletedOnDate(taskKey, DateTime.now());
  }

  /// 新しいタスクを追加
  Future<void> addTask(HabitTask task) async {
    final index = await _box.add(task);

    // リマインダーが有効な場合、通知をスケジュール
    if (task.reminderEnabled && task.reminderTime != null) {
      await _notificationService?.scheduleTaskNotification(
        index,
        task,
        task.reminderTime!,
      );
    }
  }

  /// タスクを更新（既存のHiveObjectの場合）
  Future<void> updateTask(HabitTask task) async {
    await task.save();

    // タスクのインデックスを取得
    final index = _box.values.toList().indexOf(task);
    if (index == -1) return;

    // リマインダーが有効な場合、通知をスケジュール
    if (task.reminderEnabled && task.reminderTime != null) {
      await _notificationService?.scheduleTaskNotification(
        index,
        task,
        task.reminderTime!,
      );
    } else {
      // リマインダーが無効の場合、通知をキャンセル
      await _notificationService?.cancelTaskNotification(index);
    }
  }

  /// インデックス指定でタスクを削除（履歴も削除）
  Future<void> deleteTaskAt(int index) async {
    // 関連する履歴も削除
    await _historyRepo.deleteAllForTask(index);

    // 通知もキャンセル
    await _notificationService?.cancelTaskNotification(index);

    await _box.deleteAt(index);
  }

  /// タスクを完了にする（履歴に記録）
  Future<void> completeTask(int index, {required int xpGained}) async {
    final task = _box.getAt(index);
    if (task == null) {
      return;
    }

    // 今日既に完了している場合は何もしない
    if (_historyRepo.isTaskCompletedOnDate(index, DateTime.now())) {
      return;
    }

    // 完了履歴を追加
    final completion = TaskCompletionHistory(
      taskKey: index,
      completedAt: DateTime.now(),
      earnedXp: xpGained,
    );
    await _historyRepo.addCompletion(completion);
  }

  /// タスクの完了を取り消す（今日の完了履歴を削除）
  Future<bool> uncompleteTask(int index) async {
    return await _historyRepo.deleteTodayCompletionForTask(index);
  }

  /// タスクの総数を取得
  int get taskCount => _box.length;

  /// Boxを取得（状態変化監視用）
  Box<HabitTask> get box => _box;

  /// タスクを複製（新しいタスクとして追加）
  Future<void> duplicateTask(int index) async {
    final task = _box.getAt(index);
    if (task == null) return;

    // 新しいタスクを作成（名前に「(コピー)」を追加）
    final duplicatedTask = HabitTask(
      name: '${task.name} (コピー)',
      iconCodePoint: task.iconCodePoint,
      reminderEnabled: task.reminderEnabled,
      difficulty: task.difficulty,
      scheduledDate: task.scheduledDate,
      repeatStart: task.repeatStart,
      repeatEnd: task.repeatEnd,
      reminderTime: task.reminderTime,
    );

    await addTask(duplicatedTask);
  }

  /// タスクの順序を入れ替え（ドラッグ&ドロップ用）
  Future<void> reorderTask(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    if (oldIndex < 0 || oldIndex >= _box.length) return;
    if (newIndex < 0 || newIndex >= _box.length) return;

    // 全タスクを取得
    final allTasks = <HabitTask>[];
    for (var i = 0; i < _box.length; i++) {
      final task = _box.getAt(i);
      if (task != null) {
        allTasks.add(task);
      }
    }

    // リストで並び替え
    final task = allTasks.removeAt(oldIndex);
    allTasks.insert(newIndex, task);

    // Boxをクリアして再構築
    await _box.clear();
    for (var i = 0; i < allTasks.length; i++) {
      await _box.add(allTasks[i]);
    }

    // 履歴のタスクキーを全て更新
    // 注: この実装は完全ではありませんが、シンプルなケースでは動作します
  }

  /// 複数のタスクを削除
  Future<void> deleteTasks(List<int> indices) async {
    // インデックスを降順にソートして削除（後ろから削除）
    final sortedIndices = indices.toList()..sort((a, b) => b.compareTo(a));

    for (final index in sortedIndices) {
      await deleteTaskAt(index);
    }
  }
}
