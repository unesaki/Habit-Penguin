import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'models/habit_task.dart';
import 'models/task_completion_history.dart';
import 'models/notification_history.dart';
import 'models/advanced_notification_settings.dart';
import 'providers/providers.dart';
import 'screens/settings_screen.dart';
import 'screens/advanced_notification_screen.dart';
import 'services/migration_service.dart';
import 'services/monitoring_service.dart';
import 'services/notification_service.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Sentryの初期化（本番環境用のDSNを設定）
  // NOTE: デバッグモードではSentryは無効化されます
  await MonitoringService.instance.initialize(
    dsn: '', // 本番環境ではSentryプロジェクトのDSNを設定してください
    enableInDebug: false,
    environment: kDebugMode ? 'development' : 'production',
  );

  // Sentryでアプリ全体のエラーをキャプチャ
  await SentryFlutter.init(
    (options) {
      // DSNが空の場合はSentryを無効化
      options.dsn = '';
      options.environment = kDebugMode ? 'development' : 'production';
      options.tracesSampleRate = kDebugMode ? 0.1 : 1.0;
      options.debug = kDebugMode;
      options.enableAutoPerformanceTracing = true;
    },
    appRunner: () async {
      await Hive.initFlutter();
      Hive.registerAdapter(HabitTaskAdapter());
      Hive.registerAdapter(TaskCompletionHistoryAdapter());
      Hive.registerAdapter(NotificationHistoryAdapter());
      Hive.registerAdapter(AdvancedNotificationSettingsAdapter());
      await Hive.openBox<HabitTask>('tasks');
      await Hive.openBox<TaskCompletionHistory>('completion_history');
      await Hive.openBox<NotificationHistory>('notification_history');
      await Hive.openBox<AdvancedNotificationSettings>('advanced_notification_settings');
      await Hive.openBox('notification_settings');
      final appStateBox = await Hive.openBox('appState');

      // データマイグレーション実行
      await MigrationService.migrate(appStateBox);

      // 通知権限をリクエスト
      final notificationService = NotificationService();
      await notificationService.requestPermissions();

      runApp(
        ProviderScope(
          overrides: [
            notificationServiceProvider.overrideWithValue(notificationService),
          ],
          child: const HabitPenguinApp(),
        ),
      );
    },
  );
}

class HabitPenguinApp extends StatelessWidget {
  const HabitPenguinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habit Penguin',
      // 多言語化対応
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', ''), // 日本語
        Locale('en', ''), // 英語
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlueAccent),
        useMaterial3: true,
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),
      // Sentryによるナビゲーショントラッキング
      navigatorObservers: [
        SentryNavigatorObserver(),
      ],
      home: const HabitHomeShell(),
    );
  }
}

class HabitHomeShell extends ConsumerStatefulWidget {
  const HabitHomeShell({super.key});

  @override
  ConsumerState<HabitHomeShell> createState() => _HabitHomeShellState();
}

class _HabitHomeShellState extends ConsumerState<HabitHomeShell> {
  int _currentIndex = 1;

