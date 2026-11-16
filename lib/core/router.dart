import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../import/import_intake.dart';
import '../poc/poc_screen.dart';
import '../roll/disposable.dart';
import '../screens/disposable/disposable_screen.dart';
import '../screens/gallery/gallery_day_screen.dart';
import '../screens/gallery/gallery_screen.dart';
import '../screens/import/import_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/roll/roll_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/viewfinder/viewfinder_screen.dart';

/// The paths of the screens of the app.
class AppRoutes {
  const AppRoutes._();

  /// The camera: the first screen of the app.
  static const String camera = '/';

  /// The proof of concept and benchmark (`--dart-define=CARRETE_BENCH=true`
  /// opens it at start).
  static const String bench = '/bench';

  /// The gallery of the photos.
  static const String gallery = '/gallery';

  /// The loose photos of one day of the gallery, named like `20261113`.
  static const String galleryDay = '/gallery/day/:key';

  /// The path of the day [key] of the gallery.
  static String galleryDayOf(String key) =>
      '/gallery/day/${Uri.encodeComponent(key)}';

  /// Develops photos taken before with a film. It needs the photos that
  /// were chosen (an [ImportBatch]) as the extra data of the route: without
  /// them it goes back to the gallery.
  static const String importPhotos = '/import';

  /// The settings of the app.
  static const String settings = '/settings';

  /// The tutorial: three screens, reached from the settings. A new user goes
  /// straight to the camera instead (see the hint of the camera).
  static const String onboarding = '/welcome';

  /// The disposable camera: a locked screen with nothing but the shutter.
  /// While a disposable roll is in the camera the app shows only this route.
  static const String disposable = '/disposable';

  /// The roll [id].
  static const String roll = '/roll/:id';

  /// The path of the roll [id].
  static String rollOf(String id) => '/roll/${Uri.encodeComponent(id)}';
}

/// Whether the benchmark screen exists in this build: debug, profile and the
/// builds made with `--dart-define=CARRETE_BENCH=true`. Never in a plain
/// release, where another app could open it through the platform's initial
/// route.
const bool benchAvailable =
    kDebugMode || kProfileMode || bool.fromEnvironment('CARRETE_BENCH');

/// Where the app starts: the camera, or the benchmark for the lead's measures.
const String _initialLocation = bool.fromEnvironment('CARRETE_BENCH')
    ? AppRoutes.bench
    : AppRoutes.camera;

/// The router of the app.
final routerProvider = Provider<GoRouter>((ref) {
  // The lock changes what every route may show, so the router checks its
  // redirects again whenever the lock is taken or released.
  final refresh = _Refresh();
  ref.listen(disposableLockProvider, (_, _) => refresh.notify());
  final router = buildRouter(
    disposableLock: () => ref.read(disposableLockProvider),
    refreshListenable: refresh,
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// Lets the router be told to run its redirects again.
class _Refresh extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// The router of the app, opening [initialLocation]. The benchmark route is
/// registered only with [benchEnabled].
///
/// When [disposableLock] is given and answers a roll id, a disposable camera is
/// in the camera: every route leads to [AppRoutes.disposable], so a restart (or
/// a notification) cannot take the phone out of the mode. With no lock the
/// disposable route leads back to the camera. [refreshListenable] says when
/// the answer may have changed.
GoRouter buildRouter({
  String initialLocation = _initialLocation,
  bool benchEnabled = benchAvailable,
  int? Function()? disposableLock,
  Listenable? refreshListenable,
}) {
  return GoRouter(
    initialLocation: !benchEnabled && initialLocation == AppRoutes.bench
        ? AppRoutes.camera
        : initialLocation,
    // The initial route comes from here, never from the intent that started
    // the activity (`am start --es route ...`).
    overridePlatformDefaultLocation: true,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      if (disposableLock != null) {
        final locked = disposableLock() != null;
        final onDisposable = state.matchedLocation == AppRoutes.disposable;
        if (locked && !onDisposable) return AppRoutes.disposable;
        if (!locked && onDisposable) return AppRoutes.camera;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.camera,
        builder: (context, state) => const ViewfinderScreen(),
      ),
      if (benchEnabled)
        GoRoute(
          path: AppRoutes.bench,
          builder: (context, state) => const PocScreen(),
        ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.gallery,
        builder: (context, state) => const GalleryScreen(),
      ),
      GoRoute(
        path: AppRoutes.galleryDay,
        builder: (context, state) =>
            GalleryDayScreen(dayKey: state.pathParameters['key'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.importPhotos,
        redirect: (context, state) =>
            state.extra is ImportBatch ? null : AppRoutes.gallery,
        builder: (context, state) =>
            ImportScreen(batch: state.extra! as ImportBatch),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.disposable,
        builder: (context, state) => const DisposableScreen(),
      ),
      GoRoute(
        path: AppRoutes.roll,
        builder: (context, state) =>
            RollScreen(id: state.pathParameters['id'] ?? ''),
      ),
    ],
  );
}
