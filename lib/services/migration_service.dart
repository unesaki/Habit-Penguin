import 'package:hive/hive.dart';

import '../models/habit_task.dart';
import '../models/task_completion_history.dart';

/// データベースのマイグレーションを管理するサービス
/// スキーマバージョンを管理し、必要に応じてデータ移行を実行
class MigrationService {
  static const String _versionKey = 'schema_version';
  static const int _currentVersion = 2;

  /// 初期化時にマイグレーションを実行
  static Future<void> migrate(Box appStateBox) async {
    final currentVersion = (appStateBox.get(_versionKey) as int?) ?? 0;

    if (currentVersion == _currentVersion) {
      // 最新バージョン: 何もしない
      return;
    }

    // バージョンごとのマイグレーション実行
    if (currentVersion < 1) {
      await _migrateToV1(appStateBox);
    }

    if (currentVersion < 2) {
      await _migrateToV2(appStateBox);
    }

    // バージョン番号を更新
    await appStateBox.put(_versionKey, _currentVersion);
  }

  /// バージョン1へのマイグレーション
  /// 初期バージョンなので、基本的には初期化処理
  static Future<void> _migrateToV1(Box appStateBox) async {
    // V1では特に移行処理は不要
    // 既存データがあればそのまま使用

    // XPが未設定の場合は0で初期化
    if (!appStateBox.containsKey('xp')) {
      await appStateBox.put('xp', 0);
    }
  }

  /// バージョン2へのマイグレーション
  /// 完了タスクの情報を履歴ボックスに移行
  static Future<void> _migrateToV2(Box appStateBox) async {
    final tasksBox = Hive.box<HabitTask>('tasks');
    final historyBox = Hive.box<TaskCompletionHistory>('completion_history');

    // 既存の完了済みタスクを履歴に移行
    for (var i = 0; i < tasksBox.length; i++) {
      final task = tasksBox.getAt(i);
      if (task == null) continue;

      // isCompletedがtrueの場合、履歴に追加
      // ignore: deprecated_member_use_from_same_package
      if (task.isCompleted &&
          // ignore: deprecated_member_use_from_same_package
          task.completedAt != null) {
        // 履歴に既に存在しないかチェック
        final alreadyExists = historyBox.values.any(
          (h) =>
              h.taskKey == i &&
              // ignore: deprecated_member_use_from_same_package
              h.completedAt.difference(task.completedAt!).inSeconds.abs() < 60,
        );

        if (!alreadyExists) {
          final history = TaskCompletionHistory(
            taskKey: i,
            // ignore: deprecated_member_use_from_same_package
            completedAt: task.completedAt!,
            // ignore: deprecated_member_use_from_same_package
            earnedXp: task.completionXp ?? 30, // デフォルトはNormal難易度
          );
          await historyBox.add(history);
        }

        // 単発タスクの場合はisCompletedをfalseに戻す
        // （繰り返しタスクは完了フラグを残す）
        if (!task.isRepeating) {
          // 単発タスクは既に完了しているので、
          // isCompletedをtrueのまま残して非表示にする
          // これは意図通りなので何もしない
        } else {
          // 繰り返しタスクはリセット（毎日完了できるように）
          // ignore: deprecated_member_use_from_same_package
          task.isCompleted = false;
          await task.save();
        }
      }
    }
  }

  /// 現在のスキーマバージョンを取得
  static int getCurrentVersion(Box appStateBox) {
    return (appStateBox.get(_versionKey) as int?) ?? 0;
  }
}
