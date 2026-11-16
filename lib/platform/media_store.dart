import 'dart:convert';
import 'dart:typed_data' show Endian;

import 'package:flutter/services.dart';

import '../location/photo_location.dart';
import 'exif_dates.dart';

/// Native JPEG encoding and gallery saving (Android: Bitmap + MediaStore,
/// album "Pictures/Diapo", the optional untouched originals in its
/// subfolder "Originales"; iOS: pending, see .handoff.md).
///
/// Large stills use [beginTiledSave] and acknowledged [saveTile] messages.
/// Bounded small stills and the benchmark use two messages, in order: metadata on the method channel
/// (`beginSave`, answered with a token) and then the pixels alone on a binary
/// channel. The pixels travel as a direct buffer: the standard codec would
/// turn them into a Java-heap `byte[]` (200 MB for a 50 MP still) and kill
/// the process. The reply of the second message is a UTF-8 JSON object with
/// `ok`, the timings and the `uri`, or `ok: false` and an `error`.
class MediaStore {
  static const _channel = MethodChannel('carrete/media');
  static const _pixels = BasicMessageChannel<ByteData?>(
    'carrete/media/pixels',
    BinaryCodec(),
  );

  /// Bounded tile transport. One native bitmap is allocated for the print;
  /// each acknowledged message replaces a small rectangle in that bitmap.
  static const _tiles = BasicMessageChannel<ByteData?>(
    'carrete/media/tiles',
    BinaryCodec(),
  );

  static Future<int> beginTiledSave({
    required int width,
    required int height,
    required int tileSize,
    required String displayName,
    String? sourcePath,
    bool includeLocation = false,
    PhotoLocation? location,
    DateTime? takenAt,
    bool framed = false,
  }) async {
    final token = await _channel.invokeMethod<int>('beginTiledSave', {
      'width': width,
      'height': height,
      'tileSize': tileSize,
      'quality': 95,
      'displayName': displayName,
      'sourcePath': sourcePath,
      'includeLocation': includeLocation,
      if (includeLocation && location != null) 'location': location.toJson(),
      if (takenAt != null) 'takenAt': takenAt.millisecondsSinceEpoch,
      'framed': framed,
    });
    if (token == null) throw StateError('No token for the tiled save');
    return token;
  }

  /// Returns the saved URI on the last tile, otherwise just acknowledges it.
  static Future<Map<String, Object?>> saveTile({
    required int token,
    required int x,
    required int y,
    required int width,
    required int height,
    required Uint8List rgba,
  }) async {
    if (width <= 0 || height <= 0 || rgba.length != width * height * 4) {
      throw ArgumentError('Invalid tile pixels');
    }
    // Five little-endian int32s followed by RGBA. This copy is tile-sized,
    // never frame-sized (4 MiB with the production tile side of 1024).
    final message = ByteData(20 + rgba.length);
    final fields = [token, x, y, width, height];
    for (var i = 0; i < fields.length; i++) {
      message.setInt32(i * 4, fields[i], Endian.little);
    }
    message.buffer.asUint8List().setRange(20, message.lengthInBytes, rgba);
    return _pixelReply(await _tiles.send(message));
  }

  /// Releases an incomplete native bitmap after a render/transport failure.
  static Future<void> cancelTiledSave(int token) =>
      _channel.invokeMethod<void>('cancelTiledSave', {'token': token});

  static Map<String, Object?> _pixelReply(ByteData? reply) {
    if (reply == null) {
      throw PlatformException(code: 'save_failed', message: 'No pixel reply');
    }
    final decoded = jsonDecode(utf8.decode(Uint8List.sublistView(reply)));
    final result = decoded is Map
        ? Map<String, Object?>.from(decoded)
        : <String, Object?>{};
    if (result.remove('ok') != true) {
      throw PlatformException(
        code: 'save_failed',
        message: result['error']?.toString() ?? 'unknown error',
      );
    }
    return result;
  }

  /// Finds a completed export owned by this app, removing interrupted pending
  /// rows before a retry. [displayName] excludes the JPEG extension.
  static Future<String?> findSaved(String displayName) =>
      _channel.invokeMethod<String>('findSaved', {'displayName': displayName});

