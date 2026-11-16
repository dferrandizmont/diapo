# Privacy policy

*Last updated: 2026-11-16. Applies to Diapo for Android and iOS, all versions.*

Diapo is a film camera: you pick a film, see it live in the viewfinder and shoot. It is free, works offline, and everything it does happens on your device. This policy explains, briefly, what data is processed, what is not, and what rights you have.

## Who is responsible

Data controller: Daniel Mont Ferrandiz. Contact: diapo@mainshai.com.

In practice the controller never receives any data about you: the app does not talk to anyone, except to ask the store for its rating window (see "Store ratings"), and that request carries no data about you. We name the controller so you know whom to write to.

## What data is processed and what is not

All processing happens on your device, inside the app, and it is your choice.

| Data | What for | Where it stays |
| --- | --- | --- |
| Camera image | Show the viewfinder with the film applied and take the photo | In memory while you use the camera. The photos you take are saved to your gallery (Android: the `Pictures/Diapo` folder; iOS: an album of its own) at full resolution and with no watermark. |
| Untouched original (optional) | If you turn on "Also save the original", keep the photo as the camera took it as well | In your gallery, in the `Pictures/Diapo/Originales` folder. Off by default. |
| Photo metadata (EXIF) | Keep the date and the camera details (model, exposure, aperture, ISO) in the photo, like any phone photo | Inside the photo file, in your gallery. The location is written only if you turn on "Save location" (next row). Otherwise the app does not write it and, if the source photo carries GPS coordinates (for example, a photo you import), they are removed. |
| Location (optional) | If you turn on "Save location", record in each photo where you took it, like the phone's own camera does | The app asks the phone's location system for the position (GPS, or nearby Wi-Fi and cell towers) only while the viewfinder is open on screen, never in the background, and writes it into the photo's metadata (and its original's, if you save it), in your gallery. How the system works that position out depends on your phone's location settings, not on the app. If the phone gives no recent position, the photo is saved without a location. In an undeveloped roll, the coordinates are kept encrypted with the photo until it is developed. If you import photos with the option on, the coordinates the photo already had are kept; the app does not add your position to them. Off by default. Keep in mind that anyone who receives a photo with a location can see where it was taken. |
| Record of your photos | Show your gallery inside the app: which photos you took, with which film, on which date and in which roll | In a database in the app's private storage. It keeps a reference to each photo, not a copy. |
| Undeveloped roll photos | Keep them until the roll is developed, in disposable mode too | Encrypted (AES-256) in the app's private storage, which no other app can read, with the key protected by the system's secure keystore. When the roll is developed they move to your gallery and are deleted from the encrypted storage. They never reach the gallery earlier. |
| Photos you import | Apply a film to them, if you choose "Develop photos from your phone" | You pick them in the system photo picker, and the app receives only those. They are copied briefly to its cache to be processed, and the copy is deleted afterwards. The result is saved to your gallery as a new photo; the original is left untouched. |
| Settings | Remember your preferences (grid, level, sounds, date style, language, theme, default film) and the fine tuning of each film | In the app's private storage. If you use "Export settings", a copy is also saved to a file, wherever you choose with the system picker; the copy holds no photos and no locations. Importing a copy never switches on location saving or the saving of originals. |
| Phone tilt | Draw the horizon level in the viewfinder, if you turn it on | Read from the accelerometer while the viewfinder is open and never stored. Off by default. |

What the app **does not do**:

- It has no accounts or sign-up, and asks for no personal data.
- It does not connect to the internet. Published versions do not declare Android's network permission (`INTERNET`), so they cannot connect to the internet. The app is open source (https://github.com/dferrandizmont/diapo), so anyone can check this in its Android manifest. There are no analytics, crash reports, trackers or advertising.
- It does not use the microphone. It uses your location only if you turn on "Save location", and never in the background.
- It does not browse your gallery: it only sees the photos it saved itself and the ones you pick when importing.
- It shares data with no one. If you tap Share, the photo is handed to the app you choose through the system share menu; from then on that app's policy applies. If you rate the app, the store receives your rating directly, not us.

## Permissions and what they are for

