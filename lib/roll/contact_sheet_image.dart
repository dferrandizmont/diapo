import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart';

import '../ui/theme/carrete_tokens.dart';
import 'contact_sheet_layout.dart';

/// One frame of the shareable contact sheet.
class ContactSheetFrame {
  /// A frame with a photo that [load] reads when the sheet is painted.
  const ContactSheetFrame({required this.number, this.load});

  /// A frame with no photo (deleted, or never developed): the sheet shows an
  /// empty frame that keeps its [number].
  const ContactSheetFrame.missing(this.number) : load = null;

  /// The original frame number of the roll, printed under the frame.
  final int number;

  /// Reads the encoded photo (JPEG, PNG...). Called once, when it is the
  /// frame's turn; the bytes are dropped as soon as the frame is painted, so
  /// only one photo is in memory at a time. A null answer, an error or bytes
  /// that cannot be decoded leave the frame empty.
  final Future<Uint8List?> Function()? load;
}

/// Turns the painted sheet into the bytes of an image file.
///
/// Android uses native JPEG encoding; other platforms and native failures
/// fall back to PNG. Neither encoder writes to the system gallery.
abstract interface class ContactSheetEncoder {
  /// The extension of the last encoded image, without the dot (`jpg`).
  String get extension;

  /// The bytes of [image]. The caller keeps ownership of the image.
  Future<Uint8List> encode(ui.Image image);
}

/// A [ContactSheetEncoder] that needs no native side: PNG through the engine.
/// The files are several times larger than a JPEG; it is the fallback for
/// platforms without the native encoder and for the tests.
class PngContactSheetEncoder implements ContactSheetEncoder {
  const PngContactSheetEncoder();

  @override
  String get extension => 'png';

  @override
  Future<Uint8List> encode(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('The sheet could not be encoded');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
}

/// Native JPEG at quality 88, bounded to 4096 px per side and 16,000,000 pixels,
/// with PNG as the fallback. Use one instance per sheet: [extension] follows
/// the format returned by the latest [encode].
class JpegContactSheetEncoder implements ContactSheetEncoder {
  static const _pixels = BasicMessageChannel<ByteData?>(
    'carrete/media/contact-sheet',
    BinaryCodec(),
  );

  String _extension = 'jpg';

  @override
  String get extension => _extension;

  @override
  Future<Uint8List> encode(ui.Image image) async {
    try {
      // Keep in sync with validateContactSheetDimensions on Android, before
      // allocating RGBA or building the native message.
      if (image.width < 1 ||
          image.height < 1 ||
          image.width > 4096 ||
          image.height > 4096 ||
          image.width * image.height > 16000000) {
        throw StateError('The sheet exceeds the native encoder size limit');
      }
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rgba == null) throw StateError('The sheet has no pixels');
      // The direct binary transport avoids a frame-sized Java byte array.
      // Three little-endian int32s precede the RGBA, as in the tile transport.
      final message = ByteData(12 + rgba.lengthInBytes)
        ..setInt32(0, image.width, Endian.little)
        ..setInt32(4, image.height, Endian.little)
        ..setInt32(8, 88, Endian.little);
      message.buffer.asUint8List().setRange(
        12,
        message.lengthInBytes,
        Uint8List.sublistView(rgba),
      );
      final reply = await _pixels.send(message);
      if (reply == null || reply.lengthInBytes == 0) {
        throw PlatformException(code: 'encode_failed');
      }
      _extension = 'jpg';
      return Uint8List.sublistView(reply);
    } on Object {
      final png = await const PngContactSheetEncoder().encode(image);
      _extension = 'png';
      return png;
    }
  }
}

ContactSheetEncoder _defaultEncoder() =>
    defaultTargetPlatform == TargetPlatform.android
    ? JpegContactSheetEncoder()
    : const PngContactSheetEncoder();

/// The folder of the cache that holds the sheets to share.
const String contactSheetFolder = 'contact-sheets';

/// Keeps two sheets made in the same microsecond apart.
int _sheetCounter = 0;

