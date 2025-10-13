import 'package:hive/hive.dart';

import '../models/habit_task.dart';

/// 経験値（XP）管理を担当するサービスクラス
class XpService {
  XpService(this._appStateBox);

  final Box _appStateBox;

  static const String _xpKey = 'xp';

  /// 現在の総経験値を取得
  int getCurrentXp() {
    return (_appStateBox.get(_xpKey) as int?) ?? 0;
  }

  /// 経験値を追加
  Future<void> addXp(int amount) async {
    final currentXp = getCurrentXp();
    await _appStateBox.put(_xpKey, currentXp + amount);
  }

  /// 経験値を設定（直接上書き）
  Future<void> setXp(int amount) async {
    await _appStateBox.put(_xpKey, amount);
  }

  /// タスクの難易度に応じた獲得経験値を計算
  int calculateXpForDifficulty(TaskDifficulty difficulty) {
    switch (difficulty) {
      case TaskDifficulty.easy:
        return 5;
      case TaskDifficulty.normal:
        return 30;
      case TaskDifficulty.hard:
        return 50;
    }
  }

  /// 現在の経験値からレベルを計算（将来的な拡張用）
  int calculateLevel() {
    final xp = getCurrentXp();
    // シンプルなレベル計算式: 100XPごとにレベルアップ
    return (xp / 100).floor() + 1;
  }

  /// 次のレベルまでに必要なXPを計算
  int xpToNextLevel() {
    final currentXp = getCurrentXp();
    final currentLevel = calculateLevel();
    final nextLevelXp = currentLevel * 100;
    return nextLevelXp - currentXp;
  }

  /// AppState Boxを取得（状態変化監視用）
  Box get box => _appStateBox;
}
