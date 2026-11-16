import 'dart:async';

import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../camera/camera_flash.dart';
import '../../camera/frame_geometry.dart';
import '../../capture/cinema_bands.dart';
import '../../capture/date_stamp.dart';
import '../../core/l10n/localized_text.dart';
import '../../core/settings/film_tuning.dart';
import '../../core/settings/film_tuning_provider.dart';
import '../../core/settings/settings_provider.dart';
import '../../import/import_developer.dart';
import '../../import/import_intake.dart';
import '../../import/import_job.dart';
import '../../import/import_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../render/film_resources.dart';
import '../../ui/theme/carrete_tokens.dart';
import '../../ui/theme/import_tokens.dart';
import '../../ui/widgets/carrete_icon.dart';
import '../../ui/widgets/plastic_key.dart';
import '../roll/roll_parts.dart';
import '../viewfinder/film_carousel.dart';
import '../viewfinder/film_shader_view.dart';
import '../viewfinder/tuning_panel.dart';
import '../viewfinder/viewfinder_state.dart';

/// Develops photos the person already took: the film live over the photo,
/// the same fine tuning as the camera, a finger held down to compare with the
/// original, and an export at full resolution into the own gallery.
///
/// The screen is always dark: the colours of a photo are
/// judged against a dark surround. The tuning starts as the camera has it for
/// each film and changes only here: the camera is not touched.
///
/// Nothing is kept until "develop" is pressed. Leaving earlier, or cancelling
/// the export, keeps nothing: the temporary copies are deleted and so is
/// whatever was already developed.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({required this.batch, this.onLeave, super.key});

  /// The photos that were chosen.
  final ImportBatch batch;

  /// Leaves the screen. Goes back to the previous screen when null.
  final VoidCallback? onLeave;

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  late final ImportStaging _staging;
  late final Map<String, FilmTuning> _tunings;
  String? _filmId;
  int _index = 0;
  bool _comparing = false;
  bool _tuningOpen = false;
  bool _notices = false;
  Timer? _noticeTimer;

  ImportRun? _run;
  ImportOutcome? _result;
  bool _leaving = false;

  // The size of the photo shown, learned when its picture is decoded.
  ImageStream? _sizeStream;
  ImageStreamListener? _sizeListener;
  String? _sizedPath;
  Size? _photoSize;

  List<ImportPhoto> get _photos => widget.batch.photos;

  ImportPhoto get _photo => _photos[_index];

  @override
  void initState() {
    super.initState();
    _staging = ref.read(importStagingProvider);
    _tunings = Map<String, FilmTuning>.of(ref.read(filmTuningsProvider));
    _notices = widget.batch.truncated || widget.batch.rejected > 0;
    if (_notices) {
      _noticeTimer = Timer(CarreteDurations.notice, () {
        if (mounted) setState(() => _notices = false);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _watchSize();
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    _unwatchSize();
    final run = _run;
    if (run != null && !run.finished) run.cancel();
    // The copies are the app's own and nothing is kept: whichever way the
    // screen ends, they go.
    unawaited(_staging.clear());
    super.dispose();
  }

  // --- the size of the photo -------------------------------------------------

  void _watchSize() {
    if (_photos.isEmpty) return;
    final path = _photo.path;
    if (_sizedPath == path) return;
    _unwatchSize();
    _sizedPath = path;
    _photoSize = null;
    final provider = ref.read(importPreviewProvider(path));
    final stream = provider.resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener(
      (info, _) {
        final size = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
        // The listener owns the handle it is given.
        info.dispose();
        if (mounted && _sizedPath == path && _photoSize != size) {
          setState(() => _photoSize = size);
        }
      },
      onError: (error, stack) {
        if (kDebugMode) debugPrint('Could not read an imported photo: $error');
      },
    );
    stream.addListener(listener);
    _sizeStream = stream;
    _sizeListener = listener;
  }

  void _unwatchSize() {
    final listener = _sizeListener;
    if (listener != null) _sizeStream?.removeListener(listener);
    _sizeStream = null;
    _sizeListener = null;
  }

  // --- actions ---------------------------------------------------------------

  FilmTuning _tuningOf(String filmId) =>
      _tunings[filmId] ?? FilmTuning.defaults;

  void _select(int index) {
    if (index == _index) return;
    setState(() {
      _index = index;
      _comparing = false;
    });
    _watchSize();
  }

  void _selectFilm(Recipe recipe) => setState(() => _filmId = recipe.id);

  void _tune(FilmTuning Function(FilmTuning current) change, String filmId) =>
      setState(() => _tunings[filmId] = change(_tuningOf(filmId)));

  void _setComparing(bool value) {
    if (_comparing != value && _run == null) setState(() => _comparing = value);
  }

  /// Leaves the screen, keeping nothing.
  Future<void> _leave() async {
    if (_leaving) return;
    final run = _run;
    if (run != null && !run.finished) {
      // An export in progress stops after its current photo and undoes the
      // rest; the screen waits for that.
      run.cancel();
      setState(() {});
      final outcome = await run.outcome;
      if (outcome.leftover > 0) {
        if (mounted) setState(() => _result = outcome);
        return;
      }
    }
    if (!mounted) return;
    _leaving = true;
    await _staging.clear();
    if (!mounted) return;
    final callback = widget.onLeave;
    if (callback != null) {
      callback();
    } else if (context.canPop()) {
      context.pop();
    }
  }

  void _develop(Recipe recipe) {
    if (_run != null) return;
    final settings = ref.read(settingsProvider);
    final tuning = _tuningOf(recipe.id);
    final first = DateTime.now();
    final jobs = [
      for (var i = 0; i < _photos.length; i++)
        importJobFor(
          photo: _photos[i],
          recipe: recipe,
          tuning: tuning,
          stampStyle: settings.dateStampStyle,
          includeLocation: settings.saveLocation,
          // Each photo has its own moment, so its own name and place in the
          // gallery.
          developedAt: first.add(Duration(milliseconds: i)),
        ),
    ];
    final run = ref.read(importDeveloperProvider).start(jobs);
    setState(() {
      _run = run;
      _tuningOpen = false;
      _comparing = false;
    });
    unawaited(run.outcome.then(_onOutcome));
  }

  void _onOutcome(ImportOutcome outcome) {
    if (!mounted || _leaving) return;
    // Photos that could not be removed are told, never left behind in silence.
    if ((outcome.cancelled || outcome.complete) && outcome.leftover == 0) {
      unawaited(_leave());
    } else {
      setState(() => _result = outcome);
    }
  }

  // --- building --------------------------------------------------------------

  /// What the screen shows while the book of films has not loaded: a spinner,
  /// or the failure, with the key to leave always in reach.
  Widget _buildBookState(AppLocalizations l10n, {required bool failed}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CarreteSpacing.margin,
            CarreteSpacing.s,
            CarreteSpacing.margin,
            0,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: PlasticKey(
              key: const ValueKey('import-close-key'),
              semanticLabel: l10n.importCloseLabel,
              onPressed: () => unawaited(_leave()),
              child: const CarreteIconView(icon: CarreteIcon.close),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(CarreteSpacing.margin),
              child: failed
                  ? Semantics(
                      header: true,
                      liveRegion: true,
                      child: Text(
                        l10n.filmsLoadFailed,
                        textAlign: TextAlign.center,
                        style: CarreteText.message,
                      ),
                    )
                  : Semantics(
                      label: l10n.filmsLoading,
                      liveRegion: true,
                      child: const SizedBox(
                        width: CarreteImport.spinner,
                        height: CarreteImport.spinner,
                        child: CircularProgressIndicator(
                          strokeWidth: CarreteImport.spinnerStroke,
                          color: CarreteColors.silk,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bookAsync = ref.watch(recipeBookProvider);
    final book = bookAsync.value;
    final resources = ref.watch(filmResourcesProvider).value;

    final Widget body;
    if (book == null) {
      body = _buildBookState(l10n, failed: bookAsync.hasError);
    } else {
      body = _buildWorkbench(book, resources);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        backgroundColor: CarreteColors.viewfinder,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: body),
              if (_run != null) _buildExportPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkbench(RecipeBook book, FilmResources? resources) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final recipe = selectedRecipe(book, _filmId ?? settings.defaultFilmId);
    final tuning = _tuningOf(recipe.id);
    final look = lookFor(recipe, tuning, CarreteFlash.off);
    final exporting = _run != null;

    return Column(
      children: [
        _buildTopBar(),
        const SizedBox(height: CarreteImport.barGap),
        Expanded(child: _buildPreview(recipe, tuning, look, resources)),
        if (_photos.length > 1) _buildStrip(),
        ExcludeSemantics(
          excluding: exporting,
          child: IgnorePointer(
            ignoring: exporting,
            child: FilmCarousel(
              recipes: book.recipes,
              selectedId: recipe.id,
              onSelected: _selectFilm,
              onTune: (r) {
                _selectFilm(r);
                setState(() => _tuningOpen = true);
              },
              thumbnailBuilder: (context, r) => FilmShaderView(
                cameraTexture: false,
                resources: resources,
                filmId: r.id,
                look: lookFor(r, _tuningOf(r.id), CarreteFlash.off),
                child: _photoImage(
                  ref.read(importThumbnailProvider(_photo.path)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: CarreteSpacing.s),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CarreteSpacing.margin,
            0,
            CarreteSpacing.margin,
            CarreteSizes.bottomInset,
          ),
          child: RollWideKey(
            label: l10n.importDevelopAction(_photos.length),
            onPressed: exporting ? null : () => _develop(recipe),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final exporting = _run != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CarreteSpacing.margin,
        CarreteSpacing.s,
        CarreteSpacing.margin,
        0,
      ),
      child: Row(
        children: [
          PlasticKey(
            key: const ValueKey('import-close-key'),
            semanticLabel: l10n.importCloseLabel,
            onPressed: exporting ? null : () => unawaited(_leave()),
            child: const CarreteIconView(icon: CarreteIcon.close),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: CarreteSpacing.s),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      CarreteText.upper(l10n.importTitle, locale),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CarreteText.labelStrong,
                    ),
                  ),
                  if (_photos.length > 1)
                    ExcludeSemantics(
                      child: Text(
                        l10n.importCounter(_index + 1, _photos.length),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: CarreteText.label,
                      ),
                    ),
                ],
              ),
            ),
          ),
          PlasticKey(
            key: const ValueKey('import-tune-key'),
            semanticLabel: l10n.importTuneLabel,
            selected: _tuningOpen,
            onPressed: exporting
                ? null
                : () => setState(() => _tuningOpen = !_tuningOpen),
            child: const CarreteIconView(icon: CarreteIcon.sliders),
          ),
        ],
      ),
    );
  }

  Widget _photoImage(ImageProvider provider) => Image(
    image: provider,
    fit: BoxFit.cover,
    alignment: Alignment.center,
    width: double.infinity,
    height: double.infinity,
    gaplessPlayback: true,
    excludeFromSemantics: true,
    errorBuilder: (context, error, stack) =>
        const ColoredBox(color: CarreteImportColors.window),
  );

  Widget _buildPreview(
    Recipe recipe,
    FilmTuning tuning,
    ResolvedLook look,
    FilmResources? resources,
  ) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final format = look.format;
    // The frame is what the export keeps: a centred crop of the photo to the
    // format of the film, as the camera does.
    final source = _photoSize ?? const Size(3, 4);
    final crop = frameCrop(format, source);
    final aspect = crop.width / crop.height;
    // The date printed is the one of the camera when the photo was taken; a
    // photo with no date gets none.
    final date = _photo.date;
    final stampText = look.dateStamp && date != null
        ? DateStamp.format(date.wall, settings.dateStampStyle)
        : null;
    final noDate = look.dateStamp && date == null;
    final whiteFrame = look.whiteFrame && format == FrameFormat.r1x1;
    final cinemaBands = look.cinemaBands && format.supportsCinemaBands;
    final filmName = recipe.name.of(context);
    final provider = ref.read(importPreviewProvider(_photo.path));

    return LayoutBuilder(
      builder: (context, constraints) {
        final frame = placeFrame(
          screen: constraints.biggest,
          aspect: aspect,
          topReserved: 0,
          bottomReserved: 0,
        );
        return Stack(
          children: [
            Positioned.fill(
              child: Semantics(
                container: true,
                button: true,
                label: l10n.importPhotoSemantics(
                  _index + 1,
                  _photos.length,
                  filmName,
                ),
                hint: l10n.importCompareHint,
                onTap: () => _setComparing(!_comparing),
                excludeSemantics: true,
                child: Listener(
                  key: const ValueKey('import-photo'),
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) => _setComparing(true),
                  onPointerUp: (_) => _setComparing(false),
                  onPointerCancel: (_) => _setComparing(false),
                  child: Stack(
                    children: [
                      Positioned.fromRect(
                        rect: frame,
                        child: ClipRect(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (_comparing)
                                _photoImage(provider)
                              else
                                FilmShaderView(
                                  cameraTexture: false,
                                  resources: resources,
                                  filmId: recipe.id,
                                  look: look,
                                  child: _photoImage(provider),
                                ),
                              if (!_comparing && stampText != null)
                                DateStampOverlay(
                                  text: stampText,
                                  cinemaBands: cinemaBands,
                                ),
                              if (!_comparing && cinemaBands)
                                const CinemaBandsOverlay(),
                              if (_comparing)
                                Positioned(
                                  left: CarreteImport.pillInset,
                                  top: CarreteImport.pillInset,
                                  child: _Pill(text: l10n.importOriginalPill),
                                ),
                              if (!_comparing && (whiteFrame || noDate))
                                Positioned(
                                  left: CarreteImport.pillInset,
                                  bottom: CarreteImport.pillInset,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (whiteFrame)
                                        _Pill(text: l10n.whiteFrameHint),
                                      if (whiteFrame && noDate)
                                        const SizedBox(
                                          height: CarreteSpacing.xs,
                                        ),
                                      if (noDate)
                                        _Pill(text: l10n.importNoDate),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_notices)
              Positioned(
                left: CarreteSpacing.margin,
                right: CarreteSpacing.margin,
                top: CarreteSpacing.s,
                child: Semantics(
                  liveRegion: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.batch.truncated)
                        _Pill(
                          text: l10n.importPickLimit(kImportLimit),
                          wrap: true,
                        ),
                      if (widget.batch.truncated && widget.batch.rejected > 0)
                        const SizedBox(height: CarreteSpacing.xs),
                      if (widget.batch.rejected > 0)
                        _Pill(
                          text: l10n.importRejected(widget.batch.rejected),
                          wrap: true,
                        ),
                    ],
                  ),
                ),
              ),
            if (_tuningOpen && _run == null)
              Positioned(
                left: CarreteSizes.panelMargin,
                right: CarreteSizes.panelMargin,
                bottom: CarreteSpacing.s,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * CarreteImport.panelShare,
                  ),
                  child: FilmTuningPanel(
                    recipe: recipe,
                    tuning: tuning,
                    effectiveFormat: format,
                    showFormat: true,
                    effectiveDateStamp: look.dateStamp,
                    effectiveCinemaBands: look.cinemaBands,
                    sampleStamp: DateStamp.format(
                      _photo.date?.wall ?? DateTime.now(),
                      settings.dateStampStyle,
                    ),
                    onChanged: (change) => _tune(change, recipe.id),
                    onClose: () => setState(() => _tuningOpen = false),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStrip() {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.importStripLabel,
      child: SizedBox(
        height: CarreteImport.stripThumbHeight + CarreteSpacing.s * 2,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: CarreteImport.stripPadding,
          itemCount: _photos.length,
          separatorBuilder: (_, _) =>
              const SizedBox(width: CarreteImport.stripGap),
          itemBuilder: (context, i) {
            final selected = i == _index;
            return Semantics(
              button: true,
              selected: selected,
              label: l10n.importStripItem(i + 1, _photos.length),
              onTap: () => _select(i),
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _select(i),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(CarreteRadii.thumbnail),
                    border: Border.all(
                      color: selected
                          ? CarreteColors.amber
                          : Colors.transparent,
                      width: CarreteImport.stripBorder,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(CarreteRadii.thumbnail),
                    child: SizedBox(
                      width: CarreteImport.stripThumbWidth,
                      height: CarreteImport.stripThumbHeight,
                      child: _photoImage(
                        ref.read(importThumbnailProvider(_photos[i].path)),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildExportPanel() {
    final l10n = AppLocalizations.of(context);
    final run = _run!;
    final result = _result;
    return Positioned.fill(
      // The panel names itself to a screen reader as soon as it opens.
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: l10n.importTitle,
        child: Stack(
          children: [
            const ModalBarrier(dismissible: false, color: CarreteColors.notice),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(CarreteSpacing.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: CarreteImport.resultMaxWidth,
                  ),
                  child: PlasticPlateSurface(
                    child: Padding(
                      padding: CarreteImport.resultPadding,
                      child: result == null
                          ? _buildProgress(run)
                          : _buildResult(result),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress(ImportRun run) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<ImportProgress>(
      valueListenable: run.progress,
      builder: (context, progress, _) {
        final title = progress.cancelling
            ? l10n.importCancelling
            : l10n.importProgress(progress.current, progress.total);
        final fraction = progress.total == 0
            ? 0.0
            : progress.done / progress.total;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              header: true,
              child: Text(title, style: CarreteText.panelTitle),
            ),
            const SizedBox(height: CarreteSpacing.m),
            ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(CarreteRadii.track),
                child: SizedBox(
                  height: CarreteImport.progressHeight,
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: ColoredBox(
                          color: CarreteImportColors.progressTrack,
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: fraction,
                        child: const ColoredBox(color: CarreteColors.amber),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: CarreteSpacing.l),
            RollWideKey(
              label: l10n.dialogCancel,
              onPressed: progress.cancelling ? null : run.cancel,
            ),
          ],
        );
      },
    );
  }

  Widget _buildResult(ImportOutcome result) {
    final l10n = AppLocalizations.of(context);
    final none = result.developed == 0;
    final leftover = result.leftover > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            leftover
                ? l10n.importLeftoverTitle
                : none
                ? l10n.importFailedTitle
                : l10n.importPartialTitle,
            style: CarreteText.panelTitle,
          ),
        ),
        const SizedBox(height: CarreteSpacing.s),
        Text(
          leftover
              ? l10n.importLeftoverBody(result.leftover)
              : none
              ? l10n.importFailedBody
              : l10n.importPartialBody(result.developed, result.total),
          style: CarreteText.row,
        ),
        const SizedBox(height: CarreteSpacing.l),
        RollWideKey(
          label: l10n.importOpenGallery,
          onPressed: () => unawaited(_leave()),
        ),
      ],
    );
  }
}

/// A short label over the picture, like the hints of the viewfinder.
class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.wrap = false});

  final String text;

  /// Whether the text may take several lines (a long notice).
  final bool wrap;

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
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: wrap ? 3 : 1,
          overflow: TextOverflow.ellipsis,
          style: CarreteText.hint,
        ),
      ),
    );
  }
}
