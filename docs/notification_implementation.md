# リマインダー機能実装ドキュメント

## 概要
Habit Penguinアプリにローカル通知によるリマインダー機能を実装しました。ユーザーは各タスクに通知時刻を設定し、指定された時間に通知を受け取ることができます。

## 実装内容

### 1. 依存パッケージの追加
**pubspec.yaml**に以下を追加:
- `flutter_local_notifications: ^18.0.1` - クロスプラットフォーム通知機能
- `timezone: ^0.9.4` - タイムゾーン対応のスケジュール機能

### 2. NotificationServiceの実装
**lib/services/notification_service.dart**

#### 主な機能:
- **初期化**: Android/iOS/macOS向けの通知設定
- **タイムゾーン設定**: Asia/Tokyoに設定
- **通知権限リクエスト**: プラットフォームごとの権限取得
- **通知スケジュール**: タスクごとの通知設定
- **繰り返し通知**: 繰り返しタスクは毎日同じ時刻に通知
- **スヌーズ機能**: 指定分後に再通知
- **通知キャンセル**: 個別/全体の通知キャンセル

#### 主要メソッド:
```dart
// タスクの通知をスケジュール
Future<void> scheduleTaskNotification(
  int taskId,
  HabitTask task,
  TimeOfDay reminderTime,
)

// 通知をキャンセル
Future<void> cancelTaskNotification(int taskId)

// スヌーズ機能
Future<void> snoozeNotification(int taskId, HabitTask task, int minutes)

// テスト通知
Future<void> showTestNotification()
```

### 3. HabitTaskモデルの拡張
**lib/models/habit_task.dart**

#### 追加フィールド:
- `TimeOfDay? reminderTime` - 通知時刻

#### Hiveアダプター更新:
- TimeOfDayを分単位の整数（minutes since midnight）として保存
- 読み込み時にTimeOfDayオブジェクトに復元
- フィールド番号10番を使用

### 4. TaskRepositoryの統合
**lib/repositories/task_repository.dart**

#### 通知管理の統合:
- **タスク追加時**: リマインダーが有効な場合、通知を自動スケジュール
- **タスク更新時**:
  - リマインダー有効 → 通知を再スケジュール
  - リマインダー無効 → 通知をキャンセル
- **タスク削除時**: 関連する通知をキャンセル

### 5. UIの更新
**lib/main.dart**

#### タスクフォームに追加:
- **通知時刻ピッカー**: リマインダーが有効な場合に表示
- **デフォルト時刻**: 9:00 AM
- **時刻フォーマット**: HH:MM形式で表示
- **アニメーション**: スムーズな表示/非表示切り替え

#### コード例:
```dart
AnimatedSwitcher(
  duration: const Duration(milliseconds: 200),
  child: !_reminderEnabled
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _DateActionRow(
            label: '通知時刻',
            value: _reminderTime != null
                ? _formatTimeLabel(_reminderTime!)
                : '未選択',
            onTap: _pickReminderTime,
          ),
        ),
)
```

### 6. Riverpodプロバイダーの追加
**lib/providers/providers.dart**

```dart
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
```

TaskRepositoryにNotificationServiceを注入し、依存性を管理。

### 7. アプリ起動時の権限リクエスト
**lib/main.dart**の`main()`関数で通知権限をリクエスト:
```dart
final notificationService = NotificationService();
await notificationService.requestPermissions();
```

## 通知の動作

### 単発タスク
- スケジュールされた日付の指定時刻に1回だけ通知
- 過去の時刻の場合は翌日に設定

### 繰り返しタスク
- 期間内は毎日同じ時刻に通知
- `DateTimeComponents.time`を使用して日次繰り返しを実現

### 通知内容
- **タイトル**: "リマインダー: {タスク名}"
- **本文**:
  - 繰り返しタスク: "今日のタスクを完了しましょう！"
  - 単発タスク: "タスクを完了しましょう！"
- **ペイロード**: `task_{taskId}` - 将来的な拡張用

## プラットフォーム対応

### Android
- 通知チャンネル: `habit_reminders`
- 重要度: High
- アイコン: `@mipmap/ic_launcher`

### iOS/macOS
- アラート、バッジ、サウンドをすべて有効化
- 権限リクエストを初回起動時に表示

## 高度な通知機能（拡張機能）

### 8. 通知タップ時のナビゲーション
**lib/main.dart** - HabitHomeShell

通知をタップすると、該当するタスクの編集画面に直接遷移します:
- `onNotificationTapped`コールバックでペイロードを解析
- `task_{taskId}`形式のペイロードからタスクIDを抽出
- Tasksタブに切り替えてタスク編集画面を開く
- 通知履歴にタップイベントを記録

### 9. 通知設定画面
**lib/screens/notification_settings_screen.dart**

ユーザーが通知の動作をカスタマイズできる設定画面:
- **音設定**: 通知音の有効/無効
- **バイブレーション**: バイブレーションの有効/無効
- **通知プレビュー**: 詳細表示の有効/無効
- **通知優先度**: 高/デフォルト/低の3段階
- **テスト通知**: 設定を確認するためのテスト送信機能

