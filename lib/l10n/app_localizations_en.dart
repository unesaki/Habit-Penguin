// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Habit Penguin';

  @override
  String get tabTasks => 'Tasks';

  @override
  String get tabHome => 'Home';

  @override
  String get tabPenguin => 'Penguin';

  @override
  String get welcomeBack => 'Welcome back!';

  @override
  String get questDescription =>
      'Let\'s complete today\'s quests with your penguin';

  @override
  String get todayTasks => 'Today\'s Tasks';

  @override
  String get createTaskPrompt => 'Create your first task';

  @override
  String get createTaskInstruction =>
      'Tap the \'+\' button at the bottom right of the Tasks tab to add a new task.';

  @override
  String get seeMoreTasks => 'See more tasks in the Tasks tab.';

  @override
  String currentXp(int xp) {
    return 'XP: $xp XP';
  }

  @override
  String get completedTasksButton => 'Completed';

  @override
  String get activeTasks => 'Today\'s Tasks';

  @override
  String get registeredTasks => 'All Tasks';

  @override
  String get noActiveTasks => 'No tasks scheduled for today.';

  @override
  String get noTasks => 'No tasks yet. Tap + to add one.';

  @override
  String get addTask => 'Add Task';

  @override
  String get editTask => 'Edit Task';

  @override
  String get habitName => 'Habit Name';

  @override
  String get habitNameHint => 'e.g., Morning Stretch';

  @override
  String get habitNameRequired => 'Please enter a habit name';

  @override
  String get icon => 'Icon';

  @override
  String get basicInfo => 'Basic Information';

  @override
  String get schedule => 'Schedule';

  @override
  String get reminder => 'Reminder';

  @override
  String get date => 'Date';

  @override
  String get notSelected => 'Not selected';

  @override
  String get repeatingTask => 'Repeating Task';

  @override
  String get startDate => 'Start Date';

  @override
  String get endDate => 'End Date';

  @override
  String get enableNotification => 'Enable Notifications';

  @override
  String get notificationTime => 'Notification Time';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get createTask => 'Create Task';

  @override
  String get selectStartDate => 'Please select start and end dates.';

  @override
  String get endDateAfterStart => 'End date must be after start date.';

  @override
  String get selectDate => 'Please select a date.';

  @override
  String get difficultyEasy => 'Easy';

  @override
  String get difficultyNormal => 'Normal';

  @override
  String get difficultyHard => 'Hard';

  @override
  String get completeTask => 'Complete';

  @override
  String get deleteTask => 'Delete this task?';

  @override
  String get deleteWarning => 'This action cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get taskDeleted => 'Task deleted.';

  @override
  String get alreadyCompletedToday => 'Already completed today';

  @override
  String get questAchieved => 'Quest Achieved!';

  @override
  String xpGained(int xp) {
    return 'Gained $xp XP!';
  }

  @override
  String get ok => 'OK';

  @override
  String get completedTasks => 'Completed Tasks';

  @override
  String get noCompletedTasks => 'No completed tasks yet.';

  @override
  String earnedXp(int xp) {
    return 'Earned XP: $xp';
  }

  @override
  String completionDate(String date) {
    return 'Completed: $date';
  }

  @override
  String get penguinRoomComingSoon => 'Penguin Room Coming Soon!';

  @override
  String get penguinRoomDescription =>
      'Missions and new animations will be added in the next update.';

  @override
  String streakDays(int days) {
    return '$days day streak';
  }

  @override
  String get reminderOn => 'Reminder ON';

  @override
  String get anytime => 'Anytime';

  @override
  String error(String message) {
    return 'Error: $message';
  }
}
