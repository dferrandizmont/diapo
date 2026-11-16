import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../capture/save_status.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme/carrete_tokens.dart';
import '../roll/roll_parts.dart';
import 'tuning_panel.dart' show PlasticPlateSurface;

/// What the camera says about the photos it is putting away, quietly, over the
/// picture:
///
/// - while photos are being saved, "Saving 2 photos" with a tiny progress
///   mark. It shows only after [CarreteSaveStatus.showDelay], so a single fast
///   save never flickers;
/// - while photos could not be saved and wait, a chip that stays until they
///   are saved. Tapping it opens [SaveRecoverySheet].
///
/// It draws nothing, and takes no touches, when there is nothing to say. It
/// never shows a photo: only counts and words.
class SaveStatusStrip extends ConsumerStatefulWidget {
  const SaveStatusStrip({this.onOpenRecovery, super.key});

  /// Called when the chip is tapped. Opens the recovery sheet by default.
  final VoidCallback? onOpenRecovery;

  @override
  ConsumerState<SaveStatusStrip> createState() => _SaveStatusStripState();
}

class _SaveStatusStripState extends ConsumerState<SaveStatusStrip> {
  Timer? _delay;

  /// Whether the saving has lasted long enough to be said.
  bool _saidSaving = false;

  @override
  void initState() {
    super.initState();
    if (ref.read(saveStatusProvider).isSaving) _startDelay();
  }

  @override
  void dispose() {
    _delay?.cancel();
    super.dispose();
  }

  void _startDelay() {
    _delay?.cancel();
    _delay = Timer(CarreteSaveStatus.showDelay, () {
      if (mounted) setState(() => _saidSaving = true);
    });
  }

  void _saving(bool saving) {
    if (saving) {
      if (!_saidSaving && !(_delay?.isActive ?? false)) _startDelay();
    } else {
      _delay?.cancel();
      if (_saidSaving) setState(() => _saidSaving = false);
    }
  }

  void _openRecovery() {
    final callback = widget.onOpenRecovery;
    if (callback != null) {
      callback();
    } else {
      unawaited(showSaveRecoverySheet(context));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(saveStatusProvider.select((s) => s.isSaving), (_, saving) {
      _saving(saving);
    });
    final status = ref.watch(saveStatusProvider);
    final l10n = AppLocalizations.of(context);
    final reduced = MediaQuery.disableAnimationsOf(context);

    final Widget child;
    if (status.isSaving && _saidSaving) {
      child = _SavingPill(
        key: const ValueKey('save-status-saving'),
        text: l10n.saveStatusSaving(status.savingCount),
        reduced: reduced,
      );
    } else if (status.hasFailures) {
      child = _PendingChip(
        key: const ValueKey('save-status-pending'),
        text: l10n.saveStatusPending,
        onTap: _openRecovery,
      );
    } else {
      child = const SizedBox.shrink(key: ValueKey('save-status-none'));
    }
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: math.min(
          CarreteSaveStatus.maxWidth,
          MediaQuery.sizeOf(context).width - 2 * CarreteSpacing.margin,
        ),
      ),
      child: AnimatedSwitcher(
        duration: reduced ? Duration.zero : CarreteSaveStatus.fade,
        // Whatever is going out must not catch a tap.
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.centerLeft,
          children: [
            for (final old in previous) IgnorePointer(child: old),
            ?current,
          ],
        ),
        child: child,
      ),
    );
  }
}

/// The pill that says photos are being saved, with a tiny progress mark. With
/// reduced motion the mark does not turn.
class _SavingPill extends StatelessWidget {
  const _SavingPill({required this.text, required this.reduced, super.key});

