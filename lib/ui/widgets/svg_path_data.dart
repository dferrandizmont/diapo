import 'dart:ui';

/// Parses the `d` attribute of an SVG path into a Flutter [Path].
///
/// Supports the commands the icons of the camera use: M, L, H, V, C, S, Q, T,
/// A and Z, absolute and relative. A malformed string yields the path parsed
/// up to the problem, never an exception: an icon must not take the screen
/// down.
Path parseSvgPathData(String data) {
  final parser = _PathParser(data);
  return parser.parse();
}

class _PathParser {
  _PathParser(this._s);

  final String _s;
  int _i = 0;
  final Path _path = Path();

  double _x = 0;
  double _y = 0;
  double _startX = 0;
  double _startY = 0;
  double _lastCtrlX = 0;
  double _lastCtrlY = 0;
  String _prev = '';

  Path parse() {
    String? cmd;
    while (true) {
      _skipSeparators();
      if (_i >= _s.length) break;
      final c = _s[_i];
      if (_isCommand(c)) {
        cmd = c;
        _i++;
      } else if (cmd == null) {
        break;
      } else if (cmd == 'M') {
        cmd = 'L';
      } else if (cmd == 'm') {
        cmd = 'l';
      }
      if (!_run(cmd)) break;
      // A close takes no numbers: whatever follows must be a new command.
      if (cmd == 'Z' || cmd == 'z') cmd = null;
    }
    return _path;
  }

  bool _isCommand(String c) => 'MmLlHhVvCcSsQqTtAaZz'.contains(c);

  void _skipSeparators() {
    while (_i < _s.length) {
      final c = _s.codeUnitAt(_i);
      if (c == 0x20 || c == 0x2C || c == 0x09 || c == 0x0A || c == 0x0D) {
        _i++;
      } else {
        break;
      }
    }
  }

  double? _number() {
    _skipSeparators();
    final start = _i;
    if (_i < _s.length && (_s[_i] == '-' || _s[_i] == '+')) _i++;
    var seenDot = false;
    var seenDigit = false;
    while (_i < _s.length) {
      final c = _s[_i];
      if (c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39) {
        seenDigit = true;
        _i++;
      } else if (c == '.' && !seenDot) {
        seenDot = true;
        _i++;
      } else {
        break;
      }
    }
    if (!seenDigit) {
      _i = start;
      return null;
    }
    return double.tryParse(_s.substring(start, _i));
  }

  /// Arc flags are single characters and may be glued to the next number.
  bool? _flag() {
    _skipSeparators();
    if (_i >= _s.length) return null;
    final c = _s[_i];
    if (c == '0' || c == '1') {
      _i++;
      return c == '1';
    }
    return null;
  }

  List<double>? _numbers(int count) {
    final out = <double>[];
    for (var k = 0; k < count; k++) {
      final n = _number();
      if (n == null) return null;
      out.add(n);
    }
    return out;
  }

  bool _run(String cmd) {
    final rel = cmd.toLowerCase() == cmd;
    switch (cmd.toUpperCase()) {
      case 'M':
        final n = _numbers(2);
        if (n == null) return false;
        _x = rel ? _x + n[0] : n[0];
        _y = rel ? _y + n[1] : n[1];
        _startX = _x;
        _startY = _y;
        _path.moveTo(_x, _y);
      case 'L':
        final n = _numbers(2);
        if (n == null) return false;
        _x = rel ? _x + n[0] : n[0];
        _y = rel ? _y + n[1] : n[1];
        _path.lineTo(_x, _y);
      case 'H':
        final n = _numbers(1);
        if (n == null) return false;
        _x = rel ? _x + n[0] : n[0];
        _path.lineTo(_x, _y);
      case 'V':
        final n = _numbers(1);
        if (n == null) return false;
        _y = rel ? _y + n[0] : n[0];
        _path.lineTo(_x, _y);
      case 'C':
        final n = _numbers(6);
        if (n == null) return false;
        final ox = rel ? _x : 0.0;
        final oy = rel ? _y : 0.0;
        _path.cubicTo(
          ox + n[0],
          oy + n[1],
          ox + n[2],
          oy + n[3],
          ox + n[4],
          oy + n[5],
        );
        _lastCtrlX = ox + n[2];
        _lastCtrlY = oy + n[3];
        _x = ox + n[4];
        _y = oy + n[5];
      case 'S':
        final n = _numbers(4);
        if (n == null) return false;
        final ox = rel ? _x : 0.0;
        final oy = rel ? _y : 0.0;
        final smooth = 'CcSs'.contains(_prev);
        final c1x = smooth ? 2 * _x - _lastCtrlX : _x;
        final c1y = smooth ? 2 * _y - _lastCtrlY : _y;
        _path.cubicTo(c1x, c1y, ox + n[0], oy + n[1], ox + n[2], oy + n[3]);
        _lastCtrlX = ox + n[0];
        _lastCtrlY = oy + n[1];
        _x = ox + n[2];
        _y = oy + n[3];
      case 'Q':
        final n = _numbers(4);
        if (n == null) return false;
        final ox = rel ? _x : 0.0;
        final oy = rel ? _y : 0.0;
        _path.quadraticBezierTo(ox + n[0], oy + n[1], ox + n[2], oy + n[3]);
        _lastCtrlX = ox + n[0];
        _lastCtrlY = oy + n[1];
        _x = ox + n[2];
        _y = oy + n[3];
      case 'T':
        final n = _numbers(2);
        if (n == null) return false;
        final ox = rel ? _x : 0.0;
        final oy = rel ? _y : 0.0;
        final smooth = 'QqTt'.contains(_prev);
        final cx = smooth ? 2 * _x - _lastCtrlX : _x;
        final cy = smooth ? 2 * _y - _lastCtrlY : _y;
        _path.quadraticBezierTo(cx, cy, ox + n[0], oy + n[1]);
        _lastCtrlX = cx;
        _lastCtrlY = cy;
        _x = ox + n[0];
        _y = oy + n[1];
      case 'A':
        final head = _numbers(3);
        if (head == null) return false;
        final large = _flag();
        final sweep = _flag();
        if (large == null || sweep == null) return false;
        final tail = _numbers(2);
        if (tail == null) return false;
        final ex = rel ? _x + tail[0] : tail[0];
        final ey = rel ? _y + tail[1] : tail[1];
        if (head[0] == 0 || head[1] == 0) {
          _path.lineTo(ex, ey);
        } else {
          _path.arcToPoint(
            Offset(ex, ey),
            radius: Radius.elliptical(head[0].abs(), head[1].abs()),
            rotation: head[2],
            largeArc: large,
            clockwise: sweep,
          );
        }
        _x = ex;
        _y = ey;
      case 'Z':
        _path.close();
        _x = _startX;
        _y = _startY;
    }
    _prev = cmd;
    return true;
  }
}
