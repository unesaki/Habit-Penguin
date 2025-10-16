import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'privacy_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'notification_history_screen.dart';

/// メイン設定画面
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        children: [
          // 通知セクション
          _SectionHeader(title: '通知'),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('通知設定'),
            subtitle: const Text('音、バイブレーション、表示設定'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationSettingsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('通知履歴'),
            subtitle: const Text('送信された通知の履歴を確認'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationHistoryScreen(),
                ),
              );
            },
          ),
          const Divider(),

          // プライバシーとデータセクション
          _SectionHeader(title: 'プライバシーとデータ'),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('プライバシーとデータ管理'),
            subtitle: const Text('データのエクスポート、削除、規約'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PrivacySettingsScreen(),
                ),
              );
            },
          ),
          const Divider(),

          // アプリ情報セクション
          _SectionHeader(title: 'アプリ情報'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('バージョン'),
            subtitle: const Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('ライセンス'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showLicensePage(context: context);
            },
          ),
          const Divider(),

          // フィードバックセクション
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'フィードバック',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'ご意見やご要望がございましたら、お気軽にお問い合わせください。',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
