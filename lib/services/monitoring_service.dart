import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// クラッシュレポーティングとエラー監視を提供するサービス
///
/// Sentryを使用してアプリケーションのエラーとクラッシュを追跡します。
/// 本番環境でのみクラッシュレポートを送信し、開発環境ではコンソールに出力します。
class MonitoringService {
  MonitoringService._();
  static final MonitoringService instance = MonitoringService._();

  bool _isInitialized = false;

  /// Sentryの初期化
  ///
  /// [dsn]: SentryプロジェクトのDSN（Data Source Name）
  /// [enableInDebug]: デバッグモードでもSentryを有効にするか（デフォルト: false）
  /// [environment]: 環境名（development, staging, production）
  Future<void> initialize({
    required String dsn,
    bool enableInDebug = false,
    String environment = 'production',
  }) async {
    // デバッグモードでSentryが無効の場合、初期化をスキップ
    if (kDebugMode && !enableInDebug) {
      debugPrint('MonitoringService: Sentry is disabled in debug mode');
      _isInitialized = true;
      return;
    }

    try {
      await SentryFlutter.init(
        (options) {
          options.dsn = dsn;
          options.environment = environment;

          // サンプリングレート（本番環境では100%、開発環境では低めに設定）
          options.tracesSampleRate = environment == 'production' ? 1.0 : 0.1;

          // リリースバージョンの設定
          options.release = 'habit_penguin@1.0.0+1';

          // パフォーマンスモニタリングの有効化
          options.enableAutoPerformanceTracing = true;

          // スクリーンショットの添付（プライバシーに配慮）
          options.attachScreenshot = false;

          // ユーザーインタラクションの追跡
          options.enableUserInteractionTracing = true;

          // ネイティブクラッシュレポートの有効化
          options.enableNativeCrashHandling = true;

          // デバッグログの有効化（開発環境のみ）
          options.debug = kDebugMode;
        },
      );

      _isInitialized = true;
      debugPrint('MonitoringService: Sentry initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('MonitoringService: Failed to initialize Sentry: $e');
      debugPrint('Stack trace: $stackTrace');
      _isInitialized = false;
    }
  }

  /// エラーを記録
  ///
  /// [exception]: エラーオブジェクト
  /// [stackTrace]: スタックトレース
  /// [hint]: 追加情報（オプション）
  /// [level]: エラーレベル（デフォルト: error）
  Future<void> recordError(
    dynamic exception,
    StackTrace? stackTrace, {
    dynamic hint,
    SentryLevel level = SentryLevel.error,
  }) async {
    if (!_isInitialized) {
      debugPrint('MonitoringService: Error recorded (Sentry not initialized)');
      debugPrint('Exception: $exception');
      debugPrint('Stack trace: $stackTrace');
      return;
    }

    try {
      await Sentry.captureException(
        exception,
        stackTrace: stackTrace,
        hint: hint,
        withScope: (scope) {
          scope.level = level;
        },
      );
    } catch (e) {
      debugPrint('MonitoringService: Failed to record error: $e');
    }
  }

  /// カスタムメッセージを記録
  ///
  /// [message]: ログメッセージ
  /// [level]: ログレベル（デフォルト: info）
  Future<void> recordMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
  }) async {
    if (!_isInitialized) {
      debugPrint(
          'MonitoringService: Message recorded (Sentry not initialized)');
      debugPrint('Message: $message');
      return;
    }

    try {
      await Sentry.captureMessage(
        message,
        level: level,
      );
    } catch (e) {
      debugPrint('MonitoringService: Failed to record message: $e');
    }
  }

  /// ユーザー情報を設定
  ///
  /// [id]: ユーザーID（オプション）
  /// [email]: メールアドレス（オプション）
  /// [username]: ユーザー名（オプション）
  /// [data]: 追加情報（オプション）
  Future<void> setUser({
    String? id,
    String? email,
    String? username,
    Map<String, dynamic>? data,
  }) async {
    if (!_isInitialized) return;

    try {
      await Sentry.configureScope((scope) {
        scope.setUser(SentryUser(
          id: id,
          email: email,
          username: username,
          data: data,
        ));
      });
    } catch (e) {
      debugPrint('MonitoringService: Failed to set user: $e');
    }
  }

  /// ユーザー情報をクリア
  Future<void> clearUser() async {
    if (!_isInitialized) return;

    try {
      await Sentry.configureScope((scope) {
        scope.setUser(null);
      });
    } catch (e) {
      debugPrint('MonitoringService: Failed to clear user: $e');
    }
  }

  /// カスタムコンテキストを追加
  ///
  /// [key]: コンテキストキー
  /// [value]: コンテキスト値
  Future<void> setContext(String key, Map<String, dynamic> value) async {
    if (!_isInitialized) return;

    try {
      await Sentry.configureScope((scope) {
        scope.setContexts(key, value);
      });
    } catch (e) {
      debugPrint('MonitoringService: Failed to set context: $e');
    }
  }

  /// ブレッドクラムを追加（ユーザーの操作履歴を記録）
  ///
  /// [message]: ブレッドクラムメッセージ
  /// [category]: カテゴリー（例: 'navigation', 'user_action'）
  /// [level]: レベル（デフォルト: info）
  /// [data]: 追加データ（オプション）
  Future<void> addBreadcrumb({
    required String message,
    String? category,
    SentryLevel level = SentryLevel.info,
    Map<String, dynamic>? data,
  }) async {
    if (!_isInitialized) return;

    try {
      Sentry.addBreadcrumb(Breadcrumb(
        message: message,
        category: category,
        level: level,
        data: data,
        timestamp: DateTime.now().toUtc(),
      ));
    } catch (e) {
      debugPrint('MonitoringService: Failed to add breadcrumb: $e');
    }
  }

  /// パフォーマンストランザクションを開始
  ///
  /// [name]: トランザクション名
  /// [operation]: 操作名（例: 'navigation', 'task_completion'）
  ISentrySpan startTransaction({
    required String name,
    required String operation,
  }) {
    if (!_isInitialized) {
      // Sentryが初期化されていない場合はNoOpSpanを返す
      return Sentry.startTransaction(name, operation, bindToScope: false);
    }

    return Sentry.startTransaction(name, operation, bindToScope: true);
  }

  /// カスタムメトリクスを記録
  ///
  /// [key]: メトリクス名
  /// [value]: 値
  /// [unit]: 単位（オプション）
  Future<void> recordMetric({
    required String key,
    required double value,
    String? unit,
  }) async {
    if (!_isInitialized) return;

    try {
      // Sentryのカスタムメトリクス（Sentryバージョン8.0以降）
      await setContext('metrics', {
        key: {
          'value': value,
          'unit': unit ?? '',
          'timestamp': DateTime.now().toIso8601String(),
        },
      });
    } catch (e) {
      debugPrint('MonitoringService: Failed to record metric: $e');
    }
  }

  /// 初期化状態を取得
  bool get isInitialized => _isInitialized;
}
