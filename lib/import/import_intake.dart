import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../capture/still_bounds.dart';
import '../platform/exif_dates.dart';

/// The most photos that can be developed in one go. The photos wait on disk
/// (about 5 to 25 MB each) while the person chooses the film; this keeps that
/// and the time of the export bounded.
const int kImportLimit = 30;

/// Asks the person for photos of their gallery.
///
/// The real one opens the Photo Picker of the system, which hands over only
/// the photos the person chooses: the app asks for no permission to read the
/// gallery.
abstract interface class ImportPicker {
  /// The files of the chosen photos, copies in the cache of the app; empty
  /// when the person chose none. At most [limit].
  Future<List<String>> pick({required int limit});

  /// Throws away the result of a pick the app never received (it was killed
  /// while the picker was open). The files of it are deleted.
  Future<void> discardLost();
}

/// [ImportPicker] on the `image_picker` plugin, which uses the Photo Picker
/// of Android (or the system file picker on versions without it).
class ImagePickerImportPicker implements ImportPicker {
  ImagePickerImportPicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<List<String>> pick({required int limit}) async {
    // No size or quality: the plugin copies the original bytes, which keeps
    // the EXIF and the resolution for the export.
    final files = await _picker.pickMultiImage(limit: limit);
    return [for (final file in files.take(limit)) file.path];
  }

  @override
  Future<void> discardLost() async {
    try {
      final lost = await _picker.retrieveLostData();
      for (final file in lost.files ?? const <XFile>[]) {
        try {
          await File(file.path).delete();
        } on FileSystemException {
          // Already gone.
        }
      }
    } on Object catch (error) {
      // Only Android has lost data; elsewhere there is nothing to retrieve.
      if (kDebugMode) debugPrint('No lost picker data: $error');
    }
  }
}

/// A photo chosen to be developed.
@immutable
class ImportPhoto {
  const ImportPhoto({required this.path, this.date});

  /// The copy of the photo in the staging folder of the app.
  final String path;

  /// When the photo was taken (see [photoDateOf]); null when it carries no
  /// date, and then no date is printed on it.
  final PhotoDate? date;

  @override
  bool operator ==(Object other) =>
      other is ImportPhoto && other.path == path && other.date == date;

  @override
  int get hashCode => Object.hash(path, date);
}

/// The photos the person chose.
@immutable
class ImportBatch {
  const ImportBatch(this.photos, {this.truncated = false, this.rejected = 0});

  /// The photos, in the order they were chosen.
  final List<ImportPhoto> photos;

  /// Whether the person chose more than [kImportLimit] and the last were left
  /// out.
  final bool truncated;

  /// How many photos were left out for being too big to open (see
  /// [StillBounds.maxFileBytes] and [StillBounds.maxSourcePixels]).
  final int rejected;
}

/// The folder where the chosen photos wait: `<cache>/import/`, one folder per
/// batch, so two batches never share a path (and so never a cached picture).
/// Everything in it is the app's own temporary copy, never the originals of
/// the person.
class ImportStaging {
  ImportStaging(this.directory, {required this.cacheDirectory});

  /// The staging folder.
  final Directory directory;

  /// The cache of the app, which holds the folders the picker writes to.
  final Directory cacheDirectory;

  /// The name of a folder of the picker plugin: a random (version 4) UUID.
  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  /// What the plugin copies: one photo, rarely more. A folder with more
  /// files, or with anything else, is not the plugin's.
  static const int _pickerFolderMaxFiles = 5;

  /// The extensions of the files the plugin copies (the name is the one the
  /// photo has in the gallery of the person).
  static const Set<String> _pickerExtensions = {
    'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif', 'gif', 'bmp', 'avif', //
    'dng', 'mp4', 'mov', '3gp', 'webm', 'mkv',
  };

