# Carrete Maestro smoke flows

Requires Maestro 2.12.1, an installed app (`io.github.dferrandizmont.carrete`),
and an Android emulator or phone in **Spanish**, portrait orientation. Each
flow clears the app's data, grants camera/notification permissions, and starts
independently. Use a QA installation: clearing data also loses undeveloped
photos. Clearing app data does not clear photos already exported to MediaStore.

Run the emulator **with a window** and set its system language to **Spanish**
(`es-US` was used for the first run):

```sh
sh ~/.agents/scripts/emu.sh start <AVD> --window
```

A headless emulator crashed when the app opened the camera.

From the repository root:

```sh
maestro test .maestro/
maestro test .maestro/shoot.yaml
sh .maestro/run.sh <device-serial>
```

The runner selects that serial and writes JUnit to `build/maestro/report.xml`.
`config.yaml` selects the nine entry flows; `common/` is called via `runFlow`.
The runner only runs Maestro; use the shared heavy-command queue when required
by your session's instructions.

| Flow | Coverage |
| --- | --- |
| `onboarding.yaml` | All three first-use screens and arrival at the camera. |
| `shoot.yaml` | Two loose photos, session counter, today's day, frames, viewer film/date/time and return. |
| `film_and_format.yaml` | Three films, all four formats, four flash modes, grid on/off. |
| `roll_instant.yaml` | 12-frame instant roll, two shots, close/develop, two-frame contact sheet and viewer. |
| `roll_discard.yaml` | 12-frame one-hour roll, one shot, confirmed discard, gallery still empty. |
| `disposable.yaml` | Start dialog, one of 27 shots, blocked Back, 2.5 s exit hold, confirmation, resume entry. |
| `gallery_delete.yaml` | One loose photo, confirmed deletion, empty day and gallery. |
| `settings.yaml` | Grid, level, sounds and originals both ways; date style, default film, themes, Català/Español and licences. |
| `import.yaml` | Captures its own source photo, selects one photo in the system Photo Picker, changes film, develops and checks both photos in the app gallery. |

`common/start_camera.yaml` skips onboarding; `common/shoot_once.yaml` waits for
an enabled shutter before and after capture. Export waits allow 60 seconds for
loose photos and 120 seconds for developing. These are maximum waits, not sleeps.

The first Android 36 release-APK run passed four of nine flows. These fixes
still need a device rerun. Calibrate the identical `swipe.start` and
`swipe.end` points in `disposable.yaml` (initially `82%, 8%`). If the picker has
different thumbnail labels from `Foto tomado el` / `Photo taken on`, update
the selector in `import.yaml`. The exit coordinates are portrait percentages.

The picker confirmation supports `Done`, `Listo`, `Añadir`, `Agregar` and `Add`
(including a selection count) and is optional for pickers that return on a
single tap. Android 36 exposed `Foto tomado el …` thumbnails and no confirmation
button in the failure hierarchy. The flow captures and waits for its own source
photo before opening the picker, so it does not depend on suite order.
Avoid a run across midnight: newly captured photos are matched under `Hoy`.
Imported photos can belong to an older day, based on their EXIF date.

See [LABELS.md](LABELS.md) for every label's source, validation evidence, skipped
checks and the hardware tuning checklist. No Dart changes are needed.
