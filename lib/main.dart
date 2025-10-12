import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/habit_task.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(HabitTaskAdapter());
  await Hive.openBox<HabitTask>('tasks');
  await Hive.openBox('appState');
  runApp(const HabitPenguinApp());
}

class HabitPenguinApp extends StatelessWidget {
  const HabitPenguinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habit Penguin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlueAccent),
        useMaterial3: true,
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const HabitHomeShell(),
    );
  }
}

class HabitHomeShell extends StatefulWidget {
  const HabitHomeShell({super.key});

  @override
  State<HabitHomeShell> createState() => _HabitHomeShellState();
}

class _HabitHomeShellState extends State<HabitHomeShell> {
  int _currentIndex = 1;

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _openTaskForm(
    BuildContext context, {
    HabitTask? initialTask,
    int? taskIndex,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            TaskFormPage(initialTask: initialTask, taskIndex: taskIndex),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabTitles = ['Tasks', 'Home', 'Penguin'];
    return Scaffold(
      appBar: AppBar(
        title: Text('Habit Penguin - ${tabTitles[_currentIndex]}'),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          TasksTab(
            onEditTask: (index, task) {
              _openTaskForm(context, initialTask: task, taskIndex: index);
            },
          ),
          const HomeTab(),
          const PenguinTab(),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () => _openTaskForm(context),
              tooltip: 'Add Task',
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.checklist), label: 'Tasks'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_people),
            label: 'Penguin',
          ),
        ],
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late final Box<HabitTask> _tasksBox;

  @override
  void initState() {
    super.initState();
    _tasksBox = Hive.box<HabitTask>('tasks');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<HabitTask>>(
      valueListenable: _tasksBox.listenable(),
      builder: (context, tasksBox, _) {
        final today = DateTime.now();
        final todaysEntries = <MapEntry<int, HabitTask>>[];
        var openTaskCount = 0;
        for (var i = 0; i < tasksBox.length; i++) {
          final task = tasksBox.getAt(i);
          if (task == null || task.isCompleted) {
            continue;
          }
          openTaskCount++;
          if (todaysEntries.length < 3 && task.isActiveOn(today)) {
            todaysEntries.add(MapEntry(i, task));
          }
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.35),
                Theme.of(context).colorScheme.surface,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PenguinHeroSection(totalTasks: openTaskCount),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        Text(
                          '今日のタスク',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        if (todaysEntries.isEmpty) ...[
                          const _CreateTaskCallout(),
                        ] else ...[
                          for (var i = 0; i < todaysEntries.length; i++)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: i == todaysEntries.length - 1 ? 0 : 12,
                              ),
                              child: _TodayTaskCard(
                                task: todaysEntries[i].value,
                                index: todaysEntries[i].key,
                              ),
                            ),
                          if (openTaskCount > todaysEntries.length)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(
                                '残りのタスクはTasksタブで確認できます。',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.secondary,
                                    ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PenguinHeroSection extends StatelessWidget {
  const _PenguinHeroSection({required this.totalTasks});

  final int totalTasks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final heroHeight = math.max(screenHeight * 0.5, 360.0);
    return SizedBox(
      height: heroHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final penguinWidth = math.min(width * 0.55, 260.0);
          final iceWidth = math.min(width * 0.95, 380.0);
          final penguinBottom = heroHeight * 0.01;
          final iceBottom = -heroHeight * 0.2;
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/bg.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.15),
                        Colors.transparent,
                        theme.colorScheme.surface.withValues(alpha: 0.85),
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 32,
                left: 24,
                right: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'おかえり！',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'ペンギンと一緒に今日のクエストをこなそう',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: iceBottom,
                left: (width - iceWidth) / 2,
                child: SizedBox(
                  width: iceWidth,
                  child: Image.asset('assets/ice.png', fit: BoxFit.contain),
                ),
              ),
              Positioned(
                bottom: penguinBottom,
                left: (width - penguinWidth) / 2,
                child: SizedBox(
                  width: penguinWidth,
                  child: Image.asset(
                    'assets/penguin_normal.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              // Positioned(
              //   left: 24,
              //   right: 24,
              //   bottom: 24,
              //   child: Container(
              //     padding: const EdgeInsets.symmetric(
              //       horizontal: 20,
              //       vertical: 18,
              //     ),
              //     decoration: BoxDecoration(
              //       color: surfaceOverlay.withValues(alpha: 0.9),
              //       borderRadius: BorderRadius.circular(24),
              //     ),
              //     // child: Row(
              //     //   children: [
              //     //     const Icon(Icons.emoji_events, size: 22),
              //     //     const SizedBox(width: 12),
              //     //     Expanded(
              //     //       child: Text(
              //     //         'クエストは$totalTasks件！達成でペンギンにごほうびをあげよう。',
              //     //         style: theme.textTheme.bodyMedium?.copyWith(
              //     //           color: theme.colorScheme.onSurface.withValues(
              //     //             alpha: 0.95,
              //     //           ),
              //     //         ),
              //     //       ),
              //     //     ),
              //     //   ],
              //     // ),
              //   ),
              // ),
            ],
          );
        },
      ),
    );
  }
}

class _TodayTaskCard extends StatelessWidget {
  const _TodayTaskCard({required this.task, required this.index});

