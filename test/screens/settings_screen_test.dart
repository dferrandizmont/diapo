import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:diapo/core/app_info.dart';
import 'package:diapo/core/settings/app_settings.dart';
import 'package:diapo/core/settings/settings_provider.dart';
import 'package:diapo/l10n/app_localizations.dart';
import 'package:diapo/platform/external_links.dart';
import 'package:diapo/render/film_resources.dart';
import 'package:diapo/screens/settings/settings_parts.dart';
import 'package:diapo/screens/settings/settings_screen.dart';
import 'package:diapo/ui/theme/carrete_tokens.dart';
import 'package:diapo/ui/widgets/plastic_controls.dart';
import 'package:diapo/ui/widgets/plastic_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

class _FakeLinks extends ExternalLinks {
  _FakeLinks({this.available = true, this.opens = true});

  final bool available;
  final bool opens;
  int kofiCalls = 0;

  @override
  bool get canOpen => available;

  @override
  Future<bool> openKofi() async {
    kofiCalls++;
    return opens;
  }
}

class _Harness {
  _Harness(this.prefs);

  final SharedPreferences prefs;

  ProviderContainer get container =>
      ProviderScope.containerOf(find.byType(SettingsScreen).evaluate().first);

  AppSettings get settings => container.read(settingsProvider);
}

bool _selected(WidgetTester tester, Finder finder) =>
    tester.getSemantics(finder).flagsCollection.isSelected == Tristate.isTrue;

bool _toggled(WidgetTester tester, Finder finder) =>
    tester.getSemantics(finder).flagsCollection.isToggled == Tristate.isTrue;

