/// The two app icon candidates of Carrete, drawn with `dart:ui` only.
///
/// Everything is drawn on the 108 dp canvas of an Android adaptive icon (the
/// centre is at 54, 54). The foreground keeps its important shapes inside the
/// 66 dp safe circle; the launcher shows at most the central 72 dp. The same
/// drawing renders the adaptive layers (the whole 108 dp canvas) and the
/// finished icon (the central 72 dp), so the PNGs and the sheet agree.
///
/// No lettering and no maker's marks: shapes and the colours of the camera
/// (see `lib/ui/theme/carrete_tokens.dart`).
library;

import 'dart:math' as math;
import 'dart:ui';

/// The candidates agreed by the product reviewers.
enum IconCandidate {
  /// Cream compact camera with an oversized charcoal lens and a vermilion
  /// shutter dot, on charcoal.
  a,

  /// Charcoal film frame with perforations and an amber exposure glow, on
  /// paper.
  b,
}

/// The layers of an adaptive icon.
enum IconLayer { background, foreground, monochrome }

/// The colours of the icon (all from the camera tokens, see the README).
abstract final class IconColors {
  static const Color charcoal = Color(0xFF232528); // CarreteColors.plastic
  static const Color tileTop = Color(0xFF44474D); // above plasticHigh
  static const Color tileBottom = Color(
    0xFF2A2C30,
  ); // between plastic and plasticHigh
  static const Color glass = Color(0xFF0B0C0D); // CarreteColors.viewfinder
  static const Color lensRing = Color(0xFF3D4045); // keyTop
  static const Color cream = Color(0xFFF4F1E8); // whiteFrame
  static const Color creamShade = Color(0xFFDDD9CC);
  static const Color paper = Color(0xFFF1F0EB); // CarreteColors.paper
  static const Color vermilion = Color(0xFFC93A20); // CarreteColors.shutter
  static const Color vermilionLight = Color(0xFFE5442A);
  static const Color vermilionDark = Color(0xFFAE2D18);
  static const Color amber = Color(0xFFFFB020); // CarreteColors.amber
  static const Color orange = Color(0xFFFF7A1A); // CarreteColors.date
  static const Color hot = Color(0xFFFFF0C8);
}

/// Draws the icons.
abstract final class CarreteIcon {
  /// The side of the adaptive canvas, in dp.
  static const double grid = 108;

  /// The side of the part of the canvas every launcher shows, in dp.
  static const double visible = 72;

  /// The diameter of the safe circle, in dp.
  static const double safe = 66;

  static const double _c = grid / 2;

  /// Paints one adaptive layer over the whole 108 dp canvas on a square of
  /// [size] pixels.
  static void paintLayer(
    Canvas canvas,
    double size,
    IconCandidate candidate,
    IconLayer layer,
  ) {
    canvas.save();
    canvas.scale(size / CarreteIcon.grid);
    switch (layer) {
      case IconLayer.background:
        _background(canvas, candidate);
      case IconLayer.foreground:
        _foreground(canvas, candidate);
      case IconLayer.monochrome:
        _monochrome(canvas, candidate);
    }
    canvas.restore();
  }

