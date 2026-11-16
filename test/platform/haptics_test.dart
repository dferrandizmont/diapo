import 'package:diapo/platform/camera_sounds.dart';
import 'package:diapo/platform/haptics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final played = <Object?>[];

  setUp(() {
    played.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            played.add(call.arguments);
          }
          return null;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('iOS follows the setting without querying the ringer', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var enabled = true;
    final h = Haptics(
      enabled: () => enabled,
      ringerMode: () async => throw StateError('iOS must not query the ringer'),
    );
    await h.selectionClick();
    await h.mediumImpact();
    await h.lightImpact();
    expect(played, hasLength(3));
    enabled = false;
    played.clear();
    await h.selectionClick();
    await h.mediumImpact();
    await h.lightImpact();
    expect(played, isEmpty);
  });

  Haptics haptics({
    bool Function()? enabled,
    RingerMode? ringer = RingerMode.normal,
  }) => Haptics(enabled: enabled ?? () => true, ringerMode: () async => ringer);

  test('plays the three kinds', () async {
    final h = haptics();
    await h.selectionClick();
    await h.mediumImpact();
    await h.lightImpact();
    expect(played, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.lightImpact',
    ]);
  });

  test('plays nothing when the setting is off', () async {
    final h = haptics(enabled: () => false);
    await h.selectionClick();
    await h.mediumImpact();
    await h.lightImpact();
    expect(played, isEmpty);
  });

  test('plays nothing on silent', () async {
    final h = haptics(ringer: RingerMode.silent);
    await h.selectionClick();
    expect(played, isEmpty);
  });

  test('plays on vibrate, where the user asked for vibration', () async {
    final h = haptics(ringer: RingerMode.vibrate);
    await h.mediumImpact();
    expect(played, ['HapticFeedbackType.mediumImpact']);
  });

  test('plays nothing when the ringer cannot be read', () async {
    final h = haptics(ringer: null);
    await h.selectionClick();
    expect(played, isEmpty);
  });

  test('the setting is checked again after asking for the ringer', () async {
    var enabled = true;
    final h = Haptics(
      enabled: () => enabled,
      ringerMode: () async {
        enabled = false;
        return RingerMode.normal;
      },
    );
    await h.selectionClick();
    expect(played, isEmpty);
  });
}
