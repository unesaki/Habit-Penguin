import 'package:hive/hive.dart';

/// データベースのマイグレーションを管理するサービス
/// スキーマバージョンを管理し、必要に応じてデータ移行を実行
class MigrationService {
  static const String _versionKey = 'schema_version';
  static const int _currentVersion = 1;

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

    // 将来のバージョン対応例:
    // if (currentVersion < 2) {
    //   await _migrateToV2(appStateBox);
    // }

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

  // 将来のマイグレーション例
  // static Future<void> _migrateToV2(Box appStateBox) async {
  //   // 例: 新しいフィールドの追加や、データ構造の変更
  //   // タスクボックスを開いて、各タスクに新しいフィールドを追加
  //   final tasksBox = Hive.box<HabitTask>('tasks');
  //   for (var i = 0; i < tasksBox.length; i++) {
  //     final task = tasksBox.getAt(i);
  //     if (task != null) {
  //       // 新しいフィールドの設定など
  //       await task.save();
  //     }
  //   }
  // }

  /// 現在のスキーマバージョンを取得
  static int getCurrentVersion(Box appStateBox) {
    return (appStateBox.get(_versionKey) as int?) ?? 0;
  }
}
