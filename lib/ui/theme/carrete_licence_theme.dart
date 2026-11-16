import 'package:flutter/material.dart';

import 'carrete_tokens.dart';

/// The Material theme of the screens that are plain Flutter pages (the page of
/// licences), drawn with the palette and the fonts of the settings so they do
/// not show the default lavender of Material 3.
///
/// It is applied only to those pages, not to the whole app: the dialogs, the
/// snack bars and the sheets keep their own look.
abstract final class CarreteLicenceTheme {
  /// The theme for the [palette] (the light or the dark gallery).
  static ThemeData of(CarretePalette palette) {
    final scheme = ColorScheme(
      brightness: palette.brightness,
      primary: palette.accent,
      onPrimary: palette.background,
      secondary: palette.accent,
      onSecondary: palette.background,
      error: CarreteColors.shutter,
      onError: CarreteColors.white,
      surface: palette.background,
      onSurface: palette.ink,
      onSurfaceVariant: palette.inkSoft,
      outline: palette.hairline,
      outlineVariant: palette.hairline,
      surfaceTint: Colors.transparent,
      surfaceContainerLowest: palette.background,
      surfaceContainerLow: palette.plate,
      surfaceContainer: palette.plate,
      surfaceContainerHigh: palette.plate,
      surfaceContainerHighest: palette.plate,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: palette.brightness,
      colorScheme: scheme,
    );
    final text = base.textTheme.apply(
      fontFamily: CarreteFonts.text,
      fontFamilyFallback: const [CarreteFonts.display],
      bodyColor: palette.ink,
      displayColor: palette.ink,
    );
    return base.copyWith(
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      // The list of packages draws its rows on the card colour.
      cardColor: palette.plate,
      dividerColor: palette.hairline,
      highlightColor: palette.hairline,
      splashFactory: NoSplash.splashFactory,
      textTheme: text,
      primaryTextTheme: text,
      iconTheme: IconThemeData(color: palette.ink),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: palette.ink),
        titleTextStyle: CarreteText.pageTitle(palette.ink),
      ),
      dividerTheme: DividerThemeData(color: palette.hairline),
      listTileTheme: ListTileThemeData(
        textColor: palette.ink,
        iconColor: palette.ink,
      ),
    );
  }
}
