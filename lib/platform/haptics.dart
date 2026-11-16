import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings/settings_provider.dart';
import 'camera_sounds.dart';

/// The small vibrations of the camera: the shutter, a cartridge settling, a
/// roll loaded or finished.
///
/// Nothing is played when the "Vibration" setting is off or the phone is on
/// silent. Vibrate mode is fine: the user asked for vibration there. When the
/// ringer mode cannot be read, haptics stay off. On iOS only the setting is
/// checked; the system applies its own haptics preference.
///
/// Call without awaiting: a haptic never delays the shutter or a screen.
class Haptics {
  Haptics({required this.enabled, required this.ringerMode});

  /// The live "Vibration" setting.
  final bool Function() enabled;

  /// The ringer mode of the phone; null when it cannot be read.
  final Future<RingerMode?> Function() ringerMode;

  /// A tick: a cartridge settling, the shutter.
  Future<void> selectionClick() => _play(HapticFeedback.selectionClick);

  /// A firm thump: a roll loaded.
  Future<void> mediumImpact() => _play(HapticFeedback.mediumImpact);

  /// A light tap: the last frame of a roll secured.
  Future<void> lightImpact() => _play(HapticFeedback.lightImpact);

  Future<void> _play(Future<void> Function() haptic) async {
    if (!enabled()) return;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await haptic();
      return;
    }
    final mode = await ringerMode();
    // The setting and the ringer are checked again after the wait.
    // Unknown ringer mode (null, no native side) means no vibration: we
    // cannot guarantee the silence policy otherwise.
    if (!enabled() || mode == null || mode == RingerMode.silent) return;
    await haptic();
  }
}

/// The haptics of the camera. The tests override it.
final hapticsProvider = Provider<Haptics>(
  (ref) => Haptics(
    enabled: () => ref.read(settingsProvider).haptics,
    ringerMode: () => ref.read(cameraSoundsProvider).ringerMode(),
  ),
);
