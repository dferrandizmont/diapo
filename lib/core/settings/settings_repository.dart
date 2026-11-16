import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_locales.dart';
import 'app_settings.dart';
import 'settings_snapshot.dart';

/// Reads and writes the [AppSettings] of the app in the preferences of the
/// device.
///
/// Legacy values are written one by one. After a settings import, portable
/// values use [SettingsSnapshot] alongside film tuning; onboarding stays local.
/// Missing or corrupt values fall back to their defaults.
class SettingsRepository {
  SettingsRepository(this._preferences);

  final SharedPreferences _preferences;

  static const String _kCameraSounds = 'carrete.settings.cameraSounds';
  static const String _kHaptics = 'carrete.settings.haptics';
  static const String _kSaveOriginal = 'carrete.settings.saveOriginal';
  static const String _kSaveLocation = 'carrete.settings.saveLocation';
  static const String _kGrid = 'carrete.settings.grid';
  static const String _kLevel = 'carrete.settings.level';
  static const String _kDateStampStyle = 'carrete.settings.dateStampStyle';
  static const String _kDefaultFilmId = 'carrete.settings.defaultFilmId';
  static const String _kThemeMode = 'carrete.settings.themeMode';
  static const String _kLocaleOverride = 'carrete.settings.localeOverride';
  static const String _kOnboardingSeen = 'carrete.settings.onboardingSeen';

  /// The settings stored in the device, or the default of every field that
  /// is missing or corrupt.
  AppSettings load() {
    final snapshot = SettingsSnapshot(_preferences).read();
    if (snapshot != null) {
      return AppSettings.fromJson(
        (snapshot['settings']! as Map).cast<String, Object?>(),
      ).copyWith(onboardingSeen: _readBool(_kOnboardingSeen) ?? false);
    }
    const defaults = AppSettings.defaults;
    final locale = _readString(_kLocaleOverride);
    return AppSettings(
      cameraSounds: _readBool(_kCameraSounds) ?? defaults.cameraSounds,
      haptics: _readBool(_kHaptics) ?? defaults.haptics,
      saveOriginal: _readBool(_kSaveOriginal) ?? defaults.saveOriginal,
      saveLocation: _readBool(_kSaveLocation) ?? defaults.saveLocation,
      grid: _readBool(_kGrid) ?? defaults.grid,
      level: _readBool(_kLevel) ?? defaults.level,
      dateStampStyle: DateStampStyle.fromStorage(_readString(_kDateStampStyle)),
      defaultFilmId: _readString(_kDefaultFilmId) ?? defaults.defaultFilmId,
      themeMode: _readThemeMode(_kThemeMode),
      localeOverride: locale == null ? null : appLocaleForCode(locale),
      onboardingSeen: _readBool(_kOnboardingSeen) ?? defaults.onboardingSeen,
    );
  }

  /// Writes [settings] to the preferences of the device.
  Future<void> save(AppSettings settings) =>
      SettingsSnapshot(_preferences).serialize(() => _save(settings));

  /// Evaluate field changes only when preceding writes have been confirmed.
  Future<void> update(AppSettings Function(AppSettings) change) =>
      SettingsSnapshot(_preferences).serialize(() => _save(change(load())));

  Future<void> _save(AppSettings settings) async {
    final store = SettingsSnapshot(_preferences);
    final snapshot = store.read();
    if (snapshot != null) {
      await store.write({
        ...snapshot,
        'settings': settings.toJson()..remove('onboardingSeen'),
      });
      await _preferences.setBool(_kOnboardingSeen, settings.onboardingSeen);
      return;
    }
    await _preferences.setBool(_kCameraSounds, settings.cameraSounds);
    await _preferences.setBool(_kHaptics, settings.haptics);
    await _preferences.setBool(_kSaveOriginal, settings.saveOriginal);
    await _preferences.setBool(_kSaveLocation, settings.saveLocation);
    await _preferences.setBool(_kGrid, settings.grid);
    await _preferences.setBool(_kLevel, settings.level);
    await _preferences.setString(
      _kDateStampStyle,
      settings.dateStampStyle.storageValue,
    );
    await _preferences.setString(_kDefaultFilmId, settings.defaultFilmId);
    await _preferences.setString(_kThemeMode, settings.themeMode.name);
    await _preferences.setBool(_kOnboardingSeen, settings.onboardingSeen);
    final locale = settings.localeOverride;
    if (locale == null) {
      await _preferences.remove(_kLocaleOverride);
    } else {
      await _preferences.setString(_kLocaleOverride, locale.languageCode);
    }
  }

  /// The bool stored in [key], or null when there is none or it is not a
  /// bool (a broken value reads as "not set").
  bool? _readBool(String key) {
    try {
      return _preferences.getBool(key);
    } on TypeError {
      return null;
    }
  }

  /// The string stored in [key], or null when there is none, it is not a
  /// string or it is empty.
  String? _readString(String key) {
    try {
      final value = _preferences.getString(key);
      if (value == null || value.isEmpty) return null;
      return value;
    } on TypeError {
      return null;
    }
  }

  ThemeMode _readThemeMode(String key) {
    final value = _readString(key);
    if (value == null) return ThemeMode.system;
    for (final mode in ThemeMode.values) {
      if (mode.name == value) return mode;
    }
    return ThemeMode.system;
  }
}
