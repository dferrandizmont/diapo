import 'dart:ui' as ui;

import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../render/film_resources.dart';
import '../../render/look_adjust.dart';

/// Draws [child] (the camera texture) through the film shader of one film.
///
/// The shader runs as an image filter, so it sees the whole child as its input
/// and uses the size of the child as the size of the frame: grain, vignette and
/// light leak are relative to it. Without GPU support for shader filters, or
/// before the resources are loaded, the child is shown as it is.
class FilmShaderView extends StatefulWidget {
  const FilmShaderView({
    required this.resources,
    required this.filmId,
    required this.look,
    required this.child,
    this.seed,
    this.cameraTexture = true,
    super.key,
  });

  /// The shader and the curves, or null when they are not there (yet).
  final FilmResources? resources;

  /// The film, to pick its tone curve.
  final String filmId;

  /// The look to apply.
  final ResolvedLook look;

  /// The grain seed. A notifier lets the grain change every frame without
  /// rebuilding the child; null keeps the grain still.
  final ValueListenable<double>? seed;

  /// Whether [child] is a camera texture (the default). The shader turns a
  /// camera texture upright on Impeller's OpenGL ES backend by flipping it; a
  /// photo shown through an `Image` is already upright and must pass false.
  final bool cameraTexture;

  /// The unfiltered picture.
  final Widget child;

  /// Whether this device can run a fragment shader as an image filter.
  static bool get supported => ui.ImageFilter.isShaderFilterSupported;

  @override
  State<FilmShaderView> createState() => _FilmShaderViewState();
}

class _FilmShaderViewState extends State<FilmShaderView> {
  ui.FragmentShader? _shader;
  ui.Image? _curveOf;

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  /// The shader of this view, with the curve of the current film bound.
  ui.FragmentShader? _shaderFor(FilmResources? resources) {
    if (resources == null) return null;
    final curve = resources.curves[widget.filmId];
    if (curve == null) return null;
    var shader = _shader;
    if (shader == null) {
      shader = resources.program.fragmentShader();
      _shader = shader;
      _curveOf = null;
    }
    if (!identical(_curveOf, curve)) {
      shader.setImageSampler(1, curve);
      _curveOf = curve;
    }
    return shader;
  }

  Widget _filtered(double seed) {
    final shader = _shaderFor(widget.resources);
    if (shader == null) return widget.child;
    applyResolvedLook(
      shader,
      widget.look,
      filterMode: true,
      seed: seed,
      cameraTexture: widget.cameraTexture,
    );
    return ImageFiltered(
      imageFilter: ui.ImageFilter.shader(shader),
      child: widget.child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!FilmShaderView.supported || widget.resources == null) {
      return widget.child;
    }
    final seed = widget.seed;
    if (seed == null) return _filtered(0.37);
    return ValueListenableBuilder<double>(
      valueListenable: seed,
      builder: (context, value, _) => _filtered(value),
    );
  }
}
