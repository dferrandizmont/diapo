# Test like a human · Diapo 0.1.0 (6)

- **Verdict:** PASS, with one major failure (F1) for Daniel to decide on before production
- **Date:** 2026-11-16 · **Commit:** 1cd0cfd · **Level:** full (first store version)
- **Layer 1 target:** every screen, with extra attention to the changes since `v0.1.0-alpha.5`
  (77 files in `lib/`). These are: the rename to Diapo (album `Pictures/Diapo`), the store review
  request, the privacy policy and legal notice pages, the GPL notice and Diapo's Licences entry,
  roll names, contact sheet sharing, the reveal, the save status chip and recovery sheet, the
  settings regrouping ("Avanzado"), the first-minute hint and the roll offer.
- **Devices:**

| Device | Type | OS / API | Build | Layer 0 | Layer 1 |
|---|---|---|---|---|---|
| Pixel-class AVD `Carrete_Phone` (emulator-5554) | emulator | Android 16 / 36, es-US | profile (built from 1cd0cfd) | ✅ 45/45 flow runs, monkey clean, 0 log errors | ~95 actions, ~25 min (Sonnet) |
| OnePlus 10 Pro | physical | Android 15 / 35, English, system dark | **release** `app-release.apk` (sha1 0c7d6ae1…) | no Maestro (owner's phone): adb conditions only | ~85 actions, ~25 min (Sonnet) |

- **Cold start:** OnePlus release 463 ms (TotalTime). Emulator profile 3857 ms.
- **Monkey:** 3000 events on the emulator, seed 20261116, no failures.
- **Install:** the release APK installs as a new package `es.diapo.app` next to the old
  `io.github.dferrandizmont.carrete` and reports `versionName=0.1.0`, `versionCode=6`.

## Failures

| ID | Severity | Where | Summary | Reproduced |
|---|---|---|---|---|
| F1 | **major** | Camera · both devices | After the camera permission is denied twice, the viewfinder stays black with no message and no way to recover | yes (lead, emulator; subagents on both devices) |
| F5 | minor | Gallery viewer · emulator, OnePlus | Deleting the last photo of a day lands on "No encuentro este día" instead of the gallery | yes (both devices) |
| F9 | minor | Camera · OnePlus, font 1.5× | Film names are cut mid-word ("SUMME / R 98" on the LCD) and carousel labels are clipped with no ellipsis | yes (screenshot) |
| F6 | cosmetic | Camera · both | The swipe hint stays after the user swipes the carousel. It goes on a film tap or its X | yes (emulator) |
| F4 | cosmetic | Settings > Licences · OnePlus | The list also has an entry named "carrete" (the code name). Flutter adds the root package's LICENSE as `name: carrete` from `pubspec.yaml`, next to the "Diapo" entry. The English page title reads "Licenses" while the row reads "Licences" | seen once, cause found in code |
| E1 | cosmetic | Camera top bar · Català | "Carregar carret" wraps onto two lines in its key, tight against "Apagat" | seen once |
| F2 | minor | Roll counter after a fast double shutter tap · OnePlus | The sheet said 12 left after 1 frame | **not reproduced** (emulator: 2/4 simultaneous taps counted right, 12−9 = 3 frames) |
| F3 | minor | Share contact sheet · OnePlus | A double tap on Share opened two share sheets | **not reproduced** (emulator: one chooser) |
| F8 | minor | Camera · OnePlus | The app went to the launcher once | **not reproduced**: logcat shows a system force-stop (`am_kill … stop es.diapo.app`, 12:43:52) while the tester changed the permission in App info. Not a crash |
| E3 | minor | Gallery header · emulator | The day header said "4 fotos" after a delete | **not confirmed** (one observation, not rechecked) |

No crash, ANR, Flutter exception or overflow in any log (OnePlus logcat 409k lines; emulator
logcat across all conditions plus monkey).

### F1 · The camera is dead after the permission is denied twice

- **Device and condition:** emulator (profile, es) reproduced by the lead. The OnePlus release
  build (en) showed the same.
- **Steps:**
  1. Fresh install, or `pm clear es.diapo.app`. Open the app.
  2. On the system dialog tap "No permitir". The dialog comes back at once: the app asks
     a second time straight away, which uses up Android's two requests.
  3. Tap "No permitir" again. The permission is now `USER_FIXED`.
- **Expected:** the camera area shows `cameraPermissionDenied` ("Hace falta el permiso de la
  cámara…") with Retry and "open settings" keys. `_CameraProblem` in
  `lib/screens/viewfinder/viewfinder_screen.dart:913` exists for this.
- **Got:** a black viewfinder, a disabled shutter and no text. Relaunching changes nothing. Only
  Android Settings > App info > Permissions gets the user out. Granting it there (or `pm grant`)
  brings the camera back live without a relaunch. Nothing is logged. The camera service seems
  never to reach `CameraFailure.permissionDenied` in this path (the plugin's denial is not a
  `CameraException` with a `CameraAccessDenied*` code, or it never completes).
- **Why major, not blocker:** it only happens after the user refuses the camera twice, and the
  system settings path works. But for a camera app on the store it is a dead first screen with
  no explanation. Fix it before the production track.
- **Evidence:** `evidence/F1-emulator-denied-twice.png`, `evidence/layer1/F1-denied-twice.png`.
- **Maestro flow or test added:** pending. A widget/service test for "permission permanently
  denied → failure state" is the right guard. Maestro cannot deny the system dialog reliably.

### F5 · Deleting the last photo of a day

- **Steps:** take 1 loose photo > Galería > "Fotos sueltas · Hoy" > Fotograma 1 > Borrar > Borrar.
- **Expected:** back to the gallery (the day no longer exists). **Got:** a "Hoy" screen saying
  "No encuentro este día". Back returns to the gallery.
- **Evidence:** `evidence/layer1/F5-day-not-found.png`. Flow: pending. `gallery_delete.yaml`
  passes because it only asserts the empty gallery afterwards.

### F9 · Large text (1.5×) on the camera

- **Evidence:** `evidence/oneplus/conditions/font-camera.png`. The LCD shows "SUMME" / "R 98".
  The carousel shows "Cold / slide" and "Flash / night" cut at the bottom and "Clas" cut at the
  edge, all with no ellipsis. Settings at 1.5× are fine.

## Coverage

| Screen | base | dark | font | locale | landscape | offline | process | layer 1 |
|---|---|---|---|---|---|---|---|---|
| Camera (films, flash, format, grid/level, shutter) | ✅ | ✅ | ⚠️ F9 | ✅ es/ca/en | ✅ (locked portrait) | ✅ | ✅ | ⚠️ F1, F6 |
| Roll: load, shoot, develop now, reveal, contact sheet, viewer | ✅ | ✅ | ✅ | ✅ ca | — | ✅ | ✅ | ✅ |
| Roll names (40 cap, empty, emoji, RTL, Zalgo, injection, 1000-char paste) | — | — | — | — | — | — | — | ✅ |
| Share contact sheet (preview + system chooser, closed) | — | — | — | — | — | — | — | ✅ |
| Roll discard | ✅ | ✅ | ✅ | — | — | ✅ | ✅ | — |
| Disposable camera (start, back blocked, 2.5 s exit, resume) | ✅ | ✅ | ✅ | — | — | ✅ | ✅ | — |
| Gallery, day sheet, delete | ✅ | ✅ | ✅ | ✅ ca | — | ✅ | ✅ | ⚠️ F5 |
| Import from the Photo Picker | ✅ | ✅ | ✅ | — | — | ✅ | ✅ | ✅ (OnePlus) |
| Settings (Cámara, Película, Aspecto, Acerca de, Avanzado) | ✅ | ✅ | ✅ | ✅ es/ca/en | — | ✅ | ✅ | ✅ |
| Privacy policy, legal notice (offline, to the end) | — | — | — | ✅ ca/en | — | ✅ (emulator offline) | — | ✅ |
| GPL notice, Licences, Diapo's GPL entry | ✅ | ✅ | ✅ | ✅ | — | — | — | ⚠️ F4 |
| Rate Diapo (sideloaded: Play "Item not found", Back returns) | — | — | — | — | — | — | — | ✅ |
| Tutorial "Cómo funciona" (3 steps) | ✅ | ✅ | ✅ | — | — | ✅ | ✅ | ✅ |
| Backup screen "Tus ajustes, sin fotos" (opened only) | — | — | — | ✅ ca | — | — | — | ✅ |

Notes:

- Layer 0 conditions (base, dark, font 1.5×, offline, "Don't keep activities") ran all 9 Maestro
  flows on the emulator. Landscape and process death only launch and take a screenshot.
- On the OnePlus, light, font 1.5×, app locale es and ca, landscape and process death were set
  with `device-state.sh`, with screenshots of the camera and of all of Settings
  (`evidence/oneplus/conditions/sheet-*.png`). Everything was restored.
- Photos land in `Pictures/Diapo` (the album was created on the OnePlus).

## Not tested

- iOS (Windows session, no Mac).
- A staged reveal of a long roll ("one after another, one tap shows all") and Home in the middle
  of developing a long roll. Both test rolls developed almost at once.
- The "waiting to be saved" chip and its recovery sheet. No way to force a failed save without
  filling the storage. "Saving N photos" was seen once on the OnePlus.
- The store review dialog itself. It needs 7 days and 5 days of use, and the sideloaded build
  shows "Item not found" in Play.
- Settings export and import (deliberately not run on the owner's phone or the emulator).
- Disposable camera and Maestro flows on the OnePlus (owner's phone: no Maestro, no data
  clearing). Disposable was covered by Maestro on the emulator.
- Tablet layout and Android 8-9.

## Housekeeping

- The flows in `.maestro/` are stale for 0.1.0 (old `appId`, the session counter, "Cargar un
  carrete", the one flash key, "Revelar ahora", the tutorial reached from Settings, "Cámara
  desechable en pausa"). The updated copies are in `qa/0.1.0/flows/` (all 9 pass) and should
  replace `.maestro/`.
- `evidence/` is ignored by `qa/0.1.0/.gitignore` and by the `qa/*/evidence/` line another
  session added to the root `.gitignore` (uncommitted). Keep one of the two.
- OnePlus: Diapo stays installed with camera and notifications granted. They were granted by
  hand after the deliberate denial test. Location is not granted. All test photos and rolls were
  deleted in the app, and `Pictures/Diapo` is empty. Theme, font, rotation, app locale and
  stay-awake were restored. The device lock was released.
- Emulator stopped, locks released, no leftover processes.

## User exceptions

- None.
