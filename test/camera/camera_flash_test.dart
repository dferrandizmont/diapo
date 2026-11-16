import 'dart:io';

import 'package:diapo/camera/camera_flash.dart';
import 'package:diapo/camera/camera_service.dart';
import 'package:diapo/render/look_adjust.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final book = RecipeBook.parse(
    File('packages/film_recipes/assets/recipes.json').readAsStringSync(),
  );
  final recipe = book.recipes.first;
  final look = resolve(recipe);

  group('party flash', () {
    test('adds the documented exposure and halation', () {
      final party = lookWithFlash(look, CarreteFlash.party);
      expect(
        party.exposure,
        closeTo(look.exposure + PartyFlash.exposureStops, 1e-9),
      );
      expect(
        party.halationAmount,
        closeTo(look.halationAmount * PartyFlash.halationScale, 1e-9),
      );
    });

    test('the constants are +0.3 EV and 1.5x halation', () {
      expect(PartyFlash.exposureStops, 0.3);
      expect(PartyFlash.halationScale, 1.5);
    });

    test('keeps everything else of the look', () {
      final party = lookWithFlash(look, CarreteFlash.party);
      expect(party.saturation, look.saturation);
      expect(party.matrix, look.matrix);
      expect(party.grainAmount, look.grainAmount);
      expect(party.vignetteAmount, look.vignetteAmount);
      expect(party.leakAmount, look.leakAmount);
      expect(party.curveR, look.curveR);
      expect(party.format, look.format);
      expect(party.dateStamp, look.dateStamp);
    });

    test('the halation never goes above 1, the maximum of the shader', () {
      // Just under the maximum, whatever the recipe's own halation is, so
      // tuning a film never breaks this test.
      final strong = look.adjusted(halationScale: 0.95 / look.halationAmount);
      expect(strong.halationAmount, lessThan(1));
      expect(lookWithFlash(strong, CarreteFlash.party).halationAmount, 1);
    });

    test('the other modes leave the look as it is', () {
      for (final mode in [
        CarreteFlash.off,
        CarreteFlash.auto,
        CarreteFlash.on,
      ]) {
        expect(identical(lookWithFlash(look, mode), look), isTrue);
      }
    });

    test('party and on both fire the flash every time', () {
      expect(CarreteFlash.party.firesAlways, isTrue);
      expect(CarreteFlash.on.firesAlways, isTrue);
      expect(CarreteFlash.auto.firesAlways, isFalse);
      expect(CarreteFlash.off.firesAlways, isFalse);
    });
  });

  group('zoomRange', () {
    test('is 1x to 2x on a device that allows more', () {
      expect(zoomRange(1, 10), (1.0, 2.0));
    });

    test('is narrowed to what the device can do', () {
      expect(zoomRange(1, 1.5), (1.0, 1.5));
      expect(zoomRange(1, 1), (1.0, 1.0));
    });

    test('never goes below the device minimum', () {
      expect(zoomRange(1.2, 8), (1.2, 2.0));
    });
  });
}
