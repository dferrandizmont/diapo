import 'dart:async';
import 'dart:convert';

import 'package:diapo/core/backup/settings_backup_service.dart';
import 'package:diapo/core/settings/review_state.dart';
import 'package:diapo/core/settings/settings_provider.dart';
import 'package:diapo/render/film_resources.dart';
import 'package:diapo/review/review_service.dart';
import 'package:diapo/roll/roll_providers.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/backup/settings_backup_service_test.dart'
    show FakeSettingsBackupFiles;

class _FakeStore implements StoreReviewPlatform {
  bool available = true;
  bool failRequest = false;
  bool failAvailable = false;
  int requests = 0;
  final List<String?> listings = [];

  /// When set, `isAvailable` waits for it, so a test can interleave triggers.
  Completer<void>? gate;

  @override
  Future<bool> isAvailable() async {
    if (failAvailable) throw StateError('no store');
    await gate?.future;
    return available;
  }

  @override
  Future<void> requestReview() async {
    requests++;
    if (failRequest) throw StateError('store failed');
  }

  @override
  Future<void> openStoreListing({String? appStoreId}) async {
    listings.add(appStoreId);
  }
}

class _Clock {
  _Clock(this.now);

  DateTime now;

  DateTime call() => now;
}

/// A [ReviewStore] whose next write can be held, to interleave an import with
/// the write of a request.
class _GatedStore extends ReviewStore {
  const _GatedStore(super.preferences, this.gates);

  final List<Completer<void>> gates;

  @override
  Future<void> save(ReviewState state) async {
    if (gates.isNotEmpty && state.requestCount > 0) {
      final gate = gates.removeAt(0);
      await gate.future;
    }
    await super.save(state);
  }
}

/// Preferences whose writes say "not saved".
class _RefusingPreferences implements SharedPreferences {
  _RefusingPreferences(this.delegate, {this.throws = false});

  final SharedPreferences delegate;
  final bool throws;

  @override
  String? getString(String key) => delegate.getString(key);

