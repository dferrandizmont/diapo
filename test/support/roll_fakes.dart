import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:diapo/capture/capture_queue.dart';
import 'package:diapo/core/database/app_database.dart';
import 'package:diapo/core/database/converters.dart';
import 'package:diapo/core/database/tables.dart';
import 'package:diapo/gallery/photo_library.dart';
import 'package:diapo/platform/gallery_images.dart';
import 'package:diapo/platform/photo_actions.dart';
import 'package:diapo/roll/roll_developer.dart';
import 'package:diapo/roll/roll_name.dart';
import 'package:diapo/roll/roll_reveal.dart';
import 'package:diapo/roll/roll_service.dart';

/// A 1 x 1 PNG, so `Image.memory` has something it can decode.
final Uint8List tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

/// A roll row for the tests.
RollRow rollRow({
  int id = 7,
  String filmId = 'alpha',
  int length = 24,
  RollMode mode = RollMode.roll,
  DevelopDelay delay = DevelopDelay.oneHour,
  RollState state = RollState.open,
  int createdAt = 1000,
  int? closedAt,
  int? developAt,
  int? developedAt,
  String? name,
}) => RollRow(
  id: id,
  filmId: filmId,
  length: length,
  mode: mode,
  developDelay: delay,
  state: state,
  createdAt: createdAt,
  closedAt: closedAt,
  developAt: developAt,
  developedAt: developedAt,
  name: name,
);

/// A frame of a roll; [galleryUri] null with no [failure] is a frame whose
/// photo is gone.
ShotRow shotRow(
  int frame, {
  int rollId = 7,
  String? galleryUri,
  String? failure,
}) => ShotRow(
  id: rollId * 100 + frame,
  rollId: rollId,
  frameNumber: frame,
  filmId: 'alpha',
  format: ShotFormat.ratio3x2,
  lens: ShotLens.back,
  takenAt: 1000 + frame,
  galleryUri: galleryUri,
  intensity: 1,
  developFailure: failure,
);

/// A gallery that answers from a map: a location that is not in it is a
/// photo the user deleted.
class FakeGalleryImages implements GalleryImages {
  FakeGalleryImages([Map<String, Uint8List>? photos])
    : photos = photos ?? <String, Uint8List>{};

  final Map<String, Uint8List> photos;
  final List<String> thumbnailsAsked = <String>[];
  final List<String> fullsAsked = <String>[];

  @override
  Future<Uint8List?> thumbnail(String location) async {
    thumbnailsAsked.add(location);
    return photos[location];
  }

  @override
  Future<Uint8List?> full(String location) async {
    fullsAsked.add(location);
    return photos[location];
  }
}

/// A roll service that records what the screens ask of it.
class FakeRollService implements RollService {
  final List<String> calls = <String>[];
  Object? failWith;
  Completer<void>? developing;

  void _record(String call) {
    calls.add(call);
    if (failWith != null) throw failWith!;
  }

  @override
  Future<RollRow> openRoll(
    int length,
    DevelopDelay delay, {
    String? filmId,
  }) async {
    _record('open $length ${delay.name} $filmId');
    return rollRow(length: length, delay: delay, filmId: filmId ?? 'alpha');
  }

  /// What [captureIntoRoll] waits for, when it is set.
  Completer<void>? capturing;

  /// The jobs [captureIntoRoll] was given.
  final List<CaptureJob> jobs = <CaptureJob>[];

  @override
  Future<RollRow> openDisposable(DevelopDelay delay, {String? filmId}) async {
    _record('openDisposable ${delay.name} $filmId');
    return rollRow(
      length: 27,
      mode: RollMode.disposable,
      delay: delay,
      filmId: filmId ?? 'alpha',
    );
  }

  @override
  Future<ShotRow> captureIntoRoll(
    CaptureJob job, {
    int? rollId,
    ShotLens lens = ShotLens.back,
  }) async {
    jobs.add(job);
    _record('capture $rollId');
    await capturing?.future;
    return shotRow(1, rollId: rollId ?? 7);
  }

  @override
  Future<RollRow> closeRoll([int? rollId]) async {
    _record('close $rollId');
    return rollRow(id: rollId ?? 7, state: RollState.developing);
  }

  @override
  Future<void> developNow(int rollId) async {
    _record('developNow $rollId');
    await developing?.future;
  }

  @override
  Future<void> discardRoll(int rollId) async => _record('discard $rollId');

  /// The names the screens asked to store, by roll.
  final Map<int, String?> names = <int, String?>{};

  @override
  Future<String?> renameRoll(int rollId, String? name) async {
    _record('rename $rollId $name');
    return names[rollId] = normalizeRollName(name);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Progress as the developer reports it.
DevelopProgress progress(int done, int total, {int rollId = 7}) =>
    DevelopProgress(rollId, done, total);

/// A loose photo (taken with no roll), in the gallery at [galleryUri] unless
/// that is null.
ShotRow looseShotRow(
  int id, {
  required DateTime takenAt,
  String filmId = 'alpha',
  String? galleryUri,
}) => ShotRow(
  id: id,
  filmId: filmId,
  format: ShotFormat.ratio3x2,
  lens: ShotLens.back,
  takenAt: takenAt.millisecondsSinceEpoch,
  galleryUri: galleryUri ?? 'content://media/$id',
  intensity: 1,
);

/// A photo library that records what the screens ask of it.
class FakePhotoLibrary implements PhotoLibrary {
  PhotoDeletion deletion = PhotoDeletion.deleted;
  bool shares = true;
  final List<String> shared = <String>[];
  final List<(int, String)> deleted = <(int, String)>[];

  /// The photos each call of [dropMissing] was asked about.
  final List<List<ShotRow>> swept = <List<ShotRow>>[];

  @override
  Future<bool> share(String location) async {
    shared.add(location);
    return shares;
  }

  @override
  Future<PhotoDeletion> delete(int shotId, String location) async {
    deleted.add((shotId, location));
    return deletion;
  }

  @override
  Future<int> dropMissing(List<ShotRow> photos) async {
    swept.add(photos);
    return 0;
  }
}

/// The memory of the rolls that were revealed, in memory. With [allSeen] every
/// roll counts as seen, so a screen shows its frames at once.
class MemoryRollRevealStore implements RollRevealStore {
  MemoryRollRevealStore({this.allSeen = false});

  final bool allSeen;
  final Set<int> marked = <int>{};

  @override
  bool seen(int rollId) => allSeen || marked.contains(rollId);

  @override
  Future<void> markSeen(int rollId) async => marked.add(rollId);
}
