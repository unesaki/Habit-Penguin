import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja')
  ];

  /// アプリケーションのタイトル
  ///
  /// In ja, this message translates to:
  /// **'Habit Penguin'**
  String get appTitle;

  /// タスクタブのラベル
  ///
  /// In ja, this message translates to:
  /// **'Tasks'**
  String get tabTasks;

  /// ホームタブのラベル
  ///
  /// In ja, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// ペンギンタブのラベル
  ///
  /// In ja, this message translates to:
  /// **'Penguin'**
  String get tabPenguin;

  /// ホーム画面の挨拶
  ///
  /// In ja, this message translates to:
  /// **'おかえり！'**
  String get welcomeBack;

  /// ホーム画面の説明
  ///
  /// In ja, this message translates to:
  /// **'ペンギンと一緒に今日のクエストをこなそう'**
  String get questDescription;

  /// 今日のタスクセクションのタイトル
  ///
  /// In ja, this message translates to:
  /// **'今日のタスク'**
  String get todayTasks;

  /// タスクがない時の促し
  ///
  /// In ja, this message translates to:
  /// **'今日のタスクを作成しよう'**
  String get createTaskPrompt;

  /// タスク作成の手順説明
  ///
  /// In ja, this message translates to:
  /// **'Tasksタブ右下の「＋」ボタンから新しいタスクを追加できます。'**
  String get createTaskInstruction;

  /// 追加タスクの案内
  ///
  /// In ja, this message translates to:
  /// **'残りのタスクはTasksタブで確認できます。'**
  String get seeMoreTasks;

  /// 現在のXP表示
  ///
  /// In ja, this message translates to:
  /// **'経験値: {xp} XP'**
  String currentXp(int xp);

  /// 完了済みタスクボタン
  ///
  /// In ja, this message translates to:
  /// **'完了済み'**
  String get completedTasksButton;

  /// アクティブなタスクセクション
  ///
  /// In ja, this message translates to:
  /// **'今日のタスク'**
  String get activeTasks;

  /// 登録中のタスクセクション
  ///
  /// In ja, this message translates to:
  /// **'登録中のタスク'**
  String get registeredTasks;

  /// アクティブタスクなしのメッセージ
  ///
  /// In ja, this message translates to:
  /// **'今日は予定されたタスクがありません。'**
  String get noActiveTasks;

  /// タスクなしのメッセージ
  ///
  /// In ja, this message translates to:
  /// **'タスクがまだありません。右下の＋で追加しよう。'**
  String get noTasks;

  /// タスク追加ボタン
  ///
  /// In ja, this message translates to:
  /// **'タスクを追加'**
  String get addTask;

  /// タスク編集タイトル
  ///
  /// In ja, this message translates to:
  /// **'タスクを編集'**
  String get editTask;

  /// 習慣名フィールドラベル
  ///
  /// In ja, this message translates to:
  /// **'Habit名'**
  String get habitName;

  /// 習慣名のヒント
  ///
  /// In ja, this message translates to:
  /// **'例: 朝のストレッチ'**
  String get habitNameHint;

  /// 習慣名の必須エラー
  ///
  /// In ja, this message translates to:
  /// **'Habit名を入力してください'**
  String get habitNameRequired;

  /// アイコンセクション
  ///
  /// In ja, this message translates to:
  /// **'アイコン'**
  String get icon;

  /// 基本情報セクション
  ///
  /// In ja, this message translates to:
  /// **'基本情報'**
  String get basicInfo;

  /// スケジュールセクション
  ///
  /// In ja, this message translates to:
  /// **'スケジュール'**
  String get schedule;

  /// リマインダーセクション
  ///
  /// In ja, this message translates to:
  /// **'リマインダー'**
  String get reminder;

  /// 日付ラベル
  ///
  /// In ja, this message translates to:
  /// **'日付'**
  String get date;

  /// 未選択状態
  ///
  /// In ja, this message translates to:
  /// **'未選択'**
  String get notSelected;

  /// 繰り返しタスクラベル
  ///
  /// In ja, this message translates to:
  /// **'繰り返しタスク'**
  String get repeatingTask;

  /// 開始日ラベル
  ///
  /// In ja, this message translates to:
  /// **'開始日'**
  String get startDate;

  /// 終了日ラベル
  ///
  /// In ja, this message translates to:
  /// **'終了日'**
  String get endDate;

  /// 通知有効化ラベル
  ///
  /// In ja, this message translates to:
  /// **'通知を受け取る'**
  String get enableNotification;

  /// 通知時刻ラベル
  ///
  /// In ja, this message translates to:
  /// **'通知時刻'**
  String get notificationTime;

  /// 変更保存ボタン
  ///
  /// In ja, this message translates to:
  /// **'変更を保存'**
  String get saveChanges;

  /// タスク作成ボタン
  ///
  /// In ja, this message translates to:
  /// **'タスクを作成'**
  String get createTask;

  /// 日付選択エラー
  ///
  /// In ja, this message translates to:
  /// **'開始日と終了日を選択してください。'**
  String get selectStartDate;

  /// 日付範囲エラー
  ///
  /// In ja, this message translates to:
  /// **'終了日は開始日以降を選択してください。'**
  String get endDateAfterStart;

  /// 日付未選択エラー
  ///
  /// In ja, this message translates to:
  /// **'日付を選択してください。'**
  String get selectDate;

  /// 難易度：簡単
  ///
  /// In ja, this message translates to:
  /// **'Easy'**
  String get difficultyEasy;

  /// 難易度：普通
  ///
  /// In ja, this message translates to:
  /// **'Normal'**
  String get difficultyNormal;

  /// 難易度：難しい
  ///
  /// In ja, this message translates to:
  /// **'Hard'**
  String get difficultyHard;

  /// タスク完了ボタン
  ///
  /// In ja, this message translates to:
  /// **'完了にする'**
  String get completeTask;

  /// 削除確認ダイアログタイトル
  ///
  /// In ja, this message translates to:
  /// **'タスクを削除しますか？'**
  String get deleteTask;

  /// 削除警告メッセージ
  ///
  /// In ja, this message translates to:
  /// **'この操作は取り消せません。'**
  String get deleteWarning;

  /// キャンセルボタン
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get cancel;

  /// 削除ボタン
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get delete;

  /// 削除完了メッセージ
  ///
  /// In ja, this message translates to:
  /// **'タスクを削除しました。'**
  String get taskDeleted;

  /// 既に完了済みメッセージ
  ///
  /// In ja, this message translates to:
  /// **'本日は既に完了しています'**
  String get alreadyCompletedToday;

  /// タスク完了ダイアログタイトル
  ///
  /// In ja, this message translates to:
  /// **'クエスト達成！'**
  String get questAchieved;

  /// XP獲得メッセージ
  ///
  /// In ja, this message translates to:
  /// **'{xp} XPを獲得しました！'**
  String xpGained(int xp);

  /// OKボタン
  ///
  /// In ja, this message translates to:
  /// **'OK'**
  String get ok;

  /// 完了済みタスク画面タイトル
  ///
  /// In ja, this message translates to:
  /// **'完了済みタスク'**
  String get completedTasks;

  /// 完了済みタスクなし
  ///
  /// In ja, this message translates to:
  /// **'完了済みのタスクはまだありません。'**
  String get noCompletedTasks;

  /// 獲得XP表示
  ///
  /// In ja, this message translates to:
  /// **'獲得XP: {xp}'**
  String earnedXp(int xp);

  /// 完了日表示
  ///
  /// In ja, this message translates to:
  /// **'完了日: {date}'**
  String completionDate(String date);

  /// ペンギンルーム準備中メッセージ
  ///
  /// In ja, this message translates to:
  /// **'ペンギンルームは準備中！'**
  String get penguinRoomComingSoon;

  /// ペンギンルームの説明
  ///
  /// In ja, this message translates to:
  /// **'次のアップデートでミッションや表情変化が登場予定です。'**
  String get penguinRoomDescription;

  /// 連続達成日数
  ///
  /// In ja, this message translates to:
  /// **'{days}日連続'**
  String streakDays(int days);

  /// リマインダー有効表示
  ///
  /// In ja, this message translates to:
  /// **'Reminder ON'**
  String get reminderOn;

  /// スケジュール：いつでも
  ///
  /// In ja, this message translates to:
  /// **'いつでも'**
  String get anytime;

  /// エラーメッセージ
  ///
  /// In ja, this message translates to:
  /// **'エラー: {message}'**
  String error(String message);

  /// オンボーディング：ウェルカムタイトル
  ///
  /// In ja, this message translates to:
  /// **'Habit Penguinへようこそ！'**
  String get onboardingWelcomeTitle;

  /// オンボーディング：ウェルカム説明
  ///
  /// In ja, this message translates to:
  /// **'楽しく、モチベーションを保ちながらより良い習慣を作りましょう。日々のタスクを記録して、レベルアップしよう！'**
  String get onboardingWelcomeDescription;

  /// オンボーディング：機能1タイトル
  ///
  /// In ja, this message translates to:
  /// **'XPを獲得してレベルアップ'**
  String get onboardingFeature1Title;

  /// オンボーディング：機能1説明
  ///
  /// In ja, this message translates to:
  /// **'タスクを完了すると経験値を獲得できます。難しいタスクほど多くのXPがもらえます！'**
  String get onboardingFeature1Description;

  /// オンボーディング：機能1ポイント1
  ///
  /// In ja, this message translates to:
  /// **'Easyタスク: 10 XP'**
  String get onboardingFeature1Point1;

  /// オンボーディング：機能1ポイント2
  ///
  /// In ja, this message translates to:
  /// **'Normalタスク: 20 XP'**
  String get onboardingFeature1Point2;

  /// オンボーディング：機能1ポイント3
  ///
  /// In ja, this message translates to:
  /// **'Hardタスク: 30 XP'**
  String get onboardingFeature1Point3;

  /// オンボーディング：機能2タイトル
  ///
  /// In ja, this message translates to:
  /// **'連続記録を追跡'**
  String get onboardingFeature2Title;

  /// オンボーディング：機能2説明
  ///
  /// In ja, this message translates to:
  /// **'毎日タスクを完了して勢いをつけましょう。連続記録を維持してモチベーションを保とう！'**
  String get onboardingFeature2Description;

  /// オンボーディング：機能2ポイント1
  ///
  /// In ja, this message translates to:
  /// **'毎日のタスク完了'**
  String get onboardingFeature2Point1;

  /// オンボーディング：機能2ポイント2
  ///
  /// In ja, this message translates to:
  /// **'カスタマイズ可能なリマインダー'**
  String get onboardingFeature2Point2;

  /// オンボーディング：機能2ポイント3
  ///
  /// In ja, this message translates to:
  /// **'完了履歴の記録'**
  String get onboardingFeature2Point3;

  /// オンボーディング：サンプルタイトル
  ///
  /// In ja, this message translates to:
  /// **'さあ、始めましょう！'**
  String get onboardingSampleTitle;

  /// オンボーディング：サンプル説明
  ///
  /// In ja, this message translates to:
  /// **'サンプルタスクから始めて、使い方を確認しますか？'**
  String get onboardingSampleDescription;

  /// オンボーディング：サンプル作成ボタン
  ///
  /// In ja, this message translates to:
  /// **'サンプルタスクを作成'**
  String get onboardingCreateSampleTasks;

  /// オンボーディング：ゼロから始めるボタン
  ///
  /// In ja, this message translates to:
  /// **'ゼロから始める'**
  String get onboardingStartFromScratch;

  /// オンボーディング：次へボタン
  ///
  /// In ja, this message translates to:
  /// **'次へ'**
  String get onboardingNext;

  /// オンボーディング：戻るボタン
  ///
  /// In ja, this message translates to:
  /// **'戻る'**
  String get onboardingBack;

  /// 空状態：タイトル
  ///
  /// In ja, this message translates to:
  /// **'タスクを追加して始めましょう'**
  String get emptyStateTitle;

  /// 空状態：説明
  ///
  /// In ja, this message translates to:
  /// **'右下の＋ボタンをタップして、最初の習慣タスクを作成しましょう。'**
  String get emptyStateDescription;

  /// 空状態：タスク作成ボタン
  ///
  /// In ja, this message translates to:
  /// **'最初のタスクを作成'**
  String get emptyStateCreateTask;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
