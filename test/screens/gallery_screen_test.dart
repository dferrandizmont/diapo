import 'dart:async';

import 'package:carrete/core/database/app_database.dart';
import 'package:carrete/core/database/tables.dart';
import 'package:carrete/gallery/gallery_content.dart';
import 'package:carrete/gallery/photo_library.dart';
import 'package:carrete/screens/gallery/gallery_day_screen.dart';
import 'package:carrete/screens/gallery/gallery_screen.dart';
import 'package:carrete/screens/roll/frame_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../support/roll_fakes.dart';
import '../support/roll_harness.dart';

final _now = DateTime(2026, 11, 13, 12);
const _tall = Size(412, 2400);

List<Override> _overrides({
  List<RollRow> rolls = const [],
  List<ShotRow> shots = const [],
  FakeGalleryImages? images,
  Stream<List<ShotRow>>? shotsStream,
  FakePhotoLibrary? library,
  DateTime? now,
}) => [
  ...rollOverrides(rolls: rolls, gallery: images, now: now ?? _now),
  photoLibraryProvider.overrideWithValue(library ?? FakePhotoLibrary()),
  galleryShotsProvider.overrideWith(
    (ref) => shotsStream ?? Stream.value(shots),
  ),
];

RollRow _developed({int id = 7, int developedAt = 0}) => rollRow(
  id: id,
  state: RollState.developed,
  developedAt: developedAt == 0
      ? DateTime(2026, 11, 13, 10).millisecondsSinceEpoch
      : developedAt,
);

FakeGalleryImages _photos(int count) => FakeGalleryImages({
  for (var i = 1; i <= count; i++) 'content://media/$i': tinyPng,
});

