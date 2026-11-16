/// Regenerates the golden images of every recipe.
///
/// Run it from the package root:
///
/// ```sh
/// dart run tool/update_goldens.dart
/// ```
///
/// It writes `test/goldens/<id>_<intensity>.png` for every recipe at full
/// strength and at half strength, plus `test/goldens/hashes.json` with the
/// SHA-256 of the raw RGBA bytes of each image.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:image/image.dart' as img;

/// The intensities every recipe is rendered at.
const List<double> kGoldenIntensities = <double>[1, 0.5];

Future<void> main(List<String> args) async {
  final root = _packageRoot();
  final source = File(
    '${root.path}${Platform.pathSeparator}assets${Platform.pathSeparator}recipes.json',
  );
  final book = RecipeBook.parse(source.readAsStringSync());

  final goldens = Directory(
    '${root.path}${Platform.pathSeparator}test${Platform.pathSeparator}goldens',
  );
  if (!goldens.existsSync()) {
    goldens.createSync(recursive: true);
  }

  final chart = buildTestChart();
  final hashes = <String, String>{};

  for (final recipe in book.recipes) {
    for (final intensity in kGoldenIntensities) {
      final look = resolve(recipe, intensity: intensity);
      final rgba = renderReference(
        chart,
        kTestChartWidth,
        kTestChartHeight,
        look,
      );
      final name = goldenFileName(recipe.id, intensity);
      File(
        '${goldens.path}${Platform.pathSeparator}$name',
      ).writeAsBytesSync(_encodePng(rgba, kTestChartWidth, kTestChartHeight));
      final hash = sha256.convert(rgba).toString();
      hashes[name] = hash;
      stdout.writeln('$name $hash');
    }
  }

  File('${goldens.path}${Platform.pathSeparator}hashes.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(hashes)}\n',
  );
  stdout.writeln('${hashes.length} golden images written to ${goldens.path}');
}

/// The root of the package, found from the location of this script.
Directory _packageRoot() {
  var directory = File.fromUri(Platform.script).parent;
  while (!File('${directory.path}${Platform.pathSeparator}pubspec.yaml')
      .existsSync()) {
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('pubspec.yaml not found above ${directory.path}');
    }
    directory = parent;
  }
  return directory;
}

/// Encodes RGBA bytes as a PNG image.
Uint8List _encodePng(Uint8List rgba, int width, int height) {
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgba.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return img.encodePng(image);
}
