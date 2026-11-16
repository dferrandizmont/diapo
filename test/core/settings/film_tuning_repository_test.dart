import 'dart:convert';

import 'package:diapo/core/settings/film_tuning.dart';
import 'package:diapo/core/settings/film_tuning_provider.dart';
import 'package:diapo/core/settings/film_tuning_repository.dart';
import 'package:diapo/core/settings/settings_provider.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _prefs([
  Map<String, Object> values = const {},
]) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  test('cinema bands preserve true, false and recipe inheritance', () async {
    final repo = FilmTuningRepository(await _prefs());
    final recipe = Recipe.fromJson({
      'id': 'cine',
      'defaults': {'cinemaBands': true},
    });
    for (final value in [true, false, null]) {
      final tuning = FilmTuning.defaults.copyWith(cinemaBands: value);
      expect(FilmTuning.fromJson(tuning.toJson()), tuning);
      expect(tuning.overrides.cinemaBands, value);
      expect(cinemaBandsFor(recipe, tuning), value ?? true);
      expect(tuning.copyWith(clearCinemaBands: true), FilmTuning.defaults);
      await repo.save({'cine': tuning});
      expect(repo.load()['cine'] ?? FilmTuning.defaults, tuning);
    }
    expect(FilmTuning.fromJson({}).cinemaBands, isNull);
    expect(FilmTuning.fromJson({'cinemaBands': 'yes'}).cinemaBands, isNull);
    expect(const FilmTuning(cinemaBands: false).isDefault, isFalse);
  });

  group('FilmTuning', () {
    test('the panel shows 0 to 100 with 50 as the recipe', () {
      expect(FilmTuning.multiplierOf(50), 1);
      expect(FilmTuning.multiplierOf(0), 0);
      expect(FilmTuning.multiplierOf(100), 2);
      expect(FilmTuning.displayOf(1), 50);
      expect(FilmTuning.displayOf(0), 0);
      expect(FilmTuning.displayOf(2), 100);
      for (var v = 0; v <= 100; v++) {
        expect(FilmTuning.displayOf(FilmTuning.multiplierOf(v)), v);
      }
    });

    test('values are clamped to 0..2', () {
      final t = FilmTuning.defaults.copyWith(grain: 5, vignette: -1);
      expect(t.grain, 2);
      expect(t.vignette, 0);
    });

    test('becomes the LookOverrides of the engine', () {
      final overrides = const FilmTuning(
        grain: 0.5,
        halation: 1.5,
        leak: 0,
        vignette: 2,
        dateStamp: true,
        format: FrameFormat.r1x1,
      ).overrides;
      expect(overrides.grain, 0.5);
      expect(overrides.halation, 1.5);
      expect(overrides.leak, 0);
      expect(overrides.vignette, 2);
      expect(overrides.dateStamp, isTrue);
      expect(overrides.format, FrameFormat.r1x1);
    });

    test('feeds resolve(): the multiplier scales the amount', () {
      final recipe = RecipeBook.parse(
        '{"schemaVersion":1,"recipesVersion":"2026.11.1","recipes":[{"id":"aa",'
        '"name":{"es":"a","ca":"a","en":"a"},'
        '"description":{"es":"a","ca":"a","en":"a"},'
        '"grain":{"amount":0.4,"size":1}}]}',
      ).recipes.first;
      final base = resolve(recipe);
      final tuned = resolve(
        recipe,
        overrides: const FilmTuning(grain: 0.5).overrides,
      );
      expect(tuned.grainAmount, closeTo(base.grainAmount * 0.5, 1e-9));
    });
  });

  group('FilmTuningRepository', () {
    test('nothing stored gives no tuning', () async {
      final repo = FilmTuningRepository(await _prefs());
      expect(repo.load(), isEmpty);
    });

    test('round trips the tuning of several films', () async {
      final prefs = await _prefs();
      final repo = FilmTuningRepository(prefs);
      await repo.save({
        'verano-98': const FilmTuning(
          grain: 0.2,
          leak: 1.8,
          dateStamp: true,
          format: FrameFormat.r16x9,
        ),
        'bn-clasico': const FilmTuning(vignette: 0),
      });

      final loaded = FilmTuningRepository(prefs).load();
      expect(loaded.keys, unorderedEquals(['verano-98', 'bn-clasico']));
      expect(loaded['verano-98']!.grain, 0.2);
      expect(loaded['verano-98']!.leak, 1.8);
      expect(loaded['verano-98']!.halation, 1);
      expect(loaded['verano-98']!.dateStamp, isTrue);
      expect(loaded['verano-98']!.format, FrameFormat.r16x9);
      expect(loaded['bn-clasico']!.vignette, 0);
      expect(loaded['bn-clasico']!.dateStamp, isNull);
      expect(loaded['bn-clasico']!.format, isNull);
    });

    test('films that match their recipe are not stored', () async {
      final prefs = await _prefs();
      final repo = FilmTuningRepository(prefs);
      await repo.save({'a': FilmTuning.defaults});
      expect(prefs.getString(FilmTuningRepository.storageKey), isNull);
    });

    test('corrupt JSON falls back to the defaults', () async {
      final repo = FilmTuningRepository(
        await _prefs({FilmTuningRepository.storageKey: '{not json'}),
      );
      expect(repo.load(), isEmpty);
    });

    test('JSON that is not a map falls back to the defaults', () async {
      for (final raw in ['[1,2]', '"text"', '42', 'null', '']) {
        final repo = FilmTuningRepository(
          await _prefs({FilmTuningRepository.storageKey: raw}),
        );
        expect(repo.load(), isEmpty, reason: raw);
      }
    });

    test('a value of the wrong type falls back to the defaults', () async {
      final repo = FilmTuningRepository(
        await _prefs({FilmTuningRepository.storageKey: 7}),
      );
      expect(repo.load(), isEmpty);
    });

    test('bad entries and bad fields are ignored one by one', () async {
      final repo = FilmTuningRepository(
        await _prefs({
          FilmTuningRepository.storageKey: jsonEncode({
            'broken': 'text',
            'also-broken': [1],
            'partly': {
              'grain': 'lots',
              'halation': 9,
              'leak': -3,
              'vignette': 0.5,
              'dateStamp': 'yes',
              'format': '5:4',
            },
          }),
        }),
      );
      final loaded = repo.load();
      expect(loaded.keys, ['partly']);
      final t = loaded['partly']!;
      expect(t.grain, 1);
      expect(t.halation, 2);
      expect(t.leak, 0);
      expect(t.vignette, 0.5);
      expect(t.dateStamp, isNull);
      expect(t.format, isNull);
    });
  });

  group('filmTuningsProvider', () {
    test('a change is kept in memory and stored per film', () async {
      final prefs = await _prefs();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(filmTuningsProvider.notifier);
      notifier.update('verano-98', (t) => t.copyWith(grain: 0.4));
      notifier.update(
        'bn-clasico',
        (t) => t.copyWith(format: FrameFormat.r1x1),
      );

      expect(container.read(filmTuningsProvider)['verano-98']!.grain, 0.4);
      expect(notifier.of('desechable'), FilmTuning.defaults);
      await pumpEventQueue();

      final stored = FilmTuningRepository(prefs).load();
      expect(stored['verano-98']!.grain, 0.4);
      expect(stored['bn-clasico']!.format, FrameFormat.r1x1);

      // A new container (a new launch of the app) sees the same tuning.
      final next = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(next.dispose);
      expect(next.read(filmTuningsProvider)['verano-98']!.grain, 0.4);
    });

    test('returning a film to its recipe forgets the entry', () async {
      final prefs = await _prefs();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(filmTuningsProvider.notifier);
      notifier.update('a', (t) => t.copyWith(grain: 0.4));
      notifier.update('a', (t) => t.copyWith(grain: 1));
      expect(container.read(filmTuningsProvider), isEmpty);
      await pumpEventQueue();
      expect(prefs.getString(FilmTuningRepository.storageKey), isNull);
    });
  });
}
