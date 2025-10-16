import 'package:hive/hive.dart';

import '../models/habit_task.dart';
import '../models/task_completion_history.dart';

/// データ削除機能を提供するサービス
/// GDPR/CCPAに準拠したユーザーデータの完全削除をサポート
class DataDeletionService {
  /// すべてのユーザーデータを削除
  /// GDPR/CCPA準拠: ユーザーの「忘れられる権利」に対応
  Future<void> deleteAllUserData() async {
    try {
      // 各Boxをクリア
      await _clearBox('tasks');
      await _clearBox('completion_history');
      await _clearBox('appState');

      // 通知もクリア（NotificationServiceを使用する場合）
      // await notificationService.cancelAllNotifications();
    } catch (e) {
      throw DataDeletionException('データの削除に失敗しました: $e');
    }
  }

  /// タスクデータのみを削除（完了履歴は保持）
  Future<void> deleteTasksOnly() async {
    try {
      await _clearBox('tasks');
    } catch (e) {
      throw DataDeletionException('タスクデータの削除に失敗しました: $e');
    }
  }

  /// 完了履歴のみを削除（タスクは保持）
  Future<void> deleteCompletionHistoryOnly() async {
    try {
      await _clearBox('completion_history');
    } catch (e) {
      throw DataDeletionException('完了履歴の削除に失敗しました: $e');
    }
  }

  /// XPデータのみを削除（タスクと履歴は保持）
  Future<void> deleteXpDataOnly() async {
    try {
      final appStateBox = Hive.box('appState');
      await appStateBox.delete('xp');
    } catch (e) {
      throw DataDeletionException('XPデータの削除に失敗しました: $e');
    }
  }

  /// 指定期間より古い完了履歴を削除
  Future<int> deleteOldCompletionHistory(Duration olderThan) async {
    try {
      final historyBox = Hive.box<TaskCompletionHistory>('completion_history');
      final cutoffDate = DateTime.now().subtract(olderThan);
      var deletedCount = 0;

      // 後ろから削除していく（インデックスのずれを防ぐ）
      for (var i = historyBox.length - 1; i >= 0; i--) {
        final history = historyBox.getAt(i);
        if (history != null && history.completedAt.isBefore(cutoffDate)) {
          await historyBox.deleteAt(i);
          deletedCount++;
        }
      }

      return deletedCount;
    } catch (e) {
      throw DataDeletionException('古い履歴の削除に失敗しました: $e');
    }
  }

  /// データ削除前の確認情報を取得
  Future<DataDeletionSummary> getDeletionSummary() async {
    final tasksBox = Hive.box<HabitTask>('tasks');
    final historyBox = Hive.box<TaskCompletionHistory>('completion_history');
    final appStateBox = Hive.box('appState');

    return DataDeletionSummary(
      taskCount: tasksBox.length,
      completionHistoryCount: historyBox.length,
      currentXp: appStateBox.get('xp', defaultValue: 0) as int,
      hasData: tasksBox.isNotEmpty ||
          historyBox.isNotEmpty ||
          appStateBox.containsKey('xp'),
    );
  }

  /// Boxをクリアするヘルパーメソッド
  Future<void> _clearBox(String boxName) async {
    if (Hive.isBoxOpen(boxName)) {
      final box = Hive.box(boxName);
      await box.clear();
    }
  }

  /// データ削除後の検証
  Future<bool> verifyDataDeletion() async {
    final tasksBox = Hive.box<HabitTask>('tasks');
    final historyBox = Hive.box<TaskCompletionHistory>('completion_history');
    final appStateBox = Hive.box('appState');

    return tasksBox.isEmpty &&
        historyBox.isEmpty &&
        !appStateBox.containsKey('xp');
  }
}

/// データ削除のサマリー情報
class DataDeletionSummary {
  final int taskCount;
  final int completionHistoryCount;
  final int currentXp;
  final bool hasData;

  DataDeletionSummary({
    required this.taskCount,
    required this.completionHistoryCount,
    required this.currentXp,
    required this.hasData,
  });

  String get summary {
    if (!hasData) {
      return '削除するデータがありません。';
    }

    final items = <String>[];
    if (taskCount > 0) items.add('タスク: $taskCount件');
    if (completionHistoryCount > 0) items.add('完了履歴: $completionHistoryCount件');
    if (currentXp > 0) items.add('XP: $currentXp');

    return '以下のデータが削除されます:\n${items.join('\n')}';
  }
}

/// データ削除時の例外
class DataDeletionException implements Exception {
  final String message;

  DataDeletionException(this.message);

  @override
  String toString() => message;
}
