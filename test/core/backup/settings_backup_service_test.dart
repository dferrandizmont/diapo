import 'dart:async';
import 'dart:convert';

import 'package:carrete/core/backup/settings_backup_codec.dart';
import 'package:carrete/core/database/rolls_dao.dart';
import 'package:carrete/core/backup/settings_backup_files.dart';
import 'package:carrete/core/backup/settings_backup_service.dart';
import 'package:carrete/core/settings/app_settings.dart';
import 'package:carrete/core/settings/film_tuning.dart';
import 'package:carrete/core/settings/film_tuning_provider.dart';
import 'package:carrete/core/settings/film_tuning_repository.dart';
import 'package:carrete/core/settings/settings_provider.dart';
import 'package:carrete/core/settings/settings_repository.dart';
import 'package:carrete/core/settings/settings_snapshot.dart';
import 'package:carrete/render/film_resources.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/test_database.dart';
import 'settings_backup_codec_test.dart' show backupError, document;

class FakeSettingsBackupFiles implements SettingsBackupFiles {
  Uint8List? input;
  Uint8List? output;
  String? name;
  bool save = true;
  Completer<Uint8List?>? pending;

  @override
  Future<Uint8List?> read() async => pending == null ? input : pending!.future;

  @override
  Future<bool> write({
    required String suggestedName,
    required Uint8List bytes,
  }) async {
    name = suggestedName;
    output = bytes;
    return save;
  }

  void setDocument({Object? settings = const {}, Object? tuning = const {}}) {
    input = Uint8List.fromList(document(settings: settings, tuning: tuning));
  }
}

/// Models Android commit: native and Dart memory change even on a disk failure.
class FailingPreferences implements SharedPreferences {
  FailingPreferences(
    this.delegate, {
    required this.reloadFails,
    this.restoreFails = false,
    this.writeThrows = false,
  });
  final SharedPreferences delegate;
  final bool reloadFails;
  final bool restoreFails;
  final bool writeThrows;
  int writes = 0;
  int reloads = 0;

  @override
  String? getString(String key) => delegate.getString(key);
  @override
  bool? getBool(String key) => delegate.getBool(key);
  @override
  Future<bool> setString(String key, String value) async {
    await delegate.setString(key, value);
    writes++;
    if (writes == 1 && writeThrows) throw StateError('Commit failed');
    return writes != 1 && !restoreFails;
  }

  @override
  Future<bool> remove(String key) async {
    await delegate.remove(key);
    return !restoreFails;
  }

