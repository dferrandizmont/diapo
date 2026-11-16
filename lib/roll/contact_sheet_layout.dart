import 'dart:math' as math;
import 'dart:ui';

/// The geometry of the shareable contact sheet image, in output pixels.
///
/// A portrait sheet: a leader strip with the film name and the date, then the
/// frames in strips of [columns] across, each strip with perforations above
/// and below and the frame numbers printed under the frames. Every frame sits
/// in an equal cell of 3:2 (the frame of a 35 mm film, as in the contact sheet
/// of the app); a photo is fitted inside its cell, never cropped.
///
/// All the measures are written for a sheet 1200 px wide and scaled with the
/// width, so a different width gives the same sheet at another size. This class
/// is pure maths: it paints nothing.
class ContactSheetLayout {
  ContactSheetLayout._({
    required this.frameCount,
    required this.columns,
    required this.width,
    required this.height,
    required this.rows,
    required this.unit,
    required this.cellSize,
    required this.frameLeft,
  });

  /// The layout of a sheet of [frameCount] frames, [columns] across, on an
  /// image [width] pixels wide. The height follows from the number of rows.
  factory ContactSheetLayout(
    int frameCount, {
    int columns = defaultColumns,
    int width = defaultWidth,
  }) {
    if (frameCount < 1) {
      throw ArgumentError.value(frameCount, 'frameCount', 'must be positive');
    }
    if (columns < 1) {
      throw ArgumentError.value(columns, 'columns', 'must be positive');
    }
    if (width < 240) {
      throw ArgumentError.value(width, 'width', 'is too small to be a sheet');
    }
    final unit = width / defaultWidth;
    double u(double value) => (value * unit).roundToDouble();

    final stripWidth = width - 2 * u(_margin);
    final inner = stripWidth - 2 * u(_stripInset) - (columns - 1) * u(_gap);
    final cellWidth = (inner / columns).floorToDouble();
    final cellHeight = (cellWidth / frameAspect).roundToDouble();
    final rowsFor = (frameCount + columns - 1) ~/ columns;
    final frameLeft =
        u(_margin) +
        ((stripWidth - columns * cellWidth - (columns - 1) * u(_gap)) / 2)
            .floorToDouble();

    final layout = ContactSheetLayout._(
      frameCount: frameCount,
      columns: columns,
      width: width,
      height: 0,
      rows: rowsFor,
      unit: unit,
      cellSize: Size(cellWidth, cellHeight),
      frameLeft: frameLeft,
    );
    final height =
        2 * layout.margin +
        layout.leaderHeight +
        rowsFor * (layout.stripGap + layout.stripHeight);
    return ContactSheetLayout._(
      frameCount: frameCount,
      columns: columns,
      width: width,
      height: height.round(),
      rows: rowsFor,
      unit: unit,
      cellSize: Size(cellWidth, cellHeight),
      frameLeft: frameLeft,
    );
  }

  /// The frames across: about four fill a phone screen with 24 or 36 frames.
  static const int defaultColumns = 4;

  /// The width the measures are written for, in pixels.
  static const int defaultWidth = 1200;

  /// The shape of a cell, width over height.
  static const double frameAspect = 3 / 2;

  // The measures, at the default width.
  static const double _margin = 24;
  static const double _gap = 12;
  static const double _stripInset = 20;
  static const double _perf = 24;
  static const double _perfPad = 6;
  static const double _number = 24;
  static const double _stripGap = 16;
  static const double _leaderText = 40;

  /// The number of frames on the sheet (the missing ones too).
  final int frameCount;

  /// The frames across.
  final int columns;

  /// The width of the image, in pixels.
  final int width;

  /// The height of the image, in pixels.
  final int height;

  /// The strips of frames (the leader is not counted).
  final int rows;

  /// How many times the measures at the default width are scaled.
  final double unit;

  /// The size of a cell: every frame sits in one of these.
  final Size cellSize;

  /// The left edge of the first frame of a strip.
  final double frameLeft;

  double _u(double value) => (value * unit).roundToDouble();

  /// The space around the sheet.
  double get margin => _u(_margin);

  /// The space between the frames of a strip.
  double get frameGap => _u(_gap);

  /// The height of a row of perforations.
  double get perfHeight => _u(_perf);

  /// The distance between two perforations.
  double get perfPitch => _u(30);

  /// The width of a perforation.
  double get perfWidth => _u(18);

  /// The height of a perforation hole.
  double get perfHole => _u(14);

