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
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        Positioned.fill(
          child: Transform.translate(
            offset: Offset(0, -50), // 50px 上にずらす
            child: Image.asset(
              'assets/bg.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
        ),
        // Ice image positioned below the penguin
        Positioned(
          bottom: 180,
          left: 0,
          right: 0,
          child: Center(
            child: Image.asset(
              'assets/ice.png',
              width: size.width * 0.6,
              fit: BoxFit.contain,
            ),
          ),
        ),
        Positioned(
          bottom: 230,
          left: 0,
          right: 0,
          child: Center(
            child: Image.asset(
              'assets/penguin_normal.png',
              width: size.width * 0.5,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
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
