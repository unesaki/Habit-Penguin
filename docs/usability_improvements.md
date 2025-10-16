# 操作性向上機能実装ドキュメント

## 概要
Habit Penguinアプリにタスクの一括操作機能とUndo/Redo機能を実装しました。これにより、ユーザーはタスクをより効率的に管理できるようになります。

## 実装内容

### 1. タスクの複数選択機能

#### UI要素
- **選択ボタン**: TasksTabの右上に「選択」ボタンを配置
- **選択モード**: 選択モードON時、各タスクにチェックボックスが表示
- **一括削除ボタン**: 選択モード時に削除ボタンが表示

#### 実装詳細
**lib/main.dart** - `_TasksTabState`

```dart
class _TasksTabState extends ConsumerState<TasksTab> {
  bool _isSelectionMode = false;
  final Set<int> _selectedIndices = {};

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedIndices.clear();
      }
    });
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }
}
```

#### 使用方法
1. Tasksタブ右上の「選択」ボタンをタップ
2. 削除したいタスクをタップして選択（チェックボックスが表示）
3. 削除ボタンをタップして一括削除
4. キャンセルボタンで選択モードを終了

### 2. タスクの複製機能

#### UI要素
- **メニューボタン**: 各タスクに3点メニューボタンを配置
- **複製オプション**: メニューから「複製」を選択

#### 実装詳細
**lib/repositories/task_repository.dart**

```dart
/// タスクを複製（新しいタスクとして追加）
Future<void> duplicateTask(int index) async {
  final task = _box.getAt(index);
  if (task == null) return;

  // 新しいタスクを作成（名前に「(コピー)」を追加）
  final duplicatedTask = HabitTask(
    name: '${task.name} (コピー)',
    iconCodePoint: task.iconCodePoint,
    reminderEnabled: task.reminderEnabled,
    difficulty: task.difficulty,
    scheduledDate: task.scheduledDate,
    repeatStart: task.repeatStart,
    repeatEnd: task.repeatEnd,
    reminderTime: task.reminderTime,
  );

  await addTask(duplicatedTask);
}
```

#### 使用方法
1. タスクの3点メニューボタンをタップ
2. 「複製」を選択
3. 元のタスクのコピーが「(コピー)」という接尾辞付きで作成される

### 3. 複数タスクの一括削除

#### 実装詳細
**lib/repositories/task_repository.dart**

```dart
/// 複数のタスクを削除
Future<void> deleteTasks(List<int> indices) async {
  // インデックスを降順にソートして削除（後ろから削除）
  final sortedIndices = indices.toList()..sort((a, b) => b.compareTo(a));

  for (final index in sortedIndices) {
    await deleteTaskAt(index);
  }
}
```

#### 機能
- 選択された複数のタスクを一度に削除
- インデックスのずれを防ぐため、降順で削除
- 各タスクの通知と完了履歴も一緒に削除

### 4. Undo/Redo機能

#### アーキテクチャ
**lib/services/undo_service.dart**

```dart
/// Undo可能なアクション
class UndoAction {
  UndoAction({
    required this.type,
    required this.description,
    required this.undo,
    this.data,
  });

  final UndoActionType type;
  final String description;
  final Future<void> Function() undo;
  final Map<String, dynamic>? data;
}

/// Undo/Redo機能を管理するサービス
class UndoService extends ChangeNotifier {
  final List<UndoAction> _undoStack = [];
  final int _maxStackSize = 20; // 最大20個まで保持

  /// アクションを記録
  void recordAction(UndoAction action) {
    _undoStack.add(action);
    if (_undoStack.length > _maxStackSize) {
      _undoStack.removeAt(0);
    }
    notifyListeners();
  }

  /// 最後のアクションを取り消す
  Future<void> undo() async {
    if (_undoStack.isEmpty) return;
    final action = _undoStack.removeLast();
    await action.undo();
    notifyListeners();
  }
}
```

#### 対応アクション
1. **タスク削除**
   - 削除されたタスクを復元
   - 元の位置に挿入

2. **複数タスク削除**
   - 削除されたすべてのタスクを復元
   - 各タスクを元の位置に復元

3. **タスク完了**
   - 完了履歴を削除
   - 獲得したXPを減算

