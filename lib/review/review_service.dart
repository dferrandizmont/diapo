import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';

import '../core/app_info.dart';
import '../core/database/database_provider.dart';
import '../core/database/tables.dart';
import '../core/settings/first_minute.dart';
import '../core/settings/review_state.dart';
import '../core/settings/settings_provider.dart';
import '../roll/roll_providers.dart';
import 'review_policy.dart';

/// The review dialog of the store, behind an interface so the tests use a
/// fake. The real one is the `in_app_review` plugin: the system sheet on iOS,
/// Play's in-app review on Android.
abstract class StoreReviewPlatform {
  Future<bool> isAvailable();
  Future<void> requestReview();
  Future<void> openStoreListing({String? appStoreId});
}

/// [StoreReviewPlatform] on the `in_app_review` plugin.
class PluginStoreReviewPlatform implements StoreReviewPlatform {
  const PluginStoreReviewPlatform();

  @override
  Future<bool> isAvailable() => InAppReview.instance.isAvailable();

  @override
  Future<void> requestReview() => InAppReview.instance.requestReview();

  @override
  Future<void> openStoreListing({String? appStoreId}) =>
      InAppReview.instance.openStoreListing(appStoreId: appStoreId);
}

final storeReviewPlatformProvider = Provider<StoreReviewPlatform>(
  (ref) => const PluginStoreReviewPlatform(),
);

/// The version of the app the requests are counted by.
final reviewAppVersionProvider = Provider<String>((ref) => kAppVersion);

/// The App Store id of the app. Null until the app has a listing on iOS.
final reviewAppStoreIdProvider = Provider<String?>((ref) => kAppStoreId);

/// Whether the person has work of their own in the app: a developed roll, or
/// enough loose photos. Read from the database, so a photo deleted from the app
/// does not count and the answer never depends on a counter that can stop.
final reviewOwnWorkProvider = Provider<Future<bool> Function()>((ref) {
  return () async {
    final rolls = await ref.read(rollsDaoProvider).allRolls();
    final developed = rolls.where((r) => r.state == RollState.developed).length;
    final loose = await ref.read(shotsDaoProvider).looseShotCount();
    return ReviewPolicy.ownWork(developedRolls: developed, loosePhotos: loose);
  };
});

/// Records the days the app is opened and, at a success moment, asks the store
/// for a review when [ReviewPolicy] allows it. Nothing here ever shows an
/// error: a failure only means the question is not asked.
class ReviewService {
  ReviewService(this._ref);

  final Ref _ref;

  // Every read-modify-write of the counters runs one after another, so two
  // triggers (or an open and a request) never work on a stale copy.
  Future<void> _tail = Future<void>.value();

  // A settings import was announced and its day is not saved yet. It keeps the
  // store quiet while the import still waits in the queue.
  int _importsPending = 0;

  Future<T> _serial<T>(Future<T> Function() job) {
    final result = _tail.then((_) => job());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  CivilDay get _today => CivilDay.fromDateTime(_ref.read(rollClockProvider)());

  /// Counts today as a day the app was opened (once per day).
  Future<void> recordOpen() async {
    try {
      await _serial(() async {
        final store = _ref.read(reviewStoreProvider);
        await store.save(store.load().withOpenOn(_today));
      });
    } on Object {
      // The counters are a convenience: a failed write changes nothing.
    }
  }

  /// Settings were imported: no request today or in the next few days.
  Future<void> recordSettingsImport() async {
    // Synchronously, so a request that is already past its checks sees it.
    _importsPending++;
    try {
      await _serial(() async {
        final store = _ref.read(reviewStoreProvider);
        await store.save(store.load().withImportOn(_today));
      });
    } on Object {
      // Silent by design.
    } finally {
      _importsPending--;
    }
  }

  /// Runs a whole settings import (reading, validating, waiting in the queue,
  /// writing) with the store kept quiet, from its very start until it ends,
  /// however it ends: done, cancelled or failed.
  Future<T> guardSettingsImport<T>(Future<T> Function() import) async {
    _importsPending++;
    try {
      return await import();
    } finally {
      _importsPending--;
    }
  }

  /// A success moment: asks the store for a review if the policy says yes.
  /// Never throws and never waits for the user.
  Future<void> maybeAskAfterSuccess() async {
    try {
      if (!await _canAsk(_ref.read(reviewStoreProvider).load())) return;
      final platform = _ref.read(storeReviewPlatformProvider);
      if (!await platform.isAvailable()) return;
      // The store answered after a wait: an import may have started meanwhile,
      // and a second trigger may have asked. The check and the note of the
      // request are one step of the queue, so only one trigger gets through.
      final before = await _serial(_claim);
      if (before == null) return;
      // The write took a while too: an import may have started during it.
      // Check once more, right before the store, and take the request back.
      if (_importQuiet(_ref.read(reviewStoreProvider).load())) {
        await _serial(() => _unclaim(before));
        return;
      }
      // The sheet is asked outside the queue: the request is already written,
      // so a second trigger sees it, and an open is not held up.
      await platform.requestReview();
    } on Object {
      // Silent by design.
    }
  }

  /// Notes the request and returns the state it replaced, or null when the
  /// policy says no (now, with the freshest counters).
  Future<ReviewState?> _claim() async {
    final store = _ref.read(reviewStoreProvider);
    final state = store.load();
    if (!await _canAsk(state)) return null;
    await store.save(
      state.withRequestOn(_today, _ref.read(reviewAppVersionProvider)),
    );
    return state;
  }

  /// The request was noted but not made: gives its place back.
  Future<void> _unclaim(ReviewState before) async {
    final store = _ref.read(reviewStoreProvider);
    await store.save(store.load().withLastRequestUndone(before.lastRequestDay));
  }

  /// An import is running, or one was recorded and the silence is not over.
  bool _importQuiet(ReviewState state) =>
      _importsPending > 0 ||
      ReviewPolicy.inImportSilence(state.lastImportDay, _today);

  Future<bool> _canAsk(ReviewState state) async {
    if (_importsPending > 0) return false;
    final hasOwnWork = await _ref.read(reviewOwnWorkProvider)();
    if (_importsPending > 0) return false;
    return ReviewPolicy.shouldAsk(
      state: state,
      today: _today,
      appVersion: _ref.read(reviewAppVersionProvider),
      hasOwnWork: hasOwnWork,
      inFirstUse: !_hasFinishedFirstUse,
    );
  }

  /// The first use is over once the tutorial was seen, the hint about swiping
  /// the films was dismissed or the offer of a first roll was shown (which
  /// takes two photos).
  bool get _hasFinishedFirstUse {
    final firstMinute = _ref.read(firstMinuteProvider);
    return _ref.read(settingsProvider).onboardingSeen ||
        firstMinute.swipeHintSeen ||
        firstMinute.rollOfferSeen;
  }

  /// "Rate Diapo": the store page of the app. Errors are swallowed: a device
  /// with no store has nothing to show.
  Future<void> openStoreListing() async {
    try {
      await _ref
          .read(storeReviewPlatformProvider)
          .openStoreListing(appStoreId: _ref.read(reviewAppStoreIdProvider));
    } on Object {
      // No store on this device.
    }
  }
}

final reviewServiceProvider = Provider<ReviewService>(ReviewService.new);
