import 'dart:convert';
import 'dart:typed_data';

import 'package:film_recipes/film_recipes.dart';

enum BackupErrorCode {
  tooLarge,
  invalidJson,
  wrongFormat,
  unsupportedVersion,
  invalidValue,
  busy,
  storage,
  interrupted,
}

/// A stable code and field path for the caller to translate into UI text.
class SettingsBackupException implements Exception {
  const SettingsBackupException(this.code, [this.path = '']);

  final BackupErrorCode code;
  final String path;

  @override
  String toString() => 'SettingsBackupException(${code.name}, $path)';
}

/// Validated patches. Missing fields preserve the device's current values.
class SettingsBackupData {
  SettingsBackupData({
    required this.appVersion,
    required Map<String, Object?> settings,
    required Map<String, Map<String, Object?>> tuning,
    required List<String> skippedFilmIds,
  }) : settings = Map.unmodifiable(settings),
       tuning = Map.unmodifiable({
         for (final entry in tuning.entries)
           entry.key: Map<String, Object?>.unmodifiable(entry.value),
       }),
       skippedFilmIds = List.unmodifiable(skippedFilmIds);

  final String appVersion;
  final Map<String, Object?> settings;
  final Map<String, Map<String, Object?>> tuning;
  final List<String> skippedFilmIds;
}

/// Pure Dart wire format, independent of Flutter, preferences and file pickers.
class SettingsBackupCodec {
  SettingsBackupCodec({required Set<String> knownFilmIds})
    : knownFilmIds = Set.unmodifiable(knownFilmIds);

  static const maxBytes = 256 * 1024;
  static const format = 'carrete-settings';
  static const version = 1;

  final Set<String> knownFilmIds;

  static const settingKeys = {
    'cameraSounds',
    'haptics',
    'saveOriginal',
    'saveLocation',
    'grid',
    'level',
    'dateStampStyle',
    'defaultFilmId',
    'themeMode',
    'localeOverride',
  };
  static const tuningKeys = {
    'grain',
    'halation',
    'leak',
    'vignette',
    'dateStamp',
    'cinemaBands',
    'format',
  };

