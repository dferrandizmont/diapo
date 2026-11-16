import 'dart:async';

import 'package:film_recipes/film_recipes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../camera/camera_flash.dart';
import '../capture/capture_queue.dart';
import '../core/database/app_database.dart';
import '../core/database/tables.dart';
import '../core/settings/film_tuning.dart';
import '../core/settings/settings_provider.dart';

/// The photos of a disposable camera: always 27, like the ones at a wedding.
const int kDisposableFrames = 27;

/// The film of the disposable camera. It is fixed: nobody picks a film on a
/// camera that is passed from hand to hand.
const String kDisposableFilmId = 'desechable';

/// The fine tuning of the disposable camera: none, but the frame is the 3:2 of
/// a real 35 mm disposable. The film's own default is the square instant frame
/// with a white border, which a disposable never has.
const FilmTuning kDisposableTuning = FilmTuning(format: FrameFormat.r3x2);

/// When the photos of a disposable develop unless the person who starts it
/// picks another time: the next morning, after the party.
const DevelopDelay kDisposableDefaultDelay = DevelopDelay.nextMorning;

/// Which disposable roll is in the camera right now, if any.
///
/// A disposable that is open is either "in the camera" (the screen is locked to
/// it and only a long press leaves) or set aside (the person left on purpose;
/// the roll stays open and behaves like any open roll). The roll is in the
/// camera while this holds its id. It is stored on the device, so a restart
/// returns straight to the disposable camera.
class DisposableLock extends Notifier<int?> {
  static const String _key = 'carrete.disposable.rollId';

  @override
  int? build() => ref.watch(sharedPreferencesProvider).getInt(_key);

  /// The roll in the camera now, or null.
  int? get current => state;

  /// Puts the disposable roll [rollId] in the camera.
  Future<void> lock(int rollId) async {
    state = rollId;
    await ref.read(sharedPreferencesProvider).setInt(_key, rollId);
  }

  /// Takes the disposable camera away: the roll is set aside or finished.
  Future<void> release() async {
    state = null;
    await ref.read(sharedPreferencesProvider).remove(_key);
  }

  /// Releases the lock when it points at something that is not an open
  /// disposable roll any more (the roll closed, was thrown away or is gone).
  ///
  /// With [only], it is released only while the lock still holds that id: an
  /// answer that was asked for before the lock changed must not clear a newer
  /// one.
  Future<void> releaseIfStale(RollRow? active, {int? only}) async {
    final id = state;
    if (id == null || (only != null && id != only)) return;
    final live =
        active != null &&
        active.id == id &&
        active.mode == RollMode.disposable &&
        active.state == RollState.open;
    if (!live) await release();
  }
}

/// The id of the disposable roll that is in the camera, or null.
final disposableLockProvider = NotifierProvider<DisposableLock, int?>(
  DisposableLock.new,
);

/// Checks the lock against the first answer of the database ([answer], the open
/// roll or null) when the app starts.
///
/// It waits up to [wait] so the camera of design A never shows for a moment. A
/// late answer is checked just the same: whenever it comes, a lock with no open
/// disposable roll of its id behind it is dropped. With no answer at all the
/// lock stays, and the screen's exit stamp is the way out.
Future<void> reconcileDisposableLock(
  DisposableLock lock,
  Future<RollRow?> answer, {
  Duration wait = const Duration(seconds: 3),
}) async {
  // The answer is about the lock of now, not about a later one.
  final asked = lock.current;
  // Never an unhandled error, whenever the answer fails.
  final checked = answer.then<void>(
    (active) => lock.releaseIfStale(active, only: asked),
    onError: (Object _) {},
  );
  try {
    await checked.timeout(wait);
  } on TimeoutException {
    // The check goes on in the background and still applies.
  }
}

/// The job as a frame of a disposable camera has to be: the fixed 3:2 look of
/// [kDisposableTuning] and no white border, whatever the screen that took the
/// photo asked for. The film, the flash, the date and the rest are kept.
///
/// The roll service applies it to every frame of a disposable roll, so no path
/// (the locked screen, the camera of design A, a recovered capture) can put a
/// photo of another shape into the party's roll.
CaptureJob disposableFrame(CaptureJob job, RecipeBook book) {
  final recipe = book.byId(job.filmId) ?? book.recipes.first;
  final look = lookWithFlash(
    resolve(recipe, overrides: kDisposableTuning.overrides),
    job.flash,
  );
  return job.withFrame(
    look: look,
    format: kDisposableTuning.format ?? look.format,
    tuning: kDisposableTuning,
    whiteFrame: false,
  );
}
