import 'package:diapo/core/settings/settings_provider.dart';
import 'package:diapo/l10n/app_localizations.dart';
import 'package:diapo/render/film_resources.dart';
import 'package:diapo/screens/settings/settings_screen.dart';
import 'package:diapo/ui/theme/carrete_tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

Future<void> _openLicences(WidgetTester tester, ThemeMode mode) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(412, 3000);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        recipeBookProvider.overrideWith((ref) async => testBook()),
      ],
      // The same bare Material 3 themes as the app (lib/app.dart).
      child: MaterialApp(
        locale: const Locale('en'),
        themeMode: mode,
        theme: ThemeData(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(today: DateTime(2026, 7, 14)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.tap(find.text('Licenses'));
  await tester.pumpAndSettle();
}

/// The colour the page paints for its scaffold and its app bar.
({Color page, Color bar, Color title}) _colors(WidgetTester tester) {
  final scaffold = find.descendant(
    of: find.byType(LicensePage),
    matching: find.byType(Scaffold),
  );
  final context = tester.element(scaffold.last);
  final page = Theme.of(context).scaffoldBackgroundColor;
  final barMaterial = tester.widget<Material>(
    find
        .descendant(
          of: find.byType(AppBar).last,
          matching: find.byType(Material),
        )
        .first,
  );
  final title = tester
      .widget<DefaultTextStyle>(
        find
            .descendant(
              of: find.byType(AppBar).last,
              matching: find.byType(DefaultTextStyle),
            )
            .first,
      )
      .style
      .color!;
  return (page: page, bar: barMaterial.color!, title: title);
}

void main() {
  setUp(() {
    LicenseRegistry.addLicense(
      () => Stream.value(
        const LicenseEntryWithLineBreaks([
          'carrete_test_package',
        ], 'A licence.'),
      ),
    );
  });

  for (final (mode, palette) in [
    (ThemeMode.light, CarretePalette.light),
    (ThemeMode.dark, CarretePalette.dark),
  ]) {
    testWidgets('the licence page and the detail of a package use the '
        'palette (${mode.name})', (tester) async {
      await _openLicences(tester, mode);

      expect(find.byType(LicensePage), findsOneWidget);
      var c = _colors(tester);
      expect(c.page, palette.background, reason: 'scaffold of the list');
      expect(c.bar, palette.background, reason: 'app bar of the list');
      expect(c.title, palette.ink, reason: 'title of the list');
      // Neither the lavender of Material 3 nor its default surface.
      expect(
        Theme.of(tester.element(find.byType(LicensePage))).colorScheme.primary,
        palette.accent,
      );

      // The detail of a package is a route of the navigator of the page.
      await tester.tap(find.text('carrete_test_package'));
      await tester.pumpAndSettle();
      c = _colors(tester);
      expect(c.page, palette.background, reason: 'scaffold of the detail');
      expect(c.bar, palette.background, reason: 'app bar of the detail');
      expect(c.title, palette.ink, reason: 'title of the detail');
    });
  }

  testWidgets('leaves the theme of the rest of the app alone', (tester) async {
    await _openLicences(tester, ThemeMode.light);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsNothing);
    final context = tester.element(find.byType(SettingsScreen));
    expect(
      Theme.of(context).colorScheme.primary,
      isNot(CarretePalette.light.accent),
    );
  });
}
