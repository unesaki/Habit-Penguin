# テストガイド

## 概要

Habit Penguinアプリの品質保証のため、包括的なテストスイートを実装しました。ユニットテスト、ウィジェットテスト、インテグレーションテストをカバーしています。

## テスト構成

### ユニットテスト

ビジネスロジックとデータモデルの動作を検証します。

#### 1. XpService テスト (`test/services/xp_service_test.dart`)

**テスト対象:**
- XP計算ロジック
- 難易度別のXP獲得量
- レベル計算

**主要テストケース:**
- ✅ Easy: 5 XP, Normal: 30 XP, Hard: 50 XP
- ✅ XPの加算と設定機能
- ✅ レベル計算（100XPごとにレベルアップ）
- ✅ データの永続化

```dart
test('returns correct XP for hard task', () {
  expect(xpService.calculateXpForDifficulty(TaskDifficulty.hard), 50);
});

test('level 2 at 100-199 XP', () async {
  await xpService.setXp(150);
  expect(xpService.calculateLevel(), 2);
});
```

#### 2. CompletionHistoryRepository テスト (`test/repositories/completion_history_repository_test.dart`)

**テスト対象:**
- 完了履歴の追加・取得
- ストリーク計算アルゴリズム
- 日付ベースの完了チェック
- 履歴の削除

**主要テストケース:**
- ✅ 完了履歴の記録
- ✅ 特定タスクの履歴取得
- ✅ 今日の完了チェック
- ✅ 連続達成日数（ストリーク）の計算
- ✅ 最大ストリークの追跡
- ✅ 日付が飛んだ場合のストリークリセット
- ✅ 同日の複数完了の処理

```dart
test('counts consecutive days correctly', () async {
  final now = DateTime.now();

  // 今日
  await repository.addCompletion(TaskCompletionHistory(...));
  // 昨日
  await repository.addCompletion(TaskCompletionHistory(...));
  // 2日前
  await repository.addCompletion(TaskCompletionHistory(...));

  expect(repository.calculateStreak(0), 3);
});

test('streak breaks on missing day', () async {
  // 今日と昨日は完了、一昨日は未完了、3日前は完了
  // → ストリークは2になる
  expect(repository.calculateStreak(0), 2);
});
```

#### 3. HabitTask モデルテスト (`test/models/habit_task_test.dart`)

**テスト対象:**
- タスクタイプ判定（単発/繰り返し）
- 日付範囲でのアクティブ状態
- copyWithメソッドの動作

**主要テストケース:**
- ✅ 繰り返しタスクの判定
- ✅ 指定日のアクティブ状態チェック
- ✅ 日付範囲の境界値テスト
- ✅ タスクのコピーと更新
- ✅ 単発タスク↔繰り返しタスクの切り替え

```dart
test('repeating task is active within date range', () {
  final task = HabitTask(
    name: 'Test Task',
    iconCodePoint: Icons.check.codePoint,
    repeatStart: DateTime(2025, 1, 1),
    repeatEnd: DateTime(2025, 12, 31),
  );

  expect(task.isActiveOn(DateTime(2025, 6, 15)), true);
  expect(task.isActiveOn(DateTime(2024, 12, 31)), false);
  expect(task.isActiveOn(DateTime(2026, 1, 1)), false);
});
```

#### 4. TaskCompletionHistory モデルテスト (`test/models/task_completion_history_test.dart`)

**テスト対象:**
- 完了日時の正規化
- 日付比較ロジック
- メモ機能

**主要テストケース:**
- ✅ 時刻を除いた日付の取得
- ✅ 時刻の違いを無視した日付比較
- ✅ データの整合性

```dart
test('returns date without time', () {
  final history = TaskCompletionHistory(
    taskKey: 0,
    completedAt: DateTime(2025, 6, 15, 14, 30, 45),
    earnedXp: 30,
  );

  final date = history.completedDate;
  expect(date.hour, 0);
  expect(date.minute, 0);
});
```

### ウィジェットテスト

UIコンポーネントの表示と操作を検証します。

#### main_screen_test.dart (`test/widget/main_screen_test.dart`)

**テスト対象:**
- ナビゲーションの動作
- 各タブの表示内容
- タスクフォームの操作

**主要テストケース:**
- ✅ 3つのタブ（Tasks, Home, Penguin）の表示
- ✅ タブ切り替え機能
- ✅ タスク追加ボタンの表示
- ✅ タスクフォームの開閉
- ✅ フォーム入力のバリデーション
- ✅ 難易度・アイコン選択UI
- ✅ 繰り返しタスクトグル
- ✅ リマインダートグル

```dart
testWidgets('opens task form when add button is tapped', (tester) async {
  await tester.pumpWidget(const HabitPenguinApp());
  await tester.pumpAndSettle();

  await tester.tap(find.text('Tasks'));
  await tester.pumpAndSettle();

  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();

  expect(find.text('新しいタスク'), findsOneWidget);
});
```

### インテグレーションテスト

エンドツーエンドのワークフローを検証します。

