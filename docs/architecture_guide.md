# Habit Penguin アーキテクチャガイド

このドキュメントは、Habit Penguinアプリのアーキテクチャパターンと実装の詳細を説明します。

## 概要

Habit Penguinは以下のアーキテクチャパターンを採用しています：

- **Repository Pattern**: データアクセスロジックのカプセル化
- **Service Pattern**: ビジネスロジックの集約
- **Riverpod**: 状態管理とDI（依存性注入）
- **Migration Service**: データベーススキーマのバージョン管理

## ディレクトリ構造

```
lib/
├── main.dart                 # アプリケーションのエントリーポイント
├── models/                   # データモデル
│   └── habit_task.dart       # タスクモデルとHiveアダプター
├── repositories/             # データアクセス層
│   └── task_repository.dart  # タスクデータのCRUD操作
├── services/                 # ビジネスロジック層
│   ├── xp_service.dart       # 経験値管理
│   └── migration_service.dart # データマイグレーション
└── providers/                # Riverpodプロバイダー
    └── providers.dart        # 全プロバイダーの定義
```

## 各層の責務

### 1. Models（モデル層）

**責務**: データ構造の定義

- `HabitTask`: タスクのデータ構造
- `HabitTaskAdapter`: Hiveでのシリアライズとデシリアライズ
- `TaskDifficulty`: タスクの難易度Enum

**特徴**:
- ビジネスロジックを含まない
- Hiveの`HiveObject`を継承し、永続化可能
- 基本的な計算メソッド（`isActiveOn`など）のみ持つ

### 2. Repositories（リポジトリ層）

**責務**: データの取得・保存・更新・削除

**TaskRepository** ([lib/repositories/task_repository.dart](lib/repositories/task_repository.dart)):

```dart
class TaskRepository {
  TaskRepository(this._box);

  final Box<HabitTask> _box;

  // タスクの取得
  List<HabitTask> getAllTasks()
  HabitTask? getTaskAt(int index)
  List<MapEntry<int, HabitTask>> getOpenTasksWithIndex()
  List<HabitTask> getCompletedTasks()
  List<MapEntry<int, HabitTask>> getActiveTasksOn(DateTime date)

  // タスクの変更
  Future<void> addTask(HabitTask task)
  Future<void> updateTask(HabitTask task)
  Future<void> deleteTaskAt(int index)
  Future<void> completeTask(int index, {required int xpGained})
}
```

**利点**:
- UIとデータアクセスの分離
- テスト容易性の向上
- Hiveの実装詳細を隠蔽

### 3. Services（サービス層）

**責務**: ビジネスロジックの実装

#### XpService ([lib/services/xp_service.dart](lib/services/xp_service.dart))

経験値に関するすべてのロジックを管理：

```dart
class XpService {
  // XPの取得・設定
  int getCurrentXp()
  Future<void> addXp(int amount)
  Future<void> setXp(int amount)

  // XP計算ロジック
  int calculateXpForDifficulty(TaskDifficulty difficulty)
  int calculateLevel()
  int xpToNextLevel()
}
```

**XP計算ルール**:
- Easy: 5 XP
- Normal: 30 XP
- Hard: 50 XP
- レベル計算: 100 XPごとに1レベルアップ

#### MigrationService ([lib/services/migration_service.dart](lib/services/migration_service.dart))

データベーススキーマのバージョン管理：

```dart
class MigrationService {
  static Future<void> migrate(Box appStateBox)
  static int getCurrentVersion(Box appStateBox)
}
```

**マイグレーション戦略**:
1. 現在のスキーマバージョンを`appState`ボックスに保存
2. アプリ起動時にバージョンをチェック
3. 必要に応じてマイグレーション関数を実行
4. 新しいバージョン番号を保存

**マイグレーション追加例**:
```dart
// 将来のバージョン2へのマイグレーション
static Future<void> _migrateToV2(Box appStateBox) async {
  // データ構造の変更処理
  final tasksBox = Hive.box<HabitTask>('tasks');
  for (var i = 0; i < tasksBox.length; i++) {
    final task = tasksBox.getAt(i);
    if (task != null) {
      // 新しいフィールドの追加など
      await task.save();
    }
  }
}
```

### 4. Providers（プロバイダー層）

**責務**: 依存性注入と状態管理

**主要なプロバイダー** ([lib/providers/providers.dart](lib/providers/providers.dart)):

```dart
// Repository/Serviceのプロバイダー
final taskRepositoryProvider = Provider<TaskRepository>(...)
final xpServiceProvider = Provider<XpService>(...)

// データストリームプロバイダー
final currentXpProvider = StreamProvider<int>(...)
final allTasksProvider = StreamProvider<List<HabitTask>>(...)
final openTasksProvider = StreamProvider<List<MapEntry<int, HabitTask>>>(...)
final completedTasksProvider = StreamProvider<List<HabitTask>>(...)
final todayActiveTasksProvider = StreamProvider<List<MapEntry<int, HabitTask>>>(...)
```

**プロバイダーの使い方**:

```dart
// ウィジェットでの使用例
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // データの監視
    final xpAsync = ref.watch(currentXpProvider);

    return xpAsync.when(
      data: (xp) => Text('XP: $xp'),
      loading: () => CircularProgressIndicator(),
      error: (e, st) => Text('Error: $e'),
    );
  }
}

// 一度だけ読み取る場合
final repository = ref.read(taskRepositoryProvider);
await repository.addTask(task);
```