  final String text;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: text,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CarreteColors.notice,
          borderRadius: BorderRadius.circular(CarreteRadii.key),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CarreteSizes.pillInsetH,
            vertical: CarreteSizes.pillInsetV,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: CarreteSaveStatus.mark,
                child: CircularProgressIndicator(
                  key: const ValueKey('save-status-mark'),
                  // A still arc says the same without moving.
                  value: reduced ? 0.7 : null,
                  strokeWidth: CarreteSaveStatus.markStroke,
                  color: CarreteColors.white,
                  backgroundColor: CarreteColors.white.withValues(alpha: 0.25),
                ),
              ),
              const SizedBox(width: CarreteSaveStatus.gap),
              Flexible(child: Text(text, style: CarreteText.notice)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The persistent chip of photos that wait to be saved. The pill is small; the
/// target around it is at least [CarreteSpacing.minTouch] tall.
class _PendingChip extends StatelessWidget {
  const _PendingChip({required this.text, required this.onTap, super.key});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: text,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: CarreteSpacing.minTouch),
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: CarreteColors.notice,
                borderRadius: BorderRadius.circular(CarreteRadii.key),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CarreteSizes.pillInsetH,
                  vertical: CarreteSizes.pillInsetV,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecoratedBox(
                      decoration: const BoxDecoration(
                        color: CarreteSaveStatus.warn,
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox.square(
                        dimension: CarreteSaveStatus.dot,
                      ),
                    ),
                    const SizedBox(width: CarreteSaveStatus.gap),
                    Flexible(child: Text(text, style: CarreteText.notice)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the sheet that explains the photos waiting to be saved.
Future<void> showSaveRecoverySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (_) => CarreteCameraTheme(
      colors: CarreteCameraColors.forBrightness(Theme.of(context).brightness),
      child: const SaveRecoverySheet(),
    ),
  );
}

/// What happened to the photos that wait, in plain words, with "Try again"
/// and "Later". Retrying hands the photos back to the queue and closes the
/// sheet; the camera then says they are being saved.
class SaveRecoverySheet extends ConsumerWidget {
  const SaveRecoverySheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = CarreteCameraColors.of(context);
    final tone = RollTone(null, camera: colors);
    final status = ref.watch(saveStatusProvider);
    final screen = MediaQuery.sizeOf(context);
    final why = switch (status.problem) {
      SaveProblem.storageFull => l10n.saveSheetStorageFull,
      SaveProblem.permission => l10n.saveSheetPermission,
      SaveProblem.unknown => l10n.saveSheetUnknown,
    };
    // Nothing to retry while a retry or a save is under way.
    final canRetry = status.failed > 0 && !status.isSaving;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CarreteSizes.panelMargin,
        0,
        CarreteSizes.panelMargin,
        CarreteSizes.panelMargin,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: CarreteRoll.sheetMaxWidth,
            maxHeight: screen.height,
          ),
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            scopesRoute: true,
            namesRoute: true,
            label: l10n.saveSheetTitle,
            child: PlasticPlateSurface(
              child: SingleChildScrollView(
                padding: CarreteRoll.sheetPadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.saveSheetTitle,
                        style: CarreteText.panelTitle.copyWith(
                          color: colors.panelTitle,
                        ),
                      ),
                    ),
                    const SizedBox(height: CarreteSpacing.s),
                    if (status.failed > 0) ...[
                      Text(
                        l10n.saveSheetCount(status.failed),
                        key: const ValueKey('save-sheet-count'),
                        style: tone.row,
                      ),
                      const SizedBox(height: CarreteSpacing.xs),
                    ],
                    Text(
                      why,
                      key: const ValueKey('save-sheet-reason'),
                      style: tone.note,
                    ),
                    const SizedBox(height: CarreteSpacing.xs),
                    Text(
                      l10n.saveSheetKept,
                      key: const ValueKey('save-sheet-kept'),
                      style: tone.note,
                    ),
                    const SizedBox(height: CarreteSpacing.m),
                    RollWideKey(
                      key: const ValueKey('save-sheet-retry'),
                      label: l10n.saveSheetRetry,
                      color: colors.active,
                      onPressed: canRetry
                          ? () {
                              // Taken before the sheet closes and its ref goes.
                              final controller = ref.read(
                                saveStatusProvider.notifier,
                              );
                              Navigator.of(context).pop();
                              unawaited(controller.retry());
                            }
                          : null,
                    ),
                    const SizedBox(height: CarreteSpacing.s),
                    RollWideKey(
                      key: const ValueKey('save-sheet-later'),
                      label: l10n.saveSheetLater,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
