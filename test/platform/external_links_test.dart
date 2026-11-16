import 'package:diapo/platform/external_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('carrete/system');

  setUp(ExternalLinks.resetRepeatGuard);

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  void answer(Object? Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => handler(call));
  }

  test(
    'openKofi calls the native openKofi without arguments (Android)',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final calls = <MethodCall>[];
      answer((call) {
        calls.add(call);
        return true;
      });
      expect(await const ExternalLinks().openKofi(), isTrue);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'openKofi');
      expect(calls.single.arguments, isNull);
    },
  );

  test('says false when the system could not open it', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    answer((call) => false);
    expect(await const ExternalLinks().openKofi(), isFalse);
  });

  test('a failing call or a missing method is a plain false', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    answer((call) => throw PlatformException(code: 'boom'));
    expect(await const ExternalLinks().openKofi(), isFalse);
    // No handler: the method is missing.
    ExternalLinks.resetRepeatGuard();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    expect(await const ExternalLinks().openKofi(), isFalse);
  });

  test('only Android can open it, and iOS does not call the channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var called = false;
    answer((call) {
      called = true;
      return true;
    });
    const links = ExternalLinks();
    expect(links.canOpen, isFalse);
    expect(await links.openKofi(), isFalse);
    expect(called, isFalse);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(links.canOpen, isTrue);
  });

  test('a quick second tap does not open the page twice', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    var calls = 0;
    answer((call) {
      calls++;
      return true;
    });
    const links = ExternalLinks();
    expect(await links.openKofi(), isTrue);
    expect(await links.openKofi(), isTrue);
    expect(calls, 1);
    ExternalLinks.resetRepeatGuard();
    expect(await links.openKofi(), isTrue);
    expect(calls, 2);
  });
}
