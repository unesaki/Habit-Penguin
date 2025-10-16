// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Habit Penguin';

  @override
  String get tabTasks => 'Tasks';

  @override
  String get tabHome => 'Home';

  @override
  String get tabPenguin => 'Penguin';

  @override
  String get welcomeBack => 'おかえり！';

  @override
  String get questDescription => 'ペンギンと一緒に今日のクエストをこなそう';

  @override
  String get todayTasks => '今日のタスク';

  @override
  String get createTaskPrompt => '今日のタスクを作成しよう';

  @override
  String get createTaskInstruction => 'Tasksタブ右下の「＋」ボタンから新しいタスクを追加できます。';

  @override
  String get seeMoreTasks => '残りのタスクはTasksタブで確認できます。';

  @override
  String currentXp(int xp) {
    return '経験値: $xp XP';
  }

  @override
  String get completedTasksButton => '完了済み';

  @override
  String get activeTasks => '今日のタスク';

  @override
  String get registeredTasks => '登録中のタスク';

  @override
  String get noActiveTasks => '今日は予定されたタスクがありません。';

  @override
  String get noTasks => 'タスクがまだありません。右下の＋で追加しよう。';

  @override
  String get addTask => 'タスクを追加';

  @override
  String get editTask => 'タスクを編集';

  @override
  String get habitName => 'Habit名';

  @override
  String get habitNameHint => '例: 朝のストレッチ';

  @override
  String get habitNameRequired => 'Habit名を入力してください';

  @override
  String get icon => 'アイコン';

  @override
  String get basicInfo => '基本情報';

  @override
  String get schedule => 'スケジュール';

  @override
  String get reminder => 'リマインダー';

  @override
  String get date => '日付';

  @override
  String get notSelected => '未選択';

  @override
  String get repeatingTask => '繰り返しタスク';

  @override
  String get startDate => '開始日';

  @override
  String get endDate => '終了日';

  @override
  String get enableNotification => '通知を受け取る';

  @override
  String get notificationTime => '通知時刻';

  @override
  String get saveChanges => '変更を保存';

  @override
  String get createTask => 'タスクを作成';

  @override
  String get selectStartDate => '開始日と終了日を選択してください。';

  @override
  String get endDateAfterStart => '終了日は開始日以降を選択してください。';

  @override
  String get selectDate => '日付を選択してください。';

  @override
  String get difficultyEasy => 'Easy';

  @override
  String get difficultyNormal => 'Normal';

  @override
  String get difficultyHard => 'Hard';

  @override
  String get completeTask => '完了にする';

  @override
  String get deleteTask => 'タスクを削除しますか？';

  @override
  String get deleteWarning => 'この操作は取り消せません。';

  @override
  String get cancel => 'キャンセル';

  @override
  String get delete => '削除';

  @override
  String get taskDeleted => 'タスクを削除しました。';

  @override
  String get alreadyCompletedToday => '本日は既に完了しています';

  @override
  String get questAchieved => 'クエスト達成！';

  @override
  String xpGained(int xp) {
    return '$xp XPを獲得しました！';
  }

  @override
  String get ok => 'OK';

  @override
  String get completedTasks => '完了済みタスク';

  @override
  String get noCompletedTasks => '完了済みのタスクはまだありません。';

  @override
  String earnedXp(int xp) {
    return '獲得XP: $xp';
  }

  @override
  String completionDate(String date) {
    return '完了日: $date';
  }

  @override
  String get penguinRoomComingSoon => 'ペンギンルームは準備中！';

  @override
  String get penguinRoomDescription => '次のアップデートでミッションや表情変化が登場予定です。';

  @override
  String streakDays(int days) {
    return '$days日連続';
  }

  @override
  String get reminderOn => 'Reminder ON';

  @override
  String get anytime => 'いつでも';

  @override
  String error(String message) {
    return 'エラー: $message';
  }
}