  /// Creates the folder of a new batch.
  Future<Directory> newBatchDirectory([Random? random]) async {
    final source = random ?? Random.secure();
    final name =
        'b${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
        '${source.nextInt(1 << 20).toRadixString(36)}';
    return Directory('${directory.path}/$name').create(recursive: true);
  }

  /// Removes every photo of the staging folder.
  Future<void> clear() async {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } on FileSystemException catch (error) {
      if (kDebugMode) debugPrint('Could not clear the staging folder: $error');
    }
  }

  /// Removes one staged photo. A photo that is already gone is not an error.
  Future<void> remove(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone.
    }
  }

  /// Moves the file the picker made into [batch] as number [index].
  Future<File> adopt(String picked, Directory batch, int index) async {
    final dot = picked.lastIndexOf('.');
    final slash = picked.lastIndexOf(RegExp(r'[\\/]'));
    final extension = dot > slash && dot >= 0 ? picked.substring(dot) : '';
    final target = '${batch.path}/photo_$index$extension';
    final source = File(picked);
    try {
      return await source.rename(target);
    } on FileSystemException {
      final copy = await source.copy(target);
      await source.delete();
      return copy;
    }
  }

  /// Deletes the files the picker made, and the folder each one sits in
  /// when that folder is provably the picker's (see [_deletePickerFolder]).
  Future<void> discardPicked(Iterable<String> picked) async {
    for (final path in picked) {
      final file = File(path);
      try {
        await file.delete();
      } on FileSystemException {
        // Moved into the staging folder, or already gone.
      }
      await _deletePickerFolder(file.parent);
    }
  }

  /// Deletes the folders the picker plugin leaves in the cache
  /// (`<cache>/<uuid>/<name>`): a pick whose result the app never took.
  /// Only folders that are provably the plugin's are touched.
  Future<void> sweepPickerFolders() async {
    try {
      if (!await cacheDirectory.exists()) return;
      await for (final entry in cacheDirectory.list(followLinks: false)) {
        if (entry is Directory) await _deletePickerFolder(entry);
      }
    } on FileSystemException catch (error) {
      if (kDebugMode) debugPrint('Could not sweep the picker folders: $error');
    }
  }

  static final RegExp _separators = RegExp(r'[\\/]');

  static bool _same(String a, String b) =>
      a.replaceAll(_separators, '/') == b.replaceAll(_separators, '/');

  /// Deletes [folder] only when it is provably a folder of the picker plugin:
  ///
  /// - a direct child of the cache that is not the staging folder;
  /// - named like a random UUID;
  /// - holding nothing but a few regular files (no links, no subfolders)
  ///   named like images or videos.
  ///
  /// Anything else is left alone, whatever its name. The files are deleted
  /// one by one and then the folder itself, never with a recursive delete.
  Future<void> _deletePickerFolder(Directory folder) async {
    try {
      final name = folder.path.split(RegExp(r'[\\/]')).last;
      if (!_uuid.hasMatch(name)) return;
      if (!await folder.exists()) return;
      if (!await FileSystemEntity.identical(
        folder.parent.path,
        cacheDirectory.path,
      )) {
        return;
      }
      if (_same(folder.path, directory.path)) return;
      final files = <File>[];
      await for (final entry in folder.list(followLinks: false)) {
        if (entry is! File || files.length >= _pickerFolderMaxFiles) return;
        final dot = entry.path.lastIndexOf('.');
        final slash = entry.path.lastIndexOf(RegExp(r'[\\/]'));
        final extension = dot > slash
            ? entry.path.substring(dot + 1).toLowerCase()
            : '';
        if (!_pickerExtensions.contains(extension)) return;
        files.add(entry);
      }
      for (final file in files) {
        await file.delete();
      }
      await folder.delete();
    } on FileSystemException catch (error) {
      if (kDebugMode) debugPrint('Could not delete a picker folder: $error');
    }
  }
}

/// Reads the capture dates of a staged photo. Overridden in the tests.
typedef ExifReader = Future<ExifDates> Function(String path);

