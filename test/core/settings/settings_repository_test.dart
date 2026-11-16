import 'package:diapo/core/settings/app_settings.dart';
import 'package:diapo/core/settings/settings_repository.dart';
import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SettingsRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = SettingsRepository(await SharedPreferences.getInstance());
  });

  test('a device with nothing stored has the default settings', () {
    expect(repository.load(), AppSettings.defaults);
  });

  test('the settings that are saved are the ones that are read', () async {
    const settings = AppSettings(
      cameraSounds: false,
      saveOriginal: true,
      saveLocation: true,
      grid: true,
      level: true,
      dateStampStyle: DateStampStyle.dayFirst,
      defaultFilmId: 'invierno-84',
      themeMode: ThemeMode.light,
      localeOverride: Locale('en'),
    );

    await repository.save(settings);

    expect(repository.load(), settings);
  });

  test('the language of the app can be taken back', () async {
    await repository.save(const AppSettings(localeOverride: Locale('ca')));
    expect(repository.load().localeOverride, Locale('ca'));

    await repository.save(
      const AppSettings(localeOverride: Locale('ca'))
          .copyWith(clearLocaleOverride: true),
    );
    expect(repository.load().localeOverride, isNull);
  });

  test('a value that is corrupt falls back to the default', () async {
    // The keys are the ones of the repository; a value of the wrong type
    // (or a value the app does not know) reads as "not stored".
    SharedPreferences.setMockInitialValues({
      'carrete.settings.cameraSounds': 'yes',
      'carrete.settings.grid': 1,
      'carrete.settings.dateStampStyle': 'dd mm yyyy',
      'carrete.settings.themeMode': 'sepia',
      'carrete.settings.localeOverride': 'de',
      'carrete.settings.defaultFilmId': '',
    });
    final corrupt = SettingsRepository(await SharedPreferences.getInstance());

    final settings = corrupt.load();

    expect(settings.cameraSounds, isTrue);
    expect(settings.grid, isFalse);
    expect(settings.dateStampStyle, DateStampStyle.yearFirst);
    expect(settings.themeMode, ThemeMode.system);
    expect(settings.localeOverride, isNull);
    expect(settings.defaultFilmId, 'verano-98');
  });
}