## データフロー

### タスク完了の例

```
1. ユーザーが完了ボタンをタップ
   ↓
2. _completeTaskWithXp関数が呼ばれる
   ↓
3. TaskRepositoryからタスクを取得
   ↓
4. XpServiceでXPを計算
   ↓
5. TaskRepository.completeTask()でタスクを更新
   ↓
6. XpService.addXp()でXPを追加
   ↓
7. Hiveが変更を保存
   ↓
8. StreamProviderが変更を検知
   ↓
9. UIが自動的に更新される
```

## 状態管理の仕組み

### Riverpodによる状態の監視

1. **StreamProvider**がHiveの変更を定期的にポーリング（100msごと）
2. データが変更されたら、`.distinct()`で重複を除去
3. 変更があった場合のみウィジェットに通知
4. ウィジェットが自動的に再ビルドされる

### メリット

- **自動更新**: データが変わると自動的にUIが更新
- **最小限の再ビルド**: 必要な部分だけが再ビルドされる
- **テスト容易性**: モックリポジトリを使ったテストが簡単

## 初期化フロー

```dart
Future<void> main() async {
  // 1. Flutterバインディングの初期化
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Hiveの初期化
  await Hive.initFlutter();
  Hive.registerAdapter(HabitTaskAdapter());

  // 3. Boxを開く
  await Hive.openBox<HabitTask>('tasks');
  final appStateBox = await Hive.openBox('appState');

  // 4. データマイグレーション実行
  await MigrationService.migrate(appStateBox);

  // 5. アプリ起動（ProviderScopeでラップ）
  runApp(const ProviderScope(child: HabitPenguinApp()));
}
```

## ベストプラクティス

### 1. Repository経由でのみデータアクセス

❌ **悪い例**:
```dart
final box = Hive.box<HabitTask>('tasks');
await box.add(task); // UIから直接Hiveにアクセス
```

✅ **良い例**:
```dart
final repository = ref.read(taskRepositoryProvider);
await repository.addTask(task); // Repositoryを経由
```

### 2. ビジネスロジックはServiceに

❌ **悪い例**:
```dart
// UIでXP計算
final xp = task.difficulty == TaskDifficulty.easy ? 5 :
           task.difficulty == TaskDifficulty.normal ? 30 : 50;
```

✅ **良い例**:
```dart
final xpService = ref.read(xpServiceProvider);
final xp = xpService.calculateXpForDifficulty(task.difficulty);
```

### 3. ref.watchとref.readの使い分け

- **ref.watch**: データの変更を監視したい場合（buildメソッド内）
- **ref.read**: 一度だけ値を読み取りたい場合（イベントハンドラ内）

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  // 監視: データが変わると再ビルド
  final xp = ref.watch(currentXpProvider);

  return ElevatedButton(
    onPressed: () {
      // 一度だけ読み取り
      final repository = ref.read(taskRepositoryProvider);
      repository.addTask(task);
    },
    child: Text('追加'),
  );
}
```

## テスト戦略

### Repositoryのテスト

```dart
test('TaskRepository adds task correctly', () async {
  final box = await Hive.openBox<HabitTask>('test_tasks');
  final repository = TaskRepository(box);

  final task = HabitTask(name: 'Test', iconCodePoint: 1234);
  await repository.addTask(task);

  expect(repository.taskCount, 1);
  expect(repository.getAllTasks().first.name, 'Test');
});
```

### Serviceのテスト

```dart
test('XpService calculates XP correctly', () {
  final box = Hive.box('test_appState');
  final service = XpService(box);

  expect(service.calculateXpForDifficulty(TaskDifficulty.easy), 5);
  expect(service.calculateXpForDifficulty(TaskDifficulty.normal), 30);
  expect(service.calculateXpForDifficulty(TaskDifficulty.hard), 50);
});
```

## 今後の拡張性

### 新しいリポジトリの追加

例：統計情報を管理する`StatisticsRepository`

```dart
class StatisticsRepository {
  final Box _statsBox;

  Future<Map<String, int>> getWeeklyStats() async { ... }
  Future<int> getStreak() async { ... }
}

// プロバイダーの追加
final statisticsRepositoryProvider = Provider<StatisticsRepository>((ref) {
  final box = Hive.box('statistics');
  return StatisticsRepository(box);
});
```

### 新しいサービスの追加

例：通知を管理する`NotificationService`

```dart
class NotificationService {
  Future<void> scheduleNotification(HabitTask task) async { ... }
  Future<void> cancelNotification(int taskId) async { ... }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
```

## まとめ

このアーキテクチャにより、以下のメリットが得られます：

1. **保守性**: 各層の責務が明確で、変更の影響範囲が限定的
2. **テスト容易性**: 各コンポーネントを個別にテストできる
3. **拡張性**: 新しい機能の追加が容易
4. **可読性**: コードの意図が明確
5. **再利用性**: RepositoryやServiceは複数の画面で再利用可能

今後の開発では、このアーキテクチャパターンを維持しながら、新しい機能を追加していくことを推奨します。