設定はHiveの`notification_settings`ボックスに保存され、NotificationServiceで参照されます。

### 10. 通知履歴画面
**lib/screens/notification_history_screen.dart**
**lib/models/notification_history.dart**

送信された通知の履歴を表示:
- 通知の送信日時
- タスク名
- タップ済み/未タップのステータス
- タップした日時（タップ済みの場合）
- 履歴の一括削除機能

NotificationHistoryモデル:
```dart
@HiveType(typeId: 3)
class NotificationHistory extends HiveObject {
  @HiveField(0) int taskId;
  @HiveField(1) String taskName;
  @HiveField(2) DateTime sentAt;
  @HiveField(3) bool tapped;
  @HiveField(4) DateTime? tappedAt;
}
```

### 11. 高度な通知設定
**lib/screens/advanced_notification_screen.dart**
**lib/models/advanced_notification_settings.dart**

タスクごとに詳細な通知設定が可能:
- **複数通知時刻**: 最大5つの通知時刻を設定
- **曜日別通知**: 通知を受け取る曜日を選択（月〜日）
- **プリセットボタン**: 平日のみ/週末のみ/毎日の一括設定

AdvancedNotificationSettingsモデル:
```dart
@HiveType(typeId: 4)
class AdvancedNotificationSettings extends HiveObject {
  @HiveField(0) int taskId;
  @HiveField(1) List<TimeOfDay> reminderTimes;
  @HiveField(2) List<int> enabledWeekdays;  // 0=月, 6=日
  @HiveField(3) String? customSound;
  @HiveField(4) String? vibrationPattern;

  bool shouldNotifyToday() {
    final today = DateTime.now().weekday % 7;
    return enabledWeekdays.contains(today);
  }
}
```

### 12. 設定画面統合
**lib/screens/settings_screen.dart**

メイン設定画面から各通知機能にアクセス:
- 通知設定（音、バイブレーション、優先度）
- 通知履歴
- プライバシーとデータ管理
- アプリ情報

タスク編集画面からも「高度な通知設定」にアクセス可能です。

## 今後の改善点

### 追加実装予定機能:
1. **スヌーズ機能のUI統合**
   - 通知アクションボタンの追加
   - スヌーズ時間の選択UI

2. **カスタム通知音**
   - 独自の通知音をアップロード
   - 通知音ライブラリから選択

3. **バイブレーションパターン**
   - カスタムバイブレーションパターンの設定

4. **通知統計**
   - 送信済み通知の統計情報
   - タップ率の分析

### パーミッションの注意点:
- **iOS**: Info.plistに通知権限の説明を追加する必要あり
- **Android**: AndroidManifest.xmlに通知権限を追加（Android 13以降）

## テスト方法

### テスト通知の表示:
```dart
final notificationService = ref.read(notificationServiceProvider);
await notificationService.showTestNotification();
```

### 保留中の通知を確認:
```dart
final pending = await notificationService.getPendingNotifications();
for (final notification in pending) {
  print('Pending: ${notification.id} - ${notification.title}');
}
```

## ファイル構成

```
lib/
├── services/
│   └── notification_service.dart            # 通知管理サービス（拡張済み）
├── repositories/
│   └── task_repository.dart                 # 通知統合
├── models/
│   ├── habit_task.dart                      # reminderTimeフィールド追加
│   ├── notification_history.dart            # 通知履歴モデル (typeId: 3)
│   └── advanced_notification_settings.dart  # 高度な通知設定 (typeId: 4)
├── screens/
│   ├── settings_screen.dart                 # メイン設定画面
│   ├── notification_settings_screen.dart    # 通知設定画面
│   ├── notification_history_screen.dart     # 通知履歴画面
│   └── advanced_notification_screen.dart    # 高度な通知設定画面
├── providers/
│   ├── providers.dart                       # NotificationServiceプロバイダー
│   └── navigation_provider.dart             # 通知タップナビゲーション
└── main.dart                                # UI更新、権限リクエスト、タップハンドラー
```

## まとめ

リマインダー機能とその拡張機能が完全に実装され、以下が可能になりました:

### 基本機能:
- ✅ タスクごとの通知時刻設定
- ✅ 単発/繰り返しタスクの適切な通知
- ✅ タスク追加/更新/削除時の通知管理
- ✅ プラットフォーム横断的な動作
- ✅ 権限管理

### 拡張機能:
- ✅ 通知タップ時のタスク画面への直接遷移
- ✅ 通知設定画面（音、バイブレーション、優先度）
- ✅ 通知履歴の表示と管理
- ✅ 複数通知時刻の設定（最大5つ）
- ✅ 曜日別通知設定

これにより、ユーザーは習慣タスクを柔軟にカスタマイズし、忘れずに実行できるようになり、アプリの実用性が大幅に向上しました。
