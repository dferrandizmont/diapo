import 'package:diapo/core/settings/settings_provider.dart';
import 'package:diapo/l10n/app_localizations.dart';
import 'package:diapo/render/film_resources.dart';
import 'package:diapo/review/review_service.dart';
import 'package:diapo/screens/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

class _FakeStore implements StoreReviewPlatform {
  final List<String?> listings = [];

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> requestReview() async {}

  @override
  Future<void> openStoreListing({String? appStoreId}) async {
    listings.add(appStoreId);
  }
}

Future<_FakeStore> _pump(WidgetTester tester, {String? appStoreId}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final store = _FakeStore();
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(412, 3000);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        recipeBookProvider.overrideWith((ref) async => testBook()),
        storeReviewPlatformProvider.overrideWithValue(store),
        reviewAppStoreIdProvider.overrideWithValue(appStoreId),
      ],
      child: MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(today: DateTime(2026, 7, 14)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return store;
}

void main() {
  final rate = find.byKey(const ValueKey('settings-rate'));

  testWidgets('Android shows the row and opens the store listing', (
    tester,
  ) async {
    final store = await _pump(tester);
    expect(rate, findsOneWidget);
    expect(find.text('Valorar Diapo'), findsOneWidget);
    expect(
      find.text('Una reseña ayuda a que otros la encuentren'),
      findsOneWidget,
    );
    await tester.tap(rate);
    await tester.pump();
    expect(store.listings, [null]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('iOS without an App Store id hides the row', (tester) async {
    await _pump(tester);
    expect(rate, findsNothing);
    expect(find.text('Valorar Diapo'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS with an App Store id shows the row and passes the id', (
    tester,
  ) async {
    final store = await _pump(tester, appStoreId: '123456');
    expect(rate, findsOneWidget);
    await tester.tap(rate);
    await tester.pump();
    expect(store.listings, ['123456']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
