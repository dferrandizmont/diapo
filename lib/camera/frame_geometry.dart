import 'dart:math' as math;
import 'dart:ui';

import 'package:film_recipes/film_recipes.dart';

/// Geometry of the frame formats.
///
/// The app is portrait only, so the frames are 2:3, 3:4, 1:1 and 9:16 (width
/// to height). A still that comes out of the sensor in landscape gets the
/// landscape version of the frame.
extension FrameFormatGeometry on FrameFormat {
  /// Width divided by height of the frame, in portrait.
  double get portraitAspect => switch (this) {
    FrameFormat.r3x2 => 2 / 3,
    FrameFormat.r4x3 => 3 / 4,
    FrameFormat.r1x1 => 1,
    FrameFormat.r16x9 => 9 / 16,
  };

  /// Whether this format supports cinema bands.
  bool get supportsCinemaBands => this == FrameFormat.r16x9;

  /// The label of the format on the keys: `3:2`, `4:3`, `1:1` or `16:9`.
  String get label => wireName;

  /// The next format when the format key is pressed.
  FrameFormat get next {
    const order = FrameFormat.values;
    return order[(order.indexOf(this) + 1) % order.length];
  }
}

/// How much two aspect ratios may differ before the field of view of the
/// preview is considered different from the one of the still.
const double kFieldAspectTolerance = 0.02;

/// The rectangle of a still of [source] size that the saved photo keeps.
///
/// The photo is a centred crop of the still to the [format]. When the preview
/// has another aspect ratio than the still ([fieldAspect], width divided by
/// height in portrait), the still is first cropped to the field of view of
/// the preview, so that the saved photo shows what the viewfinder showed.
///
/// The rectangle has whole pixel coordinates.
Rect frameCrop(FrameFormat format, Size source, {double? fieldAspect}) {
  final landscape = source.width > source.height;
  var area = Offset.zero & source;

  if (fieldAspect != null && fieldAspect > 0) {
    final wanted = landscape ? 1 / fieldAspect : fieldAspect;
    final have = source.width / source.height;
    if ((have - wanted).abs() / wanted > kFieldAspectTolerance) {
      area = _centreCrop(area, wanted);
    }
  }

  final ratio = landscape && format != FrameFormat.r1x1
      ? 1 / format.portraitAspect
      : format.portraitAspect;
  return _centreCrop(area, ratio);
}

/// The biggest centred rectangle of [area] with the given width / height
/// [ratio], on whole pixels.
Rect _centreCrop(Rect area, double ratio) {
  double w = area.width;
  double h = area.height;
  if (w / h > ratio) {
    w = h * ratio;
  } else {
    h = w / ratio;
  }
  final cw = math.min(area.width, w.roundToDouble());
  final ch = math.min(area.height, h.roundToDouble());
  final left = area.left + ((area.width - cw) / 2).floorToDouble();
  final top = area.top + ((area.height - ch) / 2).floorToDouble();
  return Rect.fromLTWH(left, top, cw, ch);
}

/// Where a frame of width / height [aspect] sits on a screen of [screen]
/// size, in the band between the bottom of the top bar ([topReserved] from the
/// top of the screen) and the top of the carousel ([bottomReserved] from the
/// bottom).
///
/// The whole frame is always inside the band: it is as wide as the screen
/// when the band is tall enough and otherwise it is scaled down until its
/// height is the height of the band, with black on both sides. It is centred
/// horizontally and vertically in the band. When the band has no height the
/// frame is empty.
Rect placeFrame({
  required Size screen,
  required double aspect,
  required double topReserved,
  required double bottomReserved,
}) {
  final band = math.max(0.0, screen.height - topReserved - bottomReserved);
  final width = math.min(screen.width, band * aspect);
  final height = width / aspect;
  return Rect.fromLTWH(
    (screen.width - width) / 2,
    topReserved + (band - height) / 2,
    width,
    height,
  );
}

/// Converts a point of the frame (0..1 in both axes) to a point of the
/// preview (0..1), knowing that the preview fills the frame with a centred
/// crop ("cover").
///
/// [preview] is the size of the preview in portrait, [frame] the size of the
/// frame on screen.
Offset framePointToPreview(Offset point, Size frame, Size preview) {
  final frameAspect = frame.width / frame.height;
  final previewAspect = preview.width / preview.height;
  var x = point.dx;
  var y = point.dy;
  if (previewAspect > frameAspect) {
    // The preview is wider: the sides are cropped.
    final visible = frameAspect / previewAspect;
    x = (1 - visible) / 2 + x * visible;
  } else {
    // The preview is taller: the top and bottom are cropped.
    final visible = previewAspect / frameAspect;
    y = (1 - visible) / 2 + y * visible;
  }
  return Offset(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));
}