  @override
  void initState() {
    super.initState();
    // 通知タップ時のナビゲーションを設定
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notificationService = ref.read(notificationServiceProvider);
      notificationService.onNotificationTapped = (payload) {
        if (payload != null && payload.startsWith('task_')) {
          // タスクIDを抽出
          final taskIdStr = payload.replaceFirst('task_', '');
          final taskId = int.tryParse(taskIdStr);

          if (taskId != null) {
            // Tasksタブに切り替えてタスクを開く
            setState(() {
              _currentIndex = 0;
            });

            // タスク編集画面を開く
            final taskRepository = ref.read(taskRepositoryProvider);
            final task = taskRepository.getTaskAt(taskId);
            if (task != null && mounted) {
              _openTaskForm(context, initialTask: task, taskIndex: taskId);
            }
          }
        }
      };
    });
  }

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
    final l10n = AppLocalizations.of(context)!;
    final tabTitles = [l10n.tabTasks, l10n.tabHome, l10n.tabPenguin];
    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.appTitle} - ${tabTitles[_currentIndex]}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '設定',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
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

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final openTasksAsync = ref.watch(openTasksProvider);
    final todayActiveTasksAsync = ref.watch(todayActiveTasksProvider);

    return openTasksAsync.when(
      data: (openEntries) {
        return todayActiveTasksAsync.when(
          data: (todaysEntries) {
            final displayedTasks = todaysEntries.take(3).toList(growable: false);
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
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PenguinHeroSection(totalTasks: openEntries.length),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        Text(
                          '今日のタスク',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        if (displayedTasks.isEmpty) ...[
                          const _CreateTaskCallout(),
                        ] else ...[
                          for (var i = 0; i < displayedTasks.length; i++)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: i == displayedTasks.length - 1 ? 0 : 8,
                              ),
                              child: _TodayTaskCard(
                                task: displayedTasks[i].value,
                                index: displayedTasks[i].key,
                                onComplete: () => _completeTaskWithXp(
                                  context,
                                  ref,
                                  displayedTasks[i].key,
                                ),
                              ),
                            ),
                          if (openEntries.length > displayedTasks.length)
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
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('エラー: $e')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('エラー: $e')),
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
          final iceBottom = -heroHeight * 0.25;
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
                child: _HappyPenguinAnimator(width: penguinWidth),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HappyPenguinAnimator extends StatefulWidget {
  const _HappyPenguinAnimator({required this.width});

  final double width;

  @override
  State<_HappyPenguinAnimator> createState() => _HappyPenguinAnimatorState();
}

class _HappyPenguinAnimatorState extends State<_HappyPenguinAnimator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _offsetAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _offsetAnimation = Tween<double>(
      begin: 1,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _scaleAnimation = Tween<double>(
      begin: 1,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_offsetAnimation.value, 0),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: SizedBox(
              width: widget.width,
              child: Image.asset(
                'assets/happy_penguin.gif',
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TodayTaskCard extends StatelessWidget {
  const _TodayTaskCard({
    required this.task,
    required this.index,
    this.onComplete,
  });

  final HabitTask task;
  final int index;
  final VoidCallback? onComplete;

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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
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
                radius: 18,
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: Icon(task.iconData, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onComplete != null)
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline),
                      color: theme.colorScheme.primary,
                      tooltip: '完了にする',
                      onPressed: onComplete,
                    ),
                  const Icon(Icons.chevron_right),
                ],
              ),
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
                  '今日のタスクを作成しよう',
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

class TasksTab extends ConsumerStatefulWidget {
  const TasksTab({super.key, required this.onEditTask});

  final void Function(int index, HabitTask task) onEditTask;

  @override
  ConsumerState<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends ConsumerState<TasksTab> {
  bool _isSelectionMode = false;
  bool _isReorderMode = false;
  final Set<int> _selectedIndices = {};

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _isReorderMode = false;
      if (!_isSelectionMode) {
        _selectedIndices.clear();
      }
    });
  }

  void _toggleReorderMode() {
    setState(() {
      _isReorderMode = !_isReorderMode;
      _isSelectionMode = false;
      _selectedIndices.clear();
    });
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentXpAsync = ref.watch(currentXpProvider);
    final openTasksAsync = ref.watch(openTasksProvider);
    final todayActiveTasksAsync = ref.watch(todayActiveTasksProvider);
    final undoService = ref.watch(undoServiceProvider);

    return currentXpAsync.when(
      data: (currentXp) {
        return openTasksAsync.when(
          data: (openEntries) {
            return todayActiveTasksAsync.when(
              data: (activeEntries) {
                final activeKeys =
                    activeEntries.map((entry) => entry.key).toSet();
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
                    if (!_isSelectionMode && !_isReorderMode)
                      IconButton(
                        icon: const Icon(Icons.swap_vert),
                        tooltip: '並び替え',
                        onPressed: openEntries.isEmpty ? null : _toggleReorderMode,
                      ),
                    if (!_isSelectionMode && !_isReorderMode)
                      IconButton(
                        icon: const Icon(Icons.checklist),
                        tooltip: '選択',
                        onPressed: openEntries.isEmpty ? null : _toggleSelectionMode,
                      ),
                    if (_isSelectionMode || _isReorderMode)
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'キャンセル',
                        onPressed: _isSelectionMode ? _toggleSelectionMode : _toggleReorderMode,
                      ),
                    if (_isSelectionMode && _selectedIndices.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: '削除',
                        onPressed: () => _deleteSelectedTasks(context, ref, openEntries),
                      ),
                    if (!_isReorderMode)
                      TextButton.icon(
                        onPressed: () => _openCompletedTasks(context),
                        icon: const Icon(Icons.history),
                        label: const Text('完了済み'),
                      ),
                  ],
                ),
                if (undoService.canUndo && !_isSelectionMode && !_isReorderMode)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextButton.icon(
                      onPressed: () async {
                        await undoService.undo();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('「${undoService.lastActionDescription ?? "操作"}」を取り消しました'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.undo),
                      label: Text('取り消し: ${undoService.lastActionDescription}'),
                    ),
                  ),
                if (_isReorderMode)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'タスクを長押ししてドラッグして並び替えます',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                if (_isReorderMode)
                  _buildReorderableTaskList(context, ref, openEntries)
                else
                  ...[
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
                            taskIndex: entry.key,
                            onTap: _isSelectionMode
                                ? () => _toggleSelection(entry.key)
                                : () => widget.onEditTask(entry.key, entry.value),
                            onDelete: () => _confirmDelete(context, ref, entry.key),
                            onComplete: () =>
                                _completeTaskWithXp(context, ref, entry.key),
                            isActive: true,
                            isSelectionMode: _isSelectionMode,
                            isSelected: _selectedIndices.contains(entry.key),
                            onSelectionToggle: () => _toggleSelection(entry.key),
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
                            taskIndex: entry.key,
                            onTap: _isSelectionMode
                                ? () => _toggleSelection(entry.key)
                                : () => widget.onEditTask(entry.key, entry.value),
                            onDelete: () => _confirmDelete(context, ref, entry.key),
                            onComplete: () =>
                                _completeTaskWithXp(context, ref, entry.key),
                            isActive: entry.value.isActiveOn(DateTime.now()),
                            isSelectionMode: _isSelectionMode,
                            isSelected: _selectedIndices.contains(entry.key),
                            onSelectionToggle: () => _toggleSelection(entry.key),
                          ),
                        ),
                      ),
                  ],
              ],
            );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('エラー: $e')),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('エラー: $e')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('エラー: $e')),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    int index,
  ) async {
    final repository = ref.read(taskRepositoryProvider);
    final undoService = ref.read(undoServiceProvider);
    final task = repository.getTaskAt(index);
    if (task == null) return;

    // タスクのコピーを保存（Undo用）
    final taskCopy = HabitTask(
      name: task.name,
      iconCodePoint: task.iconCodePoint,
      reminderEnabled: task.reminderEnabled,
      difficulty: task.difficulty,
      scheduledDate: task.scheduledDate,
      repeatStart: task.repeatStart,
      repeatEnd: task.repeatEnd,
      reminderTime: task.reminderTime,
    );

    // 削除実行
    await repository.deleteTaskAt(index);

    // Undo機能を記録
    undoService.recordDeleteTask(
      index: index,
      task: taskCopy,
      restoreFunction: () async {
        // タスクを復元（同じ位置に挿入）
        await repository.box.putAt(index, taskCopy);
      },
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「${task.name}」を削除しました'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: '取り消し',
          onPressed: () async {
            await undoService.undo();
          },
        ),
      ),
    );
  }

  Future<void> _deleteSelectedTasks(
    BuildContext context,
    WidgetRef ref,
    List<MapEntry<int, HabitTask>> allTasks,
  ) async {
    if (_selectedIndices.isEmpty) return;

    final repository = ref.read(taskRepositoryProvider);
    final undoService = ref.read(undoServiceProvider);

    // 削除するタスクのコピーを保存
    final deletedTasks = <MapEntry<int, HabitTask>>[];
    for (final index in _selectedIndices) {
      final task = repository.getTaskAt(index);
      if (task != null) {
        deletedTasks.add(MapEntry(index, HabitTask(
          name: task.name,
          iconCodePoint: task.iconCodePoint,
          reminderEnabled: task.reminderEnabled,
          difficulty: task.difficulty,
          scheduledDate: task.scheduledDate,
          repeatStart: task.repeatStart,
          repeatEnd: task.repeatEnd,
          reminderTime: task.reminderTime,
        )));
      }
    }

    // 削除実行
    await repository.deleteTasks(_selectedIndices.toList());

    // Undo機能を記録
    undoService.recordDeleteTasks(
      deletedTasks: deletedTasks,
      restoreFunction: () async {
        // タスクを復元
        for (final entry in deletedTasks) {
          await repository.box.putAt(entry.key, entry.value);
        }
      },
    );

    setState(() {
      _selectedIndices.clear();
      _isSelectionMode = false;
    });

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${deletedTasks.length}個のタスクを削除しました'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: '取り消し',
          onPressed: () async {
            await undoService.undo();
          },
        ),
      ),
    );
  }

  Widget _buildReorderableTaskList(
    BuildContext context,
    WidgetRef ref,
    List<MapEntry<int, HabitTask>> allTasks,
  ) {
    if (allTasks.isEmpty) {
      return Text(
        'タスクがまだありません。',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: allTasks.length,
      onReorder: (oldIndex, newIndex) async {
        await _handleReorder(context, ref, allTasks, oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final entry = allTasks[index];
        return Padding(
          key: ValueKey(entry.key),
          padding: const EdgeInsets.only(bottom: 12),
          child: _TaskListTile(
            task: entry.value,
            taskIndex: entry.key,
            onTap: () {}, // 並び替えモードではタップ無効
            onDelete: () {}, // 並び替えモードでは削除無効
            onComplete: () {}, // 並び替えモードでは完了無効
            isActive: entry.value.isActiveOn(DateTime.now()),
            isReorderMode: true,
          ),
        );
      },
    );
  }

  Future<void> _handleReorder(
    BuildContext context,
    WidgetRef ref,
    List<MapEntry<int, HabitTask>> allTasks,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex == newIndex) return;

    final repository = ref.read(taskRepositoryProvider);
    final taskEntry = allTasks[oldIndex];

    // Hiveのインデックスを使って並び替え
    await repository.reorderTask(taskEntry.key, newIndex);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「${taskEntry.value.name}」を移動しました'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openCompletedTasks(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const CompletedTasksPage()));
  }
}

