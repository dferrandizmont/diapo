import 'package:carrete/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// A fresh in-memory database, for the tests.
///
/// The sqlite library comes from `package:sqlite3` (a dependency of drift),
/// which bundles it when the tests run: nothing to install.
AppDatabase openMemoryDatabase() {
  // The tests open several databases on purpose.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      // No timers are left after the close (drift recommends it for the
      // tests of the widgets).
      closeStreamsSynchronously: true,
    ),
  );
}