#### task_workflow_test.dart (`test/integration/task_workflow_test.dart`)

**テスト対象:**
- タスクの作成から完了までの流れ
- XP獲得プロセス
- データの永続化

**主要テストケース:**
- ✅ 単発タスクの作成
- ✅ 繰り返しタスクの作成
- ✅ タスク完了とXP獲得
- ✅ 難易度別XP獲得量の確認
- ✅ 繰り返しタスクの複数回完了
- ✅ タスクの削除
- ✅ アプリ再起動後のデータ保持

```dart
testWidgets('completes task and gains XP', (tester) async {
  // タスク作成
  // ...タスク作成のステップ...

  // タスク完了
  await tester.tap(find.byType(Checkbox));
  await tester.pumpAndSettle();

  // XPダイアログ確認
  expect(find.text('クエスト達成！'), findsOneWidget);
  expect(find.textContaining('5 XP'), findsOneWidget);

  // XPが加算されたことを確認
  final appStateBox = Hive.box('appState');
  final finalXp = appStateBox.get('currentXp', defaultValue: 0) as int;
  expect(finalXp, initialXp + 5);
});
```

## テストの実行

### すべてのテストを実行

```bash
flutter test
```

### ユニットテストのみ実行

```bash
flutter test test/services/ test/repositories/ test/models/
```

### 特定のテストファイルを実行

```bash
flutter test test/services/xp_service_test.dart
```

### 特定のテストケースを実行

```bash
flutter test --plain-name 'returns correct XP for hard task'
```

## テスト結果

### 現在のテストカバレッジ

**ユニットテスト: 57個のテストすべて成功 ✅**

- XpService: 8テスト
- CompletionHistoryRepository: 19テスト
- HabitTask: 18テスト
- TaskCompletionHistory: 12テスト

```
00:01 +57: All tests passed!
```

### カバレッジ領域

✅ **完全カバレッジ:**
- XP計算ロジック
- ストリーク計算アルゴリズム
- タスクモデルのビジネスロジック
- 完了履歴の管理

⚠️ **部分カバレッジ:**
- ウィジェットテスト（基本的なUIテストは実装済み）
- インテグレーションテスト（主要フローは実装済み）

🔲 **未カバレッジ:**
- NotificationServiceの単体テスト
- TaskRepositoryの統合テスト
- エラーハンドリングのエッジケース

## テストのベストプラクティス

### 1. テストの命名規則

```dart
test('メソッド名 動作 期待結果', () {
  // 例: 'calculateStreak returns 0 for task with no history'
});
```

### 2. AAA パターンの使用

- **Arrange（準備）**: テストデータをセットアップ
- **Act（実行）**: テスト対象のメソッドを実行
- **Assert（検証）**: 期待される結果を確認

```dart
test('adds XP correctly', () async {
  // Arrange
  await xpService.addXp(50);

  // Act
  await xpService.addXp(30);

  // Assert
  expect(xpService.getCurrentXp(), 80);
});
```

### 3. テストデータの分離

各テストは独立して実行できる必要があります。`setUp`と`tearDown`を使用してテストデータをクリーンに保ちます。

```dart
setUp(() async {
  tempDir = await Directory.systemTemp.createTemp('test');
  Hive.init(tempDir.path);
  // ...初期化...
});

tearDown() async {
  await Hive.deleteFromDisk();
  await tempDir.delete(recursive: true);
});
```

### 4. エッジケースのテスト

- 境界値（0, -1, 最大値）
- null/空データ
- 異常なシーケンス

## CI/CD統合

### GitHub Actions設定例

```yaml
name: Flutter Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter test
      - run: flutter analyze
```

## 今後の改善

### 短期的な改善
1. NotificationServiceのユニットテスト追加
2. TaskRepositoryの完全なテストカバレッジ
3. エラーハンドリングのテスト強化

### 長期的な改善
1. テストカバレッジレポートの自動生成
2. パフォーマンステストの追加
3. E2Eテストの拡充
4. ビジュアルリグレッションテスト

## トラブルシューティング

### よくある問題

#### Hiveの初期化エラー

```dart
// 解決策: TestWidgetsFlutterBinding.ensureInitialized()を追加
TestWidgetsFlutterBinding.ensureInitialized();
```

#### ProviderScope not foundエラー

```dart
// 解決策: WidgetをProviderScopeでラップ
await tester.pumpWidget(
  const ProviderScope(
    child: HabitPenguinApp(),
  ),
);
```

#### 非同期テストのタイムアウト

```dart
// 解決策: pumpAndSettleを使用
await tester.pumpAndSettle();
```

## まとめ

現在のテストスイートは、Habit Penguinアプリのコアビジネスロジックを包括的にカバーしています。すべてのユニットテストが成功しており、データモデル、リポジトリ、サービスの信頼性が保証されています。

今後は、UIテストとインテグレーションテストの安定化、そしてCI/CDパイプラインへの統合を進めることで、さらに堅牢なアプリケーションを実現できます。