/// Paints the contact sheet of a developed roll and writes it to a file in
/// `<cache>/contact-sheets/`, ready to share.
///
/// [frames] are the frames of the roll in order, one per frame of the sheet
/// (a deleted photo is a [ContactSheetFrame.missing]), with their original
/// numbers. [filmName] and [date] are printed small on the leader strip, in
/// the style of the edge markings of a film, and [bandColor] (the band of the
/// film's cartridge, see `filmBandColor`) is the one touch of colour. The name
/// the user gave the roll ([rollName], when it has one) is written by hand
/// after the film name, in Caveat, and cut with an ellipsis when it does not
/// fit. Nothing else is printed: no app name, no watermark.
///
/// The photos are decoded one by one, already reduced to the size of their
/// cell, so memory stays at the size of the sheet itself (about 12 MB at the
/// default size) however many frames there are.
///
/// The file has a name of its own, and nothing else in the folder is touched:
/// several previews may be painting at once, and a render that finishes late
/// must never delete the sheet another one is showing. The caller deletes only
/// the files it made (see `deleteContactSheet`); a file that was handed to
/// another app is left until the next start, when [cleanContactSheets] sweeps
/// the folder (`cleanStartupTemps`).
Future<File> renderContactSheet({
  required List<ContactSheetFrame> frames,
  required String filmName,
  String? rollName,
  required ui.Color bandColor,
  required DateTime date,
  required Directory cache,
  ContactSheetEncoder? encoder,
  int columns = ContactSheetLayout.defaultColumns,
  int width = ContactSheetLayout.defaultWidth,
  CarreteSheetColors colors = CarreteSheetColors.dark,
}) async {
  encoder ??= _defaultEncoder();
  final bytes = await encodeContactSheet(
    frames: frames,
    filmName: filmName,
    rollName: rollName,
    bandColor: bandColor,
    date: date,
    encoder: encoder,
    columns: columns,
    width: width,
    colors: colors,
  );
  final directory = Directory('${cache.path}/$contactSheetFolder');
  await directory.create(recursive: true);
  final file = File(
    '${directory.path}/sheet-${DateTime.now().microsecondsSinceEpoch}'
    '-${_sheetCounter++}.${encoder.extension}',
  );
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

/// Paints the sheet and returns the bytes of the encoded image, with no file.
Future<Uint8List> encodeContactSheet({
  required List<ContactSheetFrame> frames,
  required String filmName,
  String? rollName,
  required ui.Color bandColor,
  required DateTime date,
  ContactSheetEncoder? encoder,
  int columns = ContactSheetLayout.defaultColumns,
  int width = ContactSheetLayout.defaultWidth,
  CarreteSheetColors colors = CarreteSheetColors.dark,
}) async {
  final image = await paintContactSheet(
    frames: frames,
    filmName: filmName,
    rollName: rollName,
    bandColor: bandColor,
    date: date,
    columns: columns,
    width: width,
    colors: colors,
  );
  try {
    return await (encoder ?? _defaultEncoder()).encode(image);
  } finally {
    image.dispose();
  }
}

/// Paints the sheet to an image the caller owns (and must dispose).
Future<ui.Image> paintContactSheet({
  required List<ContactSheetFrame> frames,
  required String filmName,
  String? rollName,
  required ui.Color bandColor,
  required DateTime date,
  int columns = ContactSheetLayout.defaultColumns,
  int width = ContactSheetLayout.defaultWidth,
  CarreteSheetColors colors = CarreteSheetColors.dark,
}) async {
  final layout = ContactSheetLayout(
    frames.length,
    columns: columns,
    width: width,
  );
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(
    recorder,
    ui.Rect.fromLTWH(0, 0, layout.width.toDouble(), layout.height.toDouble()),
  );
  final painter = _SheetPainter(layout, colors, canvas);
  painter.paintBase(
    filmName: filmName,
    rollName: rollName,
    bandColor: bandColor,
    date: date,
    numbers: [for (final frame in frames) frame.number],
  );
  for (var i = 0; i < frames.length; i++) {
    final photo = await _loadPhoto(frames[i], layout.cellSize);
    painter.paintFrame(i, photo);
    photo?.dispose();
  }
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(layout.width, layout.height);
  } finally {
    picture.dispose();
  }
}

/// Deletes the sheets left in `<cache>/contact-sheets/`. They are plaintext
/// copies of the user's photos. It runs at app start (`cleanStartupTemps`) and
/// nowhere else: [renderContactSheet] never sweeps, because a preview that is
/// open may be showing one of them.
Future<void> cleanContactSheets(Directory cache) async {
  final directory = Directory('${cache.path}/$contactSheetFolder');
  try {
    if (!await directory.exists()) return;
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is File) {
        try {
          await entry.delete();
        } on FileSystemException {
          // Gone already or in use (the share sheet is reading it); the next
          // start tries again.
        }
      }
    }
  } on FileSystemException {
    // Starting must still work if the cache is not available.
  }
}

