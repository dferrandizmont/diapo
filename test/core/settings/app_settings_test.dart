import 'package:diapo/core/settings/app_settings.dart';
import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the defaults', () {
    test('are the ones of a fresh install', () {
      const settings = AppSettings.defaults;

      expect(settings.cameraSounds, isTrue);
      expect(settings.saveOriginal, isFalse);
      expect(settings.saveLocation, isFalse);
      expect(settings.grid, isFalse);
      expect(settings.level, isFalse);
      expect(settings.dateStampStyle, DateStampStyle.yearFirst);
      expect(settings.defaultFilmId, 'verano-98');
      expect(settings.themeMode, ThemeMode.system);
      expect(settings.localeOverride, isNull);
    });

    test('the date of the photo is stamped the year first', () {
      expect(DateStampStyle.yearFirst.storageValue, 'yy m d');
      expect(DateStampStyle.dayFirst.storageValue, 'd m yy');
    });
  });

  group('copyWith', () {
    test('changes only the field it is given', () {
      const settings = AppSettings.defaults;

      final changed = settings.copyWith(grid: true);

      expect(changed.grid, isTrue);
      expect(changed.cameraSounds, settings.cameraSounds);
      expect(changed.level, settings.level);
      expect(changed.themeMode, settings.themeMode);
    });

    test('removes the language of the app when it is asked to', () {
      const settings = AppSettings(localeOverride: Locale('ca'));

      expect(
        settings.copyWith(clearLocaleOverride: true).localeOverride,
        isNull,
      );
      expect(settings.copyWith().localeOverride, Locale('ca'));
    });
  });

  group('toJson and fromJson', () {
    test('a round trip gives the same settings', () {
      const settings = AppSettings(
        cameraSounds: false,
        saveOriginal: true,
        saveLocation: true,
        grid: true,
        level: true,
        dateStampStyle: DateStampStyle.dayFirst,
        defaultFilmId: 'invierno-84',
        themeMode: ThemeMode.dark,
        localeOverride: Locale('en'),
      );

      expect(AppSettings.fromJson(settings.toJson()), settings);
    });

    test('a value that is not there falls back to the default', () {
      final settings = AppSettings.fromJson(const <String, Object?>{});

      expect(settings, AppSettings.defaults);
    });

    test('a value that is corrupt falls back to the default', () {
      final settings = AppSettings.fromJson(const <String, Object?>{
        'cameraSounds': 'yes',
        'saveOriginal': 'true',
        'dateStampStyle': 'dd mm yyyy',
        'defaultFilmId': '',
        'themeMode': 'sepia',
        'localeOverride': 'fr',
      });

      expect(settings.cameraSounds, isTrue);
      expect(settings.saveOriginal, isFalse);
      expect(settings.dateStampStyle, DateStampStyle.yearFirst);
      expect(settings.defaultFilmId, 'verano-98');
      expect(settings.themeMode, ThemeMode.system);
      expect(settings.localeOverride, isNull);
    });

    test('a language the app does not speak is not kept', () {
      final settings = AppSettings.fromJson(const <String, Object?>{
        'localeOverride': 'de',
      });

      expect(settings.localeOverride, isNull);
    });

    test('a language the app speaks is kept', () {
      final settings = AppSettings.fromJson(const <String, Object?>{
        'localeOverride': 'ca',
      });

      expect(settings.localeOverride, Locale('ca'));
    });
  });
}
