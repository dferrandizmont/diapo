import 'dart:ui';

/// The white border of an instant photo: thin on the top and the sides, thick
/// at the bottom, like the print of an instant camera.
///
/// The proportions are fractions of the side of the (square) photo, so the
/// frame looks the same at any resolution.
abstract final class WhiteFrame {
  /// The border on the left, the right and the top.
  static const double sideFraction = 0.06;

  /// The border at the bottom.
  static const double bottomFraction = 0.2;

  /// The size of the print for a photo of [photo] size.
  static Size outerSize(Size photo) {
    final side = photo.shortestSide;
    return Size(
      photo.width + 2 * (side * sideFraction).roundToDouble(),
      photo.height +
          (side * sideFraction).roundToDouble() +
          (side * bottomFraction).roundToDouble(),
    );
  }

  /// Where the photo sits inside the print.
  static Rect photoRect(Size photo) {
    final side = photo.shortestSide;
    final edge = (side * sideFraction).roundToDouble();
    return Rect.fromLTWH(edge, edge, photo.width, photo.height);
  }
}
