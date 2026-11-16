# Google Play: console answers for Diapo

The listing texts live in `fastlane/metadata/android/<locale>/` (es-ES is the default language, then en-US and
ca); this file only holds the answers to the console forms and the settings that the Android Publisher API
cannot set. Checked against the code on 2026-11-16 (the owner's legal notes). Change them together with the
privacy policy whenever a permission, SDK or data flow changes.

## App details

| Field | Value |
| --- | --- |
| App name | Diapo: Cámara de película (title per language in `title.txt`) |
| Package | `es.diapo.app` (fixed by the first upload) |
| App or game | App |
| Free or paid | Free (no in-app purchases, no ads) |
| Default language | Spanish (Spain), `es-ES` |
| Category | Photography |
| Tags (max 5) | Camera, Photography, Photo editor, Retro, Vintage (pick the closest the console offers) |
| Contact email | diapo@mainshai.com |
| Website | https://diapo.mainshai.com/ |
| Privacy policy | https://diapo.mainshai.com/privacy/ |

## Console app

Created on 2026-11-16 in the DanielMF developer account (app id 4974256637192188216): app, free, default
language es-ES, automatic protection **off** (Daniel: Diapo is free and open source, and the installer check would
add Google code the public repository does not have and block the signed APKs from GitHub).

## App content

| Declaration | Answer | Why |
| --- | --- | --- |
| Privacy policy | https://diapo.mainshai.com/privacy/ | Also readable in the app, offline (Settings) |
| Ads | **No, my app does not contain ads** | No ad SDK (`pubspec.yaml`) |
| App access | **All functionality is available without special access** | No accounts, no login |
| Content rating | IARC questionnaire below | |
| Target audience | **13–15, 16–17 and 18 and over** (not under 13) | Not directed at children; avoids the Families policy (the owner's legal notes, "Children") |
| Appeals to children | No | |
| News app | No | |
| COVID-19 contact tracing / status | No | |
| Data safety | Below | |
| Government app | No | |
| Financial features | None | |
| Health | None | |
| Advertising ID | **No**, the app does not use an advertising ID | No Play services, no `AD_ID` permission in the merged manifest |
| Foreground service, exact alarms, full-screen intents | Not used | Not in the manifest; the roll reminder is an inexact alarm |
| Photo and video permissions | Not used | Import uses the system Photo Picker (`image_picker`), no `READ_MEDIA_IMAGES` |

## Data safety

- Does the app collect or share any of the required user data types? **No.**
- Result shown on the store: "No data collected", "No data shared".
- Encryption in transit and data deletion questions do not apply when nothing is collected.
- Location: the optional "Guardar la ubicación" writes the position into the user's own photo on the device and
  never sends it off the device, so under Play's definition (data transmitted off the device) it is **not
  collected**. Camera images, the gallery database and settings stay on the device too.
- Store review request: the Play Core review library and play-services-base ship in the app, and the answer
  stays **No data collected**. The rating and review are typed into the Play Store's own window and sent by the
  Play Store under the Play Terms; Diapo only names itself to the Play Store app on the device and transmits
  nothing (reasoning in the owner's legal notes).
- If ads, crash reports or any network SDK ever ship, this answer changes in the same release
  (the owner's legal notes).

## Content rating (IARC questionnaire)

- Category: **All other app types** (not a game, not social, not a communication app).
- Violence, fear, sexuality, nudity, crude humour, profanity: **No** to every question.
- Controlled substances (drugs, alcohol, tobacco): **No**.
- Gambling or simulated gambling: **No**.
- Users can interact or exchange content (chat, user-generated content shared in the app): **No**. Sharing a photo
  hands it to another app through the system share sheet; the app hosts no content.
- Shares the user's current physical location with other users: **No**.
- Allows purchases of digital goods: **No**.
- Unrestricted internet access / web browser: **No** (no internet permission).
- Expected rating: PEGI 3 / Everyone / USK 0.

## Devices: phones only (Daniel, 2026-11-16)

No tablet release. The API cannot set this: in **Release > Device catalog**, filter by form factor
**Tablet** (and **Chromebook**, **TV**, **Wear OS**, **Car** if listed), select all and **Exclude**. Do it before the
first release goes out to testers. The manifest keeps no tablet-specific declarations; `test-like-a-human` notes
that the portrait lock is ignored on 600 dp+ screens under API 36, one more reason to exclude them.

## Release

- Track for the first upload: **internal testing**, then the closed test (12 testers for 14 days, later).
- Play App Signing: Google keeps the app signing key; the upload key is `diapo-upload.jks`, kept outside the repository
  (alias `upload`), outside the repository. Its passwords are in Daniel's password manager.
- Upload with `~/.agents/skills/release/scripts/play-upload.py` (release skill §2b), dry run first.
