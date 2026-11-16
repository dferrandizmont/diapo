import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_provider.dart';

/// What the camera has already told a new user in the first minutes: the hint
/// about swiping the films and the offer of a roll of 12, each shown once, and
/// how many loose photos were saved so far.
///
/// It is kept on the device next to the settings, but it is not a setting: it
/// is not exported with them and it is not part of a backup.
class FirstMinuteState {
  const FirstMinuteState({
    this.swipeHintSeen = false,
    this.rollOfferSeen = false,
    this.loosePhotos = 0,
    this.countedCaptures = const <String>[],
  });

  /// Whether the hint about swiping the films was shown and dismissed.
  final bool swipeHintSeen;

  /// Whether the offer of a first roll of 12 was shown.
  final bool rollOfferSeen;

  /// The loose photos saved since the app counts them.
  final int loosePhotos;

  /// The identities of the last captures that were counted, so a photo is
  /// counted once whether it is saved at once or recovered after a restart.
  final List<String> countedCaptures;

  FirstMinuteState copyWith({
    bool? swipeHintSeen,
    bool? rollOfferSeen,
    int? loosePhotos,
    List<String>? countedCaptures,
  }) => FirstMinuteState(
    swipeHintSeen: swipeHintSeen ?? this.swipeHintSeen,
    rollOfferSeen: rollOfferSeen ?? this.rollOfferSeen,
    loosePhotos: loosePhotos ?? this.loosePhotos,
    countedCaptures: countedCaptures ?? this.countedCaptures,
  );
}

/// The loose photos that have to be saved before the camera offers a roll.
const int kLoosePhotosBeforeRollOffer = 2;

/// How many capture identities are remembered to count a photo once.
const int kCountedCapturesKept = 32;

/// The length of the roll the camera offers a new user.
const int kOfferedRollLength = 12;

/// Keeps [FirstMinuteState] in the preferences of the device.
class FirstMinute extends Notifier<FirstMinuteState> {
  static const String _kSwipeHint = 'carrete.firstMinute.swipeHintSeen';
  static const String _kRollOffer = 'carrete.firstMinute.rollOfferSeen';
  static const String _kLoosePhotos = 'carrete.firstMinute.loosePhotos';
  static const String _kCounted = 'carrete.firstMinute.countedCaptures';

  SharedPreferences get _preferences => ref.read(sharedPreferencesProvider);

  @override
  FirstMinuteState build() {
    final preferences = ref.watch(sharedPreferencesProvider);
    bool flag(String key) {
      try {
        return preferences.getBool(key) ?? false;
      } on TypeError {
        return false;
      }
    }

    int count() {
      try {
        return preferences.getInt(_kLoosePhotos) ?? 0;
      } on TypeError {
        return 0;
      }
    }

    List<String> counted() {
      try {
        return preferences.getStringList(_kCounted) ?? const <String>[];
      } on TypeError {
        return const <String>[];
      }
    }

    return FirstMinuteState(
      swipeHintSeen: flag(_kSwipeHint),
      rollOfferSeen: flag(_kRollOffer),
      loosePhotos: count(),
      countedCaptures: counted(),
    );
  }

  /// The hint about swiping the films was dismissed, or the user swiped.
  void markSwipeHintSeen() {
    if (state.swipeHintSeen) return;
    state = state.copyWith(swipeHintSeen: true);
    _write(() => _preferences.setBool(_kSwipeHint, true));
  }

  /// The offer of a roll of 12 was shown (so it is not shown again), whatever
  /// the user answers.
  void markRollOfferSeen() {
    if (state.rollOfferSeen) return;
    state = state.copyWith(rollOfferSeen: true);
    _write(() => _preferences.setBool(_kRollOffer, true));
  }

  /// A loose photo was durably saved. [captureId] is the identity of the
  /// capture: a photo that fails, is recovered after a restart and is saved
  /// then counts once, and a save that is reported twice counts once. A photo
  /// with no identity always counts. After the offer there is nothing left to
  /// count for, so nothing is written. Returns how many were counted so far.
  int countLoosePhoto([String? captureId]) {
    if (state.rollOfferSeen) return state.loosePhotos;
    if (captureId != null && state.countedCaptures.contains(captureId)) {
      return state.loosePhotos;
    }
    final count = state.loosePhotos + 1;
    final ids = captureId == null
        ? state.countedCaptures
        : [...state.countedCaptures, captureId]
              .skip(
                math.max(
                  0,
                  state.countedCaptures.length + 1 - kCountedCapturesKept,
                ),
              )
              .toList();
    state = state.copyWith(loosePhotos: count, countedCaptures: ids);
    _write(() => _preferences.setInt(_kLoosePhotos, count));
    if (captureId != null) {
      _write(() => _preferences.setStringList(_kCounted, ids));
    }
    return count;
  }

  /// A preference that cannot be written only means the hint comes back; it
  /// never breaks the camera.
  void _write(Future<bool> Function() write) {
    write().then<void>((_) {}, onError: (Object _, StackTrace _) {});
  }
}

/// What the camera has already told the user in the first minutes.
final firstMinuteProvider = NotifierProvider<FirstMinute, FirstMinuteState>(
  FirstMinute.new,
);