  /// Finds a completed original saved by [saveOriginal] under [displayName]
  /// (with its `_original` suffix, no extension). Only the subfolder of the
  /// originals is searched; the developed photos are not matched.
  static Future<String?> findSavedOriginal(String displayName) =>
      _channel.invokeMethod<String>('findSaved', {
        'displayName': displayName,
        'original': true,
      });

  /// Saves the untouched camera JPEG at [sourcePath] (a file in the cache of
  /// the app) in the subfolder `Pictures/Diapo/Originales`, as
  /// [displayName] (no extension; it must end in `_original`). The bytes are
  /// copied as they are, with their EXIF, except the GPS tags: those stay only
  /// with [includeLocation]. Saving a name that is already there answers the
  /// existing item instead of writing a second one. Returns its location.
  static Future<String> saveOriginal({
    required String sourcePath,
    required String displayName,
    bool includeLocation = false,
    PhotoLocation? location,
    DateTime? takenAt,
  }) async {
    final uri = await _channel.invokeMethod<String>('saveOriginal', {
      'sourcePath': sourcePath,
      'displayName': displayName,
      'includeLocation': includeLocation,
      if (includeLocation && location != null) 'location': location.toJson(),
      if (takenAt != null) 'takenAt': takenAt.millisecondsSinceEpoch,
    });
    if (uri == null) {
      throw PlatformException(
        code: 'save_failed',
        message: 'The native side gave no place for the original.',
      );
    }
    return uri;
  }

  /// The capture dates of the photo at [path], a file in the cache of the
  /// app. Never throws: a file that cannot be read, or a platform without
  /// the native side, answers no dates.
  static Future<ExifDates> readExifDates(String path) async {
    try {
      final answer = await _channel.invokeMapMethod<String, String?>(
        'readExifDates',
        {'path': path},
      );
      return ExifDates(
        original: answer?['original'],
        originalOffset: answer?['originalOffset'],
        digitized: answer?['digitized'],
        digitizedOffset: answer?['digitizedOffset'],
      );
    } on PlatformException {
      return const ExifDates();
    } on MissingPluginException {
      return const ExifDates();
    }
  }

  /// Encodes premultiplied RGBA pixels as JPEG, copies the camera EXIF of
  /// [sourcePath] (orientation reset to normal, since pixels are already
  /// upright) and adds the file to the gallery. Returns native timings and
  /// the saved URI.
  ///
  /// The GPS tags of the source are copied only with [includeLocation]; by
  /// default they are stripped, whatever the source carries.
  static Future<Map<String, Object?>> saveRgbaAsJpeg({
    required Uint8List rgba,
    required int width,
    required int height,
    required String displayName,
    String? sourcePath,
    int quality = 95,
    bool includeLocation = false,
    PhotoLocation? location,
    DateTime? takenAt,
  }) async {
    if (rgba.lengthInBytes != width * height * 4) {
      throw ArgumentError(
        'rgba has ${rgba.lengthInBytes} bytes for $width x $height',
      );
    }
    final token = await _channel.invokeMethod<int>('beginSave', {
      'width': width,
      'height': height,
      'quality': quality,
      'displayName': displayName,
      'sourcePath': sourcePath,
      'includeLocation': includeLocation,
      if (includeLocation && location != null) 'location': location.toJson(),
      if (takenAt != null) 'takenAt': takenAt.millisecondsSinceEpoch,
    });
    if (token == null) {
      throw PlatformException(
        code: 'save_failed',
        message: 'The native side gave no token for the save.',
      );
    }
    // A view, not a copy: the pixels are read straight from the Dart buffer.
    final reply = await _pixels.send(ByteData.sublistView(rgba));
    if (reply == null) {
      throw PlatformException(
        code: 'save_failed',
        message: 'The native side gave no reply for the pixels.',
      );
    }
    final decoded = jsonDecode(utf8.decode(Uint8List.sublistView(reply)));
    final result = decoded is Map
        ? Map<String, Object?>.from(decoded)
        : const <String, Object?>{};
    if (result['ok'] != true) {
      throw PlatformException(
        code: 'save_failed',
        message: result['error']?.toString() ?? 'unknown error',
      );
    }
    result.remove('ok');
    return result;
  }
}