/// The width and height of the photo at a path, read from its header without
/// decoding it; null when they cannot be known.
typedef ImageSizeReader = Future<(int, int)?> Function(String path);

/// The size of the image at [path] from its header only.
Future<(int, int)?> readImageSize(String path) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  try {
    buffer = await ui.ImmutableBuffer.fromFilePath(path);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    return (descriptor.width, descriptor.height);
  } on Object {
    return null;
  } finally {
    descriptor?.dispose();
    buffer?.dispose();
  }
}

/// Takes the photos the person chooses from their gallery and prepares them
/// to be developed: copies them into a staging folder, refuses the ones that
/// are too big to open and finds each one's date.
class ImportIntake {
  ImportIntake({
    required this._picker,
    required this._staging,
    required this._readDates,
    this.readSize = readImageSize,
    this.limit = kImportLimit,
  });

  final ImportPicker _picker;
  final ImportStaging _staging;
  final ExifReader _readDates;

  /// Reads the size of a photo before it is decoded.
  final ImageSizeReader readSize;

  /// The most photos taken.
  final int limit;

  /// Opens the picker. Null when the person chose nothing. Leftovers of an
  /// earlier import are removed first.
  ///
  /// Whatever happens, no copy of the picker stays behind: the files it made
  /// and their folders are deleted, and when the batch cannot be delivered
  /// (an error half way) so is everything already staged.
  Future<ImportBatch?> pick() async {
    // A cleanup of the start that is still running must finish first: it
    // would delete the copies of this pick.
    await _cleanup;
    await _staging.clear();
    // One more than the limit, so a longer choice is noticed.
    final picked = await _picker.pick(limit: limit + 1);
    if (picked.isEmpty) return null;
    try {
      final batch = await _staging.newBatchDirectory();
      final photos = <ImportPhoto>[];
      var rejected = 0;
      for (var i = 0; i < picked.length; i++) {
        final file = await _staging.adopt(picked[i], batch, i);
        if (i >= limit) {
          // The ones left out are not kept anywhere.
          await _staging.remove(file.path);
          continue;
        }
        if (!await _canOpen(file)) {
          rejected++;
          await _staging.remove(file.path);
          continue;
        }
        final exif = await _readDates(file.path);
        photos.add(ImportPhoto(path: file.path, date: photoDateOf(exif)));
      }
      return ImportBatch(
        photos,
        truncated: picked.length > limit,
        rejected: rejected,
      );
    } on Object {
      await _staging.clear();
      rethrow;
    } finally {
      await _staging.discardPicked(picked);
    }
  }

  /// Removes what an earlier run left behind: a batch nobody developed, the
  /// copies of a pick the app never took, and what the plugin kept of a pick
  /// cut short. Never throws. It runs once; a second call gives the same
  /// future, and [pick] waits for it.
  Future<void> cleanLeftovers() => _cleanup ??= _clean();

  /// The cleanup of the start, once begun. [pick] waits for it.
  Future<void>? _cleanup;

  Future<void> _clean() async {
    try {
      await _picker.discardLost();
      await _staging.clear();
      await _staging.sweepPickerFolders();
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('Could not clean the import leftovers: $error');
      }
    }
  }

  /// Whether the photo is small enough to be opened: a file under
  /// [StillBounds.maxFileBytes] and an image under the pixel limit of its
  /// format ([StillBounds.sourcePixelLimit]), read from the header.
  Future<bool> _canOpen(File file) async {
    if (await file.length() > StillBounds.maxFileBytes) return false;
    final size = await readSize(file.path);
    if (size == null) return true;
    return size.$1 * size.$2 <=
        StillBounds.sourcePixelLimit(jpeg: await _isJpeg(file));
  }

  Future<bool> _isJpeg(File file) async {
    final reader = await file.open();
    try {
      return StillBounds.isJpeg(await reader.read(2));
    } finally {
      await reader.close();
    }
  }
}
