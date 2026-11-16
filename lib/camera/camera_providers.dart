import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/router.dart';
import '../core/settings/settings_provider.dart';
import '../location/camera_location_session.dart';
import '../location/location_provider.dart';
import 'camera_service.dart';
import 'plugin_camera_service.dart';

/// The camera of the device. Overridden with a fake in the widget tests.
final cameraServiceProvider = Provider<CameraService>((ref) {
  final service = PluginCameraService();
  final location = CameraLocationSession(
    ref.read(locationControllerProvider),
    service.state,
    ref.read(routerProvider).routerDelegate,
  );
  ref.listen(settingsProvider.select((s) => s.saveLocation), (_, enabled) {
    location.enabled = enabled;
    location.sync();
  }, fireImmediately: true);
  ref.onDispose(location.dispose);
  ref.onDispose(service.dispose);
  return service;
});
