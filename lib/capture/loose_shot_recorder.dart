import '../core/database/app_database.dart';
import '../core/database/converters.dart';
import '../core/database/shots_dao.dart';
import 'capture_queue.dart';
import 'film_capture_processor.dart';

/// Writes a loose photo (taken with no roll in the camera) into the database
/// once it is in the gallery of the system, so the own gallery can show it
/// with its film, day and size.
///
/// The photo is recorded after the save, never before, and by the shot's own
/// identity ([CaptureJob.captureId]): recording a shot twice (a retry after the
/// process died between the save and here) updates its row, and two shots of
/// the same moment stay two photos (see [ShotsDao.recordLooseShot]).
class LooseShotRecorder {
  const LooseShotRecorder(this._shots);

  final ShotsDao _shots;

  /// Records [job], saved as [still]. Throws when the database cannot: the
  /// caller then keeps the original and the sidecar of the shot, so it is
  /// recorded the next time. Returns the row of the shot.
  Future<ShotRow> record(CaptureJob job, SavedStill still) async {
    return _shots.recordLooseShot(
      filmId: job.filmId,
      format: ShotFormat.fromStorage(job.format.wireName),
      lens: job.lens,
      takenAt: job.takenAt,
      galleryUri: still.uri,
      captureId: job.captureId,
      width: still.width,
      height: still.height,
    );
  }
}
