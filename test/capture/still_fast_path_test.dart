import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:carrete/capture/capture_queue.dart';
import 'package:carrete/capture/failed_shots.dart';
import 'package:carrete/location/photo_location.dart';
import 'package:carrete/capture/film_capture_processor.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/local_shutter_time.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calendar = DateTime(2026, 11, 14);
  final shutter = LocalShutterTime(
    calendar,
    calendar.timeZoneOffset + const Duration(hours: 1),
  );
  final location = PhotoLocation(
    latitude: 48.654321,
    longitude: -3.123456,
    altitude: -12.5,
    accuracy: 10,
    time: DateTime.fromMillisecondsSinceEpoch(
      shutter.millisecondsSinceEpoch,
      isUtc: true,
    ),
  );

  for (final large in [false, true]) {
    testWidgets(
      large
          ? 'large source uses tiles even when its crop fits 24 MP'
          : '3008 square still uses one legacy render and pixel message',
      (tester) async {
        await tester.runAsync(() async {
          final cache = await Directory.systemTemp.createTemp('carrete_fast_');
          addTearDown(() => cache.delete(recursive: true));
          final width = large ? 6000 : 3008;
          final height = large ? 4001 : 3008;
          final recorder = ui.PictureRecorder();
          ui.Canvas(recorder)
              .drawColor(const ui.Color(0xffb06030), ui.BlendMode.src);
          final picture = recorder.endRecording();
          final image = await picture.toImage(width, height);
          picture.dispose();
          final original = File('${cache.path}/photo.png');
          try {
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            await original.writeAsBytes(Uint8List.sublistView(png!));
          } finally {
            image.dispose();
          }

          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          const method = MethodChannel('carrete/media');
          const pixels = BasicMessageChannel<ByteData?>(
            'carrete/media/pixels',
            BinaryCodec(),
          );
          const tiles = BasicMessageChannel<ByteData?>(
            'carrete/media/tiles',
            BinaryCodec(),
          );
          final methods = <String>[];
          var pixelMessages = 0;
          var tileMessages = 0;
          var coveredPixels = 0;
          var outputWidth = 0;
          var outputHeight = 0;
          ByteData reply() => ByteData.sublistView(
            utf8.encode('{"ok":true,"uri":"content://saved"}'),
          );

          messenger.setMockMethodCallHandler(method, (call) async {
            methods.add(call.method);
            if (call.method == 'cancelTiledSave') return null;
            expect(call.method, large ? 'beginTiledSave' : 'beginSave');
            final args = call.arguments as Map;
            outputWidth = args['width'] as int;
            outputHeight = args['height'] as int;
            expect((
              outputWidth,
              outputHeight,
            ), large ? (6000, 4000) : (3008, 3008));
            expect(args['sourcePath'], original.path);
            expect(args['includeLocation'], isTrue);
            expect(args['location'], location.toJson());
            expect(args['takenAt'], shutter.millisecondsSinceEpoch);
            expect(args['displayName'], 'CARRETE_fast_path');
            return 7;
          });
          messenger.setMockDecodedMessageHandler<ByteData?>(pixels, (
            message,
          ) async {
            expect(large, isFalse);
            pixelMessages++;
            expect(message!.lengthInBytes, width * height * 4);
            return reply();
          });
          messenger.setMockDecodedMessageHandler<ByteData?>(tiles, (
            message,
          ) async {
            expect(large, isTrue);
            tileMessages++;
            final bytes = message!;
            expect(bytes.getInt32(0, Endian.little), 7);
            final w = bytes.getInt32(12, Endian.little);
            final h = bytes.getInt32(16, Endian.little);
            expect(w, inInclusiveRange(1, 1024));
            expect(h, inInclusiveRange(1, 1024));
            expect(bytes.lengthInBytes, 20 + w * h * 4);
            coveredPixels += w * h;
            return coveredPixels == outputWidth * outputHeight
                ? reply()
                : ByteData.sublistView(utf8.encode('{"ok":true}'));
          });
          addTearDown(() {
            messenger.setMockMethodCallHandler(method, null);
            messenger.setMockDecodedMessageHandler<ByteData?>(pixels, null);
            messenger.setMockDecodedMessageHandler<ByteData?>(tiles, null);
          });

          SavedStill? saved;
          final processor = FilmCaptureProcessor(
            loadProgram: () =>
                ui.FragmentProgram.fromAsset('shaders/film.frag'),
            onSaved: (_, still) async {
              saved = still;
            },
          );
          final recipe = testBook().recipes.first;
          final captured = CaptureJob(
            filePath: original.path,
            filmId: recipe.id,
            look: resolve(recipe),
            format: large ? FrameFormat.r3x2 : FrameFormat.r1x1,
            seed: 97.125,
            takenAt: shutter,
            displayName: 'CARRETE_fast_path',
            includeLocation: true,
            location: location,
          );
          final snapshot = FailedShots.encode(captured, attempts: 0)
            ..['location'] = location.toJson();
          final restored = FailedShots.decode(
            snapshot,
            testBook(),
            original.path,
          )!.withFile(original.path, displayName: 'CARRETE_fast_path');
          expect(restored.takenAt, calendar);
          expect(
            restored.location!.isUsableAt(restored.shutterInstant!),
            isTrue,
          );
          final uri = await processor.process(restored);
          expect(uri, 'content://saved');
          expect((saved!.width, saved!.height), (outputWidth, outputHeight));
          expect(pixelMessages, large ? 0 : 1);
          expect(tileMessages, large ? 24 : 0);
          expect(
            methods,
            large ? ['beginTiledSave', 'cancelTiledSave'] : ['beginSave'],
          );
          expect(original.existsSync(), isFalse);
        });
      },
    );
  }
}
