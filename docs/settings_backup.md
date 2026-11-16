# Settings backup contract

The settings rows can read `settingsBackupProvider` from
`lib/core/backup/settings_backup_service.dart` and call:

- `exportSettings()`: `true` means the document was saved; `false` means cancelled.
- `importSettings()`: `null` means cancelled. Otherwise `SettingsImportResult`
  lists `appliedSettings` (field names), `appliedFilmIds`, `skippedFilmIds` and
  `needsUserSettings`. The last list contains privacy switches that were not
  applied because enabling them requires a user decision in the future UI.
  The applied lists contain fields accepted from the document, including values
  that already matched the device. Show a localized completion message with the applied
  counts and any skipped film IDs. Cancellation needs no error message.
- Catch `SettingsBackupException` and translate its `code`. `invalidValue`
  includes a `path` identifying the rejected field. The remaining codes are
  `tooLarge`, `invalidJson`, `wrongFormat`, `unsupportedVersion`, `busy`,
  `storage` and `interrupted`. The latter reports a previous Android operation
  whose Dart caller was lost during recreation; it does not apply an import.
  Disable both rows during either operation; the service also rejects overlapping
  operations with `busy`.

No UI, translations, dependencies or permissions are added by this service.
`settingsProvider` and `filmTuningsProvider` refresh after successful persistence.

## Version 1

```json
{
  "format": "carrete-settings",
  "version": 1,
  "app": "0.1.0-alpha.3",
  "settings": {
    "cameraSounds": true,
    "saveOriginal": false,
    "saveLocation": false,
    "grid": true,
    "level": false,
    "dateStampStyle": "yy m d",
    "defaultFilmId": "verano-98",
    "themeMode": "system",
    "localeOverride": null
  },
  "tuning": {
    "verano-98": {
      "grain": 0.7,
      "halation": 1,
      "leak": 0,
      "vignette": 1.2,
      "dateStamp": true,
      "format": "3:2"
    }
  }
}
```

The pure Dart `SettingsBackupCodec` takes known IDs from the current recipe
book. Export includes every portable setting and complete tuning for every
known film, including default multipliers and explicit null optional overrides.
This also clears destination-only tuning when restoring a full export.
Both directions are limited
to **262144 UTF-8 bytes**, inclusive. Import requires valid UTF-8 JSON, an object,
the exact format, integer version 1, a nonblank app string, and object-valued
`settings` and `tuning`. The app version is informational, not a compatibility
gate. Unknown keys at every level are ignored, but their JSON must still be
valid. A strict reader rejects duplicate object names before inserting values
into maps, including ignored extension objects and names equal after JSON
unescaping (for example `grid` and `gr\u0069d`). Nesting is limited to 64 levels;
duplicate names, excessive nesting and malformed JSON return `invalidJson`.

Known setting fields must have their exact types. The five switches are
booleans. Date style accepts `yy m d` or `d m yy`; theme accepts `system`, `light`
or `dark`; locale accepts null (follow the device), `es`, `ca` or `en`.
`defaultFilmId` must be a nonempty string. Unknown film IDs in it or in `tuning`
are skipped and reported once per ID. An unknown film's entire tuning entry is
ignored without interpreting its fields. The skipped-ID report contains at most
50 distinct display IDs, each truncated to 64 Unicode characters without splitting
surrogate pairs. Truncated duplicates are reported once; further IDs are omitted.
All unknown films are skipped even when the report is full.

The four tuning numbers must be finite and in [0, 2], inclusive: these are the
multipliers documented by the recipe engine's `LookOverrides`. The engine
separately clamps the resulting amounts to [0, 1]; backups preserve the
multipliers, not those rendered amounts. `dateStamp` accepts boolean or null;
`format` accepts null or a `FrameFormat.wireName` (`3:2`, `4:3`, `1:1`, `16:9`).
Null clears either optional override, restoring the recipe default.

## Apply semantics

Import merges fields into the current device values after the picker closes.
Absent fields, absent film entries and absent tuning values preserve the
device's current values. Empty objects are no-ops. This supports partial files
without silently resetting unrelated preferences. Any invalid **known** field
rejects the entire document before persistence, including otherwise valid
fields. Unknown keys and unknown films are the only exceptions. This prevents a
damaged backup from applying a surprising subset of recognized values.

