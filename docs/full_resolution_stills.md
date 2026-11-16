# Full-resolution stills

Production capture, rolls and imports share `FilmCaptureProcessor` and
`FilmStillRenderer.renderTiles`, with an optional single-pass consumer. The
benchmark renderer is independent.

## Small-still fast path

After one bounded decode, production selects a single full-target render when
**both the decoded source and final output fit 24,000,000 pixels and 8192 pixels
per side**. The output check includes the white border. A crop cannot opt a
larger input texture into the old full-frame working set, and a border cannot
exceed that budget or the legacy encoder's texture-side guard. Larger images
retain their resolution and use 1024-pixel tiles; no second decode is needed.

The small path uses the same drawing function, crop coordinates, date patch and
shader as the tiles, directly rendering the entire output once. It avoids the
previous intermediate crop and border composition images. It reads one
premultiplied `rawRgba` buffer, releases the source, shader, date patch and full
GPU target, then calls the existing `saveRgbaAsJpeg` (`beginSave` followed by one
headerless binary pixel message). Android's legacy `copyPixelsFromBuffer`
expects premultiplied pixels; the tile sink's `setPixels` still receives straight
RGBA. Keeping those contracts preserves transparent imports on both paths.

At 24 MP, the single-pass path retains the old approximate 288 MB transfer
budget (Dart pixels, transport copy, native bitmap), with asynchronously disposed
GPU resources subject to the caveats below. A 3008 x 3008 output replaces nine
tile renders/readbacks and nine header/copy/conversion messages with one render,
one readback and one direct-buffer message. These are operation counts, not
measured latency savings. `CARRETE_PERF capture` labels the selected path
`single` or `tiled` in debug/profile builds.

## Limits

- Decoded source: **50,000,000 pixels**, **8192 pixels per side**. An
  8160 x 6120 Pixel original (49,939,200 pixels) keeps every pixel before the
  selected frame's intentional crop. These limits bound the one input texture;
  8192 remains the conservative supported texture dimension. The codec is
  asked for the bounded dimensions, and its returned dimensions are checked.
- Imports/capture originals: unchanged **100 MiB file**, **200 MP JPEG** or
  **100 MP other formats**. Header rejection happens before decoding. Larger
  accepted originals decode down to the output guard; 200 MP is an acceptance
  limit, not a promise of 200 MP export. Non-JPEG decoder scratch allocations
  can still depend on the source dimensions, as before.
- Large-output tiles: **1024 x 1024** maximum, including border tiles. There is no
  complete cropped or shaded GPU target and no complete Dart RGBA output in
  tiled production path. The small path reads a complete bounded target;
  the reference helper `render` assembles tiles into Dart pixels.
- Native output: **50 MP**, **8192 pixels per side**, checked before allocation.
  Only prints explicitly marked `framed` may use **71 MP**, **10324 pixels per
  side**, accommodating a maximum 50 MP square photo plus the existing
  1.12 x 1.26 white border. The border adds canvas, never reduces photo pixels.

## Coordinates and neighbouring samples

Float slots 0-38 are unchanged. All three uniform mirrors append:

| Slots | Meaning |
| --- | --- |
| 39-40 | Whole photo size, before the white border; zero selects engine size |
| 41-42 | Tile origin in whole-photo pixels (can be negative in the border) |
| 43-46 | Normalized source crop: left, top, width, height |

`uSize` is the current render target size (engine-owned for filters). Grain,
leak, vignette and halation use `(FlutterFragCoord + tileOrigin) / frameSize`.
The seed remains fixed for the entire photo. Sampling maps those coordinates
through the source crop; samples clamp at the crop's edge texel centres.

**Halation needs no output overlap:** every tile's sampler references the
same complete decoded input texture, not a cropped input tile. Both rings of
all eight blur directions can read across every output tile edge, even at the
largest recipe radius. An implementation that later region-decodes the input
must add an input halo of at least `ceil(radius * wholeShortSide) + 1` pixels
(the extra pixel covers bilinear sampling), before applying the source crop.

