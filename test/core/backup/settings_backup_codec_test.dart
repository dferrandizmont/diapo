import 'dart:convert';

import 'package:diapo/core/backup/settings_backup_codec.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> document({
  Object? settings = const {},
  Object? tuning = const {},
  Map<String, Object?> overrides = const {},
}) => utf8.encode(
  jsonEncode({
    'format': 'carrete-settings',
    'version': 1,
    'app': '0.1.0',
    'settings': settings,
    'tuning': tuning,
    ...overrides,
  }),
);

Matcher backupError(BackupErrorCode code, [String? path]) =>
    isA<SettingsBackupException>()
        .having((e) => e.code, 'code', code)
        .having((e) => path == null || e.path == path, 'path matches', true);

void main() {
  final codec = SettingsBackupCodec(knownFilmIds: {'verano-98', 'bn-clasico'});

  test('round trip includes every portable field and strips private data', () {
    final settings = <String, Object?>{
      'cameraSounds': false,
      'haptics': false,
      'saveOriginal': true,
      'saveLocation': false,
      'grid': true,
      'level': true,
      'dateStampStyle': 'd m yy',
      'defaultFilmId': 'verano-98',
      'themeMode': 'dark',
      'localeOverride': 'ca',
    };
    final tuning = <String, Map<String, Object?>>{
      'verano-98': {
        'grain': 0,
        'halation': 2,
        'leak': 0.5,
        'vignette': 1,
        'dateStamp': true,
        'cinemaBands': true,
        'format': '1:1',
      },
      'bn-clasico': {'dateStamp': null, 'format': null, 'cinemaBands': false},
    };
    final bytes = codec.encode(
      appVersion: '0.1.0',
      settings: {
        ...settings,
        'onboardingSeen': true,
        'disposableLock': 'secret',
        'path': '/private',
        'vault': 'secret',
        'rolls': [],
      },
      tuning: {
        ...tuning,
        'removed-film': {'grain': 1},
      },
    );
    expect(utf8.decode(bytes), isNot(contains('secret')));
    expect(utf8.decode(bytes), isNot(contains('onboardingSeen')));
    expect(utf8.decode(bytes), isNot(contains('/private')));
    final decoded = codec.decode(bytes);
    expect(decoded.settings, settings);
    expect(decoded.tuning, tuning);
    expect(decoded.appVersion, '0.1.0');
    expect(decoded.skippedFilmIds, isEmpty);
  });

  test('old backups omit cinema bands and invalid flags are rejected', () {
    final old = codec.decode(
      document(
        tuning: {
          'verano-98': {'dateStamp': true},
        },
      ),
    );
    expect(old.tuning['verano-98']!.containsKey('cinemaBands'), isFalse);
    expect(
      () => codec.decode(
        document(
          tuning: {
            'verano-98': {'cinemaBands': 1},
          },
        ),
      ),
      throwsA(
        backupError(
          BackupErrorCode.invalidValue,
          'tuning.verano-98.cinemaBands',
        ),
      ),
    );
  });

  test('partial objects are patches and unknown keys are ignored', () {
    final data = codec.decode(
      document(
        settings: {'grid': true, 'future': []},
        tuning: {
          'verano-98': {'grain': 0.7, 'future': false},
          'bn-clasico': {'future': 1},
        },
        overrides: {'future': 1},
      ),
    );
    expect(data.settings, {'grid': true});
    expect(data.tuning, {
      'verano-98': {'grain': 0.7},
    });
    expect(codec.decode(document()).settings, isEmpty);
    expect(codec.decode(document()).tuning, isEmpty);
  });

  test('unknown film ids are skipped as units and reported once', () {
    final data = codec.decode(
      document(
        settings: {'defaultFilmId': 'future-film'},
        tuning: {
          'future-film': 'unknown shape',
          'verano-98': {'grain': 2},
        },
      ),
    );
    expect(data.settings, isEmpty);
    expect(data.tuning.keys, ['verano-98']);
    expect(data.skippedFilmIds, ['future-film']);
  });

  test(
    'literal duplicate keys at every level are rejected after unescaping',
    () {
      for (final raw in [
        r'{"format":"carrete-settings","version":2,"version":1,"app":"x","settings":{},"tuning":{}}',
        r'{"format":"carrete-settings","version":1,"app":"x","settings":{},"settings":{},"tuning":{}}',
        r'{"format":"carrete-settings","version":1,"app":"x","settings":{"grid":"invalid","grid":true},"tuning":{}}',
        r'{"format":"carrete-settings","version":1,"app":"x","settings":{"gr\u0069d":"invalid","grid":true},"tuning":{}}',
        r'{"format":"carrete-settings","version":1,"app":"x","settings":{},"tuning":{"verano-98":{},"verano-98":{}}}',
        r'{"format":"carrete-settings","version":1,"app":"x","settings":{},"tuning":{"verano-98":{"grain":-1,"grain":1}}}',
        r'{"format":"carrete-settings","version":1,"app":"x","settings":{},"tuning":{},"future":[{"x":null,"\u0078":true}]}',
      ]) {
        expect(
          () => codec.decode(utf8.encode(raw)),
          throwsA(backupError(BackupErrorCode.invalidJson)),
        );
      }
    },
  );

  test('skipped ids are capped at 50 entries and 64 Unicode characters', () {
    final data = codec.decode(
      document(
        settings: {'defaultFilmId': '\u{1f600}' * 80},
        tuning: {for (var i = 0; i < 80; i++) '$i-${'x' * 100}': {}},
      ),
    );
    expect(data.skippedFilmIds, hasLength(50));
    expect(data.skippedFilmIds.every((id) => id.runes.length <= 64), true);
    expect(data.skippedFilmIds, contains('\u{1f600}' * 64));
    expect(data.settings, isEmpty);
    expect(data.tuning, isEmpty);
  });

  test('strict reader accepts escaped names and rejects malformed extensions', () {
    final raw =
        r'{"format":"carrete-settings","version":1,"app":"x","settings":{"gr\u0069d":true},"tuning":{},"future":[1,-2.5e+1,true,false,null,"quote\"slash\\"]}';
    expect(codec.decode(utf8.encode(raw)).settings, {'grid': true});
    for (final extra in [
      '[1,]',
      '{"a":1,}',
      '01',
      'true false',
      '"bad\\x"',
      '[${'[' * 70}0${']' * 70}]',
    ]) {
      final malformed = utf8
          .decode(document(overrides: {'future': null}))
          .replaceFirst('"future":null', '"future":$extra');
      expect(
        () => codec.decode(utf8.encode(malformed)),
        throwsA(backupError(BackupErrorCode.invalidJson)),
      );
    }
  });

  test('valid enums and nullable fields are accepted', () {
    for (final locale in [null, 'es', 'ca', 'en']) {
      for (final theme in ['system', 'light', 'dark']) {
        for (final style in ['yy m d', 'd m yy']) {
          codec.decode(
            document(
              settings: {
                'localeOverride': locale,
                'themeMode': theme,
                'dateStampStyle': style,
              },
            ),
          );
        }
      }
    }
    for (final format in [null, '3:2', '4:3', '1:1', '16:9']) {
      for (final stamp in [null, true, false]) {
        codec.decode(
          document(
            tuning: {
              'verano-98': {'format': format, 'dateStamp': stamp},
            },
          ),
        );
      }
    }
  });

  for (final key in [
    'cameraSounds',
    'haptics',
    'saveOriginal',
    'saveLocation',
    'grid',
    'level',
  ]) {
    for (final value in [null, 0, 'true', [], {}]) {
      test('rejects settings.$key = $value', () {
        expect(
          () => codec.decode(document(settings: {key: value})),
          throwsA(backupError(BackupErrorCode.invalidValue, 'settings.$key')),
        );
      });
    }
  }
  final invalidSettings = <String, List<Object?>>{
    'dateStampStyle': [null, false, 1, 'yearFirst', ''],
    'themeMode': [null, true, 0, 'sepia', ''],
    'localeOverride': [false, 0, 'de', '', 'es-ES'],
    'defaultFilmId': [null, false, 1, '', []],
  };
  for (final entry in invalidSettings.entries) {
    for (final value in entry.value) {
      test('rejects settings.${entry.key} = $value', () {
        expect(
          () => codec.decode(document(settings: {entry.key: value})),
          throwsA(
            backupError(BackupErrorCode.invalidValue, 'settings.${entry.key}'),
          ),
        );
      });
    }
  }
  for (final key in ['grain', 'halation', 'leak', 'vignette']) {
    for (final value in [null, false, '1', [], {}, -0.001, 2.001, 1e300]) {
      test('rejects tuning.$key = $value', () {
        expect(
          () => codec.decode(
            document(
              tuning: {
                'verano-98': {key: value},
              },
            ),
          ),
          throwsA(
            backupError(BackupErrorCode.invalidValue, 'tuning.verano-98.$key'),
          ),
        );
      });
    }
  }
  for (final entry in {
    'dateStamp': [0, 'true', [], {}],
    'format': [false, 1, '5:4', '', []],
  }.entries) {
    for (final value in entry.value) {
      test('rejects tuning.${entry.key} = $value', () {
        expect(
          () => codec.decode(
            document(
              tuning: {
                'verano-98': {entry.key: value},
              },
            ),
          ),
          throwsA(backupError(BackupErrorCode.invalidValue)),
        );
      });
    }
  }
  test('nonfinite JSON numbers are rejected', () {
    final raw = utf8
        .decode(
          document(
            tuning: {
              'verano-98': {'grain': 1},
            },
          ),
        )
        .replaceFirst('"grain":1', '"grain":1e9999');
    expect(
      () => codec.decode(utf8.encode(raw)),
      throwsA(backupError(BackupErrorCode.invalidValue)),
    );
  });

  for (final value in [null, [], '', 0, false]) {
    test('rejects non-object containers: $value', () {
      for (final bytes in [
        utf8.encode(jsonEncode(value)),
        document(settings: value),
        document(tuning: value),
        document(tuning: {'verano-98': value}),
      ]) {
        expect(
          () => codec.decode(bytes),
          throwsA(backupError(BackupErrorCode.invalidValue)),
        );
      }
    });
  }
  test('missing required envelope fields are rejected', () {
    final root = jsonDecode(utf8.decode(document())) as Map<String, dynamic>;
    for (final key in root.keys) {
      final copy = {...root}..remove(key);
      expect(
        () => codec.decode(utf8.encode(jsonEncode(copy))),
        throwsA(isA<SettingsBackupException>()),
      );
    }
  });
  for (final value in [null, true, 0, 'other']) {
    test('wrong format $value has a typed error', () {
      expect(
        () => codec.decode(document(overrides: {'format': value})),
        throwsA(backupError(BackupErrorCode.wrongFormat)),
      );
    });
  }
  for (final value in [null, '1', 1.0, true, 0, -1]) {
    test('invalid version $value is rejected', () {
      expect(
        () => codec.decode(document(overrides: {'version': value})),
        throwsA(backupError(BackupErrorCode.invalidValue)),
      );
    });
  }
  for (final value in [null, '', '   ', 1, false, []]) {
    test('invalid app version $value is rejected', () {
      expect(
        () => codec.decode(document(overrides: {'app': value})),
        throwsA(backupError(BackupErrorCode.invalidValue)),
      );
    });
  }
  test('newer versions have a distinct typed error', () {
    expect(
      () => codec.decode(document(overrides: {'version': 2})),
      throwsA(backupError(BackupErrorCode.unsupportedVersion)),
    );
  });
  test('invalid JSON and UTF8 have typed errors', () {
    for (final bytes in <List<int>>[
      [],
      utf8.encode('{'),
      [0xff],
      utf8.encode('{"a":NaN}'),
    ]) {
      expect(
        () => codec.decode(bytes),
        throwsA(backupError(BackupErrorCode.invalidJson)),
      );
    }
  });
  test(
    'size is checked in bytes before parsing and includes the exact boundary',
    () {
      final bytes = document();
      final padded = [
        ...bytes,
        ...List.filled(SettingsBackupCodec.maxBytes - bytes.length, 32),
      ];
      codec.decode(padded);
      expect(
        () => codec.decode([...padded, 32]),
        throwsA(backupError(BackupErrorCode.tooLarge)),
      );
      final multibyte = document(
        overrides: {'unknown': List.filled(140000, 'é').join()},
      );
      expect(
        () => codec.decode(multibyte),
        throwsA(backupError(BackupErrorCode.tooLarge)),
      );
      expect(
        () => codec.encode(
          appVersion: 'x' * SettingsBackupCodec.maxBytes,
          settings: {},
          tuning: {},
        ),
        throwsA(backupError(BackupErrorCode.tooLarge)),
      );
    },
  );
}