class TaskFormPage extends ConsumerStatefulWidget {
  const TaskFormPage({super.key, this.initialTask, this.taskIndex});

  final HabitTask? initialTask;
  final int? taskIndex;

  @override
  ConsumerState<TaskFormPage> createState() => _TaskFormPageState();
}

Future<void> _completeTaskWithXp(
  BuildContext context,
  WidgetRef ref,
  int index,
) async {
  final repository = ref.read(taskRepositoryProvider);
  final xpService = ref.read(xpServiceProvider);
  final undoService = ref.read(undoServiceProvider);

  final task = repository.getTaskAt(index);
  if (task == null) {
    return;
  }

  // 今日既に完了済みかチェック
  if (repository.isCompletedToday(index)) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('本日は既に完了しています')),
    );
    return;
  }

  final gainedXp = xpService.calculateXpForDifficulty(task.difficulty);

  // タスクを完了にする（履歴に記録）
  await repository.completeTask(index, xpGained: gainedXp);

  // XPを追加
  await xpService.addXp(gainedXp);

  // Undo機能を記録
  undoService.recordCompleteTask(
    index: index,
    task: task,
    undoFunction: () async {
      await repository.uncompleteTask(index);
      await xpService.subtractXp(gainedXp);
    },
  );

  if (!context.mounted) {
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('クエスト達成！'),
      content: Text('$gainedXp XPを獲得しました！'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

class _TaskFormPageState extends ConsumerState<TaskFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late bool _reminderEnabled;
  TimeOfDay? _reminderTime;
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
    _reminderTime = initialTask?.reminderTime;
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'タスクを編集' : 'タスクを追加')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FormSection(
                  title: '基本情報',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Habit名',
                          hintText: '例: 朝のストレッチ',
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Habit名を入力してください';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      Text('アイコン', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _iconOptions.map((icon) {
                          final selected =
                              _selectedIconCodePoint == icon.codePoint;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedIconCodePoint = icon.codePoint;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: selected
                                    ? theme.colorScheme.primaryContainer
                                    : theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(18),
                                border: selected
                                    ? Border.all(
                                        color: theme.colorScheme.primary,
                                        width: 2,
                                      )
                                    : null,
                              ),
                              child: Icon(
                                icon,
                                color: selected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: SegmentedButton<TaskDifficulty>(
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            padding: WidgetStateProperty.all(
                              const EdgeInsets.symmetric(horizontal: 12),
                            ),
                          ),
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
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _FormSection(
                  title: 'スケジュール',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_isRepeating)
                        _DateActionRow(
                          label: '日付',
                          value: _scheduledDate != null
                              ? _formatDateLabel(_scheduledDate!)
                              : '未選択',
                          onTap: _pickScheduledDate,
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('繰り返しタスク', style: theme.textTheme.bodyLarge),
                          Switch(
                            value: _isRepeating,
                            onChanged: (value) {
                              setState(() {
                                _isRepeating = value;
                                if (value) {
                                  _repeatStart ??=
                                      _scheduledDate ?? DateTime.now();
                                  _repeatEnd ??= _repeatStart;
                                  _scheduledDate = null;
                                } else {
                                  _scheduledDate =
                                      _repeatStart ?? DateTime.now();
                                  _repeatStart = null;
                                  _repeatEnd = null;
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: !_isRepeating
                            ? const SizedBox.shrink()
                            : Row(
                                children: [
                                  Expanded(
                                    child: _DateActionRow(
                                      label: '開始日',
                                      value: _repeatStart != null
                                          ? _formatDateLabel(_repeatStart!)
                                          : '未選択',
                                      onTap: _pickRepeatStart,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _DateActionRow(
                                      label: '終了日',
                                      value: _repeatEnd != null
                                          ? _formatDateLabel(_repeatEnd!)
                                          : '未選択',
                                      onTap: _pickRepeatEnd,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _FormSection(
                  title: 'リマインダー',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('通知を受け取る', style: theme.textTheme.bodyLarge),
                          Switch(
                            value: _reminderEnabled,
                            onChanged: (value) {
                              setState(() {
                                _reminderEnabled = value;
                                if (value && _reminderTime == null) {
                                  _reminderTime = const TimeOfDay(hour: 9, minute: 0);
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: !_reminderEnabled
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _DateActionRow(
                                      label: '通知時刻',
                                      value: _reminderTime != null
                                          ? _formatTimeLabel(_reminderTime!)
                                          : '未選択',
                                      onTap: _pickReminderTime,
                                    ),
                                    if (widget.taskIndex != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute<void>(
                                                builder: (_) =>
                                                    AdvancedNotificationScreen(
                                                  taskId: widget.taskIndex!,
                                                  taskName: _nameController.text,
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.tune),
                                          label: const Text('高度な通知設定'),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.all(12),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: FilledButton.icon(
            onPressed: () => _saveTask(ref),
            icon: const Icon(Icons.save_outlined),
            label: Text(isEditing ? '変更を保存' : 'タスクを作成'),
          ),
        ),
      ),
    );
  }

  Future<void> _saveTask(WidgetRef ref) async {
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

    final repository = ref.read(taskRepositoryProvider);

    if (widget.taskIndex == null) {
      final task = HabitTask(
        name: _nameController.text.trim(),
        iconCodePoint: _selectedIconCodePoint,
        reminderEnabled: _reminderEnabled,
        difficulty: _selectedDifficulty,
        scheduledDate: scheduledDate,
        repeatStart: repeatStart,
        repeatEnd: repeatEnd,
        reminderTime: _reminderTime,
      );
      await repository.addTask(task);
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
          ..repeatEnd = repeatEnd
          ..reminderTime = _reminderTime;
        await repository.updateTask(existing);
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

  Future<void> _pickReminderTime() async {
    final initial = _reminderTime ?? const TimeOfDay(hour: 9, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      setState(() {
        _reminderTime = picked;
      });
    }
  }

  DateTime _asDateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _DateActionRow extends StatelessWidget {
  const _DateActionRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskListTile extends ConsumerWidget {
  const _TaskListTile({
    required this.task,
    required this.taskIndex,
    required this.onTap,
    required this.onDelete,
    required this.onComplete,
    required this.isActive,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelectionToggle,
    this.isReorderMode = false,
  });

  final HabitTask task;
  final int taskIndex;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onComplete;
  final bool isActive;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onSelectionToggle;
  final bool isReorderMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final historyRepo = ref.watch(completionHistoryRepositoryProvider);
    final streak = historyRepo.calculateStreak(taskIndex);

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
                    if (task.reminderEnabled || streak > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            if (task.reminderEnabled)
                              Text(
                                'Reminder ON',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (task.reminderEnabled && streak > 0)
                              Text(
                                ' • ',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            if (streak > 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.local_fire_department,
                                    size: 14,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '$streak日連続',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (isReorderMode)
                Icon(
                  Icons.drag_handle,
                  color: theme.colorScheme.onSurfaceVariant,
                )
              else if (isSelectionMode)
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => onSelectionToggle?.call(),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      tooltip: 'メニュー',
                      onSelected: (value) async {
                        final repository = ref.read(taskRepositoryProvider);
                        if (value == 'duplicate') {
                          await repository.duplicateTask(taskIndex);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('「${task.name}」を複製しました')),
                            );
                          }
                        } else if (value == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'duplicate',
                          child: Row(
                            children: [
                              Icon(Icons.content_copy),
                              SizedBox(width: 8),
                              Text('複製'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline),
                              SizedBox(width: 8),
                              Text('削除'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline),
                      color: theme.colorScheme.primary,
                      tooltip: '完了にする',
                      onPressed: onComplete,
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

class CompletedTasksPage extends ConsumerWidget {
  const CompletedTasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentXpAsync = ref.watch(currentXpProvider);
    final completedTasksAsync = ref.watch(completedTasksWithHistoryProvider);
    final taskRepository = ref.watch(taskRepositoryProvider);

    return currentXpAsync.when(
      data: (currentXp) {
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
          body: completedTasksAsync.when(
            data: (completed) {
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
                  final entry = completed[index];
                  final task = taskRepository.getTaskAt(entry.key);
                  final history = entry.value;

                  if (task == null) {
                    return const SizedBox.shrink();
                  }

                  final parts = <String>[
                    _difficultyLabel(task.difficulty),
                    '獲得XP: ${history.earnedXp}',
                    '完了日: ${_formatDateLabel(history.completedAt)}',
                  ];

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
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('エラー: $e')),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => Scaffold(
        body: Center(child: Text('エラー: $e')),
      ),
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
            Image.asset('assets/happy_penguin.gif', width: 160),
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

String _formatTimeLabel(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
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
