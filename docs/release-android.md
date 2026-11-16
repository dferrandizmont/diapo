# Android release

## Upload signing (local setup only)

Create the upload keystore **outside the repository**. Replace the placeholders;
let keytool prompt for passwords (never put them on the command line):

```sh
keytool -genkeypair -v -keystore <EXTERNAL_DIRECTORY>/carrete-upload.jks \
  -alias <UPLOAD_KEY_ALIAS> -keyalg RSA -keysize 2048 -validity 10000
```

Copy `android/key.properties.example` to `android/key.properties` locally and
fill all four properties. `storeFile` should be an absolute path outside the
repository; use forward slashes on Windows. Neither the real properties file
nor the keystore belongs in version control. Back up the keystore securely, never
share it or its passwords, and keep the passwords in a password manager, apart
from the keystore backup.

The app is enrolled in **Play App Signing** with this same key as its app
signing key (checked on 2026-11-16: the universal APK Google Play serves for
build 7 and the GitHub APK both have the certificate SHA-256
`11:F0:F9:73:9F:4C:F0:91:7B:76:C2:8C:B2:F5:BC:B2:15:96:2D:09:E2:A9:D0:37:E5:59:1E:1E:34:01:04:B5`),
so a Play install and the GitHub APK update each other. Keep signing bundles
and APKs with it; `play-upload.py apk --version-code N` downloads the APK Google
serves to check the certificate again. Without `android/key.properties`,
release APKs deliberately use the debug key and print a Gradle warning for
private prereleases; `bundleRelease` fails instead, so no debug-signed bundle
can be built for Play. An existing but
incomplete properties file fails configuration instead of falling back.

## Build and archive

Run from the repository root with the installed Flutter SDK (currently 3.47.7,
Android compile/target SDK 36). Increase the app version before each upload.

```sh
sh ~/.agents/scripts/heavy.sh flutter build apk --release
sh ~/.agents/scripts/heavy.sh flutter build appbundle --release --obfuscate --split-debug-info=build/app/symbols
```

The outputs are `build/app/outputs/flutter-apk/app-release.apk` and
`build/app/outputs/bundle/release/app-release.aab`. Check the bundle's signing
certificate against the upload certificate registered in Play Console.
Archive `build/app/symbols` **per version and build number** before the next
build, alongside the bundle and `build/app/outputs/mapping/release/mapping.txt`
(R8). Keep these outside version control; Dart symbols are needed to symbolicate
obfuscated crash stacks. Record APK/AAB sizes and compare with the previous build.

## Pre-release checks (lead verification)

Tests, analysis and builds use the shared heavy queue. The artifact checks are
light and run directly: piping `heavy.sh` into `grep` would filter its summary
(it shortens outputs over 60 lines), not the real output. Set `AAPT2` to the
installed Android SDK's `build-tools/<VERSION>/aapt2` executable (`aapt2.exe` on
Windows); the commands below use a POSIX shell:

```sh
sh ~/.agents/scripts/heavy.sh flutter analyze
(cd android && sh ~/.agents/scripts/heavy.sh ./gradlew :app:testDebugUnitTest)
"$AAPT2" dump permissions build/app/outputs/flutter-apk/app-release.apk
"$AAPT2" dump resources build/app/outputs/flutter-apk/app-release.apk | grep ic_roll_ready
unzip -l build/app/outputs/flutter-apk/app-release.apk | grep -E 'assets/flutter_assets/assets/(sounds/.*\.wav|fonts/.*\.ttf)'
```

The APK must request exactly `android.permission.CAMERA`,
`android.permission.ACCESS_FINE_LOCATION`, `android.permission.ACCESS_COARSE_LOCATION`
(foreground only, for the optional "Save location"),
`android.permission.POST_NOTIFICATIONS`, `android.permission.RECEIVE_BOOT_COMPLETED`,
`android.permission.WRITE_EXTERNAL_STORAGE` and `android.permission.READ_EXTERNAL_STORAGE`
(both storage permissions capped at `maxSdkVersion=28`), plus
`io.github.dferrandizmont.carrete.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`.
Stop if any additional permission appears. Confirm that `ic_roll_ready`, both
`shutter.wav` and `advance.wav`, and every font declared in `pubspec.yaml` remain
in the APK. Preserve the drawable keep entry in `res/raw/keep.xml`.

On a device, exercise the minified release: media/system method channels,
capture/save/read/delete/share (including EXIF), scheduled roll notifications
after process death and reboot, encrypted roll storage across restarts, camera
preview/capture, shutter/advance sounds and ringer modes, the sensor level, and
gallery import through the image picker. Check navigation/back and system bars.
The unmodified build already targeted API 36; this configuration adds no API
level behaviour migration. Complete the project's device QA and release flow
before uploading to Play.
