# iOS port plan

Map of what the Dart side asks the platform for, its Android implementation, and what iOS needs. Written on
2026-11-16 from the code on `main` (0.1.1+8). iOS has never been built: `ios/` is the Flutter template
(bundle id `es.diapo.app`, Swift Package Manager for the plugins, no Podfile), with no Swift of our own.
The channel names, method names, argument keys and answers stay **exactly** as they are: the Dart tests listed at
the end pin them, so a Swift side that mirrors the Kotlin one needs no Dart change for those channels.

Kotlin lives in `android/app/src/main/kotlin/io/github/dferrandizmont/carrete/`.

## Channels

### `carrete/media` (MethodChannel) + `carrete/media/pixels`, `carrete/media/tiles`, `carrete/media/contact-sheet` (BasicMessageChannel, binary)

Dart: `lib/platform/media_store.dart`, `lib/platform/gallery_images.dart`, `lib/platform/photo_actions.dart`,
`lib/roll/contact_sheet_image.dart`. Kotlin: `MediaChannel.kt` (register :120, `onMethodCall` :129,
viewer calls :585, `onPixels` :319, `onTilePixels` :351, `onContactSheetPixels` :283), `ExifCopy.kt`,
`PhotoLocation.kt`, `SavedJpeg.kt`, `TileRaster.kt`, `MissingRules.kt`, `OriginalRules.kt`, `ContactSheet*.kt`.

On Android a photo is a MediaStore row in `Pictures/Diapo` (originals in `Pictures/Diapo/Originales`) and its
"uri" is a `content://` string kept in the database. On iOS the uri becomes `ph://<PHAsset localIdentifier>`
(an opaque string for Dart), the photos go into an album **Diapo** in Photos, and the originals into a second
album **Diapo Originales** (Photos has no nested folders without a folder list).

| Method | Args → answer | Android | iOS |
| --- | --- | --- | --- |
| `beginSave` | `width, height, quality, displayName, sourcePath, includeLocation, location?, takenAt?` → token; then the RGBA pixels on `carrete/media/pixels` → JSON `{ok, uri, timings}` | Bitmap → JPEG, EXIF copied from the camera file, saved with `IS_PENDING` | `CGImage` from the RGBA bytes → `CGImageDestination` JPEG (ImageIO) with the camera file's EXIF (`CGImageSourceCopyPropertiesAtIndex`), orientation 1, real size, `Software = Diapo`, GPS **removed** unless `includeLocation` (then written from `location`); `PHAssetCreationRequest` with `originalFilename = displayName`, added to the album |
| `beginTiledSave` / `cancelTiledSave` | as above + `tileSize, framed`; tiles on `carrete/media/tiles` | `TileRaster` into one ARGB bitmap | One RGBA buffer filled tile by tile (24 MP = 96 MB, same peak as Android), then the same encode and save |
| `findSaved` | `displayName, original?` → uri or null | Query by name in the folder | The local identifier Diapo stored for that name when it saved (a small map in Application Support), checked to still exist; never a search of the library |
| `saveOriginal` | `sourcePath, displayName, includeLocation, location?, takenAt?` → uri | Copy to `Originales` with GPS rules | Same EXIF rule (strip or write GPS), into the album **Diapo Originales** |
| `readExifDates` | `path` → `{original, originalOffset, digitized, digitizedOffset}` | `ExifInterface` | `kCGImagePropertyExifDateTimeOriginal`, `…OffsetTimeOriginal`, `…DateTimeDigitized`, `…OffsetTimeDigitized` |
| `loadThumbnail` | `uri, extent` → JPEG bytes; `not_found`, `not_allowed` | Thumbnail loader, 2 threads | `PHImageManager.requestImage` (target `extent`), encoded to JPEG |
| `readImage` | `uri` → full JPEG bytes | Read the row | `requestImageDataAndOrientation` |
| `shareImage` / `shareFile` | `uri` / `path` → bool | `ACTION_SEND` chooser | `UIActivityViewController` (a `ph://` asset is first written to a temp file in `tmp/`) |
| `deleteImage` | `uri` → `deleted`, `deletedPhotoKeptOriginal`, `gone`, `cancelled` | `createDeleteRequest` when the system asks | `PHAssetChangeRequest.deleteAssets`: iOS always shows its own confirmation; refusing it answers `cancelled` |
| `missingImages` | `uris` → the ones that no longer exist | `MissingRules` | `PHAsset.fetchAssets(withLocalIdentifiers:)` |
| contact sheet | RGBA pixels → JPEG q88 (max 4096 px, 16 MP) or error | `onContactSheetPixels` | ImageIO JPEG, same limits |

