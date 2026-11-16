import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/widgets.dart';

/// Picks the text of the language of the app out of a [LocalizedText].
extension LocalizedTextForLocale on LocalizedText {
  /// The text for [languageCode]; Spanish, the source language, when the app
  /// speaks a language the recipe does not.
  String forLanguage(String languageCode) => switch (languageCode) {
    'ca' => ca,
    'en' => en,
    _ => es,
  };

  /// The text for the language the app is shown in.
  String of(BuildContext context) =>
      forLanguage(Localizations.localeOf(context).languageCode);
}
