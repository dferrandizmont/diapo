import 'package:carrete/platform/system_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('carrete/system');

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  void answer(Object? Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => handler(call));
  }

  test('asks the system whether the camera is granted (Android)', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final calls = <String>[];
    answer((call) {
      calls.add(call.method);
      return false;
    });
    expect(await const SystemSettings().cameraPermissionGranted(), isFalse);
    expect(calls, ['cameraPermission']);
    answer((call) => true);
    expect(await const SystemSettings().cameraPermissionGranted(), isTrue);
  });

  test('does not know when the platform cannot say', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(await const SystemSettings().cameraPermissionGranted(), isNull);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    // No handler: the method is missing.
    expect(await const SystemSettings().cameraPermissionGranted(), isNull);
  });

  test('a failing call is "unknown", not a denial', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    answer((call) => throw PlatformException(code: 'boom'));
    expect(await const SystemSettings().cameraPermissionGranted(), isNull);
  });
}
