import '../core/settings/review_state.dart';

/// When the app may ask the store for a review. Pure: the caller gives the
/// facts, so every rule can be tested at its boundary.
///
/// All of these must hold:
/// - the app was first opened at least [minDaysSinceFirstOpen] days ago;
/// - it was opened on at least [minOpenDays] different calendar days;
/// - the person has their own work (a developed roll, or at least
///   [minLoosePhotos] loose photos), which the caller tells in `hasOwnWork`;
/// - it is not the first use, and not in the [importSilenceDays] days that
///   start on the day of a settings import (import on day 1: quiet on days 1,
///   2 and 3, it may ask from day 4);
/// - the store was asked fewer than [maxRequests] times, not yet for this app
///   version, and the last time was at least [minDaysBetweenRequests] days ago.
abstract final class ReviewPolicy {
  static const int minDaysSinceFirstOpen = 7;
  static const int minOpenDays = 5;

  /// The loose photos that count as own work when there is no developed roll.
  static const int minLoosePhotos = 10;

  /// How many days stay quiet from the day of an import, that day included.
  static const int importSilenceDays = 3;
  static const int maxRequests = 3;
  static const int minDaysBetweenRequests = 90;

  /// Whether [developedRolls] and [loosePhotos] are enough work to be asked
  /// about: one developed roll, or [minLoosePhotos] loose photos.
  static bool ownWork({
    required int developedRolls,
    required int loosePhotos,
  }) => developedRolls >= 1 || loosePhotos >= minLoosePhotos;

  /// Whether [today] is still in the quiet days after an import on [imported]
  /// (an import dated in the future, from a clock that went back, stays quiet).
  static bool inImportSilence(CivilDay? imported, CivilDay today) =>
      imported != null && today.daysSince(imported) < importSilenceDays;

  static bool shouldAsk({
    required ReviewState state,
    required CivilDay today,
    required String appVersion,
    required bool hasOwnWork,
    required bool inFirstUse,
  }) {
    if (inFirstUse || !hasOwnWork) return false;
    final first = state.firstOpenDay;
    if (first == null || today.daysSince(first) < minDaysSinceFirstOpen) {
      return false;
    }
    if (state.openDays < minOpenDays) return false;
    if (inImportSilence(state.lastImportDay, today)) return false;
    if (state.requestCount >= maxRequests) return false;
    if (state.requestedVersions.contains(appVersion)) return false;
    final last = state.lastRequestDay;
    if (last != null && today.daysSince(last) < minDaysBetweenRequests) {
      return false;
    }
    return true;
  }
}
