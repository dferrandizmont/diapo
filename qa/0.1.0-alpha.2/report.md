# QA 0.1.0-alpha.2

**Result: SKIPPED** (private prerelease for Daniel's test phones; Daniel asked to cut it
and tests it himself). `test-like-a-human` runs before any store upload.

## Manual device check instead (OnePlus 8T, Android, release build, 2026-11-13)

Passing:

- Roll 12 / instant and 12 / 1 h. The LCD counts down, the other films are locked, no photo of
  the roll reaches the gallery before developing. "Carrete terminado" opens the developing
  screen. 12 frames develop into exactly 12 gallery items.
- Contact sheet with thumbnails and the full-size viewer with swipe.
- Database migration v1 to v2 on an existing install.
- "Revelar ahora" (warning, develops, cancels the reminder). "Tirar" (confirmation, cancels
  the reminder, nothing in the gallery).
- Notification permission prompt, reminder alarm, "Tu carrete está listo" notification and its
  tap opening and developing the roll.
- A photo with the phone lying flat matches the viewfinder (raw EXIF orientation 6, sensor 90).

Found and fixed: release resource shrinking dropped the notification icon (3df94c3).

Not checked: the reminder after a reboot, the light theme on a device, Android 8-9, the front
camera mirroring.

Automated: `flutter analyze` clean, `flutter test` 349 passed.
