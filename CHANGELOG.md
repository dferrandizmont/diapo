# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## Unreleased

### Added

- A "Buy me a coffee" row in the settings (Android) opens the Ko-fi page in
  the browser; the app still has no internet permission.

### Changed

- Catalan now calls a roll of film "rodet" instead of "carret", everywhere in
  the app, the privacy policy, the legal notice and the web page.
- The English settings row reads "Licenses", like the title of the page it
  opens.

### Fixed

- The Licenses page lists Diapo once, without the code name.
- With large system text, the film name on the LCD and on the film cartridges
  shrinks to fit instead of breaking in the middle of a word or being cut at
  the edge; a name that still cannot fit ends with an ellipsis.
- Swiping the films now dismisses the first-minute hint about swiping them, and
  the hint does not come back.
- The disposable camera, when the camera permission is denied, now has an
  "Open settings" key that opens the system page of the app, like the main
  camera.
- Deleting the last photo of a day returns to the gallery instead of an empty day,
  and Back from there still returns to the camera.

## [0.1.0] - 2026-11-16

### Added

- The privacy policy and the legal notice can be read in the app, offline,
  from Settings (About), in Spanish, Catalan or English.
- Diapo is free software under GPL-3.0-only. Settings (About) says so and shows
  where the source code lives (as text; the app never opens it), and the
  Licences page has Diapo's own entry with the full licence text.
- A store review request and a "Rate Diapo" row in Settings (Android; iOS once
  the app has an App Store id). After a first-time roll reveal or a shared
  contact sheet, the app may ask the store to show its own review dialog, at
  most 3 times (once per version, 90 days apart), only after 7 days and 5
  different days of use, with a developed roll or 10 loose photos, and never in
  the first use or within 3 days of importing settings. The counters stay on
  the device, outside the settings export, and the store decides whether the
  dialog appears. Adds the `in_app_review` package (Play In-App Review and
  StoreKit).
- Optional roll names. From the screen of a roll, a pencil key opens a small
  dialog to give the roll a name of up to 40 characters, with a counter; an
  empty name takes the roll back to "Roll 07". The name is written by hand
  (Caveat) in the header of the roll, on its card in the gallery and on the
  leader strip of the shareable contact sheet, after the film name. Rolls can
  be named at any time, also before they are developed (the name is not photo
  content), and naming is never asked for. Roll names stay on the device and
  are not part of the settings export.
- The camera now says what happens to the photos it is saving. While photos are
  being saved it shows "Saving 2 photos" with a tiny progress mark, only after
  about 400 ms, so a single fast save does not flicker; roll frames count too,
  and nothing about their content is shown. When photos could not be saved, a
  chip "Some photos are waiting to be saved" stays on the camera, also after
  the app is restarted, until they are saved. Tapping it opens a short sheet
  that says what happened (storage full, a missing permission, or unknown) and
  offers "Try again" and "Later". Retrying runs one at a time, also for the
  photos that used up their automatic attempts. The "Photo saved" announcement
  is only made for a photo that is already in the gallery.
- The reveal of a roll. While a roll develops, its contact sheet fills with each
  photo as soon as it is saved, with no artificial wait. The first time a
  developed roll is opened, its frames come in one after another in about a
  second, and one tap shows them all. One quiet click and a light tap tell that
  the roll is ready, nothing per frame. With reduced motion everything shows at
  once. A roll is only revealed once.
- "Share contact sheet" on a developed roll: a preview of the whole roll as one
  image, portrait, with the perforations, the original frame numbers, the film
  name and the date, and empty frames for the ones that are missing, then the
  share menu of the system. No app name and no watermark. The image is a
  temporary copy: it is deleted when the preview closes, unless you shared it
  (the other app may still be reading it), and then it goes the next time the
  app starts. A photo deleted from the app leaves an empty frame with its number
  on the sheet. On a short screen or with large text the preview scrolls with
  its keys within reach.
- The camera feels like an object. A cartridge that settles in the carousel
  clicks softly and gives a small tap, a roll that is loaded (from the sheet,
  from the offer or the disposable camera) makes a thud and a firmer tap, and
  the last frame of a roll rewinds: a motor sound, a light tap and the film
  running backwards in the LCD (no animation with reduced motion).
- A "Vibration" setting, on by default and apart from the camera sounds, turns
  the small vibrations off, shutter included. They are skipped on silent and
  work on vibrate (Android; on iOS there is no ringer check yet, so they stay
  off there). It is part of the settings export.

### Changed

