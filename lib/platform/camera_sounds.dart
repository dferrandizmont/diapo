import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings/settings_provider.dart';

/// The ringer mode of the phone, as Android reports it.
enum RingerMode { silent, vibrate, normal }

/// The shutter, film advance and roll-handling sounds.
///
/// The sounds are played by `CameraSounds.kt` (a `SoundPool`, which decodes
/// them once when they are loaded) over the `carrete/system` channel. Nothing
/// here waits for the sound: the screens call [playShot] and move on.
///
/// Nothing is played when the phone is on silent or vibrate, or when the
/// platform has no native side (iOS for now). The tests pass `supported: true`
/// and mock the channel.
class CameraSounds {
  CameraSounds({
    bool? supported,
    this.advanceDelay = defaultAdvanceDelay,
    this.soundsEnabled,
  }) : _supported =
           supported ??
           (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  /// The name of the shutter click. `CameraSounds.kt` maps the names to the
  /// files in `assets/sounds/`; no path crosses the channel.
  static const String shutterSound = 'shutter';

  /// The name of the film advance.
  static const String advanceSound = 'advance';

  static const String cartridgeSound = 'cartridge';
  static const String loadSound = 'load';
  static const String rewindSound = 'rewind';

  /// How long after the click the film advances: the flash of the shutter is
  /// over and the film starts to wind.
  static const Duration defaultAdvanceDelay = Duration(milliseconds: 240);

  static const MethodChannel _channel = MethodChannel('carrete/system');

  final bool _supported;

  /// The live setting for roll-handling sounds; null allows them. The provider
  /// supplies it from settings. Shutter callers check the setting themselves.
  final bool Function()? soundsEnabled;

  /// The time between the click and the whirr.
  final Duration advanceDelay;

  Future<void>? _loading;
  bool _loaded = false;
  final Set<Timer> _timers = <Timer>{};
  bool _disposed = false;

  /// Loads all sounds. It completes once they are decoded (the native side
  /// answers then), so a shot after it never finds them half loaded. Safe to
  /// call again: a load that worked is not repeated, one that failed or timed
  /// out is tried again.
  Future<void> preload() => _loading ??= _load();

  Future<void> _load() async {
    if (!_supported) return;
    try {
      _loaded = await _channel.invokeMethod<bool>('loadSounds') ?? false;
    } on PlatformException {
      // No sound is better than a broken camera.
    } on MissingPluginException {
      // No native side: no sound.
    }
    if (!_loaded) _loading = null;
  }

  /// The ringer mode of the phone; null when it cannot be read.
  Future<RingerMode?> ringerMode() async {
    if (!_supported) return null;
    try {
      final name = await _channel.invokeMethod<String>('ringerMode');
      return RingerMode.values.where((m) => m.name == name).firstOrNull;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Plays the click of the shutter now and the whirr of the film advance
  /// after [advanceDelay]. Does nothing unless the phone rings normally.
  ///
  /// Call it without awaiting: it never delays the shutter. A shot that comes
  /// before the sounds are decoded is silent (and starts loading them): a
  /// click that arrives late is worse than none.
  Future<void> playShot() async {
    if (!_supported || _disposed) return;
    if (!_loaded) {
      unawaited(preload());
      return;
    }
    if (await ringerMode() != RingerMode.normal || _disposed) return;
    await _play(shutterSound);
    late final Timer timer;
    timer = Timer(advanceDelay, () {
      _timers.remove(timer);
      unawaited(_play(advanceSound));
    });
    _timers.add(timer);
  }

  /// Plays the soft click of a cartridge settling in the carousel.
  Future<void> playCartridge() => _playEffect(cartridgeSound);

  /// Plays the thud and latch snap of a roll being loaded.
  Future<void> playLoad() => _playEffect(loadSound);

  /// Plays the motor whirr and final click of a roll rewinding.
  Future<void> playRewind() => _playEffect(rewindSound);

  // Like a shot, an effect that arrives before decoding is skipped, never
  // queued. Check the live setting again after querying the ringer mode.
  Future<void> _playEffect(String name) async {
    if (!_supported || _disposed || !(soundsEnabled?.call() ?? true)) return;
    if (!_loaded) {
      unawaited(preload());
      return;
    }
    if (await ringerMode() != RingerMode.normal ||
        _disposed ||
        !(soundsEnabled?.call() ?? true)) {
      return;
    }
    await _play(name);
  }

  Future<void> _play(String name) async {
    try {
      await _channel.invokeMethod<bool>('playSound', <String, Object?>{
        'name': name,
      });
    } on PlatformException {
      // Ignored: a missed click is not worth an error.
    } on MissingPluginException {
      // Ignored.
    }
  }

  /// Cancels the whirrs that have not played yet.
  void dispose() {
    _disposed = true;
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }
}

/// The camera sounds. The tests override it.
final cameraSoundsProvider = Provider<CameraSounds>((ref) {
  final sounds = CameraSounds(
    soundsEnabled: () => ref.read(settingsProvider).cameraSounds,
  );
  ref.onDispose(sounds.dispose);
  return sounds;
});
