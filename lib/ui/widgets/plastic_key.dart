import 'package:flutter/material.dart';

import '../theme/carrete_tokens.dart';
import 'plastic_surface.dart';

/// A raised plastic key. When [selected] it looks sunken and its content takes
/// the amber of an active control, like a pressed key of a 90s compact. It
/// moves down only while the finger is on it, so a row of keys keeps one line.
///
/// The touch target is never smaller than 44 x 44 logical pixels.
class PlasticKey extends StatefulWidget {
  const PlasticKey({
    required this.semanticLabel,
    required this.onPressed,
    required this.child,
    this.selected,
    this.width = CarreteSpacing.minTouch,
    this.height = CarreteSpacing.minTouch,
    this.semanticHint,
    this.palette,
    super.key,
  });

  /// What a screen reader says.
  final String semanticLabel;

  /// An extra hint for screen readers.
  final String? semanticHint;

  /// Called on a tap. Null disables the key.
  final VoidCallback? onPressed;

  /// The content: an icon or a short text.
  final Widget child;

  /// Whether the key is on. Null for a key that is not a toggle.
  final bool? selected;

  /// The width of the key (at least 44).
  final double width;

  /// The height of the key (at least 44).
  final double height;

  /// The colours of the key on a screen that follows the theme of the system.
  /// Null for the plastic of the camera ([CarreteCameraColors.of]).
  final CarretePalette? palette;

  @override
  State<PlasticKey> createState() => _PlasticKeyState();
}

class _PlasticKeyState extends State<PlasticKey> {
  bool _down = false;

  void _setDown(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.selected ?? false;
    final sunken = on || _down;
    final enabled = widget.onPressed != null;
    final instant = MediaQuery.disableAnimationsOf(context);
    final palette = widget.palette;
    final camera = CarreteCameraColors.of(context);
    final color = palette == null
        ? (on ? camera.active : camera.ink)
        : (on ? palette.accent : palette.ink);

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      hint: widget.semanticHint,
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _setDown(true) : null,
        onTapUp: enabled ? (_) => _setDown(false) : null,
        onTapCancel: enabled ? () => _setDown(false) : null,
        onTap: widget.onPressed,
        child: SizedBox(
          width: widget.width < CarreteSpacing.minTouch
              ? CarreteSpacing.minTouch
              : widget.width,
          height: widget.height < CarreteSpacing.minTouch
              ? CarreteSpacing.minTouch
              : widget.height,
          child: AnimatedSlide(
            duration: instant ? Duration.zero : CarreteDurations.keyPress,
            // Only the finger moves the key: a selected key looks sunken
            // but stays level with its neighbours.
            offset: _down ? const Offset(0, CarreteSizes.keySink) : Offset.zero,
            child: CustomPaint(
              painter: palette == null
                  ? PlasticSurfacePainter(
                      radius: CarreteRadii.key,
                      pressed: sunken,
                      top: camera.keyTop,
                      bottom: camera.keyBottom,
                      pressedTop: camera.keyPressedTop,
                      pressedBottom: camera.keyPressedBottom,
                      hardShadow: camera.hard,
                      diffuseShadow: camera.diffuse,
                      highlight: camera.highlight,
                      pressedEdge: camera.pressedEdge,
                      innerShadow: camera.innerShadow,
                    )
                  : PlasticSurfacePainter(
                      radius: CarreteRadii.key,
                      pressed: sunken,
                      top: palette.keyTop,
                      bottom: palette.keyBottom,
                      pressedTop: palette.keyPressedTop,
                      pressedBottom: palette.keyPressedBottom,
                      hardShadow: BoxShadow(
                        color: palette.keyHardShadow,
                        offset: CarreteRelief.hard.offset,
                      ),
                      diffuseShadow: null,
                      highlight: palette.keyHighlight,
                    ),
              child: Center(
                child: IconTheme(
                  data: IconThemeData(color: color),
                  child: DefaultTextStyle(
                    style: CarreteText.key.copyWith(color: color),
                    child: Opacity(
                      opacity: enabled ? 1 : CarreteRelief.disabledOpacity,
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
