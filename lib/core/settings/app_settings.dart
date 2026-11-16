import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Locale, ThemeMode;

import '../l10n/app_locales.dart';

/// The film the camera loads when the user does not pick one. The recipes
/// live in `packages/film_recipes`; this is only the id of the default one.
const String kDefaultFilmId = 'verano-98';

/// How the date is stamped on the photo.
enum DateStampStyle {
  /// `yy m d`: the year first.
  yearFirst('yy m d'),

  /// `d m yy`: the day first.
  dayFirst('d m yy');

  const DateStampStyle(this.storageValue);

  /// The value written to the settings file.
  final String storageValue;

  /// The style stored as [value]; the default one when the value is unknown.
  static DateStampStyle fromStorage(String? value) => values.firstWhere(
    (style) => style.storageValue == value,
    orElse: () => DateStampStyle.yearFirst,
  );
}

/// The settings of the app, as the user sees them in the settings screen.
///
/// The class is immutable: [copyWith] makes a new one. [toJson] and
/// [fromJson] keep the shape of the settings for the export of a later
/// version, and make a value that is not there (or is corrupt) fall back to
/// the default instead of breaking the app.
@immutable
class AppSettings {
  const AppSettings({
    this.cameraSounds = true,
    this.haptics = true,
    this.saveOriginal = false,
    this.saveLocation = false,
    this.grid = false,
    this.level = false,
    this.dateStampStyle = DateStampStyle.yearFirst,
    this.defaultFilmId = kDefaultFilmId,
    this.themeMode = ThemeMode.system,
    this.localeOverride,
    this.onboardingSeen = false,
  });

  /// The settings of a fresh install.
  static const AppSettings defaults = AppSettings();

  /// The shutter click and the film-advance whirr after each shot. They are
  /// still skipped when the phone is on silent or vibrate.
  final bool cameraSounds;

  /// The small vibrations of the camera: the shutter, a cartridge settling, a
  /// roll loaded or finished. They are skipped when the phone is on silent;
  /// vibrate mode is fine.
  final bool haptics;

  /// Keep the photo without the film look, next to the developed one.
  final bool saveOriginal;

  /// Save where every photo was taken.
  final bool saveLocation;

  /// The grid of thirds on the viewfinder.
  final bool grid;

  /// The level (the horizon) on the viewfinder.
  final bool level;

  /// How the date is stamped on the photo.
  final DateStampStyle dateStampStyle;

  /// The film the camera loads when the user does not pick one.
  final String defaultFilmId;

  /// The theme of the screens that are not the camera.
  final ThemeMode themeMode;

  /// The language of the app; null follows the language of the device.
  final Locale? localeOverride;

  /// Whether the first-use flow was finished or skipped, so it is not shown
  /// again before the camera.
  final bool onboardingSeen;

  /// The same settings with the given fields changed.
  ///
  /// [clearLocaleOverride] removes the language override; without it a null
  /// [localeOverride] keeps the current one.
  AppSettings copyWith({
    bool? cameraSounds,
    bool? haptics,
    bool? saveOriginal,
    bool? saveLocation,
    bool? grid,
    bool? level,
    DateStampStyle? dateStampStyle,
    String? defaultFilmId,
    ThemeMode? themeMode,
    Locale? localeOverride,
    bool? onboardingSeen,
    bool clearLocaleOverride = false,
  }) => AppSettings(
    cameraSounds: cameraSounds ?? this.cameraSounds,
    haptics: haptics ?? this.haptics,
    saveOriginal: saveOriginal ?? this.saveOriginal,
    saveLocation: saveLocation ?? this.saveLocation,
    grid: grid ?? this.grid,
    level: level ?? this.level,
    dateStampStyle: dateStampStyle ?? this.dateStampStyle,
    defaultFilmId: defaultFilmId ?? this.defaultFilmId,
    themeMode: themeMode ?? this.themeMode,
    localeOverride: clearLocaleOverride
        ? null
        : (localeOverride ?? this.localeOverride),
    onboardingSeen: onboardingSeen ?? this.onboardingSeen,
  );

  /// The settings as data, for the export of a later version.
  Map<String, Object?> toJson() => <String, Object?>{
    'cameraSounds': cameraSounds,
    'haptics': haptics,
    'saveOriginal': saveOriginal,
    'saveLocation': saveLocation,
    'grid': grid,
    'level': level,
    'dateStampStyle': dateStampStyle.storageValue,
    'defaultFilmId': defaultFilmId,
    'themeMode': themeMode.name,
    'localeOverride': localeOverride?.languageCode,
    'onboardingSeen': onboardingSeen,
  };

  /// The settings of [json]. A field that is missing, or that holds a value
  /// the app does not know, falls back to the default.
  factory AppSettings.fromJson(Map<String, Object?> json) {
    const defaults = AppSettings.defaults;
    return AppSettings(
      cameraSounds: _boolOf(json['cameraSounds'], defaults.cameraSounds),
      haptics: _boolOf(json['haptics'], defaults.haptics),
      saveOriginal: _boolOf(json['saveOriginal'], defaults.saveOriginal),
      saveLocation: _boolOf(json['saveLocation'], defaults.saveLocation),
      grid: _boolOf(json['grid'], defaults.grid),
      level: _boolOf(json['level'], defaults.level),
      dateStampStyle: DateStampStyle.fromStorage(
        json['dateStampStyle'] is String
            ? json['dateStampStyle']! as String
            : null,
      ),
      defaultFilmId: _stringOf(json['defaultFilmId'], defaults.defaultFilmId),
      themeMode: _themeModeOf(json['themeMode']),
      localeOverride: _localeOf(json['localeOverride']),
      onboardingSeen: _boolOf(json['onboardingSeen'], defaults.onboardingSeen),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.cameraSounds == cameraSounds &&
      other.haptics == haptics &&
      other.saveOriginal == saveOriginal &&
      other.saveLocation == saveLocation &&
      other.grid == grid &&
      other.level == level &&
      other.dateStampStyle == dateStampStyle &&
      other.defaultFilmId == defaultFilmId &&
      other.themeMode == themeMode &&
      other.localeOverride == localeOverride &&
      other.onboardingSeen == onboardingSeen;

  @override
  int get hashCode => Object.hash(
    cameraSounds,
    haptics,
    saveOriginal,
    saveLocation,
    grid,
    level,
    dateStampStyle,
    defaultFilmId,
    themeMode,
    localeOverride,
    onboardingSeen,
  );

  @override
  String toString() => 'AppSettings(${toJson()})';
}

bool _boolOf(Object? value, bool fallback) => value is bool ? value : fallback;

String _stringOf(Object? value, String fallback) =>
    value is String && value.isNotEmpty ? value : fallback;

ThemeMode _themeModeOf(Object? value) {
  if (value is! String) return ThemeMode.system;
  for (final mode in ThemeMode.values) {
    if (mode.name == value) return mode;
  }
  return ThemeMode.system;
}

Locale? _localeOf(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return appLocaleForCode(value);
}
