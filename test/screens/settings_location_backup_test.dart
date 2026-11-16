import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:carrete/core/backup/settings_backup_codec.dart';
import 'package:carrete/core/backup/settings_backup_files.dart';
import 'package:carrete/core/backup/settings_backup_service.dart';
import 'package:carrete/core/settings/app_settings.dart';
import 'package:carrete/core/settings/settings_provider.dart';
import 'package:carrete/l10n/app_localizations.dart';
import 'package:carrete/location/location_provider.dart';
import 'package:carrete/location/location_source.dart';
import 'package:carrete/platform/system_settings.dart';
import 'package:carrete/render/film_resources.dart';
import 'package:carrete/screens/settings/settings_screen.dart';
import 'package:carrete/ui/widgets/plastic_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

/// A location source that answers what the test says and counts the asks.
class _FakeLocationSource implements LocationSource {
  /// What the system says when it is only looked at.
  LocationPermission status = LocationPermission.denied;

  /// What the system answers when the dialog is opened.
  LocationPermission afterRequest = LocationPermission.granted;

  /// How many times the system dialog was requested.
  int requests = 0;

  @override
  Future<LocationPermission> permission({bool request = false}) async {
    if (request) {
      requests++;
      status = afterRequest;
    }
    return status;
  }

  @override
  Future<LocationReading> current() async => LocationReading(status, null);

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}

/// A file picker the test drives.
class _FakeBackupFiles implements SettingsBackupFiles {
  bool save = true;
  Object? writeError;
  Object? readError;
  Uint8List? input;
  Completer<Uint8List?>? pendingRead;
  int writes = 0;
  int reads = 0;
  Uint8List? output;
  String? name;

  @override
  Future<bool> write({
    required String suggestedName,
    required Uint8List bytes,
  }) async {
    writes++;
    if (writeError != null) throw writeError!;
    name = suggestedName;
    output = bytes;
    return save;
  }

  @override
  Future<Uint8List?> read() async {
    reads++;
    if (readError != null) throw readError!;
    return pendingRead != null ? pendingRead!.future : input;
  }
}

Uint8List _file({
  Map<String, Object?> settings = const {},
  Map<String, Object?> tuning = const {},
  Object format = 'carrete-settings',
  int version = 1,
}) => Uint8List.fromList(
  utf8.encode(
    jsonEncode({
      'format': format,
      'version': version,
      'app': '1.0.0',
      'settings': settings,
      'tuning': tuning,
    }),
  ),
);

class _Harness {
  _Harness(this.prefs, this.location, this.files, this.system);

  final SharedPreferences prefs;
  final _FakeLocationSource location;
  final _FakeBackupFiles files;
  final FakeSystemSettings system;

  ProviderContainer get container =>
      ProviderScope.containerOf(find.byType(SettingsScreen).evaluate().first);

  AppSettings get settings => container.read(settingsProvider);
}

