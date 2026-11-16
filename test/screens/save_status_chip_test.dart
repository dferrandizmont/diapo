import 'package:diapo/capture/save_status.dart';
import 'package:diapo/l10n/app_localizations.dart';
import 'package:diapo/screens/viewfinder/save_status_chip.dart';
import 'package:diapo/ui/theme/carrete_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A status the test moves by hand, and a retry it only counts.
class _FakeStatus extends SaveStatusController {
  _FakeStatus(this.initial);

  final SaveStatus initial;
  int retries = 0;

  @override
  SaveStatus build() => initial;

  @override
  Future<void> retry() async => retries++;

  void set(SaveStatus status) => state = status;
}

Future<_FakeStatus> _pump(
  WidgetTester tester,
  SaveStatus initial, {
  Brightness brightness = Brightness.dark,
  double textScale = 1,
  bool reduced = false,
  Size size = const Size(412, 915),
}) async {
  final fake = _FakeStatus(initial);
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [saveStatusProvider.overrideWith(() => fake)],
      child: MaterialApp(
        locale: const Locale('en'),
        theme: ThemeData(brightness: brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduced,
          ),
          child: child!,
        ),
        home: const Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: CarreteSpacing.margin,
                top: 100,
                child: SaveStatusStrip(),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return fake;
}

final _saving = find.byKey(const ValueKey('save-status-saving'));
final _pending = find.byKey(const ValueKey('save-status-pending'));

