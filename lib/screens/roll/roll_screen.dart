import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../capture/error_log.dart';
import '../../core/database/app_database.dart';
import '../../core/database/tables.dart';
import '../../core/l10n/localized_text.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/camera_sounds.dart';
import '../../platform/gallery_images.dart';
import '../../platform/haptics.dart';
import '../../render/film_resources.dart';
import '../../review/review_service.dart';
import '../../roll/contact_sheet_share.dart';
import '../../roll/roll_providers.dart';
import '../../roll/roll_reveal.dart';
import '../../ui/theme/carrete_tokens.dart';
import 'contact_sheet.dart';
import 'contact_sheet_share.dart';
import 'develop_view.dart';
import 'roll_name_dialog.dart';
import 'roll_parts.dart';

/// The screen of a roll, in the style of proposal A on a screen that follows
/// the theme of the app. What it shows depends on where the roll stands:
///
/// * waiting for its time: when it will be ready, with "develop now";
/// * being developed: the progress, on an LCD and a strip of frames;
/// * developed: the contact sheet, from which each photo opens full size;
/// * lost, thrown away or missing: a short message.
class RollScreen extends ConsumerStatefulWidget {
  const RollScreen({super.key, required this.id});

  /// The id of the roll.
  final String id;

  @override
  ConsumerState<RollScreen> createState() => _RollScreenState();
}

