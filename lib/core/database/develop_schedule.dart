import 'tables.dart';

/// When a roll closed at [closedAt] starts developing.
///
/// The times are the ones of the device: a roll that develops "the next
/// morning" does it at [nextMorningHour] of the next day, and a roll that
/// develops "in three days" does it at the same hour of the day three days
/// later, even when the device changes its time zone in between (the change
/// of the hour of the day is kept).
///
/// [closedAt] is expected to be a local time; the result is local too.
DateTime developAtFor(DevelopDelay delay, DateTime closedAt) {
  switch (delay) {
    case DevelopDelay.instant:
      return closedAt;
    case DevelopDelay.oneHour:
      return closedAt.add(const Duration(hours: 1));
    case DevelopDelay.nextMorning:
      final nextDay = DateTime(closedAt.year, closedAt.month, closedAt.day + 1);
      return DateTime(
        nextDay.year,
        nextDay.month,
        nextDay.day,
        nextMorningHour,
      );
    case DevelopDelay.threeDays:
      return DateTime(
        closedAt.year,
        closedAt.month,
        closedAt.day + 3,
        closedAt.hour,
        closedAt.minute,
        closedAt.second,
        closedAt.millisecond,
      );
  }
}
