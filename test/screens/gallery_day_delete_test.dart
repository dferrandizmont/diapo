import 'dart:async';

import 'package:diapo/app.dart';
import 'package:diapo/core/database/app_database.dart';
import 'package:diapo/core/router.dart';
import 'package:diapo/core/settings/settings_provider.dart';
import 'package:diapo/gallery/gallery_content.dart';
import 'package:diapo/gallery/photo_library.dart';
import 'package:diapo/platform/gallery_images.dart';
import 'package:diapo/platform/photo_actions.dart';
import 'package:diapo/render/film_resources.dart';
import 'package:diapo/screens/gallery/gallery_screen.dart';
import 'package:diapo/roll/roll_providers.dart';
import 'package:diapo/screens/roll/frame_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../support/roll_fakes.dart';

DateTime _taken(int i) => DateTime(2026, 11, 13, 9).add(Duration(minutes: i));

class _UpdatingPhotoLibrary extends FakePhotoLibrary {
  _UpdatingPhotoLibrary(this.controller, this.shots);

  final StreamController<List<ShotRow>> controller;
  final List<ShotRow> shots;

  @override
  Future<PhotoDeletion> delete(int shotId, String location) async {
    deleted.add((shotId, location));
    shots.removeWhere((s) => s.id == shotId);
    controller.add(List<ShotRow>.from(shots));
    return deletion;
  }
}

Future<GoRouter> _pumpGalleryDay(
  WidgetTester tester, {
  required Stream<List<ShotRow>> shotsStream,
  required FakeGalleryImages images,
  required PhotoLibrary library,
  String initialLocation = AppRoutes.gallery,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final router = buildRouter(initialLocation: initialLocation);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        routerProvider.overrideWithValue(router),
        recipeBookProvider.overrideWith((ref) async => testBook()),
        rollsListProvider.overrideWith((ref) => Stream.value(const [])),
        galleryShotsProvider.overrideWith((ref) => shotsStream),
        galleryImagesProvider.overrideWithValue(images),
        photoLibraryProvider.overrideWithValue(library),
        rollClockProvider.overrideWithValue(() => DateTime(2026, 11, 13, 12)),
      ],
      child: const CarreteApp(),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('last photo of a day deleted lands on the gallery', (
    tester,
  ) async {
    final shots = [looseShotRow(1, takenAt: _taken(1))];
    final controller = StreamController<List<ShotRow>>();
    addTearDown(controller.close);
    final images = FakeGalleryImages({
      for (var s in shots) s.galleryUri!: tinyPng,
    });
    final library = _UpdatingPhotoLibrary(controller, List.of(shots))
      ..deletion = PhotoDeletion.deleted;
    final router = await _pumpGalleryDay(
      tester,
      shotsStream: controller.stream,
      images: images,
      library: library,
      initialLocation: AppRoutes.settings,
    );
    controller.add(shots);
    await tester.pumpAndSettle();
    // In the app the gallery is pushed over the camera: push it over another
    // page here too, so the stack under it can be checked.
    unawaited(router.push(AppRoutes.gallery));
    await tester.pumpAndSettle();
    final gallery = tester.state(find.byType(GalleryScreen));

    await tester.tap(find.textContaining('Today'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('frame-1')));
    await tester.pumpAndSettle();
    expect(find.byType(FrameViewer), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('viewer-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.byType(FrameViewer), findsNothing);
    expect(find.text('Gallery'), findsOneWidget);
    // Back to the same gallery, not a new one: the stack under it (the camera)
    // is kept and nothing is rebuilt in the middle of a frame.
    expect(tester.state(find.byType(GalleryScreen)), same(gallery));
    expect(router.canPop(), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a photo that is not the last stays on the day', (tester) async {
    final shots = [
      looseShotRow(1, takenAt: _taken(1)),
      looseShotRow(2, takenAt: _taken(2)),
    ];
    final controller = StreamController<List<ShotRow>>();
    addTearDown(controller.close);
    final images = FakeGalleryImages({
      for (var s in shots) s.galleryUri!: tinyPng,
    });
    final library = _UpdatingPhotoLibrary(controller, List.of(shots))
      ..deletion = PhotoDeletion.deleted;
    await _pumpGalleryDay(
      tester,
      shotsStream: controller.stream,
      images: images,
      library: library,
    );
    controller.add(shots);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Today'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('frame-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('viewer-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.byType(FrameViewer), findsOneWidget);
  });

  testWidgets('a day emptied while open pops to the gallery', (tester) async {
    final controller = StreamController<List<ShotRow>>();
    addTearDown(controller.close);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final router = buildRouter(initialLocation: AppRoutes.gallery);
    addTearDown(router.dispose);
    final shots = [looseShotRow(1, takenAt: _taken(1))];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          routerProvider.overrideWithValue(router),
          recipeBookProvider.overrideWith((ref) async => testBook()),
          rollsListProvider.overrideWith((ref) => Stream.value(const [])),
          galleryShotsProvider.overrideWith((ref) => controller.stream),
          galleryImagesProvider.overrideWithValue(
            FakeGalleryImages({'content://media/1': tinyPng}),
          ),
          photoLibraryProvider.overrideWithValue(FakePhotoLibrary()),
          rollClockProvider.overrideWithValue(() => DateTime(2026, 11, 13, 12)),
        ],
        child: const CarreteApp(),
      ),
    );
    await tester.pumpAndSettle();
    controller.add(shots);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Today'));
    await tester.pumpAndSettle();

    controller.add(const []);
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    expect(find.text('Gallery'), findsOneWidget);
  });

  testWidgets('a day emptied while the viewer is open pops after Back', (
    tester,
  ) async {
    final shots = [looseShotRow(1, takenAt: _taken(1))];
    final controller = StreamController<List<ShotRow>>();
    addTearDown(controller.close);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final router = buildRouter(initialLocation: AppRoutes.gallery);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          routerProvider.overrideWithValue(router),
          recipeBookProvider.overrideWith((ref) async => testBook()),
          rollsListProvider.overrideWith((ref) => Stream.value(const [])),
          galleryShotsProvider.overrideWith((ref) => controller.stream),
          galleryImagesProvider.overrideWithValue(
            FakeGalleryImages({'content://media/1': tinyPng}),
          ),
          photoLibraryProvider.overrideWithValue(FakePhotoLibrary()),
          rollClockProvider.overrideWithValue(() => DateTime(2026, 11, 13, 12)),
        ],
        child: const CarreteApp(),
      ),
    );
    await tester.pumpAndSettle();
    controller.add(shots);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Today'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('frame-1')));
    await tester.pumpAndSettle();
    expect(find.byType(FrameViewer), findsOneWidget);

    controller.add(const []);
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    expect(find.byType(FrameViewer), findsOneWidget);

    Navigator.of(tester.element(find.byType(FrameViewer))).pop();
    await tester.pumpAndSettle();

    expect(find.byType(FrameViewer), findsNothing);
    expect(find.text('Gallery'), findsOneWidget);
  });
}
