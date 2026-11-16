import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../core/database/app_database.dart';
import '../l10n/app_localizations.dart';

abstract interface class RollNotifications {
  Future<void> requestPermission();

  /// Announces that [roll], holding [photos] photos, is ready to develop.
  Future<void> schedule(RollRow roll, {required int photos});
  Future<void> cancel(int rollId);
}

/// Notifications announce readiness; they never decrypt or render a photo.
class LocalRollNotifications implements RollNotifications {
  LocalRollNotifications({
    required this.texts,
    required this.onTap,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final AppLocalizations Function() texts;
  final void Function(int rollId) onTap;
  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _initialization;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    tz_data.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_roll_ready'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) => _tap(response.payload),
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _tap(launch?.notificationResponse?.payload);
    }
  }

  void _tap(String? payload) {
    final id = int.tryParse(payload ?? '');
    if (id != null && id > 0) onTap(id);
  }

  @override
  Future<void> requestPermission() async {
    await initialize();
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: false, sound: true);
  }

  @override
  Future<void> schedule(RollRow roll, {required int photos}) async {
    await initialize();
    final l10n = texts();
    // An absolute UTC instant needs no device timezone plugin or permission.
    await _plugin.zonedSchedule(
      id: roll.id,
      title: l10n.rollReadyTitle,
      body: l10n.rollReadyBody(photos),
      scheduledDate: tz.TZDateTime.fromMillisecondsSinceEpoch(
        tz.UTC,
        roll.developAt!,
      ),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'roll_ready',
          l10n.rollReadyTitle,
          enableVibration: false,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: '${roll.id}',
    );
  }

  @override
  Future<void> cancel(int rollId) async {
    await initialize();
    await _plugin.cancel(id: rollId);
  }
}
