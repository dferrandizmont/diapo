# Project conventions

Carrete (code name; the commercial name is pending) is a free film camera for
Android and iOS in Flutter: pick a film before shooting, see it live in the
viewfinder, optionally wait for the roll to "develop". A camera, not a filter
app. Product spec: private notes of the owner (Spanish; the path is in
`CLAUDE.md`, which is not published) and their shared rules.

## Rules

- **Privacy first.** No accounts, servers, analytics or network calls. Photos
  never leave the device. Undeveloped roll photos stay encrypted in app storage
  and never reach the system gallery before developing.
- **Free and complete.** No feature, film or format behind a payment. No ads
  unless Daniel approves a gallery banner on a screenshot (`google_mobile_ads`
  is not a dependency until then). No watermark, ever.
- **Trademarks.** Films have their own names. Never use names, logos or box art
  of film or camera makers (Kodak, Fuji, Polaroid, Ilford, Lomo, Leica...).
- **Shader contract.** `shaders/film.frag` renders both the live viewfinder
  (ImageFilter on the camera preview) and the full-resolution still (paint
  shader). Its uniform layout is mirrored in `lib/render/film_uniforms.dart`;
  change both together. Everything that shapes the look (grain, vignette, leak,
  halation) is expressed relative to the frame, never in pixels, so preview and
  saved photo match.
- **Recipes are data.** Film recipes live in versioned JSON validated against a
  schema; adding a film must not touch code. Reference-image tests guard every
  recipe against unintended changes.
- **No hard-coded UI text.** Strings go in ARB files (`lib/l10n`, Spanish is the
  source; Catalan and English translated). No emojis in UI, notifications or
  store text.
- **Dependencies.** Add one only with a reason; prefer maintained packages with
  a permissive licence (Apache-2.0, MIT, BSD).
- **No secrets** in the repository: no keys, keystores, tokens or `.env` files.
- **Language.** Code, comments, commit messages and docs in English.
- **Changelog.** Every user-visible change goes to `CHANGELOG.md` ("Unreleased",
  in English) in the same commit.
