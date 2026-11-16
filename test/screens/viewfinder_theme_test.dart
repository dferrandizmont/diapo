import 'package:diapo/camera/camera_providers.dart';
import 'package:diapo/capture/capture_providers.dart';
import 'package:diapo/core/settings/settings_provider.dart';
import 'package:diapo/l10n/app_localizations.dart';
import 'package:diapo/render/film_resources.dart';
import 'package:diapo/roll/roll_providers.dart';
import 'package:diapo/screens/viewfinder/film_carousel.dart';
import 'package:diapo/screens/viewfinder/top_bar.dart';
import 'package:diapo/screens/viewfinder/tuning_panel.dart';
import 'package:diapo/screens/viewfinder/viewfinder_screen.dart';
import 'package:diapo/ui/theme/carrete_tokens.dart';
import 'package:diapo/ui/widgets/plastic_controls.dart';
import 'package:diapo/ui/widgets/plastic_key.dart';
import 'package:diapo/ui/widgets/plastic_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

Future<void> _pump(WidgetTester tester, Brightness brightness) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(412, 915);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeRollProvider.overrideWith((ref) => Stream.value(null)),
        sharedPreferencesProvider.overrideWithValue(preferences),
        cameraServiceProvider.overrideWithValue(FakeCameraService()),
        captureQueueProvider.overrideWithValue(FakeCaptureQueue()),
        recipeBookProvider.overrideWith((ref) async => testBook()),
        filmResourcesProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
        themeMode: brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        home: const ViewfinderScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// The painter of the settings key of the top bar.
PlasticSurfacePainter _settingsKey(WidgetTester tester) {
  final key = find.descendant(
    of: find.byType(ViewfinderTopBar),
    matching: find.byType(PlasticKey),
  );
  final paint = tester.widget<CustomPaint>(
    find.descendant(of: key.last, matching: find.byType(CustomPaint)).first,
  );
  return paint.painter! as PlasticSurfacePainter;
}

/// The colour of the small label under the LCD.
Color? _counterLabel(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byType(ViewfinderTopBar),
        matching: find.text('LOOSE PHOTOS'),
      ),
    )
    .style
    ?.color;

void main() {
  testWidgets('a dark theme keeps the camera of today', (tester) async {
    await _pump(tester, Brightness.dark);

    const dark = CarreteCameraColors.dark;
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      CarreteColors.viewfinder,
    );
    expect(
      tester
          .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
          )
          .value,
      SystemUiOverlayStyle.light,
    );
    final key = _settingsKey(tester);
    expect(key.top, CarreteColors.keyTop);
    expect(key.bottom, CarreteColors.keyBottom);
    expect(key.hardShadow, CarreteRelief.hard);
    expect(key.diffuseShadow, CarreteRelief.diffuse);
    expect(key.highlight, CarreteRelief.highlight);
    expect(_counterLabel(tester), CarreteColors.silk2);
    expect(find.byKey(const ValueKey('viewfinder-surround')), findsNothing);

    // The plastic of the camera is exactly the colours it always had.
    expect(dark.body, CarreteColors.viewfinder);
    expect(dark.ink, CarreteColors.silk);
    expect(dark.inkSoft, CarreteColors.silk2);
    expect(dark.active, CarreteColors.amber);
    expect(dark.panel, CarreteColors.panel);
    expect(dark.tray, CarreteColors.deep);
    expect(dark.plateShadow, CarreteRelief.panel);
  });

  testWidgets('a light theme dresses the camera in the light plastic', (
    tester,
  ) async {
    await _pump(tester, Brightness.light);

    const light = CarreteCameraColors.light;
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      light.body,
    );
    expect(
      tester
          .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
          )
          .value,
      SystemUiOverlayStyle.dark,
    );
    final key = _settingsKey(tester);
    expect(key.top, light.keyTop);
    expect(key.bottom, light.keyBottom);
    expect(key.highlight, light.highlight);
    expect(_counterLabel(tester), light.inkSoft);
    expect(light.surround, CarreteColors.viewfinder);
    expect(find.byKey(const ValueKey('viewfinder-surround')), findsOneWidget);

    // The shutter and the cartridges are light plastic too.
    final shutter = tester.widget<CustomPaint>(
      find
          .descendant(
            of: find.byType(ShutterButton),
            matching: find.byType(CustomPaint),
          )
          .first,
    );
    expect(shutter.painter, isNotNull);
    final plate = tester.widget<CustomPaint>(
      find
          .descendant(
            of: find.byType(FilmCarousel),
            matching: find.descendant(
              of: find.byType(PlasticPlate),
              matching: find.byType(CustomPaint),
            ),
          )
          .first,
    );
    final selected = plate.painter! as PlasticSurfacePainter;
    expect(selected.top, light.cartridgeSelectedTop);
  });

  testWidgets('the tuning panel follows the light theme', (tester) async {
    await _pump(tester, Brightness.light);
    await tester.longPress(find.byType(FilmCartridge).first);
    await tester.pump();

    final plate = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(PlasticPlateSurface),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = plate.decoration as BoxDecoration;
    expect(decoration.color, CarreteCameraColors.light.panel);
  });

  test('the light camera keeps its print readable', () {
    double luminance(Color c) => c.computeLuminance();
    double contrast(Color a, Color b) {
      final x = luminance(a);
      final y = luminance(b);
      final hi = x > y ? x : y;
      final lo = x > y ? y : x;
      return (hi + 0.05) / (lo + 0.05);
    }

    const c = CarreteCameraColors.light;
    for (final (ink, surface) in [
      (c.ink, c.body),
      (c.ink, c.keyTop),
      (c.ink, c.keyBottom),
      (c.inkSoft, c.body),
      (c.inkSoft, c.cartridgeBottom),
      (c.active, c.keyPressedTop),
      (c.active, c.keyPressedBottom),
      (c.active, c.cartridgeSelectedBottom),
      (c.ink, c.panel),
      (c.inkSoft, c.panel),
      (c.active, c.panel),
      (CarreteColors.lcdInk, CarreteColors.lcd),
    ]) {
      expect(
        contrast(ink, surface),
        greaterThanOrEqualTo(4.5),
        reason: '$ink on $surface',
      );
    }
  });
}