  @override
  Future<void> reload() async {
    reloads++;
    if (reloadFails) throw StateError('Reload failed');
    // Real Android reload reads the already changed native memory.
    await delegate.reload();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SuspendedPreferences implements SharedPreferences {
  SuspendedPreferences(this.delegate);
  final SharedPreferences delegate;
  final entered = Completer<void>();
  final release = Completer<void>();
  bool suspended = false;

  @override
  String? getString(String key) => delegate.getString(key);
  @override
  bool? getBool(String key) => delegate.getBool(key);
  @override
  Future<bool> setBool(String key, bool value) => delegate.setBool(key, value);
  @override
  Future<bool> setString(String key, String value) async {
    if (key == SettingsSnapshot.storageKey && !suspended) {
      suspended = true;
      // Both caches change before the disk confirms the write.
      await delegate.setString(key, value);
      entered.complete();
      await release.future;
      return true;
    }
    return delegate.setString(key, value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final codec = SettingsBackupCodec(knownFilmIds: {'verano-98', 'bn-clasico'});
  late SharedPreferences preferences;
  late ProviderContainer container;
  late FakeSettingsBackupFiles files;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'carrete.settings.onboardingSeen': true,
      'carrete.disposable.rollId': 42,
      'unrelated': 'keep',
    });
    preferences = await SharedPreferences.getInstance();
    files = FakeSettingsBackupFiles();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        settingsBackupFilesProvider.overrideWithValue(files),
        recipeBookProvider.overrideWith(
          (ref) async => const RecipeBook(
            schemaVersion: 1,
            recipesVersion: 'test',
            recipes: [
              Recipe(
                id: 'verano-98',
                name: LocalizedText(es: '', ca: '', en: ''),
                description: LocalizedText(es: '', ca: '', en: ''),
              ),
              Recipe(
                id: 'bn-clasico',
                name: LocalizedText(es: '', ca: '', en: ''),
                description: LocalizedText(es: '', ca: '', en: ''),
              ),
            ],
          ),
        ),
      ],
    );
  });
  tearDown(() => container.dispose());

  test(
    'export uses current data, safe filename and no private preferences',
    () async {
      await SettingsRepository(preferences)
          .save(const AppSettings(grid: true, onboardingSeen: true));
      await FilmTuningRepository(preferences)
          .save({'verano-98': const FilmTuning(grain: 0.3)});
      final service = SettingsBackupService(
        files: files,
        codec: () async => codec,
        now: () => DateTime(2026, 2, 3),
        loadSettings: () => SettingsRepository(preferences).load(),
        loadTuning: () => FilmTuningRepository(preferences).load(),
        commit: (_, _) async => fail('Export cannot write preferences'),
      );
      expect(await service.exportSettings(), isTrue);
      expect(files.name, 'diapo-ajustes-2026-02-03.json');
      final data = codec.decode(files.output!);
      expect(data.settings['grid'], true);
      expect(data.tuning['verano-98']!['grain'], 0.3);
      expect(data.tuning['verano-98']!.containsKey('dateStamp'), isTrue);
      expect(data.tuning['verano-98']!['dateStamp'], isNull);
      expect(data.tuning['bn-clasico'], {
        'grain': 1,
        'halation': 1,
        'leak': 1,
        'vignette': 1,
        'dateStamp': null,
        'cinemaBands': null,
        'format': null,
      });
      expect(utf8.decode(files.output!), isNot(contains('onboarding')));
      expect(utf8.decode(files.output!), isNot(contains('keep')));
      files.save = false;
      expect(await service.exportSettings(), false);
    },
  );

  test(
    'roll names are data, not settings: the export leaves them out',
    () async {
      // A roll with a name sits in the database of the app.
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final dao = RollsDao(database);
      final roll = await dao.openRoll(filmId: 'verano-98', length: 12);
      await dao.renameRoll(roll.id, 'Boda de Laia');
      await SettingsRepository(preferences)
          .save(const AppSettings(grid: true, onboardingSeen: true));
      final service = SettingsBackupService(
        files: files,
        codec: () async => codec,
        now: () => DateTime(2026, 2, 3),
        loadSettings: () => SettingsRepository(preferences).load(),
        loadTuning: () => FilmTuningRepository(preferences).load(),
        commit: (_, _) async => fail('Export cannot write preferences'),
      );
      expect(await service.exportSettings(), isTrue);
      expect(utf8.decode(files.output!), isNot(contains('Boda de Laia')));
      // The export only ever carries the settings and tunings it lists.
      expect(SettingsBackupCodec.settingKeys, isNot(contains('name')));
      expect(SettingsBackupCodec.settingKeys, isNot(contains('rollName')));
      expect(SettingsBackupCodec.tuningKeys, isNot(contains('name')));
      // Even a name handed to the codec is dropped.
      final bytes = codec.encode(
        appVersion: 'test',
        settings: {'grid': true, 'rollName': 'Boda de Laia', 'name': 'x'},
        tuning: const {},
      );
      expect(utf8.decode(bytes), isNot(contains('Boda')));
    },
  );

  test(
    'backup export and import preserve explicit cinema band choices',
    () async {
      final service = container.read(settingsBackupProvider);
      for (final value in [true, false]) {
        container
            .read(filmTuningsProvider.notifier)
            .update('verano-98', (t) => t.copyWith(cinemaBands: value));
        await pumpEventQueue();
        await service.exportSettings();
        expect(
          codec.decode(files.output!).tuning['verano-98']!['cinemaBands'],
          value,
        );
        files.input = files.output;
        container
            .read(filmTuningsProvider.notifier)
            .update('verano-98', (t) => t.copyWith(cinemaBands: !value));
        await pumpEventQueue();
        await service.importSettings();
        expect(
          container.read(filmTuningsProvider)['verano-98']!.cinemaBands,
          value,
        );
      }
    },
  );

  test('restoring a full export clears destination-only tuning', () async {
    final service = container.read(settingsBackupProvider);
    await service.exportSettings();
    files.input = files.output;
    container
        .read(filmTuningsProvider.notifier)
        .update(
          'verano-98',
          (t) => t.copyWith(
            grain: 0.4,
            dateStamp: true,
            cinemaBands: true,
            format: FrameFormat.r1x1,
          ),
        );
    container
        .read(filmTuningsProvider.notifier)
        .update('bn-clasico', (t) => t.copyWith(halation: 2));
    await pumpEventQueue();
    final result = await service.importSettings();
    expect(result!.appliedFilmIds, ['verano-98', 'bn-clasico']);
    expect(container.read(filmTuningsProvider), isEmpty);
    await preferences.reload();
    expect(FilmTuningRepository(preferences).load(), isEmpty);
  });

  test(
    'export waits for queued ordinary edits before capturing values',
    () async {
      container.read(settingsProvider.notifier).setGrid(true);
      container.read(settingsProvider.notifier).setSaveOriginal(true);
      container
          .read(filmTuningsProvider.notifier)
          .update('verano-98', (t) => t.copyWith(grain: 0.2));
      expect(
        await container.read(settingsBackupProvider).exportSettings(),
        true,
      );
      final data = codec.decode(files.output!);
      expect(data.settings['grid'], true);
      expect(data.settings['saveOriginal'], true);
      expect(data.tuning['verano-98']!['grain'], 0.2);
    },
  );

  test('import refreshes watched providers and survives reload', () async {
    await SettingsRepository(preferences)
        .save(const AppSettings(level: true, onboardingSeen: true));
    await FilmTuningRepository(preferences).save({
      'verano-98': const FilmTuning(
        grain: 0.3,
        leak: 1.8,
        dateStamp: true,
        format: FrameFormat.r1x1,
      ),
      'bn-clasico': const FilmTuning(vignette: 0),
    });
    final settingsEvents = <AppSettings>[];
    final tuningEvents = <Map<String, FilmTuning>>[];
    container.listen(
      settingsProvider,
      (_, next) => settingsEvents.add(next),
      fireImmediately: true,
    );
    container.listen(
      filmTuningsProvider,
      (_, next) => tuningEvents.add(next),
      fireImmediately: true,
    );
    files.setDocument(
      settings: {'grid': true, 'localeOverride': 'ca', 'onboardingSeen': false},
      tuning: {
        'verano-98': {'grain': 2, 'dateStamp': null, 'format': null},
        'future-film': null,
      },
    );
    final result = await container
        .read(settingsBackupProvider)
        .importSettings();
    final settings = container.read(settingsProvider);
    final tuning = container.read(filmTuningsProvider);
    expect(result!.appliedSettings, ['grid', 'localeOverride']);
    expect(result.appliedFilmIds, ['verano-98']);
    expect(result.skippedFilmIds, ['future-film']);
    expect(settings.grid, true);
    expect(settings.level, true);
    expect(settings.localeOverride?.languageCode, 'ca');
    expect(settings.onboardingSeen, true);
    expect(tuning['verano-98'], const FilmTuning(grain: 2, leak: 1.8));
    expect(tuning['bn-clasico'], const FilmTuning(vignette: 0));
    expect(settingsEvents.last, settings);
    expect(tuningEvents.last, tuning);
    expect(settingsEvents, hasLength(2));
    expect(tuningEvents, hasLength(2));
    expect(preferences.getInt('carrete.disposable.rollId'), 42);
    expect(preferences.getString('unrelated'), 'keep');
    await preferences.reload();
    expect(SettingsRepository(preferences).load(), settings);
    expect(FilmTuningRepository(preferences).load(), tuning);
    expect(
      preferences.getString(SettingsSnapshot.storageKey),
      isNot(contains('onboardingSeen')),
    );
  });

  test(
    'normal edits after import preserve the other section and onboarding',
    () async {
      files.setDocument(
        settings: {'grid': true},
        tuning: {
          'verano-98': {'grain': 0.4},
        },
      );
      await container.read(settingsBackupProvider).importSettings();
      container.read(settingsProvider.notifier).setLevel(true);
      container
          .read(filmTuningsProvider.notifier)
          .update('verano-98', (t) => t.copyWith(leak: 0.2));
      await pumpEventQueue();
      await preferences.reload();
      expect(SettingsRepository(preferences).load().grid, true);
      expect(SettingsRepository(preferences).load().level, true);
      expect(SettingsRepository(preferences).load().onboardingSeen, true);
      expect(
        FilmTuningRepository(preferences).load()['verano-98'],
        const FilmTuning(grain: 0.4, leak: 0.2),
      );
      container.read(settingsProvider.notifier).setOnboardingSeen(false);
      await pumpEventQueue();
      expect(SettingsRepository(preferences).load().onboardingSeen, false);
    },
  );

  test(
    'one invalid known field rejects every otherwise valid change',
    () async {
      final original = container.read(settingsProvider);
      final originalTuning = container.read(filmTuningsProvider);
      for (final bad in [
        document(
          settings: {'grid': true},
          tuning: {
            'verano-98': {'grain': 0.2},
            'bn-clasico': {'leak': 3},
          },
        ),
        document(settings: {'grid': true, 'level': 'yes'}),
        List.filled(SettingsBackupCodec.maxBytes + 1, 32),
      ]) {
        files.input = Uint8List.fromList(bad);
        await expectLater(
          container.read(settingsBackupProvider).importSettings(),
          throwsA(isA<SettingsBackupException>()),
        );
        expect(container.read(settingsProvider), original);
        expect(container.read(filmTuningsProvider), originalTuning);
        expect(preferences.getString(SettingsSnapshot.storageKey), isNull);
      }
    },
  );

  test(
    'empty patches and unknown films report without any persistence',
    () async {
      files.setDocument(
        settings: {'defaultFilmId': 'future'},
        tuning: {
          'future': {'grain': -20},
        },
      );
      final result = await container
          .read(settingsBackupProvider)
          .importSettings();
      expect(result!.appliedSettings, isEmpty);
      expect(result.appliedFilmIds, isEmpty);
      expect(result.skippedFilmIds, ['future']);
      expect(preferences.getString(SettingsSnapshot.storageKey), isNull);
    },
  );

  test('cancellation leaves all state alone', () async {
    expect(
      await container.read(settingsBackupProvider).importSettings(),
      isNull,
    );
    expect(preferences.getString(SettingsSnapshot.storageKey), isNull);
  });

  test(
    'second operation fails busy and the service recovers after cancellation',
    () async {
      files.pending = Completer<Uint8List?>();
      final service = container.read(settingsBackupProvider);
      final first = service.importSettings();
      await expectLater(
        service.exportSettings(),
        throwsA(backupError(BackupErrorCode.busy)),
      );
      files.pending!.complete(null);
      expect(await first, isNull);
      files.pending = null;
      expect(await service.exportSettings(), true);
    },
  );

  test(
    'settings edited during the picker are retained for missing fields',
    () async {
      files.pending = Completer<Uint8List?>();
      final first = container.read(settingsBackupProvider).importSettings();
      container.read(settingsProvider.notifier).setLevel(true);
      files.pending!.complete(
        Uint8List.fromList(document(settings: {'grid': true})),
      );
      await first;
      expect(container.read(settingsProvider).level, true);
      expect(container.read(settingsProvider).grid, true);
    },
  );

  test(
    'failed atomic write restores cached snapshot and does not notify',
    () async {
      for (final scenario in [
        (false, false),
        (false, true),
        (true, false),
        (true, true),
      ]) {
        final (initialSnapshot, reloadFails) = scenario;
        await preferences.remove(SettingsSnapshot.storageKey);
        if (initialSnapshot) {
          await preferences.setString(
            SettingsSnapshot.storageKey,
            jsonEncode({
              'settings': AppSettings.defaults.toJson(),
              'tuning': {'verano-98': const FilmTuning(grain: 0.4).toJson()},
            }),
          );
        }
        final failing = FailingPreferences(
          preferences,
          reloadFails: reloadFails,
        );
        final failedContainer = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(failing),
            settingsBackupFilesProvider.overrideWithValue(files),
            recipeBookProvider.overrideWith(
              (ref) => container.read(recipeBookProvider.future),
            ),
          ],
        );
        final beforeSettings = failedContainer.read(settingsProvider);
        final beforeTuning = failedContainer.read(filmTuningsProvider);
        var changes = 0;
        failedContainer.listen(settingsProvider, (_, _) => changes++);
        failedContainer.listen(filmTuningsProvider, (_, _) => changes++);
        files.setDocument(
          settings: {'grid': true},
          tuning: {
            'verano-98': {'grain': 2},
          },
        );
        await expectLater(
          failedContainer.read(settingsBackupProvider).importSettings(),
          throwsA(backupError(BackupErrorCode.storage)),
        );
        expect(SettingsRepository(failing).load(), beforeSettings);
        expect(FilmTuningRepository(failing).load(), beforeTuning);
        expect(changes, 0);
        expect(failing.reloads, 0);
        expect(
          preferences.getString(SettingsSnapshot.storageKey),
          initialSnapshot ? isNot(contains('"grid":true')) : isNull,
        );
        // A failed write releases the service busy guard.
        expect(
          await failedContainer.read(settingsBackupProvider).exportSettings(),
          true,
        );
        failedContainer.dispose();
      }
    },
  );

  test(
    'unconfirmed rollback retains confirmed reads and prevents later writes',
    () async {
      final failing = FailingPreferences(
        preferences,
        reloadFails: true,
        restoreFails: true,
      );
      final store = SettingsSnapshot(failing);
      final before = SettingsRepository(failing).load();
      await expectLater(
        store.write({
          'settings': {'grid': true},
          'tuning': {},
        }),
        throwsStateError,
      );
      expect(SettingsRepository(failing).load(), before);
      final writes = failing.writes;
      await expectLater(
        store.write({
          'settings': {'grid': true},
          'tuning': {},
        }),
        throwsStateError,
      );
      expect(failing.writes, writes);
      expect(failing.reloads, 0);
    },
  );

  test(
    'a throwing commit explicitly restores the previous snapshot too',
    () async {
      final failing = FailingPreferences(
        preferences,
        reloadFails: true,
        writeThrows: true,
      );
      final store = SettingsSnapshot(failing);
      await expectLater(
        store.write({
          'settings': {'grid': true},
          'tuning': {},
        }),
        throwsStateError,
      );
      expect(preferences.getString(SettingsSnapshot.storageKey), isNull);
      expect(store.read(), isNull);
      expect(failing.reloads, 0);
      // A confirmed rollback permits a later successful write.
      await store.write({
        'settings': {'grid': true},
        'tuning': {},
      });
      expect(SettingsRepository(failing).load().grid, true);
    },
  );

  test(
    'edits queued during import use the confirmed imported settings and tuning',
    () async {
      // Initialize the snapshot so only its import write is suspended.
      await SettingsSnapshot(preferences).write({
        'settings': AppSettings.defaults.toJson(),
        'tuning': <String, Object?>{},
      });
      final suspended = SuspendedPreferences(preferences);
      final active = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(suspended),
          settingsBackupFilesProvider.overrideWithValue(files),
          recipeBookProvider.overrideWith(
            (ref) => container.read(recipeBookProvider.future),
          ),
        ],
      );
      addTearDown(active.dispose);
      active.read(settingsProvider);
      active.read(filmTuningsProvider);
      files.setDocument(
        settings: {'grid': true, 'themeMode': 'dark'},
        tuning: {
          'verano-98': {'grain': 0.3, 'leak': 1.7},
        },
      );
      final importing = active.read(settingsBackupProvider).importSettings();
      await suspended.entered.future;
      expect(SettingsRepository(suspended).load().grid, false);
      active.read(settingsProvider.notifier).setLevel(true);
      active
          .read(filmTuningsProvider.notifier)
          .update('verano-98', (t) => t.copyWith(grain: 0.8));
      suspended.release.complete();
      await importing;
      await pumpEventQueue();
      final settings = active.read(settingsProvider);
      expect(settings.grid, true);
      expect(settings.themeMode.name, 'dark');
      expect(settings.level, true);
      expect(
        active.read(filmTuningsProvider)['verano-98'],
        const FilmTuning(grain: 0.8, leak: 1.7),
      );
      expect(SettingsRepository(suspended).load(), settings);
      await preferences.reload();
      final fresh = SuspendedPreferences(preferences);
      expect(SettingsRepository(fresh).load(), settings);
      expect(
        FilmTuningRepository(fresh).load()['verano-98'],
        const FilmTuning(grain: 0.8, leak: 1.7),
      );
    },
  );

  test(
    'privacy switches require the user only for false to true changes',
    () async {
      final service = container.read(settingsBackupProvider);
      files.setDocument(
        settings: {'saveLocation': true, 'saveOriginal': true, 'grid': true},
      );
      final blocked = (await service.importSettings())!;
      expect(blocked.needsUserSettings, ['saveLocation', 'saveOriginal']);
      expect(blocked.appliedSettings, ['grid']);
      expect(container.read(settingsProvider).saveLocation, false);
      expect(container.read(settingsProvider).saveOriginal, false);
      container.read(settingsProvider.notifier).setSaveLocation(true);
      container.read(settingsProvider.notifier).setSaveOriginal(true);
      await pumpEventQueue();
      final allowed = (await service.importSettings())!;
      expect(allowed.needsUserSettings, isEmpty);
      expect(
        allowed.appliedSettings,
        containsAll(['saveLocation', 'saveOriginal']),
      );
      files.setDocument(
        settings: {'saveLocation': false, 'saveOriginal': false},
      );
      final disabling = (await service.importSettings())!;
      expect(disabling.needsUserSettings, isEmpty);
      expect(container.read(settingsProvider).saveLocation, false);
      expect(container.read(settingsProvider).saveOriginal, false);
    },
  );

  test('the import is announced from its first step to its end', () async {
    var active = 0;
    final seen = <int>[];
    final service = SettingsBackupService(
      files: files,
      codec: () async => codec,
      loadSettings: () => AppSettings.defaults,
      loadTuning: () => {},
      commit: (_, _) async => seen.add(active),
      guardImport: <T>(Future<T> Function() action) async {
        active++;
        try {
          return await action();
        } finally {
          active--;
        }
      },
    );

    // While the file is being picked and read.
    files.pending = Completer<Uint8List?>();
    final reading = service.importSettings();
    await pumpEventQueue();
    expect(active, 1);
    // Cancelled: released.
    files.pending!.complete(null);
    expect(await reading, isNull);
    expect(active, 0);

    // A file that does not validate: released.
    files.pending = null;
    files.input = Uint8List.fromList(utf8.encode('not a backup'));
    await expectLater(service.importSettings(), throwsA(isA<Object>()));
    expect(active, 0);

    // A good one: held while it is committed, released after.
    files.setDocument(settings: {'grid': true});
    await service.importSettings();
    expect(seen, [1]);
    expect(active, 0);
  });

  test('provider storage errors release the Dart busy guard', () async {
    const channel = MethodChannel('carrete/system');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final service = SettingsBackupService(
      files: const SystemSettingsBackupFiles(),
      codec: () async => codec,
      loadSettings: () => AppSettings.defaults,
      loadTuning: () => {},
      commit: (_, _) async {},
    );
    for (final error in ['storage', 'interrupted']) {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: error),
      );
      await expectLater(
        service.importSettings(),
        throwsA(
          backupError(
            error == 'storage'
                ? BackupErrorCode.storage
                : BackupErrorCode.interrupted,
          ),
        ),
      );
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      expect(await service.importSettings(), isNull);
    }
  });

  test('platform contract, cancellation, size cap and typed errors', () async {
    const channel = MethodChannel('carrete/system');
    const platform = SystemSettingsBackupFiles();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final calls = <MethodCall>[];
    Object? response;
    PlatformException? error;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (error != null) throw error;
      return response;
    });
    final bytes = Uint8List.fromList(document());
    response = true;
    expect(
      await platform.write(
        suggestedName: 'diapo-ajustes-2026-02-03.json',
        bytes: bytes,
      ),
      true,
    );
    expect(calls.last.method, 'exportSettings');
    expect(calls.last.arguments, {
      'suggestedName': 'diapo-ajustes-2026-02-03.json',
      'bytes': bytes,
    });
    response = bytes;
    expect(await platform.read(), bytes);
    expect(calls.last.method, 'importSettings');
    response = null;
    expect(await platform.read(), isNull);
    expect(await platform.write(suggestedName: '', bytes: bytes), false);
    response = Uint8List(SettingsBackupCodec.maxBytes + 1);
    await expectLater(
      platform.read(),
      throwsA(backupError(BackupErrorCode.tooLarge)),
    );
    await expectLater(
      platform.write(suggestedName: '', bytes: response as Uint8List),
      throwsA(backupError(BackupErrorCode.tooLarge)),
    );
    for (final entry in {
      'too_large': BackupErrorCode.tooLarge,
      'busy': BackupErrorCode.busy,
      'storage': BackupErrorCode.storage,
      'interrupted': BackupErrorCode.interrupted,
      'other': BackupErrorCode.storage,
    }.entries) {
      error = PlatformException(code: entry.key);
      await expectLater(platform.read(), throwsA(backupError(entry.value)));
    }
    messenger.setMockMethodCallHandler(channel, null);
    await expectLater(
      platform.read(),
      throwsA(backupError(BackupErrorCode.storage)),
    );
  });

  test(
    'importing an export with no haptics key turns vibration on and persists '
    'it, when it was off',
    () async {
      await SettingsRepository(preferences)
          .save(const AppSettings(haptics: false, onboardingSeen: true));
      files.setDocument(settings: {'grid': true});
      final result = await container
          .read(settingsBackupProvider)
          .importSettings();
      expect(result, isNotNull);
      expect(container.read(settingsProvider).haptics, isTrue);
      await preferences.reload();
      expect(SettingsRepository(preferences).load().haptics, isTrue);
    },
  );

  test('importing an export with haptics false keeps vibration off', () async {
    await SettingsRepository(preferences)
        .save(const AppSettings(haptics: false, onboardingSeen: true));
    files.setDocument(settings: {'haptics': false, 'grid': true});
    final result = await container
        .read(settingsBackupProvider)
        .importSettings();
    expect(result, isNotNull);
    expect(container.read(settingsProvider).haptics, isFalse);
    await preferences.reload();
    expect(SettingsRepository(preferences).load().haptics, isFalse);
  });
}
