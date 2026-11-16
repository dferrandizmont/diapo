import 'dart:async';

import 'package:carrete/core/database/app_database.dart';
import 'package:carrete/core/database/tables.dart';
import 'package:carrete/core/router.dart';
import 'package:carrete/platform/camera_sounds.dart';
import 'package:carrete/platform/haptics.dart';
import 'package:carrete/roll/roll_developer.dart';
import 'package:carrete/roll/roll_reveal.dart';
import 'package:carrete/screens/roll/roll_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/review_fakes.dart';
import '../../support/roll_fakes.dart';
import '../../support/roll_harness.dart';

class _Sounds extends CameraSounds {
  _Sounds() : super(supported: false);

  final List<String> played = <String>[];

  @override
  Future<void> playCartridge() async => played.add('cartridge');

  @override
  Future<void> playLoad() async => played.add('load');

  @override
  Future<void> playRewind() async => played.add('rewind');

  @override
  Future<void> playShot() async => played.add('shot');
}

class _Haptics extends Haptics {
  _Haptics() : super(enabled: () => true, ringerMode: () async => null);

  final List<String> played = <String>[];

  @override
  Future<void> lightImpact() async => played.add('light');

  @override
  Future<void> mediumImpact() async => played.add('medium');

  @override
  Future<void> selectionClick() async => played.add('selection');
}

final _developed = rollRow(
  state: RollState.developed,
  closedAt: 1000,
  developedAt: DateTime(2026, 11, 14, 9).millisecondsSinceEpoch,
);

List<ShotRow> _photos(int n) => [
  for (var i = 1; i <= n; i++) shotRow(i, galleryUri: 'content://media/$i'),
];

FakeGalleryImages _gallery(int n) => FakeGalleryImages({
  for (var i = 1; i <= n; i++) 'content://media/$i': tinyPng,
});

final _skip = find.byKey(const ValueKey('reveal-skip'));

/// The opacity of the frame [number] at this moment of the reveal.
double _opacity(WidgetTester tester, int number) {
  final fade = find.ancestor(
    of: find.byKey(ValueKey('frame-$number')),
    matching: find.byType(FadeTransition),
  );
  return tester.widget<FadeTransition>(fade.first).opacity.value;
}

