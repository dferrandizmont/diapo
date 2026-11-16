import 'dart:async';

import 'package:diapo/core/database/database_provider.dart';
import 'package:diapo/core/database/rolls_dao.dart';
import 'package:diapo/core/database/app_database.dart';
import 'package:diapo/core/database/tables.dart';
import 'package:diapo/roll/roll_providers.dart';
import 'package:diapo/roll/roll_reveal.dart';
import 'package:diapo/gallery/photo_library.dart';
import 'package:diapo/gallery/gallery_content.dart';
import 'package:diapo/platform/photo_actions.dart';
import 'package:diapo/platform/gallery_images.dart';
import 'package:diapo/render/film_resources.dart';
import 'package:diapo/screens/roll/contact_sheet.dart';
import 'package:diapo/screens/roll/frame_viewer.dart';
import 'package:diapo/screens/roll/roll_screen.dart';
import 'package:diapo/screens/gallery/gallery_screen.dart';
import 'package:diapo/ui/theme/carrete_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/roll_fakes.dart';
import '../../support/roll_harness.dart';
import '../../support/fakes.dart';
import '../../support/test_database.dart';

final _noon = DateTime(2026, 11, 13, 12);

/// A closed roll that develops [after] noon of 2026-11-13.
RollRow _waiting({
  Duration after = const Duration(hours: 22),
  int length = 24,
}) {
  final closed = _noon.millisecondsSinceEpoch;
  return rollRow(
    state: RollState.developing,
    length: length,
    closedAt: closed,
    developAt: _noon.add(after).millisecondsSinceEpoch,
  );
}

