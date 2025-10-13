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

## 今後の改善点

### 未実装機能:
1. **通知タップ時のナビゲーション**
   - 現在はログ出力のみ
   - グローバルNavigatorKeyまたはRiverpodプロバイダーを使用して実装予定

2. **通知設定画面**
   - 通知音のカスタマイズ
   - 通知スタイルの選択
   - 通知履歴の表示

3. **スヌーズ機能のUI統合**
   - 通知アクションボタンの追加
   - スヌーズ時間の選択UI

4. **複数通知時刻**
   - 1日に複数回の通知を設定可能にする

5. **曜日指定**
   - 特定の曜日だけ通知を送る機能

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
│   └── notification_service.dart     # 通知管理サービス
├── repositories/
│   └── task_repository.dart          # 通知統合
├── models/
│   └── habit_task.dart                # reminderTimeフィールド追加
├── providers/
│   └── providers.dart                 # NotificationServiceプロバイダー
└── main.dart                          # UI更新と権限リクエスト
```

## まとめ

リマインダー機能は完全に実装され、以下が可能になりました:
- ✅ タスクごとの通知時刻設定
- ✅ 単発/繰り返しタスクの適切な通知
- ✅ タスク追加/更新/削除時の通知管理
- ✅ プラットフォーム横断的な動作
- ✅ 権限管理

これにより、ユーザーは習慣タスクを忘れずに実行できるようになり、アプリの実用性が大幅に向上しました。
