import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

import '../models/habit_task.dart';

/// 通知管理を担当するサービスクラス
class NotificationService {
  NotificationService() {
    _initializeNotifications();
  }

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// 通知の初期化
  Future<void> _initializeNotifications() async {
    if (_initialized) return;

    // タイムゾーンの初期化
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));

    // Android設定
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

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
    // TODO: 通知タップ時にタスク画面に遷移
    // 実装例: グローバルNavigatorKeyを使用してTasksタブに遷移
    // navigatorKey.currentState?.pushNamed('/tasks');
    // または、Riverpodのプロバイダーを使用して現在のタブインデックスを更新
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
}
