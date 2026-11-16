import 'dart:async';

import 'package:diapo/core/database/tables.dart';
import 'package:diapo/screens/roll/roll_sheet.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/roll_fakes.dart';
import '../../support/roll_harness.dart';

/// Opens the sheet from a button and keeps what it popped with.
class _Opener extends StatelessWidget {
  const _Opener({required this.film, required this.onResult});

  final Recipe film;
  final ValueChanged<RollSheetIntent?> onResult;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () async =>
            onResult(await showRollSheet(context, loadFilm: film)),
        child: const Text('open'),
      ),
    ),
  );
}

Future<List<RollSheetIntent?>> _open(
  WidgetTester tester, {
  required List<Override> overrides,
  Size size = const Size(412, 915),
}) async {
  final results = <RollSheetIntent?>[];
  await pumpRollApp(
    tester,
    _Opener(film: testBook().recipes[1], onResult: results.add),
    overrides: overrides,
    mode: ThemeMode.dark,
    size: size,
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

final _loadKey = find.text('Load roll');

void main() {
  group('with no roll loaded', () {
    testWidgets('offers the lengths, the delays and the film', (tester) async {
      await _open(tester, overrides: rollOverrides());
      expect(find.text('Load a roll'), findsWidgets);
      // The film of the carousel.
      expect(find.text('Beta'), findsOneWidget);
      for (final n in ['12', '24', '36']) {
        expect(find.text(n), findsOneWidget);
      }
      for (final d in ['Now', '1 hour', 'Next morning', '3 days']) {
        expect(find.text(d), findsOneWidget);
      }
      expect(find.text('Load roll'), findsOneWidget);
      expect(
        find.textContaining('you will not see your photos'),
        findsOneWidget,
      );
    });

    testWidgets('explains the roll in one line and when the wait starts', (
      tester,
    ) async {
      await _open(tester, overrides: rollOverrides());
      expect(
        find.text(
          'One film for the whole roll. The photos stay hidden until you '
          'develop it.',
        ),
        findsOneWidget,
      );
      // The film, the length and the wait are together in the sheet.
      expect(find.text('Film'), findsOneWidget);
      expect(find.text('Wait to develop'), findsOneWidget);
      expect(
        find.text('The wait starts when you close the roll.'),
        findsOneWidget,
      );
    });

    testWidgets('offers the disposable camera as the secondary option', (
      tester,
    ) async {
      final results = await _open(tester, overrides: rollOverrides());
      final option = find.byKey(const ValueKey('disposable-key'));
      expect(option, findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Disposable camera · 27 photos to share the camera',
        ),
        findsOneWidget,
      );
      // Under the key that loads a roll, not above it.
      expect(
        tester.getTopLeft(option).dy,
        greaterThan(tester.getTopLeft(find.text('Load roll')).dy),
      );
      expect(results, isEmpty);
    });

    testWidgets('warns that undeveloped photos are lost on uninstall', (
      tester,
    ) async {
      await _open(tester, overrides: rollOverrides());
      expect(
        find.text(
          'The photos of a roll you have not developed exist only on this '
          'phone. If you uninstall the app, clear its data or move to '
          'another phone, they are lost.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('keeps the load key reachable on a small phone with big text', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _open(
        tester,
        overrides: rollOverrides(),
        size: const Size(360, 640),
      );
      final key = find.text('Load roll');
      await tester.ensureVisible(key);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(key).bottom, lessThanOrEqualTo(640));
      expect(find.textContaining('they are lost'), findsOneWidget);
    });

    testWidgets('loads a roll of 24 frames, 1 hour, by default', (
      tester,
    ) async {
      final results = await _open(tester, overrides: rollOverrides());
      await tester.tap(find.text('Load roll'));
      await tester.pumpAndSettle();
      final intent = results.single as LoadRollIntent;
      expect(intent.length, 24);
      expect(intent.delay, DevelopDelay.oneHour);
    });

    testWidgets('loads the length and the delay that were picked', (
      tester,
    ) async {
      final results = await _open(tester, overrides: rollOverrides());
      await tester.tap(find.text('36'));
      await tester.pump();
      await tester.tap(find.text('Next morning'));
      await tester.pump();
      await tester.tap(find.text('Load roll'));
      await tester.pumpAndSettle();
      final intent = results.single as LoadRollIntent;
      expect(intent.length, 36);
      expect(intent.delay, DevelopDelay.nextMorning);
    });

    testWidgets('the close key dismisses it with no intent', (tester) async {
      final results = await _open(tester, overrides: rollOverrides());
      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();
      expect(results, [null]);
      expect(find.text('Load roll'), findsNothing);
    });

    testWidgets('lists the last five rolls that wait, are developed or lost', (
      tester,
    ) async {
      final rolls = [
        rollRow(
          id: 9,
          state: RollState.developing,
          closedAt: 5000,
          developAt: DateTime(2026, 11, 14).millisecondsSinceEpoch,
        ),
        rollRow(id: 8),
        rollRow(
          id: 7,
          state: RollState.developed,
          filmId: 'beta',
          length: 12,
          developedAt: DateTime(2026, 11, 10).millisecondsSinceEpoch,
        ),
        rollRow(id: 6, state: RollState.discarded),
        for (var id = 5; id >= 1; id--) rollRow(id: id, state: RollState.lost),
      ];
      final results = await _open(
        tester,
        overrides: rollOverrides(
          rolls: rolls,
          shots: {
            7: [for (var i = 1; i <= 10; i++) shotRow(i)],
          },
        ),
      );
      expect(find.text('RECENT ROLLS'), findsOneWidget);
      // Waiting, developed and the three newest lost rolls: five rows. The
      // open and the discarded rolls are not listed.
      expect(find.text('Waiting'), findsOneWidget);
      expect(find.text('Developed'), findsOneWidget);
      expect(find.text('Lost'), findsNWidgets(3));
      // The developed roll counts the frames it holds, not its length.
      expect(find.textContaining('10 frames'), findsOneWidget);

      await tester.tap(find.text('Waiting'));
      await tester.pumpAndSettle();
      expect((results.single as OpenRollIntent).rollId, 9);
    });
  });

  group('with a roll loaded', () {
    final roll = rollRow(delay: DevelopDelay.nextMorning);

    testWidgets('says how many frames are left and what the roll is', (
      tester,
    ) async {
      await _open(
        tester,
        overrides: rollOverrides(active: roll, framesLeft: 9),
      );
      expect(find.text('Roll in the camera'), findsWidgets);
      expect(find.text('9 frames left'), findsOneWidget);
      expect(find.text('Alpha · 24 frames'), findsOneWidget);
      expect(find.text('Wait to develop: next morning'), findsOneWidget);
      // A short reminder of where the undeveloped photos live.
      expect(find.byKey(const ValueKey('roll-loss-note')), findsOneWidget);
      expect(
        find.text(
          'They exist only on this phone: they are lost if you uninstall, '
          'clear the data or change phone.',
        ),
        findsOneWidget,
      );
      // The form and the list of rolls are not here.
      expect(find.text('Load roll'), findsNothing);
      expect(find.text('RECENT ROLLS'), findsNothing);
    });

    testWidgets('closes the roll', (tester) async {
      final results = await _open(
        tester,
        overrides: rollOverrides(active: roll),
      );
      await tester.tap(find.text('Close roll'));
      await tester.pumpAndSettle();
      expect((results.single as CloseRollIntent).rollId, 7);
    });

    testWidgets('warns before developing early, and can keep waiting', (
      tester,
    ) async {
      final results = await _open(
        tester,
        overrides: rollOverrides(active: roll),
      );
      await tester.tap(find.text('Develop now'));
      await tester.pumpAndSettle();
      expect(find.text('Develop now?'), findsOneWidget);
      // It says what happens, with no guilt: how many photos and that the
      // wait ends now.
      expect(
        find.textContaining('The wait ends now and this cannot be undone.'),
        findsOneWidget,
      );
      expect(find.textContaining('This roll has no photos.'), findsOneWidget);
      expect(find.textContaining('is part of the fun'), findsNothing);
      await tester.tap(find.text('Keep waiting'));
      await tester.pumpAndSettle();
      // Back in the sheet, nothing was chosen.
      expect(results, isEmpty);
      expect(find.text('Close roll'), findsOneWidget);
    });

    testWidgets('the warning says how many photos are developed now', (
      tester,
    ) async {
      await _open(
        tester,
        overrides: rollOverrides(active: roll, framesLeft: 9),
      );
      await tester.tap(find.text('Develop now'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'The 15 photos on this roll will be developed now.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('does not guess how many photos there are before it knows', (
      tester,
    ) async {
      final frames = StreamController<int>();
      addTearDown(() => unawaited(frames.close()));
      await _open(
        tester,
        overrides: rollOverrides(active: roll, framesStream: frames.stream),
      );
      // The count has not arrived: no frames left are claimed and the roll
      // cannot be developed now.
      expect(find.textContaining('frames left'), findsNothing);
      await tester.tap(find.text('Develop now'));
      await tester.pumpAndSettle();
      expect(find.text('Develop now?'), findsNothing);

      frames.add(9);
      await tester.pumpAndSettle();
      expect(find.text('9 frames left'), findsOneWidget);
      await tester.tap(find.text('Develop now'));
      await tester.pumpAndSettle();
      expect(find.text('Develop now?'), findsOneWidget);
      expect(
        find.textContaining(
          'The 15 photos on this roll will be developed now.',
        ),
        findsOneWidget,
      );
    });

    for (final (left, text) in [
      (24, 'This roll has no photos.'),
      (23, 'The photo on this roll will be developed now.'),
      (14, 'The 10 photos on this roll will be developed now.'),
      (0, 'The 24 photos on this roll will be developed now.'),
    ]) {
      testWidgets('says the real count of a roll with $left frames left', (
        tester,
      ) async {
        await _open(
          tester,
          overrides: rollOverrides(active: roll, framesLeft: left),
        );
        await tester.tap(find.text('Develop now'));
        await tester.pumpAndSettle();
        expect(find.textContaining(text), findsOneWidget);
      });
    }

    testWidgets('the disposable row is tinted while it is pressed', (
      tester,
    ) async {
      await _open(tester, overrides: rollOverrides());
      final row = find.byKey(const ValueKey('disposable-key'));
      Color? tint() =>
          (tester
                      .widget<AnimatedContainer>(
                        find.descendant(
                          of: row,
                          matching: find.byKey(
                            const ValueKey('secondary-option-surface'),
                          ),
                        ),
                      )
                      .decoration!
                  as BoxDecoration)
              .color;
      expect(tint(), Colors.transparent);
      final press = await tester.startGesture(tester.getCenter(row));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tint(), isNot(Colors.transparent));
      await press.up();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tint(), Colors.transparent);
    });

    testWidgets('the load sheet scrolls at 2x on a small phone, with every '
        'note', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _open(
        tester,
        overrides: rollOverrides(),
        size: const Size(320, 568),
      );
      expect(tester.takeException(), isNull);
      final scroll = find.descendant(
        of: find.byType(RollSheet),
        matching: find.byType(SingleChildScrollView),
      );
      expect(scroll, findsOneWidget);
      // Everything can be reached by scrolling: the key and the last row.
      for (final target in [
        find.byKey(const ValueKey('roll-sheet-intro')),
        find.byKey(const ValueKey('roll-delay-note')),
        _loadKey,
        find.byKey(const ValueKey('roll-loss-warning')),
        find.byKey(const ValueKey('disposable-key')),
      ]) {
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        final rect = tester.getRect(target);
        expect(rect.top, greaterThanOrEqualTo(-0.5), reason: '$target');
        // A note taller than the screen starts at the top of the sheet; the rest
        // fit whole.
        if (rect.height < 500) {
          expect(rect.bottom, lessThanOrEqualTo(568.5), reason: '$target');
        } else {
          expect(rect.top, lessThan(568), reason: '$target');
        }
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('develops early once the warning is accepted', (tester) async {
      final results = await _open(
        tester,
        overrides: rollOverrides(active: roll),
      );
      await tester.tap(find.text('Develop now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Develop now').last);
      await tester.pumpAndSettle();
      expect((results.single as DevelopRollNowIntent).rollId, 7);
    });

    testWidgets('asks before throwing the roll away', (tester) async {
      final results = await _open(
        tester,
        overrides: rollOverrides(active: roll),
      );
      await tester.tap(find.text('Throw away the roll'));
      await tester.pumpAndSettle();
      expect(find.text('Throw away the roll?'), findsOneWidget);
      expect(find.textContaining('There is no undo'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(results, isEmpty);

      await tester.tap(find.text('Throw away the roll'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Throw away'));
      await tester.pumpAndSettle();
      expect((results.single as DiscardRollIntent).rollId, 7);
    });

    testWidgets('the keys are at least 48 dp tall', (tester) async {
      await _open(tester, overrides: rollOverrides(active: roll));
      for (final label in [
        'Close roll',
        'Develop now',
        'Throw away the roll',
      ]) {
        final key = find.ancestor(
          of: find.text(label),
          matching: find.byType(SizedBox),
        );
        final tall = key.evaluate().any(
          (e) => tester.getSize(find.byWidget(e.widget)).height >= 48,
        );
        expect(tall, isTrue, reason: label);
      }
    });
  });
}
