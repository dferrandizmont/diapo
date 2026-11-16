import 'dart:convert';

import 'package:carrete/core/backup/settings_backup_codec.dart';
import 'package:carrete/core/settings/app_settings.dart';
import 'package:carrete/core/settings/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('the vibration setting', () {
    test('is on on a fresh install and apart from the sounds', () {
      expect(AppSettings.defaults.haptics, isTrue);
      expect(
        AppSettings.defaults.copyWith(cameraSounds: false).haptics,
        isTrue,
      );
      expect(
        AppSettings.defaults.copyWith(haptics: false).cameraSounds,
        isTrue,
      );
    });

    test('goes through the data of the settings and back', () {
      final off = AppSettings.defaults.copyWith(haptics: false);
      expect(off.toJson()['haptics'], isFalse);
      expect(AppSettings.fromJson(off.toJson()), off);
      expect(off, isNot(AppSettings.defaults));
      expect(off.hashCode, isNot(AppSettings.defaults.hashCode));
    });

    test('a missing or corrupt value reads as on', () {
      expect(AppSettings.fromJson(const {}).haptics, isTrue);
      expect(AppSettings.fromJson(const {'haptics': 'no'}).haptics, isTrue);
    });

    test('is stored on the device and read back', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = SettingsRepository(preferences);
      await repository.save(AppSettings.defaults.copyWith(haptics: false));
      expect(preferences.getBool('carrete.settings.haptics'), isFalse);
      expect(repository.load().haptics, isFalse);
    });

    test('a value of the wrong type reads as on', () async {
      SharedPreferences.setMockInitialValues({
        'carrete.settings.haptics': 'off',
      });
      final repository = SettingsRepository(
        await SharedPreferences.getInstance(),
      );
      expect(repository.load().haptics, isTrue);
    });

    test('travels in the export of the settings, like the sounds', () {
      final codec = SettingsBackupCodec(knownFilmIds: {'verano-98'});
      final bytes = codec.encode(
        appVersion: '0.1.0',
        settings: AppSettings.defaults.copyWith(haptics: false).toJson(),
        tuning: const {},
      );
      expect(utf8.decode(bytes), contains('"haptics":false'));
      expect(codec.decode(bytes).settings['haptics'], isFalse);
    });

    test('an old export without it still imports, with vibration on', () {
      final codec = SettingsBackupCodec(knownFilmIds: {'verano-98'});
      final bytes = codec.encode(
        appVersion: '0.1.0',
        settings: const {'cameraSounds': false},
        tuning: const {},
      );
      final settings = AppSettings.fromJson(codec.decode(bytes).settings);
      expect(settings.cameraSounds, isFalse);
      expect(settings.haptics, isTrue);
    });
  });
}