void main() {
  group('a roll that is not there', () {
    testWidgets('deleting the open roll shows the missing state', (
      tester,
    ) async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final roll = await RollsDao(database)
          .openRoll(filmId: 'alpha', length: 12);
      await pumpRollApp(
        tester,
        RollScreen(id: '${roll.id}'),
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          recipeBookProvider.overrideWith((ref) async => testBook()),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.text('This roll is still in the camera'), findsOneWidget);
      await (database.delete(
        database.rolls,
      )..where((r) => r.id.equals(roll.id))).go();
      await tester.pumpAndSettle();
      expect(find.text('This roll cannot be found'), findsOneWidget);
      expect(find.text('This roll is still in the camera'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('says it cannot be found', (tester) async {
      await pumpRollApp(
        tester,
        const RollScreen(id: '7'),
        overrides: rollOverrides(),
      );
      expect(find.text('This roll cannot be found'), findsOneWidget);
    });

    testWidgets('says the same for an id that is not a number', (tester) async {
      await pumpRollApp(
        tester,
        const RollScreen(id: 'abc'),
        overrides: rollOverrides(),
      );
      expect(find.text('This roll cannot be found'), findsOneWidget);
    });

    testWidgets('a thrown-away roll says so', (tester) async {
      await pumpRollApp(
        tester,
        const RollScreen(id: '7'),
        overrides: rollOverrides(rolls: [rollRow(state: RollState.discarded)]),
      );
      expect(find.text('This roll was thrown away'), findsOneWidget);
    });

    testWidgets('a roll still in the camera says so', (tester) async {
      await pumpRollApp(
        tester,
        const RollScreen(id: '7'),
        overrides: rollOverrides(rolls: [rollRow()]),
      );
      expect(find.text('This roll is still in the camera'), findsOneWidget);
    });

    testWidgets('a lost roll says it cannot be developed', (tester) async {
      await pumpRollApp(
        tester,
        const RollScreen(id: '7'),
        overrides: rollOverrides(rolls: [rollRow(state: RollState.lost)]),
      );
      expect(find.text('This roll cannot be developed'), findsOneWidget);
      expect(find.textContaining('cannot be recovered'), findsOneWidget);
      expect(find.text('Develop now'), findsNothing);
    });
  });

  group('a roll that is waiting', () {
    testWidgets('shows when it will be ready and its frames', (tester) async {
      await pumpRollApp(
        tester,
        const RollScreen(id: '7'),
        overrides: rollOverrides(rolls: [_waiting()], now: _noon),
      );
      expect(find.text('Roll 07'), findsOneWidget);
      expect(find.text('Roll waiting'), findsOneWidget);
      // 22 hours after noon: 10 in the morning of the next day. It says the
      // roll can be developed from then, not that it will be done by itself.
      expect(find.textContaining('You can develop from'), findsOneWidget);
      expect(find.textContaining('Ready on'), findsNothing);
      expect(find.textContaining('Developed'), findsNothing);
      expect(find.textContaining('Sat, Nov 14'), findsOneWidget);
      expect(find.textContaining('10:00 AM'), findsOneWidget);
      expect(find.text('Develop now'), findsOneWidget);
      // A reminder that the photos live only on this phone.
      expect(find.byKey(const ValueKey('roll-loss-note')), findsOneWidget);
    });

    testWidgets('uses the 24-hour clock when the system does', (tester) async {
      await pumpRollApp(
        tester,
        MediaQuery(
          data: const MediaQueryData(alwaysUse24HourFormat: true),
          child: const RollScreen(id: '7'),
        ),
        overrides: rollOverrides(rolls: [_waiting()], now: _noon),
      );
      expect(find.textContaining('10:00'), findsOneWidget);
      expect(find.textContaining('AM'), findsNothing);
    });

    testWidgets('shows the date in the language of the app', (tester) async {
      await pumpRollApp(
        tester,
        const RollScreen(id: '7'),
        overrides: rollOverrides(rolls: [_waiting()], now: _noon),
        locale: const Locale('es'),
      );
      expect(find.text('Carrete 07'), findsOneWidget);
      expect(
        find.textContaining('Puedes revelar a partir del'),
        findsOneWidget,
      );
      expect(find.textContaining('Listo el'), findsNothing);
    });

    testWidgets('warns before developing early and keeps waiting on cancel', (
      tester,
    ) async {
      final service = FakeRollService();
      await pumpRollApp(
        tester,
        const RollScreen(id: '7'),
        overrides: rollOverrides(
          rolls: [_waiting()],
          shots: {
            7: [for (var i = 1; i <= 24; i++) shotRow(i)],
          },
          now: _noon,
          service: service,
        ),
      );
      await tester.tap(find.text('Develop now'));
      await tester.pumpAndSettle();
      expect(find.text('Develop now?'), findsOneWidget);
      expect(
        find.textContaining(
          'The 24 photos on this roll will be developed now.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('cannot be undone'), findsOneWidget);
      expect(find.textContaining('you lose it'), findsNothing);

      await tester.tap(find.text('Keep waiting'));
      await tester.pumpAndSettle();
      expect(service.calls, isEmpty);
      expect(find.text('Roll waiting'), findsOneWidget);
    });

    testWidgets('cannot be developed now before its photos are known', (
      tester,
    ) async {
      final shots = StreamController<List<ShotRow>>();
      addTearDown(() => unawaited(shots.close()));
      final service = FakeRollService();
      await pumpRollApp(
        tester,
        const RollScreen(id: '7'),
        overrides: rollOverrides(
          rolls: [_waiting()],
          shotsStream: shots.stream,
          now: _noon,
          service: service,
        ),
      );
      await tester.tap(find.text('Develop now'));
      await tester.pumpAndSettle();
      expect(find.text('Develop now?'), findsNothing);
      expect(service.calls, isEmpty);

      // A roll shot only in part says the real count, not its capacity.
      shots.add([for (var i = 1; i <= 10; i++) shotRow(i)]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Develop now'));
      await tester.pumpAndSettle();
      expect(find.text('Develop now?'), findsOneWidget);
      expect(
        find.textContaining(
          'The 10 photos on this roll will be developed now.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('24 photos'), findsNothing);
    });

    testWidgets('develops at once after the warning and shows the progress', (
      tester,
    ) async {
      final service = FakeRollService();
      await pumpRollApp(
        tester,
        const RollScreen(id: '7'),
        overrides: rollOverrides(
          rolls: [_waiting()],
          shots: {
            7: [for (var i = 1; i <= 24; i++) shotRow(i)],
          },
          now: _noon,
          service: service,
        ),
      );
      await tester.tap(find.text('Develop now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Develop now').last);
      await tester.pumpAndSettle();
      expect(service.calls, ['developNow 7']);
      expect(find.text('Developing'), findsOneWidget);
      expect(find.text('Roll waiting'), findsNothing);
    });

    testWidgets('says so when developing fails and offers it again', (
      tester,
    ) async {
      final service = FakeRollService()..failWith = StateError('no');
      await pumpRollApp(
        tester,
        const RollScreen(id: '7'),
        overrides: rollOverrides(
          rolls: [_waiting()],
          now: _noon,
          service: service,
        ),
      );
      await tester.tap(find.text('Develop now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Develop now').last);
      await tester.pumpAndSettle();
      expect(find.text('That did not work. Try again.'), findsOneWidget);
      expect(find.text('Develop now'), findsOneWidget);
    });

    testWidgets('throws the roll away only after a confirmation', (
      tester,
    ) async {
      final service = FakeRollService();
      await pumpRollApp(
        tester,
        const RollScreen(id: '7'),
        overrides: rollOverrides(
          rolls: [_waiting()],
          now: _noon,
          service: service,
        ),
      );
      await tester.tap(find.text('Throw away the roll'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.calls, isEmpty);

      await tester.tap(find.text('Throw away the roll'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Throw away'));
      await tester.pumpAndSettle();
      expect(service.calls, ['discard 7']);
    });

    testWidgets('starts developing by itself when the time comes', (
      tester,
    ) async {
      var now = _noon;
      var runs = 0;
      await pumpRollApp(
        tester,
        const RollScreen(id: '7'),
        overrides: rollOverrides(
          rolls: [_waiting(after: const Duration(seconds: 30))],
          clock: () => now,
          foreground: RollForeground(
            develop: () async {
              runs++;
            },
          ),
        ),
      );
      expect(find.text('Roll waiting'), findsOneWidget);
      expect(runs, 0);

      now = _noon.add(const Duration(seconds: 31));
      await tester.pump(const Duration(seconds: 31));
      await tester.pump();
      expect(find.text('Developing'), findsOneWidget);
      expect(runs, 1);
    });
  });

  group('a roll that is being developed', () {
    testWidgets('counts the frames done on the LCD and on a strip', (
      tester,
    ) async {
      await pumpRollApp(
        tester,
        const RollScreen(id: '7'),
        overrides: rollOverrides(
          rolls: [_waiting()],
          progress: {7: progress(7, 24)},
          now: _noon,
        ),
      );
      expect(find.text('Developing'), findsOneWidget);
      expect(find.text('Keep the app open until it finishes.'), findsOneWidget);
      expect(find.bySemanticsLabel('7 of 24 frames developed'), findsOneWidget);
      // No generic spinner.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);

      Color? fill(int i) {
        final box = tester.widget<AnimatedContainer>(
          find.byKey(ValueKey('develop-cell-$i')),
        );
        return (box.decoration! as BoxDecoration).color;
      }

      final palette = CarretePalette.light;
      expect(fill(0), palette.accent);
      expect(fill(6), palette.accent);
      expect(fill(7), Colors.transparent);
      expect(find.byKey(const ValueKey('develop-cell-23')), findsOneWidget);
      expect(find.byKey(const ValueKey('develop-cell-24')), findsNothing);
    });

    testWidgets('is developing too when its time has passed', (tester) async {
      await pumpRollApp(
        tester,
        const RollScreen(id: '7'),
        overrides: rollOverrides(
          rolls: [_waiting(after: Duration.zero, length: 12)],
          shots: {
            7: [for (var i = 1; i <= 12; i++) shotRow(i)],
          },
          now: _noon,
        ),
      );
      expect(find.text('Developing'), findsOneWidget);
      expect(find.bySemanticsLabel('0 of 12 frames developed'), findsOneWidget);
    });

    testWidgets('also reads well in the dark theme', (tester) async {
      await pumpRollApp(
        tester,
        const RollScreen(id: '7'),
        mode: ThemeMode.dark,
        overrides: rollOverrides(
          rolls: [_waiting()],
          progress: {7: progress(3, 12)},
          now: _noon,
        ),
      );
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, CarretePalette.dark.background);
      final cell = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('develop-cell-0')),
      );
      expect(
        (cell.decoration! as BoxDecoration).color,
        CarretePalette.dark.accent,
      );
    });
  });

  group('a developed roll', () {
    final developed = rollRow(
      state: RollState.developed,
      closedAt: _noon.millisecondsSinceEpoch,
      developedAt: DateTime(2026, 11, 14, 9).millisecondsSinceEpoch,
    );
    final shots = [
      shotRow(1, galleryUri: 'content://media/1'),
      shotRow(2, galleryUri: 'content://media/2'),
      shotRow(3, failure: 'vault_corrupt'),
      shotRow(4, galleryUri: 'content://media/deleted'),
      shotRow(5),
      shotRow(6, galleryUri: 'content://media/6'),
    ];

    FakeGalleryImages gallery() => FakeGalleryImages({
      'content://media/1': tinyPng,
      'content://media/2': tinyPng,
      'content://media/6': tinyPng,
    });

    for (final galleryScreen in [false, true]) {
      for (final resume in [false, true]) {
        testWidgets(
          '${resume ? 'resuming' : 'reopening'} the ${galleryScreen ? 'gallery' : 'roll'} shows a restored native photo',
          (tester) async {
            const channel = MethodChannel('carrete/media');
            var missing = true;
            var calls = 0;
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              channel,
              (_) async {
                calls++;
                if (missing) throw PlatformException(code: 'not_found');
                return tinyPng;
              },
            );
            addTearDown(
              () => tester.binding.defaultBinaryMessenger
                  .setMockMethodCallHandler(channel, null),
            );
            final container = ProviderContainer(
              overrides: [
                rollProvider(7).overrideWith((ref) => Stream.value(developed)),
                rollShotsProvider(7)
                    .overrideWith((ref) => Stream.value([shots.first])),
                recipeBookProvider.overrideWith((ref) async => testBook()),
                galleryContentProvider.overrideWithValue(
                  AsyncData(
                    GalleryContent(
                      developing: [],
                      entries: [
                        GalleryRoll(developed, [shots.first], _noon),
                      ],
                    ),
                  ),
                ),
                photoLibraryProvider.overrideWithValue(FakePhotoLibrary()),
                rollRevealStoreProvider.overrideWithValue(
                  MemoryRollRevealStore(allSeen: true),
                ),
              ],
            );
            addTearDown(container.dispose);
            Widget screen(Widget child) =>
                UncontrolledProviderScope(container: container, child: child);
            final page = galleryScreen
                ? const GalleryScreen()
                : const RollScreen(id: '7');
            await pumpRollApp(tester, screen(page));
            await tester.pumpAndSettle();
            expect(find.text('DELETED'), findsOneWidget);
            missing = false;
            tester.element(find.byType(GalleryThumbnail)).markNeedsBuild();
            await tester.pumpAndSettle();
            expect(find.text('DELETED'), findsOneWidget);
            expect(calls, 1);
            if (resume) {
              for (final state in [
                AppLifecycleState.inactive,
                AppLifecycleState.hidden,
                AppLifecycleState.paused,
                AppLifecycleState.hidden,
                AppLifecycleState.inactive,
                AppLifecycleState.resumed,
              ]) {
                tester.binding.handleAppLifecycleStateChanged(state);
              }
            } else {
              await pumpRollApp(tester, screen(const SizedBox.shrink()));
              await pumpRollApp(tester, screen(page));
            }
            await tester.pumpAndSettle();
            expect(find.text('DELETED'), findsNothing);
            expect(find.byType(Image), findsOneWidget);
            expect(calls, 2);
            if (resume && !galleryScreen) {
              missing = true;
              await tester.tap(find.byKey(const ValueKey('frame-1')));
              await tester.pumpAndSettle();
              expect(find.text('The photo cannot be shown.'), findsOneWidget);
              missing = false;
              for (final state in [
                AppLifecycleState.inactive,
                AppLifecycleState.hidden,
                AppLifecycleState.paused,
                AppLifecycleState.hidden,
                AppLifecycleState.inactive,
                AppLifecycleState.resumed,
              ]) {
                tester.binding.handleAppLifecycleStateChanged(state);
              }
              await tester.pumpAndSettle();
              expect(find.text('The photo cannot be shown.'), findsNothing);
              expect(find.byType(Image).hitTestable(), findsOneWidget);
            }
          },
        );
      }
    }

    Future<void> pumpSheet(
      WidgetTester tester, {
      ThemeMode mode = ThemeMode.light,
      FakeGalleryImages? images,
      FakePhotoLibrary? library,
    }) async {
      await pumpRollApp(
        tester,
        const RollScreen(id: '7'),
        mode: mode,
        overrides: [
          ...rollOverrides(
            rolls: [developed],
            shots: {7: shots},
            gallery: images ?? gallery(),
          ),
          if (library != null) photoLibraryProvider.overrideWithValue(library),
        ],
      );
      // The thumbnails answer a moment after the frames are built.
      await tester.pumpAndSettle();
    }

    testWidgets('shows the film, the frames and the day in the header', (
      tester,
    ) async {
      await pumpSheet(tester);
      expect(find.text('Roll 07'), findsOneWidget);
      expect(
        find.textContaining('Alpha · 6 frames · Developed on'),
        findsOneWidget,
      );
      expect(find.text('CONTACT SHEET'), findsOneWidget);
      expect(find.text('6 FRAMES'), findsOneWidget);
    });

    testWidgets('numbers every frame and asks for each thumbnail', (
      tester,
    ) async {
      final images = gallery();
      await pumpSheet(tester, images: images);
      for (var n = 1; n <= 6; n++) {
        expect(find.text('$n'), findsOneWidget);
      }
      expect(images.thumbnailsAsked, [
        'content://media/1',
        'content://media/2',
        'content://media/deleted',
        'content://media/6',
      ]);
      // Two strips of four frames: 4 and 2.
      expect(find.byType(ContactFrame), findsNWidgets(6));
    });

    testWidgets('a failed frame is empty, with its number and a label', (
      tester,
    ) async {
      await pumpSheet(tester);
      expect(find.text('FAILED'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Frame 3, could not be developed'),
        findsOneWidget,
      );
      // Nothing opens on a tap.
      await tester.tap(find.byKey(const ValueKey('frame-3')));
      await tester.pumpAndSettle();
      expect(find.byType(FrameViewer), findsNothing);
    });

    testWidgets('a photo deleted from the gallery is an empty frame', (
      tester,
    ) async {
      await pumpSheet(tester);
      // Frame 4 (the gallery has no such item) and frame 5 (no URI at all).
      expect(find.text('DELETED'), findsNWidgets(2));
      expect(
        find.bySemanticsLabel('Frame 5, no longer in the gallery'),
        findsOneWidget,
      );
    });

    testWidgets(
      'a missing native item stays missing across rebuilds and in the viewer',
      (tester) async {
        const channel = MethodChannel('carrete/media');
        final calls = <String>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call.method);
              throw PlatformException(code: 'not_found');
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null),
        );
        await pumpRollApp(
          tester,
          const RollScreen(id: '7'),
          overrides: [
            ...rollOverrides(
              rolls: [developed],
              shots: {
                7: [shots.first],
              },
              gallery: NativeGalleryImages(),
            ),
          ],
        );
        await tester.pumpAndSettle();
        expect(find.text('DELETED'), findsOneWidget);
        tester.element(find.byType(ContactSheet)).markNeedsBuild();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('frame-1')));
        await tester.pumpAndSettle();
        expect(find.text('The photo cannot be shown.'), findsOneWidget);
        expect(calls, ['loadThumbnail']);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('the strips are black with light perforations on paper', (
      tester,
    ) async {
      await pumpSheet(tester);
      bool hasColor(Color c) => find
          .byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color == c,
          )
          .evaluate()
          .isNotEmpty;
      expect(hasColor(CarreteSheetColors.light.strip), isTrue);
      expect(hasColor(CarreteSheetColors.light.sheet), isTrue);
      expect(hasColor(CarreteSheetColors.dark.strip), isFalse);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, CarretePalette.light.background);
    });

    testWidgets('in the dark theme it is a light table', (tester) async {
      await pumpSheet(tester, mode: ThemeMode.dark);
      bool hasColor(Color c) => find
          .byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color == c,
          )
          .evaluate()
          .isNotEmpty;
      expect(hasColor(CarreteSheetColors.dark.strip), isTrue);
      expect(hasColor(CarreteSheetColors.dark.sheet), isTrue);
      expect(hasColor(CarreteSheetColors.light.strip), isFalse);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, CarretePalette.dark.background);
      final number = tester.widget<Text>(find.text('1'));
      expect(number.style!.color, CarreteSheetColors.dark.edge);
    });

    testWidgets('opens a photo full size and swipes between photos', (
      tester,
    ) async {
      final images = gallery();
      await pumpSheet(tester, images: images);
      await tester.tap(find.byKey(const ValueKey('frame-2')));
      await tester.pumpAndSettle();
      expect(find.byType(FrameViewer), findsOneWidget);
      // Only the frames that have a photo are in the viewer: 1, 2, 4 and 6
      // (frame 3 failed and frame 5 has no photo at all).
      expect(find.text('2 of 4'), findsOneWidget);
      expect(images.fullsAsked, contains('content://media/2'));

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 2000);
      await tester.pumpAndSettle();
      expect(find.text('3 of 4'), findsOneWidget);
      // Frame 4 was deleted from the gallery meanwhile.
      expect(find.text('The photo cannot be shown.'), findsOneWidget);

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 2000);
      await tester.pumpAndSettle();
      expect(find.text('4 of 4'), findsOneWidget);
      expect(images.fullsAsked, contains('content://media/6'));

      await tester.fling(find.byType(PageView), const Offset(400, 0), 2000);
      await tester.pumpAndSettle();
      expect(find.text('3 of 4'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(FrameViewer), findsNothing);
      expect(find.text('CONTACT SHEET'), findsOneWidget);
    });

    testWidgets(
      'deleting the last photo tells on the sheet that its original stayed',
      (tester) async {
        final library = FakePhotoLibrary()
          ..deletion = PhotoDeletion.deletedKeptOriginal;
        await pumpSheet(tester, library: library);
        await tester.tap(find.byKey(const ValueKey('frame-1')));
        await tester.pumpAndSettle();
        // Four photos are in the viewer: delete them one after another.
        for (var i = 0; i < 4; i++) {
          await tester.tap(find.byKey(const ValueKey('viewer-delete')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Delete'));
          await tester.pumpAndSettle();
        }

        expect(find.byType(FrameViewer), findsNothing);
        expect(find.text('CONTACT SHEET'), findsOneWidget);
        expect(
          find.text(
            'Photo deleted, but its original is still in '
            'Pictures/Diapo/Originales.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('the viewer says so when a photo cannot be read', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        images: FakeGalleryImages({'content://media/1': tinyPng}),
      );
      // Frame 2 shows an empty frame in the sheet, but it still opens: the
      // gallery may answer by the time the user taps it.
      await tester.tap(find.byKey(const ValueKey('frame-2')));
      await tester.pumpAndSettle();
      expect(find.text('2 of 4'), findsOneWidget);
      expect(find.text('The photo cannot be shown.'), findsOneWidget);
    });

    testWidgets('a frame is at least 48 dp wide and tall to tap', (
      tester,
    ) async {
      await pumpSheet(tester);
      final size = tester.getSize(find.byKey(const ValueKey('frame-1')));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });
}
