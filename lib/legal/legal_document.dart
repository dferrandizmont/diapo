import 'dart:ui';

/// The legal texts bundled with the app, readable offline.
enum LegalDocument {
  privacyPolicy('politica-privacidad'),
  legalNotice('aviso-legal');

  const LegalDocument(this.baseName);

  /// The start of the file name of every language of the text.
  final String baseName;

  /// The languages the texts are written in; any other locale reads English.
  static const List<String> languages = ['es', 'ca', 'en'];

  /// The language of the text shown to [locale].
  static String languageFor(Locale locale) =>
      languages.contains(locale.languageCode) ? locale.languageCode : 'en';

  /// The asset that holds the text for [locale]: Spanish has no suffix.
  String assetFor(Locale locale) {
    final language = languageFor(locale);
    final suffix = language == 'es' ? '' : '.$language';
    return 'docs/legal/$baseName$suffix.md';
  }

  /// The text a Markdown link points to (`politica-privacidad.ca.md`), or null
  /// when it is not one of the bundled texts.
  static LegalDocument? fromLink(String target) {
    final name = target.split('/').last.split('#').first;
    for (final document in values) {
      if (name == '${document.baseName}.md' ||
          languages.any((l) => name == '${document.baseName}.$l.md')) {
        return document;
      }
    }
    return null;
  }
}