- **Camera:** only to show the viewfinder and take photos. Without it the camera cannot work.
- **Location (optional):** requested only when you turn on "Save location". You can grant the approximate location instead of the precise one; the photos then carry an approximate position. The app never uses it in the background. If you withdraw the permission, it stops saving the location.
- **Gallery:** to save the photos. On Android 10 or later no permission is needed: they are saved through the system media store, and the app can only see and delete the photos it saved itself. On Android 8 and 9 the classic storage permission is requested, to write the photos and read its own back. That permission technically grants access to the whole shared storage, but the app only writes and reads its own folder.
- **Importing photos:** needs no permission. It uses the system photo picker, which hands the app only the photos you pick.
- **Notifications:** to tell you that your roll is ready to develop. They are local notifications, scheduled by the app on your device; there is no external notification service. If you refuse them you get no reminder, but you can still develop the roll from the app when it is ready.
- **Run at startup (Android):** to schedule the roll reminder again if you restart the phone. It does nothing else.

## Store ratings

Now and then, after you develop your first roll or share a contact sheet, Diapo may ask the store (Google Play or, on iPhone, the App Store) to show you its window for rating the app. The store decides whether to show it, and the app asks no more than three times. You can also open Diapo's store page from Settings › About › "Rate Diapo". For this, on Android the app includes the Google Play ratings library (Play Core) and the Google Play services libraries it relies on; on iPhone it uses the system feature.

Diapo only tells the store which app it is: it does not pass on your photos or any other data about you, and it does not know whether you rated it or what you wrote. The window is shown by the store app, which is the one that connects to the internet; Diapo still has no network permission. You write your rating and review in that window and Google or Apple receives them, with your store account and under their own terms. You can delete them from your store account.

To decide when to ask, the app keeps in its private storage the day you first opened it, on how many different days you have opened it, how many times it has asked for a rating, and when and with which version it last did. These counters never leave the phone: they are not in the settings file you export or in system backups, from which Diapo excludes its private data (see "Backups"), and they are deleted when you uninstall the app or clear its data.

## Deleting photos

If you delete a photo from the app's gallery, it is also deleted from the system gallery, together with its original if you saved one; if the original cannot be deleted, the app tells you it is still in the `Originales` folder. Android may ask you to confirm. Photos the app did not save cannot be deleted from it.

## Retention and deletion

Your photos are in your gallery and you manage them. The settings, the record of your photos and the undeveloped roll photos live in the app's private storage. If you uninstall the app or clear its data, all of that is lost, and **undeveloped roll photos are lost with no way to recover them**. Photos already developed or already saved to the gallery are not touched.

If a photo cannot finish saving (for example, because the app was closed halfway), it stays in the app's private cache and is retried the next time you open it. After three attempts it is no longer retried and the file stays there until you clear the app's cache or data. While a roll photo is being captured and developed, a temporary unencrypted copy exists in that cache, and it is deleted when done.

## Backups

The photos in your gallery follow whatever backups you have set up on the device (Google Photos, iCloud or others); that is your choice, not the app's. The app's private data (settings, the record of your photos, the rating counters, and undeveloped roll photos with their key) is excluded from cloud backups and from transfers to a new phone: the key exists only on this device, so on a new phone the app starts from scratch.

## Legal basis

The only processing happens on your device, by your own decision, when you use the app. Within the meaning of Regulation (EU) 2016/679, the General Data Protection Regulation (GDPR), and of the Spanish Ley Orgánica 3/2018, de Protección de Datos Personales y garantía de los derechos digitales (Organic Law on Personal Data Protection and Digital Rights, LOPDGDD), the controller does not collect, store or access any personal data of yours.

## Your rights

You have the right to access your data, rectify it, erase it, restrict or object to its processing, and to data portability. Since the controller holds no data about you, it cannot act on such requests: everything is on your device and you control it directly (delete photos from the gallery, clear the app's data, uninstall, turn off "Save location" or withdraw the permission; a location already written into a photo stays there until you delete the photo). If you have any questions, write to diapo@mainshai.com. Rights over a published review are exercised with the store (Google or Apple).

If you believe your rights are not being respected, you can lodge a complaint with the Agencia Española de Protección de Datos (Spanish Data Protection Agency, AEPD), www.aepd.es, or with the supervisory authority of your country.

## Children

The app is not directed at children, but we know that many families photograph their kids. So we say it plainly: the photos you take never leave your device; the app does not analyse them or send them anywhere. Once in your gallery, they depend on the permissions you give other apps and on your backups. We collect data from no one, children included. If you turn on "Save location", remember that the photo carries the place where it was taken when you share it.

## Changes

If the app changes in a way that affects this policy (for example, if it ever sent crash reports or included advertising), we will update it before releasing that version and say so in the release notes. The current version is always available in the app and at diapo.mainshai.com.

## Contact

Daniel Mont Ferrandiz · diapo@mainshai.com
