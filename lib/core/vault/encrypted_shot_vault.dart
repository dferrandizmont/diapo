import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../database/shot_vault.dart';
import 'vault_exceptions.dart';
import 'vault_key_store.dart';

/// The vault: the photos of an open roll, encrypted on disk until the roll
/// develops.
///
/// Every photo is one file in the vault folder (inside the support directory
/// of the app, which the system never shows, backs up or purges), sealed with
/// AES-256-GCM under one key per installation that lives in the platform
/// keystore ([VaultKeyStore]). The file names are random, so neither the
/// name nor the content says when or with which film the photo was taken.
///
/// File format (version 1):
///
/// ```text
/// 0..3    magic "CRVT"
/// 4       format version (1)
/// 5..12   key id: which key sealed the file (8 random bytes)
/// 13..24  nonce (96 bits, fresh for every file)
/// 25..    ciphertext, then the 128-bit GCM tag
/// ```
///
/// The header is authenticated as associated data, so changing any of it is
/// detected like changing the photo itself.
///
/// Deleting a file does not scrub it: flash storage remaps blocks and keeps
/// old copies, so a secure overwrite cannot be guaranteed. The protection of
/// a thrown-away photo is that its bytes are unreadable without the key, not
/// that they are gone.
class EncryptedShotVault implements ShotVault {
  /// Creates a vault over [directory] (resolved once, on first use) with the
  /// key in [keys].
  ///
  /// [random] names the files; it must be a cryptographically secure source
  /// in production. The tests pass a predictable one.
  EncryptedShotVault({
    required FutureOr<Directory> Function() directory,
    required VaultKeyStore keys,
    Random? random,
  }) : this._(directory, keys, random ?? Random.secure());

  EncryptedShotVault._(this._directory, this._keys, this._random);

  /// The name of the vault folder inside the support directory of the app.
  ///
  /// It is excluded from Android backups in
  /// `android/app/src/main/res/xml/` because the key cannot follow it.
  static const String folderName = 'vault';

  static const List<int> _magic = [0x43, 0x52, 0x56, 0x54]; // CRVT
  static const int _version = 1;
  static const int _keyIdLength = 8;
  static const int _keyLength = 32;
  static const int _nonceLength = 12;
  static const int _tagLength = 16;
  static const int _headerLength = 4 + 1 + _keyIdLength + _nonceLength;
  static const int _nameBytes = 16;

  /// A valid file name: 32 lower-case hexadecimal characters, nothing else.
  static final RegExp _namePattern = RegExp(r'^[0-9a-f]{32}$');

  final FutureOr<Directory> Function() _directory;
  final VaultKeyStore _keys;
  final Random _random;

  Future<Directory>? _directoryFuture;
  Future<_VaultKey?>? _keyFuture;

  Future<Directory> _folder() => _directoryFuture ??= Future(() async {
    final directory = await _directory();
    await directory.create(recursive: true);
    return directory;
  });

  /// The key of the vault, or null when the store has none.
  ///
  /// Throws [VaultKeyLostException] when the store cannot be read.
  Future<_VaultKey?> _currentKey(String path) {
    return _keyFuture ??= Future(() async {
      final Uint8List? blob;
      try {
        blob = await _keys.read();
      } catch (error) {
        _keyFuture = null;
        throw VaultKeyLostException(path, error);
      }
      if (blob == null) return null;
      if (blob.length != _keyIdLength + _keyLength) {
        throw VaultKeyLostException(path, 'the stored key has a wrong size');
      }
      return _VaultKey(
        id: Uint8List.sublistView(blob, 0, _keyIdLength),
        bytes: Uint8List.sublistView(blob, _keyIdLength),
      );
    });
  }

  /// The key of the vault, generating and storing a fresh one if there is
  /// none yet.
  Future<_VaultKey> _keyForStoring() async {
    final existing = await _currentKey('');
    if (existing != null) return existing;
    final secure = Random.secure();
    final blob = Uint8List.fromList(
      List.generate(_keyIdLength + _keyLength, (_) => secure.nextInt(256)),
    );
    await _keys.write(blob);
    _keyFuture = null;
    final created = await _currentKey('');
    if (created == null) {
      throw const VaultKeyLostException('', 'the key store did not keep it');
    }
    return created;
  }

  @override
  Future<String> store(Uint8List jpeg) async {
    final key = await _keyForStoring();
    final folder = await _folder();
    final name = _newName();
    final sealed = await Isolate.run(
      () => _seal(jpeg, key.bytes, key.id),
      debugName: 'vault-seal',
    );

    final target = File('${folder.path}/$name');
    final temporary = File('${target.path}.tmp');
    try {
      await temporary.writeAsBytes(sealed, flush: true);
      await temporary.rename(target.path);
    } catch (_) {
      try {
        await temporary.delete();
      } catch (_) {
        // The temporary file was never written, or cannot be removed now.
      }
      rethrow;
    }
    return name;
  }

