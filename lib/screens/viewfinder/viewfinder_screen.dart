import 'dart:async';
import 'dart:math' as math;

import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../camera/camera_flash.dart';
import '../../camera/camera_providers.dart';
import '../../camera/camera_service.dart';
import '../../camera/frame_geometry.dart';
import '../../capture/capture_providers.dart';
import '../../capture/capture_queue.dart';
import '../../capture/cinema_bands.dart';
import '../../capture/date_stamp.dart';
import '../../capture/film_capture_processor.dart';
import '../../core/database/app_database.dart';
import '../../core/database/tables.dart';
import '../../core/l10n/localized_text.dart';
import '../../core/router.dart';
import '../../capture/loose_photo_tracker.dart';
import '../../core/settings/first_minute.dart';
import '../../core/settings/film_tuning.dart';
import '../../core/settings/film_tuning_provider.dart';
import '../../location/location_provider.dart';
import '../../core/settings/settings_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/camera_sounds.dart';
import '../../platform/haptics.dart';
import '../../platform/system_settings.dart';
import '../../render/film_resources.dart';
import '../../roll/disposable.dart';
import '../../roll/roll_service.dart';
import '../roll/roll_mode.dart';
import '../roll/roll_sheet.dart';
import '../../ui/theme/carrete_tokens.dart';
import '../../ui/widgets/carrete_icon.dart';
import '../../ui/widgets/plastic_controls.dart';
import '../../ui/widgets/plastic_key.dart';
import 'film_carousel.dart';
import 'first_minute_cards.dart';
import 'film_shader_view.dart';
import 'frame_overlays.dart';
import 'level_overlay.dart';
import 'save_status_chip.dart';
import 'top_bar.dart';
import 'tuning_panel.dart';
import 'viewfinder_state.dart';

/// The camera: a live preview through the selected film, the controls of a
/// plastic 90s compact around it and a carousel of films underneath.
class ViewfinderScreen extends ConsumerStatefulWidget {
  const ViewfinderScreen({
    this.onOpenSettings,
    this.onOpenRoll,
    this.onOpenGallery,
    super.key,
  });

  /// Called by the settings key. Opens the settings screen when null.
  final VoidCallback? onOpenSettings;

  /// Called with the id of a roll to show: a roll that closed, or one chosen
  /// in the roll sheet. Opens the screen of the roll when null.
  final ValueChanged<int>? onOpenRoll;

  /// Called by the gallery key. Opens the gallery when null.
  final VoidCallback? onOpenGallery;

  @override
  ConsumerState<ViewfinderScreen> createState() => _ViewfinderScreenState();
}

