// Synthesises the camera sounds of Carrete: shutter, film advance, cartridge
// selection, roll loading and rewind. No sample, no network: the files
// are made from filtered noise bursts, short sine thumps and a low motor hum,
// with a fixed seed, so running the script again writes the same bytes.
//
//   dart run tool/generate_sounds.dart [output directory]
//
// The default output directory is `assets/sounds`. The files are 16-bit mono
// WAV at 22.05 kHz (well under 50 KB each), which Android's SoundPool loads
// without decoding delay.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int _sampleRate = 22050;

void main(List<String> args) {
  final directory = Directory(args.isEmpty ? 'assets/sounds' : args.first)
    ..createSync(recursive: true);
  _write(File('${directory.path}/shutter.wav'), _shutter());
  _write(File('${directory.path}/advance.wav'), _advance());
  _write(File('${directory.path}/cartridge.wav'), _cartridge());
  _write(File('${directory.path}/load.wav'), _load());
  _write(File('${directory.path}/rewind.wav'), _rewind());
}

void _write(File file, Float64List samples) {
  final bytes = _wav(samples);
  file.writeAsBytesSync(bytes);
  stdout.writeln('${file.path}: ${bytes.length} bytes');
}

/// The shutter: the blades open with a bright snap and a soft thump, and
/// close 45 ms later with a duller, quieter one.
Float64List _shutter() {
  final noise = _Noise(0x5eed1);
  final out = Float64List((_sampleRate * 0.16).round());
  _click(out, noise, at: 0, centre: 3400, q: 1.1, tau: 0.0045, gain: 1.0);
  _thump(out, at: 0, hz: 170, tau: 0.014, gain: 0.55);
  _click(out, noise, at: 0.045, centre: 2300, q: 1.0, tau: 0.0055, gain: 0.7);
  _thump(out, at: 0.045, hz: 125, tau: 0.012, gain: 0.35);
  return _finish(out, peak: 0.85);
}

/// The film advance: a low motor hum that slides down in pitch while a
/// ratchet clicks seven times, the clicks getting slower as the spring winds
/// down.
Float64List _advance() {
  final noise = _Noise(0xad7a9ce);
  final out = Float64List((_sampleRate * 0.52).round());
  const clicks = 7;
  var at = 0.03;
  var gap = 0.048;
  for (var i = 0; i < clicks; i++) {
    // Louder in the middle of the stroke, a little different every time.
    final shape = math.sin(math.pi * (i + 0.7) / (clicks + 0.4));
    final gain = 0.45 + 0.55 * shape;
    final centre = 2100 + 700 * noise.next();
    _click(out, noise, at: at, centre: centre, q: 1.4, tau: 0.003, gain: gain);
    _thump(out, at: at, hz: 900, tau: 0.004, gain: 0.25 * gain);
    at += gap;
    gap *= 1.09;
  }
  _hum(out, from: 0.0, to: 0.5, startHz: 92, endHz: 58, gain: 0.16, noise);
  return _finish(out, peak: 0.8);
}

/// A quiet plastic detent, with a rounded body for repeated carousel use.
Float64List _cartridge() {
  final noise = _Noise(0xca471d9e);
  final out = Float64List((_sampleRate * 0.05).round());
  _click(out, noise, at: 0, centre: 1450, q: 0.85, tau: 0.0028, gain: 0.55);
  _thump(out, at: 0, hz: 420, tau: 0.006, gain: 0.2);
  return _finish(out, peak: 0.19);
}

/// A low seating thud followed by the smaller snap of the latch.
Float64List _load() {
  final noise = _Noise(0x10ad5eed);
  final out = Float64List((_sampleRate * 0.2).round());
  _thump(out, at: 0, hz: 100, tau: 0.028, gain: 0.65);
  _click(out, noise, at: 0, centre: 850, q: 0.7, tau: 0.009, gain: 0.28);
  _click(out, noise, at: 0.055, centre: 2400, q: 1.1, tau: 0.004, gain: 0.45);
  _thump(out, at: 0.055, hz: 210, tau: 0.012, gain: 0.18);
  return _finish(out, peak: 0.65);
}

/// A gently rising motor with filtered friction noise, then a release click.
Float64List _rewind() {
  final noise = _Noise(0x4e71ad);
  final out = Float64List(_sampleRate);
  _hum(out, noise, from: 0, to: 0.94, startHz: 150, endHz: 188, gain: 0.2);
  final filter = _Bandpass(1700, 0.7);
  final motorLength = (_sampleRate * 0.94).round();
  for (var i = 0; i < motorLength; i++) {
    final x = i / motorLength;
    final envelope = math.min(1.0, x / 0.08) * math.min(1.0, (1 - x) / 0.3);
    final t = i / _sampleRate;
    final ripple = 0.8 + 0.2 * math.sin(2 * math.pi * (28 * t + 3 * t * t));
    out[i] += 0.18 * envelope * ripple * filter.process(noise.next());
  }
  _click(out, noise, at: 0.95, centre: 2100, q: 1, tau: 0.0035, gain: 0.32);
  _thump(out, at: 0.95, hz: 220, tau: 0.005, gain: 0.1);
  return _finish(out, peak: 0.52);
}

