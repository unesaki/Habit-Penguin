import 'package:flutter/material.dart';

/// 使い方ガイド画面
class HowToUseScreen extends StatelessWidget {
  const HowToUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final isJapanese = locale.languageCode == 'ja';

    return Scaffold(
      appBar: AppBar(
        title: Text(isJapanese ? '使い方ガイド' : 'How to Use'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _GuideSection(
            icon: Icons.add_task,
            title: isJapanese ? 'タスクの作成' : 'Creating Tasks',
            steps: isJapanese
                ? [
                    '1. Tasks タブの右下の「＋」ボタンをタップ',
                    '2. タスク名を入力（例：朝のストレッチ）',
                    '3. アイコンと難易度を選択',
                    '4. スケジュールを設定（一回のみ or 繰り返し）',
                    '5. 必要に応じてリマインダーを設定',
                    '6. 「タスクを作成」ボタンをタップ',
                  ]
                : [
                    '1. Tap the "+" button at the bottom right of the Tasks tab',
                    '2. Enter a task name (e.g., Morning Stretch)',
                    '3. Select an icon and difficulty',
                    '4. Set the schedule (one-time or repeating)',
                    '5. Optionally set a reminder',
                    '6. Tap "Create Task"',
                  ],
          ),
          const SizedBox(height: 24),
          _GuideSection(
            icon: Icons.check_circle,
            title: isJapanese ? 'タスクの完了' : 'Completing Tasks',
            steps: isJapanese
                ? [
                    '1. Home タブまたは Tasks タブでタスクを確認',
                    '2. タスクの右側にあるチェックボタンをタップ',
                    '3. XPを獲得！（難易度に応じて10-30 XP）',
                    '4. ストリークが更新されます',
                  ]
                : [
                    '1. View your tasks in Home or Tasks tab',
                    '2. Tap the check button on the right side of a task',
                    '3. Earn XP! (10-30 XP based on difficulty)',
                    '4. Your streak is updated',
                  ],
          ),
          const SizedBox(height: 24),
          _GuideSection(
            icon: Icons.edit,
            title: isJapanese ? 'タスクの編集' : 'Editing Tasks',
            steps: isJapanese
                ? [
                    '1. Tasks タブでタスクをタップ',
                    '2. 任意の項目を変更',
                    '3. 「変更を保存」ボタンをタップ',
                  ]
                : [
                    '1. Tap a task in the Tasks tab',
                    '2. Modify any field',
                    '3. Tap "Save Changes"',
                  ],
          ),
          const SizedBox(height: 24),
          _GuideSection(
            icon: Icons.swap_vert,
            title: isJapanese ? 'タスクの並び替え' : 'Reordering Tasks',
            steps: isJapanese
                ? [
                    '1. Tasks タブの上部にある「並び替え」ボタン（↕）をタップ',
                    '2. タスクを長押ししてドラッグ',
                    '3. 希望の位置でドロップ',
                    '4. 「×」ボタンで通常モードに戻る',
                  ]
                : [
                    '1. Tap the reorder button (↕) at the top of Tasks tab',
                    '2. Long-press and drag a task',
                    '3. Drop it in the desired position',
                    '4. Tap "×" to exit reorder mode',
                  ],
          ),
          const SizedBox(height: 24),
          _GuideSection(
            icon: Icons.delete,
            title: isJapanese ? 'タスクの削除' : 'Deleting Tasks',
            steps: isJapanese
                ? [
                    '単一削除：',
                    '• タスクをタップして編集画面を開く',
                    '• 下部の「削除」ボタンをタップ',
                    '',
                    '複数削除：',
                    '• Tasks タブの「選択」ボタン（チェックリスト）をタップ',
                    '• 削除したいタスクをタップして選択',
                    '• 上部の「削除」ボタンをタップ',
                  ]
                : [
                    'Single deletion:',
                    '• Tap a task to open edit screen',
                    '• Tap the "Delete" button at the bottom',
                    '',
                    'Multiple deletion:',
                    '• Tap the selection button (checklist icon)',
                    '• Tap tasks you want to delete',
                    '• Tap the delete button at the top',
                  ],
          ),
          const SizedBox(height: 24),
          _GuideSection(
            icon: Icons.undo,
            title: isJapanese ? '取り消し機能' : 'Undo Feature',
            steps: isJapanese
                ? [
                    '削除や完了などの操作を取り消すことができます：',
                    '',
                    '• 操作直後に表示されるスナックバーの「取り消し」をタップ',
                    '• または、Tasks タブ上部の「取り消し」ボタンをタップ',
                    '',
                    '※ 最大20件の操作を記憶しています',
                  ]
                : [
                    'You can undo actions like deletion or completion:',
                    '',
                    '• Tap "Undo" in the snackbar shown after an action',
                    '• Or tap the "Undo" button at the top of Tasks tab',
                    '',
                    '* Up to 20 actions are remembered',
                  ],
          ),
          const SizedBox(height: 24),
          _GuideSection(
            icon: Icons.notifications,
            title: isJapanese ? 'リマインダーの設定' : 'Setting Reminders',
            steps: isJapanese
                ? [
                    '1. タスク作成・編集画面で「通知を受け取る」をON',
                    '2. 「通知時刻」をタップして時刻を選択',
                    '3. タスクを保存',
                    '',
                    '高度な通知設定：',
                    '• タスク編集画面下部の「高度な通知設定」をタップ',
                    '• 繰り返し回数、間隔、優先度などを設定',
                  ]
                : [
                    '1. Turn ON "Enable Notifications" in task creation/edit',
                    '2. Tap "Notification Time" to select a time',
                    '3. Save the task',
                    '',
                    'Advanced notification settings:',
                    '• Tap "Advanced Notification Settings" at bottom',
                    '• Configure repeat count, interval, priority, etc.',
                  ],
          ),
          const SizedBox(height: 24),
          _GuideSection(
            icon: Icons.privacy_tip,
            title: isJapanese ? 'データ管理' : 'Data Management',
            steps: isJapanese
                ? [
                    '設定 > プライバシーとデータ管理 で以下ができます：',
                    '',
                    '• データのエクスポート（JSON形式）',
                    '• すべてのデータの削除',
                    '• プライバシーポリシーの確認',
                    '• 利用規約の確認',
                  ]
                : [
                    'In Settings > Privacy and Data Management:',
                    '',
                    '• Export data (JSON format)',
                    '• Delete all data',
                    '• View privacy policy',
                    '• View terms of service',
                  ],
          ),
          const SizedBox(height: 32),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isJapanese ? 'ヒント' : 'Tips',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isJapanese
                        ? '• 毎日同じ時間にタスクを完了すると習慣化しやすくなります\n'
                            '• 最初は簡単なタスクから始めて、徐々に難易度を上げましょう\n'
                            '• ストリークが途切れても、また今日から始めましょう！\n'
                            '• XPを貯めてレベルアップを目指しましょう'
                        : '• Complete tasks at the same time daily to build habits\n'
                            '• Start with easy tasks and gradually increase difficulty\n'
                            '• If your streak breaks, just start again today!\n'
                            '• Accumulate XP to level up',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({
    required this.icon,
    required this.title,
    required this.steps,
  });

  final IconData icon;
  final String title;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 28),
            const SizedBox(width: 12),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: steps.map((step) {
                if (step.isEmpty) {
                  return const SizedBox(height: 8);
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    step,
                    style: theme.textTheme.bodyMedium,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
