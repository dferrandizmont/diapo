# Selector sources and QA handoff

All app message keys below refer to `lib/l10n/app_es.arb`; their use was checked
against the targeted widgets in `lib/screens/`. Selectors are Java regular
expressions: `.*` permits accessibility hints merged by Flutter, punctuation is
escaped, and `(?i)` permits the contact sheet's uppercase text. Numeric examples
are actual substitutions of the ARB placeholders/plurals.

## App labels

| Label or instantiated pattern | ARB key(s) | Used by |
| --- | --- | --- |
| `Saltar` | `onboardingSkip` | shared start |
| `Paso 1 de 3`, `Paso 2 de 3`, `Paso 3 de 3` | `onboardingStepSemantics` | onboarding |
| `Una cámara, no un filtro.` | `onboardingTitle1` | onboarding |
| `Elige la película y afínala.` | `onboardingTitle2` | onboarding |
| `Un carrete: fotos sin mirar.` | `onboardingTitle3` | onboarding |
| `Siguiente` | `onboardingNext` | onboarding |
| `Empezar a disparar` | `onboardingStart` | onboarding |
| `Disparar` | `shutterLabel` | shared capture, camera checks |
| `Ninguna foto en esta sesión`, `Una foto en esta sesión`, `2 fotos en esta sesión` | `cameraCounterSemantics` | shared start, onboarding, shoot, deletion |
| `Galería` | `galleryTitle` | camera/gallery navigation and lock checks |
| `Ajustes` | `settingsTitle` | camera/settings navigation and lock checks |
| `Fotos sueltas` | `galleryLooseLabel` | day card selectors and absence checks |
| `Hoy` | `galleryToday` | shoot, deletion day cards |
| `1 foto`, `2 fotos`, `12 fotos` | `rollFramesCount` | day cards, contact sheet, roll length |
| `Fotograma 1`, `Fotograma 2`, `Fotograma 3` | `frameSemantics` | contact sheets; third frame must be absent |
| `Foto 1 de 1`, `Foto 1 de 2` | `viewerSemantics` | viewer checks |
| `Compartir` | `viewerShare` | shoot, instant roll |
| `Borrar` | `viewerDelete`, `viewerDeleteConfirm` | viewer and delete confirmation |
| `¿Borrar esta foto?` | `viewerDeleteTitle` | deletion |
| `No encuentro este día` | `galleryDayMissingTitle` | deleted day's empty route |
| `Aún no hay fotos` | `galleryEmptyTitle` | discard baseline/result, deletion result |
| `Cargar un carrete` | `rollKeyLoad` (sheet title: `rollLoadTitle`) | onboarding, rolls, disposable |
| `Cargar carrete` | `rollLoadAction` | both roll flows |
| `Al momento` | `delayInstant` | instant roll, disposable |
| `1 hora` | `delayOneHour` | discard roll |
| `Quedan 10/11/12/26/27 fotos` | `rollCounterSemantics` | roll/disposable counters |
| `Carrete cargado, quedan 10 fotos`, `Carrete cargado, quedan 11 fotos` | `rollKeyOpen` | loaded roll sheet |
| `Cerrar y revelar` | `rollCloseAction` | instant roll |
| `Hoja de contactos` | `contactSheetTitle` | instant roll |
| `Tirar el carrete` | `rollDiscardAction` | discard roll |
| `¿Tirar el carrete?` | `rollDiscardTitle` | discard confirmation |
| `Tirar` | `rollDiscardConfirm` | discard confirmation |
| `Carrete [0-9]+,.*` | `rollNumberTitle` + `rollFramesCount` | absence of roll gallery cards after discard |
| `Cámara desechable` | `disposableOption` (dialog title: `disposableStartTitle`) | disposable entry |
| `Tiene 27 fotos y una película fija.` (prefix) | `disposableStartBody` | disposable start dialog |
| `Empezar` | `disposableStartAction` | disposable start |
| `Salir de la cámara desechable. Mantén pulsado durante dos segundos.` | `disposableExitSemantics` | exit stamp presence |
| `¿Salir de la cámara desechable?` | `disposableExitTitle` | exit confirmation |
| `Quedan 26 fotos, que se guardan para más tarde.` (prefix) | `disposableExitBody` | exit confirmation |
| `Salir` | `disposableExitConfirm` | exit confirmation |
| `Seguir con la desechable` | `disposableResume` | paused disposable's roll sheet |
| `Formato 3:2`, `Formato 4:3`, `Formato 1:1`, `Formato 16:9` | `formatKeyLabel` | format cycle |
| `Flash: Apagado/Automático/Encendido/Fiesta` | `flashKeyLabel` + `flashOff`/`flashAuto`/`flashOn`/`flashParty` | flash selection |
| `Cuadrícula` | `settingGrid` | grid toggles |
| `Nivel` | `settingLevel` | settings |
| `Sonidos de la cámara` | `settingCameraSounds` | settings |
| `Guardar también el original` | `settingSaveOriginal` | settings |
| `Día primero: .*`, `Año primero: .*` | `dateStyleSemantics` + `dateStyleDayFirst`/`dateStyleYearFirst` | date tiles |
| `Oscuro`, `Claro` | `themeDark`, `themeLight` | theme selection |
| `Català`, `Español` | `languageCatalan`, `languageSpanish` | language selection; names stay identical in Catalan |
| `Licencias` | `settingsLicences` | licence entry and return |
| `Carrete` | `appTitle` | application name on Flutter's licence page |
| `Revelar fotos del móvil` | `galleryImportRow` | import entry/return |
| `Revelar la foto` | `importDevelopAction` (count 1) | import action |
| `Foto 1 de 1, con la película Diapositiva fría` | `importPhotoSemantics` + recipe name below | import preview |

