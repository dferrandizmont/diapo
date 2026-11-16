import 'dart:async';

import 'package:carrete/camera/camera_providers.dart';
import 'package:carrete/capture/capture_providers.dart';
import 'package:carrete/core/database/app_database.dart';
import 'package:carrete/core/settings/first_minute.dart';
import 'package:carrete/core/settings/settings_provider.dart';
import 'package:carrete/l10n/app_localizations.dart';
import 'package:carrete/platform/system_settings.dart';
import 'package:carrete/render/film_resources.dart';
import 'package:carrete/screens/viewfinder/film_carousel.dart';
import 'package:carrete/screens/viewfinder/viewfinder_screen.dart';
import 'package:carrete/ui/widgets/plastic_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../support/roll_fakes.dart';
import '../support/roll_harness.dart';

class _Harness {
  _Harness(this.queue, this.service, this.preferences);

  final FakeCaptureQueue queue;
  final FakeRollService service;
  final SharedPreferences preferences;

  ProviderContainer get container => ProviderScope.containerOf(
    find.byType(ViewfinderScreen, skipOffstage: false).evaluate().first,
  );

  FirstMinuteState get firstMinute => container.read(firstMinuteProvider);
}

/// The camera of a user who [seen] the tutorial or not, with the rolls of
/// [history] already in the database.
Future<_Harness> _pump(
  WidgetTester tester, {
  bool seen = false,
  List<RollRow> history = const [],
  Map<String, Object> prefs = const {},
  Locale locale = const Locale('en'),
  Stream<RollRow?>? active,
  Stream<List<RollRow>>? rolls,
  Size size = const Size(412, 915),
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues({
    if (seen) 'carrete.settings.onboardingSeen': true,
    ...prefs,
  });
  final preferences = await SharedPreferences.getInstance();
  final queue = FakeCaptureQueue();
  final service = FakeRollService();
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...rollOverrides(
          rolls: history,
          service: service,
          activeStream: active,
          // The list of rolls can change while the camera is open.
          rollsStream: rolls,
        ),
        systemSettingsProvider.overrideWithValue(FakeSystemSettings()),
        sharedPreferencesProvider.overrideWithValue(preferences),
        cameraServiceProvider.overrideWithValue(FakeCameraService()),
        captureQueueProvider.overrideWithValue(queue),
        filmResourcesProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // The screen of a roll that closed is not part of these tests.
        home: ViewfinderScreen(onOpenRoll: (_) {}),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return _Harness(queue, service, preferences);
}

/// Presses the shutter.
Future<void> _shoot(WidgetTester tester) async {
  await tester.tap(find.byType(ShutterButton));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

/// Says that the last photo was saved.
Future<void> _save(WidgetTester tester, _Harness h) async {
  h.queue.saved(h.queue.jobs.last);
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Takes a photo and says that it was saved.
Future<void> _shootAndSave(WidgetTester tester, _Harness h) async {
  await _shoot(tester);
  await _save(tester, h);
}

final _hint = find.byKey(const ValueKey('swipe-hint'));
final _offer = find.byKey(const ValueKey('roll-offer'));

void main() {
  group('the hint about swiping the films', () {
    testWidgets('a new user sees it over the camera, and nothing else', (
      tester,
    ) async {
      final h = await _pump(tester);
      expect(_hint, findsOneWidget);
      expect(find.text('Swipe the cartridges to change film'), findsOneWidget);
      expect(_offer, findsNothing);
      expect(h.firstMinute.swipeHintSeen, isFalse);
    });

    testWidgets('a user who saw the tutorial does not see it', (tester) async {
      await _pump(tester, seen: true);
      expect(_hint, findsNothing);
    });

    testWidgets('its key closes it for good', (tester) async {
      final h = await _pump(tester);
      await tester.tap(find.byKey(const ValueKey('swipe-hint-close')));
      await tester.pump();
      expect(_hint, findsNothing);
      expect(h.firstMinute.swipeHintSeen, isTrue);
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        h.preferences.getBool('carrete.firstMinute.swipeHintSeen'),
        isTrue,
      );
    });

    testWidgets('choosing another film closes it', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Beta'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_hint, findsNothing);
    });

    testWidgets('it does not come back once it was seen', (tester) async {
      await _pump(tester, prefs: {'carrete.firstMinute.swipeHintSeen': true});
      expect(_hint, findsNothing);
    });

    testWidgets('its key has 44 px and a label for a screen reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      final key = find.byKey(const ValueKey('swipe-hint-close'));
      expect(tester.getSize(key).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(key).height, greaterThanOrEqualTo(44));
      expect(find.bySemanticsLabel('Dismiss tip'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('it is small, away from the films and inside the screen', (
      tester,
    ) async {
      await _pump(tester);
      final hint = tester.getRect(_hint);
      final carousel = tester.getRect(find.byType(FilmCarousel));
      expect(hint.bottom, lessThanOrEqualTo(carousel.top));
      expect(hint.left, greaterThanOrEqualTo(0));
      expect(hint.right, lessThanOrEqualTo(412));
    });
  });

  group('the offer of a roll of 12', () {
    testWidgets('comes after the second loose photo is saved, not before', (
      tester,
    ) async {
      final h = await _pump(tester);
      await _shootAndSave(tester, h);
      expect(_offer, findsNothing);

      await _shootAndSave(tester, h);
      expect(_offer, findsOneWidget);
      expect(find.text('Try a roll of 12'), findsOneWidget);
      // The film, the hidden photos and the instant develop.
      expect(find.textContaining('With Alpha'), findsOneWidget);
      expect(find.textContaining('hidden until you close'), findsOneWidget);
      expect(find.textContaining('right away, with no wait'), findsOneWidget);
    });

    testWidgets('a photo that failed to save does not count', (tester) async {
      final h = await _pump(tester);
      await _shootAndSave(tester, h);
      await tester.tap(find.byType(ShutterButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      // Nothing says the second photo was saved.
      expect(_offer, findsNothing);
      expect(h.firstMinute.loosePhotos, 1);
    });

    testWidgets('is shown once: closing it means never again', (tester) async {
      final h = await _pump(tester);
      await _shootAndSave(tester, h);
      await _shootAndSave(tester, h);
      await tester.tap(find.byKey(const ValueKey('roll-offer-dismiss')));
      await tester.pump();
      expect(_offer, findsNothing);
      expect(h.service.calls, isEmpty);

      await _shootAndSave(tester, h);
      await _shootAndSave(tester, h);
      expect(_offer, findsNothing);
      expect(h.firstMinute.rollOfferSeen, isTrue);
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        h.preferences.getBool('carrete.firstMinute.rollOfferSeen'),
        isTrue,
      );
    });

    testWidgets('accepting loads a roll of 12 with the film, no wait', (
      tester,
    ) async {
      final h = await _pump(tester);
      await tester.tap(find.text('Beta'));
      await tester.pump(const Duration(milliseconds: 400));
      await _shootAndSave(tester, h);
      await _shootAndSave(tester, h);
      expect(find.textContaining('With Beta'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('roll-offer-accept')));
      await tester.pump();
      await tester.pump();
      expect(h.service.calls, ['open 12 instant beta']);
      expect(_offer, findsNothing);
    });

    testWidgets('a failure to load says so', (tester) async {
      final h = await _pump(tester);
      await _shootAndSave(tester, h);
      await _shootAndSave(tester, h);
      h.service.failWith = StateError('no');

      await tester.tap(find.byKey(const ValueKey('roll-offer-accept')));
      await tester.pump();
      await tester.pump();
      expect(find.text('That did not work. Try again.'), findsOneWidget);
    });

    testWidgets('a user who already loaded a roll never gets it', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        seen: true,
        history: [rollRow(id: 3, filmId: 'alpha')],
      );
      await _shootAndSave(tester, h);
      await _shootAndSave(tester, h);
      expect(_offer, findsNothing);
      expect(h.firstMinute.rollOfferSeen, isTrue);
    });

    testWidgets('a user who saw the tutorial but never used a roll gets it', (
      tester,
    ) async {
      final h = await _pump(tester, seen: true);
      await _shootAndSave(tester, h);
      await _shootAndSave(tester, h);
      expect(_offer, findsOneWidget);
    });

    testWidgets('the count survives a restart', (tester) async {
      final h = await _pump(
        tester,
        prefs: {'carrete.firstMinute.loosePhotos': 1},
      );
      await _shootAndSave(tester, h);
      expect(_offer, findsOneWidget);
    });

    testWidgets('says that the photos live only on this phone, before the '
        'roll is loaded', (tester) async {
      final h = await _pump(tester);
      await _shootAndSave(tester, h);
      await _shootAndSave(tester, h);
      final loss = find.descendant(
        of: _offer,
        matching: find.byKey(const ValueKey('roll-offer-loss')),
      );
      expect(loss, findsOneWidget);
      expect(
        find.text(
          'They exist only on this phone: they are lost if you uninstall, '
          'clear the data or change phone.',
        ),
        findsOneWidget,
      );
      // It is read before the key that loads the roll is touched.
      expect(h.service.calls, isEmpty);
    });

    testWidgets('waits behind another screen and is marked as seen only '
        'when it is shown', (tester) async {
      final h = await _pump(tester);
      await _shootAndSave(tester, h);
      await _shoot(tester);
      // Another screen covers the camera before the second photo is saved.
      final navigator = Navigator.of(tester.element(find.byType(Scaffold)));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('gallery')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _save(tester, h);
      expect(h.firstMinute.loosePhotos, 2);
      expect(_offer, findsNothing);
      expect(h.firstMinute.rollOfferSeen, isFalse);

      // Back on the camera, the offer that waited is shown.
      navigator.pop();
      await tester.pumpAndSettle();
      expect(_offer, findsOneWidget);
      expect(h.firstMinute.rollOfferSeen, isTrue);
    });

    testWidgets('waits while the app is in the background', (tester) async {
      final h = await _pump(tester);
      await _shootAndSave(tester, h);
      await _shoot(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await _save(tester, h);
      expect(_offer, findsNothing);
      expect(h.firstMinute.rollOfferSeen, isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(_offer, findsOneWidget);
      expect(h.firstMinute.rollOfferSeen, isTrue);
    });

    testWidgets('loading a roll cancels it for good, also after the roll '
        'closes', (tester) async {
      final active = StreamController<RollRow?>();
      final rolls = StreamController<List<RollRow>>();
      addTearDown(() => unawaited(active.close()));
      addTearDown(() => unawaited(rolls.close()));
      active.add(null);
      rolls.add(const []);
      final h = await _pump(tester, active: active.stream, rolls: rolls.stream);
      await _shootAndSave(tester, h);
      await _shootAndSave(tester, h);
      expect(_offer, findsOneWidget);

      // A roll is loaded from somewhere else: the offer goes away.
      final roll = rollRow(id: 4, filmId: 'alpha');
      active.add(roll);
      rolls.add([roll]);
      await tester.pump();
      await tester.pump();
      expect(_offer, findsNothing);

      // The roll closes: the offer does not come back.
      active.add(null);
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      expect(_offer, findsNothing);
      await _shootAndSave(tester, h);
      await _shootAndSave(tester, h);
      expect(_offer, findsNothing);
      expect(h.firstMinute.rollOfferSeen, isTrue);
    });

    testWidgets('a roll loaded while the offer waits cancels it', (
      tester,
    ) async {
      final active = StreamController<RollRow?>();
      final rolls = StreamController<List<RollRow>>();
      addTearDown(() => unawaited(active.close()));
      addTearDown(() => unawaited(rolls.close()));
      active.add(null);
      rolls.add(const []);
      final h = await _pump(tester, active: active.stream, rolls: rolls.stream);
      await _shootAndSave(tester, h);
      await _shoot(tester);
      final navigator = Navigator.of(tester.element(find.byType(Scaffold)));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('gallery')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _save(tester, h);
      expect(_offer, findsNothing);

      // While the camera is covered a roll is loaded and closed.
      final roll = rollRow(id: 4, filmId: 'alpha');
      active.add(roll);
      rolls.add([roll]);
      await tester.pump();
      await tester.pump();
      active.add(null);
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));

      navigator.pop();
      await tester.pumpAndSettle();
      expect(_offer, findsNothing);
      expect(h.firstMinute.rollOfferSeen, isTrue);
    });

    testWidgets('is checked again before it is shown: a roll that appeared '
        'in the database while waiting for the list', (tester) async {
      final rolls = StreamController<List<RollRow>>();
      addTearDown(() => unawaited(rolls.close()));
      final h = await _pump(tester, rolls: rolls.stream);
      await _shootAndSave(tester, h);
      await _shootAndSave(tester, h);
      // The list of rolls has not answered yet: nothing is shown.
      expect(_offer, findsNothing);
      expect(h.firstMinute.rollOfferSeen, isFalse);
      rolls.add([rollRow(id: 2, filmId: 'alpha')]);
      await tester.pump();
      await tester.pump();
      expect(_offer, findsNothing);
      expect(h.firstMinute.rollOfferSeen, isTrue);
    });

    testWidgets('keys side by side on a normal phone', (tester) async {
      final h = await _pump(tester);
      await _shootAndSave(tester, h);
      await _shootAndSave(tester, h);
      final accept = tester.getRect(
        find.byKey(const ValueKey('roll-offer-accept')),
      );
      final dismiss = tester.getRect(
        find.byKey(const ValueKey('roll-offer-dismiss')),
      );
      expect(accept.center.dy, closeTo(dismiss.center.dy, 0.5));
    });

    for (final (language, width, height) in [
      ('es', 320.0, 568.0),
      ('ca', 360.0, 640.0),
      ('en', 320.0, 480.0),
    ]) {
      testWidgets('at 2x on $width x $height the card is bounded, scrolls and '
          'stacks its keys ($language)', (tester) async {
        final h = await _pump(
          tester,
          locale: Locale(language),
          size: Size(width, height),
          textScale: 2,
        );
        await _shootAndSave(tester, h);
        await _shootAndSave(tester, h);
        expect(tester.takeException(), isNull);
        expect(_offer, findsOneWidget);

        final card = tester.getRect(_offer);
        expect(card.left, greaterThanOrEqualTo(0));
        expect(card.right, lessThanOrEqualTo(width));
        // Never over the carousel and the shutter.
        expect(
          card.bottom,
          lessThanOrEqualTo(
            tester.getRect(find.byType(FilmCarousel)).top + 0.5,
          ),
        );
        // The keys go one over the other, both reachable by scrolling.
        final accept = tester.getRect(
          find.byKey(const ValueKey('roll-offer-accept')),
        );
        final dismiss = tester.getRect(
          find.byKey(const ValueKey('roll-offer-dismiss')),
        );
        expect(dismiss.top, greaterThan(accept.top));
        expect(
          find.descendant(
            of: _offer,
            matching: find.byType(SingleChildScrollView),
          ),
          findsOneWidget,
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('roll-offer-dismiss')),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(
          tester
              .getSize(find.byKey(const ValueKey('roll-offer-dismiss')))
              .height,
          greaterThanOrEqualTo(44),
        );
      });
    }

    testWidgets('both keys have 44 px and the card fits a small phone', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final h = await _pump(tester, locale: const Locale('es'));
      tester.view.physicalSize = const Size(320, 640);
      await _shootAndSave(tester, h);
      await _shootAndSave(tester, h);
      expect(_offer, findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final key in ['roll-offer-dismiss', 'roll-offer-accept']) {
        final size = tester.getSize(find.byKey(ValueKey(key)));
        expect(size.height, greaterThanOrEqualTo(44), reason: key);
      }
      expect(tester.getRect(_offer).right, lessThanOrEqualTo(320));
    });

    Future<void> openTuning(WidgetTester tester) async {
      await tester.longPress(find.text('Alpha'));
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> saveSecondWhileTuningOpen(
      WidgetTester tester,
      _Harness h,
    ) async {
      await _shoot(tester);
      await openTuning(tester);
      await _save(tester, h);
    }

    testWidgets('the offer does not show while the fine-tuning panel is open: '
        'close button', (tester) async {
      final h = await _pump(tester);
      await _shootAndSave(tester, h);
      await saveSecondWhileTuningOpen(tester, h);
      expect(_offer, findsNothing);
      expect(h.firstMinute.loosePhotos, 2);

      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pump();
      await tester.pump();
      expect(_offer, findsOneWidget);
    });

    testWidgets('the offer does not show while the fine-tuning panel is open: '
        'tap on the frame', (tester) async {
      final h = await _pump(tester);
      await _shootAndSave(tester, h);
      await saveSecondWhileTuningOpen(tester, h);
      expect(_offer, findsNothing);

      await tester.tapAt(const Offset(206, 250));
      await tester.pump();
      await tester.pump();
      expect(_offer, findsOneWidget);
    });

    testWidgets(
      'the offer does not show while the fine-tuning panel is open: Back',
      (tester) async {
        final h = await _pump(tester);
        await _shootAndSave(tester, h);
        await saveSecondWhileTuningOpen(tester, h);
        expect(_offer, findsNothing);

        await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.pump();
        expect(_offer, findsOneWidget);
      },
    );
  });
}
