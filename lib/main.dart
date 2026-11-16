import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'capture/capture_providers.dart';
import 'capture/loose_photo_tracker.dart';
import 'core/settings/settings_provider.dart';
import 'core/startup_cleanup.dart';
import 'import/import_providers.dart';
import 'legal/app_licence.dart';
import 'roll/disposable.dart';
import 'roll/roll_notifications.dart';
import 'roll/roll_providers.dart';
import 'roll/roll_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerAppLicence();
  _registerFontLicenses();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // The settings are read before the app starts, so the first screen is
  // already in the language and the theme the user chose.
  final preferences = await SharedPreferences.getInstance();
  final cacheDir = await getTemporaryDirectory();
  // Only disposable encoder copies are removed. Unconfirmed camera originals
  // and roll recovery records must survive until their durable save. Shared
  // contact sheets go too.
  await cleanStartupTemps(cacheDir);
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      cacheDirectoryProvider.overrideWithValue(cacheDir),
    ],
  );
  await _restoreDisposable(container);
  runApp(
    UncontrolledProviderScope(container: container, child: const CarreteApp()),
  );
  final foreground = container.read(rollForegroundProvider);
  WidgetsBinding.instance.addObserver(foreground);
  unawaited(_startRolls(container));
}

/// A disposable camera that was in the camera when the app closed (or was
/// killed) is still there: the router leads to it from the first frame. This
/// waits for the first answer of the database so the camera of design A never
/// shows for a moment, and drops a lock whose roll is gone, even if the
/// database answers late.
Future<void> _restoreDisposable(ProviderContainer container) async {
  if (container.read(disposableLockProvider) == null) return;
  // Keep the roll stream alive: its first answer is read here and the router
  // asks for it again right away.
  container.listen(activeRollProvider, (_, _) {});
  await reconcileDisposableLock(
    container.read(disposableLockProvider.notifier),
    container.read(activeRollProvider.future),
  );
}

Future<void> _startRolls(ProviderContainer container) async {
  if (kDebugMode) {
    container
        .read(rollServiceProvider)
        .notificationErrors
        .listen((error) => debugPrint('Roll side effect failed: $error'));
  }
  // Copies of photos chosen to be developed (a batch nobody developed, a pick
  // the app never took) are the app's own temporary files: they go at every
  // start. A pick started meanwhile waits for this to finish (see
  // ImportIntake.pick), so the cleanup never deletes a new import.
  await container.read(importIntakeProvider).cleanLeftovers();
  // Photos saved from now on, and the ones recovered next, are counted.
  container.read(loosePhotoTrackerProvider);
  await retryFailedShots(container);
  await container.read(rollServiceProvider).recoverCaptures();
  // Keep active-roll routing ready before the first shutter press.
  container.listen(activeRollProvider, (_, _) {});
  final notifications = container.read(rollNotificationsProvider);
  try {
    if (notifications is LocalRollNotifications) {
      await notifications.initialize();
    }
    await container.read(rollServiceProvider).reconcileNotifications();
  } on Object catch (error) {
    if (kDebugMode) debugPrint('Roll notifications unavailable: $error');
  }
  await container.read(rollForegroundProvider).run();
}

/// The bundled fonts are under the SIL Open Font License; it travels with
/// them and shows in the licences page.
void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (family, file) in const [
      ('Chakra Petch', 'assets/fonts/OFL-ChakraPetch.txt'),
      ('Barlow Semi Condensed', 'assets/fonts/OFL-BarlowSemiCondensed.txt'),
      ('Bowlby One', 'assets/fonts/OFL-BowlbyOne.txt'),
      ('Space Mono', 'assets/fonts/OFL-SpaceMono.txt'),
      ('Caveat', 'assets/fonts/OFL-Caveat.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([
        family,
      ], await rootBundle.loadString(file));
    }
  });
}
