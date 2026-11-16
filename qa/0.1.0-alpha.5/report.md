# QA 0.1.0-alpha.5

**Result: SKIPPED** (private prerelease for Daniel's test phones; Daniel asked to cut it
and tests it himself). `test-like-a-human` runs before any store upload.

## Manual device check instead (2026-11-15)

Passing:

- OnePlus 10 Pro (Android 15), build of `7983aea`: the top row of the camera measured in a
  full-resolution capture, the roll key, flash keys and settings key share the same top
  and bottom edge; the LCD strip stays off the digits; the licences page in light and
  dark.
- OnePlus 8T (Android 13), build of `18fd8b7`: the selected flash key stays level with
  its neighbours.
- OnePlus 8T, build of `a98fffe` with the app theme set to light: light body, viewfinder-
  black window (bands visible in 1:1), light tuning panel with the darker groove, the
  navigation bar matches the body; dark theme unchanged. Theme set back to System.
- Minified release build of `0.1.0-alpha.5+5`: installs over the previous build on the 8T
  and reports `versionName=0.1.0-alpha.5`; the APK requests exactly the permissions
  listed in `docs/release-android.md`.

Not checked: the light camera on the 10 Pro and the tablet, the films in good light
(Monday 2026-11-16 on a tripod), Android 8-9.

Automated: `flutter analyze` clean, 1067 app tests and 156 recipe tests pass. No Android
code changed since 0.1.0-alpha.4.
