import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/develop_schedule.dart';
import '../../core/database/tables.dart';
import '../../core/l10n/localized_text.dart';
import '../../l10n/app_localizations.dart';
import '../../render/film_resources.dart';
import '../../roll/roll_providers.dart';
import '../../ui/theme/carrete_tokens.dart';
import '../../ui/widgets/carrete_icon.dart';
import '../../ui/widgets/plastic_key.dart';
import '../disposable/disposable_start_dialog.dart';
import '../viewfinder/tuning_panel.dart' show PlasticPlateSurface;
import '../viewfinder/viewfinder_state.dart';
import 'roll_parts.dart';

/// What the user asked for in the roll sheet. The camera carries it out.
sealed class RollSheetIntent {
  const RollSheetIntent();
}

/// Load a roll of [length] frames that develops [delay] after it is closed.
class LoadRollIntent extends RollSheetIntent {
  const LoadRollIntent(this.length, this.delay);
  final int length;
  final DevelopDelay delay;
}

/// Start the disposable camera: 27 photos on a locked screen, developing
/// [delay] after it is closed.
class LoadDisposableIntent extends RollSheetIntent {
  const LoadDisposableIntent(this.delay);
  final DevelopDelay delay;
}

/// Put the disposable camera that was set aside back in the camera.
class ResumeDisposableIntent extends RollSheetIntent {
  const ResumeDisposableIntent(this.rollId);
  final int rollId;
}

/// Close the roll in the camera; it develops after its delay.
class CloseRollIntent extends RollSheetIntent {
  const CloseRollIntent(this.rollId);
  final int rollId;
}

/// Close the roll in the camera and develop it right away.
class DevelopRollNowIntent extends RollSheetIntent {
  const DevelopRollNowIntent(this.rollId);
  final int rollId;
}

/// Throw the roll in the camera away.
class DiscardRollIntent extends RollSheetIntent {
  const DiscardRollIntent(this.rollId);
  final int rollId;
}

/// Open the screen of a roll from the list of recent rolls.
class OpenRollIntent extends RollSheetIntent {
  const OpenRollIntent(this.rollId);
  final int rollId;
}

/// Opens the roll sheet over the camera. Resolves to what the user chose, or
/// null when the sheet was dismissed. [loadFilm] is the film a new roll would
/// be loaded with (the one selected in the carousel).
Future<RollSheetIntent?> showRollSheet(
  BuildContext context, {
  required Recipe loadFilm,
}) {
  return showModalBottomSheet<RollSheetIntent>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (_) => CarreteCameraTheme(
      colors: CarreteCameraColors.forBrightness(Theme.of(context).brightness),
      child: RollSheet(loadFilm: loadFilm),
    ),
  );
}

/// The sheet of the camera that loads a roll, or, while one is loaded, shows
/// how many frames are left and closes, develops or throws it away.
///
/// It only decides: the camera carries out the intent it pops with.
class RollSheet extends ConsumerStatefulWidget {
  const RollSheet({required this.loadFilm, super.key});

  /// The film a new roll is loaded with.
  final Recipe loadFilm;

  @override
  ConsumerState<RollSheet> createState() => _RollSheetState();
}

class _RollSheetState extends ConsumerState<RollSheet> {
  /// The length and delay a roll is loaded with until the user chooses.
  int _length = 24;
  DevelopDelay _delay = DevelopDelay.oneHour;

  /// A paused disposable is being finished: the sheet shows how it develops
  /// instead of the two main keys.
  bool _finishing = false;

  void _done(RollSheetIntent intent) => Navigator.of(context).pop(intent);

  /// The palette of the confirmations: the light plates over a light camera,
  /// the dark plastic over the dark one.
  CarretePalette? get _confirmPalette =>
      CarreteCameraColors.of(context).brightness == Brightness.light
      ? CarretePalette.light
      : null;