**Photo library access: read-write (lead, 2026-11-16).** Saving alone would need only *add-only* access, but
Diapo's own gallery reads, shares, deletes and checks its photos after saving, which add-only does not allow. So
the app asks `PHPhotoLibrary.requestAuthorization(for: .readWrite)` the first time a photo is saved (never at
start), with `NSPhotoLibraryAddUsageDescription` and `NSPhotoLibraryUsageDescription` («Diapo solo usa sus propias
fotos: las guarda en el álbum Diapo y las abre para compartirlas o borrarlas»).

- **`.limited` is treated exactly like `.authorized`**: iOS adds the assets an app creates to its limited selection
  by itself, so with limited access and no photo selected Diapo still sees all of its own photos.
  `PHPhotoLibraryPreventAutomaticLimitedAccessAlert = true` in `Info.plist` stops iOS from offering to pick more
  photos at every launch.
- **Never the whole library**: no fetch of all assets, no fetch of other albums, no limited-library picker. Every
  read goes through the local identifiers Diapo stored when it saved (`PHAsset.fetchAssets(withLocalIdentifiers:)`).
- The albums **Diapo** and **Diapo Originales** are best effort: if iOS refuses to create or find them under
  limited access, the photo is still saved (it shows in Recents) and found through its stored identifier. Check on
  the iPhone XR with "limited, no photos selected".
- `.denied` / `.restricted`: the save fails (`save_failed`) as on Android when MediaStore refuses, and the gallery
  reads answer `not_allowed`.
- The Play listing sentence «Diapo no pide permiso para leer tu galería» refers to import (the Photo Picker); the
  App Store text does not repeat it. The privacy policies (es, ca, en, and their web copy) describe only Android in
  the «Galería» permission bullet: an iOS sentence must be added before the first upload (Claude writes, Fable
  reviews).

### `carrete/system` (MethodChannel)

Dart: `lib/platform/system_settings.dart`, `lib/platform/camera_sounds.dart`, `lib/platform/external_links.dart`,
`lib/core/backup/settings_backup_files.dart`. Kotlin: `MainActivity.kt:41-57` (handler), `CameraSounds.kt`,
`SettingsBackupDocuments.kt`, `SettingsBackupBytes.kt` (limit 256 KiB), `SettingsBackupSession.kt`.

| Method | Answer | Android | iOS |
| --- | --- | --- | --- |
| `openAppSettings` | bool | `ACTION_APPLICATION_DETAILS_SETTINGS` | `UIApplication.openSettingsURLString` |
| `cameraPermission` | bool | `checkSelfPermission(CAMERA)` | `AVCaptureDevice.authorizationStatus(for: .video) == .authorized` |
| `ringerMode` | `silent` / `vibrate` / `normal` | `AudioManager` | iOS cannot read the silent switch: answer `normal` and let the audio session do the muting (below) |
| `loadSounds` / `playSound(name)` | bool | `SoundPool`, names `shutter, advance, cartridge, load, rewind` | `AVAudioPlayer` per sound, preloaded from the Flutter assets (`FlutterDartProject.lookupKey(forAsset:)`), audio session `.ambient` so the silent switch mutes them and other audio keeps playing |
| `exportSettings(suggestedName, bytes)` | bool; errors `too_large, busy, interrupted, storage` | SAF `ACTION_CREATE_DOCUMENT` | Write to `tmp/<suggestedName>`, present `UIDocumentPickerViewController(forExporting:asCopy: true)`; cancel → false |
| `importSettings` | bytes or null | SAF `ACTION_OPEN_DOCUMENT` | `UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: true)`, read with the same 256 KiB limit; cancel → null |

### `carrete/location` (MethodChannel)

Dart: `lib/location/location_source.dart`. Kotlin: `LocationChannel.kt`.

| Method | Answer | iOS (`CLLocationManager`, when in use only) |
| --- | --- | --- |
| `permission` | `granted`, `coarseOnly`, `denied`, `permanentlyDenied` | `authorizedWhenInUse` + full accuracy → `granted`; reduced accuracy → `coarseOnly`; `notDetermined` → `denied`; `denied` / `restricted` → `permanentlyDenied` |
| `requestPermission` | same; `permission_pending` if one is open | `requestWhenInUseAuthorization`, answer from `locationManagerDidChangeAuthorization` |
| `start` / `stop` | — | `startUpdatingLocation` / `stopUpdatingLocation`, only while the camera is in the foreground |
| `current` | `{permission, fix}`; fix `{latitude, longitude, altitude, accuracy, time, approximate}` | Last `CLLocation`, dropped when the permission level changed (same rule as Kotlin) |

No "always" location, no background location mode.

### Plugins (no own native code)

