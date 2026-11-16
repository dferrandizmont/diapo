import 'package:carrete/core/settings/settings_provider.dart';
import 'package:carrete/l10n/app_localizations.dart';
import 'package:carrete/legal/app_licence.dart';
import 'package:carrete/legal/legal_document.dart';
import 'package:carrete/legal/legal_markdown.dart';
import 'package:carrete/render/film_resources.dart';
import 'package:carrete/screens/legal/legal_page.dart';
import 'package:carrete/screens/settings/settings_screen.dart';
import 'package:carrete/ui/theme/carrete_tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

Future<void> _pumpSettings(
  WidgetTester tester,
  Locale locale, {
  ThemeMode mode = ThemeMode.light,
}) async {
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
      child: MaterialApp(
        locale: locale,
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
}

/// Waits for the page to read its bundled file (a real asset read, which the
/// fake clock of the test does not wait for) and for the route to settle.
Future<void> _settleDocument(WidgetTester tester) async {
  await tester.pumpAndSettle();
  for (var i = 0; i < 50; i++) {
    if (find.byType(LegalMarkdownView).evaluate().isNotEmpty) break;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// Goes back with the back key of the app bar (`pageBack` looks the key up by
/// its tooltip, which is translated).
Future<void> _back(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
}

/// Text that the page draws inside the document (not in the app bar).
Finder _inDocument(String text) => find.descendant(
  of: find.byType(LegalMarkdownView),
  matching: find.text(text, findRichText: true),
);

Finder _inAppBar(String text) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(text));

void main() {
  const cases = [
    (Locale('es'), 'Política de privacidad', 'Aviso legal'),
    (Locale('ca'), 'Política de privacitat', 'Avís legal'),
    (Locale('en'), 'Privacy policy', 'Legal notice'),
  ];

  for (final (locale, privacy, notice) in cases) {
    testWidgets('settings opens both documents in ${locale.languageCode}', (
      tester,
    ) async {
      await _pumpSettings(tester, locale);
      expect(find.text(privacy), findsOneWidget);
      expect(find.text(notice), findsOneWidget);

      await tester.tap(find.text(privacy));
      await _settleDocument(tester);
      expect(find.byType(LegalPage), findsOneWidget);
      expect(_inAppBar(privacy), findsOneWidget);
      // The first line of the bundled file of the language.
      expect(_inDocument(privacy), findsOneWidget);

      await _back(tester);
      expect(find.byType(LegalPage), findsNothing);

      await tester.tap(find.text(notice));
      await _settleDocument(tester);
      expect(_inAppBar(notice), findsOneWidget);
      expect(_inDocument(notice), findsOneWidget);
    });
  }

  for (final (mode, palette) in [
    (ThemeMode.light, CarretePalette.light),
    (ThemeMode.dark, CarretePalette.dark),
  ]) {
    testWidgets('the page uses the palette of the settings (${mode.name})', (
      tester,
    ) async {
      await _pumpSettings(tester, const Locale('en'), mode: mode);
      await tester.tap(find.text('Privacy policy'));
      await _settleDocument(tester);

      final context = tester.element(find.byType(LegalPage));
      expect(Theme.of(context).scaffoldBackgroundColor, palette.background);
      expect(Theme.of(context).colorScheme.primary, palette.accent);
      final bar = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(AppBar),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(bar.color, palette.background);
      // Back returns to the settings.
      await _back(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  }

  for (final (locale, text) in [
    (
      const Locale('es'),
      'Diapo es software libre bajo la licencia GPL-3.0-only. '
          'Código fuente: https://github.com/dferrandizmont/diapo',
    ),
    (
      const Locale('ca'),
      'Diapo és programari lliure sota la llicència GPL-3.0-only. '
          'Codi font: https://github.com/dferrandizmont/diapo',
    ),
    (
      const Locale('en'),
      'Diapo is free software under the GPL-3.0-only licence. '
          'Source code: https://github.com/dferrandizmont/diapo',
    ),
  ]) {
    testWidgets(
      'settings says Diapo is GPL-3.0-only (${locale.languageCode})',
      (tester) async {
        await _pumpSettings(tester, locale);
        expect(find.text(text), findsOneWidget);
        expect(find.byType(SelectableText), findsWidgets);
      },
    );
  }

  testWidgets('the licence of the app is registered with the full GPL text', (
    tester,
  ) async {
    registerAppLicence();
    final entries = (await tester.runAsync(
      () => LicenseRegistry.licenses.toList(),
    ))!;
    final own = entries.where((e) => e.packages.contains('Diapo')).toList();
    expect(own, hasLength(1));
    final text = own.single.paragraphs.map((p) => p.text).join('\n');
    expect(text, contains('GNU GENERAL PUBLIC LICENSE'));
    expect(text, contains('Version 3, 29 June 2007'));
    expect(
      text,
      contains('Additional permission under GNU GPL version 3 section 7'),
    );
  });

  testWidgets('the page is selectable and scrolls', (tester) async {
    await _pumpSettings(tester, const Locale('en'));
    await tester.tap(find.text('Legal notice'));
    await _settleDocument(tester);
    expect(find.byType(SelectionArea), findsOneWidget);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -800),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  group('LegalMarkdownView', () {
    Future<void> pumpView(
      WidgetTester tester,
      String markdown, {
      ValueChanged<LegalDocument>? onOpen,
      double scale = 1,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: LegalMarkdownView(
                  blocks: parseLegalMarkdown(markdown),
                  onOpenDocument: onOpen,
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('draws a table as cards with the header as labels', (
      tester,
    ) async {
      await pumpView(
        tester,
        '| Data | Why |\n| --- | --- |\n| Photos | To save them |\n'
        '| Settings | To remember |\n',
      );
      expect(find.text('Photos', findRichText: true), findsOneWidget);
      expect(find.text('Settings', findRichText: true), findsOneWidget);
      // The label of the column is repeated on each card.
      expect(find.text('WHY', findRichText: true), findsNothing);
      expect(find.text('Why', findRichText: true), findsNWidgets(2));
      expect(find.text('To save them', findRichText: true), findsOneWidget);
      // No table widget: it must read on a phone.
      expect(find.byType(Table), findsNothing);
    });

    testWidgets('shows bullets and does not show a comment', (tester) async {
      await pumpView(
        tester,
        'Hello <!-- hidden -->\n\n<!-- more\n\nhidden too -->\n\n'
        '- one\n- two\n',
      );
      expect(find.textContaining('hidden', findRichText: true), findsNothing);
      expect(find.text('•'), findsNWidgets(2));
      expect(find.text('one', findRichText: true), findsOneWidget);
    });

    testWidgets('a link to a bundled text opens it, others do not', (
      tester,
    ) async {
      final opened = <LegalDocument>[];
      await pumpView(
        tester,
        'Read [the policy](politica-privacidad.en.md) or '
        '[the web](https://example.com).',
        onOpen: opened.add,
      );
      await tester.tapOnText(find.textRange.ofSubstring('the policy'));
      expect(opened, [LegalDocument.privacyPolicy]);
      await tester.tapOnText(find.textRange.ofSubstring('the web'));
      expect(opened, hasLength(1));
    });

    testWidgets('large text does not overflow', (tester) async {
      await pumpView(
        tester,
        '# Title\n\n| A | B |\n| - | - |\n| Name | A long value that wraps '
        'over several lines on a narrow screen |\n\n- a bullet\n',
        scale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
