import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../vault/encrypted_shot_vault.dart';
import '../vault/vault_key_store.dart';
import 'app_database.dart';
import 'database_opener.dart';
import 'rolls_dao.dart';
import 'shot_vault.dart';
import 'shots_dao.dart';

/// The database of the app.
///
/// The file is opened the first time a query needs it. The tests override
/// this provider with an in-memory database.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase(openCarreteConnection());
  ref.onDispose(() => unawaited(database.close()));
  return database;
});

/// The rules of the rolls.
final rollsDaoProvider = Provider<RollsDao>(
  (ref) => RollsDao(ref.watch(appDatabaseProvider)),
);

/// The photos of the app.
final shotsDaoProvider = Provider<ShotsDao>(
  (ref) => ShotsDao(ref.watch(appDatabaseProvider)),
);

/// The vault of the undeveloped photos: `vault/` inside the support directory
/// of the app, encrypted with a key in the platform keystore.
///
/// Nothing in the UI uses it yet; the roll mode will. The tests override it
/// with a vault over a temporary folder and an in-memory key store.
final shotVaultProvider = Provider<ShotVault>(
  (ref) => EncryptedShotVault(
    directory: () async => Directory(
      '${(await getApplicationSupportDirectory()).path}/'
      '${EncryptedShotVault.folderName}',
    ),
    keys: SecureVaultKeyStore(),
  ),
);
