import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../models/habit_task.dart';
import '../models/task_completion_history.dart';
import '../repositories/completion_history_repository.dart';
import '../repositories/task_repository.dart';
import '../services/notification_service.dart';
import '../services/xp_service.dart';
import '../services/undo_service.dart';
import '../services/onboarding_service.dart';

/// CompletionHistoryRepositoryのプロバイダー
final completionHistoryRepositoryProvider =
    Provider<CompletionHistoryRepository>((ref) {
  final box = Hive.box<TaskCompletionHistory>('completion_history');
  return CompletionHistoryRepository(box);
});

/// TaskRepositoryのプロバイダー
/// Hiveのtasksボックスからリポジトリを生成
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final box = Hive.box<HabitTask>('tasks');
  final historyRepo = ref.watch(completionHistoryRepositoryProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  return TaskRepository(box, historyRepo, notificationService);
});

/// XpServiceのプロバイダー
/// HiveのappStateボックスからサービスを生成
final xpServiceProvider = Provider<XpService>((ref) {
  final box = Hive.box('appState');
  return XpService(box);
});

/// NotificationServiceのプロバイダー
/// シングルトンとしてサービスを提供
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// UndoServiceのプロバイダー
/// Undo/Redo機能を提供
final undoServiceProvider = ChangeNotifierProvider<UndoService>((ref) {
  return UndoService();
});

/// OnboardingServiceのプロバイダー
/// オンボーディング状態を管理
final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  final box = Hive.box('appState');
  return OnboardingService(box);
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
      .distinct(_habitTaskListsEqual);
});

/// 未完了タスク（インデックス付き）を取得するプロバイダー
final openTasksProvider = StreamProvider<List<MapEntry<int, HabitTask>>>((ref) {
  final repository = ref.watch(taskRepositoryProvider);

  return Stream.periodic(const Duration(milliseconds: 100))
      .asyncMap((_) => repository.getOpenTasksWithIndex())
      .distinct(_indexedTaskEntriesEqual);
});

/// 完了済みタスクを履歴とともに取得するプロバイダー
final completedTasksWithHistoryProvider =
    StreamProvider<List<MapEntry<int, TaskCompletionHistory>>>((ref) {
  final repository = ref.watch(taskRepositoryProvider);

  return Stream.periodic(const Duration(milliseconds: 100))
      .asyncMap((_) => repository.getCompletedTasksWithHistory())
      .distinct((prev, next) => prev.length == next.length);
});

/// 今日アクティブなタスクを取得するプロバイダー（完了済み除外）
final todayActiveTasksProvider =
    StreamProvider<List<MapEntry<int, HabitTask>>>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  final today = DateTime.now();

  return Stream.periodic(const Duration(milliseconds: 100))
      .asyncMap(
          (_) => repository.getActiveTasksOn(today, excludeCompleted: true))
      .distinct(_indexedTaskEntriesEqual);
});

/// 特定のタスクのストリークを取得するプロバイダー
final taskStreakProvider = Provider.family<int, int>((ref, taskKey) {
  final historyRepo = ref.watch(completionHistoryRepositoryProvider);
  return historyRepo.calculateStreak(taskKey);
});

/// 特定のタスクの最大ストリークを取得するプロバイダー
final taskMaxStreakProvider = Provider.family<int, int>((ref, taskKey) {
  final historyRepo = ref.watch(completionHistoryRepositoryProvider);
  return historyRepo.calculateMaxStreak(taskKey);
});

bool _habitTaskListsEqual(List<HabitTask> previous, List<HabitTask> next) {
  if (identical(previous, next)) {
    return true;
  }
  if (previous.length != next.length) {
    return false;
  }

  for (var i = 0; i < previous.length; i++) {
    if (!_habitTasksStructurallyEqual(previous[i], next[i])) {
      return false;
    }
  }
  return true;
}

bool _indexedTaskEntriesEqual(
  List<MapEntry<int, HabitTask>> previous,
  List<MapEntry<int, HabitTask>> next,
) {
  if (identical(previous, next)) {
    return true;
  }
  if (previous.length != next.length) {
    return false;
  }

  for (var i = 0; i < previous.length; i++) {
    final prevEntry = previous[i];
    final nextEntry = next[i];

    if (prevEntry.key != nextEntry.key) {
      return false;
    }
    if (!_habitTasksStructurallyEqual(prevEntry.value, nextEntry.value)) {
      return false;
    }
  }
  return true;
}

bool _habitTasksStructurallyEqual(HabitTask a, HabitTask b) {
  if (identical(a, b)) {
    return true;
  }

  return a.name == b.name &&
      a.iconCodePoint == b.iconCodePoint &&
      a.reminderEnabled == b.reminderEnabled &&
      a.difficulty == b.difficulty &&
      a.scheduledDate == b.scheduledDate &&
      a.repeatStart == b.repeatStart &&
      a.repeatEnd == b.repeatEnd &&
      a.reminderTime == b.reminderTime &&
      a.memo == b.memo;
}
