import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

import '../models/habit_task.dart';
import '../models/advanced_notification_settings.dart';
import '../models/notification_history.dart';

/// 通知管理を担当するサービスクラス
class NotificationService {
  NotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    bool initialize = true,
  })  : _notifications = plugin ?? FlutterLocalNotificationsPlugin(),
        _initialized = false {
    if (initialize) {
      _initializeNotifications();
    }
  }

  /// テスト用コンストラクタ: 通知初期化をスキップ
  NotificationService.test({FlutterLocalNotificationsPlugin? plugin})
      : _notifications = plugin ?? FlutterLocalNotificationsPlugin(),
        _initialized = true;

  final FlutterLocalNotificationsPlugin _notifications;

  bool _initialized;

  /// 通知タップ時のコールバック（外部から設定可能）
  Function(String?)? onNotificationTapped;

  /// 通知の初期化
  Future<void> _initializeNotifications() async {
    if (_initialized) return;

    // タイムゾーンの初期化
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));

    // Android設定
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS設定
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // macOS設定
    const macOSSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: macOSSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  /// 通知タップ時の処理
  void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      print('Notification tapped: ${response.payload}');
    }

    // タップを履歴に記録
    if (response.payload != null && response.payload!.startsWith('task_')) {
      final taskIdStr = response.payload!.replaceFirst('task_', '');
      final taskId = int.tryParse(taskIdStr);
      if (taskId != null) {
        recordNotificationTap(taskId);
      }
    }

    // コールバックが設定されていれば呼び出す
    if (onNotificationTapped != null) {
      onNotificationTapped!(response.payload);
    }
  }

  /// 通知権限のリクエスト
  Future<bool> requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final result = await _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return result ?? false;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      final result = await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return result ?? false;
    }
    return true;
  }

  /// タスクの通知をスケジュール
  Future<void> scheduleTaskNotification(
    int taskId,
    HabitTask task,
    TimeOfDay reminderTime,
  ) async {
    if (!task.reminderEnabled) {
      return;
    }

    await _initializeNotifications();

    // 既存の通知をキャンセル
    await cancelTaskNotification(taskId);

    // 通知詳細
    const androidDetails = AndroidNotificationDetails(
      'habit_reminders',
      'タスクリマインダー',
      channelDescription: '習慣タスクのリマインダー通知',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    // 通知時刻を計算
    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      reminderTime.hour,
      reminderTime.minute,
    );

    // 過去の時刻なら翌日に設定
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

    // 繰り返しタスクの場合は毎日通知
    if (task.isRepeating) {
      await _notifications.zonedSchedule(
        taskId,
        'リマインダー: ${task.name}',
        '今日のタスクを完了しましょう！',
        tzScheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // 毎日同じ時刻に通知
        payload: 'task_$taskId',
      );
    } else {
      // 単発タスクの場合は1回のみ
      await _notifications.zonedSchedule(
        taskId,
        'リマインダー: ${task.name}',
        'タスクを完了しましょう！',
        tzScheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'task_$taskId',
      );
    }
  }

  /// タスクの通知をキャンセル
  Future<void> cancelTaskNotification(int taskId) async {
    await _notifications.cancel(taskId);
  }

  /// すべての通知をキャンセル
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// 保留中の通知一覧を取得
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// スヌーズ機能（指定分後に再通知）
  Future<void> snoozeNotification(
    int taskId,
    HabitTask task,
    int minutes,
  ) async {
    await _initializeNotifications();

    const androidDetails = AndroidNotificationDetails(
      'habit_reminders',
      'タスクリマインダー',
      channelDescription: '習慣タスクのリマインダー通知',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    final snoozeTime = DateTime.now().add(Duration(minutes: minutes));
    final tzSnoozeTime = tz.TZDateTime.from(snoozeTime, tz.local);

    await _notifications.zonedSchedule(
      taskId,
      'リマインダー: ${task.name}',
      'スヌーズしたタスクです',
      tzSnoozeTime,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'task_$taskId',
    );
  }

  /// 即座にテスト通知を表示
  Future<void> showTestNotification() async {
    await _initializeNotifications();

    const androidDetails = AndroidNotificationDetails(
      'test_channel',
      'テスト通知',
      channelDescription: 'テスト用の通知',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    await _notifications.show(
      999,
      'テスト通知',
      'これはテスト通知です',
      notificationDetails,
    );
  }

  /// 高度な通知設定を使用してタスク通知をスケジュール
  Future<void> scheduleAdvancedTaskNotification(
    int taskId,
    HabitTask task,
    AdvancedNotificationSettings advancedSettings,
  ) async {
    if (!task.reminderEnabled) {
      return;
    }

    await _initializeNotifications();

    // 既存の通知をキャンセル
    await cancelTaskNotification(taskId);

    // 通知設定を取得
    final settingsBox = Hive.box('notification_settings');
    final soundEnabled =
        settingsBox.get('sound_enabled', defaultValue: true) as bool;
    final vibrationEnabled =
        settingsBox.get('vibration_enabled', defaultValue: true) as bool;
    final priority = settingsBox.get('notification_priority',
        defaultValue: 'high') as String;

    // 優先度を設定
    final importance = priority == 'high'
        ? Importance.high
        : priority == 'low'
            ? Importance.low
            : Importance.defaultImportance;
    final androidPriority = priority == 'high'
        ? Priority.high
        : priority == 'low'
            ? Priority.low
            : Priority.defaultPriority;

    // 通知詳細
    final androidDetails = AndroidNotificationDetails(
      'habit_reminders',
      'タスクリマインダー',
      channelDescription: '習慣タスクのリマインダー通知',
      importance: importance,
      priority: androidPriority,
      playSound: soundEnabled,
      enableVibration: vibrationEnabled,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: soundEnabled,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    // 複数の通知時刻をスケジュール
    for (var i = 0; i < advancedSettings.reminderTimes.length; i++) {
      final reminderTime = advancedSettings.reminderTimes[i];
      final notificationId = taskId * 10 + i; // ユニークなIDを生成

      // 通知時刻を計算
      final now = DateTime.now();
      var scheduledDate = DateTime(
        now.year,
        now.month,
        now.day,
        reminderTime.hour,
        reminderTime.minute,
      );

      // 過去の時刻なら翌日に設定
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

      // 繰り返しタスクの場合は曜日フィルタを考慮
      if (task.isRepeating) {
        await _notifications.zonedSchedule(
          notificationId,
          'リマインダー: ${task.name}',
          '今日のタスクを完了しましょう！',
          tzScheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'task_$taskId',
        );
      } else {
        await _notifications.zonedSchedule(
          notificationId,
          'リマインダー: ${task.name}',
          'タスクを完了しましょう！',
          tzScheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'task_$taskId',
        );
      }
    }
  }

  /// 通知履歴を記録
  Future<void> recordNotificationHistory(
    int taskId,
    String taskName,
  ) async {
    final historyBox = Hive.box<NotificationHistory>('notification_history');

    final history = NotificationHistory(
      taskId: taskId,
      taskName: taskName,
      sentAt: DateTime.now(),
      tapped: false,
    );

    await historyBox.add(history);
  }

  /// 通知タップを記録
  Future<void> recordNotificationTap(int taskId) async {
    final historyBox = Hive.box<NotificationHistory>('notification_history');

    // 最新の未タップ通知を見つけて更新
    final allHistory = historyBox.values.toList();
    for (var i = allHistory.length - 1; i >= 0; i--) {
      final history = allHistory[i];
      if (history.taskId == taskId && !history.tapped) {
        history.tapped = true;
        history.tappedAt = DateTime.now();
        await history.save();
        break;
      }
    }
  }

  /// 高度な通知設定を取得
  AdvancedNotificationSettings? getAdvancedSettings(int taskId) {
    final settingsBox = Hive.box<AdvancedNotificationSettings>(
        'advanced_notification_settings');
    return settingsBox.values.firstWhere(
      (settings) => settings.taskId == taskId,
      orElse: () => AdvancedNotificationSettings(
        taskId: taskId,
        reminderTimes: const [TimeOfDay(hour: 9, minute: 0)],
        enabledWeekdays: const [0, 1, 2, 3, 4, 5, 6],
      ),
    );
  }

  /// 今日が通知を送る日かどうかをチェック
  bool shouldNotifyToday(AdvancedNotificationSettings settings) {
    return settings.shouldNotifyToday();
  }
}