Day cards merge `galleryLooseLabel`, a day title, recipe names and
`rollFramesCount` with commas in `GalleryCard`. Film buttons can append
`filmCartridgeHint` (`Mantén pulsado para los ajustes finos`); format buttons
can append `formatKeyHint` (`Cambia el formato del encuadre`). The patterns
permit those real hints without requiring their exact accessibility merging.

## Values that do not have ARB keys

The brief's ARB-only rule cannot literally cover film names or generated dates:
the production app sources these elsewhere. No labels were added to Dart.

| Value/pattern | Actual source |
| --- | --- |
| `Verano 98` | `packages/film_recipes/assets/recipes.json`, recipe `verano-98`, `name.es` |
| `Diapositiva fría` | same file, recipe `diapositiva-fria`, `name.es` |
| `Caducada` | same file, recipe `caducada`, `name.es` |
| Film + ` · ` + date/time | `FrameViewer._info`: recipe name, Material `formatMediumDate` and `formatTimeOfDay`; regex requires date digits and `h:mm`/`hh:mm` |
| Date tile's sample | `DateStamp.format`, interpolated into `dateStyleSemantics` |
| `3:2`, `4:3`, `1:1`, `16:9` | `FrameFormat` wire names, interpolated into `formatKeyLabel`; actual cycle order is 3:2, 4:3, 1:1, 16:9 |
| `Photo taken on` | Android Photo Picker thumbnail accessibility description; first match, if present |
| `Done`, `Listo`, `Añadir`, `Agregar`, `Add` | System picker confirmation alternatives; OS-owned, possibly followed by the count |

`back` is a Maestro navigation command, so it does not target an invented
`Atrás` ARB key (the app gets that tooltip from MaterialLocalizations).

## Validation and remaining device work

- All 11 flow/subflow files passed Maestro 2.12.1 `check-syntax`.
- The installed CLI's `test --help` confirms `--device`, `--format JUNIT` and
  `--output`. Shell syntax and runner argument handling were checked without a
  device. Maestro's workspace planner also parsed the full flows and their
  references, loaded `config.yaml`, and selected exactly the nine entry flows.
- The Windows launcher/bootstrap could not write its default analytics/log
  directories under the sandbox. Validation invoked the installed CLI's own
  `CheckSyntaxCommand` through its Picocli entry point using a temporary Java
  launcher outside the worktree. This performs the same Maestro syntax check,
  without starting analytics, logging or a device session.
- Full workspace loading rejects a whole coordinate supplied as `${VARIABLE}`
  even though `check-syntax` accepts it. Both coordinate fallbacks therefore
  use literal percentages, with comments identifying what to calibrate.
- No device commands, Flutter tests, builds or Dart edits were performed.

No requested navigation step was skipped. The exit hold and an unlabelled picker
thumbnail use the brief's coordinate fallback, with commented calibration points.
Full device execution is still required; syntax success does not verify the
accessibility tree or camera/export behavior.

On the emulator and phone, check:

- The exit stamp centre (`swipe.start`/`swipe.end`) and stationary 2500 ms swipe really
  hold the pointer for at least 2 seconds. `longPressOn` in 2.12.1 has no duration
  parameter. The flow asserts the stamp label and the resulting confirmation.
- The system picker is ready after its animation; adjust the first-thumbnail
  point and confirmation alternatives for the Android version/OEM. Select one
  supported, local, readable image. Its original date may place the result in
  an older app-gallery day, which the import assertion permits.
- Flutter exposes `selected` and `checked` for cartridges, keys, date tiles and
  switches as expected. Carousel scrolling, licence return position and large
  accessibility text may need tuning on smaller displays.
- Camera startup, shutter re-enabling and export/develop waits suit the device.
  A session counter can advance before saving; gallery/contact-sheet assertions
  deliberately wait for the saved result. The deletion flow also assumes
  Android accepts deletion of a photo just created by this app without another
  system confirmation.

The flows check film/date text presence, counts, UI state and navigation. They
do not assert pixel appearance, audible sounds, physical flash behavior, exact
date values, MediaStore contents outside the app, encryption or privacy. Those
remain for device QA and `test-like-a-human`.
