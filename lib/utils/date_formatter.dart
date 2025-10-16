import 'package:intl/intl.dart';

/// 日付と時刻のフォーマットユーティリティ
///
/// ロケールに応じた日付・時刻の表示をサポートします。
class DateFormatter {
  /// 日付をロケールに応じてフォーマット
  ///
  /// 例:
  /// - 日本語: 2025/01/15
  /// - 英語: Jan 15, 2025
  static String formatDate(DateTime date, String locale) {
    if (locale.startsWith('ja')) {
      return DateFormat('yyyy/MM/dd').format(date);
    } else {
      return DateFormat('MMM d, y').format(date);
    }
  }

  /// 時刻をロケールに応じてフォーマット
  ///
  /// 例:
  /// - 日本語: 09:00
  /// - 英語: 9:00 AM
  static String formatTime(DateTime time, String locale) {
    if (locale.startsWith('ja')) {
      return DateFormat('HH:mm').format(time);
    } else {
      return DateFormat('h:mm a').format(time);
    }
  }

  /// TimeOfDayをロケールに応じてフォーマット
  static String formatTimeOfDay(int hour, int minute, String locale) {
    final dateTime = DateTime(2000, 1, 1, hour, minute);
    return formatTime(dateTime, locale);
  }

  /// 日付範囲をロケールに応じてフォーマット
  ///
  /// 例:
  /// - 日本語: 2025/01/01 〜 2025/12/31
  /// - 英語: Jan 1, 2025 - Dec 31, 2025
  static String formatDateRange(DateTime start, DateTime end, String locale) {
    final formattedStart = formatDate(start, locale);
    final formattedEnd = formatDate(end, locale);

    if (locale.startsWith('ja')) {
      return '$formattedStart 〜 $formattedEnd';
    } else {
      return '$formattedStart - $formattedEnd';
    }
  }

  /// 相対的な日付表示（今日、昨日など）
  ///
  /// 例:
  /// - 日本語: 今日、昨日、2日前
  /// - 英語: Today, Yesterday, 2 days ago
  static String formatRelativeDate(DateTime date, String locale) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(date.year, date.month, date.day);
    final difference = today.difference(targetDay).inDays;

    if (locale.startsWith('ja')) {
      if (difference == 0) return '今日';
      if (difference == 1) return '昨日';
      if (difference == -1) return '明日';
      if (difference > 0) return '$difference日前';
      return '${-difference}日後';
    } else {
      if (difference == 0) return 'Today';
      if (difference == 1) return 'Yesterday';
      if (difference == -1) return 'Tomorrow';
      if (difference > 0) {
        return difference == 1 ? '$difference day ago' : '$difference days ago';
      }
      final days = -difference;
      return days == 1 ? 'in $days day' : 'in $days days';
    }
  }
}
