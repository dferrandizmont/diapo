import 'package:film_recipes/film_recipes.dart';

import '../camera/camera_flash.dart';
import '../capture/capture_queue.dart';
import '../capture/date_stamp.dart';
import '../capture/film_capture_processor.dart';
import '../core/settings/app_settings.dart';
import '../core/settings/film_tuning.dart';
import '../screens/viewfinder/viewfinder_state.dart' show lookFor;
import 'import_intake.dart';

/// The job that develops [photo] with [recipe] and the [tuning] the person
/// chose: the same look, crop, date imprint and white frame the camera gives a
/// shot, so a photo developed from the gallery is the same as one taken.
///
/// - The date imprint prints the date the photo was taken (the clock of the
///   camera, [PhotoDate.wall]), never today's. A photo with no date gets no
///   imprint, even on a film that has it on.
/// - The photo is placed in the own gallery on the day it was taken
///   ([PhotoDate.instant]); with no date, on [developedAt], the moment it is
///   developed. That moment also seeds the grain, and with the capture id it
///   names the exported file, so give every photo of a batch its own.
/// - GPS tags of the photo go into the export only with [includeLocation]
///   (the "save location" setting); otherwise the native side strips them.
CaptureJob importJobFor({
  required ImportPhoto photo,
  required Recipe recipe,
  required FilmTuning tuning,
  required DateStampStyle stampStyle,
  required bool includeLocation,
  required DateTime developedAt,
  String? captureId,
}) {
  final look = lookFor(recipe, tuning, CarreteFlash.off);
  final format = look.format;
  return CaptureJob(
    filePath: photo.path,
    filmId: recipe.id,
    look: look,
    format: format,
    seed: grainSeedOf(developedAt),
    takenAt: photo.date?.instant ?? developedAt,
    tuning: tuning,
    stampText: look.dateStamp && photo.date != null
        ? DateStamp.format(photo.date!.wall, stampStyle)
        : null,
    whiteFrame: look.whiteFrame && format == FrameFormat.r1x1,
    cinemaBands: look.cinemaBands && format == FrameFormat.r16x9,
    includeLocation: includeLocation,
    captureId: captureId ?? newCaptureId(),
  );
}