The date's blurred strokes are rasterized once into a small transparent patch,
with whole-frame placement and integer bounds padded by three blur sigmas and
half the glow stroke. This avoids clip-dependent stroke rasterization at tile
edges. Each tile composites the same patch at its global position. The white
border is filled directly in the output tiles.

## Encoding and lifetime

For the large path, `beginTiledSave` sends metadata and obtains a token. Each acknowledged binary
message on `carrete/media/tiles` contains five little-endian int32 values
(token, x, y, width, height), then straight RGBA bytes. Dart waits for its reply
before rendering another tile. The maximum transport copy is 4 MiB.

Android consumes the direct buffer inside the handler with an `IntBuffer` bulk
read per row, swaps R/B in an ARGB int array (at most 4 KiB), and writes into one
native `Bitmap` with `setPixels`. Dart explicitly reads `rawStraightRgba`;
`setPixels` performs the only alpha premultiplication during transport. No Java
frame-sized array, tile list or full-frame transport buffer
is retained. The raster validator rejects wrong order, missing/duplicate tiles,
bad dimensions and byte counts. Stale tokens cannot write a newer session.
Only the last tile triggers JPEG encoding and the existing EXIF/publication
path on the worker. Partial bitmaps are recycled on cancel, transport failure,
a new begin, channel disposal, or a main-looper watchdog after more than 60 s
without an accepted tile. The watchdog resets after each accepted tile and is
removed on completion/cancel/disposal. Session ownership transfers only after
the encoder executor accepts the final task, so rejection also recycles.
Encoding success or failure also recycles.
Both save protocols canonicalize any EXIF `sourcePath` and require a file under
the app cache. Legacy `beginSave` serves small stills and benchmarks with the same
developed-name validation and the unframed 50 MP / 8192 px bounds.
The capture queue serializes complete render/save operations. Existing retry
and original-retention behavior therefore still applies. iOS native encoding
remains pending, as it was before this change.

## Memory estimate (decimal MB)

These are live-buffer estimates, not measured process PSS; codec scratch,
engine caching, GPU driver allocations, JPEG workspace and the running app
must be added. GPU disposal is asynchronous. A 50 MP RGBA image is 200 MB.

| Stage | Previous 24 MP path | Raising old path to 50 MP | New 50 MP tiled path |
| --- | ---: | ---: | ---: |
| Crop / shade, two full GPU images | 192 | 400 | 200 source + 4.2 tile |
| RGBA transfer and native JPEG bitmap | 288 | 600 | 200 source + 200 bitmap + about 17 tile buffers |

The new rendering/transfer working set is approximately **417 MB**, plus the
small date patch (normally below 5 MB). At 24 MP it is approximately 209 MB.
The pathological square print reserves up to 282 MB for the native bitmap;
with its 200 MB source and tile buffers this is approximately **500 MB**.
Neither production path creates a second complete output image to compose the border.

Conservatively allow another **200 MB** if the engine retains a decoded CPU
copy as well as the input texture, plus up to two encoded-file copies (the
Dart bytes and immutable decoder buffer, at most 100 MiB each). Decode of
non-JPEG sources can have additional format-dependent scratch. Thus 417 MB
is not a process-memory guarantee. The fixed area/side/file guards and
sequential tiles prevent growth with an unbounded source or tile count;
actual supported-device headroom requires measurement.

## Validation and device follow-up

`tiled_still_test.dart` compares all RGBA channels with a whole-target pass
for every recipe at intensities 0.5 and 1, a fixed photo seed, odd source
sizes, partial edge tiles, a centred crop, a date crossing tile boundaries,
and a square print with a white border. An independent copy of the previous
crop/full-target/print path also serves as the reference, including 16:9,
an EXIF-rotated JPEG and transparent PNG with mid alpha (one and many tiles).
Its readback uses straight RGBA to correct the reviewed alpha bug.
Maximum permitted difference: 2.
The same fixtures also exercise the production single-pass callback (converting
its premultiplied pixels back to straight RGBA for comparison). End-to-end
processor tests assert that a 3008 x 3008 still uses `beginSave` and one pixel
message, while a 6000 x 4001 source uses tiles even with a 24 MP crop. Selection
unit tests cover exact area/side boundaries and enlarged prints.
The recipe reference goldens must pass unchanged; do not regenerate them.
Dart transport tests check headers, pixels and errors; JVM tests check raster
assembly, tile order, edge tiles, byte counts, bulk ARGB conversion with mid
alpha, separate photo/print limits, and canonical EXIF cache containment.

