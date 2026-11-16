import 'package:diapo/render/look_adjust.dart';
import 'package:diapo/screens/viewfinder/film_shader_view.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  // The shader flips its input vertically only when uMode is 1 (on Impeller's
  // OpenGL ES backend, where a camera texture arrives upside down). A decoded
  // photo shown through an Image is already upright there: the import preview
  // showed it flipped on a OnePlus 8T until it asked for mode 0.
  group('shaderModeOf', () {
    test('flips a camera texture in filter mode', () {
      expect(shaderModeOf(filterMode: true), 1);
      expect(shaderModeOf(filterMode: true, cameraTexture: true), 1);
    });

    test('leaves a photo upright in filter mode', () {
      expect(shaderModeOf(filterMode: true, cameraTexture: false), 0);
    });

    test('never flips the saved still', () {
      expect(shaderModeOf(filterMode: false), 0);
      expect(shaderModeOf(filterMode: false, cameraTexture: false), 0);
    });
  });

  test('a film view is for a camera texture unless it says otherwise', () {
    const child = SizedBox();
    final camera = FilmShaderView(
      resources: null,
      filmId: 'x',
      look: resolve(testBook().byId('alpha')!),
      child: child,
    );
    expect(camera.cameraTexture, isTrue);
  });
}
