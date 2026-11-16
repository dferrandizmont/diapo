import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../camera/camera_service.dart';
import 'location_provider.dart';

/// Acquisition is tied to the visible camera route and foreground lifecycle,
/// independently of whether navigation leaves the camera controller alive.
class CameraLocationSession with WidgetsBindingObserver {
  CameraLocationSession(this.controller, this.camera, this.route) {
    WidgetsBinding.instance.addObserver(this);
    camera.addListener(sync);
    route.addListener(sync);
  }

  final LocationController controller;
  final ValueListenable<CameraServiceState> camera;
  final GoRouterDelegate route;
  bool enabled = false;
  bool _foreground =
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  void sync() {
    final configuration = route.currentConfiguration;
    final path = configuration.isEmpty
        ? null
        : configuration.last.matchedLocation;
    controller.setActive(
      enabled &&
          _foreground &&
          camera.value.ready &&
          (path == '/' || path == '/disposable'),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    sync();
    if (_foreground) controller.refreshPermission();
  }

  void dispose() {
    camera.removeListener(sync);
    route.removeListener(sync);
    WidgetsBinding.instance.removeObserver(this);
    controller.setActive(false);
  }
}
