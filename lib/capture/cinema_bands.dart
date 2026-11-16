import 'package:flutter/widgets.dart';

/// Cinema bands follow the long edges without changing the output size.
abstract final class CinemaBands {
  static const Color color = Color(0xFF0A0A0A);
  static const double pictureAspect = 2.39;
  static const double barFraction = (1 - (16 / 9) / pictureAspect) / 2;

  /// The visible picture, in frame coordinates, at any resolution.
  static Rect pictureRect(Size frame) {
    final inset = frame.shortestSide * barFraction;
    return frame.width > frame.height
        ? Rect.fromLTRB(0, inset, frame.width, frame.height - inset)
        : Rect.fromLTRB(inset, 0, frame.width - inset, frame.height);
  }

  /// Paint after the film look so the bands remain flat and opaque.
  static void paint(Canvas canvas, Size frame) {
    final picture = pictureRect(frame);
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false;
    if (frame.width > frame.height) {
      canvas.drawRect(Rect.fromLTRB(0, 0, frame.width, picture.top), paint);
      canvas.drawRect(
        Rect.fromLTRB(0, picture.bottom, frame.width, frame.height),
        paint,
      );
    } else {
      canvas.drawRect(Rect.fromLTRB(0, 0, picture.left, frame.height), paint);
      canvas.drawRect(
        Rect.fromLTRB(picture.right, 0, frame.width, frame.height),
        paint,
      );
    }
  }
}

/// Shares the still renderer's band geometry with both live previews.
class CinemaBandsOverlay extends StatelessWidget {
  const CinemaBandsOverlay({super.key});

  @override
  Widget build(BuildContext context) => const IgnorePointer(
    child: ExcludeSemantics(
      child: CustomPaint(size: Size.infinite, painter: _CinemaBandsPainter()),
    ),
  );
}

class _CinemaBandsPainter extends CustomPainter {
  const _CinemaBandsPainter();

  @override
  void paint(Canvas canvas, Size size) => CinemaBands.paint(canvas, size);

  @override
  bool shouldRepaint(_CinemaBandsPainter oldDelegate) => false;
}
