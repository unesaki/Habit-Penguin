import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'advanced_notification_settings.g.dart';

/// 高度な通知設定モデル
@HiveType(typeId: 4)
class AdvancedNotificationSettings extends HiveObject {
  /// タスクID
  @HiveField(0)
  int taskId;

  /// 複数の通知時刻（最大5つ）
  @HiveField(1)
  List<TimeOfDay> reminderTimes;

  /// 曜日別通知設定（月曜=0, 日曜=6）
  @HiveField(2)
  List<int> enabledWeekdays;

  /// 通知サウンド（カスタム）
  @HiveField(3)
  String? customSound;

  /// バイブレーションパターン
  @HiveField(4)
  String? vibrationPattern;

  AdvancedNotificationSettings({
    required this.taskId,
    List<TimeOfDay>? reminderTimes,
    List<int>? enabledWeekdays,
    this.customSound,
    this.vibrationPattern,
  })  : reminderTimes = reminderTimes ?? [],
        enabledWeekdays = enabledWeekdays ?? List.generate(7, (i) => i);

  /// すべての曜日が有効か
  bool get allWeekdaysEnabled => enabledWeekdays.length == 7;

  /// 特定の曜日が有効か（0=月曜, 6=日曜）
  bool isWeekdayEnabled(int weekday) => enabledWeekdays.contains(weekday);

  /// 曜日を追加
  void enableWeekday(int weekday) {
    if (!enabledWeekdays.contains(weekday)) {
      enabledWeekdays.add(weekday);
      enabledWeekdays.sort();
    }
  }

  /// 曜日を削除
  void disableWeekday(int weekday) {
    enabledWeekdays.remove(weekday);
  }

  /// 通知時刻を追加
  void addReminderTime(TimeOfDay time) {
    if (reminderTimes.length < 5) {
      reminderTimes.add(time);
      _sortReminderTimes();
    }
  }

  /// 通知時刻を削除
  void removeReminderTime(int index) {
    if (index >= 0 && index < reminderTimes.length) {
      reminderTimes.removeAt(index);
    }
  }

  /// 通知時刻をソート
  void _sortReminderTimes() {
    reminderTimes.sort((a, b) {
      if (a.hour != b.hour) return a.hour.compareTo(b.hour);
      return a.minute.compareTo(b.minute);
    });
  }

  /// 今日は通知を送信すべきか（曜日チェック）
  bool shouldNotifyToday() {
    final today = DateTime.now().weekday % 7; // DateTime.weekday: 月=1, 日=7
    return enabledWeekdays.contains(today);
  }
}