On both Pixel 10 Pro and OnePlus, measure a real 8160 x 6120 original using
plain 4:3, a heavy halation/grain recipe with a date, and a square white print.
Record time from shutter/export to saved URI (`CARRETE_PERF ... total`, plus
native encode/exif/write timings where collected), peak Android process PSS,
Java/native/GPU memory, and repeated captures after returning to idle. Use a
profile build and sample throughout decode, shading, transport and encoding;
a single post-save reading misses the peak. Check saved dimensions, view
seams at 100%, retry after interrupted export, and record thermal state and
whether the OnePlus camera plugin actually exposes a 50 MP original. If it
only captures 12 MP, exercise the same 50 MP file through import.

For the small-path regression, repeat the OnePlus 10 Pro 3008 x 3008 square
release capture using the same film, settings, thermal state and shutter-to-
MediaStore polling as the lead's baseline. Record cold and warmed shots
separately, with at least three comparable warmed shots: tiled main measured
3.08 / 2.77 / 2.85 s and alpha.3 measured 3.05 / 2.45 / 2.07 s (both include about
0.3 s polling). Compare medians and peak PSS; check dimensions, date and border.
Use a profile run to confirm the `single` label and stage timings. Also repeat
one 50 MP import to confirm `tiled`, unchanged resolution, latency and memory.

## Changed files

- `lib/capture/still_bounds.dart`: 50 MP decode guard.
- `lib/capture/film_still_renderer.dart`: tile rendering, date patch and cleanup.
- `lib/capture/film_capture_processor.dart`: sequential native tile sink/cancel.
- `shaders/film.frag`, `lib/render/film_uniforms.dart`,
  `packages/film_recipes/lib/src/uniforms.dart`: shared coordinate contract.
- `lib/render/look_adjust.dart`: forwards frame/tile/crop uniforms.
- `lib/platform/media_store.dart`: binary tile protocol.
- `android/app/src/main/kotlin/io/github/dferrandizmont/carrete/MediaChannel.kt`:
  bitmap session, tile acknowledgements, encoding and cancellation.
- `android/app/src/main/kotlin/io/github/dferrandizmont/carrete/TileRaster.kt`:
  bounded raster validation and row conversion.
- `android/app/src/main/kotlin/io/github/dferrandizmont/carrete/SaveSource.kt`:
  shared canonical EXIF source validation for both save protocols.
- `test/render/tiled_still_test.dart`, `test/capture/still_bounds_test.dart`,
  `test/platform/media_store_test.dart`,
  `packages/film_recipes/test/uniforms_test.dart`,
  `android/app/src/test/kotlin/io/github/dferrandizmont/carrete/TileRasterTest.kt`:
  rendering, guards, protocol, uniform order and native raster tests.
- `android/app/src/test/kotlin/io/github/dferrandizmont/carrete/SaveSourceTest.kt`:
  canonical cache paths, traversal and sibling-prefix rejection.
- `test/render/fixtures/chart_exif_6.jpg`: deterministic 241 x 163 gradient,
  EXIF orientation 6 (upright 163 x 241), generated for the rotation regression.
- `CHANGELOG.md`, `docs/full_resolution_stills.md`: user change and design.

## Initial implementation verification (2026-11-14)

All checks used `heavy.sh`, except formatting and the whitespace check.