  Future<void> _developNow(RollRow roll, int photos) async {
    if (await RollConfirmations.developNow(
          context,
          photos: photos,
          palette: _confirmPalette,
        ) &&
        mounted) {
      _done(DevelopRollNowIntent(roll.id));
    }
  }

  Future<void> _startDisposable() async {
    final delay = await showDisposableStart(context);
    if (delay != null && mounted) _done(LoadDisposableIntent(delay));
  }

  Future<void> _discard(RollRow roll) async {
    if (await RollConfirmations.discard(context, palette: _confirmPalette) &&
        mounted) {
      _done(DiscardRollIntent(roll.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tone = RollTone(null, camera: CarreteCameraColors.of(context));
    final roll = ref.watch(activeRollProvider).value;
    final book = ref.watch(recipeBookProvider).value;
    final screen = MediaQuery.sizeOf(context);

    final filmName = roll == null
        ? widget.loadFilm.name.of(context)
        : book?.byId(roll.filmId)?.name.of(context) ?? roll.filmId;
    final title = roll == null
        ? l10n.rollLoadTitle
        : roll.mode == RollMode.disposable
        ? l10n.disposableStartTitle
        : l10n.rollOpenTitle;

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
            label: title,
            child: PlasticPlateSurface(
              child: SingleChildScrollView(
                padding: CarreteRoll.sheetPadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(title: title),
                    const SizedBox(height: CarreteSpacing.s),
                    if (roll == null)
                      ..._loadBody(l10n, tone, filmName)
                    else
                      ..._openBody(l10n, tone, roll, filmName),
                    if (roll == null) ..._recent(l10n, tone, book),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _loadBody(AppLocalizations l10n, RollTone tone, String film) {
    return [
      Text(
        l10n.rollSheetIntro,
        key: const ValueKey('roll-sheet-intro'),
        style: tone.note,
      ),
      const SizedBox(height: CarreteSpacing.s),
      _LabelRow(
        label: l10n.rollFilmRow,
        tone: tone,
        child: Text(
          film,
          style: tone.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      _Block(
        label: l10n.rollLengthLabel,
        tone: tone,
        child: RollChoiceKeys<int>(
          selected: _length,
          onSelected: (v) => setState(() => _length = v),
          options: [
            for (final n in const [12, 24, 36])
              RollChoice(n, '$n', semanticLabel: l10n.rollFramesCount(n)),
          ],
        ),
      ),
      _Block(
        label: l10n.rollDelayLabel,
        tone: tone,
        child: RollChoiceKeys<DevelopDelay>(
          columns: 2,
          selected: _delay,
          onSelected: (v) => setState(() => _delay = v),
          options: [
            for (final d in DevelopDelay.values)
              RollChoice(d, delayName(l10n, d)),
          ],
        ),
      ),
      Text(
        l10n.rollDelayNote,
        key: const ValueKey('roll-delay-note'),
        style: tone.note,
      ),
      const SizedBox(height: CarreteSpacing.m),
      RollWideKey(
        label: l10n.rollLoadAction,
        onPressed: () => _done(LoadRollIntent(_length, _delay)),
      ),
      const SizedBox(height: CarreteSpacing.m),
      Text(l10n.rollLoadNote, style: tone.note),
      const SizedBox(height: CarreteSpacing.xs),
      Text(
        l10n.rollLossWarning,
        key: const ValueKey('roll-loss-warning'),
        style: tone.note,
      ),
      const SizedBox(height: CarreteSpacing.m),
      _SecondaryOption(
        key: const ValueKey('disposable-key'),
        title: l10n.disposableOption,
        detail: l10n.disposableOptionNote,
        tone: tone,
        onTap: _startDisposable,
      ),
    ];
  }

  List<Widget> _openBody(
    AppLocalizations l10n,
    RollTone tone,
    RollRow roll,
    String film,
  ) {
    // The frames left are known when the database has answered. Until then
    // nothing is said about them and the roll cannot be developed now: the
    // count of photos is never guessed from the capacity of the roll.
    final left = ref.watch(remainingFramesProvider).value;
    final photos = left == null ? null : roll.length - left;
    final delay = delayName(l10n, roll.developDelay).toLowerCase();
    return [
      if (left != null) ...[
        Semantics(
          container: true,
          liveRegion: true,
          child: Text(l10n.rollCounterSemantics(left), style: tone.title),
        ),
        const SizedBox(height: CarreteSpacing.xs),
      ],
      Text(l10n.rollOpenSummary(film, roll.length), style: tone.note),
      Text(l10n.rollDevelopsLine(delay), style: tone.note),
      const SizedBox(height: CarreteSpacing.xs),
      Text(
        l10n.rollLossNote,
        key: const ValueKey('roll-loss-note'),
        style: tone.note,
      ),
      const SizedBox(height: CarreteSpacing.l),
      if (roll.mode == RollMode.disposable)
        ..._pausedBody(l10n, tone, roll, photos)
      else ...[
        RollWideKey(
          label: l10n.rollCloseAction,
          onPressed: () => _done(CloseRollIntent(roll.id)),
        ),
        const SizedBox(height: CarreteSpacing.s),
        RollWideKey(
          label: l10n.rollDevelopNowAction,
          onPressed: photos == null ? null : () => _developNow(roll, photos),
        ),
        const SizedBox(height: CarreteSpacing.s),
        RollWideKey(
          label: l10n.rollDiscardAction,
          color: tone.warn,
          onPressed: () => _discard(roll),
        ),
      ],
    ];
  }

  /// A disposable that was set aside: two main keys (go back to it, finish
  /// it) and, apart, a text key to throw it away. Finishing opens one step
  /// that says how it develops: right away with an instant wait, or at the
  /// scheduled time with a choice to keep the wait or develop now.
  List<Widget> _pausedBody(
    AppLocalizations l10n,
    RollTone tone,
    RollRow roll,
    int? photos,
  ) {
    if (_finishing) return _finishBody(l10n, tone, roll, photos);
    return [
      RollWideKey(
        key: const ValueKey('disposable-resume-key'),
        label: l10n.disposableResume,
        onPressed: () => _done(ResumeDisposableIntent(roll.id)),
      ),
      const SizedBox(height: CarreteSpacing.s),
      RollWideKey(
        key: const ValueKey('disposable-finish-key'),
        label: l10n.disposableFinishAction,
        onPressed: () => setState(() => _finishing = true),
      ),
      const SizedBox(height: CarreteSpacing.s),
      Text(
        l10n.disposablePausedNote,
        key: const ValueKey('disposable-paused-note'),
        style: tone.note,
      ),
      const SizedBox(height: CarreteSpacing.m),
      _TextAction(
        key: const ValueKey('disposable-discard-key'),
        label: l10n.rollDiscardAction,
        color: tone.warn,
        onPressed: () => _discard(roll),
      ),
    ];
  }

  List<Widget> _finishBody(
    AppLocalizations l10n,
    RollTone tone,
    RollRow roll,
    int? photos,
  ) {
    final instant = roll.developDelay == DevelopDelay.instant;
    final String when;
    if (instant) {
      when = l10n.disposableFinishInstantNote;
    } else {
      final at = developAtFor(
        roll.developDelay,
        ref.watch(rollClockProvider)(),
      );
      final material = MaterialLocalizations.of(context);
      when = l10n.rollReadyOn(
        material.formatMediumDate(at),
        material.formatTimeOfDay(
          TimeOfDay.fromDateTime(at),
          alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
        ),
      );
    }
    return [
      Semantics(
        container: true,
        liveRegion: true,
        child: Text(
          when,
          key: const ValueKey('disposable-finish-when'),
          style: tone.title,
        ),
      ),
      const SizedBox(height: CarreteSpacing.xs),
      Text(l10n.disposableFinishWarning, style: tone.note),
      const SizedBox(height: CarreteSpacing.l),
      if (instant)
        RollWideKey(
          key: const ValueKey('disposable-develop-key'),
          label: l10n.rollDevelopNowAction,
          onPressed: () => _done(CloseRollIntent(roll.id)),
        )
      else ...[
        RollWideKey(
          key: const ValueKey('disposable-keep-key'),
          label: l10n.disposableFinishKeepWait,
          onPressed: () => _done(CloseRollIntent(roll.id)),
        ),
        const SizedBox(height: CarreteSpacing.s),
        RollWideKey(
          key: const ValueKey('disposable-develop-key'),
          label: l10n.rollDevelopNowAction,
          onPressed: photos == null ? null : () => _developNow(roll, photos),
        ),
      ],
      const SizedBox(height: CarreteSpacing.m),
      _TextAction(
        key: const ValueKey('disposable-finish-cancel'),
        label: l10n.dialogCancel,
        color: tone.soft,
        onPressed: () => setState(() => _finishing = false),
      ),
    ];
  }

  /// The last rolls that are waiting or developed, only when no roll is
  /// loaded (a loaded roll leaves no room for them).
  List<Widget> _recent(AppLocalizations l10n, RollTone tone, RecipeBook? book) {
    final rolls = (ref.watch(rollsListProvider).value ?? const <RollRow>[])
        .where(
          (r) =>
              r.state == RollState.developing ||
              r.state == RollState.developed ||
              r.state == RollState.lost,
        )
        .take(CarreteRoll.recentRolls)
        .toList();
    if (rolls.isEmpty) return const [];
    final now = ref.watch(rollClockProvider)();
    return [
      const SizedBox(height: CarreteSpacing.l),
      Semantics(
        header: true,
        child: Text(
          CarreteText.upper(
            l10n.rollRecentTitle,
            Localizations.localeOf(context),
          ),
          style: tone.label,
        ),
      ),
      const SizedBox(height: CarreteSpacing.xs),
      for (final roll in rolls)
        RecentRollRow(
          roll: roll,
          film: book?.byId(roll.filmId),
          now: now,
          tone: tone,
          onTap: () => _done(OpenRollIntent(roll.id)),
        ),
    ];
  }
}

/// A quiet action in plain text, for what must not compete with the main keys
/// (throwing the disposable away, leaving a step).
class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.label,
    required this.color,
    required this.onPressed,
    super.key,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: color,
          minimumSize: const Size(0, CarreteRoll.rowHeight),
          textStyle: CarreteText.row,
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}

/// The title of a sheet and the key that dismisses it.
class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: CarreteSizes.panelHeader,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: CarreteText.panelTitle.copyWith(
                  color: CarreteCameraColors.of(context).panelTitle,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          PlasticKey(
            semanticLabel: l10n.tuneClose,
            onPressed: () => Navigator.of(context).maybePop(),
            child: const CarreteIconView(icon: CarreteIcon.close),
          ),
        ],
      ),
    );
  }
}

/// An option that is not the main way to load a roll: a row under a rule, with
/// a title, a line of detail and a chevron, so it does not compete with the
/// key that loads a roll. While the finger is on it the row is tinted, like a
/// key that is pressed.
class _SecondaryOption extends StatefulWidget {
  const _SecondaryOption({
    required this.title,
    required this.detail,
    required this.tone,
    required this.onTap,
    super.key,
  });

  final String title;
  final String detail;
  final RollTone tone;
  final VoidCallback onTap;

  @override
  State<_SecondaryOption> createState() => _SecondaryOptionState();
}

class _SecondaryOptionState extends State<_SecondaryOption> {
  bool _down = false;

  void _setDown(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tone = widget.tone;
    final instant = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      container: true,
      button: true,
      label: l10n.disposableOptionSemantics(widget.title, widget.detail),
      onTap: widget.onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setDown(true),
        onTapUp: (_) => _setDown(false),
        onTapCancel: () => _setDown(false),
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 1, child: ColoredBox(color: tone.line)),
            AnimatedContainer(
              key: const ValueKey('secondary-option-surface'),
              duration: instant ? Duration.zero : CarreteDurations.keyPress,
              decoration: BoxDecoration(
                color: _down
                    ? tone.line.withValues(
                        alpha: CarreteRelief.pressedRowOpacity,
                      )
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(CarreteRadii.key),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: CarreteRoll.rowHeight,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: CarreteText.row.copyWith(color: tone.ink),
                          ),
                          const SizedBox(height: CarreteSizes.hair),
                          Text(
                            widget.detail,
                            style: CarreteText.panelSubtitle.copyWith(
                              color: tone.soft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: CarreteSpacing.m),
                    CarreteIconView(
                      icon: CarreteIcon.chevron,
                      color: tone.soft,
                      size: CarreteSizes.settingsIcon,
                    ),
                    const SizedBox(width: CarreteSpacing.xs),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabelRow extends StatelessWidget {
  const _LabelRow({
    required this.label,
    required this.tone,
    required this.child,
  });

  final String label;
  final RollTone tone;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: CarreteSizes.panelRow,
      child: Row(
        children: [
          Text(label, style: CarreteText.row.copyWith(color: tone.ink)),
          const SizedBox(width: CarreteSpacing.m),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: child),
          ),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.label, required this.tone, required this.child});

  final String label;
  final RollTone tone;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CarreteSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            child: Text(
              label,
              style: CarreteText.row.copyWith(color: tone.ink),
            ),
          ),
          const SizedBox(height: CarreteSpacing.s),
          child,
        ],
      ),
    );
  }
}

