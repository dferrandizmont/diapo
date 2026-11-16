import 'package:carrete/core/database/tables.dart';
import 'package:carrete/gallery/gallery_content.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/roll_fakes.dart';

int _ms(DateTime time) => time.millisecondsSinceEpoch;

void main() {
  group('buildGalleryContent', () {
    test('an empty database is an empty gallery', () {
      final content = buildGalleryContent(rolls: [], shots: []);

      expect(content.isEmpty, isTrue);
      expect(content.photoCount, 0);
    });

    test('loose photos are grouped by day, the newest day first', () {
      final content = buildGalleryContent(
        rolls: [],
        shots: [
          looseShotRow(1, takenAt: DateTime(2026, 11, 12, 9)),
          looseShotRow(2, takenAt: DateTime(2026, 11, 13, 8)),
          looseShotRow(3, takenAt: DateTime(2026, 11, 13, 21)),
        ],
      );

      final days = content.entries.cast<GalleryDay>();
      expect(days.map((d) => d.key), ['20261113', '20261112']);
      // Oldest first inside a day, like the frames of a roll.
      expect(days.first.photos.map((s) => s.id), [2, 3]);
      expect(days.first.day, DateTime(2026, 11, 13));
      expect(content.photoCount, 3);
      expect(content.dayOf('20261112')!.photos, hasLength(1));
      expect(content.dayOf('20250101'), isNull);
    });

    test('a photo just after midnight belongs to the new day', () {
      final content = buildGalleryContent(
        rolls: [],
        shots: [
          looseShotRow(1, takenAt: DateTime(2026, 11, 12, 23, 59, 59)),
          looseShotRow(2, takenAt: DateTime(2026, 11, 13, 0, 0, 1)),
        ],
      );

      expect(content.entries, hasLength(2));
    });

    test('a developed roll lists its frames in order', () {
      final roll = rollRow(
        state: RollState.developed,
        developedAt: _ms(DateTime(2026, 11, 13, 10)),
      );
      final content = buildGalleryContent(
        rolls: [roll],
        shots: [
          shotRow(2, galleryUri: 'content://media/2'),
          shotRow(1, galleryUri: 'content://media/1'),
          shotRow(3, failure: 'corrupted'),
          shotRow(4), // never reached the gallery
        ],
      );

      final entry = content.entries.single as GalleryRoll;
      expect(entry.photos.map((s) => s.frameNumber), [1, 2]);
      expect(entry.when, DateTime(2026, 11, 13, 10));
    });

    test('rolls and days are mixed, the newest first', () {
      final roll = rollRow(
        state: RollState.developed,
        developedAt: _ms(DateTime(2026, 11, 13, 10)),
      );
      final content = buildGalleryContent(
        rolls: [roll],
        shots: [
          shotRow(1, galleryUri: 'content://media/1'),
          looseShotRow(5, takenAt: DateTime(2026, 11, 13, 12)),
          looseShotRow(6, takenAt: DateTime(2026, 11, 13, 8)),
        ],
      );

      expect(content.entries.map((e) => e.runtimeType), [
        GalleryDay,
        GalleryRoll,
      ]);
    });

    test('a roll that is not developed shows no photo, only a card', () {
      final waiting = rollRow(state: RollState.developing, developAt: 5000);
      final content = buildGalleryContent(
        rolls: [waiting],
        // Even if a frame already had a place (a roll that is developing).
        shots: [shotRow(1, galleryUri: 'content://media/1')],
      );

      expect(content.developing.single.id, waiting.id);
      expect(content.entries, isEmpty);
      expect(content.photoCount, 0);
    });

    test('open, discarded and lost rolls are not listed at all', () {
      final content = buildGalleryContent(
        rolls: [
          rollRow(id: 1),
          rollRow(id: 2, state: RollState.discarded),
          rollRow(id: 3, state: RollState.lost),
        ],
        shots: [],
      );

      expect(content.isEmpty, isTrue);
    });

    test('a developed roll whose photos were all deleted disappears', () {
      final content = buildGalleryContent(
        rolls: [rollRow(state: RollState.developed, developedAt: 5000)],
        shots: [],
      );

      expect(content.entries, isEmpty);
    });

    test('developing rolls are listed newest first', () {
      final content = buildGalleryContent(
        rolls: [
          rollRow(id: 1, state: RollState.developing, createdAt: 100),
          rollRow(id: 2, state: RollState.developing, createdAt: 300),
          rollRow(id: 3, state: RollState.developing, createdAt: 200),
        ],
        shots: [],
      );

      expect(content.developing.map((r) => r.id), [2, 3, 1]);
    });
  });

  group('the key of a day', () {
    test('a day makes a key and the key gives the day back', () {
      expect(dayKey(DateTime(2026, 11, 3)), '20261103');
      expect(parseDayKey('20261103'), DateTime(2026, 11, 3));
    });

    test('anything that is not a real day is refused', () {
      expect(parseDayKey('abc'), isNull);
      expect(parseDayKey('2026110'), isNull);
      expect(parseDayKey('20260231'), isNull);
      expect(parseDayKey('20261301'), isNull);
    });
  });

  group('calendarDaysBetween', () {
    test('counts dates, not hours', () {
      expect(
        calendarDaysBetween(
          DateTime(2026, 11, 12, 23, 59),
          DateTime(2026, 11, 13, 0, 1),
        ),
        1,
      );
      expect(
        calendarDaysBetween(
          DateTime(2026, 11, 13, 0, 1),
          DateTime(2026, 11, 13, 23, 59),
        ),
        0,
      );
    });

    test('a day of 23 hours is still one day (Madrid, 29 March 2026)', () {
      // The clocks went forward at 02:00 on 29 March 2026: 28 March at
      // midnight to 29 March at midnight is 24 h, 29 to 30 is 23 h. In a
      // time zone with that change the 23 h are one day, not zero.
      expect(
        calendarDaysBetween(DateTime(2026, 3, 29), DateTime(2026, 3, 30)),
        1,
      );
      expect(
        calendarDaysBetween(DateTime(2026, 3, 28), DateTime(2026, 3, 30)),
        2,
      );
      expect(
        calendarDaysBetween(
          DateTime(2026, 3, 29, 23, 30),
          DateTime(2026, 3, 30, 0, 30),
        ),
        1,
      );
    });

    test('a day of 25 hours is still one day (Madrid, 25 October 2026)', () {
      expect(
        calendarDaysBetween(DateTime(2026, 10, 25), DateTime(2026, 10, 26)),
        1,
      );
    });

    test('works across months and years', () {
      expect(
        calendarDaysBetween(DateTime(2025, 12, 31), DateTime(2026, 1, 1)),
        1,
      );
      expect(
        calendarDaysBetween(DateTime(2026, 2, 28), DateTime(2026, 3, 1)),
        1,
      );
    });
  });
}
