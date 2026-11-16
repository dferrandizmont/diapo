import 'package:carrete/location/photo_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final shutter = DateTime.utc(2026, 11, 14, 12);
  PhotoLocation fix({
    Duration age = Duration.zero,
    double accuracy = 10,
    double latitude = 40,
    double longitude = -3,
    double? altitude,
    bool approximate = false,
  }) => PhotoLocation(
    latitude: latitude,
    longitude: longitude,
    accuracy: accuracy,
    altitude: altitude,
    time: shutter.subtract(age),
    approximate: approximate,
  );

  test(
    'freshness includes two minutes and excludes future and older fixes',
    () {
      expect(fix().isUsableAt(shutter), isTrue);
      expect(fix(age: const Duration(minutes: 2)).isUsableAt(shutter), isTrue);
      expect(
        fix(age: const Duration(minutes: 2, milliseconds: 1))
            .isUsableAt(shutter),
        isFalse,
      );
      expect(
        fix(age: const Duration(milliseconds: -1)).isUsableAt(shutter),
        isFalse,
      );
    },
  );

  test(
    'accuracy must be finite, nonnegative and strictly below 100 metres',
    () {
      for (final accuracy in [
        100.0,
        101.0,
        -1.0,
        double.nan,
        double.infinity,
      ]) {
        expect(fix(accuracy: accuracy).isUsableAt(shutter), isFalse);
      }
      expect(fix(accuracy: 99.99).isUsableAt(shutter), isTrue);
      expect(fix(accuracy: 0).isUsableAt(shutter), isTrue);
    },
  );

  test('invalid coordinates or altitude cannot reach EXIF', () {
    expect(fix(latitude: 91).isUsableAt(shutter), isFalse);
    expect(fix(longitude: -181).isUsableAt(shutter), isFalse);
    expect(fix(latitude: double.nan).isUsableAt(shutter), isFalse);
    expect(fix(altitude: double.infinity).isUsableAt(shutter), isFalse);
  });

  test('approximate fixes allow up to 5000 metres and ten minutes', () {
    expect(fix(accuracy: 2000, approximate: true).isUsableAt(shutter), isTrue);
    expect(fix(accuracy: 2000).isUsableAt(shutter), isFalse);
    expect(fix(accuracy: 5000, approximate: true).isUsableAt(shutter), isTrue);
    for (final accuracy in [5000.01, -1.0, double.nan, double.infinity]) {
      expect(
        fix(accuracy: accuracy, approximate: true).isUsableAt(shutter),
        isFalse,
      );
    }
    expect(
      fix(
        accuracy: 2000,
        approximate: true,
        age: const Duration(minutes: 10),
      ).isUsableAt(shutter),
      isTrue,
    );
    for (final age in [
      const Duration(minutes: 10, milliseconds: 1),
      const Duration(milliseconds: -1),
    ]) {
      expect(
        fix(accuracy: 2000, approximate: true, age: age).isUsableAt(shutter),
        isFalse,
      );
    }
  });

  test(
    'JSON preserves approximate provenance and defaults old fixes to precise',
    () {
      for (final approximate in [false, true]) {
        final original = fix(accuracy: 2000, approximate: approximate);
        final restored = PhotoLocation.fromJson(original.toJson())!;
        expect(restored.toJson(), original.toJson());
        expect(restored.isUsableAt(shutter), approximate);
      }
      final legacy = fix(accuracy: 2000).toJson()..remove('approximate');
      final restored = PhotoLocation.fromJson(legacy)!;
      expect(restored.approximate, isFalse);
      expect(restored.isUsableAt(shutter), isFalse);
      expect(
        PhotoLocation.fromJson({...legacy, 'approximate': 'true'}),
        isNull,
      );
    },
  );

  test('the channel and job representation preserves all fields', () {
    final original = fix(altitude: -12.25);
    final restored = PhotoLocation.fromJson(original.toJson())!;
    expect(restored.toJson(), original.toJson());
    expect(PhotoLocation.fromJson({'latitude': '40'}), isNull);
    expect(fix().toJson(), isNot(contains('altitude')));
  });
}
