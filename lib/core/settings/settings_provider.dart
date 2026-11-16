import 'dart:async';

import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../location/location_provider.dart';
import 'app_settings.dart';
import 'settings_repository.dart';

export '../../location/location_provider.dart'
    show locationPermissionProvider, LocationPermission;

/// The preferences of the device. `main` overrides it with the instance it
/// loads before the app starts; the tests override it with a mock.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden with the instance loaded '
    'by SharedPreferences.getInstance().',
  ),
);

/// The settings of the app, stored in the preferences of the device.
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(sharedPreferencesProvider)),
);

/// The settings of the app.
///
/// Read them with `ref.watch(settingsProvider)`; change them with the setters
/// of [SettingsNotifier], which write them to the device as well.
final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

/// Changes the settings of the app, one field at a time.
class SettingsNotifier extends Notifier<AppSettings> {
  int _revision = 0;

  @override
  AppSettings build() => ref.watch(settingsRepositoryProvider).load();

  /// Turns the shutter and film-advance sounds on or off.
  void setCameraSounds(bool value) =>
      _update((current) => current.copyWith(cameraSounds: value));

  /// Turns the small vibrations of the camera on or off.
  void setHaptics(bool value) =>
      _update((current) => current.copyWith(haptics: value));

  /// Keeps the photo without the film look on or off.
  void setSaveOriginal(bool value) =>
      _update((current) => current.copyWith(saveOriginal: value));

  /// Saves where every photo was taken on or off.
  void setSaveLocation(bool value) =>
      _update((current) => current.copyWith(saveLocation: value));

  /// Call only for an explicit opt-in action. Loading or restoring settings
  /// must use setSaveLocation, which never opens a permission dialog.
  Future<LocationPermission> requestLocationPermission() =>
      ref.read(locationControllerProvider).refreshPermission(request: true);

  /// Shows the grid of thirds on the viewfinder on or off.
  void setGrid(bool value) =>
      _update((current) => current.copyWith(grid: value));

  /// Shows the level on the viewfinder on or off.
  void setLevel(bool value) =>
      _update((current) => current.copyWith(level: value));

  /// Changes how the date is stamped on the photo.
  void setDateStampStyle(DateStampStyle value) =>
      _update((current) => current.copyWith(dateStampStyle: value));

  /// Changes the film the camera loads by default. An empty id is ignored:
  /// the camera always needs a film.
  void setDefaultFilmId(String value) {
    final filmId = value.trim();
    if (filmId.isEmpty) return;
    _update((current) => current.copyWith(defaultFilmId: filmId));
  }

  /// Changes the theme of the screens that are not the camera.
  void setThemeMode(ThemeMode value) =>
      _update((current) => current.copyWith(themeMode: value));

  /// Changes the language of the app; null follows the language of the
  /// device.
  void setLocaleOverride(Locale? value) => _update(
    (current) => value == null
        ? current.copyWith(clearLocaleOverride: true)
        : current.copyWith(localeOverride: value),
  );

  /// Remembers that the first-use flow was finished or skipped (or, with
  /// false, shows it again before the camera).
  void setOnboardingSeen(bool value) =>
      _update((current) => current.copyWith(onboardingSeen: value));

  void _update(AppSettings Function(AppSettings) change) {
    final revision = ++_revision;
    state = change(state);
    final repository = ref.read(settingsRepositoryProvider);
    unawaited(
      repository
          .update(change)
          .then(
            (_) {
              if (ref.mounted && revision == _revision) {
                state = repository.load();
              }
            },
            onError: (Object _, StackTrace _) {
              if (ref.mounted && revision == _revision) {
                state = repository.load();
              }
            },
          ),
    );
  }
}