  @override
  Future<Uint8List> read(String path) async {
    final file = await _file(path);
    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } on PathNotFoundException {
      throw VaultMissingException(path);
    } on FileSystemException {
      if (!await file.exists()) throw VaultMissingException(path);
      rethrow;
    }

    if (bytes.length < _headerLength + _tagLength) {
      throw VaultCorruptedException(path, VaultCorruption.truncated);
    }
    for (var i = 0; i < _magic.length; i++) {
      if (bytes[i] != _magic[i]) {
        throw VaultCorruptedException(path, VaultCorruption.badHeader);
      }
    }
    if (bytes[_magic.length] != _version) {
      throw VaultCorruptedException(path, VaultCorruption.badHeader);
    }

    final key = await _currentKey(path);
    if (key == null) throw VaultKeyLostException(path);
    final fileKeyId = Uint8List.sublistView(
      bytes,
      _magic.length + 1,
      _headerLength - _nonceLength,
    );
    if (!_sameBytes(fileKeyId, key.id)) throw VaultKeyLostException(path);

    try {
      return await Isolate.run(
        () => _open(bytes, key.bytes),
        debugName: 'vault-open',
      );
    } on SecretBoxAuthenticationError {
      throw VaultCorruptedException(path, VaultCorruption.tampered);
    }
  }

  @override
  Future<void> delete(String path) async {
    final file = await _file(path);
    try {
      await file.delete();
    } on PathNotFoundException {
      // Already gone: nothing to do.
    } on FileSystemException {
      if (await file.exists()) rethrow;
    }
  }

  /// Throws every photo away, including half-written ones.
  ///
  /// For "throw the roll away" and for the tests. The bytes may survive on
  /// the flash chips (see the class comment); they stay unreadable without
  /// the key.
  @override
  Future<void> deleteAll() async {
    final folder = await _folder();
    await for (final entry in folder.list()) {
      await entry.delete(recursive: true);
    }
  }

  /// The names of the photos in the vault, for the tests and for a future
  /// consistency check against the database.
  @visibleForTesting
  Future<List<String>> list() async {
    final folder = await _folder();
    return [
      await for (final entry in folder.list())
        entry.path.replaceAll(r'\', '/').split('/').last,
    ];
  }

  Future<File> _file(String path) async {
    if (!_namePattern.hasMatch(path)) {
      throw ArgumentError.value(path, 'path', 'is not a vault file name');
    }
    final folder = await _folder();
    return File('${folder.path}/$path');
  }

  String _newName() {
    final buffer = StringBuffer();
    for (var i = 0; i < _nameBytes; i++) {
      buffer.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  static bool _sameBytes(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }
}

/// The key of the vault: its id (written in every file) and its bytes.
class _VaultKey {
  const _VaultKey({required this.id, required this.bytes});

  final Uint8List id;
  final Uint8List bytes;
}

AesGcm _cipher() => AesGcm.with256bits(nonceLength: 12);

/// Seals [clearText] into a vault file. Runs in a worker isolate.
Future<Uint8List> _seal(
  Uint8List clearText,
  Uint8List keyBytes,
  Uint8List keyId,
) async {
  final cipher = _cipher();
  final nonce = cipher.newNonce();
  final header = Uint8List(EncryptedShotVault._headerLength)
    ..setAll(0, EncryptedShotVault._magic)
    ..[EncryptedShotVault._magic.length] = EncryptedShotVault._version
    ..setAll(EncryptedShotVault._magic.length + 1, keyId)
    ..setAll(
      EncryptedShotVault._headerLength - EncryptedShotVault._nonceLength,
      nonce,
    );
  final box = await cipher.encrypt(
    clearText,
    secretKey: SecretKey(keyBytes),
    nonce: nonce,
    aad: header,
  );
  final out = Uint8List(
    header.length + box.cipherText.length + box.mac.bytes.length,
  );
  out.setAll(0, header);
  out.setAll(header.length, box.cipherText);
  out.setAll(header.length + box.cipherText.length, box.mac.bytes);
  return out;
}

/// Opens a vault file whose header was already checked. Runs in a worker
/// isolate. Throws [SecretBoxAuthenticationError] when the tag does not match.
Future<Uint8List> _open(Uint8List file, Uint8List keyBytes) async {
  const headerLength = EncryptedShotVault._headerLength;
  const tagLength = EncryptedShotVault._tagLength;
  final header = Uint8List.sublistView(file, 0, headerLength);
  final nonce = Uint8List.sublistView(
    file,
    headerLength - EncryptedShotVault._nonceLength,
    headerLength,
  );
  final box = SecretBox(
    Uint8List.sublistView(file, headerLength, file.length - tagLength),
    nonce: nonce,
    mac: Mac(Uint8List.sublistView(file, file.length - tagLength)),
  );
  final clear = await _cipher().decrypt(
    box,
    secretKey: SecretKey(keyBytes),
    aad: header,
  );
  return clear is Uint8List ? clear : Uint8List.fromList(clear);
}
