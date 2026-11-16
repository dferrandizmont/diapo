import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/settings/settings_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme/carrete_tokens.dart';
import '../../ui/theme/onboarding_tokens.dart';
import '../../ui/widgets/carrete_icon.dart';
import '../../ui/widgets/plastic_controls.dart';
import '../../ui/widgets/plastic_key.dart';
import '../../ui/widgets/seven_segment.dart';
import 'onboarding_art.dart';

/// The first-use flow: three screens (the camera, the film, the roll) shown
/// once before the camera, and again from the settings.
///
/// It looks like part of the camera: the picture lives in a black viewfinder,
/// an LCD counts the screens and the red shutter is the "next" button. It can
/// be skipped at any moment. It never asks for a permission: the camera does
/// that when it opens.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pages = PageController();
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: CarreteDurations.shutterFlash,
  );
  int _index = 0;
  bool _finished = false;

  bool get _isLast => _index == OnboardingSizes.steps - 1;

  @override
  void dispose() {
    _pages.dispose();
    _flash.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(page);
    } else {
      _pages.animateToPage(
        page,
        duration: OnboardingMotion.page,
        curve: OnboardingMotion.pageCurve,
      );
    }
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    if (!MediaQuery.disableAnimationsOf(context)) _flash.forward(from: 0);
    _goTo(_index + 1);
  }

  void _previous() {
    if (_index > 0) _goTo(_index - 1);
  }

  /// Marks the flow as seen and leaves it: back to the settings when it was
  /// opened from there, to the camera otherwise.
  void _finish() {
    if (_finished) return;
    _finished = true;
    ref.read(settingsProvider.notifier).setOnboardingSeen(true);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.camera);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        canPop: _index == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _previous();
        },
        child: Scaffold(
          backgroundColor: CarreteColors.viewfinder,
          body: Stack(
            children: [
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: OnboardingSizes.contentMaxWidth,
                    ),
                    child: Column(
                      children: [
                        _TopBar(
                          index: _index,
                          onSkip: _finish,
                          onBack: _index > 0 ? _previous : null,
                        ),
                        Expanded(
                          child: PageView(
                            controller: _pages,
                            onPageChanged: (page) =>
                                setState(() => _index = page),
                            children: const [
                              _Page(step: 0),
                              _Page(step: 1),
                              _Page(step: 2),
                            ],
                          ),
                        ),
                        _BottomBar(
                          index: _index,
                          label: _isLast
                              ? l10n.onboardingStart
                              : l10n.onboardingNext,
                          onNext: _next,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _flash,
                  builder: (context, _) {
                    final fading = _flash.isAnimating;
                    return ColoredBox(
                      color: fading
                          ? CarreteColors.white.withValues(
                              alpha:
                                  CarreteMotion.flashPeak * (1 - _flash.value),
                            )
                          : Colors.transparent,
                      child: const SizedBox.expand(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The skip key, the back key (from the second screen on) and the LCD that
/// counts the screens.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.index,
    required this.onSkip,
    required this.onBack,
  });

  final int index;
  final VoidCallback onSkip;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CarreteSpacing.margin,
        CarreteSpacing.s,
        CarreteSpacing.margin,
        CarreteSpacing.s,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The keys keep the text at the size the user chose: the skip key
          // grows with it, and the row wraps instead of shrinking the text.
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scale = MediaQuery.textScalerOf(context).scale(1);
                final skipWidth = (OnboardingSizes.skipKeyWidth * scale).clamp(
                  OnboardingSizes.skipKeyWidth,
                  constraints.maxWidth,
                );
                return Wrap(
                  spacing: CarreteSpacing.s,
                  runSpacing: CarreteSpacing.s,
                  children: [
                    PlasticKey(
                      semanticLabel: l10n.onboardingSkip,
                      width: skipWidth,
                      onPressed: onSkip,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: CarreteSpacing.s,
                        ),
                        child: Text(
                          CarreteText.upper(l10n.onboardingSkip, locale),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (onBack != null)
                      PlasticKey(
                        semanticLabel: MaterialLocalizations.of(context)
                            .backButtonTooltip,
                        onPressed: onBack,
                        child: const CarreteIconView(icon: CarreteIcon.back),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: CarreteSpacing.s),
          Semantics(
            liveRegion: true,
            label: l10n.onboardingStepSemantics(
              index + 1,
              OnboardingSizes.steps,
            ),
            excludeSemantics: true,
            child: LcdWindow(
              width: CarreteSizes.lcdWidth,
              height: OnboardingSizes.stepLcdHeight,
              child: SevenSegmentText(
                text: '${index + 1}-${OnboardingSizes.steps}',
                height: OnboardingSizes.stepDigits,
                color: CarreteColors.lcdInk,
                ghost: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One screen: the picture in its viewfinder window, the title and the text.
/// It scrolls when the text is large.
class _Page extends StatelessWidget {
  const _Page({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (title, body, art, artLabel) = switch (step) {
      0 => (
        l10n.onboardingTitle1,
        l10n.onboardingBody1,
        const OnboardingCameraArt(),
        l10n.onboardingArtCamera,
      ),
      1 => (
        l10n.onboardingTitle2,
        l10n.onboardingBody2,
        const _Scaled(child: OnboardingFilmArt()),
        l10n.onboardingArtFilm,
      ),
      _ => (
        l10n.onboardingTitle3,
        l10n.onboardingBody3,
        const _Scaled(child: OnboardingRollArt()),
        l10n.onboardingArtRoll,
      ),
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = (constraints.maxHeight * OnboardingSizes.windowShare)
            .clamp(
              OnboardingSizes.windowMinHeight,
              OnboardingSizes.windowMaxHeight,
            );
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            CarreteSpacing.margin,
            CarreteSpacing.xs,
            CarreteSpacing.margin,
            CarreteSpacing.l,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: height,
                child: Semantics(
                  container: true,
                  image: true,
                  label: artLabel,
                  excludeSemantics: true,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: OnboardingColors.window,
                      borderRadius: BorderRadius.circular(
                        OnboardingSizes.windowRadius,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        OnboardingSizes.windowRadius,
                      ),
                      child: IgnorePointer(child: art),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: OnboardingSizes.windowGap),
              Semantics(
                header: true,
                container: true,
                child: Text(title, style: OnboardingText.title),
              ),
              const SizedBox(height: OnboardingSizes.titleGap),
              Text(body, style: OnboardingText.body),
            ],
          ),
        );
      },
    );
  }
}

/// Draws a picture of a fixed size scaled down to the window, at the text
/// scale of the design: the picture is an illustration, its words are read
/// out in the description of the window.
class _Scaled extends StatelessWidget {
  const _Scaled({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withNoTextScaling(
      child: Center(
        child: FittedBox(fit: BoxFit.scaleDown, child: child),
      ),
    );
  }
}

/// The progress cells and the label on the left, the shutter on the right.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.index,
    required this.label,
    required this.onNext,
  });

  final int index;
  final String label;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OnboardingSizes.bottomInsetLeft,
        CarreteSpacing.s,
        CarreteSpacing.xl,
        OnboardingSizes.bottomPadding,
      ),
      child: Row(
        children: [
          Expanded(
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < OnboardingSizes.steps; i++) ...[
                        if (i > 0)
                          const SizedBox(width: OnboardingSizes.stepCellGap),
                        _StepCell(on: i == index),
                      ],
                    ],
                  ),
                  const SizedBox(height: CarreteSpacing.m),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          CarreteText.upper(label, locale),
                          style: OnboardingText.shutterLabel,
                        ),
                      ),
                      const SizedBox(width: CarreteSpacing.s),
                      const CarreteIconView(
                        icon: CarreteIcon.chevron,
                        color: CarreteColors.amber,
                        size: OnboardingSizes.labelIcon,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: CarreteSpacing.l),
          ShutterButton(semanticLabel: label, onPressed: onNext),
        ],
      ),
    );
  }
}

/// A frame of the progress: lit when it is the current screen.
class _StepCell extends StatelessWidget {
  const _StepCell({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final color = on ? CarreteColors.amber : OnboardingColors.stepOff;
    return SizedBox(
      width: OnboardingSizes.stepCellWidth,
      height: OnboardingSizes.stepCellHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: on ? color : null,
          borderRadius: BorderRadius.circular(OnboardingSizes.stepCellRadius),
          border: Border.all(
            color: color,
            width: OnboardingSizes.stepCellBorder,
          ),
        ),
      ),
    );
  }
}
