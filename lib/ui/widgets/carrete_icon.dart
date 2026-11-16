import 'package:flutter/widgets.dart';

import '../theme/carrete_tokens.dart';
import 'svg_path_data.dart';

/// The own icons of the camera, drawn as strokes on a 24 x 24 grid.
enum CarreteIcon {
  /// Flash off.
  flashOff(
    'M12 4.5L6 13.5h4.6M12.6 11.6L18 9.5l-4 5.2M10.4 15.6L10 21.5l3.2-4.2M4 4l16 16',
  ),

  /// Flash auto.
  flashAuto(
    'M10.5 3L4 12.5h5L8.2 19l6.3-9.5H10zM15.6 21l2.4-6.4 2.4 6.4M16.5 19h3',
  ),

  /// Flash on.
  flashOn('M13 2.5L5.5 13.5H11l-1 8 8.5-12H13z'),

  /// Party flash: a bolt with sparkles.
  flashParty(
    'M10 3.5L4 12.5h5l-.8 6.5 6-9H10zM18 3v4M16 5h4M19.5 13v3.4M17.8 14.7h3.4M16 19.5v2M15 20.5h2',
  ),

  /// Switch between the back and the front camera.
  flip(
    'M20 11a8 8 0 0 0-14.4-4.2L4 8.5M4 4v4.5h4.5M4 13a8 8 0 0 0 14.4 4.2L20 15.5M20 20v-4.5h-4.5M14.4 12a2.4 2.4 0 1 1-4.8 0 2.4 2.4 0 1 1 4.8 0',
  ),

  /// Settings.
  sliders(
    'M4 7h9M17 7h3M4 17h3M11 17h9M17.2 7a2.2 2.2 0 1 1-4.4 0 2.2 2.2 0 1 1 4.4 0M11.2 17a2.2 2.2 0 1 1-4.4 0 2.2 2.2 0 1 1 4.4 0',
  ),

  /// A strip of film.
  film(
    'M5 5h14a1.5 1.5 0 0 1 1.5 1.5v11A1.5 1.5 0 0 1 19 19H5a1.5 1.5 0 0 1-1.5-1.5v-11A1.5 1.5 0 0 1 5 5zM7.5 5v14M16.5 5v14M3.5 9.5h4M3.5 14.5h4M16.5 9.5h4M16.5 14.5h4',
  ),

  /// A roll of film: the reel with its hub and three slots.
  roll(
    'M20.5 12a8.5 8.5 0 1 1-17 0 8.5 8.5 0 1 1 17 0M14.4 12a2.4 2.4 0 1 1-4.8 0 2.4 2.4 0 1 1 4.8 0M12 3.5V7M5.1 16.2l3-1.7M18.9 16.2l-3-1.7',
  ),

  /// The gallery: a print with a hill and a sun.
  photos(
    'M5 4h14a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1zM4 16.5l4.5-4.5 4 4 2.5-2.5 5 5M15.5 8.8a1.4 1.4 0 1 1-2.8 0 1.4 1.4 0 1 1 2.8 0',
  ),

  /// Share: an arrow leaving a tray.
  share(
    'M12 15V3.5M7.5 8L12 3.5 16.5 8M5 13v6a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-6',
  ),

  /// Delete: a bin.
  trash('M4 7h16M9.5 7V4.5h5V7M6.5 7l1 13h9l1-13M10 11v5.5M14 11v5.5'),

  /// Close.
  close('M6 6l12 12M18 6L6 18'),

  /// Edit: a pencil.
  edit(
    'M4 20l1-4.5L16.2 4.3a1.9 1.9 0 0 1 2.7 0l.8.8a1.9 1.9 0 0 1 0 2.7L8.5 19zM14.5 6l3.5 3.5M4 20l4.5-1',
  ),

  /// Back to the previous screen.
  back('M19 12H5M11 6l-6 6 6 6'),

  /// Goes on to a screen.
  chevron('M9 5l7 7-7 7');

  const CarreteIcon(this.pathData);

  /// The SVG path data of the icon.
  final String pathData;

  static final Map<CarreteIcon, Path> _cache = <CarreteIcon, Path>{};

  /// The parsed path, on the 24 x 24 grid. Parsed once.
  Path get path => _cache.putIfAbsent(this, () => parseSvgPathData(pathData));
}

/// Draws a [CarreteIcon] with rounded strokes.
class CarreteIconView extends StatelessWidget {
  const CarreteIconView({
    required this.icon,
    this.color,
    this.size = CarreteSizes.icon,
    this.strokeWidth = CarreteSizes.iconStroke,
    super.key,
  });

  /// The icon to draw.
  final CarreteIcon icon;

  /// The colour of the strokes; the colour of the surrounding [IconTheme] when
  /// null (a key tints its icon amber when it is on).
  final Color? color;

  /// The side of the square the icon is drawn in.
  final double size;

  /// The width of the strokes, in units of the 24 x 24 grid.
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _IconPainter(
          icon.path,
          color ?? IconTheme.of(context).color ?? CarreteColors.white,
          strokeWidth,
        ),
      ),
    );
  }
}

class _IconPainter extends CustomPainter {
  const _IconPainter(this.path, this.color, this.strokeWidth);

  final Path path;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / CarreteSizes.iconGrid;
    canvas.save();
    canvas.scale(scale);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = strokeWidth
        ..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.path != path || old.color != color || old.strokeWidth != strokeWidth;
}
