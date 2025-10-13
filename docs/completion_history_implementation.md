# タスク完了履歴管理の実装ドキュメント

このドキュメントは、タスク完了状態と履歴管理の見直しの実装内容を説明します。

## 実装概要

従来は`HabitTask`の`isCompleted`フラグで完了状態を管理していましたが、以下の問題がありました：

- タスクを完了すると二度と表示されない
- 繰り返しタスクでも1回完了したら終わり
- 日々の達成履歴やストリーク（連続達成日数）が記録されない

これらを解決するため、**履歴ベースの完了管理**に移行しました。

## アーキテクチャの変更

### Before（旧アーキテクチャ）

```
HabitTask {
  isCompleted: bool      // 完了フラグ
  completedAt: DateTime?  // 完了日時
  completionXp: int?      // 獲得XP
}
```

**問題点:**
- 1つのフラグで完了状態を管理
- 履歴情報が保持されない
- 繰り返しタスクが実現できない

### After（新アーキテクチャ）

```
HabitTask {
  // isCompleted, completedAt, completionXpは非推奨
  // マイグレーション用に残存
}

TaskCompletionHistory {
  taskKey: int          // 完了したタスクのキー
  completedAt: DateTime // 完了日時
  earnedXp: int         // 獲得XP
  notes: String?        // メモ（将来の拡張用）
}
```

**利点:**
- 完了履歴を個別に記録
- 同じタスクを何度でも完了できる
- ストリークや統計情報の計算が可能
- 履歴の削除・修正が柔軟

## 新規作成ファイル

### 1. TaskCompletionHistory モデル

**ファイル:** [lib/models/task_completion_history.dart](../lib/models/task_completion_history.dart)

```dart
@HiveType(typeId: 1)
class TaskCompletionHistory extends HiveObject {
  @HiveField(0) int taskKey;
  @HiveField(1) DateTime completedAt;
  @HiveField(2) int earnedXp;
  @HiveField(3) String? notes;

  // 完了日（時刻を除いた日付のみ）
  DateTime get completedDate;

  // 今日の完了記録かどうか
  bool get isToday;

  // 指定日の完了記録かどうか
  bool isOnDate(DateTime date);
}
```

**特徴:**
- Hive TypeId: 1（HabitTaskは0）
- `completedAt`は完全な日時を保持
- `completedDate`で日付のみを取得可能

### 2. CompletionHistoryRepository

**ファイル:** [lib/repositories/completion_history_repository.dart](../lib/repositories/completion_history_repository.dart)

**主要メソッド:**

```dart
class CompletionHistoryRepository {
  // 取得系
  List<TaskCompletionHistory> getAllHistory()
  List<TaskCompletionHistory> getHistoryForTask(int taskKey)
  List<TaskCompletionHistory> getHistoryForDate(DateTime date)
  bool isTaskCompletedOnDate(int taskKey, DateTime date)
  Set<int> getTodayCompletedTaskKeys()

  // 追加・削除系
  Future<void> addCompletion(TaskCompletionHistory completion)
  Future<bool> deleteTodayCompletionForTask(int taskKey)
  Future<void> deleteAllForTask(int taskKey)

  // ストリーク計算
  int calculateStreak(int taskKey)           // 現在のストリーク
  int calculateMaxStreak(int taskKey)         // 最大ストリーク

  // 統計
  double calculateCompletionRate(int taskKey, DateTime start, DateTime end)
}
```

**ストリーク計算ロジック:**

```dart
int calculateStreak(int taskKey) {
  // 1. 完了履歴を日付のセットに変換
  final completedDates = history.map((h) => h.completedDate).toSet();

  // 2. 最新の完了日が今日または昨日でなければ0
  if (latestDate != today && latestDate != yesterday) {
    return 0;
  }

  // 3. 連続した日付をカウント
  var streak = 0;
  var currentDate = latestDate;

  for (final date in completedDates) {
    if (date == currentDate) {
      streak++;
      currentDate = currentDate.subtract(Duration(days: 1));
    } else if (date.isBefore(currentDate)) {
      break; // 日付が飛んでいる
    }
  }

  return streak;
}
```

## TaskRepository の更新

### 主な変更点

1. **コンストラクタに履歴リポジトリを追加**

```dart
class TaskRepository {
  TaskRepository(this._box, this._historyRepo);

  final Box<HabitTask> _box;
  final CompletionHistoryRepository _historyRepo;
}
```