class _ViewfinderScreenState extends ConsumerState<ViewfinderScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  /// The film advance: 0.6 s. The flash of the shutter is its first half.
  late final AnimationController _shot = AnimationController(
    vsync: this,
    duration: CarreteDurations.filmAdvance,
  );
  final ValueNotifier<double> _grainSeed = ValueNotifier<double>(0.37);

  /// The film rewinding in the LCD after the last frame of a roll.
  late final AnimationController _rewind = AnimationController(
    vsync: this,
    duration: CarreteDurations.rewind,
  );

  /// Whether the LCD is showing the rewind after the last frame of a roll: it
  /// still shows the roll ("Left 00") until the rewind ends.
  bool _rewinding = false;

  late final CameraService _camera = ref.read(cameraServiceProvider);
  Timer? _grainTimer;
  StreamSubscription<CaptureEvent>? _events;
  bool _capturing = false;
  bool _active = true;

  /// Where focus and exposure are locked, as a point of the frame (0..1).
  Offset? _lock;
  double _zoomBase = 1;
  String? _zoomText;
  Timer? _zoomTimer;
  String? _notice;
  Timer? _noticeTimer;

  /// Whether the offer of a first roll of 12 is on the screen.
  bool _offerVisible = false;
  bool _evaluatingOffer = false;
  ModalRoute<Object?>? _route;

  /// The rolls the user is closing or throwing away from the sheet: the camera
  /// opens the screen of the first kind itself and says nothing about either.
  final Set<int> _closingByUser = <int>{};
  final Set<int> _discarding = <int>{};
  Timer? _rollOpenTimer;

  /// How much of the shot animation is the shutter flash.
  static final double _flashShare =
      CarreteDurations.shutterFlash.inMilliseconds /
      CarreteDurations.filmAdvance.inMilliseconds;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Riverpod pauses unobserved streams. Keep the roll subscription live
    // so shutter routing can await its initial value without stalling. It also
    // tells when the roll in the camera ends.
    ref.listenManual(activeRollProvider, _onActiveRoll);
    // The loose photos are counted for the offer of a roll of 12 by the app,
    // not by this screen; the offer waits until the camera can show it.
    ref.read(loosePhotoTrackerProvider);
    ref.listenManual(
      firstMinuteProvider.select((s) => s.loosePhotos),
      (_, _) => unawaited(_evaluateOffer()),
    );
    // Re-evaluate the pending offer when the fine-tuning panel closes, by
    // its close button, by tapping outside or with Back.
    ref.listenManual(viewfinderProvider.select((s) => s.tuningFilmId), (
      previous,
      next,
    ) {
      if (next == null) unawaited(_evaluateOffer());
    });
    // A count that was already enough at start (the offer was waiting).
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_evaluateOffer()),
    );
    unawaited(_camera.setFlash(ref.read(viewfinderProvider).flash));
    unawaited(_camera.start());
    // The sounds are decoded as soon as they are wanted, also when they are
    // turned on in the settings while the camera is open.
    ref.listenManual(settingsProvider.select((s) => s.cameraSounds), (_, on) {
      if (on) unawaited(ref.read(cameraSoundsProvider).preload());
    }, fireImmediately: true);
    _events = ref.read(captureQueueProvider).events.listen(_onCaptureEvent);
    if (FilmShaderView.supported) {
      // Film grain changes every frame of a 24 fps projection.
      _grainTimer = Timer.periodic(CarreteDurations.grain, (_) {
        if (!_active || !mounted) return;
        if (MediaQuery.disableAnimationsOf(context)) return;
        _grainSeed.value = (_grainSeed.value + 0.137) % 97.0;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // When the route that covered the camera is gone, the offer that waited
    // can be shown.
    final route = ModalRoute.of(context);
    if (route != _route) {
      _route?.secondaryAnimation?.removeStatusListener(_onRouteCovered);
      _route = route;
      route?.secondaryAnimation?.addStatusListener(_onRouteCovered);
    }
  }

  void _onRouteCovered(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) unawaited(_evaluateOffer());
  }

  @override
  void dispose() {
    _route?.secondaryAnimation?.removeStatusListener(_onRouteCovered);
    WidgetsBinding.instance.removeObserver(this);
    _grainTimer?.cancel();
    _zoomTimer?.cancel();
    _noticeTimer?.cancel();
    _rollOpenTimer?.cancel();
    unawaited(_events?.cancel());
    _shot.dispose();
    _rewind.dispose();
    _grainSeed.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _active = true;
      unawaited(_camera.resume());
      unawaited(_evaluateOffer());
    } else {
      _active = false;
      unawaited(_camera.pause());
    }
  }

  void _onCaptureEvent(CaptureEvent event) {
    if (!mounted) return;
    // Said only for a photo that is in the gallery: the queue reports the
    // event when the processor is done, and a processor that saved nothing
    // gives no place for it.
    if (event.ok) {
      if (event.uri != null) {
        announce(context, AppLocalizations.of(context).shotSaved);
      }
    } else {
      // A shot retried from an earlier run was never on this counter.
      if (!event.job.retried) {
        ref.read(viewfinderProvider.notifier).removeShot();
      }
      _showNotice(AppLocalizations.of(context).shotSaveFailed);
    }
  }

  /// Whether the camera is what the user sees: it is the route on top and the
  /// app is in the foreground, with no fine-tuning panel over the picture.
  bool get _cameraVisible =>
      mounted &&
      _active &&
      (ModalRoute.of(context)?.isCurrent ?? true) &&
      ref.read(viewfinderProvider).tuningFilmId == null;

  /// Shows the offer of a first roll of 12 when the user is eligible and can
  /// see it: two loose photos were saved and no roll was ever loaded. It is
  /// marked as seen only when it is shown. When something covers the camera
  /// it waits, and this runs again when the camera is back.
  Future<void> _evaluateOffer() async {
    if (_evaluatingOffer || _offerVisible || !mounted) return;
    final firstMinute = ref.read(firstMinuteProvider);
    if (firstMinute.rollOfferSeen ||
        firstMinute.loosePhotos < kLoosePhotosBeforeRollOffer ||
        !_cameraVisible) {
      return;
    }
    _evaluatingOffer = true;
    // Riverpod pauses unobserved streams: listen while waiting for the rolls.
    final listening = ref.listenManual(rollsListProvider, (_, _) {});
    try {
      final rolls = await ref.read(rollsListProvider.future);
      if (!mounted) return;
      if (rolls.isNotEmpty) {
        // Someone who already used a roll knows the way: never offer.
        ref.read(firstMinuteProvider.notifier).markRollOfferSeen();
        return;
      }
    } on Object {
      return;
    } finally {
      listening.close();
      _evaluatingOffer = false;
    }
    // Everything is checked again after the wait: a roll may have been loaded
    // or something may now cover the camera.
    if (_offerVisible || ref.read(firstMinuteProvider).rollOfferSeen) return;
    if (ref.read(activeRollProvider).value != null || !_cameraVisible) return;
    ref.read(firstMinuteProvider.notifier).markRollOfferSeen();
    setState(() => _offerVisible = true);
  }

  /// A roll is loaded: whatever the user does with it later, the offer is over
  /// for good.
  void _cancelOffer() {
    ref.read(firstMinuteProvider.notifier).markRollOfferSeen();
    if (_offerVisible && mounted) setState(() => _offerVisible = false);
  }

  /// The thud and the haptic of a roll that was loaded. The objects are given
  /// by the caller, who took them before the screen could go away.
  static void _rollLoadedFeedback(CameraSounds sounds, Haptics haptics) {
    unawaited(sounds.playLoad());
    unawaited(haptics.mediumImpact());
  }

  /// The soft click of a cartridge that settled in the carousel.
  void _cartridgeSettled() {
    unawaited(ref.read(cameraSoundsProvider).playCartridge());
    unawaited(ref.read(hapticsProvider).selectionClick());
  }

  /// The last frame of a roll is secured: the film rewinds.
  void _rollFinishedFeedback() {
    unawaited(ref.read(cameraSoundsProvider).playRewind());
    unawaited(ref.read(hapticsProvider).lightImpact());
    if (MediaQuery.disableAnimationsOf(context)) return;
    setState(() => _rewinding = true);
    unawaited(
      _rewind.forward(from: 0).whenComplete(() {
        if (mounted) setState(() => _rewinding = false);
      }),
    );
  }

  /// Loads the roll of 12 the offer proposed, with the film of the camera, to
  /// develop right away once it is closed.
  Future<void> _acceptRollOffer(Recipe film) async {
    setState(() => _offerVisible = false);
    final sounds = ref.read(cameraSoundsProvider);
    final haptics = ref.read(hapticsProvider);
    try {
      await ref
          .read(rollServiceProvider)
          .openRoll(kOfferedRollLength, DevelopDelay.instant, filmId: film.id);
      _rollLoadedFeedback(sounds, haptics);
    } on OpenRollExistsException {
      // Another roll was loaded meanwhile; the camera already shows it.
    } on Object catch (error) {
      _rollActionFailed(error);
    }
  }

  void _showNotice(String message) {
    _noticeTimer?.cancel();
    setState(() => _notice = message);
    _noticeTimer = Timer(CarreteDurations.notice, () {
      if (mounted) setState(() => _notice = null);
    });
  }

  // --- the roll ------------------------------------------------------------

  /// The roll in the camera ended: it closed by itself with its last frame, or
  /// the user closed or threw it away from the sheet.
  void _onActiveRoll(AsyncValue<RollRow?>? before, AsyncValue<RollRow?> after) {
    // A roll was loaded: the offer of a first roll is over for good.
    if (after.value != null) _cancelOffer();
    final ended = before?.value;
    if (ended == null || !after.hasValue || after.value != null) return;
    if (_discarding.remove(ended.id)) return;
    if (_closingByUser.remove(ended.id)) {
      _openRollScreen(ended.id);
      return;
    }
    // The last frame: say so (and rewind), then show the roll.
    if (!mounted) return;
    _rollFinishedFeedback();
    _showNotice(AppLocalizations.of(context).rollClosedNotice);
    _rollOpenTimer?.cancel();
    _rollOpenTimer = Timer(CarreteDurations.rollClosedPause, () {
      if (mounted) _openRollScreen(ended.id);
    });
  }

  void _openRollScreen(int id) {
    final callback = widget.onOpenRoll;
    if (callback != null) {
      callback(id);
    } else {
      unawaited(context.push(AppRoutes.rollOf('$id')));
    }
  }

  /// Opens the roll sheet and carries out what the user chose.
  Future<void> _openRollSheet(Recipe film) async {
    final intent = await showRollSheet(context, loadFilm: film);
    if (!mounted) return;
    // The sheet is gone: an offer that waited behind it can be shown.
    if (intent == null) {
      unawaited(_evaluateOffer());
      return;
    }
    final service = ref.read(rollServiceProvider);
    // Taken now: loading the disposable camera takes the phone to another
    // screen, and this one may be gone by then.
    final sounds = ref.read(cameraSoundsProvider);
    final haptics = ref.read(hapticsProvider);
    try {
      switch (intent) {
        case LoadRollIntent(:final length, :final delay):
          await service.openRoll(length, delay, filmId: film.id);
          _rollLoadedFeedback(sounds, haptics);
        case LoadDisposableIntent(:final delay):
          final roll = await service.openDisposable(
            delay,
            filmId: kDisposableFilmId,
          );
          _rollLoadedFeedback(sounds, haptics);
          // The router takes the phone to the disposable camera.
          await ref.read(disposableLockProvider.notifier).lock(roll.id);
        case ResumeDisposableIntent(:final rollId):
          await ref.read(disposableLockProvider.notifier).lock(rollId);
        case CloseRollIntent(:final rollId):
          _closingByUser.add(rollId);
          await service.closeRoll(rollId);
        case DevelopRollNowIntent(:final rollId):
          _closingByUser.add(rollId);
          // Developing takes a while: the screen of the roll shows its
          // progress, so it opens as soon as the roll is closed.
          unawaited(
            service
                .developNow(rollId)
                .then<void>((_) {}, onError: _rollActionFailed),
          );
        case DiscardRollIntent(:final rollId):
          _discarding.add(rollId);
          await service.discardRoll(rollId);
        case OpenRollIntent(:final rollId):
          _openRollScreen(rollId);
      }
    } on OpenRollExistsException {
      // Another roll was loaded meanwhile; the camera already shows it.
    } on Object catch (error) {
      _closingByUser.clear();
      _discarding.clear();
      _rollActionFailed(error);
    }
  }

  void _rollActionFailed(Object error) {
    if (kDebugMode) debugPrint('Roll action failed: $error');
    if (mounted) _showNotice(AppLocalizations.of(context).rollActionFailed);
  }

  void _openSettings() {
    final callback = widget.onOpenSettings;
    if (callback != null) {
      callback();
    } else {
      unawaited(context.push(AppRoutes.settings));
    }
  }

  void _openGallery() {
    final callback = widget.onOpenGallery;
    if (callback != null) {
      callback();
    } else {
      unawaited(context.push(AppRoutes.gallery));
    }
  }

  // --- the shutter ---------------------------------------------------------

  /// Presses the shutter. Everything that shapes the photo is read now; the
  /// camera, the queue and the saving run afterwards.
  Future<void> _shoot(Recipe recipe) async {
    if (_capturing) return;
    final now = DateTime.now();
    final settings = ref.read(settingsProvider);
    final location = settings.saveLocation
        ? ref.read(locationControllerProvider).at(now)
        : null;
    final tuning =
        ref.read(filmTuningsProvider)[recipe.id] ?? FilmTuning.defaults;
    final flash = ref.read(viewfinderProvider).flash;
    final look = lookFor(recipe, tuning, flash);
    final format = look.format;
    final fieldAspect = _camera.state.value.previewAspect;
    final stampText = look.dateStamp
        ? DateStamp.format(now, settings.dateStampStyle)
        : null;
    final lens = _camera.state.value.lens;
    final shotLens = lens == CameraLens.front ? ShotLens.front : ShotLens.back;
    CaptureJob jobFor(String path) => CaptureJob(
      filePath: path,
      filmId: recipe.id,
      look: look,
      format: format,
      seed: grainSeedOf(now),
      takenAt: now,
      tuning: tuning,
      flash: flash,
      fieldAspect: fieldAspect,
      stampText: stampText,
      whiteFrame: look.whiteFrame && format == FrameFormat.r1x1,
      cinemaBands: look.cinemaBands && format == FrameFormat.r16x9,
      includeLocation: settings.saveLocation && location != null,
      location: location,
      saveOriginal: settings.saveOriginal,
      lens: shotLens,
      captureId: newCaptureId(),
    );

    _capturing = true;
    unawaited(ref.read(hapticsProvider).selectionClick());
    if (settings.cameraSounds) {
      unawaited(ref.read(cameraSoundsProvider).playShot());
    }
    if (!MediaQuery.disableAnimationsOf(context)) {
      unawaited(_shot.forward(from: 0));
    }
    // The queue and the counter are taken now: the screen may be gone when
    // the camera answers, and the photo still has to be developed.
    final queue = ref.read(captureQueueProvider);
    final rollAtShutter = ref.read(activeRollProvider.future);
    RollService rollService() => ref.read(rollServiceProvider);
    final viewfinder = ref.read(viewfinderProvider.notifier);
    // Only loose photos count on the LCD: a roll counts down its own frames,
    // and its photos must not show up as photos of this session later.
    var counted = false;
    try {
      // A disposable that is open but not in the camera is set aside: the
      // camera behaves as if no roll were loaded.
      final active = await rollAtShutter;
      final roll = active?.mode == RollMode.disposable ? null : active;
      if (roll == null) {
        viewfinder.addShot();
        counted = true;
      }
      // Resolve the service before the camera answers: the screen may leave.
      final service = roll == null ? null : rollService();
      final photo = await _camera.takePicture();
      if (service == null) {
        queue.enqueue(jobFor(photo.path));
      } else {
        unawaited(
          service
              .captureIntoRoll(
                jobFor(photo.path),
                rollId: roll!.id,
                lens: shotLens,
              )
              .then<void>(
                (_) {},
                onError: (Object error) {
                  if (kDebugMode) debugPrint('Roll capture failed: $error');
                  if (mounted) {
                    _showNotice(AppLocalizations.of(context).shotSaveFailed);
                  }
                  // The original stays in roll-recovery; it is never sent to gallery.
                },
              ),
        );
      }
    } on Object catch (error) {
      if (kDebugMode) debugPrint('takePicture failed: $error');
      if (counted) viewfinder.removeShot();
      if (mounted) _showNotice(AppLocalizations.of(context).shotSaveFailed);
    } finally {
      _capturing = false;
    }
  }

  // --- gestures on the frame -----------------------------------------------

  void _onFrameTap(TapUpDetails details, Size frame) {
    final viewfinder = ref.read(viewfinderProvider);
    if (viewfinder.tuningFilmId != null) {
      ref.read(viewfinderProvider.notifier).closeTuning();
      return;
    }
    final preview = _camera.state.value.previewSize;
    if (preview == null) return;
    final lock = _lock;
    if (lock != null &&
        (Offset(lock.dx * frame.width, lock.dy * frame.height) -
                    details.localPosition)
                .distance <
            FocusLockIndicator.width / 2) {
      setState(() => _lock = null);
      unawaited(_camera.focusAt(null));
      return;
    }
    final point = Offset(
      (details.localPosition.dx / frame.width).clamp(0.0, 1.0),
      (details.localPosition.dy / frame.height).clamp(0.0, 1.0),
    );
    setState(() => _lock = point);
    unawaited(_camera.focusAt(framePointToPreview(point, frame, preview)));
  }

  void _onScaleStart(ScaleStartDetails details) {
    _zoomBase = _camera.state.value.zoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount < 2) return;
    final state = _camera.state.value;
    final zoom = (_zoomBase * details.scale).clamp(
      state.minZoom,
      state.maxZoom,
    );
    unawaited(_camera.setZoom(zoom));
    _zoomTimer?.cancel();
    setState(
      () =>
          _zoomText = AppLocalizations.of(context)
              .zoomLabel(zoom.toStringAsFixed(1)),
    );
    _zoomTimer = Timer(CarreteDurations.zoomPill, () {
      if (mounted) setState(() => _zoomText = null);
    });
  }

  // --- building ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final book = ref.watch(recipeBookProvider);
    // The camera follows the theme of the app; its picture stays dark.
    final colors = CarreteCameraColors.forBrightness(
      Theme.of(context).brightness,
    );
    return CarreteCameraTheme(
      colors: colors,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: colors.systemOverlay,
        child: Scaffold(
          backgroundColor: colors.body,
          body: book.when(
            data: _buildCamera,
            loading: () => const SizedBox.expand(),
            error: (_, _) => Center(
              child: Text(
                l10n.filmsLoadFailed,
                style: CarreteText.message.copyWith(color: colors.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCamera(RecipeBook book) {
    final settings = ref.watch(settingsProvider);
    final tunings = ref.watch(filmTuningsProvider);
    final vf = ref.watch(viewfinderProvider);
    final resources = ref.watch(filmResourcesProvider).value;
    final reduced = MediaQuery.disableAnimationsOf(context);

    // With a roll loaded the camera counts the frames left, and (see
    // kLockFilmToRoll) shoots with the film of the roll.
    // A disposable set aside does not count: see the note in `_shoot`.
    final active = ref.watch(activeRollProvider).value;
    final paused = active?.mode == RollMode.disposable ? active : null;
    final roll = paused == null ? active : null;
    final left = active == null
        ? null
        : ref.watch(remainingFramesProvider).value ?? active.length;
    // After the last frame the LCD keeps showing the roll while it rewinds.
    final framesLeft = roll == null ? (_rewinding ? 0 : null) : left;
    final rollFilm = roll != null && kLockFilmToRoll
        ? book.byId(roll.filmId)
        : null;
    final recipe = rollFilm ?? selectedRecipe(book, settings.defaultFilmId);
    final tuning = tunings[recipe.id] ?? FilmTuning.defaults;
    final look = lookFor(recipe, tuning, vf.flash);
    final format = look.format;
    final whiteFrameHint = look.whiteFrame && format == FrameFormat.r1x1;
    final stampText = look.dateStamp
        ? DateStamp.format(DateTime.now(), settings.dateStampStyle)
        : null;

    final firstMinute = ref.watch(firstMinuteProvider);
    // A new user (one who has not seen the tutorial) gets a hint about the
    // films, once. Someone who saw the tutorial already knows.
    final showSwipeHint =
        !firstMinute.swipeHintSeen && !settings.onboardingSeen && roll == null;
    final showRollOffer = _offerVisible;

    final tuningRecipe = vf.tuningFilmId == null
        ? null
        : book.byId(vf.tuningFilmId!);

    return PopScope(
      canPop: tuningRecipe == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(viewfinderProvider.notifier).closeTuning();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screen = constraints.biggest;
          final padding = MediaQuery.paddingOf(context);
          final bar = TopBarLayout.of(
            context,
            width: screen.width - 2 * CarreteSpacing.margin,
            hasRoll: true,
            filmName: recipe.name.of(context),
            framesLeft: framesLeft,
            pausedDisposableLeft: paused == null ? null : left,
          );
          final topReserved = padding.top + bar.reserve;
          final bottomPad = math.max(padding.bottom, CarreteSizes.bottomInset);
          final bottomReserved =
              CarreteSizes.carouselHeight +
              CarreteSpacing.s +
              CarreteSpacing.shutter +
              bottomPad;
          // The whole frame fits between the top bar and the carousel, so
          // nothing of the photo is hidden under a control.
          final frame = placeFrame(
            screen: screen,
            aspect: format.portraitAspect,
            topReserved: topReserved,
            bottomReserved: bottomReserved,
          );

          final colors = CarreteCameraColors.of(context);
          return Stack(
            children: [
              // The window behind the picture, when it is not the body.
              if (colors.surround != colors.body)
                Positioned(
                  key: const ValueKey('viewfinder-surround'),
                  left: 0,
                  right: 0,
                  top: topReserved,
                  bottom: bottomReserved,
                  child: ColoredBox(color: colors.surround),
                ),
              // The picture stays dark whatever the theme: what shows while
              // the camera starts, and the problem when it fails.
              if (colors.body != CarreteColors.viewfinder)
                Positioned.fromRect(
                  rect: frame,
                  child: const ColoredBox(color: CarreteColors.viewfinder),
                ),
              Positioned.fromRect(
                key: const ValueKey('viewfinder-frame'),
                rect: frame,
                child: _buildFrame(
                  size: frame.size,
                  recipe: recipe,
                  look: look,
                  resources: resources,
                  stampText: stampText,
                  whiteFrameHint: whiteFrameHint,
                  showGrid: settings.grid,
                  showLevel: settings.level,
                  reduced: reduced,
                ),
              ),
              Positioned(
                left: CarreteSpacing.margin,
                right: CarreteSpacing.margin,
                top: padding.top + CarreteSpacing.s,
                child: ViewfinderTopBar(
                  rollFramesLeft: framesLeft,
                  pausedDisposableLeft: paused == null ? null : left,
                  filmName: recipe.name.of(context),
                  onRoll: () => unawaited(_openRollSheet(recipe)),
                  flash: vf.flash,
                  advance: reduced ? null : _shot,
                  rewind: reduced || !_rewinding ? null : _rewind,
                  onFlash: (mode) {
                    ref.read(viewfinderProvider.notifier).setFlash(mode);
                    unawaited(_camera.setFlash(mode));
                    final l10n = AppLocalizations.of(context);
                    announce(
                      context,
                      l10n.flashKeyLabel(flashModeName(l10n, mode)),
                    );
                  },
                  onSettings: _openSettings,
                ),
              ),
              // Under the LCD, over the first rows of the picture: quiet, and
              // away from the keys. It draws nothing when all is saved.
              Positioned(
                left: CarreteSpacing.margin,
                top: topReserved,
                child: const SaveStatusStrip(),
              ),
              if (showSwipeHint && tuningRecipe == null)
                Positioned(
                  key: const ValueKey('swipe-hint'),
                  left: CarreteSpacing.margin,
                  right: CarreteSpacing.margin,
                  bottom: bottomReserved + CarreteSpacing.xs,
                  child: SwipeHint(
                    onClose: ref
                        .read(firstMinuteProvider.notifier)
                        .markSwipeHintSeen,
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomPad),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilmCarousel(
                        recipes: book.recipes,
                        selectedId: recipe.id,
                        locked: rollFilm != null,
                        onSettled: _cartridgeSettled,
                        onSwiped: ref
                            .read(firstMinuteProvider.notifier)
                            .markSwipeHintSeen,
                        onSelected: (r) {
                          // Swiping the films is what the hint asked for.
                          ref
                              .read(firstMinuteProvider.notifier)
                              .markSwipeHintSeen();
                          final viewfinder = ref.read(
                            viewfinderProvider.notifier,
                          );
                          viewfinder.selectFilm(r.id);
                          if (ref.read(viewfinderProvider).tuningFilmId !=
                              null) {
                            viewfinder.openTuning(r.id);
                          }
                        },
                        onTune: (r) {
                          final viewfinder = ref.read(
                            viewfinderProvider.notifier,
                          )..selectFilm(r.id);
                          viewfinder.openTuning(r.id);
                        },
                        thumbnailBuilder: (context, r) => _buildThumbnail(
                          recipe: r,
                          tuning: tunings[r.id] ?? FilmTuning.defaults,
                          resources: resources,
                        ),
                      ),
                      const SizedBox(height: CarreteSpacing.s),
                      _buildShutterRow(recipe, format),
                    ],
                  ),
                ),
              ),
              if (tuningRecipe != null)
                Positioned(
                  left: CarreteSizes.panelMargin,
                  right: CarreteSizes.panelMargin,
                  bottom: bottomReserved - CarreteSizes.panelOverlap,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: (screen.height - bottomReserved - topReserved)
                          .clamp(
                            CarreteSizes.panelMinHeight,
                            CarreteSizes.panelMaxHeight,
                          ),
                    ),
                    child: _buildTuningPanel(tuningRecipe, tunings),
                  ),
                ),
              if (showRollOffer)
                Positioned(
                  key: const ValueKey('roll-offer'),
                  left: CarreteSizes.panelMargin,
                  right: CarreteSizes.panelMargin,
                  top: topReserved + CarreteSpacing.s,
                  child: RollOfferCard(
                    film: recipe.name.of(context),
                    // Between the top bar and the carousel, with air around.
                    maxHeight: math.max(
                      0,
                      screen.height -
                          topReserved -
                          bottomReserved -
                          2 * CarreteSpacing.s,
                    ),
                    onAccept: () => unawaited(_acceptRollOffer(recipe)),
                    onDismiss: () => setState(() => _offerVisible = false),
                  ),
                ),
              if (_notice != null)
                Positioned(
                  left: CarreteSpacing.margin,
                  right: CarreteSpacing.margin,
                  top: topReserved + CarreteSpacing.s,
                  child: Semantics(
                    liveRegion: true,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: CarreteColors.notice,
                        borderRadius: BorderRadius.circular(CarreteRadii.key),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(CarreteSpacing.m),
                        child: Text(
                          _notice!,
                          textAlign: TextAlign.center,
                          style: CarreteText.notice,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFrame({
    required Size size,
    required Recipe recipe,
    required ResolvedLook look,
    required FilmResources? resources,
    required String? stampText,
    required bool whiteFrameHint,
    required bool showGrid,
    required bool showLevel,
    required bool reduced,
  }) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<CameraServiceState>(
      valueListenable: _camera.state,
      builder: (context, cam, _) {
        if (cam.failure != null) {
          final denied = cam.failure == CameraFailure.permissionDenied;
          final system = ref.read(systemSettingsProvider);
          return CarreteCameraTheme(
            colors: CarreteCameraColors.dark,
            child: _CameraProblem(
              message: denied
                  ? l10n.cameraPermissionDenied
                  : l10n.cameraUnavailable,
              retryLabel: l10n.cameraRetry,
              onRetry: () => unawaited(_camera.start(lens: cam.lens)),
              settingsLabel: denied && system.canOpen
                  ? l10n.cameraOpenSettings
                  : null,
              onSettings: () => unawaited(system.open()),
            ),
          );
        }
        final lock = _lock;
        return Semantics(
          label: l10n.viewfinderLabel,
          container: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _onFrameTap(d, size),
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (cam.ready && cam.previewSize != null)
                    FilmShaderView(
                      resources: resources,
                      filmId: recipe.id,
                      look: look,
                      seed: reduced ? null : _grainSeed,
                      child: _coverPreview(cam.previewSize!),
                    ),
                  if (showGrid) const ThirdsGrid(),
                  if (showLevel) const LevelOverlay(),
                  if (stampText != null)
                    DateStampOverlay(
                      text: stampText,
                      cinemaBands:
                          look.cinemaBands && look.format.supportsCinemaBands,
                    ),
                  if (look.cinemaBands && look.format.supportsCinemaBands)
                    const CinemaBandsOverlay(),
                  const FrameCorners(),
                  if (lock != null)
                    Positioned(
                      left: _lockOrigin(
                        lock.dx,
                        size.width,
                        FocusLockIndicator.width,
                      ),
                      top: _lockOrigin(
                        lock.dy,
                        size.height,
                        FocusLockIndicator.height,
                      ),
                      child: Semantics(
                        label: l10n.focusLockedLabel,
                        child: const FocusLockIndicator(),
                      ),
                    ),
                  if (!reduced)
                    IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _shot,
                        builder: (context, _) => ColoredBox(
                          color: CarreteColors.white.withValues(
                            alpha: _flashOpacity(_shot.value),
                          ),
                        ),
                      ),
                    ),
                  if (whiteFrameHint)
                    Positioned(
                      left: CarreteSpacing.l,
                      bottom: CarreteSpacing.l,
                      child: _Pill(text: l10n.whiteFrameHint),
                    ),
                  if (_zoomText != null)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: CarreteSpacing.xl,
                        ),
                        child: Semantics(
                          liveRegion: true,
                          container: true,
                          child: _Pill(text: _zoomText!),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Where the top left corner of the focus indicator goes so that it is
  /// centred on [fraction] (0..1) of an [extent] long axis of the frame, and
  /// stays inside the frame.
  double _lockOrigin(double fraction, double extent, double indicator) =>
      (fraction * extent - indicator / 2).clamp(
        0.0,
        math.max(0.0, extent - indicator),
      );

  /// The flash of the shutter: up to its peak in a tenth of its length, then
  /// down to nothing.
  double _flashOpacity(double t) {
    if (t <= 0 || t >= _flashShare) return 0;
    final rise = _flashShare * CarreteMotion.flashRise;
    const peak = CarreteMotion.flashPeak;
    if (t < rise) return peak * t / rise;
    return peak * (1 - (t - rise) / (_flashShare - rise));
  }

  /// The camera texture, scaled to cover its parent and cropped to it.
  Widget _coverPreview(Size previewSize) {
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: previewSize.width,
          height: previewSize.height,
          child: _camera.buildPreview(context),
        ),
      ),
    );
  }

  Widget _buildThumbnail({
    required Recipe recipe,
    required FilmTuning tuning,
    required FilmResources? resources,
  }) {
    return ValueListenableBuilder<CameraServiceState>(
      valueListenable: _camera.state,
      builder: (context, cam, _) {
        final size = cam.previewSize;
        if (!cam.ready || size == null) {
          return const ColoredBox(color: CarreteColors.deep);
        }
        return FilmShaderView(
          resources: resources,
          filmId: recipe.id,
          look: lookFor(recipe, tuning, CarreteFlash.off),
          child: _coverPreview(size),
        );
      },
    );
  }

  Widget _buildShutterRow(Recipe recipe, FrameFormat format) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: CarreteSpacing.shutter,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Two keys on the left, one on the right and the shutter in the
          // middle of the screen: both sides get the same room. On a narrow
          // screen the keys keep the 44 dp touch size and the margins give.
          final fit = CarreteShutterRow.fit(constraints.maxWidth);
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: fit.inset),
            child: ValueListenableBuilder<CameraServiceState>(
              valueListenable: _camera.state,
              builder: (context, cam, _) => Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        // Only for a screen too narrow for the keys at 44 dp.
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PlasticKey(
                              key: const ValueKey('gallery-key'),
                              semanticLabel: l10n.galleryTitle,
                              width: fit.key,
                              height: fit.key,
                              onPressed: _openGallery,
                              child: const CarreteIconView(
                                icon: CarreteIcon.photos,
                              ),
                            ),
                            SizedBox(width: fit.gap),
                            PlasticKey(
                              semanticLabel: l10n.switchCameraLabel,
                              width: fit.key,
                              height: fit.key,
                              onPressed: () {
                                setState(() => _lock = null);
                                unawaited(_camera.switchLens());
                              },
                              child: const CarreteIconView(
                                icon: CarreteIcon.flip,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ShutterButton(
                    semanticLabel: l10n.shutterLabel,
                    onPressed: cam.ready
                        ? () => unawaited(_shoot(recipe))
                        : null,
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: PlasticKey(
                        key: const ValueKey('format-key'),
                        semanticLabel: l10n.formatKeyLabel(format.label),
                        semanticHint: l10n.formatKeyHint,
                        width: fit.key,
                        height: fit.key,
                        onPressed: () => ref
                            .read(filmTuningsProvider.notifier)
                            .update(
                              recipe.id,
                              (t) => t.copyWith(format: format.next),
                            ),
                        child: Text(format.label),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTuningPanel(Recipe recipe, Map<String, FilmTuning> tunings) {
    final tuning = tunings[recipe.id] ?? FilmTuning.defaults;
    final look = resolve(recipe, overrides: tuning.overrides);
    return FilmTuningPanel(
      recipe: recipe,
      tuning: tuning,
      effectiveFormat: look.format,
      effectiveDateStamp: look.dateStamp,
      effectiveCinemaBands: look.cinemaBands,
      sampleStamp: DateStamp.format(
        DateTime.now(),
        ref.read(settingsProvider).dateStampStyle,
      ),
      onChanged: (change) =>
          ref.read(filmTuningsProvider.notifier).update(recipe.id, change),
      onClose: ref.read(viewfinderProvider.notifier).closeTuning,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CarreteColors.pill,
        borderRadius: BorderRadius.circular(CarreteRadii.key),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CarreteSizes.pillInsetH,
          vertical: CarreteSizes.pillInsetV,
        ),
        child: Text(text, style: CarreteText.hint),
      ),
    );
  }
}

class _CameraProblem extends StatelessWidget {
  const _CameraProblem({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    required this.onSettings,
    this.settingsLabel,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  /// The label of the key that opens the settings of the system, or null
  /// when there is no such key.
  final String? settingsLabel;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CarreteSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: CarreteText.message,
            ),
            const SizedBox(height: CarreteSpacing.l),
            if (settingsLabel != null) ...[
              PlasticKey(
                semanticLabel: settingsLabel!,
                width: CarreteSizes.wideKey,
                onPressed: onSettings,
                child: Text(settingsLabel!),
              ),
              const SizedBox(height: CarreteSpacing.m),
            ],
            PlasticKey(
              semanticLabel: retryLabel,
              width: CarreteSizes.retryKey,
              onPressed: onRetry,
              child: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}