- The app is now called Diapo. Photos are saved to Pictures/Diapo (originals
  to Pictures/Diapo/Originales) and the settings backup is named
  diapo-ajustes-<date>.json. The Android package is es.diapo.app, so this is
  a new app next to the test builds: photos taken with them stay in
  Pictures/Carrete.
- The roll sheet of a disposable camera that was set aside has two main actions,
  "Back to the disposable camera" and "Finish roll", and "Throw away the roll"
  as a quiet text action under them, still with its confirmation. Finishing
  shows how it develops: one develop action with an instant wait, or the
  scheduled time with a choice between keeping the wait and developing now. The
  repeated "close" and "develop now" wording is gone.
- The export and import of the settings moved to a collapsed "Advanced" section
  at the end of the settings, labelled as settings only, not a backup of the
  photos. "Also save the original" and the level stay in the camera section.
- The fine-tuning panel of the camera no longer repeats the frame format: the
  key beside the shutter is the only one. The import screen keeps its format
  row.
- The top bar follows large text sizes: the keys and the LCD grow with the text
  up to 1.3 times, and above that the text shrinks to fit instead of being cut.
  The "Load roll" control moves to a row of its own when its text would not be
  legible, and a long film name in the LCD takes two lines and ends with an
  ellipsis.
- The hint about swiping the films is on a darker pill, readable over a bright
  scene, and its close key has its own label for screen readers. The secondary
  disposable row of the roll sheet is tinted while it is pressed.

- Honest wording about developing: the notification says "You can develop your
  roll now" and to open the app and keep it open until it finishes, because
  photos are developed by the app and not in the background. Waiting rolls say
  "You can develop from..." instead of "Ready on...", the wait is called
  "Wait to develop", the key that closes a roll says "Close roll", and
  "developed" is only used for a roll that is finished.
- Clearer about losing photos: before loading a roll the app says that
  undeveloped photos exist only on this phone and are lost if you uninstall,
  clear the app data or move to another phone, and a short reminder is in the
  details of a roll that is not developed yet. "Develop now" stays available
  for open and waiting rolls, also a paused disposable, and its confirmation
  now says how many photos are developed and that the wait ends now, instead of
  asking you to keep waiting. In the settings, the export and import say they
  cover settings only, not photos.
- A new user goes straight to the camera and its permission request instead of
  three tutorial screens. A hint about swiping the films shows once, and after
  the second loose photo the camera offers a roll of 12 once, with the selected
  film, the photos hidden until the roll is closed and developing right away.
  The tutorial stays in the settings, and it no longer teaches fine tuning.
- The LCD of the camera no longer counts photos of the session. Without a roll
  it shows the name of the selected film and "Loose photos"; with a roll it
  shows "Left 08".
- Loading a roll is easy to find: the wheel icon of the camera is now a
  labelled "Load roll" control. With a roll loaded it shows the film and how
  many frames are left, and with a disposable camera set aside it says so. The
  roll sheet explains in one line that the whole roll uses one film and the
  photos stay hidden until you develop it, shows the film, the length and the
  wait together, says the wait starts when the roll is closed, and offers the
  disposable camera as the secondary option.
- The four flash keys of the camera are one key that cycles off, auto, on and
  party. It always shows the icon and the name of the mode, tells a screen
  reader the mode and keeps the 44 px touch size at large text sizes.
- The Desechable film now shoots 3:2 without a white border, like the disposable
  camera, so it no longer looks like the Instant film. A format you chose for it
  yourself is kept.
- The app has its own icon: a cream compact camera with a big charcoal lens and
  a red shutter button, on a charcoal tile. On Android it is an adaptive icon
  with a themed (monochrome) version; iOS gets the full icon set.

### Fixed

- If you refuse the camera permission, the camera now says so and offers to
  try again or open the settings, instead of staying black. It no longer asks
  twice in a row by itself, and an open that never answers ends as an error
  after a while.
- The offer of a roll of 12 says that undeveloped photos live only on this
  phone before the roll is loaded. It is shown only when the camera is on
  screen and the app is in the foreground (it waits behind other screens), it
  never comes back once a roll was loaded, and it fits small screens and large
  text: it scrolls, and its keys go one over the other.
- Photos that failed to save and were recovered after a restart now count
  towards that offer, once each.
- "Develop now" no longer guesses how many photos a roll has while the count is
  loading: the key waits for the real count, and a roll that was shot only in
  part says its real number of photos.

## [0.1.0-alpha.5] - 2026-11-15

### Changed

