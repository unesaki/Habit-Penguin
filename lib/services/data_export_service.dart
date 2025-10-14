import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/habit_task.dart';
import '../models/task_completion_history.dart';

/// データエクスポート機能を提供するサービス
class DataExportService {
  /// すべてのデータをJSON形式でエクスポート
  Future<String> exportToJson() async {
    final data = await _collectAllData();
    return jsonEncode(data);
  }

  /// すべてのデータをCSV形式でエクスポート（タスクと履歴を別ファイルで）
  Future<Map<String, String>> exportToCsv() async {
    // データの一貫性のため一度収集（実際には各ボックスを直接使用）
    await _collectAllData();

    final tasksBox = Hive.box<HabitTask>('tasks');
    final historyBox = Hive.box<TaskCompletionHistory>('completion_history');

    // タスクCSV
    final tasksCsv = StringBuffer();
    tasksCsv.writeln(
      'ID,Name,Icon,Difficulty,ReminderEnabled,ReminderTime,IsRepeating,ScheduledDate,RepeatStart,RepeatEnd',
    );

    for (var i = 0; i < tasksBox.length; i++) {
      final task = tasksBox.getAt(i);
      if (task == null) continue;

      tasksCsv.writeln(
        '$i,'
        '"${_escapeCsv(task.name)}",'
        '${task.iconCodePoint},'
        '${task.difficulty.name},'
        '${task.reminderEnabled},'
        '${task.reminderTime != null ? "${task.reminderTime!.hour}:${task.reminderTime!.minute}" : ""},'
        '${task.isRepeating},'
        '${task.scheduledDate?.toIso8601String() ?? ""},'
        '${task.repeatStart?.toIso8601String() ?? ""},'
        '${task.repeatEnd?.toIso8601String() ?? ""}',
      );
    }

    // 履歴CSV
    final historyCsv = StringBuffer();
    historyCsv.writeln('TaskID,CompletedAt,EarnedXP,Notes');

    for (var i = 0; i < historyBox.length; i++) {
      final history = historyBox.getAt(i);
      if (history == null) continue;

      historyCsv.writeln(
        '${history.taskKey},'
        '${history.completedAt.toIso8601String()},'
        '${history.earnedXp},'
        '"${_escapeCsv(history.notes ?? "")}"',
      );
    }

    return {
      'tasks': tasksCsv.toString(),
      'history': historyCsv.toString(),
    };
  }

  /// データをファイルにエクスポートして共有
  Future<void> exportAndShare({required ExportFormat format}) async {
    try {
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');

      if (format == ExportFormat.json) {
        final json = await exportToJson();
        final file = File('${directory.path}/habit_penguin_data_$timestamp.json');
        await file.writeAsString(json);

        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Habit Penguin データエクスポート',
        );
      } else if (format == ExportFormat.csv) {
        final csvData = await exportToCsv();

        final tasksFile = File('${directory.path}/habit_penguin_tasks_$timestamp.csv');
        await tasksFile.writeAsString(csvData['tasks']!);

        final historyFile = File('${directory.path}/habit_penguin_history_$timestamp.csv');
        await historyFile.writeAsString(csvData['history']!);

        await Share.shareXFiles(
          [XFile(tasksFile.path), XFile(historyFile.path)],
          subject: 'Habit Penguin データエクスポート',
        );
      }
    } catch (e) {
      throw DataExportException('データのエクスポートに失敗しました: $e');
    }
  }

  /// すべてのデータを収集
  Future<Map<String, dynamic>> _collectAllData() async {
    final tasksBox = Hive.box<HabitTask>('tasks');
    final historyBox = Hive.box<TaskCompletionHistory>('completion_history');
    final appStateBox = Hive.box('appState');

    // タスクデータ
    final tasks = <Map<String, dynamic>>[];
    for (var i = 0; i < tasksBox.length; i++) {
      final task = tasksBox.getAt(i);
      if (task == null) continue;

      tasks.add({
        'id': i,
        'name': task.name,
        'iconCodePoint': task.iconCodePoint,
        'reminderEnabled': task.reminderEnabled,
        'reminderTime': task.reminderTime != null
            ? {
                'hour': task.reminderTime!.hour,
                'minute': task.reminderTime!.minute,
              }
            : null,
        'difficulty': task.difficulty.name,
        'isRepeating': task.isRepeating,
        'scheduledDate': task.scheduledDate?.toIso8601String(),
        'repeatStart': task.repeatStart?.toIso8601String(),
        'repeatEnd': task.repeatEnd?.toIso8601String(),
      });
    }

    // 完了履歴データ
    final history = <Map<String, dynamic>>[];
    for (var i = 0; i < historyBox.length; i++) {
      final record = historyBox.getAt(i);
      if (record == null) continue;

      history.add({
        'taskId': record.taskKey,
        'completedAt': record.completedAt.toIso8601String(),
        'earnedXp': record.earnedXp,
        'notes': record.notes,
      });
    }

    // アプリ状態データ
    final appState = {
      'currentXp': appStateBox.get('xp', defaultValue: 0),
      'schemaVersion': appStateBox.get('schemaVersion', defaultValue: 1),
    };

    return {
      'exportedAt': DateTime.now().toIso8601String(),
      'version': '1.0',
      'appState': appState,
      'tasks': tasks,
      'completionHistory': history,
    };
  }

  /// CSV用の文字列エスケープ
  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return value.replaceAll('"', '""');
    }
    return value;
  }

  /// エクスポートされたデータのサマリーを取得
  Future<DataExportSummary> getExportSummary() async {
    final tasksBox = Hive.box<HabitTask>('tasks');
    final historyBox = Hive.box<TaskCompletionHistory>('completion_history');
    final appStateBox = Hive.box('appState');

    return DataExportSummary(
      taskCount: tasksBox.length,
      completionHistoryCount: historyBox.length,
      currentXp: appStateBox.get('xp', defaultValue: 0) as int,
      exportDate: DateTime.now(),
    );
  }
}

/// エクスポート形式
enum ExportFormat {
  json,
  csv,
}

/// データエクスポートのサマリー情報
class DataExportSummary {
  final int taskCount;
  final int completionHistoryCount;
  final int currentXp;
  final DateTime exportDate;

  DataExportSummary({
    required this.taskCount,
    required this.completionHistoryCount,
    required this.currentXp,
    required this.exportDate,
  });
}

/// データエクスポート時の例外
class DataExportException implements Exception {
  final String message;

  DataExportException(this.message);

  @override
  String toString() => message;
}
