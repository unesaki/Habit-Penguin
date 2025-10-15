import 'package:flutter/foundation.dart';

import '../models/habit_task.dart';

/// Undo/Redo操作の種類
enum UndoActionType {
  deleteTask,
  deleteTasks,
  completeTask,
}

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

  /// Undo可能なアクションがあるか
  bool get canUndo => _undoStack.isNotEmpty;

  /// 最新のUndo可能なアクションの説明
  String? get lastActionDescription =>
      _undoStack.isEmpty ? null : _undoStack.last.description;

  /// アクションを記録
  void recordAction(UndoAction action) {
    _undoStack.add(action);

    // スタックサイズを制限
    if (_undoStack.length > _maxStackSize) {
      _undoStack.removeAt(0);
    }

    notifyListeners();
  }

  /// タスク削除アクションを記録
  void recordDeleteTask({
    required int index,
    required HabitTask task,
    required Future<void> Function() restoreFunction,
  }) {
    recordAction(
      UndoAction(
        type: UndoActionType.deleteTask,
        description: '「${task.name}」を削除',
        undo: restoreFunction,
        data: {
          'index': index,
          'task': task,
        },
      ),
    );
  }

  /// 複数タスク削除アクションを記録
  void recordDeleteTasks({
    required List<MapEntry<int, HabitTask>> deletedTasks,
    required Future<void> Function() restoreFunction,
  }) {
    recordAction(
      UndoAction(
        type: UndoActionType.deleteTasks,
        description: '${deletedTasks.length}個のタスクを削除',
        undo: restoreFunction,
        data: {
          'tasks': deletedTasks,
        },
      ),
    );
  }

  /// タスク完了アクションを記録
  void recordCompleteTask({
    required int index,
    required HabitTask task,
    required Future<void> Function() undoFunction,
  }) {
    recordAction(
      UndoAction(
        type: UndoActionType.completeTask,
        description: '「${task.name}」を完了',
        undo: undoFunction,
        data: {
          'index': index,
          'task': task,
        },
      ),
    );
  }

  /// 最後のアクションを取り消す
  Future<void> undo() async {
    if (_undoStack.isEmpty) return;

    final action = _undoStack.removeLast();
    await action.undo();
    notifyListeners();
  }

  /// スタックをクリア
  void clear() {
    _undoStack.clear();
    notifyListeners();
  }
}
