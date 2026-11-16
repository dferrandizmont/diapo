import 'package:diapo/core/settings/app_settings.dart';
import 'package:diapo/core/settings/settings_provider.dart';
import 'package:diapo/core/settings/settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('the flag of the first-use flow', () {
    test('is not set on a fresh install', () {
      expect(AppSettings.defaults.onboardingSeen, isFalse);
    });

    test('copyWith changes it and nothing else', () {
      final seen = AppSettings.defaults.copyWith(onboardingSeen: true);

      expect(seen.onboardingSeen, isTrue);
      expect(seen, isNot(AppSettings.defaults));
      expect(seen.copyWith(grid: true).onboardingSeen, isTrue);
      expect(seen.copyWith(onboardingSeen: false), AppSettings.defaults);
    });

    test('survives the export and import of the settings', () {
      final seen = AppSettings.defaults.copyWith(onboardingSeen: true);

      expect(seen.toJson()['onboardingSeen'], isTrue);
      expect(AppSettings.fromJson(seen.toJson()), seen);
    });

    test('a corrupt value reads as not seen', () {
      final settings = AppSettings.fromJson(const <String, Object?>{
        'onboardingSeen': 'yes',
      });

      expect(settings.onboardingSeen, isFalse);
    });

    test('is written to the device and read back', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = SettingsRepository(preferences);
      expect(repository.load().onboardingSeen, isFalse);

      await repository.save(
        AppSettings.defaults.copyWith(onboardingSeen: true),
      );

      expect(preferences.getBool('carrete.settings.onboardingSeen'), isTrue);
      expect(repository.load().onboardingSeen, isTrue);
    });

    test('a value of the wrong type reads as not seen', () async {
      SharedPreferences.setMockInitialValues({
        'carrete.settings.onboardingSeen': 'yes',
      });
      final repository = SettingsRepository(
        await SharedPreferences.getInstance(),
      );

      expect(repository.load().onboardingSeen, isFalse);
    });

    test('the notifier sets it, stores it and can clear it', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(settingsProvider.notifier);

      notifier.setOnboardingSeen(true);
      expect(container.read(settingsProvider).onboardingSeen, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(SettingsRepository(preferences).load().onboardingSeen, isTrue);

      notifier.setOnboardingSeen(false);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(SettingsRepository(preferences).load().onboardingSeen, isFalse);
    });

    test('setting another value keeps it', () async {
      SharedPreferences.setMockInitialValues({
        'carrete.settings.onboardingSeen': true,
      });
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(container.dispose);

      container.read(settingsProvider.notifier).setGrid(true);

      expect(container.read(settingsProvider).onboardingSeen, isTrue);
    });
  });
}
