import 'package:flutter/widgets.dart';

/// The languages the app is written in. Spanish is the source language of the
/// ARB files (`lib/l10n`), Catalan and English are translations.
const List<Locale> appSupportedLocales = <Locale>[
  Locale('es'),
  Locale('ca'),
  Locale('en'),
];

/// The locale of the language code [code], or null when the app does not
/// speak that language.
Locale? appLocaleForCode(String code) {
  for (final locale in appSupportedLocales) {
    if (locale.languageCode == code) return locale;
  }
  return null;
}