  final HabitTask task;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TaskFormPage(initialTask: task, taskIndex: index),
            ),
          );
        },
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: Icon(task.iconData, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_difficultyLabel(task.difficulty)} • ${_scheduleLabel(task)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateTaskCallout extends StatelessWidget {
  const _CreateTaskCallout();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
            child: const Icon(Icons.add_task),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '今日のクエストを作成しよう',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tasksタブ右下の「＋」ボタンから新しいタスクを追加できます。',
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

class TasksTab extends StatelessWidget {
  const TasksTab({super.key, required this.onEditTask});

  final void Function(int index, HabitTask task) onEditTask;

  @override
  Widget build(BuildContext context) {
    final tasksBox = Hive.box<HabitTask>('tasks');
    final appStateBox = Hive.box('appState');

    return ValueListenableBuilder<Box>(
      valueListenable: appStateBox.listenable(),
      builder: (context, appState, _) {
        final currentXp = (appState.get('xp') as int?) ?? 0;
        return ValueListenableBuilder<Box<HabitTask>>(
          valueListenable: tasksBox.listenable(),
          builder: (context, box, __) {
            final today = DateTime.now();
            final activeEntries = <MapEntry<int, HabitTask>>[];
            final openEntries = <MapEntry<int, HabitTask>>[];

            for (var i = 0; i < box.length; i++) {
              final task = box.getAt(i);
              if (task == null) continue;
              if (task.isCompleted) {
                continue;
              }
              final entry = MapEntry(i, task);
              openEntries.add(entry);
              if (task.isActiveOn(today)) {
                activeEntries.add(entry);
              }
            }

            final activeKeys = activeEntries.map((entry) => entry.key).toSet();
            final backlogEntries = openEntries
                .where((entry) => !activeKeys.contains(entry.key))
                .toList();

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                Row(
                  children: [
                    Text(
                      '経験値: $currentXp XP',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _openCompletedTasks(context),
                      icon: const Icon(Icons.history),
                      label: const Text('完了済み'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('今日のタスク', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                if (activeEntries.isEmpty)
                  Text(
                    '今日は予定されたタスクがありません。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else
                  ...activeEntries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TaskListTile(
                        task: entry.value,
                        onTap: () => onEditTask(entry.key, entry.value),
                        onDelete: () => _confirmDelete(context, entry.key),
                        onComplete: () => _completeTask(context, entry.key),
                        isActive: true,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Text('登録中のタスク', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                if (openEntries.isEmpty)
                  Text(
                    'タスクがまだありません。右下の＋で追加しよう。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else
                  ...backlogEntries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TaskListTile(
                        task: entry.value,
                        onTap: () => onEditTask(entry.key, entry.value),
                        onDelete: () => _confirmDelete(context, entry.key),
                        onComplete: () => _completeTask(context, entry.key),
                        isActive: entry.value.isActiveOn(today),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, int index) async {
    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('タスクを削除しますか？'),
            content: const Text('この操作は取り消せません。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('削除'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) {
      return;
    }

    final box = Hive.box<HabitTask>('tasks');
    await box.deleteAt(index);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('タスクを削除しました。')));
  }

  Future<void> _completeTask(BuildContext context, int index) async {
    final tasksBox = Hive.box<HabitTask>('tasks');
    final task = tasksBox.getAt(index);
    if (task == null || task.isCompleted) {
      return;
    }

    final gainedXp = _xpForDifficulty(task.difficulty);

    task
      ..isCompleted = true
      ..completedAt = DateTime.now()
      ..completionXp = gainedXp;
    await task.save();

    final appStateBox = Hive.box('appState');
    final currentXp = (appStateBox.get('xp') as int?) ?? 0;
    await appStateBox.put('xp', currentXp + gainedXp);

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$gainedXp XP獲得！')));
    }
  }

  void _openCompletedTasks(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const CompletedTasksPage()));
  }
}

class TaskFormPage extends StatefulWidget {
  const TaskFormPage({super.key, this.initialTask, this.taskIndex});

  final HabitTask? initialTask;
  final int? taskIndex;

  @override
  State<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends State<TaskFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late bool _reminderEnabled;
  late int _selectedIconCodePoint;
  late TaskDifficulty _selectedDifficulty;
  DateTime? _scheduledDate;
  bool _isRepeating = false;
  DateTime? _repeatStart;
  DateTime? _repeatEnd;

  @override
  void initState() {
    super.initState();
    final initialTask = widget.initialTask;
    _nameController = TextEditingController(text: initialTask?.name ?? '');
    _reminderEnabled = initialTask?.reminderEnabled ?? false;
    _selectedIconCodePoint =
        initialTask?.iconCodePoint ?? _iconOptions.first.codePoint;
    _selectedDifficulty = initialTask?.difficulty ?? TaskDifficulty.normal;
    _isRepeating = initialTask?.isRepeating ?? false;
    _repeatStart = initialTask?.repeatStart;
    _repeatEnd = initialTask?.repeatEnd;
    _scheduledDate = initialTask?.scheduledDate ?? DateTime.now();
    if (_isRepeating) {
      _scheduledDate = null;
      _repeatStart ??= DateTime.now();
      _repeatEnd ??= _repeatStart;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.taskIndex != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'タスクを編集' : 'タスクを追加')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Habit名'),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Habit名を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Text('Icon', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _iconOptions.map((icon) {
                  final selected = _selectedIconCodePoint == icon.codePoint;
                  return ChoiceChip(
                    label: Icon(icon),
                    selected: selected,
                    selectedColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    onSelected: (_) {
                      setState(() {
                        _selectedIconCodePoint = icon.codePoint;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Text('難易度', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SegmentedButton<TaskDifficulty>(
                segments: const [
                  ButtonSegment(
                    value: TaskDifficulty.easy,
                    label: Text('Easy'),
                  ),
                  ButtonSegment(
                    value: TaskDifficulty.normal,
                    label: Text('Normal'),
                  ),
                  ButtonSegment(
                    value: TaskDifficulty.hard,
                    label: Text('Hard'),
                  ),
                ],
                selected: {_selectedDifficulty},
                onSelectionChanged: (selection) {
                  setState(() {
                    _selectedDifficulty = selection.first;
                  });
                },
              ),
              const SizedBox(height: 24),
              Text('日付', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (!_isRepeating)
                _DateFieldTile(
                  label: '日付',
                  value: _scheduledDate != null
                      ? _formatDateLabel(_scheduledDate!)
                      : '未選択',
                  onTap: _pickScheduledDate,
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('繰り返しタスク'),
                subtitle: const Text('開始と終了期間を設定できます'),
                value: _isRepeating,
                onChanged: (value) {
                  setState(() {
                    _isRepeating = value;
                    if (value) {
                      _repeatStart ??= _scheduledDate ?? DateTime.now();
                      _repeatEnd ??= _repeatStart;
                      _scheduledDate = null;
                    } else {
                      _scheduledDate = _repeatStart ?? DateTime.now();
                      _repeatStart = null;
                      _repeatEnd = null;
                    }
                  });
                },
              ),
              if (_isRepeating) ...[
                _DateFieldTile(
                  label: '開始日',
                  value: _repeatStart != null
                      ? _formatDateLabel(_repeatStart!)
                      : '未選択',
                  onTap: _pickRepeatStart,
                ),
                const SizedBox(height: 12),
                _DateFieldTile(
                  label: '終了日',
                  value: _repeatEnd != null
                      ? _formatDateLabel(_repeatEnd!)
                      : '未選択',
                  onTap: _pickRepeatEnd,
                ),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Reminder'),
                value: _reminderEnabled,
                onChanged: (value) {
                  setState(() {
                    _reminderEnabled = value;
                  });
                },
              ),
              const SizedBox(height: 32),
              FilledButton(onPressed: _saveTask, child: const Text('保存')),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveTask() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    DateTime? scheduledDate;
    DateTime? repeatStart;
    DateTime? repeatEnd;

    if (_isRepeating) {
      if (_repeatStart == null || _repeatEnd == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('開始日と終了日を選択してください。')),
        );
        return;
      }
      if (_repeatEnd!.isBefore(_repeatStart!)) {
        messenger.showSnackBar(
          const SnackBar(content: Text('終了日は開始日以降を選択してください。')),
        );
        return;
      }
      repeatStart = _asDateOnly(_repeatStart!);
      repeatEnd = _asDateOnly(_repeatEnd!);
    } else {
      if (_scheduledDate == null) {
        messenger.showSnackBar(const SnackBar(content: Text('日付を選択してください。')));
        return;
      }
      scheduledDate = _asDateOnly(_scheduledDate!);
    }

    final tasksBox = Hive.box<HabitTask>('tasks');
    if (widget.taskIndex == null) {
      final task = HabitTask(
        name: _nameController.text.trim(),
        iconCodePoint: _selectedIconCodePoint,
        reminderEnabled: _reminderEnabled,
        difficulty: _selectedDifficulty,
        scheduledDate: scheduledDate,
        repeatStart: repeatStart,
        repeatEnd: repeatEnd,
      );
      await tasksBox.add(task);
    } else {
      final existing = widget.initialTask;
      if (existing != null) {
        existing
          ..name = _nameController.text.trim()
          ..iconCodePoint = _selectedIconCodePoint
          ..reminderEnabled = _reminderEnabled
          ..difficulty = _selectedDifficulty
          ..scheduledDate = scheduledDate
          ..repeatStart = repeatStart
          ..repeatEnd = repeatEnd;
        await existing.save();
      }
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  Future<void> _pickScheduledDate() async {
    final initial = _scheduledDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _scheduledDate = _asDateOnly(picked);
      });
    }
  }

  Future<void> _pickRepeatStart() async {
    final base = _repeatStart ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _repeatStart = _asDateOnly(picked);
        if (_repeatEnd != null && _repeatEnd!.isBefore(_repeatStart!)) {
          _repeatEnd = _repeatStart;
        }
      });
    }
  }

  Future<void> _pickRepeatEnd() async {
    final base = _repeatEnd ?? _repeatStart ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _repeatEnd = _asDateOnly(picked);
      });
    }
  }

  DateTime _asDateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

class _DateFieldTile extends StatelessWidget {
  const _DateFieldTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value),
      trailing: const Icon(Icons.calendar_today_outlined),
      onTap: onTap,
    );
  }
}

class _TaskListTile extends StatelessWidget {
  const _TaskListTile({
    required this.task,
    required this.onTap,
    required this.onDelete,
    required this.onComplete,
    required this.isActive,
  });

  final HabitTask task;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onComplete;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decoration = BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      border: isActive
          ? Border.all(color: theme.colorScheme.primary, width: 1.2)
          : null,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: decoration,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  task.iconData,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${_difficultyLabel(task.difficulty)} • ${_scheduleLabel(task)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    if (task.reminderEnabled)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Reminder ON',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline),
                    color: theme.colorScheme.primary,
                    tooltip: '完了にする',
                    onPressed: onComplete,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CompletedTasksPage extends StatelessWidget {
  const CompletedTasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tasksBox = Hive.box<HabitTask>('tasks');
    final appStateBox = Hive.box('appState');

    return ValueListenableBuilder<Box>(
      valueListenable: appStateBox.listenable(),
      builder: (context, appState, _) {
        final currentXp = (appState.get('xp') as int?) ?? 0;
        return Scaffold(
          appBar: AppBar(
            title: const Text('完了済みタスク'),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Center(child: Text('経験値: $currentXp XP')),
              ),
            ],
          ),
          body: ValueListenableBuilder<Box<HabitTask>>(
            valueListenable: tasksBox.listenable(),
            builder: (context, box, __) {
              final completed = <HabitTask>[];
              for (var i = 0; i < box.length; i++) {
                final task = box.getAt(i);
                if (task == null || !task.isCompleted) continue;
                completed.add(task);
              }
              completed.sort((a, b) {
                final aDate =
                    a.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                final bDate =
                    b.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                return bDate.compareTo(aDate);
              });

              if (completed.isEmpty) {
                return Center(
                  child: Text(
                    '完了済みのタスクはまだありません。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: completed.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final task = completed[index];
                  final xp =
                      task.completionXp ?? _xpForDifficulty(task.difficulty);
                  final completedAt = task.completedAt;
                  final parts = <String>[
                    _difficultyLabel(task.difficulty),
                    '獲得XP: $xp',
                  ];
                  if (completedAt != null) {
                    parts.add('完了日: ${_formatDateLabel(completedAt)}');
                  }

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.secondaryContainer,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onSecondaryContainer,
                      child: Icon(task.iconData),
                    ),
                    title: Text(task.name),
                    subtitle: Text(parts.join(' • ')),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class PenguinTab extends StatelessWidget {
  const PenguinTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/penguin_normal.png', width: 160),
            const SizedBox(height: 16),
            Text(
              'ペンギンルームは準備中！',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '次のアップデートでミッションや表情変化が登場予定です。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

String _difficultyLabel(TaskDifficulty difficulty) {
  switch (difficulty) {
    case TaskDifficulty.easy:
      return 'Easy';
    case TaskDifficulty.normal:
      return 'Normal';
    case TaskDifficulty.hard:
      return 'Hard';
  }
}

String _scheduleLabel(HabitTask task) {
  if (task.isRepeating && task.repeatStart != null && task.repeatEnd != null) {
    return '${_formatDateLabel(task.repeatStart!)} 〜 ${_formatDateLabel(task.repeatEnd!)}';
  }
  if (task.scheduledDate != null) {
    return _formatDateLabel(task.scheduledDate!);
  }
  return 'いつでも';
}

String _formatDateLabel(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}/$month/$day';
}

int _xpForDifficulty(TaskDifficulty difficulty) {
  switch (difficulty) {
    case TaskDifficulty.easy:
      return 5;
    case TaskDifficulty.normal:
      return 30;
    case TaskDifficulty.hard:
      return 50;
  }
}

const List<IconData> _iconOptions = [
  Icons.check_circle,
  Icons.self_improvement,
  Icons.local_fire_department,
  Icons.water_drop,
  Icons.bookmark,
  Icons.fitness_center,
  Icons.brush,
  Icons.nightlight_round,
];
