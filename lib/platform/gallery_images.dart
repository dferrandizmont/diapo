import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/theme/carrete_tokens.dart';

/// Reads the developed photos of a roll back from the gallery of the system.
///
/// `ShotRow.galleryUri` is a `content://` URI on Android 10+ and a file path
/// on Android 8-9, so `Image.file` cannot read it: the pixels come from the
/// native side (channel `carrete/media`), which serves only the photos of the
/// app's own album and needs no permission.
abstract interface class GalleryImages {
  /// A small JPEG of the photo at [location], or null when it is not there
  /// any more (the user deleted it) or cannot be read.
  Future<Uint8List?> thumbnail(String location);

  /// The whole JPEG of the photo at [location], or null as in [thumbnail].
  Future<Uint8List?> full(String location);
}

/// [GalleryImages] on the native channel. Thumbnails are kept in memory only
/// (the most recent [CarreteRoll.thumbnailCache]); nothing is written to disk.
class NativeGalleryImages implements GalleryImages {
  NativeGalleryImages({
    MethodChannel? channel,
    this.cacheSize = CarreteRoll.thumbnailCache,
    this.extent = CarreteRoll.thumbnailExtent,
  }) : _channel = channel ?? const MethodChannel('carrete/media');

  final MethodChannel _channel;

  /// The most thumbnails kept.
  final int cacheSize;

  /// The side of the thumbnails, in pixels.
  final int extent;

  final LinkedHashMap<String, Uint8List> _cache =
      LinkedHashMap<String, Uint8List>();
  final Map<String, Future<Uint8List?>> _loading =
      <String, Future<Uint8List?>>{};
  final Set<String> _missing = <String>{};

  @override
  Future<Uint8List?> thumbnail(String location) {
    if (_missing.contains(location)) return SynchronousFuture(null);
    final cached = _cache.remove(location);
    if (cached != null) {
      // Most recently used goes last.
      _cache[location] = cached;
      return SynchronousFuture<Uint8List?>(cached);
    }
    return _loading[location] ??= _load(location);
  }

  Future<Uint8List?> _load(String location) async {
    try {
      final bytes = await _read('loadThumbnail', {
        'uri': location,
        'extent': extent,
      });
      if (bytes != null) {
        _cache[location] = bytes;
        while (_cache.length > cacheSize) {
          _cache.remove(_cache.keys.first);
        }
      }
      return bytes;
    } finally {
      _loading.remove(location);
    }
  }

  @override
  Future<Uint8List?> full(String location) =>
      _read('readImage', {'uri': location});

  Future<Uint8List?> _read(
    String method,
    Map<String, Object?> arguments,
  ) async {
    final location = arguments['uri']! as String;
    if (_missing.contains(location)) return null;
    try {
      return await _channel.invokeMethod<Uint8List>(method, arguments);
    } on PlatformException catch (error) {
      // A missing or temporarily unreadable photo is remembered until the
      // screen is reopened or the app resumes.
      if (error.code == 'not_found') {
        _missing.add(location);
        while (_missing.length > cacheSize) {
          _missing.remove(_missing.first);
        }
        _cache.remove(location);
      }
      if (kDebugMode && error.code != 'not_found') {
        debugPrint('Reading $method failed: ${error.code} ${error.message}');
      }
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}

/// The photos of the gallery. Overridden in the tests.
final galleryImagesProvider = Provider<GalleryImages>((ref) {
  final lifecycle = AppLifecycleListener(onResume: ref.invalidateSelf);
  ref.onDispose(lifecycle.dispose);
  return NativeGalleryImages();
});
