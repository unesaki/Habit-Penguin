import 'package:hive/hive.dart';

part 'notification_history.g.dart';

/// 通知履歴モデル
@HiveType(typeId: 3)
class NotificationHistory extends HiveObject {
  @HiveField(0)
  int taskId;

  @HiveField(1)
  String taskName;

  @HiveField(2)
  DateTime sentAt;

  @HiveField(3)
  bool tapped;

  @HiveField(4)
  DateTime? tappedAt;

  NotificationHistory({
    required this.taskId,
    required this.taskName,
    required this.sentAt,
    this.tapped = false,
    this.tappedAt,
  });
}
