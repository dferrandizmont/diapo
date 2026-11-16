import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// After the first import this single value is authoritative for both portable
/// settings and tuning. Legacy keys remain readable until that first import.
/// Keeping the entire import in one preference avoids half-applied backups.
class SettingsSnapshot {
  factory SettingsSnapshot(SharedPreferences preferences) =>
      _stores[preferences] ??= SettingsSnapshot._(preferences);

  SettingsSnapshot._(this.preferences)
    : _confirmed = _initialValue(preferences);

  static String? _initialValue(SharedPreferences preferences) {
    try {
      return preferences.getString(storageKey);
    } on TypeError {
      return null;
    }
  }

  static final _stores = Expando<SettingsSnapshot>();
  String? _confirmed;
  bool _restoreFailed = false;
  Future<void> _tail = Future.value();

  /// Imports and field edits share this queue, including legacy preference edits.
  Future<T> serialize<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  static const storageKey = 'carrete.settingsSnapshot';
  final SharedPreferences preferences;

  Map<String, Object?>? read() {
    try {
      final raw = _confirmed;
      if (raw == null) return null;
      final value = jsonDecode(raw);
      if (value is Map<String, dynamic> &&
          value['settings'] is Map<String, dynamic> &&
          value['tuning'] is Map<String, dynamic>) {
        return value;
      }
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
    return null;
  }

  Future<void> write(Map<String, Object?> snapshot) async {
    if (_restoreFailed) {
      throw StateError('Settings restoration was not confirmed');
    }
    final previous = _confirmed;
    final encoded = jsonEncode(snapshot);
    try {
      if (!await preferences.setString(storageKey, encoded)) {
        throw StateError('Settings snapshot was not stored');
      }
      _confirmed = encoded;
    } catch (_) {
      // Android commit can fail after changing both native and Dart memory.
      // Reload reads native memory, so explicitly restore and verify instead.
      try {
        final restored = previous == null
            ? await preferences.remove(storageKey)
            : await preferences.setString(storageKey, previous);
        _restoreFailed =
            !restored || preferences.getString(storageKey) != previous;
      } catch (_) {
        _restoreFailed = true;
      }
      rethrow;
    }
  }
}
