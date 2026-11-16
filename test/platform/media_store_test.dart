import 'dart:convert';
import 'dart:typed_data' show Endian;

import 'package:diapo/platform/media_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake native side: records the metadata of `beginSave` and the pixels
/// that follow, and answers like the Kotlin channel does.
class _FakeNative {
  _FakeNative({this.fail = false});

  final bool fail;
  final List<Map<Object?, Object?>> begins = <Map<Object?, Object?>>[];
  final List<int> pixelLengths = <int>[];

  void install() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const method = MethodChannel('carrete/media');
    const pixels = BasicMessageChannel<ByteData?>(
      'carrete/media/pixels',
      BinaryCodec(),
    );
    messenger.setMockMethodCallHandler(method, (call) async {
      expect(call.method, 'beginSave');
      begins.add(call.arguments as Map<Object?, Object?>);
      return begins.length;
    });
    messenger.setMockDecodedMessageHandler<ByteData?>(pixels, (message) async {
      pixelLengths.add(message?.lengthInBytes ?? -1);
      final reply = fail
          ? {'ok': false, 'error': 'disk full'}
          : {'ok': true, 'uri': 'content://1', 'encodeMs': 3};
      return ByteData.sublistView(utf8.encode(jsonEncode(reply)));
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(method, null);
      messenger.setMockDecodedMessageHandler<ByteData?>(pixels, null);
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final rgba = Uint8List(2 * 3 * 4);

  test(
    'findSaved queries the native gallery with a stable display name',
    () async {
      const channel = MethodChannel('carrete/media');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'findSaved');
        expect(call.arguments, {'displayName': 'CARRETE_20261113_shot_7'});
        return 'content://images/7';
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      expect(
        await MediaStore.findSaved('CARRETE_20261113_shot_7'),
        'content://images/7',
      );
    },
  );

  test('findSaved returns null when no finished export exists', () async {
    const channel = MethodChannel('carrete/media');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    expect(await MediaStore.findSaved('CARRETE_20261113_shot_7'), isNull);
  });

  test('passes includeLocation false by default', () async {
    final native = _FakeNative()..install();
    final out = await MediaStore.saveRgbaAsJpeg(
      rgba: rgba,
      width: 2,
      height: 3,
      displayName: 'CARRETE_1',
      sourcePath: '/cache/CAP1.jpg',
    );
    expect(native.begins.single['includeLocation'], isFalse);
    expect(native.begins.single['width'], 2);
    expect(native.begins.single['height'], 3);
    expect(native.begins.single['displayName'], 'CARRETE_1');
    expect(native.begins.single['sourcePath'], '/cache/CAP1.jpg');
    expect(native.pixelLengths, [24], reason: 'the pixels alone, no header');
    expect(out['uri'], 'content://1');
    expect(out['encodeMs'], 3);
    expect(out.containsKey('ok'), isFalse);
  });

  test('passes includeLocation true when asked', () async {
    final native = _FakeNative()..install();
    await MediaStore.saveRgbaAsJpeg(
      rgba: rgba,
      width: 2,
      height: 3,
      displayName: 'CARRETE_2',
      includeLocation: true,
    );
    expect(native.begins.single['includeLocation'], isTrue);
  });

  test('a native error becomes a PlatformException', () async {
    _FakeNative(fail: true).install();
    expect(
      () => MediaStore.saveRgbaAsJpeg(
        rgba: rgba,
        width: 2,
        height: 3,
        displayName: 'CARRETE_3',
      ),
      throwsA(
        isA<PlatformException>().having(
          (e) => e.message,
          'message',
          'disk full',
        ),
      ),
    );
  });

  test(
    'tile transport sends a token and exact little-endian geometry',
    () async {
      const channel = MethodChannel('carrete/media');
      const tiles = BasicMessageChannel<ByteData?>(
        'carrete/media/tiles',
        BinaryCodec(),
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        final args = call.arguments as Map;
        if (call.method == 'beginTiledSave') {
          expect(args['width'], 8160);
          expect(args['height'], 6120);
          expect(args['tileSize'], 1024);
          expect(args['includeLocation'], false);
          expect(args['framed'], false);
          return 73;
        }
        expect(args['token'], 73);
        return null;
      });
      messenger.setMockDecodedMessageHandler<ByteData?>(tiles, (message) async {
        final bytes = message!;
        expect(bytes.lengthInBytes, 44);
        expect(List.generate(5, (i) => bytes.getInt32(i * 4, Endian.little)), [
          73,
          1024,
          2048,
          2,
          3,
        ]);
        expect(Uint8List.sublistView(bytes, 20), List.generate(24, (i) => i));
        return ByteData.sublistView(
          utf8.encode('{"ok":true,"uri":"content://tile"}'),
        );
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        messenger.setMockDecodedMessageHandler<ByteData?>(tiles, null);
      });
      final token = await MediaStore.beginTiledSave(
        width: 8160,
        height: 6120,
        tileSize: 1024,
        displayName: 'CARRETE_50MP',
      );
      final reply = await MediaStore.saveTile(
        token: token,
        x: 1024,
        y: 2048,
        width: 2,
        height: 3,
        rgba: Uint8List.fromList(List.generate(24, (i) => i)),
      );
      expect(reply['uri'], 'content://tile');
      expect(reply.containsKey('ok'), false);
      await MediaStore.cancelTiledSave(token);
      expect(calls, ['beginTiledSave', 'cancelTiledSave']);
    },
  );

  test(
    'framed output explicitly requests the larger native print bounds',
    () async {
      const channel = MethodChannel('carrete/media');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'beginTiledSave');
        expect((call.arguments as Map)['framed'], true);
        return 74;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      expect(
        await MediaStore.beginTiledSave(
          width: 7920,
          height: 8910,
          tileSize: 1024,
          displayName: 'CARRETE_print',
          framed: true,
        ),
        74,
      );
    },
  );

  test(
    'tile errors propagate and malformed bytes never enter the channel',
    () async {
      const tiles = BasicMessageChannel<ByteData?>(
        'carrete/media/tiles',
        BinaryCodec(),
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var calls = 0;
      messenger.setMockDecodedMessageHandler<ByteData?>(tiles, (_) async {
        calls++;
        return ByteData.sublistView(
          utf8.encode('{"ok":false,"error":"out of order tile"}'),
        );
      });
      addTearDown(
        () => messenger.setMockDecodedMessageHandler<ByteData?>(tiles, null),
      );
      await expectLater(
        MediaStore.saveTile(
          token: 1,
          x: 0,
          y: 0,
          width: 2,
          height: 3,
          rgba: Uint8List(4),
        ),
        throwsArgumentError,
      );
      expect(calls, 0);
      await expectLater(
        MediaStore.saveTile(
          token: 1,
          x: 0,
          y: 0,
          width: 2,
          height: 3,
          rgba: rgba,
        ),
        throwsA(isA<PlatformException>()),
      );
      expect(calls, 1);
    },
  );

  test('refuses pixels that do not match the size', () async {
    final native = _FakeNative()..install();
    expect(
      () => MediaStore.saveRgbaAsJpeg(
        rgba: rgba,
        width: 4,
        height: 4,
        displayName: 'CARRETE_4',
      ),
      throwsArgumentError,
    );
    expect(native.begins, isEmpty);
  });
}
