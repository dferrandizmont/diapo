import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../render/film_resources.dart';
import '../../review/review_service.dart';
import '../app_info.dart';
import '../settings/app_settings.dart';
import '../settings/film_tuning.dart';
import '../settings/film_tuning_provider.dart';
import '../settings/settings_provider.dart';
import '../settings/settings_snapshot.dart';
import 'settings_backup_codec.dart';
import 'settings_backup_files.dart';

final settingsBackupFilesProvider = Provider<SettingsBackupFiles>(
  (ref) => const SystemSettingsBackupFiles(),
);

/// Future settings rows call ref.read(settingsBackupProvider).importSettings()
/// or .exportSettings(); they handle cancellation and translate typed errors.
final settingsBackupProvider = Provider<SettingsBackupService>((ref) {
  return SettingsBackupService(
    files: ref.watch(settingsBackupFilesProvider),
    codec: () async => SettingsBackupCodec(
      knownFilmIds: (await ref.read(recipeBookProvider.future)).recipes
          .map((recipe) => recipe.id)
          .toSet(),
    ),
    loadSettings: () => ref.read(settingsRepositoryProvider).load(),
    loadTuning: () => ref.read(filmTuningRepositoryProvider).load(),
    serialize: <T>(Future<T> Function() action) =>
        SettingsSnapshot(ref.read(sharedPreferencesProvider)).serialize(action),
    // The person is checking what the import changes: the store stays quiet
    // from the first step of the import to its end, whatever the outcome.
    guardImport: <T>(Future<T> Function() action) =>
        ref.read(reviewServiceProvider).guardSettingsImport(action),
    commit: (settings, tuning) async {
      // And for a few days after: the day is noted. It never blocks or fails
      // the import.
      unawaited(ref.read(reviewServiceProvider).recordSettingsImport());
      await SettingsSnapshot(ref.read(sharedPreferencesProvider)).write({
        'settings': settings.toJson()..remove('onboardingSeen'),
        'tuning': {
          for (final entry in tuning.entries)
            if (!entry.value.isDefault) entry.key: entry.value.toJson(),
        },
      });
      // Readers observe both halves only after the one durable write succeeds.
      ref.invalidate(settingsProvider);
      ref.invalidate(filmTuningsProvider);
    },
  );
});

class SettingsImportResult {
  SettingsImportResult({
    required Iterable<String> appliedSettings,
    required Iterable<String> appliedFilmIds,
    required Iterable<String> skippedFilmIds,
    Iterable<String> needsUserSettings = const [],
  }) : appliedSettings = List.unmodifiable(appliedSettings),
       appliedFilmIds = List.unmodifiable(appliedFilmIds),
       skippedFilmIds = List.unmodifiable(skippedFilmIds),
       needsUserSettings = List.unmodifiable(needsUserSettings);

  final List<String> needsUserSettings;
  final List<String> appliedSettings;
  final List<String> appliedFilmIds;
  final List<String> skippedFilmIds;
}

class SettingsBackupService {
  SettingsBackupService({
    required this.files,
    required this.codec,
    required this.loadSettings,
    required this.loadTuning,
    required this.commit,
    this.serialize = _direct,
    this.guardImport = _direct,
    DateTime Function()? now,
    this.appVersion = kAppVersion,
  }) : now = now ?? DateTime.now;

  final Future<T> Function<T>(Future<T> Function()) serialize;

  /// Wraps a whole import, from reading the file to its last write, and is
  /// left (even on cancellation or error) when the import ends.
  final Future<T> Function<T>(Future<T> Function()) guardImport;
  static Future<T> _direct<T>(Future<T> Function() action) => action();

  final SettingsBackupFiles files;
  final Future<SettingsBackupCodec> Function() codec;
  final AppSettings Function() loadSettings;
  final Map<String, FilmTuning> Function() loadTuning;
  final Future<void> Function(AppSettings, Map<String, FilmTuning>) commit;
  final DateTime Function() now;
  final String appVersion;
  bool _busy = false;

  /// True on save, false on cancellation. Throws SettingsBackupException.
  Future<bool> exportSettings() => _run(() async {
    final encoder = await codec();
    final date = now();
    final day =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final bytes = await serialize(() async {
      final tuning = loadTuning();
      return encoder.encode(
        appVersion: appVersion,
        settings: loadSettings().toJson(),
        tuning: {
          // Export complete values for every known film, including explicit
          // defaults and null overrides. Restoring a full backup must also
          // clear tuning that only exists on the destination device.
          for (final id in encoder.knownFilmIds)
            id: {
              ...(tuning[id] ?? FilmTuning.defaults).toJson(),
              'dateStamp': tuning[id]?.dateStamp,
              'cinemaBands': tuning[id]?.cinemaBands,
              'format': tuning[id]?.format?.wireName,
            },
        },
      );
    });
    return files.write(suggestedName: 'diapo-ajustes-$day.json', bytes: bytes);
  });

  /// Null on cancellation. Missing fields preserve current values; all known
  /// fields are validated before any write. Unknown films are skipped as units.
  Future<SettingsImportResult?> importSettings() =>
      _run(() => guardImport(_import));

  Future<SettingsImportResult?> _import() async {
    final bytes = await files.read();
    if (bytes == null) return null;
    final data = (await codec()).decode(bytes);
    Future<SettingsImportResult> apply() async {
      // Merge inside the shared persistence queue, against confirmed values.
      final current = loadSettings();
      final patch = Map<String, Object?>.of(data.settings);
      // Old exports (before "Vibration" existed) omit "haptics": an import
      // of one of them turns vibration on, even if it is off on this device.
      if (!patch.containsKey('haptics') && !current.haptics) {
        patch['haptics'] = true;
      }
      final needsUser = <String>[];
      for (final key in ['saveLocation', 'saveOriginal']) {
        if (patch[key] == true && current.toJson()[key] == false) {
          patch.remove(key);
          needsUser.add(key);
        }
      }
      final settings = AppSettings.fromJson({...current.toJson(), ...patch});
      final tuning = Map<String, FilmTuning>.of(loadTuning());
      for (final entry in data.tuning.entries) {
        tuning[entry.key] = FilmTuning.fromJson({
          ...(tuning[entry.key] ?? FilmTuning.defaults).toJson(),
          ...entry.value,
        });
      }
      if (patch.isNotEmpty || data.tuning.isNotEmpty) {
        try {
          await commit(settings, tuning);
        } catch (_) {
          throw const SettingsBackupException(BackupErrorCode.storage);
        }
      }
      return SettingsImportResult(
        appliedSettings: patch.keys,
        needsUserSettings: needsUser,
        appliedFilmIds: data.tuning.keys,
        skippedFilmIds: data.skippedFilmIds,
      );
    }

    return serialize(apply);
  }

  Future<T> _run<T>(Future<T> Function() action) async {
    if (_busy) throw const SettingsBackupException(BackupErrorCode.busy);
    _busy = true;
    try {
      return await action();
    } finally {
      _busy = false;
    }
  }
}
