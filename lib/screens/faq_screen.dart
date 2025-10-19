import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// FAQ画面
class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final isJapanese = locale.languageCode == 'ja';

    return Scaffold(
      appBar: AppBar(
        title: Text(isJapanese ? 'よくある質問' : 'FAQ'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _FaqItem(
            question: isJapanese
                ? 'タスクを完了するとどうなりますか？'
                : 'What happens when I complete a task?',
            answer: isJapanese
                ? 'タスクを完了すると、難易度に応じてXP（経験値）を獲得できます：\n\n• Easy: 10 XP\n• Normal: 20 XP\n• Hard: 30 XP\n\n獲得したXPはホーム画面で確認できます。'
                : 'When you complete a task, you earn XP (experience points) based on its difficulty:\n\n• Easy: 10 XP\n• Normal: 20 XP\n• Hard: 30 XP\n\nYou can view your total XP on the Home screen.',
          ),
          _FaqItem(
            question: isJapanese ? 'ストリーク（連続記録）とは何ですか？' : 'What is a streak?',
            answer: isJapanese
                ? 'ストリークは、タスクを連続して完了した日数を表します。毎日タスクを完了することで、ストリークが増えていきます。1日でもタスクを完了しないと、ストリークは0にリセットされます。'
                : 'A streak represents the number of consecutive days you\'ve completed a task. Complete your tasks daily to build your streak. Missing a day will reset your streak to 0.',
          ),
          _FaqItem(
            question: isJapanese
                ? 'タスクの難易度はどのように選べばいいですか？'
                : 'How should I choose task difficulty?',
            answer: isJapanese
                ? '難易度は以下を参考に選択してください：\n\n• Easy: 5-10分で完了できる簡単なタスク\n• Normal: 15-30分かかる普通のタスク\n• Hard: 30分以上かかる、または精神的に負荷の高いタスク\n\n難易度が高いほど、多くのXPを獲得できます。'
                : 'Choose difficulty based on these guidelines:\n\n• Easy: Simple tasks taking 5-10 minutes\n• Normal: Regular tasks taking 15-30 minutes\n• Hard: Tasks taking 30+ minutes or requiring significant mental effort\n\nHigher difficulty = more XP!',
          ),
          _FaqItem(
            question: isJapanese
                ? 'リマインダー通知が届きません'
                : 'I\'m not receiving reminder notifications',
            answer: isJapanese
                ? '通知が届かない場合、以下を確認してください：\n\n1. アプリの通知権限が有効になっているか\n2. デバイスの通知設定でHabit Penguinが許可されているか\n3. タスクのリマインダーがONになっているか\n4. 通知時刻が正しく設定されているか\n\n設定 > 通知設定から確認できます。'
                : 'If you\'re not receiving notifications:\n\n1. Check that notification permissions are enabled for the app\n2. Verify Habit Penguin is allowed in device notification settings\n3. Ensure the task reminder is turned ON\n4. Confirm the notification time is set correctly\n\nYou can check these in Settings > Notification Settings.',
          ),
          _FaqItem(
            question: isJapanese
                ? 'タスクを削除してしまいました。復元できますか？'
                : 'I accidentally deleted a task. Can I restore it?',
            answer: isJapanese
                ? 'はい、削除直後であれば復元できます。タスクを削除すると画面下部にスナックバーが表示され、「取り消し」ボタンが表示されます。このボタンをタップすることで、削除を取り消すことができます。\n\nまた、タスク画面上部の「取り消し」ボタンからも、最後の操作を取り消すことができます。'
                : 'Yes, you can restore it immediately after deletion. When you delete a task, a snackbar appears at the bottom of the screen with an "Undo" button. Tap it to restore the task.\n\nYou can also use the "Undo" button at the top of the Tasks screen to reverse your last action.',
          ),
          _FaqItem(
            question:
                isJapanese ? 'タスクの順番を変更できますか？' : 'Can I reorder my tasks?',
            answer: isJapanese
                ? 'はい、できます。タスク画面の上部にある「並び替えボタン」（↕アイコン）をタップすると、並び替えモードに入ります。タスクを長押ししてドラッグすることで、順番を変更できます。'
                : 'Yes! Tap the reorder button (↕ icon) at the top of the Tasks screen to enter reorder mode. Then, long-press and drag tasks to rearrange them.',
          ),
          _FaqItem(
            question: isJapanese
                ? '複数のタスクを一度に削除できますか？'
                : 'Can I delete multiple tasks at once?',
            answer: isJapanese
                ? 'はい、できます。タスク画面の上部にある「選択ボタン」（チェックリストアイコン）をタップして選択モードに入り、削除したいタスクを選択してから、削除ボタンをタップしてください。'
                : 'Yes! Tap the selection button (checklist icon) at the top of the Tasks screen to enter selection mode. Select the tasks you want to delete, then tap the delete button.',
          ),
          _FaqItem(
            question:
                isJapanese ? 'データはどこに保存されますか？' : 'Where is my data stored?',
            answer: isJapanese
                ? 'すべてのデータは、お使いのデバイスにローカルで保存されます。データはクラウドに送信されず、プライバシーが保護されます。\n\nまた、データは暗号化されて保存されるため、セキュリティも確保されています。'
                : 'All your data is stored locally on your device. No data is sent to the cloud, ensuring your privacy.\n\nAdditionally, your data is encrypted for security.',
          ),
          _FaqItem(
            question: isJapanese ? 'データをバックアップできますか？' : 'Can I backup my data?',
            answer: isJapanese
                ? 'はい、できます。設定 > プライバシーとデータ管理 > データのエクスポートから、すべてのデータをJSON形式でエクスポートできます。エクスポートしたファイルは、バックアップとして保存できます。'
                : 'Yes! Go to Settings > Privacy and Data Management > Export Data to export all your data as a JSON file. You can save this file as a backup.',
          ),
          _FaqItem(
            question: isJapanese
                ? 'オンボーディングをもう一度見たい'
                : 'I want to see the onboarding again',
            answer: isJapanese
                ? '現在のバージョンでは、オンボーディングを再表示する機能はありません。次のアップデートで追加予定です。\n\nアプリの使い方については、このFAQや「使い方ガイド」をご参照ください。'
                : 'Currently, there\'s no feature to replay the onboarding. This will be added in a future update.\n\nFor app usage, please refer to this FAQ and the "How to Use" guide.',
          ),
        ],
      ),
    );
  }
}

class _FaqItem extends StatefulWidget {
  const _FaqItem({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.question,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
              if (_isExpanded) ...[
                const SizedBox(height: 12),
                Text(
                  widget.answer,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
