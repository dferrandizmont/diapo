import 'package:carrete/core/settings/app_settings.dart';
import 'package:carrete/core/settings/film_tuning.dart';
import 'package:carrete/capture/capture_queue.dart';
import 'package:carrete/capture/film_capture_processor.dart';
import 'package:carrete/import/import_intake.dart';
import 'package:carrete/import/import_job.dart';
import 'package:carrete/platform/exif_dates.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  final book = testBook();
  final photo = ImportPhoto(
    path: '/cache/import/photo_0.jpg',
    date: PhotoDate(
      wall: DateTime(1999, 8, 21, 14),
      instant: DateTime(1999, 8, 21, 15),
    ),
  );
  final developedAt = DateTime(2026, 11, 13, 20, 15, 30, 250);

  CaptureJob job({
    ImportPhoto? of,
    String film = 'gamma',
    FilmTuning tuning = FilmTuning.defaults,
    bool includeLocation = false,
    DateStampStyle style = DateStampStyle.yearFirst,
  }) => importJobFor(
    photo: of ?? photo,
    recipe: book.byId(film)!,
    tuning: tuning,
    stampStyle: style,
    includeLocation: includeLocation,
    developedAt: developedAt,
    captureId: 'imp0000001',
  );

  test('imports apply cinema bands only in 16:9', () {
    for (final format in FrameFormat.values) {
      final made = job(tuning: FilmTuning(cinemaBands: true, format: format));
      expect(made.look.cinemaBands, isTrue);
      expect(made.cinemaBands, format == FrameFormat.r16x9);
    }
    expect(
      job(
        tuning: const FilmTuning(cinemaBands: false, format: FrameFormat.r16x9),
      ).cinemaBands,
      isFalse,
    );
  });

  test('prints the date of the photo, never the day it is developed', () {
    final made = job();

    // gamma has the date imprint on by default.
    expect(made.stampText, "'99 8 21");
    expect(job(style: DateStampStyle.dayFirst).stampText, "21 8 '99");
  });

  test('prints the clock of the camera, not the instant with the offset', () {
    // wall 14:00, instant 15:00: the imprint says the date of the wall.
    final night = ImportPhoto(
      path: '/p.jpg',
      date: PhotoDate(
        wall: DateTime(2020, 12, 31, 23, 30),
        instant: DateTime(2021, 1, 1, 4, 30),
      ),
    );
    expect(job(of: night).stampText, "'20 12 31");
  });

  test('a photo with no date gets no imprint, even on a film that has it', () {
    const undated = ImportPhoto(path: '/p.jpg');

    final made = job(of: undated);

    expect(made.stampText, isNull);
    // It is placed on the day it is developed.
    expect(made.takenAt, developedAt);
  });

  test('the own gallery places the photo on the day it was taken', () {
    expect(job().takenAt, DateTime(1999, 8, 21, 15));
    expect(job().takenAt, isNot(developedAt));
  });

  test('prints no date for a film or a tuning that has it off', () {
    expect(job(film: 'alpha').stampText, isNull);
    expect(job(tuning: const FilmTuning(dateStamp: false)).stampText, isNull);
    expect(
      job(film: 'alpha', tuning: const FilmTuning(dateStamp: true)).stampText,
      "'99 8 21",
    );
  });

  test('takes the look and the format from the film and the tuning', () {
    final plain = job(film: 'alpha');
    expect(plain.format, FrameFormat.r3x2);
    expect(plain.whiteFrame, isFalse);

    final tuned = job(
      film: 'alpha',
      tuning: const FilmTuning(halation: 1.5, format: FrameFormat.r16x9),
    );
    expect(tuned.format, FrameFormat.r16x9);
    expect(tuned.tuning.halation, 1.5);
    expect(tuned.look.halationAmount, greaterThan(plain.look.halationAmount));
  });

  test('puts the white frame on a square instant film only', () {
    expect(job().whiteFrame, isTrue);
    expect(
      job(tuning: const FilmTuning(format: FrameFormat.r3x2)).whiteFrame,
      false,
    );
  });

  test('keeps the location only when the setting says so', () {
    expect(job().includeLocation, isFalse);
    expect(job(includeLocation: true).includeLocation, isTrue);
  });

  test('is a loose shot developed now, from the copy of the photo', () {
    final made = job();

    expect(made.filePath, photo.path);
    expect(made.captureId, 'imp0000001');
    expect(made.fieldAspect, isNull);
    expect(
      FilmCaptureProcessor.exportNameOf(made),
      'CARRETE_19990821_150000_000_imp0000001',
    );
  });

  test('two photos of a batch never share a name', () {
    final a = importJobFor(
      photo: photo,
      recipe: book.byId('alpha')!,
      tuning: FilmTuning.defaults,
      stampStyle: DateStampStyle.yearFirst,
      includeLocation: false,
      developedAt: developedAt,
    );
    final b = importJobFor(
      photo: photo,
      recipe: book.byId('alpha')!,
      tuning: FilmTuning.defaults,
      stampStyle: DateStampStyle.yearFirst,
      includeLocation: false,
      developedAt: developedAt,
    );
    expect(
      FilmCaptureProcessor.exportNameOf(a),
      isNot(FilmCaptureProcessor.exportNameOf(b)),
    );
  });
}