| Plugin | iOS | Notes |
| --- | --- | --- |
| `camera` (`camera_avfoundation`) | yes | `enableAudio: false`, so no microphone string |
| `flutter_secure_storage` | yes, Keychain | `IOSOptions(accessibility: first_unlock_this_device)`, key `shot_vault_key_v1` (`lib/core/vault/vault_key_store.dart:42-50`) = `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`: not in backups, not on a new phone |
| `shared_preferences`, `path_provider`, `drift_flutter` (sqlite3) | yes | |
| `image_picker` | yes | `pickMultiImage` uses `PHPickerViewController`: no photo permission |
| `flutter_local_notifications` | yes | `DarwinInitializationSettings` already set (`lib/roll/roll_notifications.dart:36-40`), permission asked later (alert, sound) |
| `in_app_review` | yes | `SKStoreReviewController`; the store page needs `kAppStoreId` |
| `sensors_plus` | yes | Accelerometer for the level |

There is **no foreground service** on Android either: developing runs in Dart while the app is open
(`lib/roll/roll_providers.dart:43`, `:143-164`) and the "roll ready" reminder is a scheduled local
notification. On iOS that is the same; when the app goes to the background iOS suspends it within seconds, so a
develop in progress pauses and resumes on return (as on Android when the process is killed). Optional later:
`beginBackgroundTask` to finish the current photo.

## Dart changes for iOS

| Where | Today | Change |
| --- | --- | --- |
| `lib/platform/camera_sounds.dart:28` | Sounds only on Android | Also iOS |
| `lib/platform/haptics.dart:14-15, :40` | No ringer mode → haptics off | iOS: follow the setting (iOS applies its own system haptics switch) |
| `lib/platform/system_settings.dart:17` | `canOpen` only on Android | Also iOS |
| `lib/roll/contact_sheet_image.dart:115` | JPEG sheet only on Android, PNG elsewhere | Also iOS (PNG stays the fallback) |
| `lib/screens/settings/settings_screen.dart:232` | Rate row on iOS only when `kAppStoreId != null` | Keep; set `kAppStoreId` (`lib/core/app_info.dart:9`) once App Store Connect gives the id |
| `lib/platform/external_links.dart` (`canOpen`) | Ko-fi row only on Android | **No change.** Ko-fi is out of iOS for good (lead, 2026-11-16): App Store guideline 3.1.1 does not allow linking external donations to an individual developer. `canOpen` is already true only on Android, so the row never shows on iOS; the Kotlin `openKofi` has no iOS counterpart |
| `lib/l10n/app_*.arb` (`Pictures/Diapo/Originales`, es :1120, ca/en :553), `lib/import/import_developer.dart:71`, `lib/platform/photo_actions.dart:11` | Android folder named in the UI | iOS wording («el álbum Diapo Originales de Fotos»), chosen by platform |
| `lib/l10n/app_*.arb` (`importLeftoverBody`, `viewerDeleteBody`: «galería del móvil», «carpeta Diapo») | Android words | iOS variants («Fotos», «álbum Diapo») |
| `lib/poc/poc_screen.dart:169` | `getExternalStorageDirectory` | Bench only: guard or use the support directory on iOS |
| App start (iOS) | — | Mark `Application Support` (database + `vault/`) excluded from iCloud and computer backups (`NSURLIsExcludedFromBackupKey`, set natively at launch), the same intent as `allowBackup="false"` and the backup rules on Android: the vault cannot be opened without this device's key |

Texts are UI work for Claude (ARB, Spanish first); the platform gates are small Dart changes with their tests.

## Info.plist and project (done on the `ios-prep` branch)

Usage strings for camera, photo library (add and read-write) and location when in use, localized in
`InfoPlist.strings` (es, ca, en); `ITSAppUsesNonExemptEncryption = false` (`docs/ios/export-compliance.md`);
portrait only; iPhone only (`TARGETED_DEVICE_FAMILY = 1`); iOS 16.0; `PrivacyInfo.xcprivacy`.

## Tests that pin the channels

The Swift side must answer exactly what these mocks expect:

- `carrete/media`: `test/platform/media_store_test.dart`, `gallery_images_test.dart`, `photo_actions_test.dart`,
  `exif_dates_test.dart`, `media_location_test.dart`, `test/capture/still_fast_path_test.dart`,
  `test/roll/roll_cinema_bands_test.dart`, `roll_restart_test.dart`, `test/screens/roll/roll_screen_test.dart`,
  `test/roll/contact_sheet_image_test.dart` (`encode_failed`).
- `carrete/system`: `test/platform/camera_sounds_test.dart`, `system_settings_test.dart`, `external_links_test.dart`,
  `test/core/backup/settings_backup_service_test.dart:747-828`.
- `carrete/location`: `test/location/location_provider_test.dart`, `test/capture/capture_location_test.dart`,
  `test/screens/viewfinder_screen_test.dart:565`.
- Notifications plugin channel: `test/roll/roll_notifications_test.dart`.
