import 'package:diapo/core/settings/app_settings.dart';
import 'package:diapo/core/settings/settings_provider.dart';
import 'package:diapo/core/settings/settings_repository.dart';
import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'the setters change the settings and write them to the device',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(container.dispose);

      expect(container.read(settingsProvider), AppSettings.defaults);

      final notifier = container.read(settingsProvider.notifier);
      notifier.setGrid(true);
      notifier.setThemeMode(ThemeMode.dark);
      notifier.setLocaleOverride(const Locale('ca'));
      notifier.setDateStampStyle(DateStampStyle.dayFirst);

      final settings = container.read(settingsProvider);
      expect(settings.grid, isTrue);
      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.localeOverride, const Locale('ca'));
      expect(settings.dateStampStyle, DateStampStyle.dayFirst);

      // The settings are written to the device (the write is not awaited).
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final saved = SettingsRepository(preferences).load();
      expect(saved.grid, isTrue);
      expect(saved.themeMode, ThemeMode.dark);
      expect(saved.localeOverride, const Locale('ca'));
      expect(saved.dateStampStyle, DateStampStyle.dayFirst);
    },
  );

  test('a film with no name is not saved', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    container.read(settingsProvider.notifier).setDefaultFilmId('  ');

    expect(container.read(settingsProvider).defaultFilmId, 'verano-98');
  });
}
