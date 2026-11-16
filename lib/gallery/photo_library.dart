import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../core/database/database_provider.dart';
import '../core/database/shots_dao.dart';
import '../platform/photo_actions.dart';

/// Share and delete a photo of the gallery, keeping the database and the
/// gallery of the system in step.
abstract interface class PhotoLibrary {
  /// Opens the share sheet for the photo at [location]. False when it could
  /// not be done.
  Future<bool> share(String location);

  /// Deletes photo [shotId], at [location] in the gallery of the system.
  Future<PhotoDeletion> delete(int shotId, String location);

  /// Removes the rows of the photos that are no longer in the gallery of the
  /// system (the user deleted them outside the app, or a delete was cut short
  /// after Android had accepted it). Returns how many rows went.
  Future<int> dropMissing(List<ShotRow> photos);
}

/// The real [PhotoLibrary]: the share and delete of the system, and the rows
/// of the database.
class SystemPhotoLibrary implements PhotoLibrary {
  const SystemPhotoLibrary({required this.actions, required this.shots});

  final PhotoActions actions;
  final ShotsDao shots;

  @override
  Future<bool> share(String location) => actions.share(location);

  /// The row goes only when the photo is no longer in the gallery of the
  /// system: it was deleted now, or it was not there to begin with (the user
  /// deleted it outside the app, so a missing photo can be cleared too). If
  /// the user refuses the confirmation of the system, or the deletion fails,
  /// nothing changes.
  @override
  Future<PhotoDeletion> delete(int shotId, String location) async {
    final outcome = await actions.delete(location);
    if (outcome == PhotoDeletion.deleted ||
        outcome == PhotoDeletion.deletedKeptOriginal ||
        outcome == PhotoDeletion.gone) {
      await shots.deleteShot(shotId);
    }
    return outcome;
  }

  @override
  Future<int> dropMissing(List<ShotRow> photos) async {
    final byLocation = <String, List<int>>{};
    for (final photo in photos) {
      final location = photo.galleryUri;
      if (location != null) (byLocation[location] ??= []).add(photo.id);
    }
    if (byLocation.isEmpty) return 0;
    final gone = await actions.missing(byLocation.keys);
    var dropped = 0;
    for (final location in gone) {
      for (final id in byLocation[location] ?? const <int>[]) {
        // Only if the row still holds the place that was checked: the lookup
        // may have taken a while, and a retry may have moved the photo.
        if (await shots.deleteShotIfGalleryUri(id, location)) dropped++;
      }
    }
    return dropped;
  }
}

/// The share and delete actions of the gallery.
final photoLibraryProvider = Provider<PhotoLibrary>(
  (ref) => SystemPhotoLibrary(
    actions: ref.watch(photoActionsProvider),
    shots: ref.watch(shotsDaoProvider),
  ),
);