2. **完了判定を履歴ベースに変更**

```dart
// 旧: isCompletedフラグで判定
List<MapEntry<int, HabitTask>> getOpenTasksWithIndex() {
  for (var i = 0; i < _box.length; i++) {
    final task = _box.getAt(i);
    if (task == null || task.isCompleted) continue; // 旧方式
    openTasks.add(MapEntry(i, task));
  }
}

// 新: 履歴で判定
List<MapEntry<int, HabitTask>> getOpenTasksWithIndex() {
  for (var i = 0; i < _box.length; i++) {
    final task = _box.getAt(i);
    if (task == null) continue;

    // 繰り返しタスク: スケジュール内なら常に表示
    if (task.isRepeating) {
      if (task.isActiveOn(today)) {
        openTasks.add(MapEntry(i, task));
      }
    } else {
      // 単発タスク: 未完了（履歴がない）場合のみ表示
      if (!_historyRepo.isTaskCompletedOnDate(i, today)) {
        openTasks.add(MapEntry(i, task));
      }
    }
  }
}
```

3. **完了メソッドの変更**

```dart
Future<void> completeTask(int index, {required int xpGained}) async {
  final task = _box.getAt(index);
  if (task == null) return;

  // 今日既に完了している場合は何もしない
  if (_historyRepo.isTaskCompletedOnDate(index, DateTime.now())) {
    return;
  }

  // 完了履歴を追加
  final completion = TaskCompletionHistory(
    taskKey: index,
    completedAt: DateTime.now(),
    earnedXp: xpGained,
  );
  await _historyRepo.addCompletion(completion);

  // 単発タスクの場合は、マイグレーション用にisCompletedも設定
  if (!task.isRepeating) {
    task.isCompleted = true;
    await task.save();
  }
}
```

4. **完了取り消し機能の追加**

```dart
Future<bool> uncompleteTask(int index) async {
  return await _historyRepo.deleteTodayCompletionForTask(index);
}
```

## プロバイダーの更新

### 新規プロバイダー

```dart
// CompletionHistoryRepository
final completionHistoryRepositoryProvider =
    Provider<CompletionHistoryRepository>(...);

// 完了済みタスクを履歴とともに取得
final completedTasksWithHistoryProvider =
    StreamProvider<List<MapEntry<int, TaskCompletionHistory>>>(...);

// ストリーク取得（family provider）
final taskStreakProvider =
    Provider.family<int, int>((ref, taskKey) { ... });

final taskMaxStreakProvider =
    Provider.family<int, int>((ref, taskKey) { ... });
```

### 既存プロバイダーの更新

```dart
// TaskRepositoryに履歴リポジトリを渡す
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final box = Hive.box<HabitTask>('tasks');
  final historyRepo = ref.watch(completionHistoryRepositoryProvider);
  return TaskRepository(box, historyRepo);
});
```

## データマイグレーション（V1→V2）

**ファイル:** [lib/services/migration_service.dart](../lib/services/migration_service.dart)

### マイグレーション内容

```dart
static Future<void> _migrateToV2(Box appStateBox) async {
  final tasksBox = Hive.box<HabitTask>('tasks');
  final historyBox = Hive.box<TaskCompletionHistory>('completion_history');

  // 既存の完了済みタスクを履歴に移行
  for (var i = 0; i < tasksBox.length; i++) {
    final task = tasksBox.getAt(i);
    if (task == null) continue;

    if (task.isCompleted && task.completedAt != null) {
      // 履歴に追加
      final history = TaskCompletionHistory(
        taskKey: i,
        completedAt: task.completedAt!,
        earnedXp: task.completionXp ?? 30,
      );
      await historyBox.add(history);

      // 繰り返しタスクはリセット
      if (task.isRepeating) {
        task.isCompleted = false;
        await task.save();
      }
    }
  }
}
```

**実行タイミング:**
- アプリ起動時に`MigrationService.migrate()`が実行される
- スキーマバージョンが2未満の場合のみ実行
- 完了後、バージョンを2に更新

## UI の変更

### 1. ストリーク表示の追加

**TasksTab の _TaskListTile:**

```dart
class _TaskListTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyRepo = ref.watch(completionHistoryRepositoryProvider);
    final streak = historyRepo.calculateStreak(taskIndex);

    // ストリーク表示
    if (streak > 0)
      Row(
        children: [
          Icon(Icons.local_fire_department, size: 14, color: Colors.orange),
          Text('$streak日連続'),
        ],
      )
  }
}
```

