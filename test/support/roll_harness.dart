import 'dart:async';

import 'package:diapo/core/database/app_database.dart';
import 'package:diapo/l10n/app_localizations.dart';
import 'package:diapo/platform/gallery_images.dart';
import 'package:diapo/render/film_resources.dart';
import 'package:diapo/roll/roll_developer.dart';
import 'package:diapo/roll/roll_reveal.dart';
import 'package:diapo/roll/roll_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'roll_fakes.dart';

/// The providers of the roll screens, answering from plain values.
List<Override> rollOverrides({
  RollRow? active,
  Stream<RollRow?>? activeStream,
  int? framesLeft,
  List<RollRow> rolls = const [],
  Stream<List<RollRow>>? rollsStream,
  Stream<int>? framesStream,
  Stream<List<ShotRow>>? shotsStream,
  Map<int, List<ShotRow>> shots = const {},
  Map<int, DevelopProgress> progress = const {},
  GalleryImages? gallery,
  DateTime? now,
  DateTime Function()? clock,
  RollService? service,
  RollForeground? foreground,
  RollRevealStore? reveal,
  Stream<RollRow?>? rollStream,
}) => [
  activeRollProvider.overrideWith(
    (ref) => activeStream ?? Stream.value(active),
  ),
  remainingFramesProvider.overrideWith(
    (ref) => framesStream ?? Stream.value(framesLeft ?? active?.length ?? 0),
  ),
  rollsListProvider.overrideWith((ref) => rollsStream ?? Stream.value(rolls)),
  rollProvider.overrideWith(
    (ref, id) =>
        rollStream ?? Stream.value(rolls.where((r) => r.id == id).firstOrNull),
  ),
  rollShotsProvider.overrideWith(
    (ref, id) => shotsStream ?? Stream.value(shots[id] ?? const []),
  ),
  rollDevelopProgressProvider.overrideWith((ref, id) {
    final p = progress[id];
    return p == null ? const Stream.empty() : Stream.value(p);
  }),
  recipeBookProvider.overrideWith((ref) async => testBook()),
  galleryImagesProvider.overrideWithValue(gallery ?? FakeGalleryImages()),
  rollClockProvider.overrideWithValue(
    clock ?? () => now ?? DateTime(2026, 11, 13, 12),
  ),
  if (service != null) rollServiceProvider.overrideWithValue(service),
  rollForegroundProvider.overrideWithValue(
    foreground ?? RollForeground(develop: () async {}),
  ),
  // By default every roll was already revealed: the frames are just there.
  rollRevealStoreProvider.overrideWithValue(
    reveal ?? MemoryRollRevealStore(allSeen: true),
  ),
];

/// Pumps [home] in an app with the roll providers, in English, with the theme
/// [mode].
Future<void> pumpRollApp(
  WidgetTester tester,
  Widget home, {
  List<Override> overrides = const [],
  ThemeMode mode = ThemeMode.light,
  Locale locale = const Locale('en'),
  Size size = const Size(412, 915),
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: locale,
        themeMode: mode,
        theme: ThemeData(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}
