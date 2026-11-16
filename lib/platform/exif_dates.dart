/// The capture dates a photo carries in its EXIF, as the raw strings the
/// native side read (`yyyy:MM:dd HH:mm:ss` and an offset such as `+02:00`),
/// each null when the photo has none.
class ExifDates {
  const ExifDates({
    this.original,
    this.originalOffset,
    this.digitized,
    this.digitizedOffset,
  });

  /// `DateTimeOriginal`: when the shutter was pressed.
  final String? original;

  /// `OffsetTimeOriginal`: the zone of [original].
  final String? originalOffset;

  /// `DateTimeDigitized`: when the picture was digitised (the same moment on
  /// a digital camera).
  final String? digitized;

  /// `OffsetTimeDigitized`: the zone of [digitized].
  final String? digitizedOffset;
}

/// When a photo was taken, in the two ways the app needs it.
class PhotoDate {
  const PhotoDate({required this.wall, required this.instant});

  /// The clock of the camera when the shutter was pressed: the date the photo
  /// is printed with, whatever the zone the phone is in now.
  final DateTime wall;

  /// The same moment in the zone of this phone, with the offset of the EXIF
  /// applied when it has one: the day the photo belongs to in the gallery.
  /// Without an offset it is [wall].
  final DateTime instant;

  @override
  bool operator ==(Object other) =>
      other is PhotoDate && other.wall == wall && other.instant == instant;

  @override
  int get hashCode => Object.hash(wall, instant);
}

/// The date of a EXIF string such as `2019:07:14 18:30:05`, as the clock of
/// the camera showed it, or null when it is empty, malformed or one of the
/// placeholders cameras write when they do not know the time
/// (`0000:00:00 00:00:00`, blanks).
DateTime? parseExifDate(String? value) {
  final fields = _fields(value);
  if (fields == null) return null;
  final [year, month, day, hour, minute, second] = fields;
  return DateTime(year, month, day, hour, minute, second);
}

/// The offset of a EXIF string such as `+02:00` or `-05:30`, or null when it
/// is missing or malformed.
Duration? parseExifOffset(String? value) {
  if (value == null) return null;
  final match = RegExp(r'^\s*([+-])(\d{2}):(\d{2})\s*$').firstMatch(value);
  if (match == null) return null;
  final hours = int.parse(match.group(2)!);
  final minutes = int.parse(match.group(3)!);
  if (hours > 14 || minutes > 59) return null;
  final offset = Duration(hours: hours, minutes: minutes);
  return match.group(1) == '-' ? -offset : offset;
}

List<int>? _fields(String? value) {
  if (value == null) return null;
  final match = RegExp(
    r'^\s*(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2}):(\d{2})',
  ).firstMatch(value);
  if (match == null) return null;
  final parts = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
  final [year, month, day, hour, minute, second] = parts;
  if (year < 1900 || month < 1 || month > 12 || day < 1 || day > 31) {
    return null;
  }
  if (hour > 23 || minute > 59 || second > 59) return null;
  // 31 February rolls over to March: that is not a date of the photo.
  final date = DateTime(year, month, day, hour, minute, second);
  if (date.month != month || date.day != day) return null;
  return parts;
}

PhotoDate? _photoDate(String? value, String? offsetValue) {
  final fields = _fields(value);
  if (fields == null) return null;
  final [year, month, day, hour, minute, second] = fields;
  final wall = DateTime(year, month, day, hour, minute, second);
  final offset = parseExifOffset(offsetValue);
  if (offset == null) return PhotoDate(wall: wall, instant: wall);
  final utc = DateTime.utc(year, month, day, hour, minute, second);
  return PhotoDate(wall: wall, instant: utc.subtract(offset).toLocal());
}

/// When an imported photo was taken: `DateTimeOriginal`, else
/// `DateTimeDigitized`, each with its own offset. Null when the photo has
/// neither (a screenshot, a picture saved from a chat): the copy the picker
/// hands over has lost the date of the original file, so the app knows no
/// date for it and prints none, rather than print the day it was imported.
PhotoDate? photoDateOf(ExifDates exif) =>
    _photoDate(exif.original, exif.originalOffset) ??
    _photoDate(exif.digitized, exif.digitizedOffset);
