import 'package:chattingapp/core/utils/time_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimeFormat.isNewDay', () {
    test('is true when previous is null', () {
      final next = DateTime(2026, 1, 5, 10);
      expect(TimeFormat.isNewDay(null, next), isTrue);
    });

    test('is false for same calendar day', () {
      final prev = DateTime(2026, 1, 5, 9);
      final next = DateTime(2026, 1, 5, 22, 59);
      expect(TimeFormat.isNewDay(prev, next), isFalse);
    });

    test('is true across day, month and year boundaries', () {
      expect(
        TimeFormat.isNewDay(DateTime(2026, 1, 5, 23), DateTime(2026, 1, 6, 0)),
        isTrue,
      );
      expect(
        TimeFormat.isNewDay(DateTime(2026, 1, 31, 23), DateTime(2026, 2, 1, 0)),
        isTrue,
      );
      expect(
        TimeFormat.isNewDay(DateTime(2025, 12, 31, 23), DateTime(2026, 1, 1, 0)),
        isTrue,
      );
    });
  });

  group('TimeFormat.messageTime', () {
    test('formats as 24h HH:mm', () {
      expect(TimeFormat.messageTime(DateTime(2026, 1, 5, 9, 5)), '09:05');
      expect(TimeFormat.messageTime(DateTime(2026, 1, 5, 21, 42)), '21:42');
    });
  });

  group('TimeFormat.daySeparator', () {
    test('returns Today for the current day', () {
      final now = DateTime.now();
      expect(TimeFormat.daySeparator(now), 'Today');
    });

    test('returns Yesterday for the previous day', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(TimeFormat.daySeparator(yesterday), 'Yesterday');
    });

    test('returns a formatted date for older days', () {
      final old = DateTime(2025, 5, 12, 10);
      expect(TimeFormat.daySeparator(old), 'May 12, 2025');
    });
  });
}