/// Opens the settings screen on a screen tall enough to build every row.
Future<_Harness> _pump(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  String language = 'en',
  ThemeMode theme = ThemeMode.light,
  Size size = const Size(412, 3000),
  bool reducedMotion = false,
  ExternalLinks? links,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final preferences = await SharedPreferences.getInstance();
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        recipeBookProvider.overrideWith((ref) async => testBook()),
        if (links != null) externalLinksProvider.overrideWithValue(links),
      ],
      child: MaterialApp(
        locale: Locale(language),
        themeMode: theme,
        theme: ThemeData(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: reducedMotion
            ? (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              )
            : null,
        home: SettingsScreen(today: DateTime(2026, 7, 14)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return _Harness(preferences);
}

void main() {
  group('what the screen lists', () {
    testWidgets('only the settings that work', (tester) async {
      await _pump(tester);
      for (final text in [
        'Settings',
        'Grid',
        'Level',
        'Camera sounds',
        'Also save the original',
        'Save location',
        'Date style',
        'DEFAULT FILM',
        'Theme',
        'Language',
        'Your settings, no photos',
        'Version',
        'Licenses',
      ]) {
        expect(find.text(text), findsWidgets, reason: text);
      }
    });

    testWidgets('the section titles are printed in capitals', (tester) async {
      await _pump(tester);
      expect(find.text('CAMERA'), findsOneWidget);
      expect(find.text('APPEARANCE'), findsOneWidget);
      expect(find.text('ABOUT'), findsOneWidget);
      expect(find.text('ADVANCED'), findsOneWidget);
    });

    testWidgets('is written in Catalan and in Spanish too', (tester) async {
      await _pump(tester, language: 'ca');
      expect(find.text('Configuració'), findsOneWidget);
      expect(find.text('Estil de la data'), findsOneWidget);
      expect(find.text('Llicències'), findsOneWidget);
      expect(find.text('Alpha ca'), findsOneWidget);
      await _pump(tester, language: 'es');
      expect(find.text('Estilo de la fecha'), findsOneWidget);
      expect(find.text('Licencias'), findsOneWidget);
    });
  });

  group('advanced', () {
    final chevron = find.byKey(const ValueKey('expander-chevron'));

    testWidgets('is the last section and starts collapsed', (tester) async {
      await _pump(tester);
      expect(find.text('Export settings'), findsNothing);
      expect(find.text('Import settings'), findsNothing);
      expect(
        tester.getTopLeft(find.text('ADVANCED')).dy,
        greaterThan(tester.getTopLeft(find.text('ABOUT')).dy),
      );
      // Nothing else comes after it.
      expect(
        tester.getTopLeft(find.text('Your settings, no photos')).dy,
        greaterThan(tester.getTopLeft(find.text('Licenses')).dy),
      );
    });

    testWidgets('opens and closes, and says the rows are only for settings', (
      tester,
    ) async {
      await _pump(tester);
      await tester.tap(chevron);
      await tester.pump();
      expect(find.text('Export settings'), findsOneWidget);
      expect(find.text('Import settings'), findsOneWidget);
      expect(find.textContaining('does not bring photos back'), findsOneWidget);
      expect(find.textContaining('It does not save your photos'), findsOne);

      await tester.tap(chevron);
      await tester.pump();
      expect(find.text('Export settings'), findsNothing);
    });

    testWidgets('announces whether it is expanded', (tester) async {
      await _pump(tester);
      final row = find.bySemanticsLabel('Your settings, no photos');
      expect(
        tester.getSemantics(row).flagsCollection.isExpanded,
        Tristate.isFalse,
      );
      await tester.tap(chevron);
      await tester.pump();
      expect(
        tester.getSemantics(row).flagsCollection.isExpanded,
        Tristate.isTrue,
      );
    });

    testWidgets('the level and the original stay in the camera section', (
      tester,
    ) async {
      await _pump(tester);
      final camera = tester.getTopLeft(find.text('CAMERA')).dy;
      final appearance = tester.getTopLeft(find.text('APPEARANCE')).dy;
      for (final label in ['Level', 'Also save the original']) {
        final y = tester.getTopLeft(find.text(label)).dy;
        expect(y, inExclusiveRange(camera, appearance), reason: label);
      }
    });

    testWidgets('is written in Spanish and in Catalan', (tester) async {
      await _pump(tester, language: 'es');
      expect(find.text('AVANZADO'), findsOneWidget);
      await _pump(tester, language: 'ca');
      expect(find.text('AVANÇAT'), findsOneWidget);
    });
  });

  group('grid', () {
    testWidgets('the switch turns the grid on and off and stores it', (
      tester,
    ) async {
      final h = await _pump(tester);
      expect(h.settings.grid, isFalse);

      await tester.tap(find.byType(PlasticSwitch).first);
      await tester.pump();
      expect(h.settings.grid, isTrue);
      expect(h.prefs.getBool('carrete.settings.grid'), isTrue);

      await tester.tap(find.byType(PlasticSwitch).first);
      await tester.pump();
      expect(h.settings.grid, isFalse);
      expect(h.prefs.getBool('carrete.settings.grid'), isFalse);
    });

    testWidgets('starts on the stored value', (tester) async {
      final h = await _pump(tester, prefs: {'carrete.settings.grid': true});
      expect(h.settings.grid, isTrue);
      final handle = tester.ensureSemantics();
      expect(_toggled(tester, find.byType(PlasticSwitch).first), isTrue);
      handle.dispose();
    });
  });

  group('level', () {
    testWidgets('is off on a fresh install; the switch turns it on', (
      tester,
    ) async {
      final h = await _pump(tester);
      expect(h.settings.level, isFalse);

      await tester.tap(find.byType(PlasticSwitch).at(1));
      await tester.pump();
      expect(h.settings.level, isTrue);
      expect(h.prefs.getBool('carrete.settings.level'), isTrue);
    });
  });

  group('vibration', () {
    testWidgets('is on on a fresh install, next to the sounds', (tester) async {
      final h = await _pump(tester);
      expect(h.settings.haptics, isTrue);
      expect(find.text('Camera sounds'), findsOneWidget);
      expect(find.text('Vibration'), findsOneWidget);
      // Right under the sounds.
      expect(
        tester.getTopLeft(find.text('Vibration')).dy,
        greaterThan(tester.getTopLeft(find.text('Camera sounds')).dy),
      );

      await tester.tap(find.byType(PlasticSwitch).at(3));
      await tester.pump();
      expect(h.settings.haptics, isFalse);
      expect(h.prefs.getBool('carrete.settings.haptics'), isFalse);
    });

    testWidgets('starts on the stored value, apart from the sounds', (
      tester,
    ) async {
      final h = await _pump(tester, prefs: {'carrete.settings.haptics': false});
      expect(h.settings.haptics, isFalse);
      expect(h.settings.cameraSounds, isTrue);
    });
  });

  group('camera sounds', () {
    testWidgets('are on on a fresh install; the switch turns them off', (
      tester,
    ) async {
      final h = await _pump(tester);
      expect(h.settings.cameraSounds, isTrue);

      await tester.tap(find.byType(PlasticSwitch).at(2));
      await tester.pump();
      expect(h.settings.cameraSounds, isFalse);
      expect(h.prefs.getBool('carrete.settings.cameraSounds'), isFalse);
    });

    testWidgets('start on the stored value', (tester) async {
      final h = await _pump(
        tester,
        prefs: {'carrete.settings.cameraSounds': false},
      );
      expect(h.settings.cameraSounds, isFalse);
      final handle = tester.ensureSemantics();
      expect(_toggled(tester, find.byType(PlasticSwitch).at(2)), isFalse);
      handle.dispose();
    });
  });

  group('save the original', () {
    testWidgets('is off on a fresh install; the switch turns it on', (
      tester,
    ) async {
      final h = await _pump(tester);
      expect(h.settings.saveOriginal, isFalse);

      await tester.tap(find.byType(PlasticSwitch).at(4));
      await tester.pump();
      expect(h.settings.saveOriginal, isTrue);
      expect(h.prefs.getBool('carrete.settings.saveOriginal'), isTrue);
    });

    testWidgets('starts on the stored value', (tester) async {
      final h = await _pump(
        tester,
        prefs: {'carrete.settings.saveOriginal': true},
      );
      expect(h.settings.saveOriginal, isTrue);
      final handle = tester.ensureSemantics();
      expect(_toggled(tester, find.byType(PlasticSwitch).at(4)), isTrue);
      handle.dispose();
    });

    testWidgets('is written in the three languages', (tester) async {
      await _pump(tester, language: 'es');
      expect(find.text('Guardar también el original'), findsOneWidget);
      await _pump(tester, language: 'ca');
      expect(find.text("Desa també l'original"), findsOneWidget);
    });
  });

  group('date style', () {
    testWidgets('shows both styles with the date of today', (tester) async {
      await _pump(tester);
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel("Year first: '26 7 14"), findsOneWidget);
      expect(find.bySemanticsLabel("Day first: 14 7 '26"), findsOneWidget);
      expect(find.text('YEAR FIRST'), findsOneWidget);
      expect(find.text('DAY FIRST'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a tap changes the style and stores it', (tester) async {
      final h = await _pump(tester);
      expect(h.settings.dateStampStyle, DateStampStyle.yearFirst);

      await tester.tap(find.text('DAY FIRST'));
      await tester.pump();
      expect(h.settings.dateStampStyle, DateStampStyle.dayFirst);
      expect(h.prefs.getString('carrete.settings.dateStampStyle'), 'd m yy');

      await tester.tap(find.text('YEAR FIRST'));
      await tester.pump();
      expect(h.settings.dateStampStyle, DateStampStyle.yearFirst);
      expect(h.prefs.getString('carrete.settings.dateStampStyle'), 'yy m d');
    });

    testWidgets('the selected style is marked for screen readers', (
      tester,
    ) async {
      await _pump(tester, prefs: {'carrete.settings.dateStampStyle': 'd m yy'});
      final handle = tester.ensureSemantics();
      expect(
        _selected(tester, find.bySemanticsLabel("Day first: 14 7 '26")),
        isTrue,
      );
      expect(
        _selected(tester, find.bySemanticsLabel("Year first: '26 7 14")),
        isFalse,
      );
      handle.dispose();
    });
  });

  group('default film', () {
    testWidgets('lists every film of the recipe book', (tester) async {
      await _pump(tester);
      expect(find.byType(SettingsChoiceRow), findsNWidgets(3));
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Gamma'), findsOneWidget);
    });

    testWidgets('shows the names in the language of the app', (tester) async {
      await _pump(tester, language: 'ca');
      expect(find.text('Beta ca'), findsOneWidget);
    });

    testWidgets('a tap selects the film and stores it', (tester) async {
      final h = await _pump(tester);
      await tester.tap(find.text('Beta'));
      await tester.pump();
      expect(h.settings.defaultFilmId, 'beta');
      expect(h.prefs.getString('carrete.settings.defaultFilmId'), 'beta');

      await tester.tap(find.text('Gamma'));
      await tester.pump();
      expect(h.settings.defaultFilmId, 'gamma');
    });

    testWidgets('the saved film is the selected one', (tester) async {
      await _pump(tester, prefs: {'carrete.settings.defaultFilmId': 'beta'});
      final handle = tester.ensureSemantics();
      bool selected(String name) =>
          _selected(tester, find.bySemanticsLabel(name));
      expect(selected('Beta'), isTrue);
      expect(selected('Alpha'), isFalse);
      handle.dispose();
    });

    testWidgets('shows the first film when the saved one is gone', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        prefs: {'carrete.settings.defaultFilmId': 'deleted-film'},
      );
      final handle = tester.ensureSemantics();
      expect(_selected(tester, find.bySemanticsLabel('Alpha')), isTrue);
      // Nothing is written until the user picks a film.
      expect(h.settings.defaultFilmId, 'deleted-film');
      handle.dispose();
    });
  });

  group('theme', () {
    testWidgets('the keys change the theme and store it', (tester) async {
      final h = await _pump(tester);
      expect(h.settings.themeMode, ThemeMode.system);

      await tester.tap(find.text('Dark'));
      await tester.pump();
      expect(h.settings.themeMode, ThemeMode.dark);
      expect(h.prefs.getString('carrete.settings.themeMode'), 'dark');

      await tester.tap(find.text('Light'));
      await tester.pump();
      expect(h.settings.themeMode, ThemeMode.light);
      expect(h.prefs.getString('carrete.settings.themeMode'), 'light');

      // Both "System" keys (theme and language) start selected.
      await tester.tap(find.text('System').first);
      await tester.pump();
      expect(h.settings.themeMode, ThemeMode.system);
      expect(h.prefs.getString('carrete.settings.themeMode'), 'system');
    });

    testWidgets('draws in the light and in the dark palette', (tester) async {
      await _pump(tester, theme: ThemeMode.light);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        CarretePalette.light.background,
      );
      expect(tester.takeException(), isNull);

      await _pump(tester, theme: ThemeMode.dark);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        CarretePalette.dark.background,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('language', () {
    testWidgets('the keys change the language and store it', (tester) async {
      final h = await _pump(tester);
      expect(h.settings.localeOverride, isNull);

      await tester.tap(find.text('Català'));
      await tester.pump();
      expect(h.settings.localeOverride, const Locale('ca'));
      expect(h.prefs.getString('carrete.settings.localeOverride'), 'ca');

      await tester.tap(find.text('Español'));
      await tester.pump();
      expect(h.settings.localeOverride, const Locale('es'));

      await tester.tap(find.text('English'));
      await tester.pump();
      expect(h.settings.localeOverride, const Locale('en'));
      expect(h.prefs.getString('carrete.settings.localeOverride'), 'en');

      // The last "System" key is the language one.
      await tester.tap(find.text('System').last);
      await tester.pump();
      expect(h.settings.localeOverride, isNull);
      expect(h.prefs.getString('carrete.settings.localeOverride'), isNull);
    });

    testWidgets('every language is written in its own language', (
      tester,
    ) async {
      await _pump(tester, language: 'ca');
      expect(find.text('Español'), findsOneWidget);
      expect(find.text('Català'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
    });
  });

  group('about', () {
    testWidgets('shows the version and the promise of privacy', (tester) async {
      await _pump(tester);
      expect(find.text(kAppVersion), findsOneWidget);
      expect(
        find.text(
          'Works offline, with no accounts and no ads. '
          'Your photos never leave the phone.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('licences opens the licence page of Flutter', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Licenses'));
      await tester.pumpAndSettle();
      expect(find.byType(LicensePage), findsOneWidget);
    });

    test('the version is the one of pubspec.yaml', () {
      // Run from the root of the project, as `flutter test` does.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final match = RegExp(
        r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.]+)?)',
        multiLine: true,
      ).firstMatch(pubspec);
      expect(match, isNotNull);
      expect(kAppVersion, match!.group(1));
    });
  });

  group('back', () {
    testWidgets('the back key leaves the screen', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            recipeBookProvider.overrideWith((ref) async => testBook()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsNothing);
    });
  });

  group('layout and accessibility', () {
    testWidgets('every control is at least 44 x 44', (tester) async {
      await _pump(tester);
      for (final finder in [
        find.byType(PlasticKey),
        find.byType(PlasticSwitch),
        find.byType(SettingsChoiceRow),
        find.byType(SettingsLinkRow),
      ]) {
        expect(finder, findsWidgets);
        for (final element in finder.evaluate()) {
          final size = tester.getSize(find.byWidget(element.widget));
          expect(size.width, greaterThanOrEqualTo(44), reason: '$finder');
          expect(size.height, greaterThanOrEqualTo(44), reason: '$finder');
        }
      }
      // The two sample tiles of the date styles.
      for (final label in ['YEAR FIRST', 'DAY FIRST']) {
        final tile = tester.getSize(
          find
              .ancestor(
                of: find.text(label),
                matching: find.byType(GestureDetector),
              )
              .first,
        );
        expect(tile.width, greaterThanOrEqualTo(44));
        expect(tile.height, greaterThanOrEqualTo(44));
      }
    });

    testWidgets('gives every control a semantic label', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      for (final label in [
        'Back',
        'Grid',
        'Level',
        'Camera sounds',
        "Year first: '26 7 14",
        "Day first: 14 7 '26",
        'Alpha',
        'Beta',
        'Gamma',
        'Theme',
        'System',
        'Light',
        'Dark',
        'Language',
        'Español',
        'Català',
        'English',
        'Version',
        'Licenses',
      ]) {
        expect(find.bySemanticsLabel(label), findsWidgets, reason: label);
      }
      handle.dispose();
    });

    testWidgets('the titles are headers for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      expect(
        tester.getSemantics(find.text('Settings')).flagsCollection.isHeader,
        isTrue,
      );
      expect(
        tester.getSemantics(find.text('CAMERA')).flagsCollection.isHeader,
        isTrue,
      );
      handle.dispose();
    });

    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('fits a small phone with large text in the ${theme.name} '
          'theme', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await _pump(tester, size: const Size(360, 640), theme: theme);
        expect(tester.takeException(), isNull);
        // Scroll through the whole page: nothing overflows on the way.
        for (var i = 0; i < 12; i++) {
          await tester.drag(find.byType(ListView), const Offset(0, -400));
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
      });
    }

    testWidgets('no animation runs when animations are disabled', (
      tester,
    ) async {
      await _pump(tester, reducedMotion: true);
      await tester.tap(find.byType(PlasticSwitch).first);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    group('Ko-fi row', () {
      final row = find.byKey(const ValueKey('settings-kofi'));

      testWidgets('shows with its label and hint where it can open', (
        tester,
      ) async {
        await _pump(tester, links: _FakeLinks());
        expect(row, findsOneWidget);
        expect(find.text('Buy me a coffee'), findsOneWidget);
        expect(find.text('Ko-fi, opens in your browser'), findsOneWidget);
      });

      testWidgets('is in the language of the app', (tester) async {
        await _pump(tester, language: 'ca', links: _FakeLinks());
        expect(find.text("Convida'm a un cafè"), findsOneWidget);
        expect(find.text("Ko-fi, s'obre al navegador"), findsOneWidget);
      });

      testWidgets('is absent where it cannot open', (tester) async {
        await _pump(tester, links: _FakeLinks(available: false));
        expect(row, findsNothing);
        expect(find.text('Buy me a coffee'), findsNothing);
      });

      testWidgets('a tap opens the page and shows nothing else', (
        tester,
      ) async {
        final links = _FakeLinks();
        await _pump(tester, links: links);
        await tester.tap(row);
        await tester.pump();
        expect(links.kofiCalls, 1);
        expect(find.byType(SnackBar), findsNothing);
      });

      testWidgets('a failed open shows a short note', (tester) async {
        final links = _FakeLinks(opens: false);
        await _pump(tester, links: links);
        await tester.tap(row);
        await tester.pump();
        await tester.pump();
        expect(links.kofiCalls, 1);
        expect(find.text('Could not open the browser'), findsOneWidget);
      });
    });
  });
}
