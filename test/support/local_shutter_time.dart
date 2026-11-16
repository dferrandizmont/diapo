import 'package:timezone/timezone.dart' as tz;

/// A local shutter in a chosen offset, with DateTime.now()'s offset-free JSON.
/// Tests can change offsets without changing the machine's timezone.
class LocalShutterTime extends tz.TZDateTime {
  LocalShutterTime(DateTime calendar, Duration offset)
    : super(
        tz.Location('shutter', [], [], [
          tz.TimeZone(offset, isDst: false, abbreviation: 'test'),
        ]),
        calendar.year,
        calendar.month,
        calendar.day,
        calendar.hour,
        calendar.minute,
        calendar.second,
        calendar.millisecond,
      );

  @override
  String toIso8601String() => DateTime(
    year,
    month,
    day,
    hour,
    minute,
    second,
    millisecond,
  ).toIso8601String();
}
