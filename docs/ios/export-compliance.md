# Export compliance (App Store)

`ios/Runner/Info.plist` declares `ITSAppUsesNonExemptEncryption = NO` (`<false/>`), so App Store Connect does not
ask the encryption questions for each build and no export documentation is uploaded. **Decided by the lead on
2026-11-16: exempt.** In short: standard AES-GCM from the `cryptography` package (no algorithm of our own); it only
protects the user's own photos on the device; nothing is transmitted (the app has no network access); and security
is not the app's primary function (EAR Category 5 Part 2, Note 4). If Apple or Daniel question it, it is reviewed
again before the first submission. With `NO`, the French encryption declaration does not apply.

## What the app encrypts

- The photos of a roll that is not developed yet: AES-256-GCM files in `<Application Support>/vault/`
  (`lib/core/vault/`, the `cryptography` Dart package), so they cannot be looked at before developing.
- The key: random, kept in the iOS Keychain (`flutter_secure_storage`, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`).
- Nothing else. The app has no network access at all: no HTTPS, no TLS, no server, no account, no key exchange.
  The encrypted files never leave the device and the app offers no way to send them.

## Why it is exempt

- The primary function of the app is photography, not computing, communication or information security. The
  encryption is a secondary part of it: it hides the app's own data on the user's device until a roll is
  developed. Under the U.S. Export Administration Regulations, Category 5 Part 2, Note 4 (items whose primary
  function is not information security and whose cryptography only supports that function), such an item is not
  controlled as encryption.
- It also fits the case Apple lists of encryption limited to protecting the user's own data stored on the device,
  with no transmission of encrypted data.
- The app does not offer encryption to the user or to other apps, does not implement a proprietary or
  non-standard algorithm (AES-GCM is standard), and does not encrypt communications.

So the answer in App Store Connect, if it ever asks, is: the app uses encryption, and it qualifies for the
exemptions (Note 4 / encryption limited to the app's own data on the device). No CCATS, no annual self-
classification report, no French declaration are needed for this use.

## When to change it

If a future version adds anything that encrypts data in transit (a server, sync, cloud backup, a network SDK),
set `ITSAppUsesNonExemptEncryption` again after answering Apple's questionnaire for that build; HTTPS through the
system only (`URLSession`) is still exempt, but it must be reviewed then.
