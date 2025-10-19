import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

/// 通知設定画面
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  late Box _settingsBox;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _showPreview = true;
  String _notificationPriority = 'high';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _settingsBox = await Hive.openBox('notification_settings');
    setState(() {
      _soundEnabled = _settingsBox.get('sound_enabled', defaultValue: true);
      _vibrationEnabled =
          _settingsBox.get('vibration_enabled', defaultValue: true);
      _showPreview = _settingsBox.get('show_preview', defaultValue: true);
      _notificationPriority =
          _settingsBox.get('notification_priority', defaultValue: 'high');
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('通知設定'),
      ),
      body: ListView(
        children: [
          _buildSection(
            context,
            title: '通知の動作',
            children: [
              SwitchListTile(
                title: const Text('サウンド'),
                subtitle: const Text('通知時に音を鳴らす'),
                value: _soundEnabled,
                onChanged: (value) {
                  setState(() {
                    _soundEnabled = value;
                  });
                  _saveSetting('sound_enabled', value);
                },
              ),
              SwitchListTile(
                title: const Text('バイブレーション'),
                subtitle: const Text('通知時に振動する（Android）'),
                value: _vibrationEnabled,
                onChanged: (value) {
                  setState(() {
                    _vibrationEnabled = value;
                  });
                  _saveSetting('vibration_enabled', value);
                },
              ),
              SwitchListTile(
                title: const Text('プレビュー表示'),
                subtitle: const Text('ロック画面で通知内容を表示'),
                value: _showPreview,
                onChanged: (value) {
                  setState(() {
                    _showPreview = value;
                  });
                  _saveSetting('show_preview', value);
                },
              ),
            ],
          ),
          const Divider(height: 1),
          _buildSection(
            context,
            title: '通知の優先度',
            children: [
              RadioGroup<String>(
                groupValue: _notificationPriority,
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _notificationPriority = value;
                  });
                  _saveSetting('notification_priority', value);
                },
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text('高'),
                      subtitle: const Text('すぐに表示され、音が鳴ります'),
                      value: 'high',
                    ),
                    RadioListTile<String>(
                      title: const Text('標準'),
                      subtitle: const Text('通常の通知として表示されます'),
                      value: 'default',
                    ),
                    RadioListTile<String>(
                      title: const Text('低'),
                      subtitle: const Text('静かに通知バーに表示されます'),
                      value: 'low',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 1),
          _buildSection(
            context,
            title: 'テスト',
            children: [
              ListTile(
                leading: const Icon(Icons.notifications_active),
                title: const Text('テスト通知を送信'),
                subtitle: const Text('通知設定を確認できます'),
                onTap: () => _sendTestNotification(context),
              ),
            ],
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ヒント',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '通知が届かない場合は、デバイスの設定から「Habit Penguin」アプリの通知権限を確認してください。',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ...children,
      ],
    );
  }

  Future<void> _sendTestNotification(BuildContext context) async {
    // テスト通知を送信
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('テスト通知を送信しました'),
        duration: Duration(seconds: 2),
      ),
    );

    // TODO: 実際のテスト通知を送信
    // NotificationService().showTestNotification();
  }
}