#### UI統合
- **Undoボタン**: TasksTabに「取り消し: [アクション名]」ボタンを表示
- **SnackBarアクション**: 削除操作後のSnackBarに「取り消し」ボタンを追加

#### 使用方法
1. **自動記録**: 削除・完了操作時に自動的にUndo情報を記録
2. **Undoボタンから**: TasksTabのUndoボタンをタップ
3. **SnackBarから**: 操作直後に表示されるSnackBarの「取り消し」をタップ

### 5. XpServiceの拡張

**lib/services/xp_service.dart**

```dart
/// 経験値を減算（Undo用）
Future<void> subtractXp(int amount) async {
  final currentXp = getCurrentXp();
  final newXp = (currentXp - amount).clamp(0, double.infinity).toInt();
  await _appStateBox.put(_xpKey, newXp);
}
```

- タスク完了のUndo時に獲得XPを正しく減算
- マイナス値にならないようにclamp処理

### 6. 完了履歴のタスクキー更新

**lib/repositories/completion_history_repository.dart**

```dart
/// タスクの並び替え後にタスクキーを更新
Future<void> updateTaskKeyAfterReorder(int oldKey, int newKey) async {
  for (var i = 0; i < _box.length; i++) {
    final record = _box.getAt(i);
    if (record != null && record.taskKey == oldKey) {
      record.taskKey = newKey;
      await record.save();
    }
  }
}
```

- タスクの並び替え後、完了履歴の参照を更新
- データの整合性を保つ

## ファイル構成

```
lib/
├── services/
│   ├── undo_service.dart           # Undo/Redo管理サービス
│   └── xp_service.dart             # XP管理（subtractXp追加）
├── repositories/
│   ├── task_repository.dart        # タスク操作（複製、並び替え、一括削除）
│   └── completion_history_repository.dart  # 履歴キー更新
├── providers/
│   └── providers.dart              # UndoServiceプロバイダー追加
└── main.dart                       # UI更新（選択モード、Undo統合）
```

## 技術的詳細

### 選択モードの状態管理
- `_isSelectionMode`: 選択モードのON/OFF
- `_selectedIndices`: 選択されたタスクのインデックスセット
- 選択モード終了時に自動的にクリア

### Undoスタック管理
- 最大20個のアクションを保持
- LIFOスタック（Last In, First Out）
- ChangeNotifierで状態変化を通知

### タスク復元の実装
```dart
undoService.recordDeleteTask(
  index: index,
  task: taskCopy,
  restoreFunction: () async {
    await repository.box.putAt(index, taskCopy);
  },
);
```

- タスクのコピーを保存
- 復元関数を定義してUndoServiceに渡す
- 非同期処理に対応

### データ整合性
- タスク削除時：通知と履歴も削除
- タスク復元時：元の位置に挿入
- インデックスのずれを考慮した実装

## 使用例

### タスクを複製
```dart
final repository = ref.read(taskRepositoryProvider);
await repository.duplicateTask(taskIndex);
```

### 複数タスクを削除
```dart
final indices = [0, 2, 5];  // 削除するタスクのインデックス
await repository.deleteTasks(indices);
```

### Undoを実行
```dart
final undoService = ref.read(undoServiceProvider);
if (undoService.canUndo) {
  await undoService.undo();
}
```

## ユーザーエクスペリエンスの向上

### 安全な操作
- 削除前の確認ダイアログは廃止（Undoで対応）
- スナックバーで即座にフィードバック
- 「取り消し」ボタンで簡単に復元

### 効率的なワークフロー
- 複数タスクを一度に削除
- タスクの複製で類似タスクを素早く作成
- ミスした操作をすぐに取り消せる

### 視覚的なフィードバック
- 選択モード時にチェックボックス表示
- Undoボタンにアクション名を表示
- スナックバーで操作結果を通知

## まとめ

操作性向上機能の実装により、以下が可能になりました：
- ✅ タスクの複数選択と一括削除
- ✅ タスクの複製機能
- ✅ 削除操作のUndo機能
- ✅ タスク完了のUndo機能
- ✅ スナックバーからの即座な取り消し
- ✅ 最大20個の操作履歴を保持

これにより、ユーザーはタスクをより安全かつ効率的に管理できるようになり、ミスを恐れずに操作できるようになりました。
