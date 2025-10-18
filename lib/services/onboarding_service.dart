import 'package:hive_flutter/hive_flutter.dart';

/// オンボーディング状態を管理するサービス
class OnboardingService {
  OnboardingService(this._box);

  final Box _box;
  static const String _hasCompletedOnboardingKey = 'hasCompletedOnboarding';

  /// オンボーディングが完了しているかどうかを取得
  bool get hasCompletedOnboarding {
    return _box.get(_hasCompletedOnboardingKey, defaultValue: false) as bool;
  }

  /// オンボーディングを完了としてマーク
  Future<void> completeOnboarding() async {
    await _box.put(_hasCompletedOnboardingKey, true);
  }

  /// オンボーディング状態をリセット（開発・テスト用）
  Future<void> resetOnboarding() async {
    await _box.put(_hasCompletedOnboardingKey, false);
  }
}