void main() {
  group('while saving', () {
    testWidgets('says nothing at first, then "Saving 2 photos"', (
      tester,
    ) async {
      await _pump(tester, const SaveStatus(saving: 2));
      expect(_saving, findsNothing);
      await tester.pump(const Duration(milliseconds: 399));
      expect(_saving, findsNothing);
      await tester.pump(const Duration(milliseconds: 2));
      await tester.pump(CarreteSaveStatus.fade);
      expect(_saving, findsOneWidget);
      expect(find.text('Saving 2 photos'), findsOneWidget);
      expect(find.byKey(const ValueKey('save-status-mark')), findsOneWidget);
    });

    testWidgets('a single fast save never shows', (tester) async {
      final fake = await _pump(tester, const SaveStatus());
      fake.set(const SaveStatus(saving: 1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_saving, findsNothing);
      fake.set(const SaveStatus());
      await tester.pump(const Duration(seconds: 1));
      expect(_saving, findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('follows the count and goes away when it is done', (
      tester,
    ) async {
      final fake = await _pump(tester, const SaveStatus(saving: 1));
      await tester.pump(CarreteSaveStatus.showDelay);
      await tester.pump(CarreteSaveStatus.fade);
      expect(find.text('Saving 1 photo'), findsOneWidget);
      fake.set(const SaveStatus(saving: 3));
      await tester.pump(CarreteSaveStatus.fade);
      expect(find.text('Saving 3 photos'), findsOneWidget);
      fake.set(const SaveStatus());
      await tester.pumpAndSettle();
      expect(_saving, findsNothing);
    });

    testWidgets('a retry counts as saving the photos that wait', (
      tester,
    ) async {
      await _pump(tester, const SaveStatus(failed: 2, retrying: true));
      await tester.pump(CarreteSaveStatus.showDelay);
      await tester.pump(CarreteSaveStatus.fade);
      expect(find.text('Saving 2 photos'), findsOneWidget);
      expect(_pending, findsNothing);
    });

    testWidgets('the mark turns, and stands still with reduced motion', (
      tester,
    ) async {
      await _pump(tester, const SaveStatus(saving: 1));
      await tester.pump(CarreteSaveStatus.showDelay);
      await tester.pump(CarreteSaveStatus.fade);
      var mark = tester.widget<CircularProgressIndicator>(
        find.byKey(const ValueKey('save-status-mark')),
      );
      expect(mark.value, isNull, reason: 'indeterminate: it turns');

      await _pump(tester, const SaveStatus(saving: 1), reduced: true);
      await tester.pump(CarreteSaveStatus.showDelay);
      mark = tester.widget<CircularProgressIndicator>(
        find.byKey(const ValueKey('save-status-mark')),
      );
      expect(mark.value, isNotNull, reason: 'a still arc');
      // Reduced motion shows it at once, without fading.
      expect(_saving, findsOneWidget);
    });
  });

  group('photos that wait', () {
    testWidgets('the chip stays while there are failures', (tester) async {
      await _pump(tester, const SaveStatus(failed: 2));
      expect(_pending, findsOneWidget);
      expect(find.text('Some photos are waiting to be saved'), findsOneWidget);
      await tester.pump(const Duration(minutes: 5));
      expect(_pending, findsOneWidget, reason: 'it does not disappear');
    });

    testWidgets('draws nothing and takes no room when all is saved', (
      tester,
    ) async {
      await _pump(tester, const SaveStatus());
      expect(_pending, findsNothing);
      expect(_saving, findsNothing);
      expect(tester.getSize(find.byType(SaveStatusStrip)), Size.zero);
    });

    testWidgets('the chip goes away once the failures are saved', (
      tester,
    ) async {
      final fake = await _pump(tester, const SaveStatus(failed: 1));
      expect(_pending, findsOneWidget);
      fake.set(const SaveStatus());
      await tester.pumpAndSettle();
      expect(_pending, findsNothing);
    });

    testWidgets('keeps the 44 px touch target', (tester) async {
      await _pump(tester, const SaveStatus(failed: 1));
      final chip = tester.getRect(_pending);
      expect(chip.height, greaterThanOrEqualTo(CarreteSpacing.minTouch));
      // The whole target takes the tap, not only the small pill.
      await tester.tapAt(Offset(chip.left + 4, chip.top + 2));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('save-sheet-retry')), findsOneWidget);
    });

    testWidgets('is a button for a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const SaveStatus(failed: 1));
      expect(
        tester.getSemantics(_pending),
        matchesSemantics(
          label: 'Some photos are waiting to be saved',
          isButton: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('the sheet', () {
    Future<void> open(WidgetTester tester) async {
      await tester.tap(_pending);
      await tester.pumpAndSettle();
    }

    testWidgets('says what happened when the storage is full', (tester) async {
      await _pump(
        tester,
        const SaveStatus(failed: 2, problem: SaveProblem.storageFull),
      );
      await open(tester);
      expect(find.text('Photos waiting'), findsOneWidget);
      expect(find.text('2 photos are waiting to be saved.'), findsOneWidget);
      expect(find.textContaining('run out of space'), findsOneWidget);
      expect(find.textContaining('kept temporarily'), findsOneWidget);
    });

    testWidgets('says what happened when a permission is missing', (
      tester,
    ) async {
      await _pump(
        tester,
        const SaveStatus(failed: 1, problem: SaveProblem.permission),
      );
      await open(tester);
      expect(find.text('1 photo is waiting to be saved.'), findsOneWidget);
      expect(find.textContaining('not allowed to save'), findsOneWidget);
    });

    testWidgets('does not guess when the reason is not known', (tester) async {
      await _pump(tester, const SaveStatus(failed: 1));
      await open(tester);
      expect(
        find.textContaining('could not be saved just now'),
        findsOneWidget,
      );
      expect(find.textContaining('space'), findsNothing);
      expect(find.textContaining('permission'), findsNothing);
    });

    testWidgets('"Try again" retries once and closes the sheet', (
      tester,
    ) async {
      final fake = await _pump(tester, const SaveStatus(failed: 1));
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('save-sheet-retry')));
      await tester.pumpAndSettle();
      expect(fake.retries, 1);
      expect(find.byKey(const ValueKey('save-sheet-retry')), findsNothing);
    });

    testWidgets('"Later" closes it and does nothing else', (tester) async {
      final fake = await _pump(tester, const SaveStatus(failed: 1));
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('save-sheet-later')));
      await tester.pumpAndSettle();
      expect(fake.retries, 0);
      expect(find.byKey(const ValueKey('save-sheet-later')), findsNothing);
      expect(_pending, findsOneWidget, reason: 'the chip stays');
    });

    testWidgets('"Try again" is off while something is being saved', (
      tester,
    ) async {
      final fake = await _pump(tester, const SaveStatus(failed: 1));
      await open(tester);
      fake.set(const SaveStatus(failed: 1, saving: 1));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('save-sheet-retry')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(fake.retries, 0);
    });
  });

  group('every theme and every text size', () {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('chip and sheet, $brightness, text x$scale', (
          tester,
        ) async {
          await _pump(
            tester,
            const SaveStatus(failed: 12, problem: SaveProblem.permission),
            brightness: brightness,
            textScale: scale,
            size: const Size(320, 568),
          );
          expect(tester.takeException(), isNull);
          // The chip never reaches past the right margin.
          expect(
            tester.getRect(_pending).right,
            lessThanOrEqualTo(320 - CarreteSpacing.margin + 0.5),
          );
          await tester.tap(_pending);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final retry = find.byKey(const ValueKey('save-sheet-retry'));
          await tester.ensureVisible(retry);
          expect(retry, findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('the saving pill, $brightness, text x$scale', (
          tester,
        ) async {
          await _pump(
            tester,
            const SaveStatus(saving: 24),
            brightness: brightness,
            textScale: scale,
            size: const Size(320, 568),
          );
          await tester.pump(CarreteSaveStatus.showDelay);
          await tester.pump(CarreteSaveStatus.fade);
          expect(_saving, findsOneWidget);
          expect(tester.takeException(), isNull);
          expect(
            tester.getRect(_saving).right,
            lessThanOrEqualTo(320 - CarreteSpacing.margin + 0.5),
          );
        });
      }
    }
  });
}
