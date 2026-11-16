import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_provider.dart';

/// A calendar day, with no time of day and no time zone: what the review
/// counters need, so "five different days" and "seven days ago" never depend
/// on the hour or on a change of clock.
class CivilDay implements Comparable<CivilDay> {
  const CivilDay(this.year, this.month, this.day);

  /// The calendar day of [moment] in the local time of the device.
  factory CivilDay.fromDateTime(DateTime moment) =>
      CivilDay(moment.year, moment.month, moment.day);

  /// Reads `2026-11-16`, or null when [text] is not such a day.
  static CivilDay? tryParse(Object? text) {
    if (text is! String) return null;
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
    if (match == null) return null;
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final check = DateTime.utc(year, month, day);
    if (check.year != year || check.month != month || check.day != day) {
      return null;
    }
    return CivilDay(year, month, day);
  }

  final int year;
  final int month;
  final int day;

  /// How many days this day is after [other] (negative when it is before).
  int daysSince(CivilDay other) => DateTime.utc(
    year,
    month,
    day,
  ).difference(DateTime.utc(other.year, other.month, other.day)).inDays;

  /// Whether this day is later than [other].
  bool isAfter(CivilDay other) => compareTo(other) > 0;

  String toIso() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(CivilDay other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is CivilDay &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}

/// What the app remembers to decide whether to ask for a store review: only
/// counters and calendar days, nothing about the photos or the rolls.
///
/// It is kept on the device next to the settings, but it is not a setting: it
/// is not exported with them and the import of settings never touches it.
class ReviewState {
  const ReviewState({
    this.firstOpenDay,
    this.lastOpenDay,
    this.openDays = 0,
    this.requestedVersions = const <String>[],
    this.lastRequestDay,
    this.lastImportDay,
  });

  static const ReviewState empty = ReviewState();

  /// The first day the app was opened (null until one is recorded).
  final CivilDay? firstOpenDay;

  /// The latest day the app was opened, so a day is counted once.
  final CivilDay? lastOpenDay;

  /// How many different calendar days the app was opened on.
  final int openDays;

  /// The app version of each request that was made, in order: its length is
  /// how many times the store was asked.
  final List<String> requestedVersions;

  /// The day of the last request.
  final CivilDay? lastRequestDay;

  /// The day settings were last imported, to keep quiet right after.
  final CivilDay? lastImportDay;

  /// How many times the store was asked.
  int get requestCount => requestedVersions.length;

  /// Counts [today] as a day the app was opened, once per day, and fixes the
  /// first day. A clock that goes back never counts the same day twice.
  ReviewState withOpenOn(CivilDay today) {
    final last = lastOpenDay;
    final isNewDay = last == null || today.isAfter(last);
    return ReviewState(
      firstOpenDay: firstOpenDay ?? today,
      lastOpenDay: isNewDay ? today : last,
      openDays: isNewDay ? openDays + 1 : openDays,
      requestedVersions: requestedVersions,
      lastRequestDay: lastRequestDay,
      lastImportDay: lastImportDay,
    );
  }

  /// Notes that the store was asked on [today] for [version].
  ReviewState withRequestOn(CivilDay today, String version) => ReviewState(
    firstOpenDay: firstOpenDay,
    lastOpenDay: lastOpenDay,
    openDays: openDays,
    requestedVersions: [...requestedVersions, version],
    lastRequestDay: today,
    lastImportDay: lastImportDay,
  );

  /// Takes back the last request (the sheet was not asked after all) and puts
  /// [previousDay] back as the day of the last request.
  ReviewState withLastRequestUndone(CivilDay? previousDay) => ReviewState(
    firstOpenDay: firstOpenDay,
    lastOpenDay: lastOpenDay,
    openDays: openDays,
    requestedVersions: requestedVersions.isEmpty
        ? requestedVersions
        : requestedVersions.sublist(0, requestedVersions.length - 1),
    lastRequestDay: previousDay,
    lastImportDay: lastImportDay,
  );

  /// Notes that settings were imported on [today].
  ReviewState withImportOn(CivilDay today) => ReviewState(
    firstOpenDay: firstOpenDay,
    lastOpenDay: lastOpenDay,
    openDays: openDays,
    requestedVersions: requestedVersions,
    lastRequestDay: lastRequestDay,
    lastImportDay: today,
  );

  Map<String, Object?> toJson() => {
    'firstOpenDay': firstOpenDay?.toIso(),
    'lastOpenDay': lastOpenDay?.toIso(),
    'openDays': openDays,
    'requestedVersions': requestedVersions,
    'lastRequestDay': lastRequestDay?.toIso(),
    'lastImportDay': lastImportDay?.toIso(),
  };

  /// A missing or malformed field falls back to "nothing recorded": a bad
  /// value never breaks the app, it only delays the question.
  factory ReviewState.fromJson(Map<String, Object?> json) {
    final days = json['openDays'];
    final versions = json['requestedVersions'];
    return ReviewState(
      firstOpenDay: CivilDay.tryParse(json['firstOpenDay']),
      lastOpenDay: CivilDay.tryParse(json['lastOpenDay']),
      openDays: days is int && days >= 0 ? days : 0,
      requestedVersions: versions is List
          ? versions.whereType<String>().toList(growable: false)
          : const <String>[],
      lastRequestDay: CivilDay.tryParse(json['lastRequestDay']),
      lastImportDay: CivilDay.tryParse(json['lastImportDay']),
    );
  }
}

/// Keeps [ReviewState] in one preference of the device, so a read or a write
/// is always of the whole of it.
class ReviewStore {
  const ReviewStore(this._preferences);

  /// The key of the counters.
  static const String storageKey = 'carrete.review.state';

  final SharedPreferences _preferences;

  /// What is stored, or an empty state when there is nothing or it cannot be
  /// read.
  ReviewState load() {
    try {
      final raw = _preferences.getString(storageKey);
      if (raw == null) return ReviewState.empty;
      final json = jsonDecode(raw);
      if (json is Map) {
        return ReviewState.fromJson(json.cast<String, Object?>());
      }
    } on Object {
      // Unreadable: start again from nothing.
    }
    return ReviewState.empty;
  }

  /// Throws when the counters could not be written (the preferences answer
  /// false or fail): a request that is not on disk must not be made.
  Future<void> save(ReviewState state) async {
    final saved = await _preferences.setString(
      storageKey,
      jsonEncode(state.toJson()),
    );
    if (!saved) throw StateError('The review counters were not saved');
  }
}

/// The review counters on the preferences of the device.
final reviewStoreProvider = Provider<ReviewStore>(
  (ref) => ReviewStore(ref.watch(sharedPreferencesProvider)),
);