class _RollScreenState extends ConsumerState<RollScreen>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    ref.invalidate(galleryImagesProvider);
  }

  Timer? _ready;
  int? _readyFor;

  /// Brings the frames of a developed roll in, one after another, the first
  /// time it is opened.
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: CarreteDurations.reveal,
  );

  /// The roll whose reveal was already decided on this screen.
  int? _revealFor;

  /// The reveal is running: the frames come in and a tap skips it.
  bool _revealing = false;

  /// The user watched this roll being developed on this screen: its frames
  /// already came in one by one, so there is nothing left to reveal.
  bool _watchedDeveloping = false;

  /// The user asked to develop now and the developer has not reported yet.
  bool _requested = false;
  bool _failed = false;
  bool _kicked = false;

  @override
  void dispose() {
    _ready?.cancel();
    _reveal.dispose();
    super.dispose();
  }

  /// Decides, once per roll, whether the roll is revealed now. The first time
  /// a developed roll is on screen it is remembered as seen, one quiet sound
  /// and a light tap tell that it is ready, and its frames come in (unless the
  /// user asked for no motion, or watched them being developed).
  ///
  /// Only the decision runs while building, so the first frame already hides
  /// the frames that are about to come in. What has effects (the memory, the
  /// sound, the tap and the animation) waits for the end of the frame.
  void _decideReveal(int rollId) {
    if (_revealFor == rollId) return;
    _revealFor = rollId;
    final store = ref.read(rollRevealStoreProvider);
    if (store.seen(rollId)) return;
    final media = MediaQuery.of(context);
    final animate =
        !_watchedDeveloping &&
        !media.disableAnimations &&
        !media.accessibleNavigation;
    _revealing = animate;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(store.markSeen(rollId).catchError((Object _) {}));
      _revealFeedback();
      if (!animate || !_revealing) {
        // Nothing to wait for: the frames are already there.
        _askForReview();
        return;
      }
      unawaited(
        _reveal.forward(from: 0).whenComplete(() {
          if (!mounted) return;
          setState(() => _revealing = false);
          _askForReview();
        }),
      );
    });
  }

  /// A success moment: the first reveal of a developed roll is over (it ran to
  /// its end, was skipped, or had none to run). One call that never blocks and
  /// swallows every error; the policy decides whether the store is asked.
  void _askForReview() {
    unawaited(ref.read(reviewServiceProvider).maybeAskAfterSuccess());
  }

  /// One soft click and a light tap, once, when the roll is ready: nothing per
  /// frame. A feedback that cannot be played never breaks the screen.
  void _revealFeedback() {
    try {
      unawaited(
        ref
            .read(cameraSoundsProvider)
            .playCartridge()
            .catchError((Object _) {}),
      );
      unawaited(
        ref.read(hapticsProvider).lightImpact().catchError((Object _) {}),
      );
    } on Object catch (error) {
      if (kDebugMode) debugPrint('Reveal feedback failed: $error');
    }
  }

  /// A tap during the reveal shows every frame at once.
  void _skipReveal() {
    _reveal.stop();
    setState(() => _revealing = false);
    _askForReview();
  }

  int? get _rollId => int.tryParse(widget.id);

  /// Rebuilds when the waiting roll is due, and asks the developer to start:
  /// nothing else does while the user watches this screen.
  void _watchDue(RollRow roll) {
    final dueAt = roll.developAt;
    if (roll.state != RollState.developing || dueAt == null) return;
    final now = ref.read(rollClockProvider)();
    final wait = dueAt - now.millisecondsSinceEpoch;
    if (wait <= 0) {
      if (!_kicked) {
        _kicked = true;
        scheduleMicrotask(() {
          if (mounted) unawaited(ref.read(rollForegroundProvider).run());
        });
      }
      return;
    }
    if (_readyFor == dueAt) return;
    _readyFor = dueAt;
    _ready?.cancel();
    _ready = Timer(Duration(milliseconds: wait), () {
      if (mounted) setState(() {});
    });
  }

  Future<void> _developNow(RollRow roll) async {
    final palette = CarretePalette.of(context);
    // The photos of the roll: asked for by the screen only once they are
    // known, so the confirmation never guesses the count.
    final photos = ref.read(rollShotsProvider(roll.id)).value?.length;
    if (photos == null) return;
    if (!await RollConfirmations.developNow(
      context,
      photos: photos,
      palette: palette,
    )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _requested = true;
      _failed = false;
    });
    unawaited(
      ref
          .read(rollServiceProvider)
          .developNow(roll.id)
          .then<void>(
            (_) {},
            onError: (Object error) {
              if (kDebugMode) debugPrint('Developing failed: $error');
              if (mounted) {
                setState(() {
                  _requested = false;
                  _failed = true;
                });
              }
            },
          ),
    );
  }

  Future<void> _discard(RollRow roll) async {
    final palette = CarretePalette.of(context);
    if (!await RollConfirmations.discard(context, palette: palette)) return;
    if (!mounted) return;
    try {
      await ref.read(rollServiceProvider).discardRoll(roll.id);
    } on Object catch (error) {
      if (kDebugMode) debugPrint('Discarding failed: $error');
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = CarretePalette.of(context);
    final id = _rollId;
    final selected = id == null
        ? const AsyncData<RollRow?>(null)
        : ref.watch(rollProvider(id));
    final roll = selected.value;

    final String fallbackTitle = id == null
        ? l10n.rollTitle
        : rollFallbackName(l10n, id);
    final String title = roll?.name ?? fallbackTitle;
    String? subtitle;
    final List<Widget> body;
    if (roll == null) {
      body = [
        if (selected.hasValue)
          RollMessage(title: l10n.rollMissingTitle, palette: palette),
      ];
    } else {
      _watchDue(roll);
      subtitle = _subtitle(context, roll, fallbackTitle);
      body = _body(context, roll, palette);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: palette.brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: palette.background,
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: CarreteRoll.bodyMaxWidth,
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  CarreteSpacing.margin,
                  CarreteSpacing.s,
                  CarreteSpacing.margin,
                  CarreteSpacing.xxl,
                ),
                children: [
                  RollHeader(
                    title: title,
                    subtitle: subtitle,
                    palette: palette,
                    handwritten: roll?.name != null,
                    // A thrown-away roll has nothing left to name.
                    onEdit: roll == null || roll.state == RollState.discarded
                        ? null
                        : () => unawaited(_rename(roll)),
                  ),
                  const SizedBox(height: CarreteSpacing.l),
                  ...body,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Asks for the name of the roll and stores it. An empty name clears it.
  Future<void> _rename(RollRow roll) async {
    final palette = CarretePalette.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final name = await showRollNameDialog(
      context,
      rollId: roll.id,
      current: roll.name,
      palette: palette,
    );
    if (name == null || !mounted) return;
    try {
      await ref.read(rollServiceProvider).renameRoll(roll.id, name);
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('Naming the roll failed: ${errorLogToken(error)}');
      }
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: palette.plate,
          content: Text(
            l10n.rollActionFailed,
            style: CarreteText.note(palette.ink),
          ),
        ),
      );
    }
  }

  /// The film, the frames and, once developed, the day. A roll with a name
  /// of its own keeps its number in front, so it can still be told apart.
  String? _subtitle(BuildContext context, RollRow roll, String fallbackTitle) {
    final l10n = AppLocalizations.of(context);
    final book = ref.watch(recipeBookProvider).value;
    final film = book?.byId(roll.filmId)?.name.of(context) ?? roll.filmId;
    final shots = ref.watch(rollShotsProvider(roll.id)).value;
    final frames = roll.state == RollState.open ? roll.length : shots?.length;
    final parts = <String>[
      if (roll.name != null) fallbackTitle,
      film,
      if (frames != null) l10n.rollFramesCount(frames),
      if (roll.state == RollState.developed && roll.developedAt != null)
        l10n.rollDevelopedOn(
          MaterialLocalizations.of(context).formatShortDate(
            DateTime.fromMillisecondsSinceEpoch(roll.developedAt!),
          ),
        ),
    ];
    return parts.join(' · ');
  }

  List<Widget> _body(
    BuildContext context,
    RollRow roll,
    CarretePalette palette,
  ) {
    final l10n = AppLocalizations.of(context);
    switch (roll.state) {
      case RollState.open:
        return [RollMessage(title: l10n.rollStillOpenTitle, palette: palette)];
      case RollState.discarded:
        return [RollMessage(title: l10n.rollDiscardedTitle, palette: palette)];
      case RollState.lost:
        return [
          RollMessage(
            title: l10n.rollLostTitle,
            body: l10n.rollLostBody,
            palette: palette,
          ),
        ];
      case RollState.developed:
        final shots = ref.watch(rollShotsProvider(roll.id)).value;
        if (shots == null) return const [];
        _decideReveal(roll.id);
        return [
          // Only a developed roll with a photo to put on it has the action.
          if (hasSharableFrames(shots)) ...[
            RollWideKey(
              key: const ValueKey('share-sheet-key'),
              palette: palette,
              label: l10n.rollShareSheetAction,
              onPressed: () => unawaited(
                showContactSheetShare(context, roll: roll, shots: shots),
              ),
            ),
            const SizedBox(height: CarreteSpacing.m),
          ],
          Stack(
            children: [
              ContactSheet(shots: shots, reveal: _revealing ? _reveal : null),
              // While the frames come in a tap anywhere skips it, and the
              // frames do not react.
              if (_revealing)
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: GestureDetector(
                      key: const ValueKey('reveal-skip'),
                      behavior: HitTestBehavior.opaque,
                      onTap: _skipReveal,
                    ),
                  ),
                ),
            ],
          ),
        ];
      case RollState.developing:
        final progress = ref.watch(rollDevelopProgressProvider(roll.id)).value;
        final shots = ref.watch(rollShotsProvider(roll.id)).value;
        final total = progress?.total ?? shots?.length ?? roll.length;
        final now = ref.read(rollClockProvider)();
        final due = (roll.developAt ?? 0) <= now.millisecondsSinceEpoch;
        if (progress != null || due || _requested) {
          _watchedDeveloping = true;
          return [
            RollDevelopingView(
              done: progress?.done ?? 0,
              total: total,
              palette: palette,
              shots: shots,
            ),
          ];
        }
        return [
          RollWaitingView(
            frames: total,
            readyAt: DateTime.fromMillisecondsSinceEpoch(roll.developAt!),
            palette: palette,
            failed: _failed,
            // Not before the photos are known: the confirmation says how many
            // are developed.
            onDevelopNow: shots == null
                ? null
                : () => unawaited(_developNow(roll)),
            onDiscard: () => unawaited(_discard(roll)),
          ),
        ];
    }
  }
}
