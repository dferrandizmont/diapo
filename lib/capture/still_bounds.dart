import 'dart:math' as math;

/// Decode limits shared by single-pass and tiled rendering. Large stills use
/// bounded output tiles to avoid full-frame GPU targets and Dart readback.
abstract final class StillBounds {
  /// Keeps 8160 x 6120 (50 MP) camera originals without scaling. Larger imports
  /// are decoded down to this guard before any render target is allocated.
  static const int maxPixels = 50000000;

  /// The longest side a still keeps. 8192 is the smallest maximum texture
  /// size of the GPUs the app runs on; it cannot be queried from Dart.
  static const int maxSide = 8192;

  /// The previous full-frame working-set budget. Check both the decoded
  /// texture and the final print, since a crop can hide a large source and
  /// a white border can enlarge an otherwise small photo.
  static const int singlePassMaxPixels = 24000000;

  static bool fitsSinglePass(
    int sourceWidth,
    int sourceHeight,
    int outputWidth,
    int outputHeight,
  ) =>
      fits(sourceWidth, sourceHeight, maxPixels: singlePassMaxPixels) &&
      fits(outputWidth, outputHeight, maxPixels: singlePassMaxPixels);

  /// The biggest file that is read whole into memory to be developed. A
  /// camera original is 5 to 30 MB; a file above this is not a photo the app
  /// should open.
  static const int maxFileBytes = 100 * 1024 * 1024;

  /// The most pixels a photo may have to be opened at all (200 MP). Above
  /// [maxPixels] a photo is scaled down; above this it is refused before it is
  /// decoded, since even a bounded decode of it costs too much.
  static const int maxSourcePixels = 200000000;

  /// The same limit for formats other than JPEG (PNG, WebP...), whose decoder
  /// needs the whole image in memory at once: 100 MP.
  static const int maxOtherSourcePixels = 100000000;

  /// Whether [bytes] start like a JPEG file.
  static bool isJpeg(List<int> bytes) =>
      bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;

  /// The most pixels a photo may declare to be opened, by its format.
  static int sourcePixelLimit({required bool jpeg}) =>
      jpeg ? maxSourcePixels : maxOtherSourcePixels;

  /// The factor (0 < f <= 1) that brings [width] x [height] inside the bounds.
  /// 1 when it already is.
  static double scaleFor(
    int width,
    int height, {
    int maxPixels = StillBounds.maxPixels,
    int maxSide = StillBounds.maxSide,
  }) {
    if (width <= 0 || height <= 0) return 1;
    final pixels = width * height;
    final byArea = pixels > maxPixels ? math.sqrt(maxPixels / pixels) : 1.0;
    final long = math.max(width, height);
    final bySide = long > maxSide ? maxSide / long : 1.0;
    return math.min(byArea, bySide);
  }

  /// [width] x [height] brought inside the bounds, or unchanged when it fits.
  /// Never smaller than one pixel on a side.
  static (int, int) bounded(
    int width,
    int height, {
    int maxPixels = StillBounds.maxPixels,
    int maxSide = StillBounds.maxSide,
  }) {
    final f = scaleFor(width, height, maxPixels: maxPixels, maxSide: maxSide);
    if (f >= 1) return (width, height);
    return (
      math.max(1, (width * f).floor()),
      math.max(1, (height * f).floor()),
    );
  }

  /// Whether [width] x [height] fits inside the bounds.
  static bool fits(
    int width,
    int height, {
    int maxPixels = StillBounds.maxPixels,
    int maxSide = StillBounds.maxSide,
  }) => scaleFor(width, height, maxPixels: maxPixels, maxSide: maxSide) >= 1;
}
