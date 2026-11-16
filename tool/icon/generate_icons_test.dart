// Renders the icon candidates to `design/icono/`.
//
// Run from the repository root:
//   sh ~/.agents/scripts/heavy.sh flutter test tool/icon/generate_icons_test.dart
//
// It is not part of `flutter test` (that only runs `test/`); it is a tool, kept
// as a test file because that is the way to get `toImage` in a headless run.
import 'dart:io';
import 'dart:typed_data' show BytesBuilder;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'carrete_icon.dart';

const _out = 'design/icono';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File('assets/fonts/$f').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

Future<void> _png(
  String name,
  int w,
  int h,
  void Function(ui.Canvas) draw,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, w + 0.0, h + 0.0));
  draw(canvas);
  final image = await recorder.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  File('$_out/$name').writeAsBytesSync(data!.buffer.asUint8List());
}

// --------------------------------------------------------- sheet helpers

void _text(
  ui.Canvas c,
  String s,
  ui.Offset at, {
  double size = 16,
  ui.Color color = const ui.Color(0xFFFFFFFF),
  bool bold = false,
  bool center = false,
}) {
  final b =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(
            fontFamily: 'BarlowSemiCondensed',
            fontSize: size,
            fontWeight: bold ? ui.FontWeight.w700 : ui.FontWeight.w500,
            textAlign: center ? ui.TextAlign.center : ui.TextAlign.left,
          ),
        )
        ..pushStyle(ui.TextStyle(color: color))
        ..addText(s);
  final p = b.build()..layout(const ui.ParagraphConstraints(width: 1800));
  c.drawParagraph(p, center ? at.translate(-900, 0) : at);
}

typedef _Mask = ui.Path Function(ui.Rect);

void _icon(
  ui.Canvas c,
  ui.Offset at,
  double size,
  _Mask mask,
  void Function(ui.Canvas, double) paint,
) {
  c.save();
  c.translate(at.dx, at.dy);
  // A faint shadow, the way launchers lift icons off the wallpaper.
  final r = ui.Rect.fromLTWH(0, 0, size, size);
  c.drawPath(
    mask(r).shift(ui.Offset(0, size * 0.025)),
    ui.Paint()
      ..color = const ui.Color(0x40000000)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, size * 0.03),
  );
  c.clipPath(mask(r));
  paint(c, size);
  c.restore();
}

void _placeholder(ui.Canvas c, double s, int kind) {
  ui.Paint p(ui.Color a, [ui.Color? b]) => b == null
      ? (ui.Paint()..color = a)
      : (ui.Paint()
          ..shader = ui.Gradient.linear(ui.Offset.zero, ui.Offset(0, s), [
            a,
            b,
          ]));
  const white = ui.Color(0xFFFFFFFF);
  switch (kind) {
    case 0: // calendar-like card on coral
      c.drawRect(
        ui.Rect.fromLTWH(0, 0, s, s),
        p(const ui.Color(0xFFFF7A66), const ui.Color(0xFFE5484D)),
      );
      final card = ui.RRect.fromLTRBXY(
        s * .24,
        s * .27,
        s * .76,
        s * .76,
        s * .08,
        s * .08,
      );
      c.drawRRect(card, p(white));
      c.drawRect(
        ui.Rect.fromLTRB(s * .24, s * .27, s * .76, s * .42),
        p(const ui.Color(0xFFFFD0C8)),
      );
      c.drawCircle(
        ui.Offset(s * .5, s * .6),
        s * .08,
        p(const ui.Color(0xFFE5484D)),
      );
    case 1: // map pin on teal
      c.drawRect(
        ui.Rect.fromLTWH(0, 0, s, s),
        p(const ui.Color(0xFF22C3B0), const ui.Color(0xFF0F766E)),
      );
      final pin = ui.Path()
        ..addOval(
          ui.Rect.fromCircle(
            center: ui.Offset(s * .5, s * .42),
            radius: s * .19,
          ),
        )
        ..moveTo(s * .33, s * .53)
        ..lineTo(s * .5, s * .8)
        ..lineTo(s * .67, s * .53)
        ..close();
      c.drawPath(pin, p(white));
      c.drawCircle(
        ui.Offset(s * .5, s * .42),
        s * .075,
        p(const ui.Color(0xFF0F766E)),
      );
    default: // ticked circle on indigo
      c.drawRect(
        ui.Rect.fromLTWH(0, 0, s, s),
        p(const ui.Color(0xFF6C6CE8), const ui.Color(0xFF3B3BA8)),
      );
      c.drawCircle(ui.Offset(s * .5, s * .5), s * .28, p(white));
      c.drawPath(
        ui.Path()
          ..moveTo(s * .39, s * .5)
          ..lineTo(s * .475, s * .585)
          ..lineTo(s * .62, s * .42),
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = s * .065
          ..strokeCap = ui.StrokeCap.round
          ..strokeJoin = ui.StrokeJoin.round
          ..color = const ui.Color(0xFF3B3BA8),
      );
  }
}

