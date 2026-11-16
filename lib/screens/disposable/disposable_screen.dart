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
import '../../capture/capture_queue.dart';
import '../../capture/date_stamp.dart';
import '../../capture/film_capture_processor.dart';
import '../../core/l10n/localized_text.dart';
import '../../core/database/app_database.dart';
import '../../core/database/tables.dart';
import '../../core/router.dart';
import '../../location/location_provider.dart';
import '../../core/settings/settings_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/camera_sounds.dart';
import '../../platform/haptics.dart';
import '../../platform/system_settings.dart';
import '../../render/film_resources.dart';
import '../../roll/disposable.dart';
import '../../roll/roll_service.dart';
import '../../ui/theme/carrete_tokens.dart';
import '../../ui/theme/disposable_tokens.dart';
import '../viewfinder/film_shader_view.dart';
import '../viewfinder/viewfinder_state.dart';
import 'disposable_parts.dart';

/// The disposable camera, in design C: kraft cardboard and paper.
///
/// A screen for passing the phone from hand to hand. It has the viewfinder, the
/// shutter, the flash switch, the counter of photos left and the thumb wheel,
/// and nothing else: no film carousel, tuning, gallery, settings, format or lens
/// key, and no way to see a photo. System back does nothing. The only way out is
/// to hold the exit stamp, and then to confirm.
///
/// The photos go into a roll of 27 (`RollMode.disposable`), so everything about
/// vaulting, developing and the contact sheet is the roll's.
class DisposableScreen extends ConsumerStatefulWidget {
  const DisposableScreen({this.onLeft, this.onFinished, super.key});

  /// Called when the person left on purpose, after the lock was released.
  /// Goes back to the camera when null.
  final VoidCallback? onLeft;

  /// Called with the id of the roll when the last photo was taken, after the
  /// lock was released. Goes to the camera and opens the roll when null.
  final ValueChanged<int>? onFinished;

  @override
  ConsumerState<DisposableScreen> createState() => _DisposableScreenState();
}

