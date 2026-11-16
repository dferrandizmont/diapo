import 'dart:ui';

import 'package:carrete/ui/widgets/carrete_icon.dart';
import 'package:carrete/ui/widgets/svg_path_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lines, relative moves and close', () {
    final path = parseSvgPathData('M2 3L10 3v5h-8z');
    expect(path.getBounds(), const Rect.fromLTRB(2, 3, 10, 8));
  });

  test('implicit commands repeat', () {
    final path = parseSvgPathData('M0 0 10 0 10 10');
    expect(path.getBounds(), const Rect.fromLTRB(0, 0, 10, 10));
  });

  test('arcs with glued flags are read', () {
    final path = parseSvgPathData(
      'M14.4 12a2.4 2.4 0 1 1-4.8 0 2.4 2.4 0 1 1 4.8 0',
    );
    final b = path.getBounds();
    expect(b.center.dx, closeTo(12, 0.01));
    expect(b.center.dy, closeTo(12, 0.01));
    expect(b.width, closeTo(4.8, 0.05));
  });

  test('a malformed string never throws and keeps what was read', () {
    final path = parseSvgPathData('M1 1 L 5 5 L nonsense');
    expect(path.getBounds(), const Rect.fromLTRB(1, 1, 5, 5));
    expect(parseSvgPathData('').getBounds(), Rect.zero);
  });

  test('every icon is inside its 24 x 24 grid', () {
    for (final icon in CarreteIcon.values) {
      final b = icon.path.getBounds();
      expect(b.isEmpty, isFalse, reason: icon.name);
      expect(b.left, greaterThanOrEqualTo(0), reason: icon.name);
      expect(b.top, greaterThanOrEqualTo(0), reason: icon.name);
      expect(b.right, lessThanOrEqualTo(24), reason: icon.name);
      expect(b.bottom, lessThanOrEqualTo(24), reason: icon.name);
    }
  });
}