/// The most pixels of a source photo the sheet agrees to open (the header is
/// read first; a larger one leaves the frame empty).
const int _maxSourcePixels = 120000000;

/// Reads and decodes the photo of [frame], reduced so that its long side is
/// the long side of a cell. Null when there is no photo or it cannot be read.
Future<ui.Image?> _loadPhoto(ContactSheetFrame frame, ui.Size cell) async {
  final load = frame.load;
  if (load == null) return null;
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  try {
    final bytes = await load();
    if (bytes == null || bytes.isEmpty) return null;
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    if (descriptor.width < 1 ||
        descriptor.height < 1 ||
        descriptor.width * descriptor.height > _maxSourcePixels) {
      return null;
    }
    final longSide = math.max(cell.width, cell.height).ceil();
    // Only ever smaller: a thumbnail is not stretched by the decoder.
    final landscape = descriptor.width >= descriptor.height;
    final longest = landscape ? descriptor.width : descriptor.height;
    codec = longest <= longSide
        ? await descriptor.instantiateCodec()
        : await descriptor.instantiateCodec(
            targetWidth: landscape ? longSide : null,
            targetHeight: landscape ? null : longSide,
          );
    final frameInfo = await codec.getNextFrame();
    return frameInfo.image;
  } on Object {
    // A photo that cannot be read leaves an empty frame, not a failed sheet.
    return null;
  } finally {
    // The codec decodes lazily from the descriptor's data: they go after the
    // frame has been taken.
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}

/// The paint of the sheet. Colours are the dark light-table colours of the
/// contact sheet of the app.
class _SheetPainter {
  _SheetPainter(this.layout, this.colors, this.canvas);

  final ContactSheetLayout layout;
  final CarreteSheetColors colors;
  final ui.Canvas canvas;

  /// Behind a photo: the unexposed base, darker than the strip.
  static const ui.Color _photoBase = ui.Color(0xFF120B05);

  void paintBase({
    required String filmName,
    String? rollName,
    required ui.Color bandColor,
    required DateTime date,
    required List<int> numbers,
  }) {
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, layout.width.toDouble(), layout.height.toDouble()),
      ui.Paint()..color = colors.sheet,
    );
    _paintLeader(filmName, rollName, bandColor, date);
    for (var row = 0; row < layout.rows; row++) {
      final strip = layout.stripRect(row);
      canvas.drawRect(strip, ui.Paint()..color = colors.strip);
      _paintPerforations(layout.topPerforations(row));
      _paintPerforations(layout.bottomPerforations(row));
    }
    for (var i = 0; i < numbers.length; i++) {
      _paintNumber(i, numbers[i]);
    }
  }

  void _paintLeader(
    String filmName,
    String? rollName,
    ui.Color bandColor,
    DateTime date,
  ) {
    canvas.drawRect(layout.leaderRect, ui.Paint()..color = colors.strip);
    _paintPerforations(layout.leaderTopPerforations);
    _paintPerforations(layout.leaderBottomPerforations);
    final text = layout.leaderTextRect;
    final u = layout.unit;
    // The band of the cartridge: the only colour on the sheet.
    final swatch = ui.Size(36 * u, 14 * u);
    final swatchRect = ui.Rect.fromLTWH(
      text.left,
      text.top + (text.height - swatch.height) / 2,
      swatch.width,
      swatch.height,
    );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(swatchRect, ui.Radius.circular(3 * u)),
      ui.Paint()..color = bandColor,
    );
    final dateParagraph = _paragraph(
      _dateLabel(date),
      size: 22 * u,
      color: colors.edge,
      maxWidth: text.width / 2,
      align: ui.TextAlign.right,
    );
    final nameLeft = swatchRect.right + 14 * u;
    // What is left between the swatch and the date, for the film and, when the
    // roll has a name, for the name written by hand.
    final room = math.max(
      1.0,
      text.right - dateParagraph.longestLine - 24 * u - nameLeft,
    );
    final gap = 24 * u;
    final handText = rollName?.trim() ?? '';
    final wantsHand = handText.isNotEmpty;
    var nameParagraph = _paragraph(
      filmName.toUpperCase(),
      size: 22 * u,
      color: colors.edge,
      maxWidth: room,
    );
    if (wantsHand && nameParagraph.longestLine > room * 0.45) {
      // The film keeps at most 45 % of the line, so the name has room too.
      nameParagraph = _paragraph(
        filmName.toUpperCase(),
        size: 22 * u,
        color: colors.edge,
        maxWidth: room * 0.45,
      );
    }
    canvas.drawParagraph(
      nameParagraph,
      ui.Offset(nameLeft, text.top + (text.height - nameParagraph.height) / 2),
    );
    final handLeft = nameLeft + nameParagraph.longestLine + gap;
    final handRoom = text.right - dateParagraph.longestLine - gap - handLeft;
    if (wantsHand && handRoom > 40 * u) {
      final handParagraph = _paragraph(
        handText,
        size: 32 * u,
        color: colors.edge,
        maxWidth: handRoom,
        family: CarreteFonts.hand,
        weight: ui.FontWeight.w600,
        tracking: 0,
      );
      canvas.drawParagraph(
        handParagraph,
        ui.Offset(
          handLeft,
          text.top + (text.height - handParagraph.height) / 2,
        ),
      );
    }
    canvas.drawParagraph(
      dateParagraph,
      ui.Offset(
        text.right - dateParagraph.width,
        text.top + (text.height - dateParagraph.height) / 2,
      ),
    );
  }

  void _paintPerforations(ui.Rect row) {
    final paint = ui.Paint()..color = colors.perf;
    final pitch = layout.perfPitch;
    final count = (row.width / pitch).floor();
    final start = row.left + (row.width - count * pitch) / 2;
    final inset = (pitch - layout.perfWidth) / 2;
    final top = row.top + (row.height - layout.perfHole) / 2;
    for (var i = 0; i < count; i++) {
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(
            start + i * pitch + inset,
            top,
            layout.perfWidth,
            layout.perfHole,
          ),
          ui.Radius.circular(layout.perfRadius),
        ),
        paint,
      );
    }
  }

  /// The number under the frame, with the small arrow of the edge print.
  void _paintNumber(int index, int number) {
    final area = layout.numberRect(index);
    final u = layout.unit;
    final paragraph = _paragraph(
      '$number',
      size: 18 * u,
      color: colors.edge,
      maxWidth: area.width,
      weight: ui.FontWeight.w600,
    );
    final y = area.top + (area.height - paragraph.height) / 2;
    canvas.drawParagraph(paragraph, ui.Offset(area.left, y));
    final arrowX = area.left + paragraph.longestLine + 8 * u;
    final mid = area.top + area.height / 2;
    canvas.drawPath(
      ui.Path()
        ..moveTo(arrowX, mid - 5 * u)
        ..lineTo(arrowX + 8 * u, mid)
        ..lineTo(arrowX, mid + 5 * u)
        ..close(),
      ui.Paint()..color = colors.edge,
    );
  }

  /// The frame at [index]: its photo fitted in the cell, or the empty frame
  /// when [photo] is null.
  void paintFrame(int index, ui.Image? photo) {
    final cell = layout.cellRect(index);
    if (photo == null) {
      canvas.drawRect(cell, ui.Paint()..color = colors.empty);
      return;
    }
    canvas.drawRect(cell, ui.Paint()..color = _photoBase);
    final target = layout.photoRect(index, photo.width, photo.height);
    canvas.drawImageRect(
      photo,
      ui.Rect.fromLTWH(0, 0, photo.width.toDouble(), photo.height.toDouble()),
      target,
      ui.Paint()
        ..filterQuality = ui.FilterQuality.high
        ..isAntiAlias = true,
    );
  }

  ui.Paragraph _paragraph(
    String text, {
    required double size,
    required ui.Color color,
    required double maxWidth,
    ui.TextAlign align = ui.TextAlign.left,
    ui.FontWeight weight = ui.FontWeight.w600,
    String family = CarreteFonts.display,
    double? tracking,
  }) {
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              fontFamily: family,
              fontSize: size,
              fontWeight: weight,
              textAlign: align,
              maxLines: 1,
              ellipsis: '…',
            ),
          )
          ..pushStyle(
            ui.TextStyle(
              color: color,
              fontFamily: family,
              fontFamilyFallback: const [CarreteFonts.text],
              fontSize: size,
              fontWeight: weight,
              // The variable font of the hand takes its weight from this axis.
              fontVariations: family == CarreteFonts.hand
                  ? [ui.FontVariation('wght', weight.value.toDouble())]
                  : null,
              letterSpacing: tracking ?? size * 0.14,
            ),
          )
          ..addText(text);
    return builder.build()..layout(ui.ParagraphConstraints(width: maxWidth));
  }
}

/// The date as the edge print of a film shows it: numbers only, year first,
/// so it reads the same in every language.
String _dateLabel(DateTime date) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${date.year} ${two(date.month)} ${two(date.day)}';
}
