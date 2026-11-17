import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:diapo/camera/camera_providers.dart';
import 'package:diapo/camera/camera_service.dart';
import 'package:diapo/core/database/app_database.dart';
import 'package:diapo/core/database/tables.dart';
import 'package:diapo/core/settings/settings_provider.dart';
import 'package:diapo/l10n/app_localizations.dart';
import 'package:diapo/platform/system_settings.dart';
import 'package:diapo/render/film_resources.dart';
import 'package:diapo/screens/disposable/disposable_parts.dart';
import 'package:diapo/screens/disposable/disposable_screen.dart';
import 'package:diapo/screens/disposable/disposable_start_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../support/roll_fakes.dart';
import '../support/roll_harness.dart';

/// The smallest phone the app still meets, in logical pixels.
const _small = Size(320, 568);

/// The languages of the app: the longest texts decide whether they fit.
const _locales = [Locale('es'), Locale('ca'), Locale('en')];

/// The text scales: the normal one and the biggest the system offers.
const _scales = [1.0, 2.0];

/// Loads the bundled fonts: the default font of the tests (Ahem) has glyphs
/// of one fixed width and hides how the real faces wrap and break.
Future<void> _loadFonts() async {
  for (final (family, files) in const [
    ('BowlbyOne', ['BowlbyOne-Regular.ttf']),
    ('SpaceMono', ['SpaceMono-Regular.ttf', 'SpaceMono-Bold.ttf']),
    ('Caveat', ['Caveat-Variable.ttf']),
    (
      'ChakraPetch',
      [
        'ChakraPetch-Regular.ttf',
        'ChakraPetch-Medium.ttf',
        'ChakraPetch-SemiBold.ttf',
        'ChakraPetch-Bold.ttf',
      ],
    ),
    (
      'BarlowSemiCondensed',
      [
        'BarlowSemiCondensed-Regular.ttf',
        'BarlowSemiCondensed-Medium.ttf',
        'BarlowSemiCondensed-SemiBold.ttf',
        'BarlowSemiCondensed-Bold.ttf',
      ],
    ),
  ]) {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = File('assets/fonts/$file').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

/// The widest word of [paragraph] at its own style and text scale.
double _widestWord(RenderParagraph paragraph) {
  var widest = 0.0;
  for (final word in paragraph.text.toPlainText().split(RegExp(r'\s+'))) {
    final painter = TextPainter(
      text: TextSpan(text: word, style: paragraph.text.style),
      textDirection: paragraph.textDirection,
      textScaler: paragraph.textScaler,
    )..layout();
    widest = math.max(widest, painter.width);
    painter.dispose();
  }
  return widest;
}

/// Pumps the disposable camera on a small phone with [scale] text and the
/// camera in [cameraState]. [framesLeft] frames are left in the roll.
Future<StreamController<RollRow?>> _pumpScreen(
  WidgetTester tester, {
  required Locale locale,
  required double scale,
  int framesLeft = 27,
  CameraServiceState? cameraState,
  FakeSystemSettings? system,
  Future<RecipeBook> Function()? book,
}) async {
  SharedPreferences.setMockInitialValues({'carrete.disposable.rollId': 7});
  final prefs = await SharedPreferences.getInstance();
  final rolls = StreamController<RollRow?>();
  addTearDown(rolls.close);
  rolls.add(rollRow(length: 27, filmId: 'beta', mode: RollMode.disposable));
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = _small;
  addTearDown(tester.view.reset);

  final base = ProviderContainer(
    overrides: [
      ...rollOverrides(
        activeStream: rolls.stream,
        framesLeft: framesLeft,
        service: FakeRollService(),
      ),
      sharedPreferencesProvider.overrideWithValue(prefs),
      cameraServiceProvider.overrideWithValue(
        cameraState == null
            ? FakeCameraService()
            : FakeCameraService(state: cameraState),
      ),
      systemSettingsProvider.overrideWithValue(system ?? FakeSystemSettings()),
      filmResourcesProvider.overrideWith((ref) async => null),
    ],
  );
  addTearDown(base.dispose);
  // A child container replaces the films where a test needs to.
  final container = ProviderContainer(
    parent: base,
    overrides: [
      if (book != null) recipeBookProvider.overrideWith((ref) => book()),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: _app(locale, scale, DisposableScreen(onFinished: (_) {})),
    ),
  );
  await tester.pumpAndSettle();
  return rolls;
}

Widget _app(Locale locale, double scale, Widget home) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

void main() {
  setUpAll(_loadFonts);

  for (final locale in _locales) {
    testWidgets('the failure message of ${locale.languageCode} switches to a '
        'narrow face at an extreme text scale and keeps the scale', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        locale: locale,
        scale: 2.5,
        cameraState: const CameraServiceState(
          failure: CameraFailure.permissionDenied,
        ),
      );
      expect(tester.takeException(), isNull);
      final message = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byType(DisposableNotice),
          matching: find.byType(RichText),
        ),
      );
      expect(message.text.style?.fontFamily, 'BarlowSemiCondensed');
      expect(message.textScaler.scale(10), closeTo(25, 0.01));
      expect(_widestWord(message), lessThanOrEqualTo(message.size.width));
      final retry = find.byType(PaperKey).last;
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      expect(retry.hitTestable(), findsOneWidget);
    });

    for (final scale in _scales) {
      final where = '${locale.languageCode} at ${scale}x';

      group('the disposable camera on 320x568, $where', () {
        testWidgets('shooting with a full roll', (tester) async {
          await _pumpScreen(tester, locale: locale, scale: scale);
          expect(tester.takeException(), isNull);
          expect(find.byType(DisposableShutter), findsOneWidget);
          expect(find.byType(ExitStamp), findsOneWidget);
        });

        testWidgets('on the last frames', (tester) async {
          await _pumpScreen(
            tester,
            locale: locale,
            scale: scale,
            framesLeft: 1,
          );
          expect(tester.takeException(), isNull);
          expect(find.byType(StickerCounter), findsOneWidget);
        });

        testWidgets('with the roll finished', (tester) async {
          final rolls = await _pumpScreen(
            tester,
            locale: locale,
            scale: scale,
            framesLeft: 0,
          );
          // The roll closes and the film rewinds: the notice stays on screen
          // until the camera hands over to the roll.
          rolls.add(null);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull);
          expect(find.byType(DisposableNotice), findsOneWidget);
          await tester.pump(const Duration(seconds: 4));
        });

        testWidgets('with the camera permission denied', (tester) async {
          final system = FakeSystemSettings();
          await _pumpScreen(
            tester,
            locale: locale,
            scale: scale,
            system: system,
            cameraState: const CameraServiceState(
              failure: CameraFailure.permissionDenied,
            ),
          );
          expect(tester.takeException(), isNull);
          final settings = find.byKey(
            const ValueKey('disposable-open-settings'),
          );
          expect(settings, findsOneWidget);
          expect(find.byType(PaperKey), findsNWidgets(2));

          // The panel is the whole window between the top band and the
          // cardboard, and nothing covers its bottom.
          final window = tester.getRect(
            find.descendant(
              of: find.byKey(const ValueKey('disposable-failure')),
              matching: find.byType(SingleChildScrollView),
            ),
          );
          expect(window.width, _small.width);
          expect(
            window.top,
            greaterThanOrEqualTo(
              tester.getRect(find.byType(DisposableBand)).bottom - 0.5,
            ),
          );
          expect(
            window.bottom,
            lessThanOrEqualTo(tester.getRect(find.byType(Cardboard)).top + 0.5),
          );

          // The words of the message do not break in two.
          final message = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.byType(DisposableNotice),
              matching: find.byType(RichText),
            ),
          );
          expect(_widestWord(message), lessThanOrEqualTo(message.size.width));
          // The message keeps the text scale of the system, whatever its face.
          expect(message.textScaler.scale(10), closeTo(10 * scale, 0.01));

          // The way to the settings is reachable by scrolling and the key is
          // fully inside the window and takes the tap.
          await tester.ensureVisible(settings);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final key = tester.getRect(settings);
          expect(key.top, greaterThanOrEqualTo(window.top - 0.5));
          expect(key.bottom, lessThanOrEqualTo(window.bottom + 0.5));
          expect(key.left, greaterThanOrEqualTo(window.left));
          expect(key.right, lessThanOrEqualTo(window.right));
          expect(settings.hitTestable(), findsOneWidget);
          await tester.tap(settings);
          expect(system.opened, 1);
        });

        testWidgets('with the camera permission denied, the retry key is '
            'reachable after the settings key', (tester) async {
          await _pumpScreen(
            tester,
            locale: locale,
            scale: scale,
            cameraState: const CameraServiceState(
              failure: CameraFailure.permissionDenied,
            ),
          );
          // The retry key, at the end of the panel, is reachable too.
          final retry = find.byType(PaperKey).last;
          await tester.ensureVisible(retry);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final window = tester.getRect(
            find.descendant(
              of: find.byKey(const ValueKey('disposable-failure')),
              matching: find.byType(SingleChildScrollView),
            ),
          );
          final key = tester.getRect(retry);
          expect(key.bottom, lessThanOrEqualTo(window.bottom + 0.5));
          expect(retry.hitTestable(), findsOneWidget);
        });

        testWidgets('with the camera permission denied and no settings page to '
            'open', (tester) async {
          await _pumpScreen(
            tester,
            locale: locale,
            scale: scale,
            system: FakeSystemSettings(available: false),
            cameraState: const CameraServiceState(
              failure: CameraFailure.permissionDenied,
            ),
          );
          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const ValueKey('disposable-open-settings')),
            findsNothing,
          );
          expect(find.byType(PaperKey), findsOneWidget);
          final retry = find.byType(PaperKey);
          await tester.ensureVisible(retry);
          await tester.pumpAndSettle();
          expect(retry.hitTestable(), findsOneWidget);
        });

        testWidgets('with the camera unavailable', (tester) async {
          await _pumpScreen(
            tester,
            locale: locale,
            scale: scale,
            cameraState: const CameraServiceState(
              failure: CameraFailure.unavailable,
            ),
          );
          expect(tester.takeException(), isNull);
          expect(find.byType(PaperKey), findsOneWidget);
        });

        testWidgets('with the films failing to load', (tester) async {
          await _pumpScreen(
            tester,
            locale: locale,
            scale: scale,
            book: () async => throw StateError('no films'),
          );
          expect(tester.takeException(), isNull);
          expect(find.byType(ExitStamp), findsOneWidget);
          expect(find.byType(DisposableNotice), findsOneWidget);
        });

        testWidgets('with the leave dialog open', (tester) async {
          await _pumpScreen(tester, locale: locale, scale: scale);
          final press = await tester.startGesture(
            tester.getCenter(find.byType(ExitStamp)),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 2100));
          await press.up();
          await tester.pumpAndSettle();
          expect(find.byType(Dialog), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('with the start dialog open', (tester) async {
          SharedPreferences.setMockInitialValues({});
          tester.view
            ..devicePixelRatio = 1
            ..physicalSize = _small;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            _app(
              locale,
              scale,
              Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => unawaited(showDisposableStart(context)),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          expect(find.byType(Dialog), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      });
    }
  }
}