void main() {
  group('the gallery', () {
    testWidgets('with nothing in it says there are no photos yet', (
      tester,
    ) async {
      await pumpRollApp(
        tester,
        const GalleryScreen(),
        overrides: _overrides(),
        size: _tall,
      );

      expect(find.text('Gallery'), findsOneWidget);
      expect(find.text('No photos yet'), findsOneWidget);
      expect(find.textContaining('show up here'), findsOneWidget);
    });

    testWidgets('lists a developed roll as a card with film, count and date', (
      tester,
    ) async {
      final opened = <int>[];
      await pumpRollApp(
        tester,
        GalleryScreen(onOpenRoll: opened.add),
        overrides: _overrides(
          rolls: [_developed()],
          shots: [
            shotRow(1, galleryUri: 'content://media/1'),
            shotRow(2, galleryUri: 'content://media/2'),
          ],
          images: _photos(2),
        ),
        size: _tall,
      );

      expect(find.text('ROLL 07'), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('2 FRAMES'), findsOneWidget);
      expect(find.textContaining('Developed on'), findsOneWidget);
      // The header counts the photos.
      expect(find.text('2 frames'), findsOneWidget);

      await tester.tap(find.text('Alpha'));
      await tester.pump();
      expect(opened, [7]);
    });

    testWidgets('a card shows the first photos of the roll on its strip', (
      tester,
    ) async {
      final images = _photos(6);
      await pumpRollApp(
        tester,
        const GalleryScreen(),
        overrides: _overrides(
          rolls: [_developed()],
          shots: [
            for (var i = 1; i <= 6; i++)
              shotRow(i, galleryUri: 'content://media/$i'),
          ],
          images: images,
        ),
        size: _tall,
      );

      expect(images.thumbnailsAsked, [
        'content://media/1',
        'content://media/2',
        'content://media/3',
        'content://media/4',
      ]);
    });

    testWidgets('groups loose photos by day and names today and yesterday', (
      tester,
    ) async {
      final opened = <String>[];
      await pumpRollApp(
        tester,
        GalleryScreen(onOpenDay: opened.add),
        overrides: _overrides(
          shots: [
            looseShotRow(1, takenAt: DateTime(2026, 11, 13, 9)),
            looseShotRow(2, takenAt: DateTime(2026, 11, 13, 10)),
            looseShotRow(
              3,
              takenAt: DateTime(2026, 11, 12, 18),
              filmId: 'beta',
            ),
            looseShotRow(4, takenAt: DateTime(2026, 11, 9, 18)),
            looseShotRow(5, takenAt: DateTime(2025, 12, 24, 18)),
          ],
          images: _photos(5),
        ),
        size: _tall,
      );

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('Mon, Nov 9'), findsOneWidget);
      expect(find.text('Wed, Dec 24 2025'), findsOneWidget);
      expect(find.text('LOOSE PHOTOS'), findsNWidgets(4));
      expect(find.text('2 FRAMES'), findsOneWidget);
      // The films of the day, so each photo is traceable to its film.
      expect(find.text('Beta'), findsOneWidget);

      await tester.tap(find.text('Yesterday'));
      await tester.pump();
      expect(opened, ['20261112']);
    });

    testWidgets('names yesterday right after a change of the clock', (
      tester,
    ) async {
      // Half an hour after midnight on 30 March 2026, the day after the clocks
      // went forward in Madrid: the 29th is yesterday, whatever its length.
      await pumpRollApp(
        tester,
        const GalleryScreen(),
        overrides: _overrides(
          now: DateTime(2026, 3, 30, 0, 30),
          shots: [
            looseShotRow(1, takenAt: DateTime(2026, 3, 29, 23, 30)),
            looseShotRow(2, takenAt: DateTime(2026, 3, 28, 12)),
          ],
          images: _photos(2),
        ),
        size: _tall,
      );

      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('Today'), findsNothing);
      expect(find.text('Sat, Mar 28'), findsOneWidget);
    });

    testWidgets('looks once for photos the system no longer has', (
      tester,
    ) async {
      final library = FakePhotoLibrary();
      final controller = StreamController<List<ShotRow>>();
      addTearDown(controller.close);
      await pumpRollApp(
        tester,
        const GalleryScreen(),
        overrides: _overrides(
          shotsStream: controller.stream,
          library: library,
          images: _photos(3),
        ),
        size: _tall,
      );
      expect(library.swept, isEmpty); // nothing known yet

      controller.add([
        looseShotRow(1, takenAt: DateTime(2026, 11, 13, 9)),
        looseShotRow(2, takenAt: DateTime(2026, 11, 13, 10)),
      ]);
      await tester.pump();
      await tester.pump();
      controller.add([looseShotRow(1, takenAt: DateTime(2026, 11, 13, 9))]);
      await tester.pump();
      await tester.pump();

      expect(library.swept, hasLength(1));
      expect(library.swept.single.map((s) => s.id), [1, 2]);
    });

    testWidgets('lists the newest first, rolls and days together', (
      tester,
    ) async {
      await pumpRollApp(
        tester,
        const GalleryScreen(),
        overrides: _overrides(
          rolls: [_developed()],
          shots: [
            shotRow(1, galleryUri: 'content://media/1'),
            looseShotRow(2, takenAt: DateTime(2026, 11, 13, 11)),
            looseShotRow(3, takenAt: DateTime(2026, 11, 8, 11)),
          ],
          images: _photos(3),
        ),
        size: _tall,
      );

      final today = tester.getTopLeft(find.text('Today')).dy;
      final roll = tester.getTopLeft(find.text('ROLL 07')).dy;
      final old = tester.getTopLeft(find.text('Sun, Nov 8')).dy;
      expect(today, lessThan(roll));
      expect(roll, lessThan(old));
    });

    testWidgets('a roll that is not developed yet shows no photo of it', (
      tester,
    ) async {
      final opened = <int>[];
      final images = _photos(3);
      await pumpRollApp(
        tester,
        GalleryScreen(onOpenRoll: opened.add),
        overrides: _overrides(
          rolls: [
            rollRow(
              id: 8,
              state: RollState.developing,
              developAt: _now
                  .add(const Duration(hours: 5))
                  .millisecondsSinceEpoch,
            ),
          ],
          // Even if a frame of it already had a place in the gallery.
          shots: [shotRow(1, rollId: 8, galleryUri: 'content://media/1')],
          images: images,
        ),
        size: _tall,
      );

      expect(find.text('DEVELOPING'), findsOneWidget);
      expect(find.text('Roll 08'), findsOneWidget);
      expect(find.textContaining('Waiting'), findsOneWidget);
      expect(images.thumbnailsAsked, isEmpty);
      expect(find.byType(Image), findsNothing);
      // With nothing else to show, the gallery is not "empty": a roll is on
      // its way.
      expect(find.text('No photos yet'), findsNothing);

      await tester.tap(find.text('Roll 08'));
      await tester.pump();
      expect(opened, [8]);
    });

    testWidgets('a photo deleted outside the app shows as missing', (
      tester,
    ) async {
      await pumpRollApp(
        tester,
        const GalleryScreen(),
        overrides: _overrides(
          shots: [looseShotRow(1, takenAt: DateTime(2026, 11, 13, 9))],
          images: FakeGalleryImages(), // the gallery has nothing
        ),
        size: _tall,
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('DELETED'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('says so when the gallery cannot be read', (tester) async {
      await pumpRollApp(
        tester,
        const GalleryScreen(),
        overrides: _overrides(
          shotsStream: Stream<List<ShotRow>>.error(StateError('no database')),
        ),
        size: _tall,
      );

      expect(find.text('The gallery could not be loaded.'), findsOneWidget);
    });

    testWidgets('every card is a labelled button that opens its photos', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpRollApp(
        tester,
        const GalleryScreen(),
        overrides: _overrides(
          rolls: [_developed()],
          shots: [
            shotRow(1, galleryUri: 'content://media/1'),
            looseShotRow(2, takenAt: DateTime(2026, 11, 13, 11)),
          ],
          images: _photos(2),
        ),
        size: _tall,
      );

      expect(
        find.bySemanticsLabel(
          RegExp('Roll 07, Alpha, Developed on .*, 1 frame'),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('Loose photos, Today, Alpha, 1 frame')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Back'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('speaks Spanish and Catalan', (tester) async {
      await pumpRollApp(
        tester,
        const GalleryScreen(),
        overrides: _overrides(
          shots: [looseShotRow(1, takenAt: DateTime(2026, 11, 13, 9))],
          images: _photos(1),
        ),
        locale: const Locale('es'),
        size: _tall,
      );
      expect(find.text('Galería'), findsOneWidget);
      expect(find.text('Hoy'), findsOneWidget);
      expect(find.text('FOTOS SUELTAS'), findsOneWidget);

      await pumpRollApp(
        tester,
        const GalleryScreen(),
        overrides: _overrides(
          shots: [looseShotRow(1, takenAt: DateTime(2026, 11, 13, 9))],
          images: _photos(1),
        ),
        locale: const Locale('ca'),
        size: _tall,
      );
      expect(find.text('Galeria'), findsOneWidget);
      expect(find.text('Avui'), findsOneWidget);
      expect(find.text('FOTOS SOLTES'), findsOneWidget);
    });

    for (final mode in ThemeMode.values.where((m) => m != ThemeMode.system)) {
      testWidgets('lays out with large text in the ${mode.name} theme', (
        tester,
      ) async {
        await pumpRollApp(
          tester,
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.4)),
            child: const GalleryScreen(),
          ),
          overrides: _overrides(
            rolls: [
              _developed(),
              rollRow(
                id: 8,
                state: RollState.developing,
                developAt: _now.millisecondsSinceEpoch + 1000,
              ),
            ],
            shots: [
              shotRow(1, galleryUri: 'content://media/1'),
              looseShotRow(2, takenAt: DateTime(2026, 11, 13, 11)),
            ],
            images: _photos(2),
          ),
          mode: mode,
          size: const Size(360, 3200),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Today'), findsOneWidget);
      });
    }
  });

  group('a day of loose photos', () {
    final taken = DateTime(2026, 11, 13, 9);
    List<ShotRow> day(int count) => [
      for (var i = 1; i <= count; i++)
        looseShotRow(i, takenAt: taken.add(Duration(minutes: i))),
    ];

    testWidgets('is a contact sheet of the photos of that day', (tester) async {
      await pumpRollApp(
        tester,
        const GalleryDayScreen(dayKey: '20261113'),
        overrides: _overrides(shots: day(5), images: _photos(5)),
        size: _tall,
      );

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('5 frames'), findsOneWidget); // the header
      expect(find.text('LOOSE PHOTOS'), findsOneWidget);
      for (var i = 1; i <= 5; i++) {
        expect(find.byKey(ValueKey('frame-$i')), findsOneWidget);
      }
    });

    testWidgets('opens a photo in the viewer, which swipes the whole day', (
      tester,
    ) async {
      await pumpRollApp(
        tester,
        const GalleryDayScreen(dayKey: '20261113'),
        overrides: _overrides(shots: day(3), images: _photos(3)),
        size: _tall,
      );

      await tester.tap(find.byKey(const ValueKey('frame-2')));
      await tester.pumpAndSettle();

      expect(find.byType(FrameViewer), findsOneWidget);
      expect(find.text('2 of 3'), findsOneWidget);
      expect(find.textContaining('Alpha'), findsOneWidget);
      expect(find.bySemanticsLabel('Share'), findsOneWidget);
      expect(find.bySemanticsLabel('Delete'), findsOneWidget);
    });

    testWidgets('a long day is cut into sheets of a roll but swipes as one', (
      tester,
    ) async {
      await pumpRollApp(
        tester,
        const GalleryDayScreen(dayKey: '20261113'),
        overrides: _overrides(shots: day(40), images: _photos(40)),
        size: const Size(412, 6000),
      );

      expect(find.text('LOOSE PHOTOS'), findsNWidgets(2));
      // The numbers go on from one sheet to the next.
      expect(find.byKey(const ValueKey('frame-37')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('frame-37')));
      await tester.pumpAndSettle();
      expect(find.text('37 of 40'), findsOneWidget);
    });

    testWidgets('a day with no photos says it cannot be found', (tester) async {
      await pumpRollApp(
        tester,
        const GalleryDayScreen(dayKey: '20240101'),
        overrides: _overrides(shots: day(2), images: _photos(2)),
        size: _tall,
      );

      expect(find.text('This day cannot be found'), findsOneWidget);
    });

    testWidgets('a key that is not a day does not crash', (tester) async {
      await pumpRollApp(
        tester,
        const GalleryDayScreen(dayKey: 'banana'),
        overrides: _overrides(),
        size: _tall,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('This day cannot be found'), findsOneWidget);
    });

    testWidgets('keeps up when a photo is deleted meanwhile', (tester) async {
      final controller = StreamController<List<ShotRow>>();
      addTearDown(controller.close);
      await pumpRollApp(
        tester,
        const GalleryDayScreen(dayKey: '20261113'),
        overrides: _overrides(
          shotsStream: controller.stream,
          images: _photos(3),
        ),
        size: _tall,
      );
      controller.add(day(3));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('frame-3')), findsOneWidget);

      controller.add(day(2));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('frame-3')), findsNothing);
      expect(find.text('2 frames'), findsWidgets);
    });
  });
}
