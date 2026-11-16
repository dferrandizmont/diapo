import 'package:diapo/app.dart';
import 'package:diapo/camera/camera_providers.dart';
import 'package:diapo/capture/capture_providers.dart';
import 'package:diapo/core/router.dart';
import 'package:diapo/core/settings/app_settings.dart';
import 'package:diapo/core/settings/settings_provider.dart';
import 'package:diapo/core/settings/settings_repository.dart';
import 'package:diapo/core/settings/settings_snapshot.dart';
import 'package:diapo/l10n/app_localizations.dart';
import 'package:diapo/platform/system_settings.dart';
import 'package:diapo/render/film_resources.dart';
import 'package:diapo/screens/roll/roll_screen.dart';
import 'package:diapo/screens/onboarding/onboarding_screen.dart';
import 'package:diapo/screens/settings/settings_screen.dart';
import 'package:diapo/screens/viewfinder/viewfinder_screen.dart';
import 'package:diapo/ui/widgets/plastic_controls.dart';
import 'package:diapo/ui/widgets/plastic_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../support/roll_harness.dart';

/// Counts the field edits that the notifier sends to the shared write queue.
class _SpyRepository extends SettingsRepository {
  _SpyRepository(super.preferences);

  int updates = 0;

  @override
  Future<void> update(AppSettings Function(AppSettings) change) {
    updates++;
    return super.update(change);
  }
}

const _title1 = 'A camera, not a filter.';
const _title2 = 'Pick a film.';
const _title3 = "A roll: photos you can't peek at.";

class _Harness {
  _Harness(this.router, this.camera, this.preferences);

  final GoRouter router;
  final FakeCameraService camera;
  final SharedPreferences preferences;

  ProviderContainer get container =>
      ProviderScope.containerOf(find.byType(CarreteApp).evaluate().first);

  bool get seen => container.read(settingsProvider).onboardingSeen;

  String get path => router.routerDelegate.currentConfiguration.uri.path;
}

/// Opens the whole app (the real router) and goes to [start], the tutorial by
/// default. The camera is a fake, so a screen that reached for it would be
/// seen in [FakeCameraService.started].
Future<_Harness> _pumpApp(
  WidgetTester tester, {
  bool seen = false,
  String start = AppRoutes.onboarding,
  Size size = const Size(412, 915),
  double textScale = 1,
  bool reducedMotion = false,
  SettingsRepository Function(SharedPreferences)? repository,
}) async {
  SharedPreferences.setMockInitialValues({
    if (seen) 'carrete.settings.onboardingSeen': true,
  });
  final preferences = await SharedPreferences.getInstance();
  final camera = FakeCameraService();
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  if (reducedMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        cameraServiceProvider.overrideWithValue(camera),
        captureQueueProvider.overrideWithValue(FakeCaptureQueue()),
        if (repository != null)
          settingsRepositoryProvider.overrideWithValue(repository(preferences)),
        ...rollOverrides(),
        systemSettingsProvider.overrideWithValue(FakeSystemSettings()),
        filmResourcesProvider.overrideWith((ref) async => null),
      ],
      child: const CarreteApp(),
    ),
  );
  // The router of the app, as it is in production.
  final container = ProviderScope.containerOf(
    find.byType(CarreteApp).evaluate().first,
  );
  final router = container.read(routerProvider);
  if (start != AppRoutes.camera) router.go(start);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return _Harness(router, camera, preferences);
}

