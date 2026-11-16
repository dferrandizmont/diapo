import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:path_provider/path_provider.dart';

import '../platform/media_store.dart';
import '../render/film_uniforms.dart';
import '../render/poc_looks.dart';
import '../render/still_renderer.dart';

const _bench = bool.fromEnvironment('CARRETE_BENCH');

/// Proof of concept: live film shader on the camera preview and
/// full-resolution save with the same shader. With
/// `--dart-define=CARRETE_BENCH=true` it runs a scripted benchmark and logs
/// `CARRETE_PERF` lines (read them with `adb logcat -s flutter`).
class PocScreen extends StatefulWidget {
  const PocScreen({super.key});

  @override
  State<PocScreen> createState() => _PocScreenState();
}

class _PocScreenState extends State<PocScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _stress = createTicker((_) {
    if (mounted) setState(() => _seed = (_seed + 0.137) % 97.0);
  });
  CameraController? _controller;
  ui.FragmentProgram? _program;
  ui.FragmentShader? _shader;
  ui.Image? _curve;
  StillRenderer? _renderer;
  final FilmLook _look = pocWarmNegative();

  bool _shaderOn = true;
  bool _animateGrain = true;
  double _seed = 0;
  Timer? _grainTimer;
  Timer? _fpsTimer;
  String _status = 'starting';
  String _fpsText = '';
  bool _busy = false;

  final List<FrameTiming> _timings = [];
  final List<FrameTiming> _liveTimings = [];
  void _timingsCallback(List<FrameTiming> t) {
    _timings.addAll(t);
    _liveTimings.addAll(t);
  }

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_timingsCallback);
    _init();
  }

  Future<void> _init() async {
    _program = await ui.FragmentProgram.fromAsset('shaders/film.frag');
    _shader = _program!.fragmentShader();
    _curve = await curveImage(_look.curve!);
    _shader!.setImageSampler(1, _curve!);
    _renderer = StillRenderer(_program!);
    await _openCamera(ResolutionPreset.max);
    _setGrainAnimation(_animateGrain);
    _fpsTimer?.cancel();
    _fpsTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateFpsText(),
    );
    if (_bench) unawaited(_runBenchmark());
  }

  Future<void> _openCamera(ResolutionPreset preset) async {
    final old = _controller;
    setState(() => _controller = null);
    await old?.dispose();
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      if (mounted) setState(() => _status = 'no camera');
      return;
    }
    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      back,
      preset,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await controller.initialize();
    if (!mounted) return;
    setState(() {
      _controller = controller;
      _status =
          'preset ${preset.name} preview ${controller.value.previewSize?.width.toInt()}x${controller.value.previewSize?.height.toInt()}';
    });
    _log({
      'event': 'camera',
      'preset': preset.name,
      'preview':
          '${controller.value.previewSize?.width.toInt()}x${controller.value.previewSize?.height.toInt()}',
    });
  }

  void _setGrainAnimation(bool on) {
    _grainTimer?.cancel();
    _animateGrain = on;
    if (on) {
      // Film grain changes every frame of a 24 fps projection.
      _grainTimer = Timer.periodic(const Duration(milliseconds: 42), (_) {
        if (mounted) setState(() => _seed = (_seed + 0.137) % 97.0);
      });
    }
  }

  void _updateFpsText() {
    if (!mounted) return;
    final s = _summarise(List.of(_liveTimings), 1);
    _liveTimings.clear();
    setState(
      () => _fpsText = '${s['fps']} fps  raster p90 ${s['rasterP90']} ms',
    );
  }

  List<FrameTiming> _takeTimings() {
    final out = List<FrameTiming>.of(_timings);
    _timings.clear();
    return out;
  }

  Map<String, Object> _summarise(List<FrameTiming> t, double seconds) {
    if (t.isEmpty) return {'frames': 0, 'fps': 0};
    List<double> ms(Duration Function(FrameTiming) f) =>
        t.map((e) => f(e).inMicroseconds / 1000).toList()..sort();
    double p(List<double> v, double q) => v[((v.length - 1) * q).round()];
    final raster = ms((e) => e.rasterDuration);
    final build = ms((e) => e.buildDuration);
    final slow = raster.where((v) => v > 33.3).length;
    return {
      'frames': t.length,
      'fps': (t.length / seconds).toStringAsFixed(1),
      'rasterP50': p(raster, 0.5).toStringAsFixed(1),
      'rasterP90': p(raster, 0.9).toStringAsFixed(1),
      'rasterP99': p(raster, 0.99).toStringAsFixed(1),
      'rasterMax': raster.last.toStringAsFixed(1),
      'buildP90': p(build, 0.9).toStringAsFixed(1),
      'over33ms': slow,
    };
  }

  void _log(Map<String, Object?> data) {
    final line = 'CARRETE_PERF ${jsonEncode(data)}';
    debugPrint(line);
    // Some vendors drop app logs from logcat: keep a copy in the app's
    // external files dir (adb pull /sdcard/Android/data/<id>/files/perf.log).
    // Only the benchmark builds write it.
    if (!_bench) return;
    unawaited(() async {
      final dir = Platform.isIOS
          ? await getApplicationSupportDirectory()
          : await getExternalStorageDirectory();
      if (dir == null) return;
      await File('${dir.path}/perf.log').writeAsString(
        '${DateTime.now().toIso8601String()} $line\n',
        mode: FileMode.append,
      );
    }());
  }

  Future<void> _phase(
    String name, {
    required bool shader,
    required bool grain,
    bool everyVsync = false,
  }) async {
    setState(() => _shaderOn = shader);
    _setGrainAnimation(grain && !everyVsync);
    // Stress mode: a new frame on every display refresh, independent of the
    // camera frame rate, to measure how much frame rate the shader allows.
    if (everyVsync) {
      _stress.start();
    } else if (_stress.isActive) {
      _stress.stop();
    }
    await Future<void>.delayed(const Duration(seconds: 2));
    _takeTimings();
    const seconds = 10;
    await Future<void>.delayed(const Duration(seconds: seconds));
    _log({'phase': name, ..._summarise(_takeTimings(), seconds.toDouble())});
  }

  Future<void> _runBenchmark() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    await _phase('max_noShader', shader: false, grain: false);
    await _phase('max_shaderStaticGrain', shader: true, grain: false);
    await _phase('max_shaderAnimatedGrain', shader: true, grain: true);
    await _phase(
      'max_noShaderEveryVsync',
      shader: false,
      grain: false,
      everyVsync: true,
    );
    await _phase(
      'max_shaderEveryVsync',
      shader: true,
      grain: true,
      everyVsync: true,
    );
    await _phase('max_shaderAnimatedGrain', shader: true, grain: true);
    for (var i = 0; i < 3; i++) {
      await _capture();
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    await _openCamera(ResolutionPreset.veryHigh);
    await _phase('1080_shaderAnimatedGrain', shader: true, grain: true);
    await _openCamera(ResolutionPreset.high);
    await _phase('720_shaderAnimatedGrain', shader: true, grain: true);
    await _openCamera(ResolutionPreset.max);
    _log({'event': 'bench_done'});
    setState(() => _status = 'benchmark done');
  }

  Future<void> _capture() async {
    final controller = _controller;
    final renderer = _renderer;
    if (controller == null || renderer == null || _busy) return;
    setState(() => _busy = true);
    final total = Stopwatch()..start();
    try {
      final file = await controller.takePicture();
      final captureMs = total.elapsedMilliseconds;
      final read = Stopwatch()..start();
      final jpeg = await File(file.path).readAsBytes();
      final readMs = read.elapsedMilliseconds;
      final (rgba, t) = await renderer.render(jpeg, _look, _curve!);
      final now = DateTime.now();
      final name =
          'CARRETE_${now.toIso8601String().replaceAll(RegExp(r'[^0-9]'), '').substring(0, 14)}';
      final native = await MediaStore.saveRgbaAsJpeg(
        rgba: rgba,
        width: t.width,
        height: t.height,
        displayName: name,
        sourcePath: file.path,
      );
      unawaited(File(file.path).delete());
      final data = {
        'event': 'capture',
        'captureMs': captureMs,
        'readMs': readMs,
        ...t.toJson(),
        ...native,
        'totalMs': total.elapsedMilliseconds,
        'afterShutterMs': total.elapsedMilliseconds - captureMs,
      };
      _log(data);
      if (mounted) {
        setState(
          () => _status =
              '${t.width}x${t.height} saved in ${total.elapsedMilliseconds} ms',
        );
      }
    } catch (e, st) {
      _log({
        'event': 'capture_error',
        'error': '$e',
        'stack': '$st'.split('\n').take(6).join(' | '),
      });
      if (mounted) setState(() => _status = 'error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_timingsCallback);
    _grainTimer?.cancel();
    _fpsTimer?.cancel();
    _stress.dispose();
    _controller?.dispose();
    _shader?.dispose();
    super.dispose();
  }

  Widget _preview(CameraController controller) {
    final size = controller.value.previewSize!;
    // previewSize is reported in sensor (landscape) orientation.
    Widget preview = FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: size.height,
        height: size.width,
        child: CameraPreview(controller),
      ),
    );
    final shader = _shader;
    if (_shaderOn && shader != null && ui.ImageFilter.isShaderFilterSupported) {
      applyFilmUniforms(shader, _look, filterMode: true, seed: _seed);
      preview = ImageFiltered(
        imageFilter: ui.ImageFilter.shader(shader),
        child: preview,
      );
    }
    return ClipRect(child: preview);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null && controller.value.isInitialized)
            _preview(controller),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '$_fpsText\n$_status\nimpeller filter: ${ui.ImageFilter.isShaderFilterSupported}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _shaderOn = !_shaderOn),
                      child: Text(_shaderOn ? 'film on' : 'film off'),
                    ),
                    GestureDetector(
                      onTap: _capture,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _busy ? Colors.grey : Colors.white,
                          border: Border.all(color: Colors.white54, width: 4),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _setGrainAnimation(!_animateGrain),
                      child: Text(_animateGrain ? 'grain anim' : 'grain still'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Keeps `kProfileMode` referenced so profile-only logging stays obvious.
const bool pocProfile = kProfileMode;
