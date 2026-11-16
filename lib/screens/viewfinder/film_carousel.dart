import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/widgets.dart';

import '../../core/l10n/localized_text.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme/carrete_tokens.dart';
import '../../ui/widgets/plastic_controls.dart';
import 'viewfinder_state.dart';

/// The carousel of film cartridges under the viewfinder.
///
/// It lists every recipe of the book, so adding a film to the JSON adds a
/// cartridge. A tap selects a film, a long press opens its fine tuning.
///
/// Every window shows the camera through its film shader, so a long list must
/// not run them all at once: only the cartridges on screen, plus
/// [liveMargin] on each side, build their live picture; the rest show a plain
/// dark window until they scroll near.
class FilmCarousel extends StatefulWidget {
  const FilmCarousel({
    required this.recipes,
    required this.selectedId,
    required this.onSelected,
    required this.onTune,
    required this.thumbnailBuilder,
    this.locked = false,
    this.onSettled,
    super.key,
  });

  /// Called once each time a cartridge settles: after a tap, when the chosen
  /// cartridge has come to its place, and after a swipe, when the list stops.
  /// Never called while the list is still moving.
  final VoidCallback? onSettled;

  /// Whether the film cannot be changed (a roll is loaded): only the selected
  /// cartridge answers, and the others are dimmed.
  final bool locked;

  /// The films, in the order of the book.
  final List<Recipe> recipes;

  /// The id of the selected film.
  final String selectedId;

  /// Called with the film that was tapped.
  final ValueChanged<Recipe> onSelected;

  /// Called with the film that was long pressed.
  final ValueChanged<Recipe> onTune;

  /// Builds the live picture inside the window of a cartridge.
  final Widget Function(BuildContext context, Recipe recipe) thumbnailBuilder;

  /// How many cartridges beyond each edge of the screen keep a live picture,
  /// so a film scrolling in already has its picture.
  static const int liveMargin = 1;

  @override
  State<FilmCarousel> createState() => _FilmCarouselState();
}

class _FilmCarouselState extends State<FilmCarousel> {
  static const double _step =
      CarreteSizes.cartridgeWidth + CarreteSizes.cartridgeGap;

  final ScrollController _controller = ScrollController();

  /// The first and the last index that show a live picture. Until the list is
  /// laid out, the first few cartridges (what fits on a phone) are live.
  final ValueNotifier<(int, int)> _live = ValueNotifier<(int, int)>((0, 6));

  /// Where a swipe started, or null while the finger has not moved the list.
  double? _swipeStart;

  /// Whether a pointer is currently down on the list. An interrupted tap's
  /// animation may finish before the drag's ScrollStartNotification arrives,
  /// so this guards its settle.
  bool _pointerDown = false;

  /// The film the user tapped, until the camera has chosen it. Only a film
  /// that was chosen by a tap settles with a click: when the camera changes
  /// the film itself (a roll that ends gives the choice back) nothing clicks.
  String? _tapped;

