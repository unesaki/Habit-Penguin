import 'package:hive/hive.dart';

part 'task_completion_history.g.dart';

/// タスクの完了履歴を表すモデル
/// 各完了記録は、タスクID、完了日時、獲得XPを保持する
@HiveType(typeId: 1)
class TaskCompletionHistory extends HiveObject {
  TaskCompletionHistory({
    required this.taskKey,
    required this.completedAt,
    required this.earnedXp,
    this.notes,
  });

  /// 完了したタスクのキー（Hiveボックス内のインデックス）
  @HiveField(0)
  int taskKey;

  /// 完了日時
  @HiveField(1)
  DateTime completedAt;

  /// 獲得した経験値
  @HiveField(2)
  int earnedXp;

  /// メモ（オプション）
  @HiveField(3)
  String? notes;

  /// 完了日（時刻を除いた日付のみ）
  DateTime get completedDate {
    return DateTime(
      completedAt.year,
      completedAt.month,
      completedAt.day,
    );
  }

  /// 今日の完了記録かどうか
  bool get isToday {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    return completedDate == todayDate;
  }

  /// 指定日の完了記録かどうか
  bool isOnDate(DateTime date) {
    final targetDate = DateTime(date.year, date.month, date.day);
    return completedDate == targetDate;
  }
}
