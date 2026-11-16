// The CHECKs of the tables name the column being declared (the idiom from
// the Drift docs).
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import 'converters.dart';

/// The kind of roll: a roll that has to be rewound, or a disposable one.
enum RollMode { roll, disposable }

/// The state of a roll.
enum RollState {
  /// The roll is in the camera and takes photos.
  open,

  /// The roll is closed and waiting for its time to come.
  developing,

  /// The roll is developed and its photos are in the gallery.
  developed,

  /// The roll was thrown away.
  discarded,

  /// The encryption key is no longer available.
  lost,
}

/// How long a closed roll takes to develop.
enum DevelopDelay {
  /// The roll develops as soon as it is closed.
  instant,

  /// The roll develops an hour after it is closed.
  oneHour,

  /// The roll develops the next morning at [nextMorningHour].
  nextMorning,

  /// The roll develops three days after it is closed.
  threeDays,
}

/// The lens that took a photo.
enum ShotLens { back, front }

/// The hour of the morning a roll closed with [DevelopDelay.nextMorning]
/// starts developing.
const int nextMorningHour = 8;

/// A roll of film: the photos of a camera until it is closed.
///
/// The times are milliseconds since the epoch (UTC), the same as the rest of
/// the app.
@DataClassName('RollRow')
class Rolls extends Table {
  /// The id of the roll.
  IntColumn get id => integer().autoIncrement()();

  /// The film of the roll.
  TextColumn get filmId => text()();

  /// The number of frames of the roll (12, 24, 36 or 27).
  IntColumn get length => integer()();

  /// Whether the roll is rewound or disposable.
  TextColumn get mode => textEnum<RollMode>()();

  /// How long the roll takes to develop once it is closed.
  TextColumn get developDelay => textEnum<DevelopDelay>()();

  /// The state of the roll.
  TextColumn get state => textEnum<RollState>()();

  /// When the roll was opened.
  IntColumn get createdAt => integer()();

  /// When the roll was closed; null while it is open.
  IntColumn get closedAt => integer().nullable()();

  /// When the roll starts developing; null while it is open.
  IntColumn get developAt => integer().nullable()();

  /// When the roll finished developing; null while it has not.
  IntColumn get developedAt => integer().nullable()();

  IntColumn get lostAt => integer().nullable()();

  /// The name the user gave the roll; null when it has none (the screens then
  /// call it "Carrete 07"). At most 40 characters, see `normalizeRollName`.
  TextColumn get name => text().nullable()();
}

/// A photo: one frame of a roll, or a loose photo outside of any roll.
///
/// A frame number appears once per roll (loose photos have none).
@DataClassName('ShotRow')
@TableIndex(
  name: 'shots_roll_frame',
  columns: {#rollId, #frameNumber},
  unique: true,
)
class Shots extends Table {
  /// The id of the photo.
  IntColumn get id => integer().autoIncrement()();

  /// The roll the photo belongs to; null for a loose photo.
  IntColumn get rollId => integer().nullable().references(
    Rolls,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// The frame of the roll the photo took; null for a loose photo.
  IntColumn get frameNumber => integer().nullable()();

  /// The film the photo was taken with.
  TextColumn get filmId => text()();

  /// The aspect ratio of the photo.
  TextColumn get format => text().map(const ShotFormatConverter())();

  /// The lens that took the photo.
  TextColumn get lens => textEnum<ShotLens>()();

  /// When the photo was taken.
  IntColumn get takenAt => integer()();

  /// The file of the photo while it is undeveloped; null once it is in the
  /// gallery.
  TextColumn get vaultPath => text().nullable()();

  /// The place of the photo in the gallery of the system; null while it is
  /// not saved.
  TextColumn get galleryUri => text().nullable()();

  /// The width of the photo in pixels.
  IntColumn get width => integer().nullable()();

  /// The height of the photo in pixels.
  IntColumn get height => integer().nullable()();

  /// How strong the film look is (1 is the recipe as it is).
  RealColumn get intensity => real().withDefault(const Constant(1))();

  /// The values the user changed in the photo, as JSON.
  TextColumn get overridesJson => text().nullable()();

  /// Versioned FailedShots JSON, null for legacy v1 shots.
  TextColumn get captureJobJson => text().nullable()();

  /// Permanent failure (for example an authenticated vault corruption).
  TextColumn get developFailure => text().nullable()();
}
