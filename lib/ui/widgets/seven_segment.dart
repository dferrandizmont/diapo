import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/carrete_tokens.dart';

/// Seven-segment digits drawn with paths: no font, so the LCD counter and the
/// date imprint look the same on every device and at every size.
///
/// The geometry follows the token sheet of proposal A (see [CarreteSegment]).
abstract final class SevenSegment {
  static const Map<String, String> _segments = <String, String>{
    '0': 'abcdef',
    '1': 'bc',
    '2': 'abdeg',
    '3': 'abcdg',
    '4': 'bcfg',
    '5': 'acdfg',
    '6': 'acdefg',
    '7': 'abc',
    '8': 'abcdefg',
    '9': 'abcdfg',
    '-': 'g',
  };

  static final double _lean = math.tan(
    CarreteSegment.leanDegrees * math.pi / 180,
  );

  /// The width of one digit, for a digit [height].
  static double digitWidth(double height) => height * CarreteSegment.digitWidth;

  /// The width of the strokes, for a digit [height].
  static double strokeWidth(double height) => height * CarreteSegment.stroke;

  /// The size [text] takes when drawn with digits [height] tall.
  static Size measure(String text, double height) {
    final w = digitWidth(height);
    final sk = _lean * height;
    var x = sk * 0.5;
    for (final ch in text.split('')) {
      if (ch == ' ') {
        x += w * CarreteSegment.space;
      } else if (ch == "'") {
        x += w * CarreteSegment.apostrophe;
      } else {
        x += w + height * CarreteSegment.gap;
      }
    }
    return Size(x + sk * 0.5, height);
  }

  /// Draws [text] with its top left corner at [origin].
  ///
  /// With [ghost] the segments that are off are drawn very faintly, like on a
  /// real LCD. With [glow] the lit segments get a soft halo of the same colour.
  static void paint(
    Canvas canvas,
    String text,
    Offset origin,
    double height,
    Color color, {
    bool ghost = false,
    bool glow = false,
  }) {
    final w = digitWidth(height);
    final sw = strokeWidth(height);
    final p = sw * CarreteSegment.cornerGap;
    final l = sw * CarreteSegment.edgeInset;
    final r = w - sw * CarreteSegment.edgeInset;
    final t = sw * CarreteSegment.edgeInset;
    final b = height - sw * CarreteSegment.edgeInset;
    final m = height / 2;
    final sk = _lean * height;

    final lit = Path();
    final dim = Path();
    var x = sk * 0.5;

    void line(Path path, double x1, double y1, double x2, double y2) {
      path
        ..moveTo(x1, y1)
        ..lineTo(x2, y2);
    }

    for (final ch in text.split('')) {
      if (ch == ' ') {
        x += w * CarreteSegment.space;
        continue;
      }
      if (ch == "'") {
        line(
          lit,
          x + w * CarreteSegment.apostropheTop,
          t,
          x + w * CarreteSegment.apostropheFoot,
          t + height * CarreteSegment.apostropheDrop,
        );
        x += w * CarreteSegment.apostrophe;
        continue;
      }
      final on = _segments[ch] ?? '';
      void seg(String name, double x1, double y1, double x2, double y2) {
        line(on.contains(name) ? lit : dim, x1, y1, x2, y2);
      }

      seg('a', x + l + p, t, x + r - p, t);
      seg('b', x + r, t + p, x + r, m - p);
      seg('c', x + r, m + p, x + r, b - p);
      seg('d', x + l + p, b, x + r - p, b);
      seg('e', x + l, m + p, x + l, b - p);
      seg('f', x + l, t + p, x + l, m - p);
      seg('g', x + l + p, m, x + r - p, m);
      x += w + height * CarreteSegment.gap;
    }

    // Skew: the top leans right by `sk`, the bottom stays put.
    final skew = Matrix4.identity()
      ..setEntry(0, 1, -_lean)
      ..setEntry(0, 3, sk);

    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.transform(skew.storage);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = sw;
    if (ghost) {
      canvas.drawPath(
        dim,
        stroke..color = color.withValues(alpha: CarreteSegment.ghostAlpha),
      );
    }
    if (glow) {
      canvas.drawPath(
        lit,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = sw * CarreteSegment.glowStroke
          ..color = color.withValues(alpha: CarreteSegment.glowAlpha)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            height * CarreteSegment.glowBlur,
          ),
      );
    }
    canvas.drawPath(lit, stroke..color = color);
    canvas.restore();
  }
}

/// Paints [text] in seven-segment digits.
class SevenSegmentText extends StatelessWidget {
  const SevenSegmentText({
    required this.text,
    required this.height,
    required this.color,
    this.ghost = false,
    this.glow = false,
    super.key,
  });

  /// The digits to draw.
  final String text;

  /// The height of the digits.
  final double height;

  /// The colour of the lit segments.
  final Color color;

  /// Whether the segments that are off show faintly.
  final bool ghost;

  /// Whether the lit segments glow.
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: SevenSegment.measure(text, height),
      painter: _SevenSegmentPainter(text, height, color, ghost, glow),
    );
  }
}

class _SevenSegmentPainter extends CustomPainter {
  const _SevenSegmentPainter(
    this.text,
    this.height,
    this.color,
    this.ghost,
    this.glow,
  );

  final String text;
  final double height;
  final Color color;
  final bool ghost;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) => SevenSegment.paint(
    canvas,
    text,
    Offset.zero,
    height,
    color,
    ghost: ghost,
    glow: glow,
  );

  @override
  bool shouldRepaint(_SevenSegmentPainter old) =>
      old.text != text ||
      old.height != height ||
      old.color != color ||
      old.ghost != ghost ||
      old.glow != glow;
}
