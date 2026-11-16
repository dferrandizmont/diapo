# QA 0.1.0-alpha.4

**Result: SKIPPED** (private prerelease for Daniel's test phones; Daniel asked to cut it
and tests it himself). `test-like-a-human` runs before any store upload.

## Manual device check instead (OnePlus 10 Pro, Android 15, 2026-11-15)

Passing:

- Settings export through the system file picker (`carrete-ajustes-2026-11-15.json` in
  Downloads) and import after the confirmation: the theme came back, "Ajustes importados."
- Save location indoors: with precise permission the EXIF position was 14 m off; with
  approximate permission it carried the approximate position (accuracy 2000 m). The switch
  asks for the permission only when turned on.
- Minified release build of `0.1.0-alpha.4+4`: installs over alpha.3, the camera opens,
  Cine switches to 16:9 with the cinema bands in the viewfinder, and the saved photo has
  the bands on the long sides of the portrait frame: 288 and 289 px of 2250 (12.8 %),
  colour #0A0A0A.
- The APK requests exactly the permissions listed in `docs/release-android.md` (now with
  the foreground location pair); sounds, fonts and `ic_roll_ready` are present.

Not checked: the bands in good light and in landscape, the bands toggle on another film,
the location on the OnePlus 8T (system location off there), the films in good light
(Monday 2026-11-16 on a tripod), Android 8-9, the tablet.

Automated: `flutter analyze` clean, 1029 app tests, 156 recipe tests and the Android JVM
tests pass.
