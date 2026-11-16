import 'package:diapo/camera/camera_providers.dart';
import 'package:diapo/capture/capture_providers.dart';
import 'package:diapo/core/database/app_database.dart';
import 'package:diapo/core/database/tables.dart';
import 'package:diapo/core/settings/settings_provider.dart';
import 'package:diapo/l10n/app_localizations.dart';
import 'package:diapo/platform/system_settings.dart';
import 'package:diapo/render/film_resources.dart';
import 'package:diapo/roll/disposable.dart';
import 'package:diapo/screens/roll/roll_sheet.dart';
import 'package:diapo/screens/viewfinder/viewfinder_screen.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

Future<void> _tapDisposableKey(WidgetTester tester) async {
  final key = find.byKey(const ValueKey('disposable-key'));
  await tester.ensureVisible(key);
  await tester.pumpAndSettle();
  await tester.tap(key);
  await tester.pumpAndSettle();
}

void main() {
  group('the roll sheet', () {
    testWidgets('offers the disposable camera when no roll is loaded', (
      tester,
    ) async {
      await _open(tester, overrides: rollOverrides());
      expect(find.text('Disposable camera'), findsOneWidget);
      expect(find.byKey(const ValueKey('disposable-resume-key')), findsNothing);
    });

    testWidgets('asks for the develop time, with the next morning chosen', (
      tester,
    ) async {
      final results = await _open(tester, overrides: rollOverrides());
      await _tapDisposableKey(tester);
      expect(find.text('Start'), findsOneWidget);
      expect(find.textContaining('27 photos'), findsWidgets);
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(results, hasLength(1));
      final intent = results.single! as LoadDisposableIntent;
      expect(intent.delay, DevelopDelay.nextMorning);
    });

    testWidgets('warns that undeveloped photos are lost on uninstall', (
      tester,
    ) async {
      await _open(tester, overrides: rollOverrides());
      await _tapDisposableKey(tester);
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text(
            'The photos of a roll you have not developed exist only on this '
            'phone. If you uninstall the app, clear its data or move to '
            'another phone, they are lost.',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('keeps Start reachable on a small phone with big text', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _open(
        tester,
        overrides: rollOverrides(),
        size: const Size(360, 640),
      );
      await _tapDisposableKey(tester);
      final start = find.text('Start');
      await tester.ensureVisible(start);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(start).bottom, lessThanOrEqualTo(640));
      expect(find.textContaining('they are lost'), findsWidgets);
    });

    testWidgets('lets the person starting it pick another time', (
      tester,
    ) async {
      final results = await _open(tester, overrides: rollOverrides());
      await _tapDisposableKey(tester);
      // The dialog has its own set of develop times; the sheet's are behind.
      await tester.tap(
        find.descendant(of: find.byType(Dialog), matching: find.text('3 days')),
      );
      await tester.pump();
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(
        (results.single! as LoadDisposableIntent).delay,
        DevelopDelay.threeDays,
      );
    });

    testWidgets('cancelling starts nothing', (tester) async {
      final results = await _open(tester, overrides: rollOverrides());
      await _tapDisposableKey(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(results, isEmpty);
      expect(find.text('Disposable camera'), findsOneWidget);
    });

    testWidgets('a disposable that was set aside can be put back', (
      tester,
    ) async {
      final roll = rollRow(mode: RollMode.disposable, length: 27);
      final results = await _open(
        tester,
        overrides: rollOverrides(active: roll, framesLeft: 14),
      );
      // The title is the disposable's, but nothing starts another one.
      expect(find.byKey(const ValueKey('disposable-key')), findsNothing);
      final key = find.byKey(const ValueKey('disposable-resume-key'));
      await tester.ensureVisible(key);
      await tester.tap(key);
      await tester.pumpAndSettle();
      expect((results.single! as ResumeDisposableIntent).rollId, roll.id);
    });

    testWidgets('while a disposable is set aside, says why no roll loads', (
      tester,
    ) async {
      await _open(
        tester,
        overrides: rollOverrides(
          active: rollRow(mode: RollMode.disposable, length: 27),
          framesLeft: 14,
        ),
      );
      expect(
        find.byKey(const ValueKey('disposable-resume-key')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('disposable-paused-note')),
        findsOneWidget,
      );
      expect(find.textContaining('To load another roll'), findsOneWidget);
      // No way to load a normal roll or another disposable from here.
      expect(find.text('Load roll'), findsNothing);
      expect(find.byKey(const ValueKey('disposable-key')), findsNothing);
      // Two main actions and, apart, the way to throw it away. The wording of
      // closing and developing is not repeated: see disposable_pause_test.
      for (final label in ['Finish roll', 'Throw away the roll']) {
        final finder = find.text(label);
        await tester.ensureVisible(finder);
        expect(finder, findsOneWidget);
      }
      expect(find.text('Close roll'), findsNothing);
      expect(find.text('Develop now'), findsNothing);
    });

    testWidgets('a normal roll has no way back to the disposable camera', (
      tester,
    ) async {
      await _open(
        tester,
        overrides: rollOverrides(active: rollRow(), framesLeft: 20),
      );
      expect(find.byKey(const ValueKey('disposable-resume-key')), findsNothing);
      expect(find.byKey(const ValueKey('disposable-key')), findsNothing);
    });
  });

  group('the camera', () {
    Future<(FakeRollService, ProviderContainer)> pump(
      WidgetTester tester, {
      RollRow? active,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = FakeRollService();
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(412, 915);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...rollOverrides(
              active: active,
              framesLeft: active == null ? null : 12,
              service: service,
            ),
            systemSettingsProvider.overrideWithValue(FakeSystemSettings()),
            sharedPreferencesProvider.overrideWithValue(prefs),
            cameraServiceProvider.overrideWithValue(FakeCameraService()),
            captureQueueProvider.overrideWithValue(FakeCaptureQueue()),
            filmResourcesProvider.overrideWith((ref) async => null),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ViewfinderScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ViewfinderScreen)),
      );
      return (service, container);
    }

    testWidgets('starting a disposable opens it with the fixed film and '
        'puts it in the camera', (tester) async {
      final (service, container) = await pump(tester);
      await tester.tap(find.byKey(const ValueKey('roll-key')));
      await tester.pumpAndSettle();
      await _tapDisposableKey(tester);
      await tester.tap(
        find.descendant(of: find.byType(Dialog), matching: find.text('3 days')),
      );
      await tester.pump();
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(service.calls, ['openDisposable threeDays desechable']);
      expect(container.read(disposableLockProvider), 7);
    });

    testWidgets('putting a disposable back locks the camera on it', (
      tester,
    ) async {
      final roll = rollRow(mode: RollMode.disposable, length: 27);
      final (service, container) = await pump(tester, active: roll);
      await tester.tap(find.byKey(const ValueKey('roll-key')));
      await tester.pumpAndSettle();
      final key = find.byKey(const ValueKey('disposable-resume-key'));
      await tester.ensureVisible(key);
      await tester.tap(key);
      await tester.pumpAndSettle();
      expect(service.calls, isEmpty);
      expect(container.read(disposableLockProvider), roll.id);
    });

    testWidgets('a failure to start says so and locks nothing', (tester) async {
      final (service, container) = await pump(tester);
      service.failWith = StateError('no');
      await tester.tap(find.byKey(const ValueKey('roll-key')));
      await tester.pumpAndSettle();
      await _tapDisposableKey(tester);
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(find.text('That did not work. Try again.'), findsOneWidget);
      expect(container.read(disposableLockProvider), isNull);
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
