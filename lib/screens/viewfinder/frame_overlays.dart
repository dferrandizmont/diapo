import 'package:flutter/widgets.dart';

import '../../ui/theme/carrete_tokens.dart';

/// The four corner marks of the frame. They are drawn inside the box they
/// are given, which is the visible frame.
class FrameCorners extends StatelessWidget {
  const FrameCorners({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: ExcludeSemantics(
        child: CustomPaint(size: Size.infinite, painter: _CornersPainter()),
      ),
    );
  }
}

class _CornersPainter extends CustomPainter {
  const _CornersPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const inset = CarreteMarks.cornerInset;
    const arm = CarreteMarks.cornerArm;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = CarreteMarks.strokeWidth
      ..strokeCap = StrokeCap.butt
      ..color = CarreteColors.frameMark;
    final l = inset;
    final t = inset;
    final r = size.width - inset;
    final b = size.height - inset;
    final path = Path()
      ..moveTo(l, t + arm)
      ..lineTo(l, t)
      ..lineTo(l + arm, t)
      ..moveTo(r - arm, t)
      ..lineTo(r, t)
      ..lineTo(r, t + arm)
      ..moveTo(r, b - arm)
      ..lineTo(r, b)
      ..lineTo(r - arm, b)
      ..moveTo(l + arm, b)
      ..lineTo(l, b)
      ..lineTo(l, b - arm);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornersPainter old) => false;
}

/// The grid of thirds.
class ThirdsGrid extends StatelessWidget {
  const ThirdsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: ExcludeSemantics(
        child: CustomPaint(size: Size.infinite, painter: _GridPainter()),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = CarreteMarks.gridWidth
      ..color = CarreteColors.gridLine;
    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}

/// The small indicator that shows where the focus and the exposure are locked:
/// four corner brackets and a padlock, in the white of the frame corners.
class FocusLockIndicator extends StatelessWidget {
  const FocusLockIndicator({super.key});

  /// The width of the indicator.
  static const double width = CarreteMarks.lockWidth;

  /// The height of the indicator.
  static const double height = CarreteMarks.lockHeight;

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _LockPainter()),
    );
  }
}

class _LockPainter extends CustomPainter {
  const _LockPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const arm = CarreteMarks.bracketArm;
    final bracket = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = CarreteMarks.strokeWidth
      ..color = CarreteColors.frameMark;
    final r = Offset.zero & size;
    final path = Path()
      ..moveTo(r.left, r.top + arm)
      ..lineTo(r.left, r.top)
      ..lineTo(r.left + arm, r.top)
      ..moveTo(r.right - arm, r.top)
      ..lineTo(r.right, r.top)
      ..lineTo(r.right, r.top + arm)
      ..moveTo(r.right, r.bottom - arm)
      ..lineTo(r.right, r.bottom)
      ..lineTo(r.right - arm, r.bottom)
      ..moveTo(r.left + arm, r.bottom)
      ..lineTo(r.left, r.bottom)
      ..lineTo(r.left, r.bottom - arm);
    canvas.drawPath(path, bracket);

    // The padlock, centred.
    const half = CarreteMarks.shackleHalf;
    final c = size.center(Offset.zero);
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: c.translate(0, CarreteMarks.padlockDrop),
        width: CarreteMarks.padlockWidth,
        height: CarreteMarks.padlockHeight,
      ),
      const Radius.circular(CarreteRadii.padlock),
    );
    canvas.drawRRect(body, Paint()..color = CarreteColors.frameMark);
    final shackle = Path()
      ..moveTo(c.dx - half, c.dy - CarreteMarks.shackleFoot)
      ..lineTo(c.dx - half, c.dy - CarreteMarks.shackleTop)
      ..arcToPoint(
        Offset(c.dx + half, c.dy - CarreteMarks.shackleTop),
        radius: const Radius.circular(half),
        clockwise: true,
      )
      ..lineTo(c.dx + half, c.dy - CarreteMarks.shackleFoot);
    canvas.drawPath(
      shackle,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = CarreteMarks.strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = CarreteColors.frameMark,
    );
  }

  @override
  bool shouldRepaint(_LockPainter old) => false;
}
