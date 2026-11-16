import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the key of the vault lives.
///
/// The vault keeps one secret (the key id and the AES-256 key, as one blob)
/// and asks this store for it. The real store is the platform keystore; the
/// tests use an in-memory one.
abstract interface class VaultKeyStore {
  /// The key blob, or null when there is none (first use, data cleared,
  /// keystore reset).
  ///
  /// May throw when the platform cannot read it; the vault reports that as a
  /// lost key.
  Future<Uint8List?> read();

  /// Stores the key blob, replacing any previous one.
  Future<void> write(Uint8List blob);

  /// Forgets the key blob.
  Future<void> delete();
}

/// The key store of the app: the platform keystore through
/// `flutter_secure_storage`.
///
/// - **Android:** the value is encrypted with an AES key that is itself
///   wrapped by an RSA key pair in the Android Keystore (non-exportable). No
///   user authentication is attached to the key, so it works after a reboot
///   as soon as the device has been unlocked once. When the Keystore key is
///   gone (data cleared, restored on another device) the plugin resets the
///   storage and `read` returns null.
/// - **iOS:** the Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`:
///   readable after the first unlock since boot (so a develop job can run
///   while the phone is locked), never migrated to another device.
class SecureVaultKeyStore implements VaultKeyStore {
  SecureVaultKeyStore([FlutterSecureStorage? storage])
    : _storage = storage ?? _defaultStorage;

  static const FlutterSecureStorage _defaultStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// The entry of the key in the secure storage.
  static const String entryName = 'shot_vault_key_v1';

  final FlutterSecureStorage _storage;

  @override
  Future<Uint8List?> read() async {
    final encoded = await _storage.read(key: entryName);
    if (encoded == null) return null;
    try {
      return base64Decode(encoded);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(Uint8List blob) =>
      _storage.write(key: entryName, value: base64Encode(blob));

  @override
  Future<void> delete() => _storage.delete(key: entryName);
}

/// A key store that lives in memory, for the tests.
///
/// [failing] makes every read throw, like a keystore that cannot unwrap its
/// key.
class InMemoryVaultKeyStore implements VaultKeyStore {
  InMemoryVaultKeyStore({Uint8List? blob, this.failing = false})
    : _blob = blob == null ? null : Uint8List.fromList(blob);

  Uint8List? _blob;

  /// Whether reads throw.
  bool failing;

  /// The stored blob, for assertions.
  Uint8List? get blob => _blob;

  @override
  Future<Uint8List?> read() async {
    if (failing) throw StateError('the keystore cannot be read');
    return _blob;
  }

  @override
  Future<void> write(Uint8List blob) async => _blob = Uint8List.fromList(blob);

  @override
  Future<void> delete() async => _blob = null;
}