  Uint8List encode({
    required String appVersion,
    required Map<String, Object?> settings,
    required Map<String, Map<String, Object?>> tuning,
  }) {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': format,
          'version': version,
          'app': appVersion,
          'settings': {
            for (final key in settingKeys)
              if (settings.containsKey(key)) key: settings[key],
          },
          'tuning': {
            for (final entry in tuning.entries)
              if (knownFilmIds.contains(entry.key))
                entry.key: {
                  for (final key in tuningKeys)
                    if (entry.value.containsKey(key)) key: entry.value[key],
                },
          },
        }),
      ),
    );
    // Export must obey the same contract as import.
    decode(bytes);
    return bytes;
  }

  SettingsBackupData decode(List<int> bytes) {
    if (bytes.length > maxBytes) {
      throw const SettingsBackupException(BackupErrorCode.tooLarge);
    }
    final Object? decoded;
    try {
      decoded = _StrictJson(utf8.decode(bytes)).read();
    } on FormatException {
      throw const SettingsBackupException(BackupErrorCode.invalidJson);
    }
    final root = _object(decoded, '.');
    if (root['format'] != format) {
      throw const SettingsBackupException(BackupErrorCode.wrongFormat);
    }
    final fileVersion = root['version'];
    if (fileVersion is! int || fileVersion < 1) _invalid('version');
    if (fileVersion > version) {
      throw const SettingsBackupException(BackupErrorCode.unsupportedVersion);
    }
    final app = root['app'];
    if (app is! String || app.trim().isEmpty) _invalid('app');
    final settings = _object(root['settings'], 'settings');
    final tuning = _object(root['tuning'], 'tuning');
    final acceptedSettings = <String, Object?>{};
    final skipped = <String>{};
    void skip(String id) {
      if (skipped.length < 50) {
        // Bound both the report and each displayable id (Unicode characters).
        skipped.add(String.fromCharCodes(id.runes.take(64)));
      }
    }

    for (final key in settingKeys) {
      if (!settings.containsKey(key)) continue;
      final value = settings[key];
      switch (key) {
        case 'cameraSounds' ||
            'haptics' ||
            'saveOriginal' ||
            'saveLocation' ||
            'grid' ||
            'level':
          if (value is! bool) _invalid('settings.$key');
        case 'dateStampStyle':
          if (!const ['yy m d', 'd m yy'].contains(value)) {
            _invalid('settings.$key');
          }
        case 'themeMode':
          if (!const ['system', 'light', 'dark'].contains(value)) {
            _invalid('settings.$key');
          }
        case 'localeOverride':
          if (value != null && !const ['es', 'ca', 'en'].contains(value)) {
            _invalid('settings.$key');
          }
        case 'defaultFilmId':
          if (value is! String || value.isEmpty) _invalid('settings.$key');
          if (!knownFilmIds.contains(value)) {
            skip(value);
            continue;
          }
      }
      acceptedSettings[key] = value;
    }
    final acceptedTuning = <String, Map<String, Object?>>{};
    for (final entry in tuning.entries) {
      if (!knownFilmIds.contains(entry.key)) {
        skip(entry.key);
        continue;
      }
      final fields = _object(entry.value, 'tuning.${entry.key}');
      final accepted = <String, Object?>{};
      for (final key in tuningKeys) {
        if (!fields.containsKey(key)) continue;
        final value = fields[key];
        final path = 'tuning.${entry.key}.$key';
        switch (key) {
          case 'grain' || 'halation' || 'leak' || 'vignette':
            // LookOverrides documents these as multipliers in [0, 2].
            // resolve() separately clamps the resulting recipe amounts to [0, 1].
            if (value is! num || !value.isFinite || value < 0 || value > 2) {
              _invalid(path);
            }
          case 'dateStamp' || 'cinemaBands':
            if (value != null && value is! bool) _invalid(path);
          case 'format':
            if (value != null &&
                (value is! String || FrameFormat.tryParse(value) == null)) {
              _invalid(path);
            }
        }
        accepted[key] = value;
      }
      if (accepted.isNotEmpty) acceptedTuning[entry.key] = accepted;
    }
    return SettingsBackupData(
      appVersion: app,
      settings: acceptedSettings,
      tuning: acceptedTuning,
      skippedFilmIds: skipped.toList()..sort(),
    );
  }

  static Map<String, Object?> _object(Object? value, String path) {
    if (value is! Map<String, dynamic>) _invalid(path);
    return value;
  }

  static Never _invalid(String path) =>
      throw SettingsBackupException(BackupErrorCode.invalidValue, path);
}

/// Bounded recursive reader: duplicate names are rejected after JSON unescaping,
/// before insertion into a map, including ignored extension objects.
class _StrictJson {
  _StrictJson(this.source);
  final String source;
  int offset = 0;
  static final _scalar = RegExp(
    r'true|false|null|-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?',
  );

  Object? read() {
    final value = _value(0);
    _space();
    if (offset != source.length) _fail();
    return value;
  }

  void _space() {
    while (offset < source.length &&
        const [32, 9, 10, 13].contains(source.codeUnitAt(offset))) {
      offset++;
    }
  }

  bool _take(String token) {
    _space();
    if (!source.startsWith(token, offset)) return false;
    offset += token.length;
    return true;
  }

  String _string() {
    _space();
    final start = offset;
    if (offset >= source.length || source[offset++] != '"') _fail();
    while (offset < source.length) {
      final char = source[offset++];
      if (char == '"') {
        return jsonDecode(source.substring(start, offset)) as String;
      }
      if (char == r'\') offset++;
    }
    return _fail();
  }

  Object? _value(int depth) {
    if (depth > 64) _fail();
    _space();
    if (_take('{')) {
      final map = <String, Object?>{};
      if (_take('}')) return map;
      do {
        final key = _string();
        if (map.containsKey(key) || !_take(':')) _fail();
        map[key] = _value(depth + 1);
        if (_take('}')) return map;
      } while (_take(','));
      return _fail();
    }
    if (_take('[')) {
      final list = <Object?>[];
      if (_take(']')) return list;
      do {
        list.add(_value(depth + 1));
        if (_take(']')) return list;
      } while (_take(','));
      return _fail();
    }
    if (offset < source.length && source[offset] == '"') return _string();
    final match = _scalar.matchAsPrefix(source, offset);
    if (match == null) return _fail();
    offset = match.end;
    return jsonDecode(match[0]!);
  }

  Never _fail() =>
      throw const FormatException('Invalid or duplicate JSON member');
}