void _checker(ui.Canvas c, ui.Rect r, double cell) {
  c.save();
  c.clipRect(r);
  c.drawRect(r, ui.Paint()..color = const ui.Color(0xFFE9E9E9));
  final dark = ui.Paint()..color = const ui.Color(0xFFD2D2D2);
  for (var y = 0; y * cell < r.height; y++) {
    for (var x = 0; x * cell < r.width; x++) {
      if ((x + y).isOdd) {
        c.drawRect(
          ui.Rect.fromLTWH(r.left + x * cell, r.top + y * cell, cell, cell),
          dark,
        );
      }
    }
  }
  c.restore();
}

void _sheet(ui.Canvas c, double w, double h) {
  const ink = ui.Color(0xFF1B1C1E);
  c.drawRect(
    ui.Rect.fromLTWH(0, 0, w, h),
    ui.Paint()..color = const ui.Color(0xFFFAF9F5),
  );
  _text(
    c,
    'Carrete: app icon candidates',
    const ui.Offset(40, 28),
    size: 38,
    bold: true,
    color: ink,
  );
  _text(
    c,
    'A (refined): cream compact, charcoal lens, vermilion dot.   B (reference, unchanged): charcoal film frame, amber glow.   Sizes are real pixels (1x).',
    const ui.Offset(40, 76),
    size: 20,
    color: const ui.Color(0xFF55595F),
  );

  const panelW = 980.0;
  const panelH = 1060.0;
  const top = 120.0;
  final panels = [
    (
      40.0,
      'Light wallpaper',
      const ui.Color(0xFFF3E9DD),
      const ui.Color(0xFFC7D5E0),
      ink,
    ),
    (
      40.0 + panelW + 40,
      'Dark wallpaper',
      const ui.Color(0xFF0F1115),
      const ui.Color(0xFF1F2A3A),
      const ui.Color(0xFFECEAE3),
    ),
  ];
  void paintFor(IconCandidate k, ui.Canvas cv, double s) =>
      CarreteIcon.paintComposite(cv, s, k);
  void paintA(ui.Canvas cv, double s) => paintFor(IconCandidate.a, cv, s);
  void paintB(ui.Canvas cv, double s) => paintFor(IconCandidate.b, cv, s);

  for (final (x0, title, c0, c1, fg) in panels) {
    final rect = ui.Rect.fromLTWH(x0, top, panelW, panelH);
    final bg = ui.Paint()
      ..shader = ui.Gradient.linear(rect.topLeft, rect.bottomRight, [c0, c1]);
    c.drawRRect(ui.RRect.fromRectXY(rect, 20, 20), bg);
    _text(
      c,
      title,
      ui.Offset(x0 + 28, top + 20),
      size: 28,
      bold: true,
      color: fg,
    );

    // Masks x sizes.
    final masks = <(String, _Mask)>[
      ('Circle', IconMasks.circle),
      ('Squircle', IconMasks.squircle),
      ('Rounded square', IconMasks.rounded),
    ];
    var y = top + 74;
    for (final (label, mask) in masks) {
      _text(
        c,
        label,
        ui.Offset(x0 + 28, y + 80),
        size: 19,
        bold: true,
        color: fg,
      );
      var x = x0 + 170;
      for (final size in [192.0, 96.0, 48.0]) {
        _icon(c, ui.Offset(x, y + (192 - size)), size, mask, paintA);
        _text(
          c,
          'A',
          ui.Offset(x + size / 2, y + 196),
          size: 17,
          color: fg,
          center: true,
        );
        x += size + 14;
        _icon(c, ui.Offset(x, y + (192 - size)), size, mask, paintB);
        _text(
          c,
          'B',
          ui.Offset(x + size / 2, y + 196),
          size: 17,
          color: fg,
          center: true,
        );
        x += size + 30;
      }
      y += 236;
    }

    // Against other icons.
    y += 4;
    _text(
      c,
      'Among other icons (squircle)',
      ui.Offset(x0 + 28, y),
      size: 22,
      bold: true,
      color: fg,
    );
    y += 38;
    final line = <(String, void Function(ui.Canvas, double))>[
      ('', (cv, s) => _placeholder(cv, s, 0)),
      ('A', paintA),
      ('', (cv, s) => _placeholder(cv, s, 1)),
      ('B', paintB),
      ('', (cv, s) => _placeholder(cv, s, 2)),
    ];
    for (final size in [96.0, 48.0]) {
      var x = x0 + 170;
      for (final (cap, paint) in line) {
        _icon(c, ui.Offset(x, y), size, IconMasks.squircle, paint);
        if (cap.isNotEmpty) {
          _text(
            c,
            cap,
            ui.Offset(x + size / 2, y + size + 4),
            size: 17,
            bold: true,
            color: fg,
            center: true,
          );
        }
        x += size + (size > 60 ? 40 : 30);
      }
      y += size + 34;
    }
  }

  // Adaptive layers.
  const ay = top + panelH + 36;
  _text(
    c,
    'Android adaptive layers (108 dp canvas; red circle = 66 dp safe zone; blue square = 72 dp always visible)',
    const ui.Offset(40, ay),
    size: 24,
    bold: true,
    color: ink,
  );
  const tile = 216.0;
  var x = 40.0;
  for (final k in IconCandidate.values) {
    final name = k == IconCandidate.a ? 'A' : 'B';
    for (final layer in IconLayer.values) {
      final r = ui.Rect.fromLTWH(x, ay + 46, tile, tile);
      if (layer == IconLayer.foreground || layer == IconLayer.monochrome) {
        _checker(c, r, 12);
      }
      c.save();
      c.clipRect(r);
      c.translate(r.left, r.top);
      CarreteIcon.paintLayer(c, tile, k, layer);
      c.restore();
      final s = tile / CarreteIcon.grid;
      final mid = r.center;
      c.drawCircle(
        mid,
        CarreteIcon.safe / 2 * s,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const ui.Color(0xFFE5442A),
      );
      c.drawRect(
        ui.Rect.fromCenter(
          center: mid,
          width: CarreteIcon.visible * s,
          height: CarreteIcon.visible * s,
        ),
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const ui.Color(0xFF3D8BFF),
      );
      _text(
        c,
        '$name ${layer.name}',
        ui.Offset(x + tile / 2, ay + 46 + tile + 4),
        size: 18,
        color: ink,
        center: true,
      );
      x += tile + 20;
    }
    x += 36;
  }
}

