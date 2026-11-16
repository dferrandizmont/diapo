import 'package:flutter/widgets.dart';

import '../theme/carrete_tokens.dart';

/// Paints a raised or sunken plastic part: the hard and the diffuse shadow, a
/// vertical gradient and the 1 px light edge on top (raised), or a dark
/// gradient with an inner shadow (sunken, when the part is pressed).
class PlasticSurfacePainter extends CustomPainter {
  const PlasticSurfacePainter({
    required this.radius,
    this.pressed = false,
    this.top = CarreteColors.keyTop,
    this.bottom = CarreteColors.keyBottom,
    this.pressedTop = CarreteColors.keyPressedTop,
    this.pressedBottom = CarreteColors.keyPressedBottom,
    this.shadows = true,
    this.hardShadow = CarreteRelief.hard,
    this.diffuseShadow = CarreteRelief.diffuse,
    this.highlight = CarreteRelief.highlight,
    this.pressedEdge = CarreteRelief.pressedEdge,
    this.innerShadow = CarreteRelief.innerShadow,
  });

  /// The corner radius.
  final double radius;

  /// Whether the part is sunken.
  final bool pressed;

  /// Colours of the raised gradient.
  final Color top;
  final Color bottom;

  /// Colours of the sunken gradient.
  final Color pressedTop;
  final Color pressedBottom;

  /// Whether to draw the shadows under the part.
  final bool shadows;

  /// The hard shadow under the part, or null for none.
  final BoxShadow? hardShadow;

  /// The diffuse shadow under the part, or null for none.
  final BoxShadow? diffuseShadow;

  /// The 1 px light edge on top of the part.
  final Color highlight;

  /// The light that catches the lower edge of the part when it is sunken.
  final Color pressedEdge;

  /// The inner shadow of the part when it is sunken.
  final Color innerShadow;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    if (pressed) {
      // The light that catches the lower edge of the hole.
      canvas.drawRRect(
        rrect.shift(const Offset(0, CarreteRelief.edgeWidth)),
        Paint()..color = pressedEdge,
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [pressedTop, pressedBottom],
          ).createShader(rect),
      );
      // The inner shadow: everything outside the part, shifted down, blurred
      // and clipped to the part.
      canvas.save();
      canvas.clipRRect(rrect);
      final outside = Path.combine(
        PathOperation.difference,
        Path()..addRect(rect.inflate(CarreteRelief.innerBleed)),
        Path()
          ..addRRect(rrect.shift(const Offset(0, CarreteRelief.innerOffset))),
      );
      canvas.drawPath(
        outside,
        Paint()
          ..color = innerShadow
          ..maskFilter = const MaskFilter.blur(
            BlurStyle.normal,
            CarreteRelief.innerBlur,
          ),
      );
      canvas.restore();
      return;
    }

    final diffuse = diffuseShadow;
    final hard = hardShadow;
    if (shadows && diffuse != null) {
      canvas.drawRRect(
        rrect.shift(diffuse.offset),
        Paint()
          ..color = diffuse.color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, diffuse.blurSigma),
      );
    }
    if (shadows && hard != null) {
      canvas.drawRRect(rrect.shift(hard.offset), Paint()..color = hard.color);
    }
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(rect),
    );
    // The light edge on top.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, CarreteRelief.edgeStrip));
    canvas.drawRRect(
      rrect.deflate(CarreteRelief.edgeWidth / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = CarreteRelief.edgeWidth
        ..color = highlight,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(PlasticSurfacePainter old) =>
      old.radius != radius ||
      old.pressed != pressed ||
      old.top != top ||
      old.bottom != bottom ||
      old.pressedTop != pressedTop ||
      old.pressedBottom != pressedBottom ||
      old.hardShadow != hardShadow ||
      old.diffuseShadow != diffuseShadow ||
      old.highlight != highlight ||
      old.pressedEdge != pressedEdge ||
      old.innerShadow != innerShadow ||
      old.shadows != shadows;
}
