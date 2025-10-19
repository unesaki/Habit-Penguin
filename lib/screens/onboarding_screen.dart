import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../services/sample_tasks_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding({bool createSampleTasks = false}) async {
    final locale = Localizations.localeOf(context);
    final navigator = Navigator.of(context);

    final onboardingService = ref.read(onboardingServiceProvider);
    await onboardingService.completeOnboarding();

    if (createSampleTasks) {
      final taskRepository = ref.read(taskRepositoryProvider);
      final sampleTasksService = SampleTasksService(taskRepository);

      if (locale.languageCode == 'ja') {
        await sampleTasksService.createSampleTasksJa();
      } else {
        await sampleTasksService.createSampleTasksEn();
      }
    }

    if (!mounted) return;
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Page indicator
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  4,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _WelcomePage(l10n: l10n),
                  _FeaturePage1(l10n: l10n),
                  _FeaturePage2(l10n: l10n),
                  _SampleTasksPage(
                    l10n: l10n,
                    onComplete: _completeOnboarding,
                  ),
                ],
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: _previousPage,
                      child: Text(l10n?.onboardingBack ?? 'Back'),
                    )
                  else
                    const SizedBox(width: 80),
                  if (_currentPage < 3)
                    ElevatedButton(
                      onPressed: _nextPage,
                      child: Text(l10n?.onboardingNext ?? 'Next'),
                    )
                  else
                    const SizedBox(width: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.l10n});

  final AppLocalizations? l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.catching_pokemon,
            size: 120,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 32),
          Text(
            l10n?.onboardingWelcomeTitle ?? 'Welcome to Habit Penguin!',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            l10n?.onboardingWelcomeDescription ??
                'Build better habits with fun and motivation. Track your daily tasks and level up!',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FeaturePage1 extends StatelessWidget {
  const _FeaturePage1({required this.l10n});

  final AppLocalizations? l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.military_tech,
            size: 100,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(height: 32),
          Text(
            l10n?.onboardingFeature1Title ?? 'Earn XP & Level Up',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            l10n?.onboardingFeature1Description ??
                'Complete tasks to earn experience points. The harder the task, the more XP you get!',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _FeatureItem(
            icon: Icons.star,
            title: l10n?.onboardingFeature1Point1 ?? 'Easy tasks: 10 XP',
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _FeatureItem(
            icon: Icons.star_half,
            title: l10n?.onboardingFeature1Point2 ?? 'Medium tasks: 20 XP',
            color: Colors.orange,
          ),
          const SizedBox(height: 12),
          _FeatureItem(
            icon: Icons.stars,
            title: l10n?.onboardingFeature1Point3 ?? 'Hard tasks: 30 XP',
            color: Colors.red,
          ),
        ],
      ),
    );
  }
}

class _FeaturePage2 extends StatelessWidget {
  const _FeaturePage2({required this.l10n});

  final AppLocalizations? l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.whatshot,
            size: 100,
            color: Colors.deepOrange,
          ),
          const SizedBox(height: 32),
          Text(
            l10n?.onboardingFeature2Title ?? 'Track Your Streaks',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            l10n?.onboardingFeature2Description ??
                'Build momentum by completing tasks every day. Maintain your streak to stay motivated!',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _FeatureItem(
            icon: Icons.check_circle,
            title: l10n?.onboardingFeature2Point1 ?? 'Daily task completion',
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          _FeatureItem(
            icon: Icons.notifications_active,
            title: l10n?.onboardingFeature2Point2 ?? 'Customizable reminders',
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(height: 12),
          _FeatureItem(
            icon: Icons.history,
            title: l10n?.onboardingFeature2Point3 ?? 'Completion history',
            color: theme.colorScheme.tertiary,
          ),
        ],
      ),
    );
  }
}

class _SampleTasksPage extends StatelessWidget {
  const _SampleTasksPage({
    required this.l10n,
    required this.onComplete,
  });

  final AppLocalizations? l10n;
  final Future<void> Function({bool createSampleTasks}) onComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.rocket_launch,
            size: 100,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 32),
          Text(
            l10n?.onboardingSampleTitle ?? 'Ready to Start?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            l10n?.onboardingSampleDescription ??
                'Would you like to start with sample tasks to see how it works?',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => onComplete(createSampleTasks: true),
              icon: const Icon(Icons.auto_awesome),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  l10n?.onboardingCreateSampleTasks ?? 'Create Sample Tasks',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => onComplete(createSampleTasks: false),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  l10n?.onboardingStartFromScratch ?? 'Start from Scratch',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}