void main() {
  late _Sounds sounds;
  late _Haptics haptics;
  late MemoryRollRevealStore store;

  setUp(() {
    sounds = _Sounds();
    haptics = _Haptics();
    store = MemoryRollRevealStore();
  });

  List<Override> overrides({
    RollRow? roll,
    List<ShotRow>? shots,
    Stream<List<ShotRow>>? shotsStream,
    Map<int, DevelopProgress> progress = const {},
    RollRevealStore? reveal,
    Stream<RollRow?>? rollStream,
    List<Override> review = const [],
  }) {
    final row = roll ?? _developed;
    return [
      ...rollOverrides(
        rolls: [row],
        shots: {row.id: shots ?? _photos(8)},
        shotsStream: shotsStream,
        progress: progress,
        gallery: _gallery(8),
        reveal: reveal ?? store,
        rollStream: rollStream,
      ),
      cameraSoundsProvider.overrideWithValue(sounds),
      hapticsProvider.overrideWithValue(haptics),
      ...review,
    ];
  }

  Future<void> pump(WidgetTester tester, List<Override> overrides) async {
    await pumpRollApp(tester, const RollScreen(id: '7'), overrides: overrides);
  }

  group('the notification', () {
    test('opens the screen of the roll that finished', () {
      // The route the tap of the notification goes to: the roll screen of
      // that roll, which shows its progress while it develops.
      expect(AppRoutes.rollOf('7'), '/roll/7');
      expect(AppRoutes.roll, '/roll/:id');
    });
  });

  group('while the roll develops', () {
    final developing = rollRow(
      state: RollState.developing,
      closedAt: 1000,
      developAt: 1000,
      length: 4,
    );

    ShotRow pending(int frame) => shotRow(frame);

    testWidgets('a thumbnail appears as each photo finishes saving', (
      tester,
    ) async {
      final shots = StreamController<List<ShotRow>>();
      addTearDown(() => unawaited(shots.close()));
      await pump(
        tester,
        overrides(
          roll: developing,
          shotsStream: shots.stream,
          progress: {7: progress(0, 4)},
        ),
      );
      shots.add([for (var i = 1; i <= 4; i++) pending(i)]);
      await tester.pumpAndSettle();
      // All four frames are there and waiting: no photo, no "missing" label.
      for (var i = 1; i <= 4; i++) {
        expect(find.bySemanticsLabel('Frame $i, developing'), findsOneWidget);
      }
      expect(find.text('DELETED'), findsNothing);
      expect(find.byType(Image), findsNothing);

      // The first two photos are saved: they show at once, the rest wait.
      shots.add([
        shotRow(1, galleryUri: 'content://media/1'),
        shotRow(2, galleryUri: 'content://media/2'),
        pending(3),
        pending(4),
      ]);
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNWidgets(2));
      expect(find.bySemanticsLabel('Frame 1'), findsOneWidget);
      expect(find.bySemanticsLabel('Frame 3, developing'), findsOneWidget);

      shots.add([
        for (var i = 1; i <= 4; i++)
          shotRow(i, galleryUri: 'content://media/$i'),
      ]);
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNWidgets(4));
      expect(find.bySemanticsLabel('Frame 4, developing'), findsNothing);
    });

    testWidgets('keeps the counter and the cells until the frames are known', (
      tester,
    ) async {
      await pump(
        tester,
        overrides(
          roll: developing,
          shots: const [],
          progress: {7: progress(1, 4)},
        ),
      );
      expect(find.bySemanticsLabel('1 of 4 frames developed'), findsOneWidget);
      expect(find.byKey(const ValueKey('develop-cell-3')), findsOneWidget);
    });

    testWidgets('a frame that failed says so, not "developing"', (
      tester,
    ) async {
      await pump(
        tester,
        overrides(
          roll: developing,
          shots: [
            shotRow(1, failure: 'corrupted'),
            pending(2),
          ],
          progress: {7: progress(1, 2)},
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Frame 1, could not be developed'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Frame 2, developing'), findsOneWidget);
    });
  });

  group('the request for a review', () {
    late CountingStoreReview storeReview;
    late List<Override> review;

    setUp(() async {
      storeReview = CountingStoreReview();
      review = await reviewReadyOverrides(storeReview);
    });

    testWidgets('once, when the first reveal ends, not while it runs', (
      tester,
    ) async {
      await pump(tester, overrides(review: review));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await flushReview(tester);
      expect(_skip, findsOneWidget, reason: 'the animation is running');
      expect(storeReview.requests, 0);

      await tester.pump(const Duration(milliseconds: 1500));
      await flushReview(tester);
      expect(_skip, findsNothing);
      expect(storeReview.requests, 1);

      // Nothing more with time.
      await tester.pump(const Duration(seconds: 5));
      await flushReview(tester);
      expect(storeReview.requests, 1);
    });

    testWidgets('a skip asks once, and the end of the clock does not again', (
      tester,
    ) async {
      await pump(tester, overrides(review: review));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(storeReview.requests, 0);

      await tester.tap(_skip);
      await tester.pump();
      await flushReview(tester);
      expect(storeReview.requests, 1);
      await tester.pump(const Duration(seconds: 3));
      await flushReview(tester);
      expect(storeReview.requests, 1);
    });

    testWidgets('only on the first reveal: a roll already seen never asks', (
      tester,
    ) async {
      await pump(
        tester,
        overrides(reveal: MemoryRollRevealStore(allSeen: true), review: review),
      );
      await tester.pump(const Duration(seconds: 3));
      await flushReview(tester);
      expect(storeReview.requests, 0);

      // The first reveal of a roll that was not seen: it asks.
      await tester.pumpWidget(const SizedBox.shrink());
      await pump(tester, overrides(review: review));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await flushReview(tester);
      expect(storeReview.requests, 1);

      // Opened again, the roll is seen now. Even with counters that would
      // allow it (fresh ones), the screen does not ask.
      final fresh = CountingStoreReview();
      await tester.pumpWidget(const SizedBox.shrink());
      await pump(tester, overrides(review: await reviewReadyOverrides(fresh)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await flushReview(tester);
      expect(fresh.requests, 0);
    });

    testWidgets('nothing happens after the screen is closed mid-reveal', (
      tester,
    ) async {
      await pump(tester, overrides(review: review));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
      await flushReview(tester);
      expect(storeReview.requests, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a reveal with reduced motion asks once, at once', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pump(tester, overrides(review: review));
      await flushReview(tester);
      expect(storeReview.requests, 1);
    });
  });

  group('the reveal of a developed roll', () {
    testWidgets('the first time, the frames come in one after another', (
      tester,
    ) async {
      await pump(tester, overrides());
      expect(store.marked, {7});
      expect(_skip, findsOneWidget);
      // Nothing is drawn at the start; the last frame comes in last.
      expect(_opacity(tester, 8), 0);
      // The first frame of the animation only starts its clock.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final first = _opacity(tester, 1);
      final last = _opacity(tester, 8);
      expect(first, greaterThan(0));
      expect(last, lessThan(first));

      // It is over in about a second and a half.
      await tester.pump(const Duration(milliseconds: 1200));
      expect(_skip, findsNothing);
      for (var i = 1; i <= 8; i++) {
        expect(_opacity(tester, i), 1, reason: 'frame $i');
      }
    });

    testWidgets('one tap skips it and shows every frame', (tester) async {
      await pump(tester, overrides());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(_opacity(tester, 8), lessThan(1));

      await tester.tap(_skip);
      await tester.pump();
      expect(_skip, findsNothing);
      for (var i = 1; i <= 8; i++) {
        expect(_opacity(tester, i), 1, reason: 'frame $i');
      }
      // Nothing was opened by the tap.
      expect(find.text('Photo'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('only once: a roll that was revealed shows at once', (
      tester,
    ) async {
      await pump(tester, overrides());
      await tester.pump(const Duration(seconds: 2));
      expect(sounds.played, ['cartridge']);

      // Open the same roll again with the same memory.
      await tester.pumpWidget(const SizedBox.shrink());
      await pump(tester, overrides());
      expect(_skip, findsNothing);
      expect(_opacity(tester, 8), 1);
      // No second sound or tap.
      expect(sounds.played, ['cartridge']);
      expect(haptics.played, ['light']);
    });

    testWidgets('a roll marked as seen is never revealed', (tester) async {
      await pump(
        tester,
        overrides(reveal: MemoryRollRevealStore(allSeen: true)),
      );
      expect(_skip, findsNothing);
      expect(sounds.played, isEmpty);
      expect(haptics.played, isEmpty);
    });

    testWidgets('plays one quiet sound and one light tap, not one per frame', (
      tester,
    ) async {
      await pump(tester, overrides());
      await tester.pump(const Duration(seconds: 2));
      expect(sounds.played, ['cartridge']);
      expect(haptics.played, ['light']);
    });

    testWidgets('with reduced motion everything shows at once', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pump(tester, overrides());
      expect(_skip, findsNothing);
      final frame = find.byKey(const ValueKey('frame-8'));
      expect(frame, findsOneWidget);
      final above = find
          .ancestor(of: frame, matching: find.byType(FadeTransition))
          .evaluate()
          .length;
      // The frame is in no reveal: the same transitions are above it (the one
      // of the page) as when the roll was already seen.
      await tester.pumpWidget(const SizedBox.shrink());
      await pump(
        tester,
        overrides(reveal: MemoryRollRevealStore(allSeen: true)),
      );
      expect(
        find
            .ancestor(of: frame, matching: find.byType(FadeTransition))
            .evaluate()
            .length,
        above,
      );
      // It still counts as seen, and still tells that it is ready.
      expect(store.marked, {7});
      expect(sounds.played, ['cartridge']);
    });

    testWidgets('a roll watched while it develops is not revealed again', (
      tester,
    ) async {
      final rolls = StreamController<RollRow?>();
      addTearDown(() => unawaited(rolls.close()));
      final developing = rollRow(
        state: RollState.developing,
        closedAt: 1000,
        developAt: 1000,
        length: 8,
      );
      await pump(
        tester,
        overrides(
          roll: developing,
          progress: {7: progress(8, 8)},
          rollStream: rolls.stream,
        ),
      );
      rolls.add(developing);
      await tester.pumpAndSettle();
      expect(find.text('Developing'), findsOneWidget);

      rolls.add(_developed);
      await tester.pumpAndSettle();
      expect(find.text('Developing'), findsNothing);
      // The frames were there while it developed: nothing comes in again.
      expect(_skip, findsNothing);
      expect(_opacity(tester, 8), 1);
      // The roll is ready: one sound and one tap, and it is remembered.
      expect(sounds.played, ['cartridge']);
      expect(haptics.played, ['light']);
      expect(store.marked, {7});
    });

    testWidgets('the remembered rolls survive a restart', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final first = PreferencesRollRevealStore(preferences);
      expect(first.seen(7), isFalse);
      await first.markSeen(7);
      await first.markSeen(9);
      final second = PreferencesRollRevealStore(preferences);
      expect(second.seen(7), isTrue);
      expect(second.seen(9), isTrue);
      expect(second.seen(8), isFalse);
    });

    testWidgets('does not forget an old roll however many came after', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final existing = <int>{for (var id = 1; id <= 700; id++) id};
      final store = PreferencesRollRevealStore(
        preferences,
        existingRollIds: () async => existing,
      );
      for (final id in existing) {
        await store.markSeen(id);
      }
      // The oldest roll is opened again after hundreds of others.
      expect(store.seen(1), isTrue);
      expect(store.seen(700), isTrue);
      expect(
        preferences.getStringList(PreferencesRollRevealStore.storageKey),
        hasLength(700),
      );
    });

    testWidgets('drops the rolls that no longer exist, and only those', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      var existing = <int>{1, 2, 3};
      final store = PreferencesRollRevealStore(
        preferences,
        existingRollIds: () async => existing,
      );
      for (final id in existing) {
        await store.markSeen(id);
      }
      // Roll 2 is gone; marking roll 4 prunes the set.
      existing = {1, 3, 4};
      await store.markSeen(4);
      expect(store.seen(1), isTrue);
      expect(store.seen(2), isFalse);
      expect(store.seen(3), isTrue);
      expect(store.seen(4), isTrue);
      expect(preferences.getStringList(PreferencesRollRevealStore.storageKey), [
        '1',
        '3',
        '4',
      ]);
    });

    testWidgets('keeps what it has when the rolls cannot be listed', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final store = PreferencesRollRevealStore(
        preferences,
        existingRollIds: () async => throw StateError('closed'),
      );
      await store.markSeen(1);
      await store.markSeen(2);
      expect(store.seen(1), isTrue);
      expect(store.seen(2), isTrue);
    });

    testWidgets('two reveals at once do not lose one of the rolls', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      // The list of the rolls takes a while: both reveals wait for it.
      final gate = Completer<void>();
      final store = PreferencesRollRevealStore(
        preferences,
        existingRollIds: () async {
          await gate.future;
          return {1, 2};
        },
      );

      final first = store.markSeen(1);
      final second = store.markSeen(2);
      gate.complete();
      await first;
      await second;

      expect(store.seen(1), isTrue);
      expect(store.seen(2), isTrue);
      expect(
        preferences
            .getStringList(PreferencesRollRevealStore.storageKey)
            ?.toSet(),
        {'1', '2'},
      );
    });
  });
}
