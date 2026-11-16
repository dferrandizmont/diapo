import 'package:drift/drift.dart';

/// The aspect ratio of a photo. The value stored in the database is the
/// ratio itself (`3:2`), so the formats of a future version can be added
/// without renaming anything in the code.
enum ShotFormat {
  ratio3x2('3:2'),
  ratio4x3('4:3'),
  ratio1x1('1:1'),
  ratio16x9('16:9');

  const ShotFormat(this.storageValue);

  /// The value written to the database.
  final String storageValue;

  /// The format stored as [value].
  static ShotFormat fromStorage(String value) => values.firstWhere(
    (format) => format.storageValue == value,
    orElse: () => throw FormatException('Unknown shot format', value),
  );
}

/// Reads and writes a [ShotFormat] as the text of the ratio.
class ShotFormatConverter extends TypeConverter<ShotFormat, String> {
  const ShotFormatConverter();

  @override
  ShotFormat fromSql(String fromDb) => ShotFormat.fromStorage(fromDb);

  @override
  String toSql(ShotFormat value) => value.storageValue;
}