### 2. 完了済みタスクの表示

**CompletedTasksPage:**

```dart
final completedTasksAsync = ref.watch(completedTasksWithHistoryProvider);

// 履歴とタスク情報を組み合わせて表示
itemBuilder: (context, index) {
  final entry = completed[index];
  final task = taskRepository.getTaskAt(entry.key);
  final history = entry.value;

  return ListTile(
    title: Text(task.name),
    subtitle: Text('獲得XP: ${history.earnedXp} • '
                   '完了日: ${_formatDateLabel(history.completedAt)}'),
  );
}
```

### 3. 完了チェックの改善

```dart
Future<void> _completeTaskWithXp(...) async {
  // 今日既に完了済みかチェック
  if (repository.isCompletedToday(index)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('本日は既に完了しています')),
    );
    return;
  }

  // 完了処理（履歴に記録）
  await repository.completeTask(index, xpGained: gainedXp);
}
```

## 動作の変化

### 繰り返しタスクの挙動

**Before:**
1. タスク作成（繰り返し設定）
2. 完了ボタンを押す → `isCompleted = true`
3. 二度と表示されない ❌

**After:**
1. タスク作成（繰り返し設定）
2. 完了ボタンを押す → 履歴に記録、タスクは残る
3. 翌日、また表示される ✅
4. 毎日完了できる ✅
5. ストリークが記録される ✅

### 単発タスクの挙動

**Before:**
1. タスク作成（単発）
2. 完了ボタンを押す → `isCompleted = true`
3. 完了済みタスクに表示

**After:**
1. タスク作成（単発）
2. 完了ボタンを押す → 履歴に記録、`isCompleted = true`（後方互換性）
3. 完了済みタスクに表示（履歴から取得）
4. タスクリストには表示されない（`isCompleted = true`のため）

## 将来の拡張性

### 1. 統計機能

```dart
// 週次・月次の達成率
final weeklyRate = historyRepo.calculateCompletionRate(
  taskKey,
  DateTime.now().subtract(Duration(days: 7)),
  DateTime.now(),
);

// 完了時間帯の分析
final completionTimes = historyRepo
    .getHistoryForTask(taskKey)
    .map((h) => h.completedAt.hour)
    .toList();
```

### 2. カレンダービュー

```dart
// 特定月の完了日を取得
final monthStart = DateTime(2025, 10, 1);
final monthEnd = DateTime(2025, 10, 31);
final completedDates = historyRepo
    .getHistoryInRange(monthStart, monthEnd)
    .map((h) => h.completedDate)
    .toSet();

// カレンダーに表示
```

### 3. メモ機能

```dart
// 完了時にメモを追加
final completion = TaskCompletionHistory(
  taskKey: index,
  completedAt: DateTime.now(),
  earnedXp: xp,
  notes: 'とても良い感じだった！', // メモ
);
```

### 4. リマインダーとの連携

```dart
// 3日間完了していないタスクを通知
final lastCompletion = historyRepo
    .getHistoryForTask(taskKey)
    .firstOrNull
    ?.completedAt;

if (lastCompletion != null &&
    DateTime.now().difference(lastCompletion).inDays > 3) {
  // リマインダーを送信
}
```

## まとめ

### 実装した内容

- ✅ 完了履歴の別モデル化
- ✅ 繰り返しタスクの日次完了機能
- ✅ ストリーク計算機能とUI表示
- ✅ データマイグレーション（V1→V2）
- ✅ 後方互換性の維持

### 未実装（将来の拡張）

- ⏸️ 進捗ビューの追加（週次・月次グラフ）
- ⏸️ カレンダービューでの完了日可視化
- ⏸️ 統計ダッシュボード
- ⏸️ メモ機能の活用

### 技術的なポイント

1. **後方互換性**: 旧フィールドを`@Deprecated`でマークし、マイグレーション用に残存
2. **段階的な移行**: 単発タスクは既存の動作を維持、繰り返しタスクのみ新方式
3. **パフォーマンス**: ストリーク計算は必要時のみ実行、キャッシュ可能
4. **テスト容易性**: Repository/Serviceパターンによりビジネスロジックをテスト可能

この実装により、Habit Penguinは真の「習慣トラッキングアプリ」として機能するようになりました。
