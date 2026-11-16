import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../capture/capture_providers.dart';
import '../capture/capture_queue.dart';
import '../capture/film_capture_processor.dart';
import '../core/database/app_database.dart';
import '../core/database/database_provider.dart';
import '../core/router.dart';
import '../core/settings/settings_provider.dart';
import '../l10n/app_localizations.dart';
import '../platform/media_store.dart';
import '../render/film_resources.dart';
import 'roll_developer.dart';
import 'roll_notifications.dart';
import 'roll_operations.dart';
import 'roll_service.dart';

final rollClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final rollOperationsProvider = Provider<RollOperations>(
  (ref) => RollOperations(),
);
final rollSavedLookupProvider = Provider<Future<String?> Function(String)>(
  (ref) => MediaStore.findSaved,
);

final Provider<RollNotifications>
rollNotificationsProvider = Provider<RollNotifications>(
  (ref) => LocalRollNotifications(
    texts: () {
      final locale =
          ref.read(settingsProvider).localeOverride ??
          WidgetsBinding.instance.platformDispatcher.locale;
      final supported = AppLocalizations.supportedLocales.any(
        (l) => l.languageCode == locale.languageCode,
      );
      return lookupAppLocalizations(
        supported ? Locale(locale.languageCode) : const Locale('es'),
      );
    },
    onTap: (id) {
      ref.read(routerProvider).go(AppRoutes.rollOf('$id'));
      // The callback runs on the foreground isolate, including cold launches.
      ref.read(rollForegroundProvider).run();
    },
  ),
);

/// Roll failures stay encrypted. Never let FailedShots retry a decrypted
/// temporary file as a loose shot on the next app start.
final rollCaptureProcessorProvider = Provider<CaptureProcessor>(
  (ref) => FilmCaptureProcessor(
    loadProgram: () async {
      final resources = await ref.read(filmResourcesProvider.future);
      if (resources == null) {
        throw StateError('The film shader is not available');
      }
      return resources.program;
    },
  ),
);

final Provider<RollDeveloper> rollDeveloperProvider = Provider<RollDeveloper>((
  ref,
) {
  final developer = RollDeveloper(
    database: ref.watch(appDatabaseProvider),
    vault: ref.watch(shotVaultProvider),
    processor: ref.watch(rollCaptureProcessorProvider),
    notifications: ref.watch(rollNotificationsProvider),
    cache: ref.watch(cacheDirectoryProvider),
    loadBook: () => ref.read(recipeBookProvider.future),
    operations: ref.watch(rollOperationsProvider),
    clock: ref.watch(rollClockProvider),
    isForeground: () => ref.read(rollForegroundProvider).isForeground,
    findSaved: ref.watch(rollSavedLookupProvider),
  );
  ref.onDispose(developer.dispose);
  return developer;
});

final rollServiceProvider = Provider<RollService>((ref) {
  final service = RollService(
    database: ref.watch(appDatabaseProvider),
    vault: ref.watch(shotVaultProvider),
    notifications: ref.watch(rollNotificationsProvider),
    developer: ref.watch(rollDeveloperProvider),
    operations: ref.watch(rollOperationsProvider),
    cache: ref.watch(cacheDirectoryProvider),
    clock: ref.watch(rollClockProvider),
    defaultFilm: () => ref.read(settingsProvider).defaultFilmId,
    activity: ref.watch(saveActivityProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final activeRollProvider = StreamProvider<RollRow?>(
  (ref) => ref.watch(rollsDaoProvider).watchActiveRoll(),
);
final remainingFramesProvider = StreamProvider<int>(
  (ref) => ref.watch(rollsDaoProvider).watchRemainingFrames(),
);
final rollsListProvider = StreamProvider<List<RollRow>>(
  (ref) => ref.watch(rollsDaoProvider).watchRolls(),
);
final rollProvider = StreamProvider.autoDispose.family<RollRow?, int>(
  (ref, id) => ref.watch(rollsDaoProvider).watchRoll(id),
);
final rollShotsProvider = StreamProvider.family<List<ShotRow>, int>(
  (ref, id) => ref.watch(rollsDaoProvider).watchShots(id),
);
final developProgressProvider = StreamProvider<DevelopProgress>(
  (ref) => ref.watch(rollDeveloperProvider).progress,
);
final rollDevelopProgressProvider = StreamProvider.family<DevelopProgress, int>(
  (ref, id) async* {
    final developer = ref.watch(rollDeveloperProvider);
    final latest = developer.latestProgress(id);
    if (latest != null) yield latest;
    yield* developer.progress.where((p) => p.rollId == id);
  },
);

/// Installed by main, separately from the widgets and easy to fake in tests.
final Provider<RollForeground> rollForegroundProvider =
    Provider<RollForeground>(
      (ref) => RollForeground(
        develop: () async {
          await ref.read(rollServiceProvider).recoverCaptures();
          await ref
              .read(rollDeveloperProvider)
              .developDue(ref.read(rollClockProvider)());
        },
      ),
    );

class RollForeground with WidgetsBindingObserver {
  RollForeground({required this.develop, this.onError});
  final Future<void> Function() develop;
  final void Function(Object)? onError;
  Future<void>? _running;
  bool _foreground = true;
  bool get isForeground => _foreground;

  Future<void> run() {
    if (!_foreground) return Future.value();
    return _running ??= _run();
  }

  Future<void> _run() async {
    try {
      await develop();
    } on Object catch (error) {
      onError?.call(error);
    } finally {
      _running = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) run();
  }
}
