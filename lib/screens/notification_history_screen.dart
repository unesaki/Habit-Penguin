import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/notification_history.dart';

/// 通知履歴画面
class NotificationHistoryScreen extends ConsumerWidget {
  const NotificationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知履歴'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'すべて削除',
            onPressed: () => _confirmClearHistory(context),
          ),
        ],
      ),
      body: ValueListenableBuilder<Box<NotificationHistory>>(
        valueListenable: Hive.box<NotificationHistory>('notification_history').listenable(),
        builder: (context, box, _) {
          final history = box.values.toList()
            ..sort((a, b) => b.sentAt.compareTo(a.sentAt)); // 新しい順にソート

          if (history.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: history.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = history[index];
              return _NotificationHistoryCard(item: item);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '通知履歴はありません',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'タスクのリマインダーが送信されると\nここに表示されます',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('履歴を削除'),
        content: const Text('すべての通知履歴を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final box = Hive.box<NotificationHistory>('notification_history');
      await box.clear();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通知履歴を削除しました')),
        );
      }
    }
  }
}

class _NotificationHistoryCard extends StatelessWidget {
  const _NotificationHistoryCard({required this.item});

  final NotificationHistory item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('M/d HH:mm');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  item.tapped
                      ? Icons.notifications_active
                      : Icons.notifications_outlined,
                  color: item.tapped
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.taskName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Text(
                  '送信: ${dateFormat.format(item.sentAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (item.tapped && item.tappedAt != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.touch_app,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'タップ: ${dateFormat.format(item.tappedAt!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
            if (!item.tapped) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '未開封',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