/// A burst of band-passed noise with an exponential decay.
void _click(
  Float64List out,
  _Noise noise, {
  required double at,
  required double centre,
  required double q,
  required double tau,
  required double gain,
}) {
  final filter = _Bandpass(centre, q);
  final start = (at * _sampleRate).round();
  final length = (tau * 9 * _sampleRate).round();
  for (var i = 0; i < length && start + i < out.length; i++) {
    final t = i / _sampleRate;
    out[start + i] += gain * filter.process(noise.next()) * math.exp(-t / tau);
  }
}

/// A short decaying sine: the body of a mechanical knock.
void _thump(
  Float64List out, {
  required double at,
  required double hz,
  required double tau,
  required double gain,
}) {
  final start = (at * _sampleRate).round();
  final length = (tau * 9 * _sampleRate).round();
  for (var i = 0; i < length && start + i < out.length; i++) {
    final t = i / _sampleRate;
    out[start + i] +=
        gain * math.sin(2 * math.pi * hz * t) * math.exp(-t / tau);
  }
}

/// A motor hum: a sine with a few harmonics and a little noise, sliding from
/// [startHz] to [endHz], with a soft attack and release.
void _hum(
  Float64List out,
  _Noise noise, {
  required double from,
  required double to,
  required double startHz,
  required double endHz,
  required double gain,
}) {
  final first = (from * _sampleRate).round();
  final last = math.min((to * _sampleRate).round(), out.length);
  final span = (last - first).toDouble();
  var phase = 0.0;
  for (var i = first; i < last; i++) {
    final x = (i - first) / span;
    final hz = startHz + (endHz - startHz) * x;
    phase += 2 * math.pi * hz / _sampleRate;
    final envelope = math.min(1.0, x / 0.08) * math.min(1.0, (1 - x) / 0.3);
    final tone =
        math.sin(phase) +
        0.5 * math.sin(2 * phase) +
        0.25 * math.sin(3 * phase);
    out[i] += gain * envelope * (tone + 0.3 * noise.next());
  }
}

/// Scales to [peak], fades out the last 3 ms and removes any offset.
Float64List _finish(Float64List samples, {required double peak}) {
  var mean = 0.0;
  for (final s in samples) {
    mean += s;
  }
  mean /= samples.length;
  var max = 0.0;
  for (var i = 0; i < samples.length; i++) {
    samples[i] -= mean;
    max = math.max(max, samples[i].abs());
  }
  final fade = (0.003 * _sampleRate).round();
  for (var i = 0; i < samples.length; i++) {
    final left = samples.length - i;
    final edge = left < fade ? left / fade : 1.0;
    samples[i] = samples[i] / max * peak * edge;
  }
  return samples;
}

/// A 16-bit mono PCM WAV file.
Uint8List _wav(Float64List samples) {
  final dataSize = samples.length * 2;
  final bytes = ByteData(44 + dataSize);
  void tag(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      bytes.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  bytes.setUint32(4, 36 + dataSize, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little); // PCM
  bytes.setUint16(22, 1, Endian.little); // mono
  bytes.setUint32(24, _sampleRate, Endian.little);
  bytes.setUint32(28, _sampleRate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  bytes.setUint32(40, dataSize, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final value = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    bytes.setInt16(44 + i * 2, value, Endian.little);
  }
  return bytes.buffer.asUint8List();
}

/// White noise in -1..1 from a xorshift32 generator: the same sequence on
/// every platform, unlike a seeded `Random`, which the SDK may change.
class _Noise {
  _Noise(this._state);

  int _state;

  double next() {
    var x = _state;
    x ^= (x << 13) & 0xffffffff;
    x ^= x >> 17;
    x ^= (x << 5) & 0xffffffff;
    _state = x & 0xffffffff;
    return _state / 0x7fffffff - 1;
  }
}

/// A band-pass biquad (RBJ cookbook, constant 0 dB peak gain).
class _Bandpass {
  _Bandpass(double centre, double q) {
    final w0 = 2 * math.pi * centre / _sampleRate;
    final alpha = math.sin(w0) / (2 * q);
    final a0 = 1 + alpha;
    _b0 = alpha / a0;
    _b2 = -alpha / a0;
    _a1 = -2 * math.cos(w0) / a0;
    _a2 = (1 - alpha) / a0;
  }

  late final double _b0;
  late final double _b2;
  late final double _a1;
  late final double _a2;
  double _x1 = 0;
  double _x2 = 0;
  double _y1 = 0;
  double _y2 = 0;

  double process(double x) {
    final y = _b0 * x + _b2 * _x2 - _a1 * _y1 - _a2 * _y2;
    _x2 = _x1;
    _x1 = x;
    _y2 = _y1;
    _y1 = y;
    return y;
  }
}
