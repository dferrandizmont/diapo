/// The deterministic chart the golden tests render.
///
/// The chart holds everything a look can change: a grey ramp, the red, green
/// and blue ramps, the cyan, magenta and yellow ramps, a few skin tones and a
/// bright spot on a dark background, which is what the halation picks up.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// The width of the chart, in pixels.
const int kTestChartWidth = 240;

/// The height of the chart, in pixels.
const int kTestChartHeight = 160;

/// Builds the chart as RGBA bytes.
Uint8List buildTestChart({
  int width = kTestChartWidth,
  int height = kTestChartHeight,
}) {
  final out = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final index = (y * width + x) * 4;
      _chartPixel(x, y, width, height, out, index);
      out[index + 3] = 255;
    }
  }
  return out;
}

/// The name of the golden image of the recipe [recipeId] at [intensity].
String goldenFileName(String recipeId, double intensity) =>
    '${recipeId}_${intensity.toStringAsFixed(1)}.png';

/// Writes the colour of the pixel at ([x], [y]) of the chart.
void _chartPixel(
  int x,
  int y,
  int width,
  int height,
  Uint8List out,
  int index,
) {
  final band = y * 4 ~/ height;

  switch (band) {
    // A grey ramp of eight steps.
    case 0:
      final step = x * 8 ~/ width;
      final value = (step * 255 / 7).round();
      out[index] = value;
      out[index + 1] = value;
      out[index + 2] = value;
    // The red, green and blue ramps.
    case 1:
      final third = x * 3 ~/ width;
      final value = ((x - third * width ~/ 3) * 255 / (width ~/ 3)).round();
      out[index] = third == 0 ? value : 0;
      out[index + 1] = third == 1 ? value : 0;
      out[index + 2] = third == 2 ? value : 0;
    // The cyan, magenta and yellow ramps.
    case 2:
      final third = x * 3 ~/ width;
      final value = ((x - third * width ~/ 3) * 255 / (width ~/ 3)).round();
      out[index] = third == 0 ? 0 : value;
      out[index + 1] = third == 1 ? 0 : value;
      out[index + 2] = third == 2 ? 0 : value;
    // Three skin tones and a bright spot on a dark background.
    default:
      final patch = x * 6 ~/ width;
      if (patch < 3) {
        const skin = <List<int>>[
          <int>[240, 202, 172],
          <int>[214, 170, 134],
          <int>[176, 132, 98],
        ];
        final colour = skin[patch];
        out[index] = colour[0];
        out[index + 1] = colour[1];
        out[index + 2] = colour[2];
      } else {
        // The spot sits in the middle of the last patch.
        final centreX = (width * 4.5 / 6).floor();
        final centreY = (height * 7 / 8).floor();
        final dx = x - centreX;
        final dy = y - centreY;
        final distance = math.sqrt(dx * dx + dy * dy);
        const radius = 10.0;
        const soft = 4.0;
        final mix = ((radius + soft - distance) / soft).clamp(0.0, 1.0);
        final value = (24 + (255 - 24) * mix).round();
        out[index] = value;
        out[index + 1] = value;
        out[index + 2] = value;
      }
  }
}
