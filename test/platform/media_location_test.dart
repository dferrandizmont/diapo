import 'dart:convert';

import 'package:carrete/location/photo_location.dart';
import 'package:carrete/platform/media_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final location = PhotoLocation(
    latitude: 40,
    longitude: -3,
    accuracy: 10,
    altitude: 650,
    time: DateTime.utc(2026, 11, 14, 12),
  );

  test(
    'all save paths receive the shutter time and the opted in fix',
    () async {
      final calls = <MethodCall>[];
      const channel = MethodChannel('carrete/media');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'saveOriginal' ? 'content://original/1' : 1;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      const pixels = BasicMessageChannel<ByteData?>(
        'carrete/media/pixels',
        BinaryCodec(),
      );
      messenger.setMockDecodedMessageHandler<ByteData?>(
        pixels,
        (_) async => ByteData.sublistView(
          utf8.encode(jsonEncode({'ok': true, 'uri': 'content://saved/1'})),
        ),
      );
      addTearDown(
        () => messenger.setMockDecodedMessageHandler<ByteData?>(pixels, null),
      );
      final shutter = location.time.add(const Duration(seconds: 30));
      for (final enabled in [false, true]) {
        await MediaStore.beginTiledSave(
          width: 2,
          height: 3,
          tileSize: 2,
          displayName: 'CARRETE_1',
          sourcePath: '/cache/CAP.jpg',
          includeLocation: enabled,
          location: location,
          takenAt: shutter,
        );
        await MediaStore.saveOriginal(
          sourcePath: '/cache/CAP.jpg',
          displayName: 'CARRETE_1_original',
          includeLocation: enabled,
          location: location,
          takenAt: shutter,
        );
        await MediaStore.saveRgbaAsJpeg(
          rgba: Uint8List(2 * 3 * 4),
          width: 2,
          height: 3,
          displayName: 'CARRETE_1',
          sourcePath: '/cache/CAP.jpg',
          includeLocation: enabled,
          location: location,
          takenAt: shutter,
        );
        for (final call in calls.skip(calls.length - 3)) {
          final args = call.arguments as Map;
          expect(args['takenAt'], shutter.millisecondsSinceEpoch);
          expect(args['includeLocation'], enabled);
          if (enabled) {
            expect(args['location'], location.toJson());
          } else {
            expect(args, isNot(contains('location')));
          }
        }
      }
    },
  );
}
