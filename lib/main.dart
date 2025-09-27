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
  int _currentIndex = 0;

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
    final tabTitles = ['Home', 'Tasks'];
    return Scaffold(
      appBar: AppBar(
        title: Text('Habit Penguin - ${tabTitles[_currentIndex]}'),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const HomeTab(),
          TasksTab(
            onEditTask: (index, task) {
              _openTaskForm(context, initialTask: task, taskIndex: index);
            },
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 1
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
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.checklist), label: 'Tasks'),
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
  late final Box _appStateBox;
  final Map<int, bool> _completedToday = <int, bool>{};
  String _todayKey = '';
  int _streak = 0;
  bool _isCheering = false;
  int _cheerMessageIndex = 0;
  String _currentBubbleMessage = 'Good job!';

  @override
  void initState() {
    super.initState();
    _tasksBox = Hive.box<HabitTask>('tasks');
    _appStateBox = Hive.box('appState');
    _todayKey = _formatDate(DateTime.now());
    _streak = (_appStateBox.get('streak') as int?) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/ice_bg.png',
            fit: BoxFit.cover,
          ),
        ),
        SafeArea(
          child: ValueListenableBuilder<Box<HabitTask>>(
            valueListenable: _tasksBox.listenable(),
            builder: (context, box, _) {
              final todaysTasks = <MapEntry<int, HabitTask>>[];
              for (var i = 0; i < box.length && todaysTasks.length < 3; i++) {
                final task = box.getAt(i);
                if (task != null) {
                  todaysTasks.add(MapEntry(i, task));
                }
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Habit Penguin',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF294B72),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.center,
                      child: _SpeechBubble(message: _currentBubbleMessage),
                    ),
                    const SizedBox(height: 28),
                    // Penguin scene should expand to fill available vertical space
                    Expanded(
                      flex: 4,
                      child: _buildPenguinScene(context),
                    ),
                    const SizedBox(height: 28),
                    _buildStreakCard(context),
                    const SizedBox(height: 24),
                    Text(
                      '今日のタスク',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF294B72),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Tasks area: expand to fill remaining space if possible
                    Expanded(
                      flex: 3,
                      child: Builder(
                        builder: (context) {
                          if (todaysTasks.isEmpty) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Text(
                                'タスクがありません。Tasksタブで追加してね。',
                                style: theme.textTheme.bodyMedium,
                              ),
                            );
                          } else {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ...todaysTasks.map((entry) {
                                  final isChecked = _completedToday[entry.key] ?? false;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _TaskCard(
                                      task: entry.value,
                                      isChecked: isChecked,
                                      onToggle: () =>
                                          _handleTaskToggle(context, entry.key, !isChecked),
                                    ),
                                  );
                                }),
                                if (box.length > todaysTasks.length)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '他のタスクはTasksタブで確認できます。',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                              ],
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPenguinScene(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Center(
      child: AnimatedScale(
        scale: _isCheering ? 1.12 : 1.0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutBack,
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Image.asset(
            'assets/penguin_normal.png',
            height: screenWidth * 0.65,
          ),
        ),
      ),
    );
  }

  Widget _buildStreakCard(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_fire_department,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Streak', style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '$_streak日連続',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleTaskToggle(BuildContext context, int taskIndex, bool isChecked) {
    final currentKey = _formatDate(DateTime.now());
    setState(() {
      if (currentKey != _todayKey) {
        _todayKey = currentKey;
        _completedToday.clear();
      }
      if (isChecked) {
        _completedToday[taskIndex] = true;
      } else {
        _completedToday.remove(taskIndex);
      }
    });

    if (isChecked) {
      _triggerCheer(context);
      _updateStreakOnCompletion();
    }
  }

  void _triggerCheer(BuildContext context) {
    final message = _cheerMessages[_cheerMessageIndex % _cheerMessages.length];
    _cheerMessageIndex++;
    setState(() {
      _isCheering = true;
      _currentBubbleMessage = message;
    });
    Future<void>.delayed(const Duration(milliseconds: 480), () {
      if (!mounted) return;
      setState(() {
        _isCheering = false;
      });
    });

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  void _updateStreakOnCompletion() {
    final todayKey = _formatDate(DateTime.now());
    final lastCompletionKey = _appStateBox.get('lastCompletionDate') as String?;
    final storedStreak = (_appStateBox.get('streak') as int?) ?? 0;

    if (lastCompletionKey == todayKey) {
      setState(() {
        _streak = storedStreak;
      });
      return;
    }

    final nextStreak = () {
      if (lastCompletionKey == null) {
        return 1;
      }
      final lastDate = DateTime.parse(lastCompletionKey);
      final today = DateTime.parse(todayKey);
      final diff = today.difference(lastDate).inDays;
      if (diff == 1) {
        return storedStreak + 1;
      }
      return 1;
    }();

    _appStateBox
      ..put('streak', nextStreak)
      ..put('lastCompletionDate', todayKey);

    setState(() {
      _streak = nextStreak;
      _todayKey = todayKey;
    });
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class TasksTab extends StatelessWidget {
  const TasksTab({super.key, required this.onEditTask});

  final void Function(int index, HabitTask task) onEditTask;

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<HabitTask>('tasks');
    return ValueListenableBuilder<Box<HabitTask>>(
      valueListenable: box.listenable(),
      builder: (context, tasksBox, _) {
        if (tasksBox.isEmpty) {
          return Center(
            child: Text(
              'タスクがまだありません。右下の＋で追加しよう。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          itemCount: tasksBox.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final task = tasksBox.getAt(index);
            if (task == null) {
              return const SizedBox.shrink();
            }
            return Material(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Icon(
                    task.iconData,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                title: Text(task.name),
                subtitle: Text(
                  task.reminderEnabled ? 'Reminder: ON' : 'Reminder: OFF',
                ),
                onTap: () => onEditTask(index, task),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(context, index),
                ),
              ),
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

  @override
  void initState() {
    super.initState();
    final initialTask = widget.initialTask;
    _nameController = TextEditingController(text: initialTask?.name ?? '');
    _reminderEnabled = initialTask?.reminderEnabled ?? false;
    _selectedIconCodePoint =
        initialTask?.iconCodePoint ?? _iconOptions.first.codePoint;
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month),
                title: const Text('Frequency'),
                subtitle: const Text('Daily'),
              ),
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

    final box = Hive.box<HabitTask>('tasks');
    final task = HabitTask(
      name: _nameController.text.trim(),
      iconCodePoint: _selectedIconCodePoint,
      reminderEnabled: _reminderEnabled,
    );

    if (widget.taskIndex == null) {
      await box.add(task);
    } else {
      await box.putAt(widget.taskIndex!, task);
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.isChecked,
    required this.onToggle,
  });

  final HabitTask task;
  final bool isChecked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = isChecked
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A3A6073),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              _TaskIconBadge(icon: task.iconData),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  task.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF294B72),
                  ),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isChecked
                      ? theme.colorScheme.primary.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(width: 2, color: borderColor),
                ),
                alignment: Alignment.center,
                child: isChecked
                    ? Icon(
                        Icons.check,
                        size: 18,
                        color: theme.colorScheme.primary,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskIconBadge extends StatelessWidget {
  const _TaskIconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: theme.colorScheme.primary, size: 26),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = Colors.white.withValues(alpha: 0.95);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(32),
            boxShadow: const [
              BoxShadow(
                color: Color(0x143A6073),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Text(
            message,
            style:
                Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF294B72),
                ) ??
                TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF294B72),
                ),
          ),
        ),
        Positioned(
          bottom: -12,
          left: 40,
          child: CustomPaint(
            size: const Size(28, 18),
            painter: _BubbleTailPainter(color: bubbleColor),
          ),
        ),
      ],
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  _BubbleTailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width * 0.45, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) {
    return oldDelegate.color != color;
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

const List<String> _cheerMessages = ['やったね！', 'えらい！', 'グッジョブ🐧'];
