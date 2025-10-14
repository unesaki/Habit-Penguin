# CI/CD とモニタリング実装ガイド

このドキュメントでは、Habit Penguinアプリの継続的インテグレーション/デリバリー（CI/CD）とモニタリング機能の実装について説明します。

## 目次

1. [CI/CDパイプライン](#cicdパイプライン)
2. [クラッシュレポーティング（Sentry）](#クラッシュレポーティングsentry)
3. [アナリティクス（Firebase Analytics）](#アナリティクスfirebase-analytics)
4. [モニタリングのベストプラクティス](#モニタリングのベストプラクティス)

---

## CI/CDパイプライン

### GitHub Actions ワークフロー

GitHub Actionsを使用した自動化パイプラインを実装しています。

#### ワークフロー構成

**ファイル**: `.github/workflows/ci.yml`

#### 実行ジョブ

1. **静的解析 (analyze)**
   - コードフォーマットの検証
   - `flutter analyze` による静的解析
   - 依存パッケージの脆弱性チェック

2. **テスト (test)**
   - すべてのユニットテストを実行
   - カバレッジレポートを生成
   - Codecovへのアップロード（オプション）

3. **ビルド (build-android, build-ios, build-macos)**
   - 各プラットフォーム向けのビルド
   - ビルド成果物をアーティファクトとして保存

#### トリガー条件

- `main` ブランチへのプッシュ
- `develop` ブランチへのプッシュ
- `main` / `develop` ブランチへのプルリクエスト

#### ワークフローの特徴

```yaml
# 静的解析の例
- name: Analyze project
  run: flutter analyze

# テストとカバレッジ
- name: Run tests
  run: flutter test --coverage

# 依存関係チェック
- name: Check for outdated dependencies
  run: flutter pub outdated --json > pub_outdated.json || true
```

### ローカルでのCI検証

CIパイプラインをローカルで実行して事前検証できます：

```bash
# フォーマットチェック
dart format --output=none --set-exit-if-changed .

# 静的解析
flutter analyze

# テスト実行
flutter test

# 依存関係チェック
flutter pub outdated
```

### Codecov統合（オプション）

コードカバレッジをCodecovで追跡する場合：

1. Codecovアカウントを作成
2. GitHubリポジトリを連携
3. Codecov tokenをGitHub Secretsに追加: `CODECOV_TOKEN`
4. CI実行時に自動アップロード

---

## クラッシュレポーティング（Sentry）

### 概要

Sentryを使用してアプリのクラッシュとエラーを追跡します。

**実装ファイル**: `lib/services/monitoring_service.dart`

### セットアップ

#### 1. Sentryプロジェクトの作成

1. [Sentry](https://sentry.io/)でアカウントを作成
2. 新しいプロジェクトを作成（Flutter）
3. DSN（Data Source Name）を取得

#### 2. DSNの設定

`lib/main.dart` でDSNを設定：

```dart
await MonitoringService.instance.initialize(
  dsn: 'YOUR_SENTRY_DSN_HERE',
  enableInDebug: false, // デバッグモードでは無効
  environment: kDebugMode ? 'development' : 'production',
);
```

**セキュリティ注意**: DSNは機密情報ではありませんが、環境変数で管理することを推奨します。

```dart
// 推奨: 環境変数から読み込む
const sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

await MonitoringService.instance.initialize(
  dsn: sentryDsn,
  // ...
);
```

ビルド時に環境変数を指定：

```bash
flutter build apk --dart-define=SENTRY_DSN=your_dsn_here
```

#### 3. 初期化

アプリの起動時に自動的に初期化されます（`main.dart`）：

```dart
await SentryFlutter.init(
  (options) {
    options.dsn = 'YOUR_DSN';
    options.environment = kDebugMode ? 'development' : 'production';
    options.tracesSampleRate = 1.0; // 100%のトランザクションを記録
    options.enableAutoPerformanceTracing = true;
  },
  appRunner: () async {
    // アプリの初期化処理
  },
);
```

### 使用方法

#### エラーの記録

```dart
try {
  // リスクのある処理
  await riskyOperation();
} catch (e, stackTrace) {
  // エラーをSentryに送信
  await MonitoringService.instance.recordError(
    e,
    stackTrace,
    level: SentryLevel.error,
  );
}
```

#### カスタムメッセージの記録

```dart
await MonitoringService.instance.recordMessage(
  'Important operation completed',
  level: SentryLevel.info,
);
```

#### ブレッドクラムの追加

ユーザーの操作履歴を記録してエラー発生時のコンテキストを把握：

```dart
await MonitoringService.instance.addBreadcrumb(
  message: 'User navigated to task form',
  category: 'navigation',
  level: SentryLevel.info,
  data: {'task_id': '123'},
);
```

#### パフォーマンストラッキング

```dart
final transaction = MonitoringService.instance.startTransaction(
  name: 'task_completion_flow',
  operation: 'task_operation',
);

try {
  await completeTask();
  transaction.status = const SpanStatus.ok();
} catch (e) {
  transaction.status = const SpanStatus.internalError();
  rethrow;
} finally {
  await transaction.finish();
}
```

### 機能

- ✅ 自動クラッシュレポート
- ✅ ハンドルされた例外の記録
- ✅ ブレッドクラム（ユーザー操作履歴）
- ✅ パフォーマンスモニタリング
- ✅ ナビゲーショントラッキング
- ✅ ネイティブクラッシュのキャプチャ
- ✅ デバッグモードでは無効化（誤報防止）

### デバッグモードの動作

開発中は `enableInDebug: false` に設定されているため、Sentryへの送信は行われません。代わりにコンソールにログ出力されます。

---

## アナリティクス（Firebase Analytics）

### 概要

Firebase Analyticsを使用してユーザー行動を追跡します。

**実装ファイル**: `lib/services/analytics_service.dart`

### セットアップ

#### 1. Firebaseプロジェクトの作成

1. [Firebase Console](https://console.firebase.google.com/)にアクセス
2. 新しいプロジェクトを作成
3. アプリを登録（iOS, Android, macOS）

#### 2. プラットフォーム別設定

##### iOS

1. Firebase Consoleから `GoogleService-Info.plist` をダウンロード
2. `ios/Runner/` ディレクトリに配置
3. Xcodeでプロジェクトに追加

##### Android

1. Firebase Consoleから `google-services.json` をダウンロード
2. `android/app/` ディレクトリに配置
3. `android/build.gradle` を編集：

```gradle
buildscript {
  dependencies {
    classpath 'com.google.gms:google-services:4.4.2'
  }
}
```

4. `android/app/build.gradle` の最後に追加：

```gradle
apply plugin: 'com.google.gms.google-services'
```

##### macOS

1. Firebase Consoleから `GoogleService-Info.plist` をダウンロード
2. `macos/Runner/` ディレクトリに配置
3. `macos/Runner/DebugProfile.entitlements` と `macos/Runner/Release.entitlements` を編集：

```xml
<key>com.apple.security.network.client</key>
<true/>
```

#### 3. 初期化

`lib/main.dart` で初期化：

```dart
import 'package:firebase_core/firebase_core.dart';
import 'services/analytics_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebaseの初期化
  await Firebase.initializeApp();

  // Analyticsの初期化
  await AnalyticsService.instance.initialize();

  // ...
}
```

### 使用方法

#### イベントの記録

```dart
// カスタムイベント
await AnalyticsService.instance.logEvent(
  name: 'custom_event',
  parameters: {
    'key': 'value',
  },
);
```

#### タスク完了の記録

```dart
await AnalyticsService.instance.logTaskCompletion(
  difficulty: 'hard',
  xpGained: 50,
  currentStreak: 7,
);
```

#### タスク作成の記録

```dart
await AnalyticsService.instance.logTaskCreated(
  difficulty: 'normal',
  hasReminder: true,
  isRepeating: false,
);
```

#### 画面遷移の記録

```dart
await AnalyticsService.instance.logScreenView(
  screenName: 'task_form',
  screenClass: 'TaskFormPage',
);
```

#### ユーザープロパティの設定

```dart
await AnalyticsService.instance.setUserProperty(
  name: 'user_level',
  value: '5',
);
```

### Firebase設定なしでの動作

Firebase設定ファイルがない場合、`AnalyticsService` は安全にスキップされます。エラーは発生せず、デバッグログにメッセージが出力されます。

### トラッキングするイベント例

| イベント名 | パラメータ | 目的 |
|-----------|----------|------|
| `task_completed` | difficulty, xp_gained, current_streak | タスク完了の分析 |
| `task_created` | difficulty, has_reminder, is_repeating | タスク作成パターンの理解 |
| `level_up` | level, total_xp | ユーザーエンゲージメント測定 |
| `data_export` | format | データエクスポート機能の利用状況 |
| `data_deletion` | deletion_type | データ削除機能の利用状況 |

---

## モニタリングのベストプラクティス

### 1. エラーハンドリング

```dart
Future<void> performCriticalOperation() async {
  try {
    // リスクのある処理
    await criticalOperation();
  } catch (e, stackTrace) {
    // Sentryに記録
    await MonitoringService.instance.recordError(e, stackTrace);

    // ユーザーにフレンドリーなエラーメッセージを表示
    showErrorDialog('操作に失敗しました。もう一度お試しください。');
  }
}
```

### 2. パフォーマンスモニタリング

```dart
Future<void> loadTasks() async {
  final transaction = MonitoringService.instance.startTransaction(
    name: 'load_tasks',
    operation: 'data_load',
  );

  try {
    final tasks = await taskRepository.getAllTasks();
    transaction.status = const SpanStatus.ok();
    return tasks;
  } catch (e) {
    transaction.status = const SpanStatus.internalError();
    rethrow;
  } finally {
    await transaction.finish();
  }
}
```

### 3. ユーザーコンテキストの追加

```dart
// エラー発生時により詳細な情報を取得
await MonitoringService.instance.setContext('task_context', {
  'task_count': taskCount,
  'current_xp': currentXp,
  'user_level': userLevel,
});
```

### 4. アナリティクスのプライバシー配慮

```dart
// 個人情報を含まないようにする
await AnalyticsService.instance.logEvent(
  name: 'task_completed',
  parameters: {
    'difficulty': 'hard', // OK
    'task_name': taskName, // NG - 個人情報の可能性
  },
);
```

### 5. デバッグモードの活用

開発環境では詳細なログを出力し、本番環境ではノイズを減らす：

```dart
if (kDebugMode) {
  debugPrint('Task completion flow started');
}

// エラーは常に記録
await MonitoringService.instance.recordError(e, stackTrace);
```

### 6. CI/CDでの自動化

GitHub Actionsで自動的にチェック：

- ✅ コード品質（flutter analyze）
- ✅ テストカバレッジ
- ✅ 依存関係の脆弱性
- ✅ ビルド成功

---

## トラブルシューティング

### Sentryにエラーが送信されない

1. DSNが正しく設定されているか確認
2. デバッグモードでは送信されない（`enableInDebug: false`）
3. ネットワーク接続を確認
4. Sentryコンソールでプロジェクトのステータスを確認

### Firebase Analyticsが動作しない

1. `google-services.json` / `GoogleService-Info.plist` が正しい場所にあるか確認
2. Firebase Consoleでアプリが正しく登録されているか確認
3. ネットワーク権限が付与されているか確認（iOS/macOS）
4. Firebase Consoleのデバッグビューで確認（リアルタイム）

### CI/CDパイプラインが失敗する

1. ローカルで同じコマンドを実行して再現
2. 依存関係のバージョン競合をチェック
3. GitHub Actionsのログを詳細に確認
4. キャッシュをクリアして再実行

---

## セキュリティとプライバシー

### Sentryのデータ

- エラースタックトレース、デバイス情報、OS情報が送信されます
- 個人を特定できる情報（PII）は送信しないでください
- Sentryのデータ保持期間を設定して古いデータを自動削除

### Firebase Analyticsのデータ

- イベント名、パラメータ、デバイス情報が送信されます
- ユーザーの同意が必要な地域（EU等）では、GDPR準拠の実装を追加
- 個人情報を含むパラメータは送信しない

### 環境変数の管理

```bash
# .env ファイル（gitignoreに追加）
SENTRY_DSN=https://...
FIREBASE_API_KEY=...
```

GitHub Secretsに環境変数を追加してCI/CDで使用：

```yaml
env:
  SENTRY_DSN: ${{ secrets.SENTRY_DSN }}
```

---

## まとめ

### 実装済み機能

- ✅ GitHub ActionsによるCI/CDパイプライン
- ✅ Sentryによるクラッシュレポーティング
- ✅ Firebase Analytics基盤（設定待ち）
- ✅ 自動テスト実行
- ✅ 静的解析
- ✅ 依存関係チェック
- ✅ マルチプラットフォームビルド

### 次のステップ

1. **Sentryのセットアップ**
   - Sentryプロジェクトを作成
   - DSNを設定
   - エラー通知を設定

2. **Firebase Analyticsのセットアップ**
   - Firebaseプロジェクトを作成
   - プラットフォーム別設定ファイルを追加
   - アナリティクスイベントを実装

3. **CI/CDの最適化**
   - コードカバレッジ目標を設定（例: 80%以上）
   - 自動デプロイの追加
   - コード署名の自動化

4. **モニタリングダッシュボード**
   - Sentryでアラートルールを設定
   - Firebase Analyticsでカスタムレポートを作成
   - 週次/月次のレビューを実施

---

## 参考リンク

- [Sentry Flutter SDK](https://docs.sentry.io/platforms/flutter/)
- [Firebase Analytics](https://firebase.google.com/docs/analytics/get-started?platform=flutter)
- [GitHub Actions](https://docs.github.com/en/actions)
- [Flutter CI/CD Best Practices](https://docs.flutter.dev/deployment/cd)