Import never enables `saveLocation` or `saveOriginal` when the last confirmed
value is false. Such fields retain their current value, are excluded from
`appliedSettings`, and are reported in `needsUserSettings`. Already-enabled
switches and disabling either switch are applied normally. A document containing
only blocked switches is a no-op with a result, without a preference write.

An import with applicable recognized fields writes settings and tuning together as one JSON
preference, `carrete.settingsSnapshot`. Repositories then treat that snapshot as
authoritative and ordinary edits preserve its other section. A shared queue per
preferences instance serializes imports, ordinary settings edits and film tuning
edits. Field changes are evaluated against the last confirmed values when their
turn starts, so an edit queued during an import preserves the imported fields.
Export captures its settings and tuning in that same queue, then releases it
before opening the document picker, so immediately preceding edits are included.
Before the first import, ordinary edits use the legacy keys in the same queue.

The snapshot store keeps its last confirmed encoded value independently of the
plugin cache. Readers continue to see it while a write is in flight. A rejected
or throwing write explicitly writes that previous value back (or removes the key
if there was no snapshot), checks the platform success flag and reads the cache
back to verify the restoration, and raises `storage` without refreshing backup
providers. It never calls `reload()`: Android commit can change native memory
even when disk persistence fails. If restoration cannot be confirmed, reads
retain the confirmed state and further snapshot writes are blocked for that
preferences instance. A second disk failure cannot provide a restart durability
guarantee; it must not silently publish the unconfirmed state in the process.

The onboarding flag remains in its original local key and is never imported or
exported. The disposable lock, other preferences, rolls, photos, vault, secure
storage and filesystem paths are never read by the backup service. This is an
application-level atomic preference update; it does not add filesystem crash
durability beyond the platform preferences API.

## Android channel

`SystemSettingsBackupFiles` implements the injectable `SettingsBackupFiles`
interface, using `carrete/system`:

- `exportSettings({suggestedName: String, bytes: Uint8List})` returns bool.
  Android launches `ACTION_CREATE_DOCUMENT`, `CATEGORY_OPENABLE`, MIME type
  `application/json`, and `EXTRA_TITLE: carrete-ajustes-YYYY-MM-DD.json`.
- `importSettings()` returns `Uint8List?`. Android launches
  `ACTION_OPEN_DOCUMENT` with the same category and MIME type. Cancellation
  returns null. Reading stops after the limit plus one byte, without trusting
  document metadata or buffering an oversized file.

I/O runs on worker threads; streams close before success is returned. A 15-second
watchdog covers provider opening, reading, writing, flushing and closing (not
user time in the picker). On timeout it answers `storage`, clears pending state,
requests stream closure off the main thread, and attempts to delete a failed
export document only if it is a document URI whose queried `COLUMN_SIZE` is
exactly zero. Existing nonempty documents, unknown sizes and failed metadata
queries never permit deletion. Streams returned after timeout are closed without use, and
late completions cannot answer a newer operation. Dart clears its busy flag on
all errors, including timeout and interruption. A provider that ignores close
can leave its worker blocked; it cannot hold the pending call or prevent a new
operation from getting a worker.

`MainActivity.onSaveInstanceState` saves the operation kind, request code,
export bytes (at most 256 KB) and, when already received, the document URI.
Recreation restores that state. An operation with a saved URI is abandoned:
neither reading nor writing is replayed, even if I/O finished before the old
process could reply. An abandoned export is eligible only for the empty-document
cleanup described above; an import is never deleted. The old Dart callback is
never reused: the next channel call receives `interrupted`. That call also
clears a restored picker without a URI, so a missing Activity result cannot
leave subsequent calls permanently `busy`. A picker result delivered before
that notice can still finish with its saved bytes. Recovered imports are not
silently applied. The interruption marker is itself saved across subsequent
recreation.

There are no new storage permissions or persistable URI grants. Picker,
provider and lifecycle failures return `storage`; oversized documents return
`too_large`; overlapping requests return `busy`. Native exception details and
URIs are not sent to Dart. No R8 rule is needed: helpers are directly referenced.

iOS can replace `settingsBackupFilesProvider` with its document implementation;
the current missing implementation is mapped to `storage`. Tests inject
`FakeSettingsBackupFiles` and cover the service without a platform picker.

## Implementation files