class _DisposableScreenState extends ConsumerState<DisposableScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  /// The thumb wheel and the flash of the shutter.
  late final AnimationController _advance = AnimationController(
    vsync: this,
    duration: DisposableDurations.advance,
  );
  final ValueNotifier<double> _grainSeed = ValueNotifier<double>(0.37);

  late final CameraService _camera = ref.read(cameraServiceProvider);
  GoRouter? _router;
  Timer? _grainTimer;
  Timer? _noticeTimer;
  Timer? _doneTimer;
  bool _active = true;
  bool _capturing = false;
  bool _leaving = false;

  /// The flash: automatic, or off.
  CarreteFlash _flash = CarreteFlash.auto;

  /// Photos taken with this screen, for the thumb wheel.
  int _advances = 0;

  /// Shots that left the shutter and have not finished going into the roll.
  int _pending = 0;

  /// The frames the roll will have left once the shots on their way are in,
  /// or null when none is. The query of the database counts a shot as soon as
  /// it is inserted, while it is still pending, so the two are not added: the
  /// counter shows the lower of them. The 27th photo is the last whatever the
  /// speed of the person holding the camera, and the number never goes back up.
  int? _expected;

  /// The roll this screen has seen in the camera. Null until the first one.
  int? _rollId;
  String? _notice;

  static final double _flashShare =
      DisposableDurations.flash.inMilliseconds /
      DisposableDurations.advance.inMilliseconds;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Kept: the screen may need it after its own context is gone.
    _router = GoRouter.maybeOf(context);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The system bars would be a way out for a guest.
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    ref.listenManual(activeRollProvider, _onActiveRoll, fireImmediately: true);
    ref.listenManual(remainingFramesProvider, (_, _) => _settle());
    unawaited(_camera.start());
    unawaited(_camera.setFlash(_flash));
    // The sounds are decoded as soon as they are wanted, also when they are
    // turned on in the settings while the camera is open.
    ref.listenManual(settingsProvider.select((s) => s.cameraSounds), (_, on) {
      if (on) unawaited(ref.read(cameraSoundsProvider).preload());
    }, fireImmediately: true);
    if (FilmShaderView.supported) {
      _grainTimer = Timer.periodic(CarreteDurations.grain, (_) {
        if (!_active || !mounted) return;
        if (MediaQuery.disableAnimationsOf(context)) return;
        _grainSeed.value = (_grainSeed.value + 0.137) % 97.0;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    _grainTimer?.cancel();
    _noticeTimer?.cancel();
    _doneTimer?.cancel();
    _advance.dispose();
    _grainSeed.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _active = true;
      unawaited(_camera.resume());
    } else {
      _active = false;
      unawaited(_camera.pause());
    }
  }

  // --- the roll ------------------------------------------------------------

  /// Remembers the roll, and notices when it ends: with the 27th photo it
  /// closes by itself and the camera becomes a roll that develops.
  void _onActiveRoll(AsyncValue<RollRow?>? before, AsyncValue<RollRow?> after) {
    if (!after.hasValue) return;
    final roll = after.value;
    if (roll != null) {
      _rollId = roll.id;
      return;
    }
    final ended = _rollId;
    // A roll that was never seen is one the database has not told us about
    // yet (the camera was just loaded), not one that ended.
    if (ended == null || _leaving) return;
    _leaving = true;
    // The last frame is secured: the film rewinds.
    unawaited(ref.read(cameraSoundsProvider).playRewind());
    unawaited(ref.read(hapticsProvider).lightImpact());
    _showNotice(AppLocalizations.of(context).disposableDone, sticky: true);
    _doneTimer = Timer(DisposableDurations.doneNotice, () => _finish(ended));
  }

  Future<void> _finish(int rollId) async {
    await ref.read(disposableLockProvider.notifier).release();
    final callback = widget.onFinished;
    if (callback != null) {
      callback(rollId);
      return;
    }
    // The camera first, so that back from the roll comes to it.
    _router
      ?..go(AppRoutes.camera)
      ..push(AppRoutes.rollOf('$rollId'));
  }

  Future<void> _leave() async {
    if (_leaving) return;
    final left = _leftNow() ?? 0;
    final sure = await confirmLeaveDisposable(context, left: left);
    if (!sure || !mounted || _leaving) return;
    _leaving = true;
    await ref.read(disposableLockProvider.notifier).release();
    final callback = widget.onLeft;
    if (callback != null) {
      callback();
    } else {
      _router?.go(AppRoutes.camera);
    }
  }

  /// The photos left, counting the ones still on their way into the roll.
  int? _leftNow() {
    final roll = ref.read(activeRollProvider).value;
    if (roll == null) return null;
    return _shownLeft(ref.read(remainingFramesProvider).value ?? roll.length);
  }

  int _shownLeft(int fromDatabase) =>
      math.max(0, math.min(fromDatabase, _expected ?? fromDatabase));

  /// Forgets the reservation once nothing is pending and the database says the
  /// same or less.
  void _settle() {
    final roll = ref.read(activeRollProvider).value;
    final expected = _expected;
    if (roll == null || expected == null || _pending > 0) return;
    final left = ref.read(remainingFramesProvider).value ?? roll.length;
    if (left <= expected) _expected = null;
  }

  void _showNotice(String message, {bool sticky = false}) {
    _noticeTimer?.cancel();
    setState(() => _notice = message);
    if (sticky) return;
    _noticeTimer = Timer(CarreteDurations.notice, () {
      if (mounted) setState(() => _notice = null);
    });
  }

  // --- the shutter ---------------------------------------------------------

  Future<void> _shoot(Recipe recipe, RollRow roll) async {
    if (_capturing || _leaving || (_leftNow() ?? 0) <= 0) return;
    final now = DateTime.now();
    final settings = ref.read(settingsProvider);
    final location = settings.saveLocation
        ? ref.read(locationControllerProvider).at(now)
        : null;
    final look = lookFor(recipe, kDisposableTuning, _flash);
    final format = look.format;
    final fieldAspect = _camera.state.value.previewAspect;
    final stampText = look.dateStamp
        ? DateStamp.format(now, settings.dateStampStyle)
        : null;
    CaptureJob jobFor(String path) => CaptureJob(
      filePath: path,
      filmId: recipe.id,
      look: look,
      format: format,
      seed: grainSeedOf(now),
      takenAt: now,
      tuning: kDisposableTuning,
      flash: _flash,
      fieldAspect: fieldAspect,
      stampText: stampText,
      whiteFrame: look.whiteFrame && format == FrameFormat.r1x1,
      includeLocation: settings.saveLocation && location != null,
      location: location,
      saveOriginal: settings.saveOriginal,
      lens: ShotLens.back,
      captureId: newCaptureId(),
    );

    _capturing = true;
    setState(() {
      _expected = (_leftNow() ?? 0) - 1;
      _pending++;
      _advances++;
    });
    unawaited(ref.read(hapticsProvider).selectionClick());
    if (settings.cameraSounds) {
      unawaited(ref.read(cameraSoundsProvider).playShot());
    }
    if (!MediaQuery.disableAnimationsOf(context)) {
      unawaited(_advance.forward(from: 0));
    }
    // The service is resolved now: the screen may be gone when the camera
    // answers, and the photo still has to go into the roll.
    final service = ref.read(rollServiceProvider);
    try {
      final photo = await _camera.takePicture();
      unawaited(
        service
            .captureIntoRoll(jobFor(photo.path), rollId: roll.id)
            .then<void>(
              (_) => _shotDone(),
              onError: (Object error) {
                if (kDebugMode) debugPrint('Disposable capture failed: $error');
                _shotDone(failed: true);
              },
            ),
      );
    } on Object catch (error) {
      if (kDebugMode) debugPrint('takePicture failed: $error');
      _shotDone(failed: true);
    } finally {
      _capturing = false;
    }
  }

  void _shotDone({bool failed = false}) {
    if (!mounted) return;
    setState(() {
      _pending = math.max(0, _pending - 1);
      // A photo that did not go in gives its frame back.
      if (failed) {
        _advances = math.max(0, _advances - 1);
        _expected = _expected == null ? null : _expected! + 1;
      }
      _settle();
    });
    if (failed) {
      _showNotice(AppLocalizations.of(context).shotSaveFailed);
    }
  }

  // --- building ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final book = ref.watch(recipeBookProvider);
    return PopScope(
      // Back never leaves the mode: only the exit stamp does.
      canPop: false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: DisposableColors.backdrop,
          body: book.when(
            data: _buildCamera,
            // The way out is there whatever happens to the films: the lock
            // outlives the app, so a screen without it would be a trap.
            loading: () => _buildExitOnly(null),
            error: (_, _) =>
                _buildExitOnly(AppLocalizations.of(context).filmsLoadFailed),
          ),
        ),
      ),
    );
  }

  Widget _buildExitOnly(String? message) {
    final padding = MediaQuery.paddingOf(context);
    return Stack(
      children: [
        Positioned(
          left: CarreteSpacing.margin,
          right: CarreteSpacing.margin,
          top: padding.top + DisposableSizes.topGap,
          child: Align(
            alignment: Alignment.centerRight,
            child: ExitStamp(onExit: () => unawaited(_leave())),
          ),
        ),
        if (message != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(CarreteSpacing.xl),
              child: DisposableNotice(text: message),
            ),
          ),
      ],
    );
  }

  Widget _buildCamera(RecipeBook book) {
    final l10n = AppLocalizations.of(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    final roll = ref.watch(activeRollProvider).value;
    final left = roll == null
        ? null
        : _shownLeft(ref.watch(remainingFramesProvider).value ?? roll.length);
    final recipe =
        book.byId(roll?.filmId ?? kDisposableFilmId) ??
        book.byId(kDisposableFilmId) ??
        book.recipes.first;
    final resources = ref.watch(filmResourcesProvider).value;
    final settings = ref.watch(settingsProvider);
    final look = lookFor(recipe, kDisposableTuning, _flash);
    final stampText = look.dateStamp
        ? DateStamp.format(DateTime.now(), settings.dateStampStyle)
        : null;
    final canShoot = roll != null && (left ?? 0) > 0 && !_leaving;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = constraints.biggest;
        final padding = MediaQuery.paddingOf(context);
        final topReserved =
            padding.top +
            DisposableSizes.topGap * 2 +
            DisposableSizes.topRow +
            CarreteSpacing.s;
        final bottomPad = math.max(padding.bottom, CarreteSizes.bottomInset);
        final cardboardHeight =
            DisposableSizes.edgeDepth +
            CarreteSpacing.m +
            DisposableSizes.strip +
            CarreteSpacing.s +
            DisposableSizes.shutterRow +
            bottomPad;
        final frame = placeFrame(
          screen: screen,
          aspect: look.format.portraitAspect,
          topReserved: topReserved,
          bottomReserved: cardboardHeight,
        );
        return Stack(
          children: [
            Positioned.fromRect(
              key: const ValueKey('disposable-frame'),
              rect: frame,
              child: _buildFrame(
                recipe: recipe,
                look: look,
                resources: resources,
                stampText: stampText,
                reduced: reduced,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: DisposableBand(height: topReserved),
            ),
            Positioned(
              left: CarreteSpacing.margin,
              right: CarreteSpacing.margin,
              top: padding.top + DisposableSizes.topGap,
              child: _buildTopRow(left),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: cardboardHeight,
              child: Cardboard(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: DisposableSizes.edgeDepth + CarreteSpacing.m,
                    bottom: bottomPad,
                  ),
                  child: Column(
                    children: [
                      CardboardStrip(
                        text: l10n.disposableStrip(kDisposableFrames),
                      ),
                      const SizedBox(height: CarreteSpacing.s),
                      SizedBox(
                        height: DisposableSizes.shutterRow,
                        child: _buildShutterRow(
                          recipe: recipe,
                          roll: roll,
                          canShoot: canShoot,
                          reduced: reduced,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_notice != null)
              Positioned(
                left: CarreteSpacing.margin,
                right: CarreteSpacing.margin,
                top: topReserved + CarreteSpacing.m,
                child: DisposableNotice(text: _notice!),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTopRow(int? left) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          flex: 3,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: StickerCounter(left: left ?? 0),
          ),
        ),
        const SizedBox(width: CarreteSpacing.s),
        FlashSwitch(
          on: _flash != CarreteFlash.off,
          onChanged: (on) {
            final mode = on ? CarreteFlash.auto : CarreteFlash.off;
            setState(() => _flash = mode);
            unawaited(_camera.setFlash(mode));
          },
        ),
        const SizedBox(width: CarreteSpacing.s),
        Flexible(
          flex: 3,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: ExitStamp(onExit: () => unawaited(_leave())),
          ),
        ),
      ],
    );
  }

  Widget _buildShutterRow({
    required Recipe recipe,
    required RollRow? roll,
    required bool canShoot,
    required bool reduced,
  }) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
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
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: FilmSticker(name: recipe.name.of(context)),
                    ),
                  ),
                ),
                DisposableShutter(
                  semanticLabel: l10n.shutterLabel,
                  onPressed: cam.ready && canShoot
                      ? () => unawaited(_shoot(recipe, roll!))
                      : null,
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ThumbWheel(
                      advances: _advances,
                      animation: reduced ? null : _advance,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFrame({
    required Recipe recipe,
    required ResolvedLook look,
    required FilmResources? resources,
    required String? stampText,
    required bool reduced,
  }) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<CameraServiceState>(
      valueListenable: _camera.state,
      builder: (context, cam, _) {
        if (cam.failure != null) {
          final denied = cam.failure == CameraFailure.permissionDenied;
          final system = ref.read(systemSettingsProvider);
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(CarreteSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DisposableNotice(
                    text: denied
                        ? l10n.cameraPermissionDenied
                        : l10n.cameraUnavailable,
                  ),
                  const SizedBox(height: CarreteSpacing.l),
                  // The same way out as the main camera: the system page
                  // where the permission can be granted again.
                  if (denied && system.canOpen) ...[
                    PaperKey(
                      key: const ValueKey('disposable-open-settings'),
                      label: l10n.cameraOpenSettings,
                      onPressed: () => unawaited(system.open()),
                    ),
                    const SizedBox(height: CarreteSpacing.m),
                  ],
                  PaperKey(
                    label: l10n.cameraRetry,
                    onPressed: () => unawaited(_camera.start()),
                  ),
                ],
              ),
            ),
          );
        }
        return Semantics(
          label: l10n.viewfinderLabel,
          container: true,
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
                if (stampText != null) DateStampOverlay(text: stampText),
                const DisposableCorners(),
                if (!reduced)
                  IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _advance,
                      builder: (context, _) => ColoredBox(
                        color: DisposableColors.flash.withValues(
                          alpha: _flashOpacity(_advance.value),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The flash of the shutter: up to its peak at once, then down to nothing.
  double _flashOpacity(double t) {
    if (t <= 0 || t >= _flashShare) return 0;
    final rise = _flashShare * DisposableDurations.flashRise;
    const peak = DisposableDurations.flashPeak;
    if (t < rise) return peak * t / rise;
    return peak * (1 - (t - rise) / (_flashShare - rise));
  }

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
}
