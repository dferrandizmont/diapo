import 'dart:io';

import 'package:diapo/app.dart';
import 'package:diapo/core/router.dart';
import 'package:diapo/core/settings/settings_provider.dart';
import 'package:diapo/gallery/gallery_content.dart';
import 'package:diapo/gallery/photo_library.dart';
import 'package:diapo/import/import_intake.dart';
import 'package:diapo/import/import_providers.dart';
import 'package:diapo/platform/exif_dates.dart';
import 'package:diapo/platform/gallery_images.dart';
import 'package:diapo/render/film_resources.dart';
import 'package:diapo/roll/roll_providers.dart';
import 'package:diapo/screens/gallery/gallery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../support/roll_fakes.dart';
import '../support/roll_harness.dart';

class _FakeStaging extends ImportStaging {
  _FakeStaging()
    : super(Directory('/staging'), cacheDirectory: Directory('/cache'));

  int cleared = 0;

  @override
  Future<void> clear() async => cleared++;
}

/// An intake that answers what it is told: a batch, nothing (the person
/// closed the picker) or an error.
class _FakeIntake implements ImportIntake {
  ImportBatch? batch;
  Object? error;
  int picks = 0;

  @override
  Future<ImportBatch?> pick() async {
    picks++;
    final failure = error;
    if (failure != null) throw failure;
    return batch;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _batch = ImportBatch([
  ImportPhoto(
    path: '/staging/photo_0.jpg',
    date: PhotoDate(wall: DateTime(2001, 2, 3), instant: DateTime(2001, 2, 3)),
  ),
  const ImportPhoto(path: '/staging/photo_1.jpg'),
]);

void main() {
  late _FakeIntake intake;
  late _FakeStaging staging;

  Future<GoRouter> pump(WidgetTester tester, String location) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final router = buildRouter(initialLocation: location);
    addTearDown(router.dispose);
    intake = _FakeIntake();
    staging = _FakeStaging();
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(412, 915);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          routerProvider.overrideWithValue(router),
          recipeBookProvider.overrideWith((ref) async => testBook()),
          filmResourcesProvider.overrideWith((ref) async => null),
          rollsListProvider.overrideWith((ref) => Stream.value(const [])),
          galleryShotsProvider.overrideWith((ref) => Stream.value(const [])),
          galleryImagesProvider.overrideWithValue(FakeGalleryImages()),
          photoLibraryProvider.overrideWithValue(FakePhotoLibrary()),
          importIntakeProvider.overrideWithValue(intake),
          importStagingProvider.overrideWithValue(staging),
          importPreviewProvider.overrideWith(
            (ref, path) => MemoryImage(tinyPng),
          ),
          importThumbnailProvider.overrideWith(
            (ref, path) => MemoryImage(tinyPng),
          ),
        ],
        child: const CarreteApp(),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('the gallery offers to develop photos of the phone', (
    tester,
  ) async {
    await pump(tester, AppRoutes.gallery);

    expect(find.text('Develop photos from your phone'), findsOneWidget);
    expect(find.text('No photos yet'), findsOneWidget);
  });

  testWidgets('the row opens the import screen with the chosen photos', (
    tester,
  ) async {
    await pump(tester, AppRoutes.gallery);
    intake.batch = _batch;

    await tester.tap(find.text('Develop photos from your phone'));
    await tester.pumpAndSettle();

    expect(intake.picks, 1);
    expect(find.text('DEVELOP PHOTOS'), findsOneWidget);
    expect(find.text('1 of 2'), findsOneWidget);
  });

  testWidgets('closing the import screen goes back to the gallery', (
    tester,
  ) async {
    final router = await pump(tester, AppRoutes.gallery);
    intake.batch = _batch;
    await tester.tap(find.text('Develop photos from your phone'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('import-close-key')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.gallery);
    expect(find.byType(GalleryScreen), findsOneWidget);
    expect(staging.cleared, greaterThan(0));
  });

  testWidgets('photos all too big to open say so and open nothing', (
    tester,
  ) async {
    await pump(tester, AppRoutes.gallery);
    intake.batch = const ImportBatch([], rejected: 2);

    await tester.tap(find.text('Develop photos from your phone'));
    await tester.pumpAndSettle();

    expect(
      find.text('2 photos are too big and were left out.'),
      findsOneWidget,
    );
    expect(find.text('DEVELOP PHOTOS'), findsNothing);
  });

  testWidgets('a picker closed with no photo stays in the gallery', (
    tester,
  ) async {
    final router = await pump(tester, AppRoutes.gallery);
    intake.batch = null;

    await tester.tap(find.text('Develop photos from your phone'));
    await tester.pumpAndSettle();

    expect(intake.picks, 1);
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.gallery);
  });

  testWidgets('a picker that fails says so and stays in the gallery', (
    tester,
  ) async {
    final router = await pump(tester, AppRoutes.gallery);
    intake.error = StateError('no picker');

    await tester.tap(find.text('Develop photos from your phone'));
    await tester.pumpAndSettle();

    expect(find.text('Could not open your photos.'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.gallery);
  });

  testWidgets('the import route without photos goes to the gallery', (
    tester,
  ) async {
    final router = await pump(tester, AppRoutes.importPhotos);

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.gallery);
    expect(find.text('Develop photos from your phone'), findsOneWidget);
  });

  testWidgets('the row speaks Spanish and Catalan', (tester) async {
    await pumpRollApp(
      tester,
      const GalleryScreen(),
      overrides: [
        ...rollOverrides(),
        photoLibraryProvider.overrideWithValue(FakePhotoLibrary()),
        galleryShotsProvider.overrideWith((ref) => Stream.value(const [])),
      ],
      locale: const Locale('es'),
    );
    expect(find.text('Revelar fotos del móvil'), findsOneWidget);

    await pumpRollApp(
      tester,
      const GalleryScreen(),
      overrides: [
        ...rollOverrides(),
        photoLibraryProvider.overrideWithValue(FakePhotoLibrary()),
        galleryShotsProvider.overrideWith((ref) => Stream.value(const [])),
      ],
      locale: const Locale('ca'),
    );
    expect(find.text('Revela fotos del mòbil'), findsOneWidget);
  });

  testWidgets('the row calls onImport when the screen is given one', (
    tester,
  ) async {
    var imports = 0;
    await pumpRollApp(
      tester,
      GalleryScreen(onImport: () => imports++),
      overrides: [
        ...rollOverrides(),
        photoLibraryProvider.overrideWithValue(FakePhotoLibrary()),
        galleryShotsProvider.overrideWith((ref) => Stream.value(const [])),
      ],
    );

    await tester.tap(find.text('Develop photos from your phone'));
    await tester.pump();

    expect(imports, 1);
  });
}
