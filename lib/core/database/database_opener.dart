import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// The name of the file of the database of the app (without the extension).
const String databaseName = 'carrete';

/// The connection of the database of the app.
///
/// The file lives in the documents directory of the app; the photos of a roll
/// are not there (they wait in the vault, encrypted), only the rolls and
/// their frames.
///
/// The file is opened when the first query needs it, not here.
DatabaseConnection openCarreteConnection() =>
    driftDatabase(name: databaseName, native: const DriftNativeOptions());
