import 'package:diapo/app.dart';
import 'package:diapo/core/router.dart';
import 'package:diapo/core/database/app_database.dart';
import 'package:diapo/core/settings/settings_provider.dart';
import 'package:diapo/gallery/gallery_content.dart';
import 'package:diapo/gallery/photo_library.dart';
import 'package:diapo/roll/roll_providers.dart';
import 'package:diapo/platform/gallery_images.dart';
import 'package:diapo/render/film_resources.dart';
import 'package:flutter/widgets.dart' show Scrollable, ValueKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../support/roll_fakes.dart';

/// The paths of the top-level routes of [router].
List<String> _paths(GoRouter router) => [
  for (final route in router.configuration.routes)
    if (route is GoRoute) route.path,
];

void main() {
  group('the benchmark route', () {
    test('is not registered in a release-like router', () {
      final router = buildRouter(
        initialLocation: AppRoutes.settings,
        benchEnabled: false,
      );
      addTearDown(router.dispose);
      expect(_paths(router), isNot(contains(AppRoutes.bench)));
      expect(_paths(router), contains(AppRoutes.camera));
      expect(router.configuration.routes, isNotEmpty);
    });

    test('is registered when the benchmark is enabled', () {
      final router = buildRouter(
        initialLocation: AppRoutes.settings,
        benchEnabled: true,
      );
      addTearDown(router.dispose);
      expect(_paths(router), contains(AppRoutes.bench));
    });

    test('a release-like router never starts on the benchmark', () {
      final router = buildRouter(
        initialLocation: AppRoutes.bench,
        benchEnabled: false,
      );
      addTearDown(router.dispose);
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.camera);
    });
  });

  testWidgets('the app opens the settings screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    // The camera is not opened in the tests: the router starts on the
    // settings.
    final router = buildRouter(initialLocation: AppRoutes.settings);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          routerProvider.overrideWithValue(router),
          recipeBookProvider.overrideWith((ref) async => testBook()),
        ],
        child: const CarreteApp(),
      ),
    );
    await tester.pumpAndSettle();

    // The strings of the test are the ones of the English language, the
    // language of the tests.
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Grid'), findsOneWidget);
    // The list is lazy and longer than the test screen: scroll to the section.
    await tester.scrollUntilVisible(
      find.text('DEFAULT FILM'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('DEFAULT FILM'), findsOneWidget);
    // The settings that are not implemented yet are not listed.
    expect(find.text('Shutter sound'), findsNothing);
  });

  group('the gallery', () {
    Future<GoRouter> pump(
      WidgetTester tester,
      String location, {
      List<ShotRow> shots = const [],
    }) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final router = buildRouter(initialLocation: location);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            routerProvider.overrideWithValue(router),
            recipeBookProvider.overrideWith((ref) async => testBook()),
            rollsListProvider.overrideWith((ref) => Stream.value(const [])),
            galleryShotsProvider.overrideWith((ref) => Stream.value(shots)),
            galleryImagesProvider.overrideWithValue(FakeGalleryImages()),
            photoLibraryProvider.overrideWithValue(FakePhotoLibrary()),
          ],
          child: const CarreteApp(),
        ),
      );
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('the gallery route opens the gallery', (tester) async {
      await pump(tester, AppRoutes.gallery);

      expect(find.text('Gallery'), findsOneWidget);
      expect(find.text('No photos yet'), findsOneWidget);
    });

    testWidgets('a day of the gallery has its own route', (tester) async {
      final shot = looseShotRow(1, takenAt: DateTime.now());
      await pump(tester, AppRoutes.gallery, shots: [shot]);

      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      // The contact sheet of the day, with its first frame.
      expect(find.byKey(const ValueKey('frame-1')), findsOneWidget);
      expect(find.text('1 frame'), findsWidgets);
    });

    testWidgets('a day that is not there does not break the route', (
      tester,
    ) async {
      await pump(tester, AppRoutes.galleryDayOf('20240101'));

      expect(find.text('This day cannot be found'), findsOneWidget);
    });
  });
}