- `lib/core/backup/settings_backup_codec.dart`: wire format, validation, typed
  errors and validated patches.
- `lib/core/backup/settings_backup_files.dart`: picker interface and system
  channel adapter.
- `lib/core/backup/settings_backup_service.dart`: service, result and Riverpod
  providers.
- `lib/core/settings/settings_snapshot.dart`: single-preference commit;
  `settings_repository.dart` and `film_tuning_repository.dart` read and preserve
  that state after import.
- Android `MainActivity.kt`: channel and activity-result routing;
  `SettingsBackupDocuments.kt`: picker lifecycle, saved state and worker I/O;
  `SettingsBackupSession.kt`: pending operation, stream ownership and watchdog;
  `SettingsBackupIo.kt`: provider access and empty-document cleanup policy;
  `SettingsBackupBytes.kt`: bounded stream reader.
- `test/core/backup/settings_backup_codec_test.dart` and
  `settings_backup_service_test.dart`: validation, round trip, full restores,
  partial patches, skipped films, size cap, atomic failure, provider refresh,
  cancellation, busy state and channel contract, with an injectable fake picker.
- Android `SettingsBackupBytesTest.kt`: empty/exact-limit reads, oversized and
  unbounded streams, and short reads.
- Android `SettingsBackupSessionTest.kt`: abandoned picker and I/O recreation,
  empty-document cleanup after interruption, persisted interruption notices,
  timeout closure, late stream rejection and protection against stale completions.
- Android `SettingsBackupIoTest.kt`: pre-truncation failure and timeout cleanup
  for empty, nonempty and unknown-size documents, non-document URI rejection,
  failed metadata queries and refused deletion.

## Review round 1 validation

The targeted Flutter run passed all **162 tests**, covering both backup files
and settings repository, tuning repository, settings provider and onboarding flag
regressions. The final export-queue adjustment was verified by rerunning all
**17 service tests** (including the new immediate-export regression) and scoped
analysis; both passed. New regressions include native-memory mutation on a failed commit, a reload that
would fail, unconfirmed rollback, suspended persistence with interleaved field
edits, duplicate literal documents, privacy consent and bounded skipped IDs.

Checks run through `sh ~/.agents/scripts/heavy.sh`:

- Scoped `flutter analyze --no-pub` for the changed Dart files.
- `flutter test --no-pub test/core/backup/settings_backup_codec_test.dart
  test/core/backup/settings_backup_service_test.dart
  test/core/settings/settings_repository_test.dart
  test/core/settings/film_tuning_repository_test.dart
  test/core/settings/settings_provider_test.dart
  test/core/settings/onboarding_flag_test.dart`.
- Android `:app:testDebugUnitTest`: **32 tests passed**, including nine new
  recovery/watchdog tests. It ran offline using the installed Gradle
  distribution, an isolated temporary Gradle home, a read-only dependency cache,
  Kotlin compilation in process and an isolated Android preferences directory.

Changed Dart sources also pass `dart format --output=none --set-exit-if-changed`.
Analytics state is isolated in a temporary directory with Dart analytics disabled.
Because `android/gradlew` was initially absent, `flutter build apk --debug` was
attempted once to generate it. The build stopped at a sandbox-denied Gradle
wrapper cache path; no APK was produced. No device-level picker or real process
kill test was run; native JVM tests exercise the shared recovery/I/O and timeout
state used by the Activity adapter.

## Review round 2 validation

All checks ran through `sh ~/.agents/scripts/heavy.sh`. Scoped Dart formatting
checked 17 files with no changes, and analysis of `lib/core/backup`,
`lib/core/settings`, `test/core/backup` and `test/core/settings` found no issues.
The same six targeted Flutter test files listed above passed **163 tests**.
Android `:app:testDebugUnitTest` passed **37 tests**, with no failures, errors or
skips, including 18 backup tests. It ran offline with one Gradle worker and
Kotlin compilation in process. The initial Gradle invocation failed because
PowerShell split the compiler option; the corrected invocation passed.

Native regressions cover existing versus empty documents after pre-truncation
failure, timeout and URI restoration; unknown metadata and non-document URIs;
abandoning restored reads and writes; and releasing a restored picker when its
interruption notice is consumed. These are JVM tests of the shared policy and
session state; no real document provider or device process-death test was run.
