import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../models/advanced_notification_settings.dart';

/// 高度な通知設定画面
class AdvancedNotificationScreen extends ConsumerStatefulWidget {
  const AdvancedNotificationScreen({
    super.key,
    required this.taskId,
    required this.taskName,
  });

  final int taskId;
  final String taskName;

  @override
  ConsumerState<AdvancedNotificationScreen> createState() =>
      _AdvancedNotificationScreenState();
}

class _AdvancedNotificationScreenState
    extends ConsumerState<AdvancedNotificationScreen> {
  List<TimeOfDay> _reminderTimes = [];
  Set<int> _enabledWeekdays = {0, 1, 2, 3, 4, 5, 6}; // すべての曜日

  final List<String> _weekdayNames = ['月', '火', '水', '木', '金', '土', '日'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final box = Hive.box<AdvancedNotificationSettings>(
        'advanced_notification_settings');

    // このタスクIDの設定を探す
    final existingSettings = box.values.firstWhere(
      (settings) => settings.taskId == widget.taskId,
      orElse: () => AdvancedNotificationSettings(
        taskId: widget.taskId,
        reminderTimes: const [TimeOfDay(hour: 9, minute: 0)],
        enabledWeekdays: const [0, 1, 2, 3, 4, 5, 6],
      ),
    );

    setState(() {
      _reminderTimes = List.from(existingSettings.reminderTimes);
      _enabledWeekdays = Set.from(existingSettings.enabledWeekdays);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('高度な通知設定'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // タスク名
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.task_alt,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.taskName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 複数通知時刻
          Text(
            '通知時刻（最大5つ）',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '複数の時刻に通知を受け取ることができます',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          ..._reminderTimes.asMap().entries.map((entry) {
            final index = entry.key;
            final time = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  child: Text('${index + 1}'),
                ),
                title: Text(
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editReminderTime(index),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _removeReminderTime(index),
                    ),
                  ],
                ),
              ),
            );
          }),

          if (_reminderTimes.length < 5)
            OutlinedButton.icon(
              onPressed: _addReminderTime,
              icon: const Icon(Icons.add),
              label: const Text('通知時刻を追加'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),

          const SizedBox(height: 32),

          // 曜日別設定
          Text(
            '通知する曜日',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '選択した曜日のみ通知を受け取ります',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(7, (index) {
              final isEnabled = _enabledWeekdays.contains(index);
              return FilterChip(
                label: Text(_weekdayNames[index]),
                selected: isEnabled,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _enabledWeekdays.add(index);
                    } else {
                      _enabledWeekdays.remove(index);
                    }
                  });
                },
                selectedColor: theme.colorScheme.primaryContainer,
                checkmarkColor: theme.colorScheme.primary,
              );
            }),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _enabledWeekdays = {0, 1, 2, 3, 4}; // 平日のみ
                    });
                  },
                  child: const Text('平日のみ'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _enabledWeekdays = {5, 6}; // 週末のみ
                    });
                  },
                  child: const Text('週末のみ'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _enabledWeekdays = {0, 1, 2, 3, 4, 5, 6}; // すべて
                    });
                  },
                  child: const Text('毎日'),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _saveSettings,
            child: const Text('設定を保存'),
          ),
        ),
      ),
    );
  }

  Future<void> _addReminderTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );

    if (time != null) {
      setState(() {
        _reminderTimes.add(time);
        _reminderTimes.sort((a, b) {
          if (a.hour != b.hour) return a.hour.compareTo(b.hour);
          return a.minute.compareTo(b.minute);
        });
      });
    }
  }

  Future<void> _editReminderTime(int index) async {
    final time = await showTimePicker(
      context: context,
      initialTime: _reminderTimes[index],
    );

    if (time != null) {
      setState(() {
        _reminderTimes[index] = time;
        _reminderTimes.sort((a, b) {
          if (a.hour != b.hour) return a.hour.compareTo(b.hour);
          return a.minute.compareTo(b.minute);
        });
      });
    }
  }

  void _removeReminderTime(int index) {
    setState(() {
      _reminderTimes.removeAt(index);
    });
  }

  Future<void> _saveSettings() async {
    if (_reminderTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('少なくとも1つの通知時刻を設定してください')),
      );
      return;
    }

    if (_enabledWeekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('少なくとも1つの曜日を選択してください')),
      );
      return;
    }

    // Hiveに保存
    final box = Hive.box<AdvancedNotificationSettings>(
        'advanced_notification_settings');

    // 既存の設定を探す
    AdvancedNotificationSettings? existingSettings;
    int? existingKey;

    for (final entry in box.toMap().entries) {
      if (entry.value.taskId == widget.taskId) {
        existingSettings = entry.value;
        existingKey = entry.key;
        break;
      }
    }

    if (existingSettings != null && existingKey != null) {
      // 既存の設定を更新
      existingSettings.reminderTimes = _reminderTimes;
      existingSettings.enabledWeekdays = _enabledWeekdays.toList();
      await existingSettings.save();
    } else {
      // 新規作成
      final newSettings = AdvancedNotificationSettings(
        taskId: widget.taskId,
        reminderTimes: _reminderTimes,
        enabledWeekdays: _enabledWeekdays.toList(),
      );
      await box.add(newSettings);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('設定を保存しました')),
    );

    Navigator.of(context).pop();
  }
}
