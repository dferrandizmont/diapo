import 'dart:async';

import 'package:diapo/camera/camera_providers.dart';
import 'package:diapo/capture/capture_providers.dart';
import 'package:diapo/capture/capture_queue.dart';
import 'package:diapo/capture/save_status.dart';
import 'package:diapo/core/database/app_database.dart';
import 'package:diapo/core/settings/settings_provider.dart';
import 'package:diapo/l10n/app_localizations.dart';
import 'package:diapo/platform/system_settings.dart';
import 'package:diapo/render/film_resources.dart';
import 'package:diapo/roll/roll_providers.dart';
import 'package:diapo/screens/viewfinder/save_status_chip.dart';
import 'package:diapo/screens/viewfinder/viewfinder_screen.dart';
import 'package:diapo/ui/theme/carrete_tokens.dart';
import 'package:diapo/ui/widgets/plastic_controls.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

class _FakeStatus extends SaveStatusController {
  _FakeStatus(this.initial);

  final SaveStatus initial;

  @override
  SaveStatus build() => initial;
}

Future<FakeCaptureQueue> _pump(
  WidgetTester tester, {
  SaveStatus? status,
  Brightness brightness = Brightness.dark,
  double textScale = 1,
  Size size = const Size(412, 915),
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final queue = FakeCaptureQueue();
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeRollProvider.overrideWith((ref) => Stream<RollRow?>.value(null)),
        remainingFramesProvider.overrideWith((ref) => Stream.value(0)),
        systemSettingsProvider.overrideWithValue(FakeSystemSettings()),
        sharedPreferencesProvider.overrideWithValue(preferences),
        cameraServiceProvider.overrideWithValue(FakeCameraService()),
        captureQueueProvider.overrideWithValue(queue),
        recipeBookProvider.overrideWith((ref) async => testBook()),
        filmResourcesProvider.overrideWith((ref) async => null),
        if (status != null)
          saveStatusProvider.overrideWith(() => _FakeStatus(status)),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        theme: ThemeData(brightness: brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const ViewfinderScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return queue;
}

final _pending = find.byKey(const ValueKey('save-status-pending'));
final _saving = find.byKey(const ValueKey('save-status-saving'));

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('the chip sits under the top bar, clear of the keys and the '
          'carousel ($brightness, text x$scale)', (tester) async {
        await _pump(
          tester,
          status: const SaveStatus(failed: 3),
          brightness: brightness,
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        expect(_pending, findsOneWidget);
        final chip = tester.getRect(_pending);
        for (final key in const ['settings-key', 'roll-key']) {
          final other = tester.getRect(find.byKey(ValueKey(key)));
          expect(
            chip.overlaps(other),
            isFalse,
            reason: 'the chip does not cover $key',
          );
        }
        expect(
          chip.overlaps(tester.getRect(find.byType(ShutterButton))),
          isFalse,
        );
        // Above the shutter row: nothing of the controls is under it.
        expect(
          chip.bottom,
          lessThan(tester.getTopLeft(find.byType(ShutterButton)).dy),
        );
        // The picture is where it was: the chip does not move it.
        expect(
          tester.getRect(find.byKey(const ValueKey('viewfinder-frame'))).top,
          greaterThanOrEqualTo(chip.top),
        );
      });
    }
  }

  testWidgets('tapping the chip opens the sheet over the camera', (
    tester,
  ) async {
    await _pump(
      tester,
      status: const SaveStatus(failed: 2, problem: SaveProblem.storageFull),
    );
    await tester.tap(_pending);
    await tester.pumpAndSettle();
    expect(find.byType(SaveRecoverySheet), findsOneWidget);
    expect(find.textContaining('run out of space'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('save-sheet-later')));
    await tester.pumpAndSettle();
    expect(find.byType(SaveRecoverySheet), findsNothing);
    expect(_pending, findsOneWidget);
  });

  testWidgets('the camera says it is saving after 400 ms, from the real '
      'queue count', (tester) async {
    final queue = await _pump(tester);
    expect(_pending, findsNothing);
    expect(_saving, findsNothing);

    queue.pendingCount = 2;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_saving, findsNothing, reason: 'not yet');
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(CarreteSaveStatus.fade);
    expect(find.text('Saving 2 photos'), findsOneWidget);

    queue.pendingCount = 0;
    await tester.pump();
    await tester.pumpAndSettle();
    expect(_saving, findsNothing);
  });

  group('the photo is only announced as saved once it is stored', () {
    late List<Object?> announced;

    setUp(() => announced = <Object?>[]);

    Future<void> listen(WidgetTester tester) async {
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (
            message,
          ) async {
            announced.add(message);
            return null;
          });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<dynamic>(
              SystemChannels.accessibility,
              null,
            ),
      );
    }

    String says(Object? message) => '$message';

    testWidgets('a saved event with a place in the gallery is announced', (
      tester,
    ) async {
      final queue = await _pump(tester);
      await listen(tester);
      final job = _job();
      queue.saved(job, 'content://photo/1');
      await tester.pump();
      expect(announced.map(says), contains(contains('Photo saved')));
    });

    testWidgets('one without a place is not, and a failure never is', (
      tester,
    ) async {
      final queue = await _pump(tester);
      await listen(tester);
      queue
        ..saved(_job(), null)
        ..failed(_job());
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      expect(announced.map(says), isNot(contains(contains('Photo saved'))));
    });
  });
}

CaptureJob _job() => CaptureJob(
  filePath: '/cache/CAP1.jpg',
  filmId: 'alpha',
  look: resolve(testBook().byId('alpha')!),
  format: FrameFormat.r3x2,
  seed: 1,
  takenAt: DateTime(2026, 11, 9),
);
