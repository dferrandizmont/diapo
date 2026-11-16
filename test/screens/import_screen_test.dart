import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:diapo/capture/cinema_bands.dart';
import 'package:diapo/capture/date_stamp.dart';

import 'package:diapo/capture/capture_queue.dart';
import 'package:diapo/capture/film_capture_processor.dart';
import 'package:diapo/core/database/app_database.dart';
import 'package:diapo/core/settings/film_tuning_provider.dart';
import 'package:diapo/core/settings/film_tuning_repository.dart';
import 'package:diapo/ui/widgets/plastic_controls.dart';
import 'package:diapo/core/settings/settings_provider.dart';
import 'package:diapo/import/import_developer.dart';
import 'package:diapo/import/import_intake.dart';
import 'package:diapo/import/import_providers.dart';
import 'package:diapo/capture/loose_shot_recorder.dart';
import 'package:diapo/l10n/app_localizations.dart';
import 'package:diapo/platform/exif_dates.dart';
import 'package:diapo/platform/photo_actions.dart';
import 'package:diapo/render/film_resources.dart';
import 'package:diapo/screens/import/import_screen.dart';
import 'package:diapo/screens/viewfinder/film_shader_view.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../support/import_fakes.dart';
import '../support/roll_fakes.dart';

/// A staging folder that touches no disk: the tests count the clean-ups.
class _FakeStaging extends ImportStaging {
  _FakeStaging()
    : super(Directory('/staging'), cacheDirectory: Directory('/cache'));

  int cleared = 0;

  @override
  Future<void> clear() async => cleared++;
}

class _FakeRecorder implements LooseShotRecorder {
  int next = 1;

  @override
  Future<ShotRow> record(CaptureJob job, SavedStill still) async =>
      shotRow(next++, rollId: 1, galleryUri: still.uri);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Develops nothing: it records the job, waits for the gate and reports the
/// photo as saved. (The real processor deletes files with real IO, which a
/// widget test cannot wait for; its own tests cover it.)
class _FakeProcessor implements CaptureProcessor {
  _FakeProcessor(this.harness, this.onSaved);

  final _Harness harness;
  final Future<void> Function(CaptureJob job, SavedStill still) onSaved;