  @override
  Future<bool> setString(String key, String value) async {
    if (throws) throw StateError('disk full');
    return false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Setup {
  _Setup(this.container, this.store, this.clock, this.preferences);

  final ProviderContainer container;
  final _FakeStore store;
  final _Clock clock;
  final SharedPreferences preferences;

  ReviewService get service => container.read(reviewServiceProvider);

  ReviewState get state => ReviewStore(preferences).load();
}

Future<_Setup> _setup({
  bool ownWork = true,
  bool firstMinuteDone = true,
  ReviewState? state,
  String version = '0.2.0',
  String? appStoreId,
  ReviewStore Function(SharedPreferences preferences)? storeOf,
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({
    if (firstMinuteDone) 'carrete.firstMinute.swipeHintSeen': true,
  });
  final preferences = await SharedPreferences.getInstance();
  if (state != null) await ReviewStore(preferences).save(state);
  final store = _FakeStore();
  final clock = _Clock(DateTime(2026, 11, 20, 10));
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      rollClockProvider.overrideWithValue(clock.call),
      storeReviewPlatformProvider.overrideWithValue(store),
      reviewOwnWorkProvider.overrideWithValue(() async => ownWork),
      reviewAppVersionProvider.overrideWithValue(version),
      reviewAppStoreIdProvider.overrideWithValue(appStoreId),
      if (storeOf != null)
        reviewStoreProvider.overrideWithValue(storeOf(preferences)),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  return _Setup(container, store, clock, preferences);
}

/// Opened for 5 days, the first of them 10 days before 2026-11-20.
const ReviewState _ready = ReviewState(
  firstOpenDay: CivilDay(2026, 11, 10),
  lastOpenDay: CivilDay(2026, 11, 19),
  openDays: 5,
);

void main() {
  group('recording opens', () {
    test('a day is counted once however many times the app opens', () async {
      final s = await _setup();
      await s.service.recordOpen();
      await s.service.recordOpen();
      expect(s.state.openDays, 1);
      expect(s.state.firstOpenDay, const CivilDay(2026, 11, 20));
      s.clock.now = DateTime(2026, 11, 21, 8);
      await s.service.recordOpen();
      expect(s.state.openDays, 2);
    });

    test('two opens at once never lose a day', () async {
      final s = await _setup();
      s.clock.now = DateTime(2026, 11, 20);
      final a = s.service.recordOpen();
      final b = s.service.recordSettingsImport();
      await Future.wait([a, b]);
      expect(s.state.openDays, 1);
      expect(s.state.lastImportDay, const CivilDay(2026, 11, 20));
    });

    test('counters are not in the settings export', () async {
      final files = FakeSettingsBackupFiles();
      final s = await _setup(
        state: _ready.withRequestOn(const CivilDay(2026, 11, 19), '9.8.7'),
        overrides: [
          settingsBackupFilesProvider.overrideWithValue(files),
          recipeBookProvider.overrideWith(
            (ref) async => const RecipeBook(
              schemaVersion: 1,
              recipesVersion: 'test',
              recipes: [
                Recipe(
                  id: 'verano-98',
                  name: LocalizedText(es: '', ca: '', en: ''),
                  description: LocalizedText(es: '', ca: '', en: ''),
                ),
              ],
            ),
          ),
        ],
      );
      await s.service.recordOpen();
      await s.service.recordSettingsImport();
      expect(
        s.preferences.getKeys().any((k) => k.startsWith('carrete.review')),
        isTrue,
        reason: 'the counters exist on the device',
      );

      final backup = s.container.read(settingsBackupProvider);
      expect(await backup.exportSettings(), isTrue);
      final exported = utf8.decode(files.output!);
      for (final needle in [
        'review',
        'openDays',
        'firstOpenDay',
        'lastOpenDay',
        'requestedVersions',
        'lastRequestDay',
        'lastImportDay',
        '2026-11-',
        '9.8.7',
      ]) {
        expect(exported, isNot(contains(needle)), reason: needle);
      }

      // And an import of that file leaves the counters as they were.
      final before = s.state.toJson();
      files.input = files.output;
      await backup.importSettings();
      await pumpEventQueue();
      final after = s.state.toJson();
      expect(after['openDays'], before['openDays']);
      expect(after['requestedVersions'], before['requestedVersions']);
    });
  });

  group('asking after a success moment', () {
    test('asks the store when the policy allows it, and notes it', () async {
      final s = await _setup(state: _ready);
      await s.service.maybeAskAfterSuccess();
      expect(s.store.requests, 1);
      expect(s.state.requestedVersions, ['0.2.0']);
      expect(s.state.lastRequestDay, const CivilDay(2026, 11, 20));
    });

    test('two triggers at once ask once', () async {
      final s = await _setup(state: _ready);
      await Future.wait([
        s.service.maybeAskAfterSuccess(),
        s.service.maybeAskAfterSuccess(),
      ]);
      expect(s.store.requests, 1);
      expect(s.state.requestCount, 1);
    });

    test('two triggers while the store answers still ask once', () async {
      final s = await _setup(state: _ready);
      s.store.gate = Completer<void>();
      final a = s.service.maybeAskAfterSuccess();
      final b = s.service.maybeAskAfterSuccess();
      await Future<void>.delayed(Duration.zero);
      s.store.gate!.complete();
      await Future.wait([a, b]);
      expect(s.store.requests, 1);
    });

    test('an open at the same time does not undo the request', () async {
      final s = await _setup(state: _ready);
      s.clock.now = DateTime(2026, 11, 21);
      s.store.gate = Completer<void>();
      final ask = s.service.maybeAskAfterSuccess();
      final open = s.service.recordOpen();
      await Future<void>.delayed(Duration.zero);
      s.store.gate!.complete();
      await Future.wait([ask, open]);
      expect(s.state.requestCount, 1);
      expect(s.state.openDays, 6);
      expect(s.state.lastOpenDay, const CivilDay(2026, 11, 21));
    });

    test('an unavailable store means nothing happens', () async {
      final s = await _setup(state: _ready);
      s.store.available = false;
      await s.service.maybeAskAfterSuccess();
      expect(s.store.requests, 0);
      expect(s.state.requestCount, 0);
    });

    test('a store that fails is swallowed', () async {
      final s = await _setup(state: _ready);
      s.store.failAvailable = true;
      await s.service.maybeAskAfterSuccess();
      expect(s.store.requests, 0);

      s.store.failAvailable = false;
      s.store.failRequest = true;
      await s.service.maybeAskAfterSuccess();
      expect(s.store.requests, 1);
      // Written before asking: a failed sheet is not asked again at once.
      expect(s.state.requestCount, 1);
    });

    test('no own work, first use or a young install: nothing', () async {
      final noWork = await _setup(state: _ready, ownWork: false);
      await noWork.service.maybeAskAfterSuccess();
      expect(noWork.store.requests, 0);

      final firstUse = await _setup(state: _ready, firstMinuteDone: false);
      await firstUse.service.maybeAskAfterSuccess();
      expect(firstUse.store.requests, 0);

      final young = await _setup(
        state: const ReviewState(
          firstOpenDay: CivilDay(2026, 11, 14),
          openDays: 5,
        ),
      );
      await young.service.maybeAskAfterSuccess();
      expect(young.store.requests, 0);
    });

    test('an import recorded earlier keeps it quiet', () async {
      final s = await _setup(
        state: ReviewState(
          firstOpenDay: _ready.firstOpenDay,
          openDays: 5,
          lastImportDay: const CivilDay(2026, 11, 18),
        ),
      );
      await s.service.maybeAskAfterSuccess();
      expect(s.store.requests, 0);
    });

    test('an import that starts while the store answers stops it', () async {
      final s = await _setup(state: _ready);
      s.store.gate = Completer<void>();
      final ask = s.service.maybeAskAfterSuccess();
      await Future<void>.delayed(Duration.zero);
      final import = s.service.recordSettingsImport();
      s.store.gate!.complete();
      await Future.wait([ask, import]);
      expect(s.store.requests, 0);
      expect(s.state.requestCount, 0);
      expect(s.state.lastImportDay, const CivilDay(2026, 11, 20));
    });

    test(
      'an import that starts while the request is written stops it',
      () async {
        final gate = Completer<void>();
        final gates = [gate];
        final s = await _setup(
          state: _ready,
          storeOf: (p) => _GatedStore(p, gates),
        );
        final ask = s.service.maybeAskAfterSuccess();
        // Let the ask reach the write of the request, held by the gate.
        await pumpEventQueue();
        expect(gates, isEmpty, reason: 'the write of the request is waiting');
        final import = s.service.recordSettingsImport();
        await pumpEventQueue();
        expect(s.store.requests, 0);
        gate.complete();
        await Future.wait([ask, import]);
        expect(s.store.requests, 0, reason: 'the store is never asked');
        expect(
          s.state.requestCount,
          0,
          reason: 'and the request is given back',
        );
        expect(s.state.lastImportDay, const CivilDay(2026, 11, 20));
      },
    );

    test(
      'a whole import, from its first step, keeps the store quiet',
      () async {
        final s = await _setup(state: _ready);
        s.store.gate = Completer<void>();
        final ask = s.service.maybeAskAfterSuccess();
        await pumpEventQueue();
        final reading = Completer<void>();
        final import = s.service.guardSettingsImport(() => reading.future);
        s.store.gate!.complete();
        await ask;
        expect(s.store.requests, 0, reason: 'the import is still reading');
        reading.complete();
        await import;
        // Over (and never recorded, as when it was cancelled): asks again.
        await s.service.maybeAskAfterSuccess();
        expect(s.store.requests, 1);
      },
    );

    test('a failed or cancelled import releases the quiet', () async {
      final s = await _setup(state: _ready);
      await expectLater(
        s.service.guardSettingsImport<void>(
          () async => throw StateError('bad file'),
        ),
        throwsStateError,
      );
      expect(await s.service.guardSettingsImport(() async => null), isNull);
      await s.service.maybeAskAfterSuccess();
      expect(s.store.requests, 1);
    });

    test('counters that cannot be saved do not ask the store', () async {
      for (final throws in [false, true]) {
        final s = await _setup(
          state: _ready,
          storeOf: (p) => ReviewStore(_RefusingPreferences(p, throws: throws)),
        );
        await s.service.maybeAskAfterSuccess();
        expect(s.store.requests, 0, reason: 'throws: $throws');
        expect(s.state.requestCount, 0);
      }
    });

    test('the version limit holds across asks', () async {
      final s = await _setup(state: _ready);
      await s.service.maybeAskAfterSuccess();
      s.clock.now = DateTime(2027, 3, 1);
      await s.service.maybeAskAfterSuccess();
      expect(s.store.requests, 1, reason: 'same version');
    });
  });

  group('the store listing', () {
    test('opens with the app store id, and swallows errors', () async {
      final s = await _setup(appStoreId: '123');
      await s.service.openStoreListing();
      expect(s.store.listings, ['123']);

      final none = await _setup();
      await none.service.openStoreListing();
      expect(none.store.listings, [null]);
    });
  });
}
