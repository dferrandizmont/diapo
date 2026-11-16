import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What happened when a photo was deleted from the gallery of the system.
enum PhotoDeletion {
  /// The photo was deleted.
  deleted,

  /// The photo was deleted but its original (saved with "Also save the
  /// original") could not be: it is still in `Pictures/Diapo/Originales`.
  deletedKeptOriginal,

  /// The photo was not there any more (the user deleted it outside the app).
  gone,

  /// The user did not allow the deletion when the system asked.
  cancelled,

  /// The deletion failed.
  failed,
}

/// What can be done with a photo of the app's own album: share it and delete
/// it. The photo is named by its `galleryUri`, as in `GalleryImages`.
abstract interface class PhotoActions {
  /// Opens the share sheet of the system with the photo at [location]. False
  /// when the photo is not there or the sheet could not open.
  Future<bool> share(String location);

  /// Shares a JPEG or PNG in `<cache>/contact-sheets/` with a temporary read
  /// grant. False when unavailable or rejected by the native side.
  Future<bool> shareFile(String path);

  /// Deletes the photo at [location] from the gallery of the system.
  Future<PhotoDeletion> delete(String location);

  /// Which of [locations] are certainly not in the gallery of the system any
  /// more. A photo that cannot be checked is not listed.
  Future<Set<String>> missing(Iterable<String> locations);
}

/// [PhotoActions] on the native channel `carrete/media`.
///
/// Sharing hands the system the same `content://` item the gallery holds; no
/// copy of the photo is made and nothing goes to a server. Deleting an item
/// the app no longer owns (for example after a reinstall) makes Android show
/// its own confirmation; the call answers when the user has chosen.
class NativePhotoActions implements PhotoActions {
  NativePhotoActions({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('carrete/media');

  final MethodChannel _channel;

  @override
  Future<bool> share(String location) async {
    try {
      final shared = await _channel.invokeMethod<bool>('shareImage', {
        'uri': location,
      });
      return shared ?? false;
    } on PlatformException catch (error) {
      if (kDebugMode) debugPrint('Sharing failed: ${error.code}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> shareFile(String path) async {
    try {
      return await _channel.invokeMethod<bool>('shareFile', {'path': path}) ??
          false;
    } on PlatformException catch (error) {
      if (kDebugMode) debugPrint('Sharing failed: ${error.code}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<PhotoDeletion> delete(String location) async {
    try {
      final answer = await _channel.invokeMethod<String>('deleteImage', {
        'uri': location,
      });
      return switch (answer) {
        'deleted' => PhotoDeletion.deleted,
        'deletedPhotoKeptOriginal' => PhotoDeletion.deletedKeptOriginal,
        'gone' => PhotoDeletion.gone,
        'cancelled' => PhotoDeletion.cancelled,
        _ => PhotoDeletion.failed,
      };
    } on PlatformException catch (error) {
      if (error.code == 'not_found') return PhotoDeletion.gone;
      if (kDebugMode) debugPrint('Deleting failed: ${error.code}');
      return PhotoDeletion.failed;
    } on MissingPluginException {
      return PhotoDeletion.failed;
    }
  }

  @override
  Future<Set<String>> missing(Iterable<String> locations) async {
    final asked = locations.toList();
    if (asked.isEmpty) return const <String>{};
    try {
      final answer = await _channel.invokeListMethod<String>('missingImages', {
        'uris': asked,
      });
      return {...?answer};
    } on PlatformException catch (error) {
      if (kDebugMode) debugPrint('Looking for missing photos: ${error.code}');
      return const <String>{};
    } on MissingPluginException {
      return const <String>{};
    }
  }
}

/// Share and delete. Overridden in the tests.
final photoActionsProvider = Provider<PhotoActions>(
  (ref) => NativePhotoActions(),
);