- `dart format` / format check of the 11 changed Dart files: passed.
- `flutter analyze --no-pub` of the 11 changed Dart files: no issues.
- `flutter test --no-pub test/render/tiled_still_test.dart
  test/capture/still_bounds_test.dart test/platform/media_store_test.dart`:
  **29 passed**. This includes 40 tiled/whole-target recipe comparisons
  (10 recipes, two intensities, plain date / square date with white print),
  maximum permitted channel difference 2.
- In `packages/film_recipes`, `dart test`: **154 passed**, including the
  existing golden images. No goldens were generated or changed.
- `flutter build apk --debug --no-pub` was attempted first because the
  Android wrapper was absent. It failed before compilation because its
  default Gradle home resolved to an unavailable `C:/` cache.
- `:app:testDebugUnitTest` was then attempted offline with the installed
  Gradle distribution, shared read-only dependency cache and temporary state.
  After loading the Android configuration, it remained **blocked before app
  compilation**: Gradle could not create `build/app/intermediates/flutter/debug`
  and could not move its problem report into `build/reports/problems`
  (`AccessDeniedException` in this managed Windows sandbox). Android JVM tests
  and native app compilation therefore remain unverified. Run them in the
  lead's normal build environment; the three new `TileRasterTest` cases have
  not yet executed.
- Device save latency and peak process/GPU memory have not been measured.

The lead subsequently built the debug APK and passed the Android JVM tests
before review round 1.

## Review round 1 verification (2026-11-14)

- Format check of the five changed Dart files: passed.
- `heavy.sh flutter analyze --no-pub` of those files: no issues.
- `heavy.sh flutter test --no-pub test/render/tiled_still_test.dart
  test/capture/still_bounds_test.dart test/platform/media_store_test.dart
  test/capture/film_capture_processor_test.dart`: **44 passed**. Includes 100
  comparisons against the previous single-pass pipeline, with a maximum
  permitted channel difference of 2, and 40 tiled/whole-target comparisons.
- In `packages/film_recipes`, `heavy.sh dart --suppress-analytics test`:
  **154 passed**, including all unchanged reference goldens.
- In `android`, `heavy.sh ./gradlew :app:testDebugUnitTest --offline
  --no-daemon`: **blocked before compilation**. After obtaining its queue turn,
  the wrapper failed to open
  `C:\.gradle\wrapper\dists\gradle-9.3.1-all\9ot9r568e8zfvvd4mn8rbu1j0\gradle-9.3.1-all.zip.lck`
  (`FileNotFoundException`). The new mid-alpha/bounds cases in `TileRasterTest`
  and `SaveSourceTest` have not executed in this session. Executor rejection
  cleanup and watchdog scheduling were checked by code inspection; their
  Android lifecycle behavior has no automated coverage in the JVM suite.

## Small-still fast-path verification (2026-11-14)

- Format check of the seven changed Dart files: passed.
- `heavy.sh flutter analyze --no-pub` of those files: no issues.
- `heavy.sh flutter test --no-pub test/render/ test/capture/ test/platform/`:
  **157 passed**, including the real 3008-square/large-source protocol selection
  tests and the extended pixel equivalence checks. Channel differences remain
  within the existing tolerance of 2; reference goldens were not regenerated.
- In `packages/film_recipes`, `heavy.sh dart --suppress-analytics test`:
  **154 passed**, including all reference goldens.
- Since `android/gradlew` was absent, `heavy.sh flutter build apk --debug
  --no-pub` ran once and generated the wrapper, but could not compile. Both
  that build and the subsequent `heavy.sh ./gradlew :app:testDebugUnitTest
  --offline --no-daemon` were blocked opening the wrapper lock under
  `C:\.gradle\wrapper\dists\gradle-9.3.1-all` (`FileNotFoundException`). No
  native files changed; JVM tests remain to be run in the lead's environment.
- The initial tool invocations also hit a read-only Dart telemetry directory.
  Pointing the tool process's `APPDATA` at a temporary directory with Dart
  analytics disabled allowed the Dart checks to complete.
- Device latency and peak PSS remain unmeasured; use the follow-up above.