Future<void> _press(WidgetTester tester) async {
  await tester.tap(find.byType(ShutterButton));
  await tester.pump();
  // The film advances one frame (300 ms) and the flash fades (320 ms).
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _skip(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Skip'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('on a fresh install', () {
    testWidgets('a new user goes straight to the camera, not the tutorial', (
      tester,
    ) async {
      final h = await _pumpApp(tester, start: AppRoutes.camera);

      expect(h.path, AppRoutes.camera);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(ViewfinderScreen), findsOneWidget);
      // The camera starts, which is where it asks for its permission.
      expect(h.camera.started, 1);
      expect(h.seen, isFalse);
    });

    testWidgets('the app opens on the camera, never on the tutorial', (
      tester,
    ) async {
      for (final seen in [false, true]) {
        final h = await _pumpApp(tester, seen: seen, start: AppRoutes.camera);
        expect(h.path, AppRoutes.camera, reason: 'seen: $seen');
        expect(find.byType(OnboardingScreen), findsNothing);
        expect(find.byType(ViewfinderScreen), findsOneWidget);
      }
    });
  });

  group('the tutorial', () {
    testWidgets('has three screens and teaches nothing about tuning', (
      tester,
    ) async {
      await _pumpApp(tester);
      expect(find.bySemanticsLabel('Step 1 of 3'), findsOneWidget);
      for (var step = 0; step < 3; step++) {
        final texts = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => (t.data ?? '').toLowerCase())
            .join('|');
        for (final word in [
          'fine-tune',
          'press and hold',
          'grain',
          'vignette',
        ]) {
          expect(texts, isNot(contains(word)), reason: 'step ${step + 1}');
        }
        if (step < 2) await _press(tester);
      }
    });

    testWidgets('the shutter goes through the three screens, then opens '
        'the camera', (tester) async {
      final h = await _pumpApp(tester);
      expect(find.text('1-3'), findsNothing); // digits are drawn, not text
      expect(find.bySemanticsLabel('Step 1 of 3'), findsOneWidget);
      expect(find.bySemanticsLabel('Next'), findsOneWidget);

      await _press(tester);
      expect(find.text(_title2), findsOneWidget);
      expect(find.bySemanticsLabel('Step 2 of 3'), findsOneWidget);
      expect(h.seen, isFalse);

      await _press(tester);
      expect(find.text(_title3), findsOneWidget);
      expect(find.bySemanticsLabel('Step 3 of 3'), findsOneWidget);
      // The last screen says what the shutter does now.
      expect(find.bySemanticsLabel('Start shooting'), findsOneWidget);
      expect(find.bySemanticsLabel('Next'), findsNothing);
      expect(h.seen, isFalse);

      await _press(tester);
      expect(h.seen, isTrue);
      expect(h.path, AppRoutes.camera);
      expect(find.byType(ViewfinderScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      // The flag is stored on the device.
      await tester.pump(const Duration(milliseconds: 50));
      expect(h.preferences.getBool('carrete.settings.onboardingSeen'), isTrue);
    });

    testWidgets('it can be skipped on the first screen', (tester) async {
      final h = await _pumpApp(tester);

      await _skip(tester);

      expect(h.seen, isTrue);
      expect(h.path, AppRoutes.camera);
      expect(find.byType(ViewfinderScreen), findsOneWidget);
    });

    testWidgets('it can be skipped on the last screen', (tester) async {
      final h = await _pumpApp(tester);
      await _press(tester);
      await _press(tester);

      await _skip(tester);

      expect(h.seen, isTrue);
      expect(find.byType(ViewfinderScreen), findsOneWidget);
    });

    testWidgets('a swipe changes the screen and the back key undoes it', (
      tester,
    ) async {
      await _pumpApp(tester);
      expect(find.bySemanticsLabel('Back'), findsNothing);

      await tester.drag(find.text(_title1), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text(_title2), findsOneWidget);
      expect(find.bySemanticsLabel('Step 2 of 3'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      expect(find.text(_title1), findsOneWidget);
      expect(find.bySemanticsLabel('Back'), findsNothing);
    });

    testWidgets('back on the first screen neither skips nor marks it seen', (
      tester,
    ) async {
      final h = await _pumpApp(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text(_title1), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(h.seen, isFalse);
    });

    testWidgets('a notification opens its roll, not the flow', (tester) async {
      final h = await _pumpApp(tester);
      expect(h.seen, isFalse);

      h.router.go(AppRoutes.rollOf('7'));
      await tester.pumpAndSettle();

      expect(find.byType(RollScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.text('This roll cannot be found'), findsOneWidget);
      expect(h.seen, isFalse);
    });

    testWidgets('taps that come together write the flag only once', (
      tester,
    ) async {
      late _SpyRepository spy;
      final h = await _pumpApp(
        tester,
        repository: (preferences) => spy = _SpyRepository(preferences),
      );
      await _press(tester);
      await _press(tester);
      expect(spy.updates, 0);

      // Two taps on the last shutter before the screen has time to leave.
      await tester.tap(find.byType(ShutterButton));
      await tester.tap(find.byType(ShutterButton));
      await tester.pump();

      expect(h.seen, isTrue);
      // Wait behind every queued write, using the same preferences as the app.
      await SettingsSnapshot(h.preferences).serialize(() async {});
      expect(spy.updates, 1);
      await h.preferences.reload();
      expect(SettingsRepository(h.preferences).load().onboardingSeen, isTrue);
    });

    testWidgets('two taps on skip write the flag only once', (tester) async {
      late _SpyRepository spy;
      final h = await _pumpApp(
        tester,
        repository: (preferences) => spy = _SpyRepository(preferences),
      );

      await tester.tap(find.bySemanticsLabel('Skip'));
      await tester.tap(find.bySemanticsLabel('Skip'));
      await tester.pump();

      expect(h.seen, isTrue);
      await SettingsSnapshot(h.preferences).serialize(() async {});
      expect(spy.updates, 1);
      await h.preferences.reload();
      expect(SettingsRepository(h.preferences).load().onboardingSeen, isTrue);
    });

    testWidgets('the system back goes to the previous screen first', (
      tester,
    ) async {
      final h = await _pumpApp(tester);
      await _press(tester);
      expect(find.text(_title2), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text(_title1), findsOneWidget);
      expect(h.seen, isFalse);
    });
  });

  group('from the settings', () {
    Future<_Harness> openFromSettings(WidgetTester tester) async {
      final h = await _pumpApp(
        tester,
        seen: true,
        start: AppRoutes.settings,
        size: const Size(412, 3000),
      );
      expect(find.byType(SettingsScreen), findsOneWidget);
      await tester.tap(find.text('How it works'));
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('the entry shows the flow again', (tester) async {
      await openFromSettings(tester);

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text(_title1), findsOneWidget);
    });

    testWidgets('finishing it goes back to the settings', (tester) async {
      final h = await openFromSettings(tester);

      await _press(tester);
      await _press(tester);
      await _press(tester);

      expect(h.path, AppRoutes.settings);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byType(ViewfinderScreen), findsNothing);
      expect(h.seen, isTrue);
    });

    testWidgets('skipping it goes back to the settings', (tester) async {
      final h = await openFromSettings(tester);

      await _skip(tester);

      expect(h.path, AppRoutes.settings);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });

  group('accessibility', () {
    testWidgets('every control and picture has a label', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpApp(tester);

      expect(find.bySemanticsLabel('Skip'), findsOneWidget);
      expect(find.bySemanticsLabel('Next'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('^A viewfinder with a scene on film')),
        findsOneWidget,
      );
      final title = tester.getSemantics(find.text(_title1));
      expect(title.flagsCollection.isHeader, isTrue);
      final skip = tester.getSemantics(find.bySemanticsLabel('Skip'));
      expect(skip.flagsCollection.isButton, isTrue);
      // Every key is at least 44 x 44.
      for (final key in tester.widgetList<PlasticKey>(
        find.byType(PlasticKey),
      )) {
        expect(key.width, greaterThanOrEqualTo(44));
        expect(key.height, greaterThanOrEqualTo(44));
      }

      await _press(tester);
      expect(
        find.bySemanticsLabel(RegExp('five film cartridges')),
        findsOneWidget,
      );
      await _press(tester);
      expect(
        find.bySemanticsLabel(RegExp('^The counter of a roll')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('large text fits on a small screen, on every screen', (
      tester,
    ) async {
      await _pumpApp(tester, size: const Size(320, 568), textScale: 2);

      for (var step = 0; step < 3; step++) {
        expect(tester.takeException(), isNull);
        // The controls stay on screen and reachable.
        expect(find.byType(ShutterButton), findsOneWidget);
        final bottom = tester.getBottomLeft(find.byType(ShutterButton)).dy;
        expect(bottom, lessThanOrEqualTo(568));
        if (step < 2) await _press(tester);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('large text keeps its size on the skip key, which grows', (
      tester,
    ) async {
      await _pumpApp(tester, size: const Size(320, 568), textScale: 2);

      final skip = find.byType(PlasticKey).first;
      expect(
        find.descendant(of: skip, matching: find.byType(FittedBox)),
        findsNothing,
      );
      // 14 px at twice the size, not shrunk back to fit the key.
      expect(tester.getSize(find.text('SKIP')).height, greaterThan(27));
      expect(tester.getSize(skip).width, greaterThan(96));
      expect(tester.getRect(skip).right, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);

      await tester.tap(skip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ViewfinderScreen), findsOneWidget);
    });

    testWidgets('with reduced motion the screen changes at once', (
      tester,
    ) async {
      await _pumpApp(tester, reducedMotion: true);

      await tester.tap(find.byType(ShutterButton));
      await tester.pump();

      // No film advance and no flash: one frame is enough.
      expect(find.text(_title2), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('it follows the language of the app', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(412, 915);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
          child: MaterialApp(
            locale: const Locale('ca'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const OnboardingScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Una càmera, no un filtre.'), findsOneWidget);
      expect(find.bySemanticsLabel('Saltar'), findsOneWidget);
    });
  });
}
