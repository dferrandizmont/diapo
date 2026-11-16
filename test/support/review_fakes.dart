import 'package:diapo/core/settings/review_state.dart';
import 'package:diapo/core/settings/settings_provider.dart';
import 'package:diapo/review/review_service.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The review dialog of the store, counting how many times it was asked.
class CountingStoreReview implements StoreReviewPlatform {
  int requests = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> requestReview() async => requests++;

  @override
  Future<void> openStoreListing({String? appStoreId}) async {}
}

/// Providers that make [ReviewPolicy] say yes at the roll tests' clock
/// (2026-11-13): the app was opened for 5 days since 2026-11-01, the person
/// has own work and the first minute is over. Put them after the roll
/// providers. The store only counts what it is asked.
Future<List<Override>> reviewReadyOverrides(CountingStoreReview store) async {
  SharedPreferences.setMockInitialValues({
    'carrete.firstMinute.swipeHintSeen': true,
  });
  final preferences = await SharedPreferences.getInstance();
  await ReviewStore(preferences).save(
    const ReviewState(
      firstOpenDay: CivilDay(2026, 11, 1),
      lastOpenDay: CivilDay(2026, 11, 12),
      openDays: 5,
    ),
  );
  return [
    sharedPreferencesProvider.overrideWithValue(preferences),
    storeReviewPlatformProvider.overrideWithValue(store),
    reviewOwnWorkProvider.overrideWithValue(() async => true),
    reviewAppVersionProvider.overrideWithValue('0.2.0'),
  ];
}

/// Lets the asynchronous steps of a review request finish.
Future<void> flushReview(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(Duration.zero);
  }
}