/// A roll in a list: its film and date, how many frames it has and where it
/// stands. Opens the screen of the roll.
class RecentRollRow extends ConsumerWidget {
  const RecentRollRow({
    required this.roll,
    required this.film,
    required this.now,
    required this.tone,
    required this.onTap,
    super.key,
  });

  final RollRow roll;

  /// The film of the roll when the book still has it.
  final Recipe? film;
  final DateTime now;
  final RollTone tone;
  final VoidCallback onTap;

  String _state(AppLocalizations l10n) => switch (roll.state) {
    RollState.developed => l10n.rollStateDeveloped,
    RollState.lost => l10n.rollStateLost,
    _ =>
      (roll.developAt ?? 0) > now.millisecondsSinceEpoch
          ? l10n.rollStateWaiting
          : l10n.rollStateDeveloping,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final frames =
        ref.watch(rollShotsProvider(roll.id)).value?.length ?? roll.length;
    final when = DateTime.fromMillisecondsSinceEpoch(
      roll.developedAt ?? roll.closedAt ?? roll.createdAt,
    );
    final date = MaterialLocalizations.of(context).formatShortDate(when);
    final name = film?.name.of(context) ?? roll.filmId;
    final state = _state(l10n);
    final count = l10n.rollFramesCount(frames);
    return Semantics(
      container: true,
      button: true,
      label: l10n.rollRowSemantics(name, count, state, date),
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: tone.line)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: CarreteRoll.rowHeight),
            child: Row(
              children: [
                if (film != null) ...[
                  SizedBox.square(
                    dimension: CarreteRoll.swatch,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: filmBandColor(film!),
                        borderRadius: BorderRadius.circular(CarreteRadii.band),
                      ),
                    ),
                  ),
                  const SizedBox(width: CarreteSpacing.m),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: CarreteText.row.copyWith(color: tone.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: CarreteSizes.hair),
                      Text(
                        l10n.rollRowSubtitle(date, count),
                        style: CarreteText.panelSubtitle.copyWith(
                          color: tone.soft,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: CarreteSpacing.m),
                Text(
                  state,
                  style: CarreteText.value.copyWith(color: tone.active),
                ),
                const SizedBox(width: CarreteSpacing.xs),
                CarreteIconView(
                  icon: CarreteIcon.chevron,
                  color: tone.soft,
                  size: CarreteSizes.settingsIcon,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
