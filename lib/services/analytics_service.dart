import 'package:flutter/foundation.dart';

/// アナリティクスサービス
///
/// アプリの利用状況を追跡するためのサービスです。
///
/// **注意**: Firebase Analyticsを使用するには、以下の設定が必要です：
///
/// 1. Firebase プロジェクトの作成
///    - Firebase Console (https://console.firebase.google.com/) でプロジェクトを作成
///
/// 2. iOS設定
///    - Firebase Console から GoogleService-Info.plist をダウンロード
///    - ios/Runner/ に配置
///
/// 3. Android設定
///    - Firebase Console から google-services.json をダウンロード
///    - android/app/ に配置
///    - android/build.gradle に以下を追加:
///      ```gradle
///      buildscript {
///        dependencies {
///          classpath 'com.google.gms:google-services:4.4.2'
///        }
///      }
///      ```
///    - android/app/build.gradle の最後に追加:
///      ```gradle
///      apply plugin: 'com.google.gms.google-services'
///      ```
///
/// 4. macOS設定
///    - Firebase Console から GoogleService-Info.plist をダウンロード
///    - macos/Runner/ に配置
///    - macos/Runner/DebugProfile.entitlements と macos/Runner/Release.entitlements に以下を追加:
///      ```xml
///      <key>com.apple.security.network.client</key>
///      <true/>
///      ```
///
/// 5. main.dart で初期化:
///    ```dart
///    await Firebase.initializeApp();
///    await AnalyticsService.instance.initialize();
///    ```
///
/// Firebase設定が完了していない場合、このサービスは安全にスキップされます（エラーは発生しません）。
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  bool _isInitialized = false;
  // Firebase Analyticsのインスタンス（動的にインポート）
  // ignore: unused_field
  dynamic _analytics;

  /// アナリティクスの初期化
  ///
  /// Firebase設定がない場合は静かに失敗し、アナリティクスは無効になります。
  Future<void> initialize() async {
    try {
      // Firebase Analyticsパッケージがインポートされている場合のみ初期化
      // 実際の実装では firebase_analytics パッケージをインポートして使用
      // import 'package:firebase_analytics/firebase_analytics.dart';
      // _analytics = FirebaseAnalytics.instance;

      _isInitialized = true;
      debugPrint('AnalyticsService: Initialized (mock mode - Firebase not configured)');
    } catch (e) {
      debugPrint('AnalyticsService: Failed to initialize: $e');
      _isInitialized = false;
    }
  }

  /// イベントを記録
  ///
  /// [name]: イベント名（例: 'task_completed', 'level_up'）
  /// [parameters]: イベントパラメータ
  Future<void> logEvent({
    required String name,
    Map<String, Object?>? parameters,
  }) async {
    if (!_isInitialized) {
      debugPrint('AnalyticsService: Event logged (not initialized): $name');
      return;
    }

    try {
      // await _analytics?.logEvent(name: name, parameters: parameters);
      debugPrint('AnalyticsService: Event logged: $name with $parameters');
    } catch (e) {
      debugPrint('AnalyticsService: Failed to log event: $e');
    }
  }

  /// タスク完了イベントを記録
  Future<void> logTaskCompletion({
    required String difficulty,
    required int xpGained,
    required int currentStreak,
  }) async {
    await logEvent(
      name: 'task_completed',
      parameters: {
        'difficulty': difficulty,
        'xp_gained': xpGained,
        'current_streak': currentStreak,
      },
    );
  }

  /// タスク作成イベントを記録
  Future<void> logTaskCreated({
    required String difficulty,
    required bool hasReminder,
    required bool isRepeating,
  }) async {
    await logEvent(
      name: 'task_created',
      parameters: {
        'difficulty': difficulty,
        'has_reminder': hasReminder,
        'is_repeating': isRepeating,
      },
    );
  }

  /// レベルアップイベントを記録
  Future<void> logLevelUp({
    required int level,
    required int totalXp,
  }) async {
    await logEvent(
      name: 'level_up',
      parameters: {
        'level': level,
        'total_xp': totalXp,
      },
    );
  }

  /// データエクスポートイベントを記録
  Future<void> logDataExport({
    required String format,
  }) async {
    await logEvent(
      name: 'data_export',
      parameters: {
        'format': format,
      },
    );
  }

  /// データ削除イベントを記録
  Future<void> logDataDeletion({
    required String type,
  }) async {
    await logEvent(
      name: 'data_deletion',
      parameters: {
        'deletion_type': type,
      },
    );
  }

  /// 画面遷移を記録
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    if (!_isInitialized) {
      debugPrint('AnalyticsService: Screen view (not initialized): $screenName');
      return;
    }

    try {
      // await _analytics?.logScreenView(
      //   screenName: screenName,
      //   screenClass: screenClass ?? screenName,
      // );
      debugPrint('AnalyticsService: Screen view: $screenName');
    } catch (e) {
      debugPrint('AnalyticsService: Failed to log screen view: $e');
    }
  }

  /// ユーザープロパティを設定
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    if (!_isInitialized) return;

    try {
      // await _analytics?.setUserProperty(name: name, value: value);
      debugPrint('AnalyticsService: User property set: $name = $value');
    } catch (e) {
      debugPrint('AnalyticsService: Failed to set user property: $e');
    }
  }

  /// ユーザーIDを設定
  Future<void> setUserId(String? userId) async {
    if (!_isInitialized) return;

    try {
      // await _analytics?.setUserId(id: userId);
      debugPrint('AnalyticsService: User ID set: $userId');
    } catch (e) {
      debugPrint('AnalyticsService: Failed to set user ID: $e');
    }
  }

  /// アナリティクスの有効/無効を設定
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    if (!_isInitialized) return;

    try {
      // await _analytics?.setAnalyticsCollectionEnabled(enabled);
      debugPrint('AnalyticsService: Analytics collection enabled: $enabled');
    } catch (e) {
      debugPrint('AnalyticsService: Failed to set analytics collection: $e');
    }
  }

  /// 初期化状態を取得
  bool get isInitialized => _isInitialized;
}