  @override
  Future<String?> process(CaptureJob job) async {
    harness.jobs.add(job);
    final gate = harness.gate;
    if (gate != null) await gate.future;
    final still = SavedStill('content://media/${harness.jobs.length}');
    await onSaved(job, still);
    return still.uri;
  }
}

class _Harness {
  final staging = _FakeStaging();
  final library = FakePhotoLibrary();
  final jobs = <CaptureJob>[];
  Completer<void>? gate;
  int leaves = 0;
}

PhotoDate _taken(int year, int month, int day) => PhotoDate(
  wall: DateTime(year, month, day),
  instant: DateTime(year, month, day),
);

final _photos = [
  ImportPhoto(path: '/staging/photo_0.jpg', date: _taken(2001, 2, 3)),
  ImportPhoto(path: '/staging/photo_1.jpg', date: _taken(2002, 3, 4)),
  ImportPhoto(path: '/staging/photo_2.jpg', date: _taken(2003, 4, 5)),
];

Future<_Harness> _pump(
  WidgetTester tester, {
  List<ImportPhoto>? photos,
  bool truncated = false,
  int rejected = 0,
  PhotoDeletion deletion = PhotoDeletion.deleted,
  double textScale = 1,
  bool reducedMotion = false,
  Size size = const Size(412, 915),
  Future<RecipeBook> Function()? book,
  Map<String, Object> initialPreferences = const {},
}) async {
  SharedPreferences.setMockInitialValues(initialPreferences);
  final prefs = await SharedPreferences.getInstance();
  final harness = _Harness();
  final developer = ImportDeveloper(
    processorFactory: (onSaved) => _FakeProcessor(harness, onSaved),
    recorder: _FakeRecorder(),
    library: harness.library..deletion = deletion,
    actions: FakePhotoActions(),
    deleteTemporary: (path) async {},
  );

  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        recipeBookProvider.overrideWith(
          (ref) async => book == null ? testBook() : await book(),
        ),
        filmResourcesProvider.overrideWith((ref) async => null),
        importStagingProvider.overrideWithValue(harness.staging),
        importDeveloperProvider.overrideWithValue(developer),
        importPreviewProvider.overrideWith((ref, path) => MemoryImage(tinyPng)),
        importThumbnailProvider.overrideWith(
          (ref, path) => MemoryImage(tinyPng),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reducedMotion,
          ),
          child: child!,
        ),
        home: ImportScreen(
          batch: ImportBatch(
            photos ?? _photos,
            truncated: truncated,
            rejected: rejected,
          ),
          onLeave: () => harness.leaves++,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return harness;
}

void main() {
  testWidgets('import preview applies cinema bands only in 16:9', (
    tester,
  ) async {
    for (final enabled in [true, false]) {
      for (final format in FrameFormat.values) {
        // Import takes a private copy of camera tuning when the screen opens.
        await tester.pumpWidget(const SizedBox.shrink());
        await _pump(
          tester,
          initialPreferences: {
            FilmTuningRepository.storageKey: jsonEncode({
              'alpha': {
                'cinemaBands': enabled,
                'format': format.wireName,
                'dateStamp': true,
              },
            }),
          },
        );
        await tester.pumpAndSettle();
        final bands = enabled && format == FrameFormat.r16x9;
        expect(
          find.byType(CinemaBandsOverlay),
          bands ? findsOneWidget : findsNothing,
        );
        expect(
          tester
              .widget<DateStampOverlay>(find.byType(DateStampOverlay))
              .cinemaBands,
          bands,
        );
        if (bands) {
          final gesture = await tester.startGesture(
            tester.getCenter(find.byKey(const ValueKey('import-photo'))),
          );
          await tester.pump();
          expect(find.byType(CinemaBandsOverlay), findsNothing);
          await gesture.up();
          await tester.pump();
          expect(find.byType(CinemaBandsOverlay), findsOneWidget);
        }
      }
    }
  });

  testWidgets('while the films load there is a spinner and a way out', (
    tester,
  ) async {
    final gate = Completer<RecipeBook>();
    final harness = await _pump(tester, book: () => gate.future);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Loading the films'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('import-close-key')));
    await tester.pump();
    await tester.pump();
    expect(harness.leaves, 1);
    gate.complete(testBook());
    await tester.pumpAndSettle();
  });

  testWidgets('if the films fail to load it says so and can be left', (
    tester,
  ) async {
    final harness = await _pump(
      tester,
      book: () async => throw StateError('no films'),
    );
    await tester.pump();

    expect(find.text('The films could not be loaded.'), findsOneWidget);
    expect(find.byKey(const ValueKey('import-close-key')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('import-close-key')));
    await tester.pump();
    await tester.pump();
    expect(harness.leaves, 1);
  });

  testWidgets('shows the first photo, its place in the batch and the strip', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('DEVELOP PHOTOS'), findsOneWidget);
    expect(find.text('1 of 3'), findsOneWidget);
    expect(find.text('Develop all 3 photos'), findsOneWidget);
    // One film carousel and a strip of three photos.
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.bySemanticsLabel('Photo 2 of 3'), findsOneWidget);
  });

  testWidgets('the film is applied to a photo, not to a camera texture', (
    tester,
  ) async {
    await _pump(tester);

    // The preview and the windows of the carousel: none flips its input like
    // a camera texture (that showed the photos upside down on a device).
    final views = tester.widgetList<FilmShaderView>(
      find.byType(FilmShaderView),
    );
    expect(views, isNotEmpty);
    expect(views.every((view) => !view.cameraTexture), isTrue);
  });

  testWidgets('a single photo has no strip and no counter', (tester) async {
    await _pump(tester, photos: [_photos.first]);

    expect(find.text('1 of 1'), findsNothing);
    expect(find.text('Develop the photo'), findsOneWidget);
  });

  testWidgets('moves between photos with the strip', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);

    await tester.tap(find.bySemanticsLabel('Photo 3 of 3'));
    await tester.pump();

    expect(find.text('3 of 3'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('holding the photo shows the original, letting go the film', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Original'), findsNothing);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('import-photo'))),
    );
    await tester.pump();
    expect(find.text('Original'), findsOneWidget);

    await gesture.up();
    await tester.pump();
    expect(find.text('Original'), findsNothing);
  });

  testWidgets('a cancelled touch also goes back to the film', (tester) async {
    await _pump(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('import-photo'))),
    );
    await tester.pump();
    expect(find.text('Original'), findsOneWidget);

    await gesture.cancel();
    await tester.pump();
    expect(find.text('Original'), findsNothing);
  });

  testWidgets('compare can be toggled without holding, for a screen reader', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);

    final photo = find.semantics.byLabel(RegExp('Photo 1 of 3, with the film'));
    expect(photo, findsOneWidget);
    tester.semantics.tap(photo);
    await tester.pump();
    expect(find.text('Original'), findsOneWidget);

    tester.semantics.tap(photo);
    await tester.pump();
    expect(find.text('Original'), findsNothing);
    handle.dispose();
  });

  testWidgets('the film chosen in the carousel is the one that develops', (
    tester,
  ) async {
    final harness = await _pump(tester, photos: [_photos.first]);

    await tester.tap(find.text('Beta'));
    await tester.pump();
    await tester.tap(find.text('Develop the photo'));
    await tester.pump();
    await tester.pump();

    expect(harness.jobs.single.filmId, 'beta');
  });

  testWidgets('the tuning is the camera one at first and changes here only', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final harness = await _pump(tester, photos: [_photos.first]);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ImportScreen)),
    );
    final cameraTuning = container.read(filmTuningsProvider);

    // Open the tuning and choose the square format.
    await tester.tap(find.byKey(const ValueKey('import-tune-key')));
    await tester.pump();
    await tester.tap(find.text('1:1'));
    await tester.pump();
    await tester.tap(find.text('Develop the photo'));
    await tester.pump();
    await tester.pump();

    expect(harness.jobs.single.format, FrameFormat.r1x1);
    expect(harness.jobs.single.tuning.format, FrameFormat.r1x1);
    // The tuning of the camera is untouched.
    expect(container.read(filmTuningsProvider), cameraTuning);
  });

  testWidgets('the cinema bands switch is in the tuning at 16:9 only', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final harness = await _pump(tester, photos: [_photos.first]);

    await tester.tap(find.byKey(const ValueKey('import-tune-key')));
    await tester.pump();
    expect(find.text('Cinema bands'), findsNothing);

    await tester.tap(find.text('16:9'));
    await tester.pump();
    expect(find.text('Cinema bands'), findsOneWidget);
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is PlasticSwitch && w.label == 'Cinema bands',
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Develop the photo'));
    await tester.pump();
    await tester.pump();
    expect(harness.jobs.single.tuning.cinemaBands, isTrue);
    expect(harness.jobs.single.format, FrameFormat.r16x9);
  });

  testWidgets('develops the whole batch with progress and then leaves', (
    tester,
  ) async {
    final harness = await _pump(tester);
    harness.gate = Completer<void>();

    await tester.tap(find.text('Develop all 3 photos'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Developing 1 of 3'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    // The film and the photos cannot be changed while it develops.
    expect(harness.jobs, hasLength(1));

    harness.gate!.complete();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(harness.jobs, hasLength(3));
    expect(harness.leaves, 1);
    expect(harness.library.deleted, isEmpty);
    // The copies are gone whichever way the screen ends.
    expect(harness.staging.cleared, greaterThan(0));
  });

  testWidgets('every photo of the batch has its own date and name', (
    tester,
  ) async {
    final harness = await _pump(tester);

    await tester.tap(find.text('Beta'));
    await tester.pump();
    await tester.tap(find.text('Develop all 3 photos'));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }

    expect(harness.jobs.map((j) => j.filePath), [
      '/staging/photo_0.jpg',
      '/staging/photo_1.jpg',
      '/staging/photo_2.jpg',
    ]);
    expect({
      for (final job in harness.jobs) FilmCaptureProcessor.exportNameOf(job),
    }, hasLength(3));
  });

  testWidgets('cancelling the export keeps nothing and leaves', (tester) async {
    final harness = await _pump(tester);
    harness.gate = Completer<void>();

    await tester.tap(find.text('Develop all 3 photos'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.text('Cancelling'), findsOneWidget);

    harness.gate!.complete();
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }

    // Only the photo in progress was ever developed, and it was deleted.
    expect(harness.jobs, hasLength(1));
    expect(harness.library.deleted, hasLength(1));
    expect(harness.leaves, 1);
  });

  testWidgets('leaving before developing keeps nothing', (tester) async {
    final harness = await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('import-close-key')));
    await tester.pump();
    await tester.pump();

    expect(harness.leaves, 1);
    expect(harness.jobs, isEmpty);
    expect(harness.staging.cleared, greaterThan(0));
  });

  testWidgets('the back gesture does the same as the close key', (
    tester,
  ) async {
    final harness = await _pump(tester);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump();

    expect(harness.leaves, 1);
    expect(harness.jobs, isEmpty);
  });

  testWidgets('says so when more photos were chosen than the limit', (
    tester,
  ) async {
    await _pump(tester, truncated: true);

    expect(
      find.text(
        'Only 30 photos can be developed at a time. '
        'The first ones were taken.',
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 4));
    expect(find.textContaining('Only 30 photos'), findsNothing);
  });

  testWidgets('says how many photos were too big to open', (tester) async {
    await _pump(tester, rejected: 2);

    expect(
      find.text('2 photos are too big and were left out.'),
      findsOneWidget,
    );
  });

  testWidgets('a photo with no date says no date will be printed', (
    tester,
  ) async {
    // gamma prints the date by default.
    await _pump(
      tester,
      photos: [const ImportPhoto(path: '/staging/photo_0.jpg')],
    );
    await tester.tap(find.text('Gamma'));
    await tester.pump();

    expect(find.text('No date: none will be printed'), findsOneWidget);
  });

  testWidgets('photos that cannot be removed after a cancel are told', (
    tester,
  ) async {
    final harness = await _pump(tester, deletion: PhotoDeletion.failed);
    harness.gate = Completer<void>();

    await tester.tap(find.text('Develop all 3 photos'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    harness.gate!.complete();
    for (var i = 0; i < 10; i++) {
      await tester.pump();
    }

    expect(find.text('Some photos stayed'), findsOneWidget);
    expect(
      find.textContaining('could not be removed from the gallery'),
      findsOneWidget,
    );
    // The screen waits for the person instead of closing in silence.
    expect(harness.leaves, 0);

    await tester.tap(find.text('Go to the gallery'));
    await tester.pump();
    await tester.pump();
    expect(harness.leaves, 1);
  });

  testWidgets('holds with a large text and reduced motion', (tester) async {
    await _pump(
      tester,
      textScale: 2,
      reducedMotion: true,
      size: const Size(360, 640),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Develop all 3 photos'), findsOneWidget);
  });
}
