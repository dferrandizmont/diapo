import 'package:carrete/platform/exif_dates.dart';
import 'package:carrete/platform/media_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseExifDate', () {
    test('reads the date and time as the clock of the camera', () {
      expect(
        parseExifDate('2019:07:14 18:30:05'),
        DateTime(2019, 7, 14, 18, 30, 5),
      );
    });

    test('accepts subseconds after the time', () {
      expect(
        parseExifDate('2019:07:14 18:30:05.12'),
        DateTime(2019, 7, 14, 18, 30, 5),
      );
    });

    test('knows no date when there is no text, or only placeholders', () {
      expect(parseExifDate(null), isNull);
      expect(parseExifDate(''), isNull);
      expect(parseExifDate('    :  :     :  :  '), isNull);
      expect(parseExifDate('0000:00:00 00:00:00'), isNull);
    });

    test('rejects dates that cannot exist', () {
      expect(parseExifDate('2019:13:01 10:00:00'), isNull);
      expect(parseExifDate('2019:02:31 10:00:00'), isNull);
      expect(parseExifDate('2019:07:14 25:00:00'), isNull);
      expect(parseExifDate('not a date'), isNull);
    });
  });

  group('parseExifOffset', () {
    test('reads signed hours and minutes', () {
      expect(parseExifOffset('+02:00'), const Duration(hours: 2));
      expect(parseExifOffset('-05:30'), -const Duration(hours: 5, minutes: 30));
      expect(parseExifOffset('+00:00'), Duration.zero);
    });

    test('knows no offset when it is missing or malformed', () {
      expect(parseExifOffset(null), isNull);
      expect(parseExifOffset(''), isNull);
      expect(parseExifOffset('02:00'), isNull);
      expect(parseExifOffset('+25:00'), isNull);
      expect(parseExifOffset('+02:75'), isNull);
    });
  });

  group('photoDateOf', () {
    test('prefers the moment the photo was taken', () {
      final date = photoDateOf(
        const ExifDates(
          original: '2020:01:02 03:04:05',
          digitized: '2021:01:02 03:04:05',
        ),
      )!;
      expect(date.wall, DateTime(2020, 1, 2, 3, 4, 5));
      // No offset: the instant is the clock of the camera.
      expect(date.instant, date.wall);
    });

    test('goes on to the digitised date', () {
      final date = photoDateOf(
        const ExifDates(
          original: '0000:00:00 00:00:00',
          digitized: '2021:01:02 03:04:05',
          digitizedOffset: '+01:00',
        ),
      )!;
      expect(date.wall, DateTime(2021, 1, 2, 3, 4, 5));
      expect(date.instant.toUtc(), DateTime.utc(2021, 1, 2, 2, 4, 5));
    });

    test('knows no date when the photo has neither (never the file date)', () {
      expect(photoDateOf(const ExifDates()), isNull);
      expect(photoDateOf(const ExifDates(original: 'garbage')), isNull);
    });

    test('honours the offset: the day of the camera is not the UTC day', () {
      // 23:30 in New York on 31 December is already January in UTC.
      final date = photoDateOf(
        const ExifDates(
          original: '2020:12:31 23:30:00',
          originalOffset: '-05:00',
        ),
      )!;
      expect(date.wall, DateTime(2020, 12, 31, 23, 30));
      expect(date.instant.toUtc(), DateTime.utc(2021, 1, 1, 4, 30));
    });

    test('an offset ahead of UTC moves the instant to the day before', () {
      // 00:30 on 1 January in Tokyo is still 31 December in UTC.
      final date = photoDateOf(
        const ExifDates(
          original: '2021:01:01 00:30:00',
          originalOffset: '+09:00',
        ),
      )!;
      expect(date.wall, DateTime(2021, 1, 1, 0, 30));
      expect(date.instant.toUtc(), DateTime.utc(2020, 12, 31, 15, 30));
    });

    test('an offset that is not valid is ignored', () {
      final date = photoDateOf(
        const ExifDates(
          original: '2020:06:01 10:00:00',
          originalOffset: 'CEST',
        ),
      )!;
      expect(date.instant, date.wall);
    });
  });

  group('MediaStore.readExifDates', () {
    const channel = MethodChannel('carrete/media');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('asks the native side for the file and wraps the answer', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'readExifDates');
        expect(call.arguments, {'path': '/cache/import/b1/photo_0.jpg'});
        return <String, String?>{
          'original': '2019:07:14 18:30:05',
          'originalOffset': '+02:00',
          'digitized': null,
          'digitizedOffset': null,
        };
      });

      final dates = await MediaStore.readExifDates(
        '/cache/import/b1/photo_0.jpg',
      );

      expect(dates.original, '2019:07:14 18:30:05');
      expect(dates.originalOffset, '+02:00');
      expect(dates.digitized, isNull);
    });

    test('answers no dates when the native side fails or is missing', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'read_failed');
      });
      expect((await MediaStore.readExifDates('/x.jpg')).original, isNull);

      messenger.setMockMethodCallHandler(channel, null);
      expect((await MediaStore.readExifDates('/x.jpg')).original, isNull);
    });
  });
}
