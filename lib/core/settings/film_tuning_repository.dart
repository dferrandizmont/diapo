import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'film_tuning.dart';
import 'settings_snapshot.dart';

/// Reads and writes the fine tuning of every film as one JSON map keyed by
/// film id, in the preferences of the device.
/// After a settings import, [SettingsSnapshot] holds it alongside settings.
///
/// A broken value (not JSON, not a map, an entry that is not a map) is read as
/// "nothing tuned": the films fall back to their recipes.
class FilmTuningRepository {
  FilmTuningRepository(this._preferences);

  final SharedPreferences _preferences;

  /// The legacy key used before the first settings import.
  static const String storageKey = 'carrete.filmTunings';

  /// The tuning of every film that has one.
  Map<String, FilmTuning> load() {
    final snapshot = SettingsSnapshot(_preferences).read();
    if (snapshot != null) {
      return {
        for (final entry in (snapshot['tuning']! as Map).entries)
          if (entry.key is String && entry.value is Map)
            entry.key as String: FilmTuning.fromJson(
              (entry.value as Map).cast<String, Object?>(),
            ),
      }..removeWhere((_, tuning) => tuning.isDefault);
    }
    final String? raw;
    try {
      raw = _preferences.getString(storageKey);
    } on TypeError {
      return <String, FilmTuning>{};
    }
    if (raw == null || raw.isEmpty) return <String, FilmTuning>{};
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return <String, FilmTuning>{};
    }
    if (decoded is! Map) return <String, FilmTuning>{};
    final result = <String, FilmTuning>{};
    decoded.forEach((key, value) {
      if (key is String && key.isNotEmpty && value is Map) {
        final tuning = FilmTuning.fromJson(value.cast<String, Object?>());
        if (!tuning.isDefault) result[key] = tuning;
      }
    });
    return result;
  }

  /// Stores [tunings]. Films that match their recipe are not written.
  Future<void> save(Map<String, FilmTuning> tunings) =>
      SettingsSnapshot(_preferences).serialize(() => _save(tunings));

  Future<void> update(String filmId, FilmTuning Function(FilmTuning) change) =>
      SettingsSnapshot(_preferences).serialize(() {
        final map = load();
        map[filmId] = change(map[filmId] ?? FilmTuning.defaults);
        return _save(map);
      });

  Future<void> _save(Map<String, FilmTuning> tunings) async {
    final map = <String, Object?>{
      for (final entry in tunings.entries)
        if (!entry.value.isDefault) entry.key: entry.value.toJson(),
    };
    final store = SettingsSnapshot(_preferences);
    final snapshot = store.read();
    if (snapshot != null) {
      await store.write({...snapshot, 'tuning': map});
      return;
    }
    if (map.isEmpty) {
      await _preferences.remove(storageKey);
      return;
    }
    await _preferences.setString(storageKey, jsonEncode(map));
  }
}