  /// Paints the finished icon (background and foreground) so that the central
  /// [visibleDp] of the adaptive canvas fills [size] pixels. The caller clips
  /// it to the shape it wants.
  static void paintComposite(
    Canvas canvas,
    double size,
    IconCandidate candidate, {
    double visibleDp = visible,
  }) {
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size, size));
    canvas.translate(size / 2, size / 2);
    canvas.scale(size / visibleDp);
    canvas.translate(-_c, -_c);
    _background(canvas, candidate);
    _foreground(canvas, candidate);
    canvas.restore();
  }

  // ---------------------------------------------------------------- shared

  static const Rect _all = Rect.fromLTWH(0, 0, grid, grid);

  /// The body of the camera and the film frame share one silhouette: 58 x 42
  /// dp, inside the safe circle.
  static const RRect _bodyA = RRect.fromLTRBXY(25, 33, 83, 75, 9, 9);
  static const RRect _frameB = RRect.fromLTRBXY(25, 33, 83, 75, 8, 8);

  static Paint _fill(Color color) => Paint()..color = color;

  static Paint _linear(Offset a, Offset b, List<Color> colors) =>
      Paint()..shader = Gradient.linear(a, b, colors);

  static Paint _radial(
    Offset c,
    double r,
    List<Color> colors, [
    List<double>? stops,
  ]) => Paint()..shader = Gradient.radial(c, r, colors, stops);

  // ------------------------------------------------------------ background

  static void _background(Canvas canvas, IconCandidate candidate) {
    switch (candidate) {
      case IconCandidate.a:
        canvas.drawRect(
          _all,
          _linear(Offset.zero, const Offset(grid, grid), const [
            IconColors.tileTop,
            IconColors.tileBottom,
          ]),
        );
      case IconCandidate.b:
        canvas.drawRect(
          _all,
          _linear(Offset.zero, const Offset(0, grid), const [
            IconColors.cream,
            IconColors.creamShade,
          ]),
        );
    }
  }

  // ------------------------------------------------------------ foreground

  static void _foreground(Canvas canvas, IconCandidate candidate) {
    switch (candidate) {
      case IconCandidate.a:
        _cameraForeground(canvas);
      case IconCandidate.b:
        _frameForeground(canvas);
    }
  }

  // Candidate A geometry.
  static const Offset _lens = Offset(_c, 54);
  static const double _lensRadius = 16.5;
  static const Offset _dot = Offset(74.5, 41.5);
  static const double _dotRadius = 4.4;
  static const RRect _flashWindow = RRect.fromLTRBXY(
    29,
    38,
    40,
    42.5,
    1.6,
    1.6,
  );
  static const Offset _glint = Offset(_c - 5.2, 54 - 5.6);

  static void _cameraForeground(Canvas canvas) {
    // Soft contact shadow so the cream reads as a part, not a flat cut-out.
    canvas.drawRRect(
      _bodyA.shift(const Offset(0, 1.4)),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
    );
    // Cream plastic body.
    canvas.drawRRect(
      _bodyA,
      _linear(const Offset(0, 33), const Offset(0, 75), const [
        IconColors.cream,
        IconColors.creamShade,
      ]),
    );
    // Flash window.
    canvas.drawRRect(_flashWindow, _fill(IconColors.charcoal));
    // Oversized lens: housing, ring, glass.
    canvas.drawCircle(_lens, _lensRadius, _fill(IconColors.charcoal));
    canvas.drawCircle(_lens, 13.6, _fill(IconColors.lensRing));
    canvas.drawCircle(
      _lens,
      12.2,
      _radial(_lens.translate(-3, -4), 16, const [
        Color(0xFF1B2830),
        IconColors.glass,
      ]),
    );
    // One highlight and one amber coating arc: enough to read as glass.
    canvas.drawCircle(_glint, 2.5, _fill(const Color(0xE6FFFFFF)));
    canvas.drawArc(
      Rect.fromCircle(center: _lens, radius: 8.6),
      0.35,
      1.0,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = IconColors.amber.withAlpha(0xD0),
    );
    // Vermilion shutter dot.
    canvas.drawCircle(
      _dot.translate(0, 0.9),
      _dotRadius,
      _fill(IconColors.vermilionDark),
    );
    canvas.drawCircle(
      _dot,
      _dotRadius,
      _radial(_dot.translate(-1.3, -1.6), 6, const [
        IconColors.vermilionLight,
        IconColors.vermilion,
      ]),
    );
  }

  // Candidate B geometry.
  static const RRect _window = RRect.fromLTRBXY(31, 43, 77, 65, 4, 4);
  static const double _holeW = 9;
  static const double _holeH = 4.4;
  static const List<Offset> _holes = [
    Offset(_c - 11.5, 38),
    Offset(_c + 11.5, 38),
    Offset(_c - 11.5, 70),
    Offset(_c + 11.5, 70),
  ];

  static Path _holesPath() {
    final path = Path();
    for (final h in _holes) {
      path.addRRect(
        RRect.fromRectXY(
          Rect.fromCenter(center: h, width: _holeW, height: _holeH),
          1.6,
          1.6,
        ),
      );
    }
    return path;
  }

  /// The charcoal frame with its two perforations per rail cut out. With
  /// [windowToo] the exposure window is cut out as well.
  static Path _framePath({required bool windowToo}) {
    var path = Path()..addRRect(_frameB);
    path = Path.combine(PathOperation.difference, path, _holesPath());
    if (windowToo) {
      path = Path.combine(
        PathOperation.difference,
        path,
        Path()..addRRect(_window),
      );
    }
    return path;
  }

  static void _frameForeground(Canvas canvas) {
    final frame = _framePath(windowToo: false);
    canvas.drawShadow(frame, const Color(0xFF000000), 1.2, false);
    canvas.drawPath(frame, _fill(IconColors.charcoal));
    // Exposure glow: a soft amber halo over the rails around the window...
    canvas.save();
    canvas.clipPath(frame);
    canvas.drawRRect(
      _window.inflate(1.2),
      Paint()
        ..color = IconColors.amber.withAlpha(0x70)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2),
    );
    canvas.restore();
    // ...and the window itself, hot in the middle and orange at the edge.
    canvas.drawRRect(
      _window,
      _radial(
        const Offset(_c, _c),
        26,
        const [IconColors.hot, IconColors.amber, IconColors.orange],
        const [0.0, 0.5, 1.0],
      ),
    );
  }

  // ------------------------------------------------------------ monochrome

  /// One opaque colour; the launcher tints the alpha. Details are holes.
  static void _monochrome(Canvas canvas, IconCandidate candidate) {
    final ink = _fill(const Color(0xFF000000));
    switch (candidate) {
      case IconCandidate.a:
        var path = Path()..addRRect(_bodyA);
        final ring = Path.combine(
          PathOperation.difference,
          Path()..addOval(Rect.fromCircle(center: _lens, radius: 16)),
          Path()..addOval(Rect.fromCircle(center: _lens, radius: 13)),
        );
        for (final hole in [
          ring,
          Path()..addRRect(_flashWindow),
          Path()..addOval(Rect.fromCircle(center: _dot, radius: _dotRadius)),
          Path()..addOval(Rect.fromCircle(center: _glint, radius: 2.5)),
        ]) {
          path = Path.combine(PathOperation.difference, path, hole);
        }
        canvas.drawPath(path, ink);
      case IconCandidate.b:
        canvas.drawPath(_framePath(windowToo: true), ink);
        // The exposure stays as a solid glow in the window.
        canvas.drawCircle(const Offset(_c, _c), 8.5, ink);
    }
  }
}

/// The outlines launchers cut icons into, in a box of [size].
abstract final class IconMasks {
  static Path circle(Rect r) => Path()..addOval(r);

  /// A superellipse (|x|^5 + |y|^5 = 1), the "squircle" of many launchers.
  static Path squircle(Rect r) {
    const n = 5.0;
    const steps = 160;
    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final t = 2 * math.pi * i / steps;
      final cs = math.cos(t);
      final sn = math.sin(t);
      final x = cs.sign * math.pow(cs.abs(), 2 / n);
      final y = sn.sign * math.pow(sn.abs(), 2 / n);
      final p = Offset(
        r.center.dx + x * r.width / 2,
        r.center.dy + y * r.height / 2,
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  static Path rounded(Rect r) =>
      Path()..addRRect(RRect.fromRectXY(r, r.width * 0.26, r.width * 0.26));
}
