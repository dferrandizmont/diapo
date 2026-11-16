import 'package:diapo/core/database/develop_schedule.dart';
import 'package:diapo/core/database/tables.dart';
import 'package:flutter_test/flutter_test.dart';

/// True when the zone of the machine follows the rules of Europe/Madrid:
/// the clock goes from 02:00 to 03:00 the last Sunday of March and from
/// 03:00 to 02:00 the last Sunday of October.
bool get _hasMadridRules {
  final winter = DateTime(2026, 1, 15, 12).timeZoneOffset;
  final spring = DateTime(2026, 3, 29, 12).timeZoneOffset;
  final autumn = DateTime(2026, 10, 25, 12).timeZoneOffset;
  return winter == const Duration(hours: 1) &&
      spring == const Duration(hours: 2) &&
      autumn == const Duration(hours: 1);
}

void main() {
  group('developAtFor', () {
    test('instant: the roll develops as it is closed', () {
      final closed = DateTime(2026, 10, 24, 21, 30);
      expect(developAtFor(DevelopDelay.instant, closed), closed);
    });

    test('oneHour: an hour later', () {
      final closed = DateTime(2026, 10, 24, 21, 30);
      final developAt = developAtFor(DevelopDelay.oneHour, closed);
      expect(developAt, DateTime(2026, 10, 24, 22, 30));
      // An hour of real time, whatever the zone does with it.
      expect(developAt.difference(closed), const Duration(hours: 1));
    });

    test('nextMorning: 08:00 of the next day, late at night', () {
      final closed = DateTime(2026, 10, 24, 23, 59, 59);
      expect(
        developAtFor(DevelopDelay.nextMorning, closed),
        DateTime(2026, 10, 25, 8),
      );
    });

    test('nextMorning: 08:00 of the next day, early in the morning', () {
      final closed = DateTime(2026, 10, 24, 7, 15);
      expect(
        developAtFor(DevelopDelay.nextMorning, closed),
        DateTime(2026, 10, 25, 8),
      );
    });

    test('nextMorning: the month rolls over', () {
      final closed = DateTime(2026, 10, 31, 20);
      expect(
        developAtFor(DevelopDelay.nextMorning, closed),
        DateTime(2026, 11, 1, 8),
      );
    });

    test('nextMorning: the year rolls over', () {
      final closed = DateTime(2026, 12, 31, 20);
      expect(
        developAtFor(DevelopDelay.nextMorning, closed),
        DateTime(2027, 1, 1, 8),
      );
    });

    test('threeDays: three days later, at the same hour of the day', () {
      final closed = DateTime(2026, 10, 24, 21, 30, 15, 250);
      expect(
        developAtFor(DevelopDelay.threeDays, closed),
        DateTime(2026, 10, 27, 21, 30, 15, 250),
      );
    });

    test('threeDays: the month rolls over', () {
      final closed = DateTime(2026, 10, 30, 8);
      expect(
        developAtFor(DevelopDelay.threeDays, closed),
        DateTime(2026, 11, 2, 8),
      );
    });

    test('oneHour across the night the clock goes forward', () {
      // 01:30 of the 29th of March, the night the clock goes from 02:00 to
      // 03:00: an hour later it is 03:30.
      final closed = DateTime(2026, 3, 29, 1, 30);
      final developAt = developAtFor(DevelopDelay.oneHour, closed);
      expect(developAt.difference(closed), const Duration(hours: 1));
      expect(
        developAt,
        DateTime(2026, 3, 29, 3, 30),
        skip: _hasMadridRules
            ? null
            : 'The expectations of the change of the hour are the ones of '
                  'Europe/Madrid',
      );
    });

    test('threeDays across the night the clock goes back', () {
      // The 25th of October, the night the clock goes from 03:00 to 02:00:
      // three days later the hour of the day is the same, but there are 73
      // hours between the two moments.
      final closed = DateTime(2026, 10, 24, 12);
      final developAt = developAtFor(DevelopDelay.threeDays, closed);
      expect(developAt, DateTime(2026, 10, 27, 12));
      expect(
        developAt.difference(closed).inHours,
        73,
        skip: _hasMadridRules
            ? null
            : 'The expectations of the change of the hour are the ones of '
                  'Europe/Madrid',
      );
    });

    test('nextMorning across the night the clock goes back', () {
      final closed = DateTime(2026, 10, 24, 23, 30);
      final developAt = developAtFor(DevelopDelay.nextMorning, closed);
      expect(developAt, DateTime(2026, 10, 25, 8));
      expect(
        developAt.difference(closed).inMinutes,
        570,
        skip: _hasMadridRules
            ? null
            : 'The expectations of the change of the hour are the ones of '
                  'Europe/Madrid',
      );
    });
  });
}
