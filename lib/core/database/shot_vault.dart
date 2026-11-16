import 'dart:typed_data';

/// The vault where the photos of a roll wait until they develop.
///
/// The photos of an open roll never reach the gallery of the system: they
/// stay in the storage of the app, encrypted, until the roll develops. This
/// interface is the contract of that storage; `EncryptedShotVault` in
/// `lib/core/vault/` is the implementation.
///
/// The paths are relative to the vault folder (random file names), so a move
/// of the data of the app does not break them.
abstract interface class ShotVault {
  /// Stores the photo [jpeg] in the vault and returns the path it was
  /// stored at.
  Future<String> store(Uint8List jpeg);

  /// The bytes of the photo stored at [path].
  Future<Uint8List> read(String path);

  /// Throws the photo stored at [path] away. A missing file is not an error.
  Future<void> delete(String path);

  /// Throws every photo away: the roll goes to the bin.
  Future<void> deleteAll();
}