Future<_Harness> _pump(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  LocationPermission permission = LocationPermission.denied,
  LocationPermission afterRequest = LocationPermission.granted,
  String language = 'en',
  bool openAdvanced = true,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final preferences = await SharedPreferences.getInstance();
  final location = _FakeLocationSource()
    ..status = permission
    ..afterRequest = afterRequest;
  final files = _FakeBackupFiles();
  final system = FakeSystemSettings();
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(412, 3000);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        recipeBookProvider.overrideWith((ref) async => testBook()),
        locationSourceProvider.overrideWithValue(location),
        settingsBackupFilesProvider.overrideWithValue(files),
        systemSettingsProvider.overrideWithValue(system),
      ],
      child: MaterialApp(
        locale: Locale(language),
        theme: ThemeData(useMaterial3: true),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(today: DateTime(2026, 7, 14)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  // The export and the import are in the collapsed Advanced section.
  final chevron = find.byKey(const ValueKey('expander-chevron'));
  if (openAdvanced && tester.widget<RotatedBox>(chevron).quarterTurns == 0) {
    await tester.tap(chevron);
    await tester.pump();
  }
  return _Harness(preferences, location, files, system);
}

/// The switch of "Save location": after grid, level, sounds, vibration and
/// original.
Finder get _locationSwitch => find.byType(PlasticSwitch).at(5);

const _needed = 'Location permission is needed to save where photos are taken.';
const _blocked =
    'Location permission is blocked. Turn it on in the system settings.';
const _revoked =
    'The location is not being saved because the permission was removed.';

Future<void> _tapImportAndConfirm(WidgetTester tester) async {
  await tester.tap(find.text('Import settings'));
  await tester.pumpAndSettle();
  expect(find.text('Import settings?'), findsOneWidget);
  await tester.tap(find.text('Import'));
  // Let the dialog close; a spinner runs after this, so no pumpAndSettle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('save location', () {
    testWidgets('is listed, off, with its explanation and no request', (
      tester,
    ) async {
      final h = await _pump(tester);
      expect(find.text('Save location'), findsOneWidget);
      expect(
        find.text(
          "The place is written into the photo's data (EXIF), only while the "
          'camera is open, and is never sent anywhere. Off by default.',
        ),
        findsOneWidget,
      );
      expect(h.settings.saveLocation, isFalse);
      // Building the screen never asks for the permission.
      expect(h.location.requests, 0);
    });

    testWidgets('on with the permission granted turns it on', (tester) async {
      final h = await _pump(tester);
      await tester.tap(_locationSwitch);
      await tester.pump();
      await tester.pump();
      expect(h.location.requests, 1);
      expect(h.settings.saveLocation, isTrue);
      expect(h.prefs.getBool('carrete.settings.saveLocation'), isTrue);
      expect(find.text(_revoked), findsNothing);
    });

    testWidgets('on with approximate permission turns it on and says so', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        afterRequest: LocationPermission.coarseOnly,
      );
      await tester.tap(_locationSwitch);
      await tester.pump();
      await tester.pump();
      expect(h.settings.saveLocation, isTrue);
      expect(
        find.text(
          'You only granted approximate location, so the place will be '
          'approximate.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('on with the permission denied stays off and explains', (
      tester,
    ) async {
      final h = await _pump(tester, afterRequest: LocationPermission.denied);
      await tester.tap(_locationSwitch);
      await tester.pump();
      await tester.pump();
      expect(h.location.requests, 1);
      expect(h.settings.saveLocation, isFalse);
      expect(h.prefs.getBool('carrete.settings.saveLocation'), isNull);
      expect(find.text(_needed), findsOneWidget);
    });

    testWidgets('on with the permission blocked offers the system settings', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        afterRequest: LocationPermission.permanentlyDenied,
      );
      await tester.tap(_locationSwitch);
      await tester.pump();
      await tester.pump();
      expect(h.settings.saveLocation, isFalse);
      expect(find.text(_blocked), findsOneWidget);

      // Let the snack bar slide in before pressing it.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.widgetWithText(SnackBarAction, 'Settings'));
      await tester.pump();
      expect(h.system.opened, 1);
    });

    testWidgets('off turns it off without asking anything', (tester) async {
      final h = await _pump(
        tester,
        prefs: {'carrete.settings.saveLocation': true},
        permission: LocationPermission.granted,
      );
      expect(h.settings.saveLocation, isTrue);
      await tester.tap(_locationSwitch);
      await tester.pump();
      expect(h.settings.saveLocation, isFalse);
      expect(h.prefs.getBool('carrete.settings.saveLocation'), isFalse);
      expect(h.location.requests, 0);
    });

    testWidgets('a removed permission shows a warning with the settings', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        prefs: {'carrete.settings.saveLocation': true},
        permission: LocationPermission.permanentlyDenied,
      );
      expect(find.text(_revoked), findsOneWidget);
      // The stored setting is not changed by the revocation.
      expect(h.settings.saveLocation, isTrue);
      expect(h.location.requests, 0);

      await tester.tap(find.text('Open system settings'));
      await tester.pump();
      expect(h.system.opened, 1);
    });

    testWidgets('no warning while the setting is off', (tester) async {
      await _pump(tester, permission: LocationPermission.denied);
      expect(find.text(_revoked), findsNothing);
    });

    testWidgets('is written in the three languages', (tester) async {
      await _pump(tester, language: 'es');
      expect(find.text('Guardar la ubicación'), findsOneWidget);
      await _pump(tester, language: 'ca');
      expect(find.text('Desa la ubicació'), findsOneWidget);
    });
  });

  group('export settings', () {
    testWidgets('says it is only settings, not a backup of the photos', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('ADVANCED'), findsOneWidget);
      expect(find.text('Your settings, no photos'), findsOneWidget);
      expect(
        find.textContaining('It does not save your photos'),
        findsOneWidget,
      );
      expect(find.textContaining('not a backup'), findsOneWidget);
      expect(find.textContaining('does not bring photos back'), findsOneWidget);
    });

    testWidgets('writes the file and says so', (tester) async {
      final h = await _pump(tester);
      await tester.tap(find.text('Export settings'));
      await tester.pump();
      await tester.pump();
      expect(h.files.writes, 1);
      expect(h.files.name, startsWith('diapo-ajustes-'));
      expect(
        SettingsBackupCodec(knownFilmIds: {'alpha', 'beta', 'gamma'})
            .decode(h.files.output!)
            .settings,
        isNotEmpty,
      );
      expect(find.text('Settings exported.'), findsOneWidget);
    });

    testWidgets('cancelling the system dialog says nothing', (tester) async {
      final h = await _pump(tester);
      h.files.save = false;
      await tester.tap(find.text('Export settings'));
      await tester.pump();
      await tester.pump();
      expect(h.files.writes, 1);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('an error shows its message', (tester) async {
      final h = await _pump(tester);
      h.files.writeError = const SettingsBackupException(
        BackupErrorCode.storage,
      );
      await tester.tap(find.text('Export settings'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Could not read or save. Try again.'), findsOneWidget);
    });
  });

  group('import settings', () {
    testWidgets('asks first and does nothing when cancelled', (tester) async {
      final h = await _pump(tester);
      h.files.input = _file(settings: {'grid': true});
      await tester.tap(find.text('Import settings'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Your current settings and film tuning will be replaced by the '
          'ones in the file.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(h.files.reads, 0);
      expect(h.settings.grid, isFalse);
    });

    testWidgets('after the confirmation applies the file and says so', (
      tester,
    ) async {
      final h = await _pump(tester);
      h.files.input = _file(
        settings: {'grid': true, 'level': true},
        tuning: {
          'alpha': {'grain': 0.5},
        },
      );
      await _tapImportAndConfirm(tester);
      await tester.pump();
      expect(h.files.reads, 1);
      expect(h.settings.grid, isTrue);
      expect(h.settings.level, isTrue);
      expect(find.text('Settings imported.'), findsOneWidget);
    });

    testWidgets('never turns location on and says where to do it', (
      tester,
    ) async {
      final h = await _pump(tester);
      h.files.input = _file(
        settings: {'saveLocation': true, 'saveOriginal': true},
      );
      await _tapImportAndConfirm(tester);
      await tester.pump();
      expect(h.settings.saveLocation, isFalse);
      expect(h.settings.saveOriginal, isFalse);
      expect(
        find.textContaining('Location is still off; turn it on here'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Also save the original is still off'),
        findsOneWidget,
      );
    });

    testWidgets('mentions the films this version does not know', (
      tester,
    ) async {
      final h = await _pump(tester);
      h.files.input = _file(
        tuning: {
          'alpha': {'grain': 0.5},
          'unknown-film': {'grain': 0.5},
        },
      );
      await _tapImportAndConfirm(tester);
      await tester.pump();
      expect(
        find.textContaining('One film this version does not know was left out'),
        findsOneWidget,
      );
    });

    testWidgets('cancelling the system picker says nothing', (tester) async {
      final h = await _pump(tester);
      h.files.input = null;
      await _tapImportAndConfirm(tester);
      await tester.pump();
      expect(h.files.reads, 1);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a file that is not a backup shows a clear message', (
      tester,
    ) async {
      final h = await _pump(tester);
      h.files.input = _file(format: 'something-else');
      await _tapImportAndConfirm(tester);
      await tester.pump();
      expect(
        find.text('This file is not a Diapo settings backup.'),
        findsOneWidget,
      );
      expect(h.settings.grid, isFalse);
    });

    testWidgets('a broken file shows a clear message', (tester) async {
      final h = await _pump(tester);
      h.files.input = Uint8List.fromList(utf8.encode('not json'));
      await _tapImportAndConfirm(tester);
      await tester.pump();
      expect(
        find.text('The file cannot be read: it is not in a valid format.'),
        findsOneWidget,
      );
    });

    const messages = {
      BackupErrorCode.tooLarge:
          'The file is too big to be a Diapo settings backup.',
      BackupErrorCode.invalidJson:
          'The file cannot be read: it is not in a valid format.',
      BackupErrorCode.wrongFormat: 'This file is not a Diapo settings backup.',
      BackupErrorCode.unsupportedVersion:
          'This file comes from a newer version of Diapo. Update the app '
          'to import it.',
      BackupErrorCode.invalidValue:
          'The file has invalid values and nothing was imported.',
      BackupErrorCode.busy: 'An export or an import is already running.',
      BackupErrorCode.storage: 'Could not read or save. Try again.',
      BackupErrorCode.interrupted: 'The operation was interrupted. Try again.',
    };
    for (final entry in messages.entries) {
      testWidgets('the error ${entry.key.name} has its own message', (
        tester,
      ) async {
        final h = await _pump(tester);
        h.files.readError = SettingsBackupException(entry.key);
        await _tapImportAndConfirm(tester);
        await tester.pump();
        expect(find.text(entry.value), findsOneWidget);
      });
    }

    testWidgets('every error code is covered by a message', (tester) async {
      expect(messages.keys.toSet(), BackupErrorCode.values.toSet());
    });

    testWidgets('both rows do nothing while an operation runs', (tester) async {
      final h = await _pump(tester);
      h.files.pendingRead = Completer<Uint8List?>();
      await _tapImportAndConfirm(tester);
      expect(h.files.reads, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // A second tap on either row is ignored.
      await tester.tap(find.text('Import settings'));
      await tester.pump();
      await tester.tap(find.text('Export settings'));
      await tester.pump();
      expect(find.text('Import settings?'), findsNothing);
      expect(h.files.reads, 1);
      expect(h.files.writes, 0);

      h.files.pendingRead!.complete(_file(settings: {'grid': true}));
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(h.settings.grid, isTrue);

      // The rows work again.
      await tester.tap(find.text('Export settings'));
      await tester.pump();
      expect(h.files.writes, 1);
    });

    testWidgets('is written in the three languages', (tester) async {
      await _pump(tester, language: 'es');
      expect(find.text('Exportar ajustes'), findsOneWidget);
      expect(find.text('Importar ajustes'), findsOneWidget);
      await _pump(tester, language: 'ca');
      expect(find.text('Exporta els ajustos'), findsOneWidget);
      expect(find.text('Importa els ajustos'), findsOneWidget);
    });
  });
}
