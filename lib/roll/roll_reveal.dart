import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/database/database_provider.dart';
import '../core/settings/settings_provider.dart';

/// Which developed rolls have already been revealed: the first time one is
/// opened its frames come in one after another, and never again.
///
/// It lives in the preferences of the device, not in the database, so it needs
/// no migration: a small set of roll ids.
abstract interface class RollRevealStore {
  /// Whether the roll was already revealed.
  bool seen(int rollId);

  /// Remembers that the roll was revealed.
  Future<void> markSeen(int rollId);
}

/// The [RollRevealStore] on the preferences of the device.
///
/// The set never forgets a roll that still exists, however many were opened
/// since: dropping an old id would play its reveal a second time. Instead it
/// is pruned of the rolls that are gone each time one is marked, so it never
/// holds more ids than there are rolls.
class PreferencesRollRevealStore implements RollRevealStore {
  PreferencesRollRevealStore(this._preferences, {this.existingRollIds});

  /// The key of the list of roll ids.
  static const String storageKey = 'carrete.roll.revealSeen';

  final SharedPreferences _preferences;

  /// The ids of the rolls that exist now. When it is null (or fails) nothing
  /// is pruned.
  final Future<Set<int>> Function()? existingRollIds;

  Set<String> _ids() => {...?_preferences.getStringList(storageKey)};

  @override
  bool seen(int rollId) => _ids().contains('$rollId');

  /// Serialises the read, prune and write of [markSeen], so two overlapping
  /// calls can never read the same set and lose an id added by the other.
  Future<void>? _markSeenQueue;

  @override
  Future<void> markSeen(int rollId) {
    final previous = _markSeenQueue;
    final completer = Completer<void>();
    final future = completer.future;
    _markSeenQueue = future;
    () async {
      try {
        if (previous != null) await previous;
        final ids = _ids()..add('$rollId');
        await _preferences.setStringList(
          storageKey,
          await _pruned(ids, rollId),
        );
        completer.complete();
      } catch (error, stack) {
        completer.completeError(error, stack);
      } finally {
        if (_markSeenQueue == future) _markSeenQueue = null;
      }
    }();
    return future;
  }

  /// [ids] without the rolls that no longer exist ([keep] stays whatever the
  /// database says, as it was just opened).
  Future<List<String>> _pruned(Set<String> ids, int keep) async {
    final lookup = existingRollIds;
    if (lookup == null) return ids.toList();
    try {
      final existing = await lookup();
      return [
        for (final id in ids)
          if (id == '$keep' || existing.contains(int.tryParse(id))) id,
      ];
    } on Object {
      return ids.toList();
    }
  }
}

/// The reveal memory of the app. Overridden in the tests.
final rollRevealStoreProvider = Provider<RollRevealStore>(
  (ref) => PreferencesRollRevealStore(
    ref.watch(sharedPreferencesProvider),
    existingRollIds: () async => {
      for (final roll in await ref.read(rollsDaoProvider).allRolls()) roll.id,
    },
  ),
);