  /// The corner radius of a perforation.
  double get perfRadius => _u(4);

  /// The space between the perforations and the frames.
  double get perfPad => _u(_perfPad);

  /// The height of the line of numbers under the frames.
  double get numberHeight => _u(_number);

  /// The space between two strips (and between the leader and the first).
  double get stripGap => _u(_stripGap);

  /// The height of a strip of frames: perforations, frames, numbers,
  /// perforations.
  double get stripHeight =>
      perfHeight + perfPad + cellSize.height + numberHeight + perfHeight;

  /// The height of the leader strip with the film name and the date.
  double get leaderHeight => perfHeight + _u(_leaderText) + perfHeight;

  /// The space between the film and the edge of a strip.
  double get stripInset => _u(_stripInset);

  /// The leader strip, on top of the sheet.
  Rect get leaderRect =>
      Rect.fromLTWH(margin, margin, width - 2 * margin, leaderHeight);

  /// The line of the leader between its two rows of perforations, where the
  /// film name and the date are printed.
  Rect get leaderTextRect => Rect.fromLTWH(
    leaderRect.left + stripInset,
    leaderRect.top + perfHeight,
    leaderRect.width - 2 * stripInset,
    _u(_leaderText),
  );

  /// The strip of the [row]th row of frames (from 0).
  Rect stripRect(int row) {
    RangeError.checkValueInInterval(row, 0, rows - 1, 'row');
    final top =
        margin + leaderHeight + stripGap + row * (stripHeight + stripGap);
    return Rect.fromLTWH(margin, top, width - 2 * margin, stripHeight);
  }

  /// The row of perforations on top of [row].
  Rect topPerforations(int row) {
    final strip = stripRect(row);
    return Rect.fromLTWH(strip.left, strip.top, strip.width, perfHeight);
  }

  /// The row of perforations under [row].
  Rect bottomPerforations(int row) {
    final strip = stripRect(row);
    return Rect.fromLTWH(
      strip.left,
      strip.bottom - perfHeight,
      strip.width,
      perfHeight,
    );
  }

  /// The row of perforations over the leader text.
  Rect get leaderTopPerforations => Rect.fromLTWH(
    leaderRect.left,
    leaderRect.top,
    leaderRect.width,
    perfHeight,
  );

  /// The row of perforations under the leader text.
  Rect get leaderBottomPerforations => Rect.fromLTWH(
    leaderRect.left,
    leaderRect.bottom - perfHeight,
    leaderRect.width,
    perfHeight,
  );

  /// The row (from 0) of the frame at [index].
  int rowOf(int index) => index ~/ columns;

  /// The column (from 0) of the frame at [index].
  int columnOf(int index) => index % columns;

  /// The cell of the frame at [index] (from 0, in order).
  Rect cellRect(int index) {
    RangeError.checkValueInInterval(index, 0, frameCount - 1, 'index');
    final strip = stripRect(rowOf(index));
    return Rect.fromLTWH(
      frameLeft + columnOf(index) * (cellSize.width + frameGap),
      strip.top + perfHeight + perfPad,
      cellSize.width,
      cellSize.height,
    );
  }

  /// The line under the cell of the frame at [index] where its number is
  /// printed.
  Rect numberRect(int index) {
    final cell = cellRect(index);
    return Rect.fromLTWH(cell.left, cell.bottom, cell.width, numberHeight);
  }

  /// Where a photo of [photoWidth] x [photoHeight] goes in the cell of the
  /// frame at [index]: the largest rectangle of its shape that fits, centred,
  /// on whole pixels.
  Rect photoRect(int index, int photoWidth, int photoHeight) =>
      fit(cellRect(index), photoWidth, photoHeight);

  /// The largest rectangle with the shape of [photoWidth] x [photoHeight] that
  /// fits in [box], centred on whole pixels. The photo is never cropped.
  static Rect fit(Rect box, int photoWidth, int photoHeight) {
    if (photoWidth < 1 || photoHeight < 1) return box;
    final scale = math.min(box.width / photoWidth, box.height / photoHeight);
    final w = math.max(1.0, (photoWidth * scale).roundToDouble());
    final h = math.max(1.0, (photoHeight * scale).roundToDouble());
    return Rect.fromLTWH(
      (box.left + (box.width - w) / 2).roundToDouble(),
      (box.top + (box.height - h) / 2).roundToDouble(),
      math.min(w, box.width),
      math.min(h, box.height),
    );
  }
}
