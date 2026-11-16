import 'package:diapo/core/database/app_database.dart';
import 'package:diapo/core/database/tables.dart';
import 'package:diapo/screens/roll/roll_sheet.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/roll_fakes.dart';
import '../../support/roll_harness.dart';

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

RollRow _paused({DevelopDelay delay = DevelopDelay.nextMorning}) =>
    rollRow(mode: RollMode.disposable, length: 27, delay: delay);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

final _resume = find.byKey(const ValueKey('disposable-resume-key'));
final _finish = find.byKey(const ValueKey('disposable-finish-key'));
final _discard = find.byKey(const ValueKey('disposable-discard-key'));

void main() {
  group('a paused disposable', () {
    testWidgets('has two main actions and the discard apart', (tester) async {
      await _open(
        tester,
        overrides: rollOverrides(active: _paused(), framesLeft: 14),
      );
      expect(_resume, findsOneWidget);
      expect(_finish, findsOneWidget);
      expect(find.text('Back to the disposable camera'), findsOneWidget);
      expect(find.text('Finish roll'), findsOneWidget);
      // The discard is a text button under the note, not a key.
      expect(_discard, findsOneWidget);
      expect(
        find.descendant(of: _discard, matching: find.byType(TextButton)),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(_discard).dy,
        greaterThan(tester.getTopLeft(_finish).dy),
      );
      // The repeated wording is gone: there is no separate close and develop.
      expect(find.text('Close roll'), findsNothing);
      expect(find.text('Develop now'), findsNothing);
    });

    testWidgets('going back puts the disposable in the camera', (tester) async {
      final results = await _open(
        tester,
        overrides: rollOverrides(active: _paused(), framesLeft: 14),
      );
      await _tap(tester, _resume);
      expect((results.single! as ResumeDisposableIntent).rollId, 7);
    });

    testWidgets('throwing it away asks first', (tester) async {
      final results = await _open(
        tester,
        overrides: rollOverrides(active: _paused(), framesLeft: 14),
      );
      await _tap(tester, _discard);
      expect(find.text('Throw away the roll?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(results, isEmpty);

      await _tap(tester, _discard);
      await tester.tap(find.text('Throw away'));
      await tester.pumpAndSettle();
      expect((results.single! as DiscardRollIntent).rollId, 7);
    });

    testWidgets('keys and the text action are at least 48 dp tall', (
      tester,
    ) async {
      await _open(
        tester,
        overrides: rollOverrides(active: _paused(), framesLeft: 14),
      );
      for (final finder in [_resume, _finish, _discard]) {
        await tester.ensureVisible(finder);
        expect(tester.getSize(finder).height, greaterThanOrEqualTo(48));
      }
    });
  });

  group('finishing with an instant wait', () {
    final roll = _paused(delay: DevelopDelay.instant);

    testWidgets('offers one develop action and no scheduled choice', (
      tester,
    ) async {
      final results = await _open(
        tester,
        overrides: rollOverrides(active: roll, framesLeft: 14),
      );
      await _tap(tester, _finish);
      expect(
        find.text('This disposable develops right away once you finish it.'),
        findsOneWidget,
      );
      expect(find.text('Keep the wait'), findsNothing);
      // The main keys give way to the step.
      expect(_resume, findsNothing);
      expect(find.text('Develop now'), findsOneWidget);

      await _tap(tester, find.byKey(const ValueKey('disposable-develop-key')));
      // Closing a roll with an instant wait develops it right away.
      expect((results.single! as CloseRollIntent).rollId, 7);
    });

    testWidgets('cancel goes back to the two main actions', (tester) async {
      final results = await _open(
        tester,
        overrides: rollOverrides(active: roll, framesLeft: 14),
      );
      await _tap(tester, _finish);
      await _tap(
        tester,
        find.byKey(const ValueKey('disposable-finish-cancel')),
      );
      expect(_resume, findsOneWidget);
      expect(_finish, findsOneWidget);
      expect(results, isEmpty);
    });
  });

  group('finishing with a delayed wait', () {
    final roll = _paused();

    testWidgets('shows the scheduled time and the two choices', (tester) async {
      await _open(
        tester,
        overrides: rollOverrides(
          active: roll,
          framesLeft: 14,
          now: DateTime(2026, 11, 13, 21),
        ),
      );
      await _tap(tester, _finish);
      // Next morning at 08:00, the day after.
      final when = tester.widget<Text>(
        find.byKey(const ValueKey('disposable-finish-when')),
      );
      expect(when.data, contains('You can develop from'));
      expect(when.data, contains('Sat, Nov 14'));
      expect(when.data, contains('8:00'));
      expect(find.text('Keep the wait'), findsOneWidget);
      expect(find.text('Develop now'), findsOneWidget);
    });

    testWidgets('keeping the wait closes the roll', (tester) async {
      final results = await _open(
        tester,
        overrides: rollOverrides(active: roll, framesLeft: 14),
      );
      await _tap(tester, _finish);
      await _tap(tester, find.byKey(const ValueKey('disposable-keep-key')));
      expect((results.single! as CloseRollIntent).rollId, 7);
    });

    testWidgets('developing now asks first and says how many photos', (
      tester,
    ) async {
      final results = await _open(
        tester,
        overrides: rollOverrides(active: roll, framesLeft: 17),
      );
      await _tap(tester, _finish);
      await _tap(tester, find.byKey(const ValueKey('disposable-develop-key')));
      expect(find.text('Develop now?'), findsOneWidget);
      expect(
        find.textContaining(
          'The 10 photos on this roll will be developed now.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Keep waiting'));
      await tester.pumpAndSettle();
      expect(results, isEmpty);

      await _tap(tester, find.byKey(const ValueKey('disposable-develop-key')));
      await tester.tap(find.text('Develop now').last);
      await tester.pumpAndSettle();
      expect((results.single! as DevelopRollNowIntent).rollId, 7);
    });
  });

  testWidgets('a normal roll keeps its three actions', (tester) async {
    await _open(tester, overrides: rollOverrides(active: rollRow()));
    for (final label in ['Close roll', 'Develop now', 'Throw away the roll']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Finish roll'), findsNothing);
  });

  testWidgets('the paused sheet scrolls at 2x on a small phone', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _open(
      tester,
      overrides: rollOverrides(active: _paused(), framesLeft: 14),
      size: const Size(320, 568),
    );
    expect(tester.takeException(), isNull);
    for (final target in [_resume, _finish, _discard]) {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      expect(tester.getRect(target).bottom, lessThanOrEqualTo(568.5));
    }
    await _tap(tester, _finish);
    expect(tester.takeException(), isNull);
  });
}
