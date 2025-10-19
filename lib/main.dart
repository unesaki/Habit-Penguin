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
import 'screens/onboarding_screen.dart';
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
      await Hive.openBox<AdvancedNotificationSettings>(
          'advanced_notification_settings');
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

      // 初回起動時にオンボーディング画面を表示
      final onboardingService = ref.read(onboardingServiceProvider);
      if (!onboardingService.hasCompletedOnboarding) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const OnboardingScreen(),
            fullscreenDialog: true,
          ),
        );
      }
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
    final tabTitles = ['タスク一覧', '', 'ペンギンの部屋'];
    return Scaffold(
      appBar: _currentIndex == 1
          ? null
          : AppBar(
              title: Text(tabTitles[_currentIndex]),
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
            final displayedTasks =
                todaysEntries.take(3).toList(growable: false);
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
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            if (displayedTasks.isEmpty) ...[
                              const _CreateTaskCallout(),
                            ] else ...[
                              for (var i = 0; i < displayedTasks.length; i++)
                                Padding(
                                  padding: EdgeInsets.only(
                                    bottom:
                                        i == displayedTasks.length - 1 ? 0 : 8,
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
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

class _TodayTaskCard extends ConsumerWidget {
  const _TodayTaskCard({
    required this.task,
    required this.index,
    this.onComplete,
  });

  final HabitTask task;
  final int index;
  final VoidCallback? onComplete;

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

  Color _difficultyColor(TaskDifficulty difficulty) {
    switch (difficulty) {
      case TaskDifficulty.easy:
        return const Color(0xFFBFE8F8);
      case TaskDifficulty.normal:
        return const Color(0xFFFFD79E);
      case TaskDifficulty.hard:
        return const Color(0xFFFFB3BA);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final historyRepo = ref.watch(completionHistoryRepositoryProvider);
    final streak = historyRepo.calculateStreak(index);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TaskFormPage(initialTask: task, taskIndex: index),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  task.iconData,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _difficultyColor(task.difficulty),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _difficultyLabel(task.difficulty),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (streak > 0) ...[
                          const SizedBox(width: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_fire_department,
                                size: 14,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '$streak日',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.check),
                      color: theme.colorScheme.onPrimaryContainer,
                      iconSize: 20,
                      tooltip: '完了にする',
                      onPressed: onComplete,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: theme.colorScheme.error,
                    ),
                    iconSize: 20,
                    tooltip: '削除',
                    onPressed: () async {
                      final repository = ref.read(taskRepositoryProvider);
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('タスクを削除'),
                          content: Text('「${task.name}」を削除しますか？'),
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
                      );
                      if (confirmed == true) {
                        await repository.deleteTaskAt(index);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('「${task.name}」を削除しました')),
                          );
                        }
                      }
                    },
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
  // ドラッグ中の一時的なリスト順序を保持
  List<dynamic>? _tempItems;

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

                // 全タスクを統合（今日のタスク + 区切り + 登録中のタスク）
                // 一時的な順序がある場合はそれを使用、なければ通常の順序
                final allItems = _tempItems ??
                    <dynamic>[
                      ...activeEntries
                          .map((e) => {'type': 'active', 'data': e}),
                      {'type': 'divider'},
                      ...backlogEntries
                          .map((e) => {'type': 'backlog', 'data': e}),
                    ];

                // データが変わったら一時的な順序をクリア
                if (_tempItems != null &&
                    openEntries.length !=
                        _tempItems!
                            .where((item) => item['type'] != 'divider')
                            .length) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _tempItems = null;
                      });
                    }
                  });
                }

                return Container(
                  color: const Color(0xFFF6F6F6),
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    '経験値: ',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF333333),
                                    ),
                                  ),
                                  Text(
                                    '$currentXp XP',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFFFD79E),
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: () =>
                                        _openCompletedTasks(context),
                                    icon: const Icon(Icons.history),
                                    label: const Text('完了済み'),
                                  ),
                                ],
                              ),
                              if (undoService.canUndo)
                                TextButton.icon(
                                  onPressed: () async {
                                    final messenger =
                                        ScaffoldMessenger.of(context);
                                    await undoService.undo();
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              '「${undoService.lastActionDescription ?? "操作"}」を取り消しました'),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.undo),
                                  label: Text(
                                      '取り消し: ${undoService.lastActionDescription}'),
                                ),
                              const SizedBox(height: 8),
                              const Text(
                                '今日のタスク',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF333333),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                      if (openEntries.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _EmptyStateWidget(
                              onCreateTask: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const TaskFormPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                        )
                      else
                        SliverReorderableList(
                          itemCount: allItems.length,
                          onReorder: (oldIndex, newIndex) {
                            // 区切り線のインデックスを計算（現在の表示リスト基準）
                            final dividerIndexInList = allItems.indexWhere(
                                (item) => item['type'] == 'divider');

                            // 区切り線をドラッグしようとした場合は無視
                            if (oldIndex == dividerIndexInList) return;

                            // newIndexの調整
                            var adjustedNewIndex = newIndex;
                            if (adjustedNewIndex > oldIndex) {
                              adjustedNewIndex--;
                            }

                            // 区切り線に移動しようとした場合は無視
                            if (adjustedNewIndex == dividerIndexInList) return;

                            final oldItem = allItems[oldIndex];
                            if (oldItem['type'] == 'divider') return;

                            final items = List<dynamic>.from(allItems);
                            final movedItem = items.removeAt(oldIndex);
                            items.insert(adjustedNewIndex, movedItem);

                            // まずUIを即座に更新
                            setState(() {
                              _tempItems = items;
                            });

                            final entry =
                                oldItem['data'] as MapEntry<int, HabitTask>;
                            final task = entry.value;

                            final wasInActive = oldIndex < dividerIndexInList;
                            final nowInActive =
                                adjustedNewIndex < dividerIndexInList;

                            // セクション間の移動のみ処理
                            if (wasInActive != nowInActive) {
                              // 非同期処理を実行（UIは既に更新済み）
                              _handleSectionMove(
                                context,
                                ref,
                                task,
                                wasInActive,
                                nowInActive,
                              ).then((_) {
                                // 処理完了後、一時的なリストをクリア
                                if (mounted) {
                                  setState(() {
                                    _tempItems = null;
                                  });
                                }
                              });
                            } else {
                              final orderedKeys = items
                                  .where((item) => item['type'] != 'divider')
                                  .map((item) =>
                                      (item['data'] as MapEntry<int, HabitTask>)
                                          .key)
                                  .toList(growable: false);
                              final oldTaskIndex = entry.key;
                              final newPosition =
                                  orderedKeys.indexOf(oldTaskIndex);

                              final taskRepository =
                                  ref.read(taskRepositoryProvider);
                              final allIndices = List<int>.generate(
                                taskRepository.taskCount,
                                (index) => index,
                              )..remove(oldTaskIndex);

                              int computedNewIndex;
                              if (newPosition + 1 < orderedKeys.length) {
                                final nextKey = orderedKeys[newPosition + 1];
                                final idx = allIndices.indexOf(nextKey);
                                if (idx != -1) {
                                  computedNewIndex = idx;
                                } else if (newPosition == 0) {
                                  computedNewIndex = 0;
                                } else {
                                  final prevKey = orderedKeys[newPosition - 1];
                                  final prevIdx = allIndices.indexOf(prevKey);
                                  computedNewIndex = prevIdx == -1
                                      ? allIndices.length
                                      : prevIdx + 1;
                                }
                              } else if (newPosition == 0) {
                                computedNewIndex = 0;
                              } else {
                                final prevKey = orderedKeys[newPosition - 1];
                                final prevIdx = allIndices.indexOf(prevKey);
                                computedNewIndex = prevIdx == -1
                                    ? allIndices.length
                                    : prevIdx + 1;
                              }

                              taskRepository
                                  .reorderTask(oldTaskIndex, computedNewIndex)
                                  .whenComplete(() {
                                if (mounted) {
                                  setState(() {
                                    _tempItems = null;
                                  });
                                }
                              });
                            }
                          },
                          proxyDecorator: (child, index, animation) {
                            return Material(
                              elevation: 6,
                              borderRadius: BorderRadius.circular(20),
                              child: child,
                            );
                          },
                          itemBuilder: (context, index) {
                            final item = allItems[index];

                            if (item['type'] == 'divider') {
                              return Container(
                                key: const ValueKey('divider'),
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 12),
                                child: const Text(
                                  '登録中のタスク',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF333333),
                                  ),
                                ),
                              );
                            }

                            final entry =
                                item['data'] as MapEntry<int, HabitTask>;
                            final isActive = item['type'] == 'active';

                            return ReorderableDragStartListener(
                              key: ValueKey('task_${entry.key}'),
                              index: index,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                    left: 16, right: 16, bottom: 12),
                                child: _TaskListTile(
                                  task: entry.value,
                                  taskIndex: entry.key,
                                  onTap: () =>
                                      widget.onEditTask(entry.key, entry.value),
                                  onDelete: () =>
                                      _confirmDelete(context, ref, entry.key),
                                  onComplete: () => _completeTaskWithXp(
                                      context, ref, entry.key),
                                  isActive: isActive,
                                  isSelectionMode: false,
                                  isSelected: false,
                                  onSelectionToggle: null,
                                  isReorderMode: false,
                                ),
                              ),
                            );
                          },
                        ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 16),
                      ),
                    ],
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

  Future<void> _handleSectionMove(
    BuildContext context,
    WidgetRef ref,
    HabitTask task,
    bool wasInActive,
    bool nowInActive,
  ) async {
    final repository = ref.read(taskRepositoryProvider);

    if (!wasInActive && nowInActive) {
      // 登録中→今日：日付を今日に設定
      final today = DateTime.now();
      task.scheduledDate = DateTime(today.year, today.month, today.day);
      task.repeatStart = null;
      task.repeatEnd = null;
      await repository.updateTask(task);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('今日のタスクに移動しました'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      // 今日→登録中：日付を選択
      final selectedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(days: 1)),
        firstDate: DateTime.now().add(const Duration(days: 1)),
        lastDate: DateTime(2100),
        helpText: 'いつ実施する？',
        cancelText: 'キャンセル',
        confirmText: '設定',
      );

      if (selectedDate != null) {
        task.scheduledDate =
            DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
        task.repeatStart = null;
        task.repeatEnd = null;
        await repository.updateTask(task);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_formatDateLabel(selectedDate)}に設定しました'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
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
  late final TextEditingController _memoController;
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
    _memoController = TextEditingController(text: initialTask?.memo ?? '');
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
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.taskIndex != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F6F6),
        elevation: 0,
        title: Text(
          isEditing ? 'タスクを編集' : 'タスクを作成',
          style: const TextStyle(
            color: Color(0xFF333333),
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF333333)),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _BrandFormSection(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _nameController,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF333333),
                                ),
                                decoration: InputDecoration(
                                  labelText: 'タスク名',
                                  hintText: 'どんな習慣をつくる?',
                                  hintStyle: TextStyle(
                                    color: const Color(0xFF333333)
                                        .withValues(alpha: 0.4),
                                  ),
                                  labelStyle: const TextStyle(
                                    color: Color(0xFF333333),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                textInputAction: TextInputAction.next,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'タスク名を入力してね';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'アイコン',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF333333),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _showIconPicker(context),
                                    icon: Icon(
                                      IconData(
                                        _selectedIconCodePoint,
                                        fontFamily: 'MaterialIcons',
                                      ),
                                      color: const Color(0xFF333333),
                                    ),
                                    label: const Text(
                                      '選択',
                                      style:
                                          TextStyle(color: Color(0xFF333333)),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      side: const BorderSide(
                                        color: Color(0xFFBFE8F8),
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                '難易度',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF333333),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SegmentedButton<TaskDifficulty>(
                                style: ButtonStyle(
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor:
                                      WidgetStateProperty.resolveWith((states) {
                                    if (states.contains(WidgetState.selected)) {
                                      return const Color(0xFFFFD79E);
                                    }
                                    return Colors.white;
                                  }),
                                  foregroundColor: WidgetStateProperty.all(
                                    const Color(0xFF333333),
                                  ),
                                  side: WidgetStateProperty.all(
                                    const BorderSide(
                                      color: Color(0xFFBFE8F8),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                segments: const [
                                  ButtonSegment(
                                    value: TaskDifficulty.easy,
                                    label: SizedBox(
                                      width: 60,
                                      child: Text('Easy',
                                          textAlign: TextAlign.center),
                                    ),
                                  ),
                                  ButtonSegment(
                                    value: TaskDifficulty.normal,
                                    label: SizedBox(
                                      width: 60,
                                      child: Text('Normal',
                                          textAlign: TextAlign.center),
                                    ),
                                  ),
                                  ButtonSegment(
                                    value: TaskDifficulty.hard,
                                    label: SizedBox(
                                      width: 60,
                                      child: Text('Hard',
                                          textAlign: TextAlign.center),
                                    ),
                                  ),
                                ],
                                selected: {_selectedDifficulty},
                                onSelectionChanged: (selection) {
                                  setState(() {
                                    _selectedDifficulty = selection.first;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _BrandFormSection(
                          child: TextFormField(
                            controller: _memoController,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF333333),
                            ),
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'メモ',
                              hintText: 'このタスクについてメモしておこう',
                              hintStyle: TextStyle(
                                color: const Color(0xFF333333)
                                    .withValues(alpha: 0.4),
                              ),
                              labelStyle: const TextStyle(
                                color: Color(0xFF333333),
                                fontWeight: FontWeight.w500,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _BrandFormSection(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    '繰り返しタスク',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF333333),
                                    ),
                                  ),
                                  Switch(
                                    value: _isRepeating,
                                    activeTrackColor: const Color(0xFFFFD79E),
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
                              const SizedBox(height: 12),
                              if (!_isRepeating)
                                _BrandDateActionRow(
                                  label: '日付',
                                  value: _scheduledDate != null
                                      ? _formatDateLabel(_scheduledDate!)
                                      : '未選択',
                                  onTap: _pickScheduledDate,
                                )
                              else
                                Row(
                                  children: [
                                    Expanded(
                                      child: _BrandDateActionRow(
                                        label: '開始日',
                                        value: _repeatStart != null
                                            ? _formatDateLabel(_repeatStart!)
                                            : '未選択',
                                        onTap: _pickRepeatStart,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _BrandDateActionRow(
                                        label: '終了日',
                                        value: _repeatEnd != null
                                            ? _formatDateLabel(_repeatEnd!)
                                            : '未選択',
                                        onTap: _pickRepeatEnd,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _BrandFormSection(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    '通知を受け取る',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF333333),
                                    ),
                                  ),
                                  Switch(
                                    value: _reminderEnabled,
                                    activeTrackColor: const Color(0xFFFFD79E),
                                    onChanged: (value) {
                                      setState(() {
                                        _reminderEnabled = value;
                                        if (value && _reminderTime == null) {
                                          _reminderTime = const TimeOfDay(
                                              hour: 9, minute: 0);
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                              if (_reminderEnabled) ...[
                                const SizedBox(height: 12),
                                _BrandDateActionRow(
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
                                      icon: const Icon(
                                        Icons.tune,
                                        color: Color(0xFF333333),
                                      ),
                                      label: const Text(
                                        '高度な通知設定',
                                        style:
                                            TextStyle(color: Color(0xFF333333)),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.all(12),
                                        side: const BorderSide(
                                          color: Color(0xFFBFE8F8),
                                          width: 1.5,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _saveTask(ref),
                      icon: const Icon(Icons.check),
                      label: Text(isEditing ? '保存するぺん' : 'タスクを作成'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD79E),
                        foregroundColor: const Color(0xFF333333),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showIconPicker(BuildContext context) async {
    final theme = Theme.of(context);
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('アイコンを選択'),
        content: SizedBox(
          width: double.maxFinite,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _iconOptions.map((icon) {
              final isSelected = _selectedIconCodePoint == icon.codePoint;
              return GestureDetector(
                onTap: () => Navigator.of(context).pop(icon.codePoint),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                    border: isSelected
                        ? Border.all(
                            color: theme.colorScheme.primary,
                            width: 2,
                          )
                        : null,
                  ),
                  child: Icon(
                    icon,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );

    if (selected != null) {
      setState(() {
        _selectedIconCodePoint = selected;
      });
    }
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
        memo: _memoController.text.trim(),
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
          ..reminderTime = _reminderTime
          ..memo = _memoController.text.trim();
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

class _BrandFormSection extends StatelessWidget {
  const _BrandFormSection({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _BrandDateActionRow extends StatelessWidget {
  const _BrandDateActionRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEECCF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF333333),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF333333),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
    final historyRepo = ref.watch(completionHistoryRepositoryProvider);
    final streak = historyRepo.calculateStreak(taskIndex);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: isActive
                ? Border.all(color: const Color(0xFFBFE8F8), width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEECCF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  task.iconData,
                  color: const Color(0xFF333333),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _difficultyColor(task.difficulty),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _difficultyLabel(task.difficulty),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ),
                        if (streak > 0) ...[
                          const SizedBox(width: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.local_fire_department,
                                size: 14,
                                color: Color(0xFFFFD79E),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '$streak日',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF333333),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (isReorderMode)
                const Icon(
                  Icons.drag_handle,
                  color: Color(0xFF333333),
                )
              else if (isSelectionMode)
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => onSelectionToggle?.call(),
                  activeColor: const Color(0xFFFFD79E),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: Color(0xFF333333),
                      ),
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
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD79E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.check),
                        color: const Color(0xFF333333),
                        iconSize: 20,
                        tooltip: '完了にする',
                        onPressed: onComplete,
                      ),
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

Color _difficultyColor(TaskDifficulty difficulty) {
  switch (difficulty) {
    case TaskDifficulty.easy:
      return const Color(0xFFBFE8F8);
    case TaskDifficulty.normal:
      return const Color(0xFFFEECCF);
    case TaskDifficulty.hard:
      return const Color(0xFFFFD79E);
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

/// 空状態を表示するウィジェット
class _EmptyStateWidget extends StatelessWidget {
  const _EmptyStateWidget({required this.onCreateTask});

  final VoidCallback onCreateTask;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_task,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              l10n?.emptyStateTitle ?? 'Let\'s Add Your First Task',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              l10n?.emptyStateDescription ??
                  'Tap the + button at the bottom right to create your first habit task.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onCreateTask,
              icon: const Icon(Icons.add),
              label: Text(l10n?.emptyStateCreateTask ?? 'Create First Task'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
