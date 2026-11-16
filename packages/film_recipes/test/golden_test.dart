import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

void main() {
  final book = RecipeBook.parse(File('assets/recipes.json').readAsStringSync());
  final chart = buildTestChart();
  final hashes = jsonDecode(
    File('test/goldens/hashes.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  group('the golden images', () {
    for (final recipe in book.recipes) {
      for (final intensity in const <double>[1, 0.5]) {
        final name = goldenFileName(recipe.id, intensity);

        test('$name has not changed', () {
          final look = resolve(recipe, intensity: intensity);
          final rgba = renderReference(
            chart,
            kTestChartWidth,
            kTestChartHeight,
            look,
          );

          final golden = File('test/goldens/$name');
          expect(
            golden.existsSync(),
            isTrue,
            reason:
                'the golden $name is missing, run '
                '`dart run tool/update_goldens.dart` to write it',
          );

          final image = img.decodePng(golden.readAsBytesSync());
          expect(image, isNotNull, reason: '$name is not a readable PNG');
          final expected = image!.getBytes(order: img.ChannelOrder.rgba);
          expect(expected.length, rgba.length);

          var worst = 0;
          var total = 0;
          for (var i = 0; i < rgba.length; i++) {
            final difference = (rgba[i] - expected[i]).abs();
            if (difference > worst) {
              worst = difference;
            }
            total += difference;
          }
          final mean = total / rgba.length / 255.0;

          final hash = sha256.convert(rgba).toString();
          final sameHash = hashes[name] == hash;
          printOnFailure(
            'the SHA-256 of $name is ${sameHash ? 'the same' : 'different'} '
            '($hash)',
          );

          expect(
            worst,
            lessThanOrEqualTo(1),
            reason:
                'the image changed, the SHA-256 is ${sameHash ? 'the '
                          'same' : 'different'}. If the change was wanted, run '
                '`dart run tool/update_goldens.dart`',
          );
          expect(
            mean,
            lessThan(0.05),
            reason:
                'the image changed, the SHA-256 is ${sameHash ? 'the '
                          'same' : 'different'}. If the change was wanted, run '
                '`dart run tool/update_goldens.dart`',
          );
        });
      }
    }
  });
}