// ------------------------------------------------------------- install

Future<ByteData> _render(
  int w,
  int h,
  void Function(ui.Canvas) draw,
  ui.ImageByteFormat format,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, w + 0.0, h + 0.0));
  draw(canvas);
  final image = await recorder.endRecording().toImage(w, h);
  return (await image.toByteData(format: format))!;
}

Future<void> _write(
  String path,
  int size,
  void Function(ui.Canvas) draw,
) async {
  final data = await _render(size, size, draw, ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(data.buffer.asUint8List());
}

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

/// An 8-bit RGB PNG (no alpha channel at all, as the App Store asks of an
/// icon) of a fully opaque square.
List<int> _rgbPng(int size, ByteData rgba) {
  final raw = BytesBuilder();
  for (var y = 0; y < size; y++) {
    raw.addByte(0);
    for (var x = 0; x < size; x++) {
      final i = (y * size + x) * 4;
      if (rgba.getUint8(i + 3) != 255) {
        throw StateError('iOS icons must be opaque (pixel $x,$y)');
      }
      raw.addByte(rgba.getUint8(i));
      raw.addByte(rgba.getUint8(i + 1));
      raw.addByte(rgba.getUint8(i + 2));
    }
  }
  final out = BytesBuilder()
    ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  void chunk(String type, List<int> data) {
    final body = [...type.codeUnits, ...data];
    final len = ByteData(4)..setUint32(0, data.length);
    final crc = ByteData(4)..setUint32(0, _crc(body));
    out
      ..add(len.buffer.asUint8List())
      ..add(body)
      ..add(crc.buffer.asUint8List());
  }

  final head = ByteData(13)
    ..setUint32(0, size)
    ..setUint32(4, size)
    ..setUint8(8, 8)
    ..setUint8(9, 2);
  chunk('IHDR', head.buffer.asUint8List());
  chunk('IDAT', ZLibCodec(level: 9).encode(raw.toBytes()));
  chunk('IEND', const []);
  return out.toBytes();
}

void main() {
  testWidgets('render the icon candidates', (tester) async {
    await tester.runAsync(() async {
      await _loadFont('BarlowSemiCondensed', [
        'BarlowSemiCondensed-Medium.ttf',
        'BarlowSemiCondensed-Bold.ttf',
      ]);
      Directory(_out).createSync(recursive: true);

      for (final k in IconCandidate.values) {
        final n = k.name;
        // The finished icon for stores and iOS: the central 72 dp at 1024 px.
        await _png(
          'carrete-$n-1024.png',
          1024,
          1024,
          (c) => CarreteIcon.paintComposite(c, 1024, k),
        );
        // The adaptive layers: 108 dp at xxxhdpi (4x) = 432 px.
        for (final layer in IconLayer.values) {
          await _png(
            'carrete-$n-adaptive-${layer.name}.png',
            432,
            432,
            (c) => CarreteIcon.paintLayer(c, 432, k, layer),
          );
        }
      }

      const w = 2080;
      const h = 1540;
      await _png('comparison.png', w, h, (c) => _sheet(c, w + 0.0, h + 0.0));
    });
  });

  testWidgets('install candidate A as the app icon', (tester) async {
    await tester.runAsync(() async {
      const a = IconCandidate.a;
      const res = 'android/app/src/main/res';
      // Android: the adaptive layers (108 dp) and the legacy icon (48 dp).
      const densities = {
        'mdpi': 1.0,
        'hdpi': 1.5,
        'xhdpi': 2.0,
        'xxhdpi': 3.0,
        'xxxhdpi': 4.0,
      };
      for (final e in densities.entries) {
        final fg = (108 * e.value).round();
        final legacy = (48 * e.value).round();
        await _write(
          '$res/mipmap-${e.key}/ic_launcher_foreground.png',
          fg,
          (c) => CarreteIcon.paintLayer(c, fg + 0.0, a, IconLayer.foreground),
        );
        await _write(
          '$res/mipmap-${e.key}/ic_launcher_monochrome.png',
          fg,
          (c) => CarreteIcon.paintLayer(c, fg + 0.0, a, IconLayer.monochrome),
        );
        await _write('$res/mipmap-${e.key}/ic_launcher.png', legacy, (c) {
          c.clipPath(
            IconMasks.rounded(
              ui.Rect.fromLTWH(0, 0, legacy + 0.0, legacy + 0.0),
            ),
          );
          CarreteIcon.paintComposite(c, legacy + 0.0, a);
        });
      }
      // iOS: every PNG of the icon set, opaque and square, sized from its name.
      const set = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
      final name = RegExp(r'^Icon-App-([\d.]+)x[\d.]+@(\d)x\.png$');
      for (final f in Directory(set).listSync().whereType<File>()) {
        final m = name.firstMatch(f.uri.pathSegments.last);
        if (m == null) continue;
        final px = (double.parse(m[1]!) * int.parse(m[2]!)).round();
        final data = await _render(
          px,
          px,
          (c) => CarreteIcon.paintComposite(c, px + 0.0, a),
          ui.ImageByteFormat.rawRgba,
        );
        f.writeAsBytesSync(_rgbPng(px, data));
      }
    });
  });
}
