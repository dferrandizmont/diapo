/// Renders every recipe over a set of sample photos into one comparison
/// sheet, with the CPU port of the shader. Used to tune recipes against real
/// photos without installing the app.
///
/// ```sh
/// dart run tool/film_sheet.dart <out.jpg> <photo> [<photo> ...] [--width=480] [--only=id1,id2]
/// ```
///
/// Rows are photos; the first column is the original, then one column per
/// recipe at full strength. The sample photos stay outside the repository.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:film_recipes/film_recipes.dart';
import 'package:image/image.dart' as img;

Future<void> main(List<String> args) async {
  final flags = {
    for (final a in args.where((a) => a.startsWith('--')))
      a.substring(2).split('=').first: a.contains('=') ? a.split('=').last : '',
  };
  final paths = args.where((a) => !a.startsWith('--')).toList();
  if (paths.length < 2) {
    stderr.writeln(
      'usage: dart run tool/film_sheet.dart <out.jpg> <photo>... [--width=480] [--only=a,b]',
    );
    exit(64);
  }
  final out = paths.first;
  final photos = paths.skip(1).toList();
  final width = int.tryParse(flags['width'] ?? '') ?? 480;
  final only = flags['only']?.split(',').where((s) => s.isNotEmpty).toSet();

  final book = RecipeBook.parse(File('assets/recipes.json').readAsStringSync());
  final recipes = book.recipes
      .where((r) => only == null || only.isEmpty || only.contains(r.id))
      .toList();

  const gap = 8;
  const label = 22;
  final tiles = <List<img.Image>>[];
  for (final path in photos) {
    final decoded = img.decodeImage(File(path).readAsBytesSync());
    if (decoded == null) {
      stderr.writeln('cannot decode $path');
      continue;
    }
    final source = img.bakeOrientation(decoded);
    final scaled = img.copyResize(
      source,
      width: width,
      interpolation: img.Interpolation.average,
    );
    final rgba = Uint8List.fromList(
      scaled.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba),
    );
    final row = <img.Image>[scaled];
    for (final recipe in recipes) {
      final look = resolve(recipe);
      final pixels = renderReference(rgba, scaled.width, scaled.height, look);
      row.add(
        img.Image.fromBytes(
          width: scaled.width,
          height: scaled.height,
          bytes: pixels.buffer,
          numChannels: 4,
          order: img.ChannelOrder.rgba,
        ),
      );
    }
    tiles.add(row);
    stdout.writeln('rendered $path');
  }
  if (tiles.isEmpty) exit(1);

  final cols = recipes.length + 1;
  final rowHeights = tiles.map((r) => r.first.height).toList();
  final sheet = img.Image(
    width: cols * width + (cols + 1) * gap,
    height: label + rowHeights.fold<int>(0, (a, b) => a + b + gap) + gap,
  );
  img.fill(sheet, color: img.ColorRgb8(24, 24, 26));
  final names = ['original', ...recipes.map((r) => r.id)];
  for (var c = 0; c < cols; c++) {
    img.drawString(
      sheet,
      names[c],
      font: img.arial14,
      x: gap + c * (width + gap),
      y: 4,
      color: img.ColorRgb8(230, 230, 230),
    );
  }
  var y = label;
  for (var r = 0; r < tiles.length; r++) {
    for (var c = 0; c < cols; c++) {
      img.compositeImage(
        sheet,
        tiles[r][c],
        dstX: gap + c * (width + gap),
        dstY: y,
      );
    }
    y += rowHeights[r] + gap;
  }
  File(out).writeAsBytesSync(img.encodeJpg(sheet, quality: 88));
  stdout.writeln('wrote $out (${sheet.width}x${sheet.height})');
}
