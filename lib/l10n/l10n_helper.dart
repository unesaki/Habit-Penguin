import 'package:flutter/material.dart';
import 'app_localizations.dart';
import '../utils/date_formatter.dart';

/// 多言語化ヘルパー関数
class L10nHelper {
  /// BuildContextからAppLocalizationsを取得
  static AppLocalizations of(BuildContext context) {
    return AppLocalizations.of(context)!;
  }

  /// 現在のロケールを取得
  static String getLocale(BuildContext context) {
    return Localizations.localeOf(context).languageCode;
  }

  /// 日付をロケールに応じてフォーマット
  static String formatDate(BuildContext context, DateTime date) {
    final locale = getLocale(context);
    return DateFormatter.formatDate(date, locale);
  }

  /// 時刻をロケールに応じてフォーマット
  static String formatTime(BuildContext context, DateTime time) {
    final locale = getLocale(context);
    return DateFormatter.formatTime(time, locale);
  }

  /// TimeOfDayをロケールに応じてフォーマット
  static String formatTimeOfDay(BuildContext context, TimeOfDay time) {
    final locale = getLocale(context);
    return DateFormatter.formatTimeOfDay(time.hour, time.minute, locale);
  }

  /// 日付範囲をロケールに応じてフォーマット
  static String formatDateRange(
    BuildContext context,
    DateTime start,
    DateTime end,
  ) {
    final locale = getLocale(context);
    return DateFormatter.formatDateRange(start, end, locale);
  }

  /// 難易度ラベルを取得
  static String getDifficultyLabel(BuildContext context, String difficulty) {
    final l10n = of(context);
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return l10n.difficultyEasy;
      case 'hard':
        return l10n.difficultyHard;
      case 'normal':
      default:
        return l10n.difficultyNormal;
    }
  }
}