- The camera follows the light theme: with the light theme (or a light system
  theme) the viewfinder controls, the fine-tuning panel and the roll sheet are a
  warm light plastic with black print and the red accent, and the picture keeps
  a dark window around it. The dark camera is unchanged.

### Fixed

- Settings show the right version: 0.1.0-alpha.4 still said 0.1.0-alpha.3.
- The film advance strip of the LCD no longer runs over the number after a
  shot, so the counter stays whole, also with two or three digits.
- The top row of the camera is aligned: the LCD, the roll key, the flash keys
  and the settings key share one centre line, and the captions under the LCD
  and the flash keys sit on the same baseline. A selected key looks sunken
  but no longer drops below its neighbours; it only moves under the finger.
- The page of licences in settings follows the look of the app, light and
  dark, instead of the default purple Material look.

## [0.1.0-alpha.4] - 2026-11-15

### Added

- Develop 50 MP photos at their original resolution, with continuous film grain
  and effects across the whole photo, including date imprints and instant frames.
  Photos up to 24 MP keep the faster single-pass save.
- Save location (off by default, "Save location" in settings): asks for the
  location permission only when you turn it on, accepts the approximate
  location, and writes where each photo was taken into its EXIF data. The
  position is followed only while the camera is open, never in the background,
  and never leaves the device; a precise position counts for 2 minutes and an
  approximate one for 10, so photos taken indoors get a location too. Roll
  photos keep the location of the shot when they are developed later, also
  after a time zone change. Settings warn when the permission was removed.
- Export and import settings ("Your settings" in settings): saves your settings
  and the fine tuning of every film to a file you choose, and reads it back
  after a confirmation. An import never turns the location or the original on.
- Cinema bands: optional black bars that leave a 2.39:1 picture inside a 16:9
  photo, on by default for the Cinema film and available to every film at 16:9
  ("Cinema bands" in the fine-tuning panel). The viewfinder and the import
  preview show the same bars the saved photo gets, and the date imprint stays
  inside the picture.

## [0.1.0-alpha.3] - 2026-11-14

### Added