  /// Which move of a tap is the last one: an earlier move that was cut short
  /// by a newer tap ends too, but it did not settle anything.
  int _move = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateLive);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centre(animate: false);
      _updateLive();
    });
  }

  void _updateLive() {
    if (!mounted || !_controller.hasClients) return;
    final position = _controller.position;
    if (!position.hasViewportDimension) return;
    final first = ((position.pixels - CarreteSpacing.margin) / _step).floor();
    final last =
        ((position.pixels +
                    position.viewportDimension -
                    CarreteSpacing.margin) /
                _step)
            .floor();
    _live.value = (
      first - FilmCarousel.liveMargin,
      last + FilmCarousel.liveMargin,
    );
  }

  @override
  void didUpdateWidget(FilmCarousel old) {
    super.didUpdateWidget(old);
    if (old.selectedId != widget.selectedId) {
      final byTap = _tapped == widget.selectedId;
      _tapped = null;
      _centre(animate: true, settle: byTap);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_updateLive);
    _controller.dispose();
    _live.dispose();
    super.dispose();
  }

  void _centre({required bool animate, bool settle = false}) {
    if (!mounted || !_controller.hasClients) return;
    final index = widget.recipes.indexWhere((r) => r.id == widget.selectedId);
    if (index < 0) return;
    const step = _step;
    final viewport = _controller.position.viewportDimension;
    final target =
        (CarreteSpacing.margin +
                index * step +
                CarreteSizes.cartridgeWidth / 2 -
                viewport / 2)
            .clamp(0.0, _controller.position.maxScrollExtent);
    if (animate && !MediaQuery.disableAnimationsOf(context)) {
      // A tap during the move starts another one and ends the first: only the
      // move that is still the last when it ends settles a cartridge.
      final move = ++_move;
      _controller
          .animateTo(
            target,
            duration: CarreteDurations.carousel,
            curve: Curves.easeOut,
          )
          .then<void>((_) {
            // Only the move that is still the last one, and only once the list
            // has really come to rest (a drag that interrupted it does not
            // count), may settle a cartridge. A finger on the list also cancels
            // it: the drag's own ScrollStartNotification can arrive after the
            // interrupted animation has already finished.
            if (mounted &&
                settle &&
                move == _move &&
                !_pointerDown &&
                !(_controller.hasClients &&
                    _controller.position.isScrollingNotifier.value)) {
              widget.onSettled?.call();
            }
          });
    } else {
      _move++;
      _controller.jumpTo(target);
      if (settle) widget.onSettled?.call();
    }
  }

  /// A swipe that moved the list settles it when it stops. A move of the list
  /// that no finger made (the cartridge chosen by a tap) is not a swipe.
  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _swipeStart = notification.metrics.pixels;
      // A drag that starts while a tap is still centring the list cancels that
      // pending move: its onSettled must not fire while the finger moves.
      _move++;
    } else if (notification is ScrollEndNotification) {
      final start = _swipeStart;
      _swipeStart = null;
      if (start != null &&
          (notification.metrics.pixels - start).abs() > _step / 2) {
        widget.onSettled?.call();
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      container: true,
      label: l10n.filmCarouselLabel,
      child: SizedBox(
        height: CarreteSizes.carouselHeight,
        // The size of the viewport or of the list can change without a scroll
        // (rotation, a window resize, a longer book): the metrics notification
        // tells the live range to follow.
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: (_) {
            _updateLive();
            return false;
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: Listener(
              onPointerDown: (_) => _pointerDown = true,
              onPointerUp: (_) => _pointerDown = false,
              onPointerCancel: (_) => _pointerDown = false,
              child: ListView.separated(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                padding: const EdgeInsets.only(
                  left: CarreteSpacing.margin,
                  right: CarreteSpacing.margin,
                  top: CarreteSpacing.s,
                ),
                itemCount: widget.recipes.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: CarreteSizes.cartridgeGap),
                itemBuilder: (context, index) {
                  final recipe = widget.recipes[index];
                  final selected = recipe.id == widget.selectedId;
                  return FilmCartridge(
                    name: recipe.name.of(context),
                    band: filmBandColor(recipe),
                    selected: selected,
                    locked: widget.locked && !selected,
                    onTap: () {
                      _tapped = recipe.id;
                      widget.onSelected(recipe);
                    },
                    onLongPress: () => widget.onTune(recipe),
                    thumbnail: ValueListenableBuilder<(int, int)>(
                      valueListenable: _live,
                      builder: (context, live, _) =>
                          index >= live.$1 && index <= live.$2
                          ? widget.thumbnailBuilder(context, recipe)
                          : const ColoredBox(color: CarreteColors.deep),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One film cartridge: a live window, a colour band and the name of the film.
class FilmCartridge extends StatelessWidget {
  const FilmCartridge({
    required this.name,
    required this.band,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.thumbnail,
    this.locked = false,
    super.key,
  });

  /// Whether the cartridge cannot be chosen now (a roll of another film is
  /// loaded). It is dimmed and ignores taps.
  final bool locked;

  /// The name of the film.
  final String name;

  /// The colour of the band under the window.
  final Color band;

  /// Whether this film is the selected one.
  final bool selected;

  /// A tap: select.
  final VoidCallback onTap;

  /// A long press: fine tuning.
  final VoidCallback onLongPress;

  /// The live picture.
  final Widget thumbnail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final instant = MediaQuery.disableAnimationsOf(context);
    final colors = CarreteCameraColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      enabled: !locked,
      label: name,
      hint: locked ? l10n.rollFilmLocked : l10n.filmCartridgeHint,
      onTap: locked ? null : onTap,
      onLongPress: locked ? null : onLongPress,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: locked ? null : onTap,
        onLongPress: locked ? null : onLongPress,
        child: Opacity(
          opacity: locked ? CarreteRelief.disabledOpacity : 1,
          child: AnimatedSlide(
            duration: instant ? Duration.zero : CarreteDurations.keyPress,
            offset: selected
                ? const Offset(
                    0,
                    -CarreteSizes.cartridgeLift / CarreteSizes.cartridgeHeight,
                  )
                : Offset.zero,
            child: SizedBox(
              width: CarreteSizes.cartridgeWidth,
              height: CarreteSizes.cartridgeHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: PlasticPlate(
                      radius: CarreteRadii.cartridge,
                      selected: selected,
                      child: const SizedBox.expand(),
                    ),
                  ),
                  if (selected)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            CarreteRadii.cartridge,
                          ),
                          border: Border.all(
                            color: colors.active,
                            width: CarreteSizes.cartridgeBorder,
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      CarreteSpacing.xs,
                      CarreteSpacing.xs,
                      CarreteSpacing.xs,
                      CarreteSizes.hair,
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: CarreteSizes.thumbnailHeight,
                          width: double.infinity,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              CarreteRadii.thumbnail,
                            ),
                            child: thumbnail,
                          ),
                        ),
                        const SizedBox(height: CarreteSizes.hair),
                        SizedBox(
                          height: CarreteSizes.bandHeight,
                          width: double.infinity,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: band,
                              borderRadius: BorderRadius.circular(
                                CarreteRadii.band,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: CarreteSizes.hair),
                        Expanded(
                          child: _CartridgeName(
                            name: name,
                            style: selected
                                ? CarreteText.cartridgeSelected.copyWith(
                                    color: colors.cartridgeSelectedInk,
                                  )
                                : CarreteText.cartridge.copyWith(
                                    color: colors.inkSoft,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The film name on a cartridge: up to two lines, never broken inside a
/// word. When the longest word is wider than the cartridge (long names, large
/// system text), the text shrinks just enough for that word to fit.
class _CartridgeName extends StatelessWidget {
  const _CartridgeName({required this.name, required this.style});

  final String name;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final direction = Directionality.of(context);
        var widest = 0.0;
        for (final word in name.split(RegExp(r'\s+'))) {
          final painter = TextPainter(
            text: TextSpan(text: word, style: style),
            textDirection: direction,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          if (painter.width > widest) widest = painter.width;
          painter.dispose();
        }
        final fit = widest > constraints.maxWidth && widest > 0
            ? constraints.maxWidth / widest
            : 1.0;
        final size = (style.fontSize ?? 14) * fit;
        return Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: style.copyWith(fontSize: size),
        );
      },
    );
  }
}
