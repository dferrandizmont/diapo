import 'dart:async';
import 'dart:io';
import 'dart:typed_data' show Endian;
import 'dart:ui' as ui;

import 'package:carrete/roll/contact_sheet_image.dart';
import 'package:carrete/roll/contact_sheet_layout.dart';
import 'package:carrete/ui/theme/carrete_tokens.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/synthetic_photos.dart';

const _band = ui.Color(0xFF2E9CCA);
final _date = DateTime(2026, 11, 15);

/// The colour of a pixel of [image], read back from its RGBA bytes.
class _Pixels {
  _Pixels(this.width, this.rgba);

  final int width;
  final ByteData rgba;

  ui.Color at(num x, num y) {
    final i = (y.round() * width + x.round()) * 4;
    return ui.Color.fromARGB(
      rgba.getUint8(i + 3),
      rgba.getUint8(i),
      rgba.getUint8(i + 1),
      rgba.getUint8(i + 2),
    );
  }
}

Future<_Pixels> _read(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return _Pixels(image.width, data!);
}

Future<void> _loadFonts() async {
  for (final (family, files) in const [
    ('ChakraPetch', ['ChakraPetch-Regular.ttf', 'ChakraPetch-SemiBold.ttf']),
    ('BarlowSemiCondensed', ['BarlowSemiCondensed-Regular.ttf']),
    ('Caveat', ['Caveat-Variable.ttf']),
  ]) {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = File('assets/fonts/$file').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const colors = CarreteSheetColors.dark;

  setUpAll(_loadFonts);

  group('JPEG encoder', () {
    const channel = BasicMessageChannel<ByteData?>(
      'carrete/media/contact-sheet',
      BinaryCodec(),
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final jpeg = Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]);
    late List<ByteData> calls;
    late Future<ByteData?> Function(ByteData?) answer;

    setUp(() {
      calls = [];
      answer = (message) async => ByteData.sublistView(jpeg);
      messenger.setMockDecodedMessageHandler<ByteData?>(channel, (data) async {
        calls.add(data!);
        return answer(data);
      });
    });

    tearDown(() {
      messenger.setMockDecodedMessageHandler<ByteData?>(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });

    Future<ui.Image> image({int width = 3, int height = 2}) async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(
        recorder,
      ).drawRect(const ui.Rect.fromLTWH(0, 0, 3, 2), ui.Paint()..color = _band);
      final picture = recorder.endRecording();
      try {
        return await picture.toImage(width, height);
      } finally {
        picture.dispose();
      }
    }

    testWidgets('sends dimensions, quality 88 and exact RGBA; returns jpg', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final source = await image();
        addTearDown(source.dispose);
        final encoder = JpegContactSheetEncoder();
        expect(encoder.extension, 'jpg');
        expect(await encoder.encode(source), jpeg);
        expect(encoder.extension, 'jpg');
        final data = calls.single;
        expect(data.getInt32(0, Endian.little), 3);
        expect(data.getInt32(4, Endian.little), 2);
        expect(data.getInt32(8, Endian.little), 88);
        expect(data.lengthInBytes, 12 + 3 * 2 * 4);
        expect(Uint8List.sublistView(data, 12), [
          for (var i = 0; i < 6; i++) ...[46, 156, 202, 255],
        ]);
        // The encoder leaves the source image owned by the caller.
        expect(await source.toByteData(), isNotNull);
      });
    });

    for (final (width, height) in [(4096, 1), (1, 4096), (4000, 4000)]) {
      testWidgets('uses native JPEG at the size limit $width x $height', (
        tester,
      ) async {
        await tester.runAsync(() async {
          final source = await image(width: width, height: height);
          addTearDown(source.dispose);
          final encoder = JpegContactSheetEncoder();
          expect(await encoder.encode(source), jpeg);
          expect(encoder.extension, 'jpg');
          expect(calls.single.getInt32(0, Endian.little), width);
          expect(calls.single.getInt32(4, Endian.little), height);
        });
      });
    }

    for (final (width, height) in [
      (4097, 1),
      (1, 4097),
      (4000, 4001),
      (4001, 4000),
      (4096, 4096),
    ]) {
      testWidgets('oversized $width x $height uses PNG without a native call', (
        tester,
      ) async {
        await tester.runAsync(() async {
          final source = await image(width: width, height: height);
          addTearDown(source.dispose);
          final encoder = JpegContactSheetEncoder();
          final bytes = await encoder.encode(source);
          expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
          expect(encoder.extension, 'png');
          expect(calls, isEmpty);
        });
      });
    }

    for (final failure in [
      'missing plugin',
      'platform error',
      'null',
      'empty',
    ]) {
      testWidgets('falls back to PNG on $failure and updates extension', (
        tester,
      ) async {
        await tester.runAsync(() async {
          answer = (_) async => switch (failure) {
            'missing plugin' => throw MissingPluginException(),
            'platform error' => throw PlatformException(code: 'encode_failed'),
            'empty' => ByteData(0),
            _ => null,
          };
          final source = await image();
          addTearDown(source.dispose);
          final encoder = JpegContactSheetEncoder();
          final bytes = await encoder.encode(source);
          expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
          expect(encoder.extension, 'png');
          final codec = await ui.instantiateImageCodec(bytes);
          final decoded = (await codec.getNextFrame()).image;
          expect(decoded.width, 3);
          expect(decoded.height, 2);
          decoded.dispose();
          codec.dispose();
          answer = (_) async => ByteData.sublistView(jpeg);
          expect(await encoder.encode(source), jpeg);
          expect(encoder.extension, 'jpg');
        });
      });
    }

    for (final nativeWorks in [true, false]) {
      testWidgets('Android cache file extension follows native $nativeWorks', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          await tester.runAsync(() async {
            if (!nativeWorks) answer = (_) async => null;
            final cache = await Directory.systemTemp.createTemp(
              'carrete-sheet',
            );
            addTearDown(() => cache.delete(recursive: true));
            final file = await renderContactSheet(
              frames: const [ContactSheetFrame.missing(1)],
              filmName: 'Test',
              bandColor: _band,
              date: _date,
              cache: cache,
              width: 600,
            );
            expect(calls, hasLength(1));
            expect(file.path, endsWith(nativeWorks ? '.jpg' : '.png'));
            if (nativeWorks) {
              expect(await file.readAsBytes(), jpeg);
            } else {
              expect((await file.readAsBytes()).take(8), [
                137,
                80,
                78,
                71,
                13,
                10,
                26,
                10,
              ]);
            }
          });
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }

    testWidgets('iOS uses PNG without calling the native encoder', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.runAsync(() async {
          final bytes = await encodeContactSheet(
            frames: const [ContactSheetFrame.missing(1)],
            filmName: 'Test',
            bandColor: _band,
            date: _date,
            width: 600,
          );
          expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
          expect(calls, isEmpty);
        });
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('the name of the roll on the leader', () {
    // The sheet of six empty frames, so only the leader has anything to tell.
    Future<(_Pixels, ContactSheetLayout)> sheet(String? rollName) async {
      final frames = [
        for (var i = 1; i <= 6; i++) ContactSheetFrame.missing(i),
      ];
      final image = await paintContactSheet(
        frames: frames,
        filmName: 'Test',
        rollName: rollName,
        bandColor: _band,
        date: _date,
      );
      addTearDown(image.dispose);
      return (await _read(image), ContactSheetLayout(frames.length));
    }

    /// The columns of the leader line with something printed on them, past the
    /// swatch of the film.
    List<int> inkColumns(_Pixels p, ContactSheetLayout layout) {
      final text = layout.leaderTextRect;
      const colors = CarreteSheetColors.dark;
      final columns = <int>[];
      for (
        var x = (text.left + 60 * layout.unit).round();
        x < text.right;
        x++
      ) {
        for (var y = text.top.round(); y < text.bottom; y++) {
          if (p.at(x, y) != colors.strip) {
            columns.add(x);
            break;
          }
        }
      }
      return columns;
    }

    testWidgets('writes the name between the film and the date', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final (plain, layout) = await sheet(null);
        final (named, _) = await sheet('Verano en la playa');
        final text = layout.leaderTextRect;
        final before = inkColumns(plain, layout);
        final after = inkColumns(named, layout);
        // Without a name there is the film, then a gap, then the date.
        final filmRight = before
            .where((x) => x < text.left + 0.5 * text.width)
            .last;
        final dateLeft = before
            .where((x) => x > text.left + 0.5 * text.width)
            .first;
        bool middle(int x) => x > filmRight + 4 && x < dateLeft - 4;
        expect(before.where(middle), isEmpty);
        expect(after.where(middle).length, greaterThan(20));
        // The film and the date are where they were.
        for (final x in before) {
          expect(after, contains(x), reason: 'column $x');
        }
        expect(after.last, before.last);
        expect(after.first, before.first);
      });
    });

    testWidgets('a name that is too long is cut and never reaches the date', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final (plain, layout) = await sheet(null);
        final (named, _) = await sheet('W' * 40);
        final text = layout.leaderTextRect;
        final u = layout.unit;
        final dateLeft = inkColumns(
          plain,
          layout,
        ).where((x) => x > text.left + 0.65 * text.width).first;
        // Everything from just before the date on is the same as without a
        // name: the date is whole and nothing overflows onto it.
        for (var y = text.top.round(); y < text.bottom; y++) {
          for (var x = (dateLeft - 12 * u).round(); x < text.right; x++) {
            expect(named.at(x, y), plain.at(x, y), reason: '$x $y');
          }
        }
        // And it did write something on the line.
        expect(
          inkColumns(named, layout).length,
          greaterThan(inkColumns(plain, layout).length + 50),
        );
      });
    });

    testWidgets('a name of spaces prints nothing', (tester) async {
      await tester.runAsync(() async {
        final (plain, layout) = await sheet(null);
        final (spaces, _) = await sheet('   ');
        expect(inkColumns(spaces, layout), inkColumns(plain, layout));
      });
    });
  });

  testWidgets('paints a mixed roll with a missing frame at the right size', (
    tester,
  ) async {
    await tester.runAsync(() async {
      const green = ui.Color(0xFF2FA84F);
      const red = ui.Color(0xFFC8372D);
      const violet = ui.Color(0xFF7A4DC4);
      final frames = [
        // Landscape 3:2 at the size of a full photo, solid green.
        ContactSheetFrame(
          number: 1,
          load: () => syntheticPhoto(1800, 1200, from: green, solid: true),
        ),
        // Portrait 9:16 solid red: letterboxed at the sides.
        ContactSheetFrame(
          number: 2,
          load: () => syntheticPhoto(540, 960, from: red, solid: true),
        ),
        const ContactSheetFrame.missing(3),
        // A load that fails, and bytes that are not an image: both empty.
        ContactSheetFrame(number: 4, load: () async => throw StateError('x')),
        ContactSheetFrame(
          number: 5,
          load: () async => Uint8List.fromList([1, 2, 3, 4]),
        ),
        // Square, violet.
        ContactSheetFrame(
          number: 6,
          load: () => syntheticPhoto(600, 600, from: violet, solid: true),
        ),
      ];
      final layout = ContactSheetLayout(frames.length);
      final image = await paintContactSheet(
        frames: frames,
        filmName: 'Tungsteno 400',
        bandColor: _band,
        date: _date,
      );
      addTearDown(image.dispose);

      expect(image.width, layout.width);
      expect(image.height, layout.height);

      final p = await _read(image);
      // The sheet around the strips.
      expect(p.at(2, 2), colors.sheet);
      // The strip base between the strips' perforations and the frames.
      final strip = layout.stripRect(0);
      expect(
        p.at(strip.left + 4, strip.top + layout.perfHeight + 2),
        colors.strip,
      );
      // A perforation hole, lit.
      final perf = layout.topPerforations(0);
      final holeX =
          perf.left +
          (perf.width -
                  (perf.width / layout.perfPitch).floor() * layout.perfPitch) /
              2 +
          layout.perfPitch / 2;
      expect(p.at(holeX, perf.center.dy), colors.perf);
      // The band colour is on the leader, and only there.
      final swatch = layout.leaderTextRect;
      expect(p.at(swatch.left + 10, swatch.center.dy), _band);

      // Frame 1 fills its cell: its colour reaches both corners.
      final one = layout.cellRect(0);
      expect(p.at(one.left + 3, one.top + 3), const ui.Color(0xFF2FA84F));
      expect(p.at(one.center.dx, one.center.dy), const ui.Color(0xFF2FA84F));
      // Frame 2 is portrait: red in the middle, the dark base at the sides.
      final two = layout.cellRect(1);
      expect(p.at(two.center.dx, two.center.dy), const ui.Color(0xFFC8372D));
      expect(p.at(two.left + 4, two.center.dy), const ui.Color(0xFF120B05));
      expect(p.at(two.right - 4, two.center.dy), const ui.Color(0xFF120B05));
      // The whole height of the cell is used, so the photo is not cropped.
      expect(p.at(two.center.dx, two.top + 2), const ui.Color(0xFFC8372D));
      expect(p.at(two.center.dx, two.bottom - 3), const ui.Color(0xFFC8372D));
      // Frames 3, 4 and 5 are the empty frame, not black or a photo.
      for (final i in [2, 3, 4]) {
        final cell = layout.cellRect(i);
        expect(p.at(cell.center.dx, cell.center.dy), colors.empty);
        expect(p.at(cell.left + 2, cell.top + 2), colors.empty);
      }
      // Frame 6 is square: violet in a narrower box.
      final six = layout.cellRect(5);
      expect(p.at(six.center.dx, six.center.dy), const ui.Color(0xFF7A4DC4));
      expect(p.at(six.left + 4, six.center.dy), const ui.Color(0xFF120B05));
      // The unused cells of the last strip stay untouched film.
      final spare = layout.cellRect(5);
      expect(spare.right, lessThan(layout.stripRect(0).right));
    });
  });

  testWidgets('a full 36 frame roll stays small and balanced', (tester) async {
    await tester.runAsync(() async {
      final shapes = const [
        (1800, 1200),
        (1200, 1800),
        (1600, 1200),
        (1200, 1200),
        (1920, 1080),
        (1080, 1920),
      ];
      final frames = [
        for (var i = 1; i <= 36; i++)
          if (i % 9 == 0)
            ContactSheetFrame.missing(i)
          else
            ContactSheetFrame(
              number: i,
              load: () => syntheticPhoto(
                shapes[i % shapes.length].$1 ~/ 3,
                shapes[i % shapes.length].$2 ~/ 3,
                from: ui.Color(0xFF000000 | (i * 6700417 & 0xFFFFFF)),
                to: ui.Color(0xFF000000 | (i * 15485863 & 0xFFFFFF)),
              ),
            ),
      ];
      final bytes = await encodeContactSheet(
        frames: frames,
        filmName: 'Tungsteno 400',
        bandColor: _band,
        date: _date,
      );
      final codec = await ui.instantiateImageCodec(bytes);
      final decoded = (await codec.getNextFrame()).image;
      addTearDown(() {
        decoded.dispose();
        codec.dispose();
      });
      expect(decoded.width, 1200);
      expect(decoded.height, 2593);
    });
  });

  testWidgets('loads each photo once, in order, one at a time', (tester) async {
    await tester.runAsync(() async {
      final log = <String>[];
      var open = 0;
      var mostOpen = 0;
      final frames = [
        for (var i = 1; i <= 8; i++)
          ContactSheetFrame(
            number: i,
            load: () async {
              open++;
              mostOpen = open > mostOpen ? open : mostOpen;
              log.add('load $i');
              final bytes = await syntheticPhoto(
                300,
                200,
                from: const ui.Color(0xFF336699),
                solid: true,
              );
              open--;
              return bytes;
            },
          ),
      ];
      final image = await paintContactSheet(
        frames: frames,
        filmName: 'Test',
        bandColor: _band,
        date: _date,
      );
      image.dispose();
      expect(log, [for (var i = 1; i <= 8; i++) 'load $i']);
      expect(mostOpen, 1);
    });
  });

  testWidgets('writes a file of its own to the cache folder and sweeps none', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final cache = await Directory.systemTemp.createTemp('carrete-sheet');
      addTearDown(() => cache.delete(recursive: true));
      final frames = [
        for (var i = 1; i <= 12; i++) ContactSheetFrame.missing(i),
      ];
      final first = await renderContactSheet(
        frames: frames,
        filmName: 'Test',
        bandColor: _band,
        date: _date,
        cache: cache,
      );
      expect(first.path, contains('/$contactSheetFolder/'));
      expect(await first.length(), greaterThan(1000));
      final second = await renderContactSheet(
        frames: frames,
        filmName: 'Test',
        bandColor: _band,
        date: _date,
        cache: cache,
      );
      // Rendering never deletes what another preview may be showing.
      expect(second.path, isNot(first.path));
      expect(await first.exists(), isTrue);
      expect(await second.exists(), isTrue);
      // The sweep is the one of the app start.
      await cleanContactSheets(cache);
      expect(await first.exists(), isFalse);
      expect(await second.exists(), isFalse);
      // Cleaning a cache with no sheets is quiet.
      await cleanContactSheets(await cache.createTemp('empty'));
    });
  });

  for (final lateFirst in [true, false]) {
    testWidgets(
      'a render that finishes ${lateFirst ? 'late' : 'early'} leaves the '
      'other sheet alone',
      (tester) async {
        await tester.runAsync(() async {
          final cache = await Directory.systemTemp.createTemp('carrete-sheet');
          addTearDown(() => cache.delete(recursive: true));
          final gateA = Completer<void>();
          final gateB = Completer<void>();
          Future<File> render(Completer<void> gate) => renderContactSheet(
            frames: [
              ContactSheetFrame(
                number: 1,
                load: () async {
                  await gate.future;
                  return null;
                },
              ),
            ],
            filmName: 'Test',
            bandColor: _band,
            date: _date,
            cache: cache,
            width: 600,
          );
          final a = render(gateA);
          final b = render(gateB);
          // The one that started first finishes last, or the other way round.
          final firstDone = lateFirst ? gateB : gateA;
          final lastDone = lateFirst ? gateA : gateB;
          firstDone.complete();
          final early = await (lateFirst ? b : a);
          expect(await early.exists(), isTrue);
          lastDone.complete();
          final late = await (lateFirst ? a : b);
          expect(await late.exists(), isTrue);
          expect(await early.exists(), isTrue);
          expect(late.path, isNot(early.path));
        });
      },
    );
  }
}