- **Commits.** Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`,
  `test:`), small and focused.
- **Heavy commands** (tests, analyze, builds) run through
  `sh ~/.agents/scripts/heavy.sh <command>`.

## Commands

```sh
flutter pub get
dart format .
sh ~/.agents/scripts/heavy.sh flutter analyze
sh ~/.agents/scripts/heavy.sh flutter test
(cd packages/film_recipes && dart pub get && dart test)
```

Run `dart pub get` inside `packages/film_recipes` once after cloning: without it the root `flutter analyze` reports hundreds of unresolved imports in the package tests.

The generated code is committed, so it is rebuilt when a table, a recipe or a
text changes:

```sh
dart run build_runner build          # the Drift code (lib/core/database)
dart run drift_dev make-migrations   # the steps of the migrations (build.yaml)
flutter gen-l10n                     # the texts (lib/l10n/*.arb)
```

`dart format --output=none --set-exit-if-changed .`, `flutter analyze` (no
issues) and `flutter test` must pass before a change is merged.

## Layout

| Path | What |
| --- | --- |
| `shaders/film.frag` | The single-pass film shader. |
| `lib/app.dart` | The app shell: `MaterialApp.router`, the languages and the theme. |
| `lib/core/router.dart` | The routes of the app (go_router). |
| `lib/core/settings/` | The settings of the app and the repository that stores them. |
| `lib/core/database/` | The local database (Drift): the rolls, the photos and the rules of both; the `ShotVault` interface and its provider. |
| `lib/core/vault/` | `EncryptedShotVault`: the undeveloped photos, AES-256-GCM files with random names under `<support dir>/vault/`, key in the platform keystore (`flutter_secure_storage`). Excluded from Android backups (`android/app/src/main/res/xml/`). |
| `lib/l10n/` | The texts of the app (ARB files; Spanish is the source). |
| `lib/screens/` | The screens of the app: `viewfinder/` (the camera), `settings/`, `roll/` (a roll, its contact sheet and the full-size viewer with share and delete) and `gallery/` (the own gallery and the contact sheet of a day). |
| `lib/gallery/` | What the gallery shows (`buildGalleryContent`: developed rolls and days of loose photos) and `PhotoLibrary` (share and delete a photo, keeping the database and the system gallery in step). |
| `lib/screens/viewfinder/` | The camera screen: frame, top bar, film carousel, fine-tuning panel. |
| `lib/screens/settings/` | The settings screen (follows the system theme): grid, date style, default film, theme, language, about. Only settings that work are listed. |
| `lib/screens/onboarding/` | The tutorial (three screens), reached from the settings; a new user goes straight to the camera. The flag is `onboardingSeen` in the settings: it only says whether the tutorial was seen, and while it is false the camera shows the hint about swiping the films. The hint and the offer of a roll of 12 (`first_minute_cards.dart`) are remembered by `lib/core/settings/first_minute.dart`, outside the settings and their export. |
| `lib/camera/` | `CameraService` (interface + `camera` plugin), flash modes, frame formats and crops; `level_tilt.dart`: the accelerometer filter and source of the level. |
| `lib/capture/` | Capture queue, full-resolution developing (bounded to 24 MP / 8192 px), date imprint, white frame, failed shots kept in `cache/failed/` and retried on start. Loose photos are recorded in `Shots` (`rollId` null) by `LooseShotRecorder` once they are saved. |
| `lib/review/` | The request for a store review: `ReviewPolicy` (pure rules: days since the first open, open days, own work, silence after a settings import, limits per version and per period), `ReviewService` (records the opens, asks at a success moment, never shows an error) and the `StoreReviewPlatform` interface over `in_app_review`. The counters (calendar days and numbers only, never exported) live in `lib/core/settings/review_state.dart`. |
| `lib/roll/` | Roll service and providers, serialized capture/develop/discard operations, foreground developer with progress, local readiness notifications and plaintext temp cleanup. |
| `lib/roll/disposable.dart` | The disposable camera: 27 frames, the fixed film and tuning, the lock (`DisposableLock`, kept in the preferences) that makes the router lead only to `/disposable`. A disposable is a roll with `RollMode.disposable`; `RollService.openDisposable` opens it. |
| `lib/screens/disposable/` | The disposable camera screen (design C: kraft and paper), its parts and the start dialog. |
| `lib/import/` | Develop photos from the gallery: the picker (`image_picker`, Photo Picker of the system, no read permission), the staging folder `<cache>/import/`, the date choice, the job per photo and the one-at-a-time export with undo. |
| `lib/screens/import/` | The import screen: live film over the photo, carousel, tuning panel, hold to compare, progress. Reached from the gallery. |
| `lib/ui/` | Theme A tokens (`theme/`; every colour, size, radius and duration of the widgets lives there; `disposable_tokens.dart` has the tokens of design C for the disposable mode) and the plastic controls (`widgets/`). |
| `lib/render/` | Uniform contract, still renderer (full resolution). |
| `lib/platform/` | Platform channels (`carrete/media` + the binary `carrete/media/pixels`: JPEG encode, EXIF without GPS unless asked, gallery, read back, share and delete of the app's own album; `carrete/system`: open the system settings of the app, the ringer mode and the camera sounds, played by `CameraSounds.kt`; the sounds are generated by `tool/generate_sounds.dart`). |
| `lib/poc/` | Proof-of-concept screen and benchmark, route `/bench` (`--dart-define=CARRETE_BENCH=true` opens it at start). |
| `packages/film_recipes/` | Pure-Dart recipe engine (JSON, schema, interpolation). |
| `drift_schemas/` | The snapshot of the schema of the database, one file per version. |
| `android/app/src/main/kotlin/.../MediaChannel.kt` | Native encode and MediaStore save. |
