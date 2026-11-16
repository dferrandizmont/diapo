import 'dart:typed_data';
import 'dart:ui' as ui;

/// A PNG of [width] x [height]: a diagonal gradient from [from] to [to] with a
/// light frame line and a circle, so a fitted or cropped photo can be told
/// apart. With [solid] it is one flat [from]. Needs `tester.runAsync` in a
/// widget test.
Future<Uint8List> syntheticPhoto(
  int width,
  int height, {
  required ui.Color from,
  ui.Color? to,
  bool solid = false,
}) async {
  final recorder = ui.PictureRecorder();
  final box = ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
  final canvas = ui.Canvas(recorder, box);
  final fill = ui.Paint()..color = from;
  if (!solid) {
    fill.shader = ui.Gradient.linear(box.topLeft, box.bottomRight, [
      from,
      to ?? from,
    ]);
  }
  canvas.drawRect(box, fill);
  if (!solid) {
    final line = ui.Paint()
      ..color = const ui.Color(0xCCFFFFFF)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = (width / 40).clamp(2, 12).toDouble();
    canvas.drawRect(box.deflate(width / 12), line);
    canvas.drawCircle(box.center, height / 6, line);
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}
