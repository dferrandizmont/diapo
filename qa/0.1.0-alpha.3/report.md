# QA 0.1.0-alpha.3

**Result: SKIPPED** (private prerelease for Daniel's test phones; Daniel asked to cut it
and tests it himself). `test-like-a-human` runs before any store upload.

## Manual device check instead (OnePlus 10 Pro, Android 15, minified release build of `5642f8f`, 2026-11-14)

Passing:

- The camera opens; a photo is saved to `Pictures/Carrete`.
- Gallery list, day sheet and viewer (film and date); Share opens the system sheet; Delete
  removes the file from the system gallery.
- The roll sheet shows the new uninstall warning. Notification permission prompt.
- A roll of 12 / 1 h: no photo reaches the gallery before developing; closing it schedules the
  reminder; the app reschedules it on start; "Tu carrete está listo" arrived (11:52 for 11:42)
  and tapping it developed the 2 photos from the encrypted vault in a fresh process, with the
  contact sheet.
- Import through the system Photo Picker, live film, hold-to-compare ("Original"), export
  without GPS in the EXIF.

Also on 2026-11-13 (OnePlus 8T and 10 Pro, release builds): the ten films, own gallery with
share and delete, first-use flow, disposable mode, import, sounds.

Not checked: "Abrir ajustes" on a denied permission, the level upright, the sounds with the
ringer on, the films in good light (Monday 2026-11-16 on a tripod), Android 8-9, the tablet.

Automated: `flutter analyze` clean, 760 app tests and the recipe tests pass, Android JVM tests pass.
