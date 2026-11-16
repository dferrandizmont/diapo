import 'package:film_recipes/film_recipes.dart';
import 'package:test/test.dart';

void main() {
  group('buildLut', () {
    test('holds 256 entries', () {
      expect(buildLut(ToneCurve.identity.points).length, 256);
    });

    test('leaves every value untouched when the curve is the identity', () {
      final lut = buildLut(ToneCurve.identity.points);

      for (var i = 0; i < lut.length; i++) {
        expect(lut[i], closeTo(i / 255, 1e-12));
      }
    });

    test('is monotone when the points are monotone', () {
      final lut = buildLut(const <CurvePoint>[
        CurvePoint(0, 0),
        CurvePoint(0.3, 0.2),
        CurvePoint(0.7, 0.6),
        CurvePoint(1, 1),
      ]);

      for (var i = 1; i < lut.length; i++) {
        expect(lut[i], greaterThanOrEqualTo(lut[i - 1]));
      }
    });

    test('never overshoots between the control points', () {
      final lut = buildLut(const <CurvePoint>[
        CurvePoint(0, 0),
        CurvePoint(0.5, 0.1),
        CurvePoint(1, 1),
      ]);

      for (var i = 0; i < lut.length; i++) {
        expect(lut[i], inInclusiveRange(0, 1));
      }
    });

    test('is monotone when the points go down', () {
      final lut = buildLut(const <CurvePoint>[
        CurvePoint(0, 1),
        CurvePoint(0.5, 0.4),
        CurvePoint(1, 0),
      ]);

      for (var i = 1; i < lut.length; i++) {
        expect(lut[i], lessThanOrEqualTo(lut[i - 1]));
      }
    });
  });

  group('curveValueAt', () {
    test('passes exactly through the control points', () {
      const points = <CurvePoint>[
        CurvePoint(0, 0.05),
        CurvePoint(0.25, 0.2),
        CurvePoint(0.5, 0.5),
        CurvePoint(0.75, 0.8),
        CurvePoint(1, 0.97),
      ];

      for (final point in points) {
        expect(curveValueAt(points, point.x), closeTo(point.y, 1e-12));
      }
    });

    test('keeps the value inside the unit square', () {
      final value = curveValueAt(const <CurvePoint>[
        CurvePoint(0, 0.2),
        CurvePoint(1, 0.9),
      ], 0.5);

      expect(value, inInclusiveRange(0, 1));
    });
  });

  group('combineLuts', () {
    test('applies the master curve and then the channel curve', () {
      final master = buildLut(const <CurvePoint>[
        CurvePoint(0, 0),
        CurvePoint(1, 0.5),
      ]);
      final channel = buildLut(const <CurvePoint>[
        CurvePoint(0, 0),
        CurvePoint(1, 1),
      ]);
      final combined = combineLuts(master, channel);

      for (var i = 0; i < combined.length; i++) {
        expect(combined[i], closeTo(master[i], 1e-12));
      }
    });

    test('applies the channel curve to the values of the master curve', () {
      final master = buildLut(ToneCurve.identity.points);
      final channel = buildLut(const <CurvePoint>[
        CurvePoint(0, 0),
        CurvePoint(1, 0.5),
      ]);
      final combined = combineLuts(master, channel);

      for (var i = 0; i < combined.length; i++) {
        expect(combined[i], closeTo(channel[i], 1e-12));
      }
    });
  });

  group('sampleLut', () {
    test('reads the first and the last entry at the ends', () {
      final lut = buildLut(ToneCurve.identity.points);

      expect(sampleLut(lut, 0), closeTo(0, 1e-12));
      expect(sampleLut(lut, 1), closeTo(1, 1e-12));
    });

    test('interpolates between the two nearest entries', () {
      final lut = buildLut(ToneCurve.identity.points);

      expect(sampleLut(lut, 0.5 / 255), closeTo(0.5 / 255, 1e-12));
    });
  });

  group('curveRgba', () {
    test('holds 256 pixels of red, green, blue and alpha', () {
      final look = resolve(
        const Recipe(
          id: 'prueba',
          name: LocalizedText(es: 'a', ca: 'b', en: 'c'),
          description: LocalizedText(es: 'a', ca: 'b', en: 'c'),
        ),
      );
      final curve = curveRgba(look);

      expect(curve.length, 256 * 4);
      for (var i = 0; i < 256; i++) {
        expect(curve[i * 4 + 3], 255);
      }
    });

    test('writes the three channels of the look', () {
      final look = resolve(
        const Recipe(
          id: 'prueba',
          name: LocalizedText(es: 'a', ca: 'b', en: 'c'),
          description: LocalizedText(es: 'a', ca: 'b', en: 'c'),
          curve: CurveSet(
            r: ToneCurve(<CurvePoint>[CurvePoint(0, 0), CurvePoint(1, 1)]),
            g: ToneCurve(<CurvePoint>[CurvePoint(0, 0), CurvePoint(1, 0.5)]),
            b: ToneCurve(<CurvePoint>[CurvePoint(0, 0), CurvePoint(1, 0.25)]),
          ),
        ),
      );
      final curve = curveRgba(look);

      expect(curve[255 * 4], 255);
      expect(curve[255 * 4 + 1], closeTo(128, 1));
      expect(curve[255 * 4 + 2], closeTo(64, 1));
    });
  });
}
