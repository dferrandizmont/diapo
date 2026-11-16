import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the page of the system settings that belongs to this app (where the
/// user can grant the camera permission again).
///
/// Available on Android and iOS. Where it is
/// not available [canOpen] is false and the screens show text only.
class SystemSettings {
  const SystemSettings();

  static const MethodChannel _channel = MethodChannel('carrete/system');

  /// Whether this platform can open the settings of the app.
  bool get canOpen =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Opens the settings of the app. False when the system could not.
  Future<bool> open() async {
    if (!canOpen) return false;
    try {
      return await _channel.invokeMethod<bool>('openAppSettings') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Whether the system says the camera permission is granted. Null when it
  /// cannot tell (unsupported platform, or the call failed): the camera plugin then
  /// answers for itself.
  Future<bool?> cameraPermissionGranted() async {
    if (!canOpen) return null;
    try {
      return await _channel.invokeMethod<bool>('cameraPermission');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}

/// The system settings of the device. The tests override it.
final systemSettingsProvider = Provider<SystemSettings>(
  (ref) => const SystemSettings(),
);
