import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../core/database/database_provider.dart';
import '../core/database/tables.dart';
import '../roll/roll_providers.dart';

/// One thing the gallery lists: a developed roll or a day of loose photos.
sealed class GalleryEntry {
  const GalleryEntry();

  /// The photos of the entry, oldest first, as a contact sheet lists them.
  List<ShotRow> get photos;

  /// Where the entry belongs in the timeline: the gallery lists the newest
  /// first.
  DateTime get when;
}

/// A developed roll with the photos it still has in the gallery.
@immutable
class GalleryRoll extends GalleryEntry {
  const GalleryRoll(this.roll, this.photos, this.when);

  final RollRow roll;

  @override
  final List<ShotRow> photos;

  @override
  final DateTime when;
}

/// The loose photos of one day (in the time zone of the phone).
@immutable
class GalleryDay extends GalleryEntry {
  const GalleryDay(this.day, this.photos, this.when);

  /// Midnight of the day.
  final DateTime day;

  @override
  final List<ShotRow> photos;

  /// The time of the last photo of the day.
  @override
  final DateTime when;

  /// The id of the day in a route: `20261113`.
  String get key => dayKey(day);
}

/// The route id of [day]: year, month and day with no separators.
String dayKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}'
    '${day.month.toString().padLeft(2, '0')}'
    '${day.day.toString().padLeft(2, '0')}';

/// How many calendar days [to] is after [from]: only the dates count, so a
/// day of 23 or 25 hours (daylight saving time) is still one day.
int calendarDaysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// The day named by [key], or null when it is not one.
DateTime? parseDayKey(String key) {
  if (!RegExp(r'^\d{8}$').hasMatch(key)) return null;
  final year = int.parse(key.substring(0, 4));
  final month = int.parse(key.substring(4, 6));
  final day = int.parse(key.substring(6, 8));
  final date = DateTime(year, month, day);
  // DateTime rolls 31 February over to March: reject it.
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

/// What the gallery shows.
@immutable
class GalleryContent {
  const GalleryContent({required this.developing, required this.entries});

  static const GalleryContent empty = GalleryContent(
    developing: [],
    entries: [],
  );

  /// The rolls that are closed and not developed yet, the newest first. Their
  /// photos are not shown: the gallery says only that they are on their way.
  final List<RollRow> developing;

  /// The developed rolls and the days of loose photos, the newest first.
  final List<GalleryEntry> entries;

  /// How many photos the entries hold.
  int get photoCount => entries.fold(0, (sum, e) => sum + e.photos.length);

  /// Whether there is nothing to show.
  bool get isEmpty => developing.isEmpty && entries.isEmpty;

  /// The day [key], or null when it has no photos.
  GalleryDay? dayOf(String key) {
    for (final entry in entries) {
      if (entry is GalleryDay && entry.key == key) return entry;
    }
    return null;
  }
}

/// Builds the gallery from the rolls and the photos that are in the gallery
/// of the system (`galleryUri` set).
///
/// * A developed roll is listed with its photos; one that has none left (all
///   deleted) is not listed.
/// * Loose photos (no roll) are grouped by day.
/// * A roll that is not developed yet lists no photos, whatever the database
///   holds for it.
GalleryContent buildGalleryContent({
  required List<RollRow> rolls,
  required List<ShotRow> shots,
}) {
  final byRoll = <int, List<ShotRow>>{};
  final loose = <ShotRow>[];
  for (final shot in shots) {
    if (shot.galleryUri == null || shot.developFailure != null) continue;
    final rollId = shot.rollId;
    if (rollId == null) {
      loose.add(shot);
    } else {
      (byRoll[rollId] ??= []).add(shot);
    }
  }

  final entries = <GalleryEntry>[];
  final developing = <RollRow>[];
  for (final roll in rolls) {
    if (roll.state == RollState.developing) {
      developing.add(roll);
    } else if (roll.state == RollState.developed) {
      final photos = byRoll[roll.id];
      if (photos == null || photos.isEmpty) continue;
      photos.sort(_byFrame);
      final when = roll.developedAt ?? photos.last.takenAt;
      entries.add(
        GalleryRoll(roll, photos, DateTime.fromMillisecondsSinceEpoch(when)),
      );
    }
  }
  developing.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  final days = <String, List<ShotRow>>{};
  for (final shot in loose) {
    final taken = DateTime.fromMillisecondsSinceEpoch(shot.takenAt);
    (days[dayKey(taken)] ??= []).add(shot);
  }
  for (final photos in days.values) {
    photos.sort((a, b) => a.takenAt.compareTo(b.takenAt));
    final last = DateTime.fromMillisecondsSinceEpoch(photos.last.takenAt);
    entries.add(
      GalleryDay(DateTime(last.year, last.month, last.day), photos, last),
    );
  }
  entries.sort((a, b) => b.when.compareTo(a.when));
  return GalleryContent(developing: developing, entries: entries);
}

int _byFrame(ShotRow a, ShotRow b) {
  final frames = (a.frameNumber ?? 0).compareTo(b.frameNumber ?? 0);
  return frames != 0 ? frames : a.takenAt.compareTo(b.takenAt);
}

/// The photos that are in the gallery of the system, as they change.
final galleryShotsProvider = StreamProvider<List<ShotRow>>(
  (ref) => ref.watch(shotsDaoProvider).watchGalleryShots(),
);

/// What the gallery shows, as the rolls and the photos change.
final galleryContentProvider = Provider<AsyncValue<GalleryContent>>((ref) {
  final rolls = ref.watch(rollsListProvider);
  final shots = ref.watch(galleryShotsProvider);
  if (rolls.hasError) {
    return AsyncError(rolls.error!, rolls.stackTrace ?? StackTrace.empty);
  }
  if (shots.hasError) {
    return AsyncError(shots.error!, shots.stackTrace ?? StackTrace.empty);
  }
  final rollList = rolls.value;
  final shotList = shots.value;
  if (rollList == null || shotList == null) return const AsyncLoading();
  return AsyncData(buildGalleryContent(rolls: rollList, shots: shotList));
});
