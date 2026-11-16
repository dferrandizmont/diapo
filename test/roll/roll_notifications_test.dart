import 'package:carrete/core/database/app_database.dart';
import 'package:carrete/core/database/tables.dart';
import 'package:carrete/l10n/app_localizations_en.dart';
import 'package:carrete/l10n/app_localizations_es.dart';
import 'package:carrete/roll/roll_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  final taps = <int>[];
  var coldLaunch = false;
  late LocalRollNotifications notifications;

  setUp(() {
    calls.clear();
    taps.clear();
    coldLaunch = false;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'getNotificationAppLaunchDetails') {
            return {
              'notificationLaunchedApp': coldLaunch,
              'notificationResponse': {
                'notificationId': 7,
                'payload': '7',
                'notificationResponseType': 0,
              },
            };
          }
          if (call.method == 'initialize' ||
              call.method == 'requestNotificationsPermission') {
            return true;
          }
          return null;
        });
    notifications = LocalRollNotifications(
      texts: AppLocalizationsEn.new,
      onTap: taps.add,
    );
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test(
    'initialization does not request permission; delayed action does',
    () async {
      await notifications.initialize();
      expect(calls.map((c) => c.method), [
        'initialize',
        'getNotificationAppLaunchDetails',
      ]);
      await notifications.requestPermission();
      expect(calls.last.method, 'requestNotificationsPermission');
      expect(calls.where((c) => c.method == 'initialize'), hasLength(1));
    },
  );

  test('schedules an inexact UTC notification with the photo count and tap payload', () async {
    final due = DateTime.now().add(const Duration(days: 3));
    await notifications.schedule(
      RollRow(
        id: 7,
        filmId: 'gamma',
        length: 24,
        mode: RollMode.roll,
        developDelay: DevelopDelay.threeDays,
        state: RollState.developing,
        createdAt: 1,
        developAt: due.millisecondsSinceEpoch,
      ),
      photos: 24,
    );
    final arguments = calls.last.arguments as Map;
    expect(calls.last.method, 'zonedSchedule');
    expect(arguments['payload'], '7');
    expect(arguments['body'], contains('24'));
    expect(arguments['timeZoneName'], 'Etc/UTC');
    expect(
      arguments['platformSpecifics']['scheduleMode'],
      'inexactAllowWhileIdle',
    );
    expect(
      calls.any((c) => c.method == 'requestExactAlarmsPermission'),
      isFalse,
    );
    await notifications.cancel(7);
    expect(calls.last.method, 'cancel');
    expect(calls.last.arguments['id'], 7);
  });

  test('a roll closed early counts its photos, singular included', () async {
    RollRow row(int id) => RollRow(
      id: id,
      filmId: 'gamma',
      length: 36,
      mode: RollMode.roll,
      developDelay: DevelopDelay.oneHour,
      state: RollState.developing,
      createdAt: 1,
      developAt: DateTime.now()
          .add(const Duration(hours: 1))
          .millisecondsSinceEpoch,
    );
    await notifications.schedule(row(8), photos: 2);
    expect(
      (calls.last.arguments as Map)['body'],
      'Open the app to develop your 2 photos. Keep it open until it finishes.',
    );
    await notifications.schedule(row(9), photos: 1);
    expect(
      (calls.last.arguments as Map)['body'],
      'Open the app to develop your photo. Keep it open until it finishes.',
    );
  });

  test('the notification promises nothing that happens by itself', () async {
    RollRow row(int id) => RollRow(
      id: id,
      filmId: 'gamma',
      length: 24,
      mode: RollMode.roll,
      developDelay: DevelopDelay.oneHour,
      state: RollState.developing,
      createdAt: 1,
      developAt: DateTime.now()
          .add(const Duration(hours: 1))
          .millisecondsSinceEpoch,
    );
    final spanish = LocalRollNotifications(
      texts: AppLocalizationsEs.new,
      onTap: taps.add,
    );
    await spanish.schedule(row(8), photos: 24);
    final arguments = calls.last.arguments as Map;
    expect(arguments['title'], 'Ya puedes revelar tu carrete');
    expect(
      arguments['body'],
      'Abre la app para revelar tus 24 fotos. Mantenla abierta hasta terminar.',
    );
    await notifications.schedule(row(9), photos: 24);
    expect(
      (calls.last.arguments as Map)['title'],
      'You can develop your roll now',
    );
  });

  test('cold launch delivers the roll id once', () async {
    coldLaunch = true;
    await notifications.initialize();
    await notifications.initialize();
    expect(taps, [7]);
  });

  test('warm taps deliver valid ids and ignore invalid payloads', () async {
    await notifications.initialize();
    for (final payload in ['7', '/roll/7', '-1', '']) {
      final reply = TestDefaultBinaryMessengerBinding
          .instance
          .defaultBinaryMessenger
          .handlePlatformMessage(
            channel.name,
            const StandardMethodCodec().encodeMethodCall(
              MethodCall('didReceiveNotificationResponse', {
                'notificationId': 7,
                'payload': payload,
                'notificationResponseType': 0,
              }),
            ),
            (_) {},
          );
      await reply;
    }
    expect(taps, [7]);
  });
}
