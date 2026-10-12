import 'package:intl/intl.dart';

/// Human-friendly timestamp formatting for chat UIs.
abstract final class TimeFormat {
  /// "09:41" if today, "Yesterday", "Mon", or "12/05/2025" if older.
  static String listTimestamp(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(time.year, time.month, time.day);

    if (day == today) return DateFormat.Hm().format(time);
    final diff = today.difference(day).inDays;
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat.E().format(time);
    return DateFormat.yMd().format(time);
  }

  /// "09:41" for message bubbles.
  static String messageTime(DateTime time) => DateFormat.Hm().format(time);

  /// Day separator inside a conversation: "Today", "Yesterday", "12 May 2025".
  static String daySeparator(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(time.year, time.month, time.day);
    if (day == today) return 'Today';
    final diff = today.difference(day).inDays;
    if (diff == 1) return 'Yesterday';
    return DateFormat.yMMMMd().format(time);
  }

  /// Whether two timestamps fall on different calendar days.
  static bool isNewDay(DateTime? previous, DateTime next) {
    if (previous == null) return true;
    return previous.year != next.year ||
        previous.month != next.month ||
        previous.day != next.day;
  }
}
