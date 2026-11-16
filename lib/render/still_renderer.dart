import 'dart:typed_data';
import 'dart:ui' as ui;

import 'film_uniforms.dart';

/// Timings of one still, in milliseconds.
class StillTimings {
  StillTimings();
  int decode = 0;
  int render = 0;
  int readback = 0;
  int width = 0;
  int height = 0;

  Map<String, Object> toJson() => {
    'decodeMs': decode,
    'renderMs': render,
    'readbackMs': readback,
    'w': width,
    'h': height,
  };
}

/// Renders a captured JPEG through the film shader at full resolution and
/// returns straight RGBA pixels.
class StillRenderer {
  StillRenderer(this.program);

  final ui.FragmentProgram program;

  Future<(Uint8List, StillTimings)> render(
    Uint8List jpeg,
    FilmLook look,
    ui.Image curve, {
    double seed = 0.37,
  }) async {
    final t = StillTimings();
    final sw = Stopwatch()..start();

    final codec = await ui.instantiateImageCodec(jpeg);
    final frame = await codec.getNextFrame();
    final photo = frame.image;
    codec.dispose();
    t.decode = sw.elapsedMilliseconds;
    t.width = photo.width;
    t.height = photo.height;

    sw.reset();
    final size = ui.Size(photo.width.toDouble(), photo.height.toDouble());
    final shader = program.fragmentShader();
    applyFilmUniforms(shader, look, filterMode: false, seed: seed, size: size);
    shader.setImageSampler(0, photo);
    shader.setImageSampler(1, curve);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(ui.Offset.zero & size, ui.Paint()..shader = shader);
    final picture = recorder.endRecording();
    final out = await picture.toImage(photo.width, photo.height);
    picture.dispose();
    t.render = sw.elapsedMilliseconds;

    sw.reset();
    final bytes = await out.toByteData(format: ui.ImageByteFormat.rawRgba);
    out.dispose();
    photo.dispose();
    shader.dispose();
    t.readback = sw.elapsedMilliseconds;

    return (bytes!.buffer.asUint8List(), t);
  }
}
