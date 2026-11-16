import 'dart:async';

import 'package:diapo/core/settings/settings_provider.dart';
import 'package:diapo/location/location_provider.dart';
import 'package:diapo/location/location_source.dart';
import 'package:diapo/location/photo_location.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeLocationSource implements LocationSource {
  LocationPermission status = LocationPermission.granted;
  int requests = 0;
  int updates = 0;
  int starts = 0;
  int stops = 0;
  PhotoLocation? fix;
  Completer<PhotoLocation?>? pending;
  @override
  Future<void> start() async {
    starts++;
  }

  @override
  Future<LocationPermission> permission({bool request = false}) async {
    if (request) requests++;
    return status;
  }

  @override
  Future<LocationReading> current() async {
    updates++;
    return LocationReading(
      status,
      await (pending?.future ?? Future.value(fix)),
    );
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'native expiry clears a held fix after the wall clock moves back',
    () async {
      var now = DateTime.utc(2026, 11, 14, 12);
      final fix = PhotoLocation(
        latitude: 40,
        longitude: -3,
        accuracy: 10,
        time: now,
      );
      var expired = false;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(NativeLocationSource.channel, (
        call,
      ) async {
        return switch (call.method) {
          'permission' => 'granted',
          'current' => {
            'permission': 'granted',
            'fix': expired ? null : fix.toJson(),
          },
          _ => null,
        };
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          NativeLocationSource.channel,
          null,
        ),
      );
      final controller = LocationController(
        NativeLocationSource(),
        clock: () => now,
      );
      addTearDown(controller.dispose);
      controller.setActive(true);
      await pumpEventQueue();
      expect(controller.at(now), isNotNull);
      now = now.add(const Duration(minutes: 3));
      expect(controller.at(now), isNull);
      now = now.subtract(const Duration(minutes: 2));
      expect(
        fix.isUsableAt(now),
        isTrue,
        reason: 'wall time alone would revive the expired fix',
      );
      expired = true;
      await controller.update();
      expect(controller.permission, LocationPermission.granted);
      expect(controller.at(now), isNull);
    },
  );

  for (final changedDuring in ['start', 'current']) {
    for (final (nextPermission, hasFix) in [
      (LocationPermission.coarseOnly, false),
      (LocationPermission.coarseOnly, true),
      (LocationPermission.denied, false),
    ]) {
      test(
        'native change during $changedDuring to $nextPermission, fix=$hasFix clears held precise fix',
        () async {
          final now = DateTime.utc(2026, 11, 14, 12);
          final precise = PhotoLocation(
            latitude: 40,
            longitude: -3,
            accuracy: 10,
            time: now,
          );
          final coarse = PhotoLocation(
            latitude: 41,
            longitude: -3,
            accuracy: 2000,
            time: now.subtract(const Duration(seconds: 30)),
            approximate: true,
          );
          var permission = LocationPermission.granted;
          var change = false;
          final calls = <String>[];
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(NativeLocationSource.channel, (
            call,
          ) async {
            calls.add(call.method);
            if (change && call.method == changedDuring) {
              permission = nextPermission;
            }
            return switch (call.method) {
              'permission' => permission.name,
              'current' => {
                'permission': permission.name,
                'fix': change
                    ? (hasFix ? coarse.toJson() : null)
                    : precise.toJson(),
              },
              _ => null,
            };
          });
          addTearDown(
            () => messenger.setMockMethodCallHandler(
              NativeLocationSource.channel,
              null,
            ),
          );
          final controller = LocationController(
            NativeLocationSource(),
            clock: () => now,
          );
          addTearDown(controller.dispose);
          controller.setActive(true);
          await pumpEventQueue();
          expect(controller.at(now)!.approximate, isFalse);
          calls.clear();
          change = true;
          await controller.update();
          expect(controller.permission, nextPermission);
          expect(calls.take(3), ['permission', 'start', 'current']);
          expect(calls, isNot(contains('requestPermission')));
          if (hasFix) {
            expect(
              controller.at(now)!.toJson(),
              coarse.toJson(),
              reason: 'older coarse fix must replace a newer held precise fix',
            );
          } else {
            expect(controller.at(now), isNull);
          }
        },
      );
    }
  }

  test(
    'coarse-only fixes stay approximate across permission changes',
    () async {
      var now = DateTime.utc(2026, 11, 14, 12);
      final source = FakeLocationSource()
        ..status = LocationPermission.coarseOnly
        ..fix = PhotoLocation(
          latitude: 40,
          longitude: -3,
          accuracy: 2000,
          time: now,
          approximate: true,
        );
      final controller = LocationController(source, clock: () => now);
      addTearDown(controller.dispose);
      controller.setActive(true);
      await pumpEventQueue();
      final coarseFix = controller.at(now)!;
      expect(coarseFix.approximate, isTrue);
      expect(coarseFix.isUsableAt(now), isTrue);

      source.status = LocationPermission.granted;
      await controller.refreshPermission();
      expect(controller.at(now), isNull);
      expect(source.stops, 1, reason: 'permission upgrades stop old updates');
      expect(coarseFix.approximate, isTrue);
      now = now.add(const Duration(seconds: 30));
      source.fix = PhotoLocation(
        latitude: 40,
        longitude: -3,
        accuracy: 2000,
        time: now,
      );
      await controller.update();
      expect(controller.at(now), isNull);
      now = now.add(const Duration(seconds: 30));
      source.fix = PhotoLocation(
        latitude: 40,
        longitude: -3,
        accuracy: 10,
        time: now,
      );
      await controller.update();
      expect(controller.at(now)!.approximate, isFalse);

      source.status = LocationPermission.coarseOnly;
      await controller.refreshPermission();
      expect(controller.at(now), isNull);
      expect(source.stops, 2, reason: 'permission downgrades stop old updates');
      now = now.add(const Duration(seconds: 30));
      source.fix = PhotoLocation(
        latitude: 40,
        longitude: -3,
        accuracy: 2000,
        time: now,
        approximate: true,
      );
      await controller.update();
      expect(controller.at(now)!.approximate, isTrue);
      expect(source.requests, 0);
    },
  );

  test('native fixes preserve their acquisition permission in JSON', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final now = DateTime.utc(2026, 11, 14, 12);
    final json = <String, Object?>{
      'latitude': 40.0,
      'longitude': -3.0,
      'accuracy': 2000.0,
      'time': now.millisecondsSinceEpoch,
      'approximate': true,
    };
    messenger.setMockMethodCallHandler(
      NativeLocationSource.channel,
      (call) async => switch (call.method) {
        'permission' => 'coarseOnly',
        'current' => {'permission': 'coarseOnly', 'fix': json},
        _ => null,
      },
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        NativeLocationSource.channel,
        null,
      ),
    );
    final source = NativeLocationSource();
    final reading = await source.current();
    expect(reading.permission, LocationPermission.coarseOnly);
    expect(reading.fix!.isUsableAt(now), isTrue);
    json.remove('approximate');
    final legacy = (await source.current()).fix!;
    expect(legacy.approximate, isFalse);
    expect(legacy.isUsableAt(now), isFalse);
  });

  test(
    'only usable fixes replace the held fix, newest before accuracy',
    () async {
      var now = DateTime.utc(2026, 11, 14, 12);
      final source = FakeLocationSource()
        ..fix = PhotoLocation(
          latitude: 40,
          longitude: -3,
          accuracy: 10,
          time: now,
        );
      final controller = LocationController(source, clock: () => now);
      addTearDown(controller.dispose);
      controller.setActive(true);
      await pumpEventQueue();
      final initial = source.fix;
      expect(controller.at(now), same(initial));
      now = now.add(const Duration(seconds: 5));
      source.fix = PhotoLocation(
        latitude: 41,
        longitude: -3,
        accuracy: 50,
        time: now,
      );
      await controller.update();
      final newest = source.fix;
      expect(controller.at(now), same(newest));
      source.fix = initial;
      await controller.update();
      expect(
        controller.at(now),
        same(newest),
        reason: 'older but more accurate',
      );
      now = now.add(const Duration(seconds: 5));
      source.fix = PhotoLocation(
        latitude: 40,
        longitude: -3,
        accuracy: 150,
        time: now,
      );
      await controller.update();
      expect(controller.at(now), same(newest), reason: 'newer but unusable');
      now = now.add(const Duration(minutes: 3));
      expect(controller.at(now), isNull);
    },
  );

  test(
    'native permission maps every result and only explicit requests prompt',
    () async {
      final calls = <String>[];
      var status = 'granted';
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(NativeLocationSource.channel, (
        call,
      ) async {
        calls.add(call.method);
        return status;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          NativeLocationSource.channel,
          null,
        ),
      );
      final source = NativeLocationSource();
      for (final permission in LocationPermission.values) {
        status = permission.name;
        expect(await source.permission(), permission);
        expect(await source.permission(request: true), permission);
      }
      expect(calls, [
        'permission',
        'requestPermission',
        'permission',
        'requestPermission',
        'permission',
        'requestPermission',
        'permission',
        'requestPermission',
      ]);
      messenger.setMockMethodCallHandler(NativeLocationSource.channel, (
        _,
      ) async {
        throw PlatformException(code: 'unavailable');
      });
      final reading = await source.current();
      expect(reading.fix, isNull);
      expect(reading.permission, LocationPermission.denied);
      expect(await source.permission(), LocationPermission.denied);
    },
  );

  test(
    'settings stay enabled after revocation, with no implicit prompt',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final source = FakeLocationSource();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          locationSourceProvider.overrideWithValue(source),
        ],
      );
      addTearDown(container.dispose);
      final settings = container.read(settingsProvider.notifier);
      settings.setSaveLocation(true);
      expect(source.requests, 0);
      expect(
        await settings.requestLocationPermission(),
        LocationPermission.granted,
      );
      expect(source.requests, 1);
      source.status = LocationPermission.permanentlyDenied;
      final states = <LocationPermission>[];
      final subscription = container.listen(locationPermissionProvider, (
        _,
        next,
      ) {
        if (next.hasValue) states.add(next.requireValue);
      }, fireImmediately: true);
      addTearDown(subscription.close);
      await pumpEventQueue();
      expect(states.last, LocationPermission.permanentlyDenied);
      expect(container.read(settingsProvider).saveLocation, isTrue);
      expect(source.requests, 1);
    },
  );

  testWidgets(
    'starts and reads updates while active, stops on inactive and dispose',
    (tester) async {
      final now = DateTime.utc(2026, 11, 14, 12);
      final source = FakeLocationSource()
        ..fix = PhotoLocation(
          latitude: 40,
          longitude: -3,
          accuracy: 10,
          time: now,
        );
      final controller = LocationController(source, clock: () => now);
      controller.setActive(true);
      await tester.pump();
      expect(source.starts, 1);
      expect(source.updates, 1);
      await tester.pump(const Duration(seconds: 5));
      expect(source.updates, 2);
      controller.setActive(false);
      expect(source.stops, 1);
      expect(controller.at(now), isNull);
      await tester.pump(const Duration(seconds: 15));
      expect(source.updates, 2);
      controller.setActive(true);
      await tester.pump();
      expect(source.updates, 3, reason: 'reactivation has no old throttle');
      controller.dispose();
      expect(source.stops, 2);
      await tester.pump(const Duration(seconds: 15));
      expect(source.updates, 3);
    },
  );

  test('cancels, rejects late replies and revoked fixes', () async {
    var now = DateTime.utc(2026, 11, 14, 12);
    final source = FakeLocationSource()
      ..fix = PhotoLocation(
        latitude: 40,
        longitude: -3,
        accuracy: 10,
        time: now,
      );
    final controller = LocationController(source, clock: () => now);
    addTearDown(controller.dispose);
    expect(controller.at(now), isNull);
    controller.setActive(true);
    await pumpEventQueue();
    expect(source.updates, 1);
    expect(controller.at(now), same(source.fix));
    await controller.update();
    expect(source.updates, 2);
    controller.setActive(false);
    expect(controller.at(now), isNull);
    controller.setActive(true);
    await pumpEventQueue();
    expect(source.updates, 3);
    now = now.add(const Duration(seconds: 5));
    source.pending = Completer();
    final request = controller.update();
    await pumpEventQueue();
    controller.setActive(false);
    source.pending!.complete(
      PhotoLocation(latitude: 41, longitude: 2, accuracy: 5, time: now),
    );
    await request;
    source.pending = null;
    source.fix = null;
    controller.setActive(true);
    await pumpEventQueue();
    expect(
      controller.at(now)?.latitude,
      isNull,
      reason: 'deactivation clears the old fix and late replies stay discarded',
    );
    source.status = LocationPermission.denied;
    await controller.refreshPermission();
    expect(controller.at(now), isNull);
    expect(source.requests, 0);
    expect(source.stops, greaterThanOrEqualTo(2));
  });

  for (final (approximate, minutes, accepted) in [
    (false, 3, false),
    (true, 8, true),
    (true, 11, false),
  ]) {
    test('active fix age $minutes min, approximate=$approximate', () async {
      final now = DateTime.utc(2026, 11, 14, 12);
      final source = FakeLocationSource()
        ..status = approximate
            ? LocationPermission.coarseOnly
            : LocationPermission.granted
        ..fix = PhotoLocation(
          latitude: 40,
          longitude: -3,
          accuracy: approximate ? 2000 : 10,
          time: now.subtract(Duration(minutes: minutes)),
          approximate: approximate,
        );
      final controller = LocationController(source, clock: () => now);
      addTearDown(controller.dispose);
      controller.setActive(true);
      await pumpEventQueue();
      expect(controller.at(now), accepted ? same(source.fix) : isNull);
    });
  }

  test(
    'permission changes clear fixes and reject an in-flight precise reply',
    () async {
      var now = DateTime.utc(2026, 11, 14, 12);
      final source = FakeLocationSource()
        ..fix = PhotoLocation(
          latitude: 40,
          longitude: -3,
          accuracy: 10,
          time: now,
        );
      final controller = LocationController(source, clock: () => now);
      addTearDown(controller.dispose);
      controller.setActive(true);
      await pumpEventQueue();
      expect(controller.at(now), isNotNull);
      source.status = LocationPermission.coarseOnly;
      await controller.refreshPermission();
      expect(controller.at(now), isNull);
      now = now.add(const Duration(seconds: 30));
      source.pending = Completer();
      final updating = controller.update();
      await pumpEventQueue();
      source.status = LocationPermission.granted;
      await controller.refreshPermission();
      source.pending!.complete(source.fix);
      await updating;
      expect(controller.at(now), isNull);
    },
  );
}
