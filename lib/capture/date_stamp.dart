import 'package:flutter/widgets.dart';

import '../core/settings/app_settings.dart';
import '../ui/theme/carrete_tokens.dart';
import '../ui/widgets/seven_segment.dart';
import 'cinema_bands.dart';

/// The date imprint of a 90s camera: orange seven-segment digits in the
/// bottom right corner of the frame.
///
/// The same code draws it on the viewfinder overlay and burns it into the
/// saved still, with a size and a position relative to the short side of the
/// frame, so both look the same at any resolution.
abstract final class DateStamp {
  /// The height of the digits, as a fraction of the short side of the frame.
  static const double heightFraction = 0.05;

  /// The distance to the right and bottom edges, as a fraction of the short
  /// side of the frame.
  static const double marginFraction = 0.05;

  /// The text of the imprint for [date] in the given [style].
  ///
  /// `yearFirst` gives `'98 7 14` and `dayFirst` gives `14 7 '98`: the year
  /// has two digits (with a leading zero: `'07`), the month and the day none.
  static String format(DateTime date, DateStampStyle style) {
    final yy = (date.year % 100).toString().padLeft(2, '0');
    return switch (style) {
      DateStampStyle.yearFirst => "'$yy ${date.month} ${date.day}",
      DateStampStyle.dayFirst => "${date.day} ${date.month} '$yy",
    };
  }

  /// The height of the digits on a frame of [frame] size.
  static double digitHeight(Size frame) => frame.shortestSide * heightFraction;

  /// The top left corner of [text] on a frame of [frame] size.
  static Offset origin(Size frame, String text) {
    final h = digitHeight(frame);
    final size = SevenSegment.measure(text, h);
    final margin = frame.shortestSide * marginFraction;
    return Offset(frame.width - margin - size.width, frame.height - margin - h);
  }

  /// Draws [text] on a frame of [frame] size.
  static void paint(Canvas canvas, Size frame, String text) {
    SevenSegment.paint(
      canvas,
      text,
      origin(frame, text),
      digitHeight(frame),
      CarreteColors.date,
      glow: true,
    );
  }
}

/// The imprint over the frame of the viewfinder.
class DateStampOverlay extends StatelessWidget {
  const DateStampOverlay({
    required this.text,
    this.cinemaBands = false,
    super.key,
  });

  /// The text to draw, see [DateStamp.format].
  final String text;

  /// Place the imprint inside the visible cinema picture.
  final bool cinemaBands;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: CustomPaint(
          size: Size.infinite,
          painter: _DateStampPainter(text, cinemaBands),
        ),
      ),
    );
  }
}

class _DateStampPainter extends CustomPainter {
  const _DateStampPainter(this.text, this.cinemaBands);

  final String text;
  final bool cinemaBands;

  @override
  void paint(Canvas canvas, Size size) {
    final picture = cinemaBands
        ? CinemaBands.pictureRect(size)
        : Offset.zero & size;
    canvas.save();
    canvas.clipRect(picture);
    canvas.translate(picture.left, picture.top);
    DateStamp.paint(canvas, picture.size, text);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DateStampPainter old) =>
      old.text != text || old.cinemaBands != cinemaBands;
}