- Also save the original (off by default, "Also save the original" in
  settings): the untouched camera photo is kept next to the developed one in
  `Pictures/Carrete/Originales`, with a name that follows its photo (so a retry
  never saves it twice) and the same location rule (GPS only with "save
  location"). It is best effort: it is tried once, never retried, and a failure
  never affects the developed photo. The photos of a roll or of the disposable
  camera save theirs when the roll is developed, never before. The own gallery
  still shows only the developed photos, and deleting a photo there deletes its
  original too (one system confirmation for both when Android asks; if the
  original cannot be deleted the photo goes and a notice says so).
- The disposable camera is now set in its own type (Bowlby One, Space Mono and
  Caveat, all SIL OFL 1.1, bundled with their licences and listed in the
  licences page) instead of the fonts of the normal camera.
- Camera sounds (on by default, "Camera sounds" in settings): a shutter click
  at the shot and a film-advance whirr a moment later, in the normal camera
  and in the disposable one. They are played natively with a sound pool loaded
  in advance, so they never delay the shutter, and nothing is played when the
  phone is on silent or vibrate. The sounds are synthesised by
  `tool/generate_sounds.dart` (no recordings, no new permission).
- Level (off by default, "Level" in settings): a thin line on the viewfinder
  that follows the tilt of the phone, with two fixed ticks, and turns to the
  accent colour when it is level within about 1 degree. It also works with
  the phone held sideways: it counts from the nearest quarter turn and the two
  ticks turn to the vertical axis. It reads the
  accelerometer (`sensors_plus`, BSD-3) only while shown, repaints only its own
  small overlay, has no animation, hides when the phone lies flat and is never
  shown in the disposable camera.

- Leaving the disposable camera now pauses it: while it is open but not in the
  camera, the normal camera takes loose photos, counts the session and leaves
  the film free. The roll sheet offers to go back to it (or to close, develop or
  throw it away) and explains that no other roll can be loaded meanwhile. Every
  frame of a disposable is 3:2 with no white border, whichever screen took it.

- Disposable camera, in the cardboard-and-paper design: "Disposable camera" in
  the roll sheet starts a roll of 27 photos on a locked screen to pass from
  hand to hand. It has only the viewfinder with the Desechable film (3:2), the
  shutter, a flash switch, a sticker that counts the photos left and a thumb
  wheel that clicks forward after each shot. No carousel, tuning, gallery,
  settings, format or lens key; the photos are never shown; system back does
  nothing. The way out is to hold the exit stamp for two seconds and confirm;
  the photos left are kept and the roll sheet puts the camera back. If the app
  is killed, it opens straight on the disposable camera. The roll closes with
  the 27th photo and develops like a roll (next morning unless another time is
  picked), with its contact sheet. Texts in Spanish, Catalan and English; large
  text and reduced motion are respected.
- First-use flow: three screens (the camera, the film, the roll) shown once
  before the camera on a fresh install, in Spanish, Catalan and English. The
  picture lives in a viewfinder, an LCD counts the screens and the shutter is
  the "next" key. It can be skipped at any moment, respects large text and
  reduced motion, never asks for the camera permission, and can be opened again
  from the settings ("How it works").
- Six new films, so the carousel has the ten of the first version: Caducada (shifted
  greens and magentas, coarse grain, strong vignette), Noche de flash (hard
  contrast, burnt faces, black background), B/N de prensa (high contrast,
  coarse grain), Instantánea (washed colours, blue shadows, square frame with
  the white border), Cine (warm skin, greenish shadows, 16:9) and Cámara de
  juguete (very strong vignette, odd colours, a huge light leak). Names and
  descriptions in Spanish, Catalan and English.
- Own gallery: a key left of the shutter opens it. Developed rolls and days of
  loose photos, the newest first, each as a strip of film with its film, photo
  count and date; a roll or a day opens as a contact sheet. Rolls that are not
  developed yet are listed apart with no photo of theirs. Photos deleted from
  the system gallery outside the app show as missing and do not crash it.
- The viewer shows the film and the day and time of each photo, and has keys to
  share it (the Android share sheet, no extra permission or dependency) and to
  delete it, after a confirmation, from Carrete and from the system gallery.
- Photos taken without a roll are now recorded on the device (film, format,
  lens, time, where it was saved and size), also when a failed save is retried after a
  restart or after the app died right after saving (the shot is kept until
  it is recorded and is not saved twice). Photos taken with earlier
  prereleases are not in the gallery.
- Opening the gallery clears the entries of photos the system gallery no
  longer has (photos in the system trash count as still there).
- Develop photos you already took: a row at the top of the gallery opens the
  Photo Picker of the system (one or several photos; Carrete asks for no
  permission to read your gallery and adds no network call). The photo shows
  live through the film you pick in the carousel, with the same fine tuning as
  the camera (changes made here do not touch the camera), and holding a finger
  on it shows the original. "Develop" exports every photo at full resolution
  (bounded like a shot of the camera, one at a time, with progress) to
  Pictures/Carrete with its EXIF and no location unless the setting says so, and
  records it as a loose photo of the gallery, on the day it was taken. The
  date imprint prints the date the photo was taken (EXIF, with its offset); a
  photo with no date gets none. Photos over 100 MB or 200 MP are refused before
  they are opened. Leaving or cancelling at any moment keeps nothing, even
  photos already developed in that batch; the temporary copies (and the ones
  the picker plugin leaves in the cache) are deleted at every start.
- A quiet note in the roll sheet and in the disposable camera start dialog: if
  the app is uninstalled or its data cleared before the roll is developed, its
  photos are lost.

### Changed

- Each film names the colour of its cartridge band (optional `bandColor` in the
  recipe, validated and documented), with a different hue family for each of
  the ten. Cine and Instantánea are retuned to read clearly as cinema (teal
  shadows, warm skin, more contrast) and instant film (milky blacks, soft
  contrast, cool shadows).
- The film carousel only runs the live picture of the cartridges on screen
  (plus one on each side), so ten films do not slow the viewfinder down.

### Fixed

- Semi-transparent imports keep their brightness when developed in tiles.
  Interrupted tiled saves release their native bitmap after 60 seconds of inactivity.
- Photos of a roll are no longer counted on the LCD as photos of the
  session once the roll is closed.
- Deleted roll photos keep their existing missing state without repeated gallery
  reads. Restored photos reappear after reopening the gallery or roll, or returning
  to the app.
- Deleting a roll while it is open shows that it can no longer be found.
- Android 8–9 retries incomplete gallery exports and preserves recovery when
  storage is temporarily unreadable. Reduced peak memory usage when opening large
  photos in the Android viewer.

## [0.1.0-alpha.2] - 2026-11-13

Second private prerelease: roll mode.

### Added

- Roll screens: a roll key in the top bar opens a sheet to load a roll (12, 24
  or 36 frames, developed now, in an hour, the next morning or in three days)
  or, with a roll loaded, to close it, develop it early (with a warning) or
  throw it away. The LCD counts the frames left, the film is fixed while the
  roll is loaded and no photo of the roll is shown.
- Roll screen: when a roll will be ready, the developing progress on an LCD and
  a strip of frames, and the contact sheet of a developed roll (light and dark)
  with a full-size viewer. Photos are read from the gallery by the native side;
  no new permission.
- Roll capture keeps photos encrypted until developing, with 12, 24 or 36
  frames, automatic closing, delayed or early developing and discarding.
- Local roll readiness reminders, with developing on the next foreground
  app start, resume or notification tap. Notifications are optional.
- Interrupted developing preserves completed saves, reports corrupt photos and identifies
  rolls whose encryption key is lost.

### Fixed

- The roll reminder counts the photos taken, so a roll closed early no longer
  announces its full length.
- Roll captures survive staging and cleanup failures, and startup recovers
  pending captures and removes plaintext copies of committed or discarded shots.
- Retrying interrupted roll development reconciles gallery exports to avoid
  duplicate photos. Early development resumes on the next foreground start.
- The app closed when developing a photo (the image decoder was released too
  early).
- On the first launch the camera now opens by itself after the permission is
  granted, instead of showing "camera unavailable".
- A photo that could not be saved is no longer lost: the original is kept in
  the cache of the app and saved again the next time the app starts.
- A photo taken while leaving the camera screen is still saved.
- Leftover camera files are cleaned from the cache when the app starts.
- Notifications work in release builds (their icon was being stripped).

### Changed

- The app no longer asks for the microphone: the permission the camera library
  brought in is removed from the Android manifest.
- The location is never written into a photo unless "save location" is on in
  the settings; the GPS tags of the camera original are stripped otherwise.
- Photos over about 24 megapixels are developed at that size, so very large
  sensors do not run the app out of memory.

## [0.1.0-alpha.1] - 2026-11-09

First private prerelease for the Android test phones.

### Added

- Bundled typefaces Chakra Petch and Barlow Semi Condensed (SIL Open Font
  License), listed in the licences page.

- Proof of concept: live film look on the camera viewfinder (one-pass shader
  with exposure, colour matrix, split toning, tone curve, halation, light leak,
  vignette and grain) and full-resolution save with the same shader to
  `Pictures/Carrete`, keeping the camera EXIF.
- The camera screen, in the style of a plastic 90s compact: live preview through
  the selected film, LCD shot counter, flash keys (off, auto, on and a party
  flash that burns the highlights a little), red shutter, pinch zoom from 1x to
  2x, tap to lock focus and exposure, optional grid and back or front camera.
- A carousel with one cartridge per film of the recipe book, each with a live
  thumbnail. A long press opens the fine tuning of that film (grain, halation,
  light leak, vignette, date imprint and format), stored per film.
- Frame formats 3:2, 4:3, 1:1 and 16:9; the saved photo is cropped to the frame
  shown in the viewfinder. Square films with a white frame get the instant
  border when the photo is saved.
- Date imprint in orange seven-segment digits (`'98 7 14` or `14 7 '98`) on the
  viewfinder and burned into the saved photo.
- Photos are developed at full resolution in a queue in the background, so the
  shutter never waits.
- Texts of the camera in Spanish, Catalan and English.
- A settings screen in the style of the camera, in the light or dark theme of the
  system: grid, date style (with a seven-segment sample of today), default film,
  theme, language, the version, a note that the app works offline without
  accounts or ads, and the list of licences. Settings that do not work yet
  (sounds, saving the original or the location, level) are not shown.

### Changed

- The proof of concept moved to `/bench` (still the start screen with
  `--dart-define=CARRETE_BENCH=true`).

### Fixed

- The frame of the viewfinder is always fully visible. In 3:2 and 16:9 it used
  to run under the film carousel (and, in 16:9, under the top bar), so the
  saved photo held parts the user could not see. It is now scaled down to fit
  between the top bar and the carousel, with black sides when needed; the corner
  marks, grid, date imprint, focus indicator and tap to focus follow it.
- Small labels of the camera (shot counter, flash and the fine-tuning subtitle)
  are printed in capitals, as in the design.
- The focus lock indicator is white, like the corner marks of the frame.
- The camera permission message no longer names the app and a key opens the
  system settings of the app (Android).
- The zoom pill is announced to screen readers on its own.
- The value of a slider of the fine-tuning panel no longer wraps with a large
  text size.
