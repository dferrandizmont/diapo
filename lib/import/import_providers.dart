import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../capture/capture_providers.dart';
import '../capture/film_capture_processor.dart';
import '../gallery/photo_library.dart';
import '../platform/photo_actions.dart';
import '../platform/media_store.dart';
import '../render/film_resources.dart';
import 'import_developer.dart';
import 'import_intake.dart';

/// The Photo Picker of the system. Overridden in the tests.
final importPickerProvider = Provider<ImportPicker>(
  (ref) => ImagePickerImportPicker(),
);

/// The folder where the chosen photos wait: `<cache>/import/`.
final importStagingProvider = Provider<ImportStaging>((ref) {
  final cache = ref.watch(cacheDirectoryProvider);
  return ImportStaging(
    Directory('${cache.path}/import'),
    cacheDirectory: cache,
  );
});

/// Takes the photos the person chooses from their gallery.
final importIntakeProvider = Provider<ImportIntake>(
  (ref) => ImportIntake(
    picker: ref.watch(importPickerProvider),
    staging: ref.watch(importStagingProvider),
    readDates: MediaStore.readExifDates,
  ),
);

/// Develops the chosen photos. Overridden in the tests.
final importDeveloperProvider = Provider<ImportDeveloper>(
  (ref) => ImportDeveloper(
    processorFactory: (onSaved) => FilmCaptureProcessor(
      loadProgram: () async {
        final resources = await ref.read(filmResourcesProvider.future);
        if (resources == null) {
          throw StateError('The film shader is not available.');
        }
        return resources.program;
      },
      // Not durable on purpose: an import that is cut short keeps nothing
      // and is not retried on the next start.
      onSaved: onSaved,
    ),
    recorder: ref.watch(looseShotRecorderProvider),
    library: ref.watch(photoLibraryProvider),
    actions: ref.watch(photoActionsProvider),
  ),
);

/// The picture of the photo at [path] for the preview of the import screen,
/// bounded in area and on both sides so a 50 MP photo never becomes a 200 MB
/// texture.
/// Overridden in the tests.
final importPreviewProvider = Provider.family<ImageProvider, String>(
  (ref, path) => ResizeImage(
    FileImage(File(path)),
    width: kImportPreviewSide,
    height: kImportPreviewSide,
    policy: ResizeImagePolicy.fit,
    allowUpscaling: false,
  ),
);

/// The picture of the photo at [path] for a thumbnail (the strip and the
/// windows of the cartridges).
final importThumbnailProvider = Provider.family<ImageProvider, String>(
  (ref, path) => ResizeImage(
    FileImage(File(path)),
    width: kImportThumbnailSide,
    height: kImportThumbnailSide,
    policy: ResizeImagePolicy.fit,
    allowUpscaling: false,
  ),
);

/// The box the preview is decoded to fit in, on both sides, keeping the
/// proportion: at most 1600 x 1600 pixels (2.6 MP), enough for a phone screen.
const int kImportPreviewSide = 1600;

/// The box a thumbnail is decoded to fit in, on both sides.
const int kImportThumbnailSide = 240;
