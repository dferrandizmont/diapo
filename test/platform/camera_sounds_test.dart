import 'dart:async';

import 'package:diapo/platform/camera_sounds.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake `carrete/system` channel that answers like the native side.
class _Native {
  _Native(this.ringer);

  String? ringer;
  bool failRinger = false;
  final List<String> calls = <String>[];
  final List<String> played = <String>[];

  /// What loadSounds answers; the call waits for [loadGate] when it is set.
  bool loadResult = true;
  Completer<void>? loadGate;
  Object? loadArguments;

  Future<Object?> handle(MethodCall call) async {
    calls.add(call.method);
    switch (call.method) {
      case 'ringerMode':
        if (failRinger) throw PlatformException(code: 'boom');
        return ringer;
      case 'loadSounds':
        loadArguments = call.arguments;
        await loadGate?.future;
        return loadResult;
      case 'playSound':
        played.add((call.arguments as Map)['name'] as String);
        return true;
    }
    return null;
  }
}

const MethodChannel _channel = MethodChannel('carrete/system');

_Native _install(String ringer) {
  final native = _Native(ringer);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, native.handle);
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null),
  );
  return native;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('iOS defaults to native playback', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final native = _install('normal');
    final service = CameraSounds();
    addTearDown(service.dispose);
    await service.preload();
    await service.playLoad();
    expect(native.calls, ['loadSounds', 'ringerMode', 'playSound']);
    expect(native.played, ['load']);
  });

  CameraSounds sounds({Duration advance = const Duration(milliseconds: 50)}) =>
      CameraSounds(supported: true, advanceDelay: advance);

  group('with the ringer on', () {
    test('plays the click now and the whirr after the delay', () async {
      final native = _install('normal');
      final service = sounds();
      addTearDown(service.dispose);
      await service.preload();

      await service.playShot();
      expect(native.played, [CameraSounds.shutterSound]);

      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(native.played, [
        CameraSounds.shutterSound,
        CameraSounds.advanceSound,
      ]);
    });

    test('loads sounds once, however many shots', () async {
      final native = _install('normal');
      final service = sounds(advance: Duration.zero);
      addTearDown(service.dispose);

      await service.preload();
      await service.playShot();
      await service.playShot();

      expect(native.calls.where((c) => c == 'loadSounds'), hasLength(1));
      // No path crosses the channel: the native side knows the names.
      expect(native.loadArguments, isNull);
      expect(CameraSounds.shutterSound, 'shutter');
      expect(CameraSounds.advanceSound, 'advance');
    });

    test('does not play the whirr of a service that was disposed', () async {
      final native = _install('normal');
      final service = sounds();
      await service.preload();

      await service.playShot();
      service.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(native.played, [CameraSounds.shutterSound]);
    });
  });

  group('silent mode', () {
    for (final mode in ['silent', 'vibrate']) {
      test('plays nothing on $mode', () async {
        final native = _install(mode);
        final service = sounds(advance: Duration.zero);
        addTearDown(service.dispose);
        await service.preload();

        await service.playShot();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(native.calls, contains('ringerMode'));
        expect(native.played, isEmpty);
      });
    }

    test('plays nothing when the ringer cannot be read', () async {
      final native = _install('normal')..failRinger = true;
      final service = sounds(advance: Duration.zero);
      addTearDown(service.dispose);
      await service.preload();

      await service.playShot();

      expect(native.played, isEmpty);
    });

    test('plays nothing when the answer is not a known mode', () async {
      final native = _install('loud');
      final service = sounds(advance: Duration.zero);
      addTearDown(service.dispose);
      await service.preload();

      await service.playShot();

      expect(native.played, isEmpty);
    });
  });

  group('the loading', () {
    test('preload completes only when the native side has decoded', () async {
      final native = _install('normal')..loadGate = Completer<void>();
      final service = sounds(advance: Duration.zero);
      addTearDown(service.dispose);

      var done = false;
      unawaited(service.preload().then((_) => done = true));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(done, isFalse);

      native.loadGate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(done, isTrue);
    });

    test(
      'a shot before the sounds are decoded is silent and loads them',
      () async {
        final native = _install('normal')..loadGate = Completer<void>();
        final service = sounds(advance: Duration.zero);
        addTearDown(service.dispose);

        await service.playShot();
        expect(native.played, isEmpty);
        expect(native.calls, ['loadSounds']);

        native.loadGate!.complete();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await service.playShot();
        expect(native.played, contains(CameraSounds.shutterSound));
      },
    );

    test('a load that failed or timed out is tried again', () async {
      final native = _install('normal')..loadResult = false;
      final service = sounds(advance: Duration.zero);
      addTearDown(service.dispose);

      await service.preload();
      await service.playShot();
      expect(native.played, isEmpty);
      // Let the load that the shot started finish before the answer changes.
      await Future<void>.delayed(const Duration(milliseconds: 20));

      native.loadResult = true;
      await service.preload();
      await service.playShot();
      expect(native.calls.where((c) => c == 'loadSounds'), hasLength(3));
      expect(native.played, contains(CameraSounds.shutterSound));
    });
  });

  final effects = <String, Future<void> Function(CameraSounds)>{
    'cartridge': (service) => service.playCartridge(),
    'load': (service) => service.playLoad(),
    'rewind': (service) => service.playRewind(),
  };
  for (final effect in effects.entries) {
    group(effect.key, () {
      test('plays the right name once in normal mode', () async {
        final native = _install('normal');
        final service = sounds();
        addTearDown(service.dispose);
        await service.preload();

        await effect.value(service);

        expect(native.played, [effect.key]);
        expect(native.calls, ['loadSounds', 'ringerMode', 'playSound']);
      });

      for (final mode in ['silent', 'vibrate', 'unknown']) {
        test('stays silent in $mode mode', () async {
          final native = _install(mode);
          final service = sounds();
          addTearDown(service.dispose);
          await service.preload();

          await effect.value(service);

          expect(native.calls, contains('ringerMode'));
          expect(native.played, isEmpty);
        });
      }

      test('stays silent when the ringer cannot be read', () async {
        final native = _install('normal')..failRinger = true;
        final service = sounds();
        addTearDown(service.dispose);
        await service.preload();

        await effect.value(service);

        expect(native.played, isEmpty);
      });

      test('respects changes to the sounds setting', () async {
        final native = _install('normal');
        var enabled = false;
        final service = CameraSounds(
          supported: true,
          soundsEnabled: () => enabled,
        );
        addTearDown(service.dispose);

        await effect.value(service);
        expect(native.calls, isEmpty);

        enabled = true;
        await service.preload();
        await effect.value(service);
        expect(native.played, [effect.key]);

        enabled = false;
        native.calls.clear();
        await effect.value(service);
        expect(native.calls, isEmpty);
        expect(native.played, [effect.key]);
      });

      test('skips an effect before decoding without playing it late', () async {
        final native = _install('normal')..loadGate = Completer<void>();
        final service = sounds();
        addTearDown(service.dispose);

        await effect.value(service);
        expect(native.calls, ['loadSounds']);
        expect(native.played, isEmpty);

        native.loadGate!.complete();
        await service.preload();
        expect(native.played, isEmpty);

        await effect.value(service);
        expect(native.played, [effect.key]);
      });

      test('stays silent when loading fails', () async {
        final native = _install('normal')..loadResult = false;
        final service = sounds();
        addTearDown(service.dispose);
        await service.preload();

        await effect.value(service);
        await service.preload();

        expect(native.played, isEmpty);
      });

      test('does nothing on an unsupported platform', () async {
        final native = _install('normal');
        final service = CameraSounds(supported: false);
        addTearDown(service.dispose);
        await service.preload();

        await effect.value(service);

        expect(native.calls, isEmpty);
      });

      test('does not throw when the native side is missing', () async {
        final service = sounds();
        addTearDown(service.dispose);

        await service.preload();
        await effect.value(service);
        await service.preload();
      });

      test('does nothing after disposal', () async {
        final native = _install('normal');
        final service = sounds();
        await service.preload();
        service.dispose();
        native.calls.clear();

        await effect.value(service);

        expect(native.calls, isEmpty);
      });
    });
  }

  test('a platform without the native side does nothing', () async {
    final native = _install('normal');
    final service = CameraSounds(supported: false);
    addTearDown(service.dispose);

    await service.preload();
    await service.playShot();

    expect(native.calls, isEmpty);
  });

  test('a missing native side is not an error', () async {
    // No handler installed: every call throws MissingPluginException.
    final service = sounds(advance: Duration.zero);
    addTearDown(service.dispose);

    await service.playShot();
    expect(await service.ringerMode(), isNull);
  });
}
