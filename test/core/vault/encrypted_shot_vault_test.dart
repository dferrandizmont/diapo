import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:diapo/core/vault/encrypted_shot_vault.dart';
import 'package:diapo/core/vault/vault_exceptions.dart';
import 'package:diapo/core/vault/vault_key_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake JPEG: the marker, then a recognisable run of bytes.
final Uint8List photo = Uint8List.fromList([
  0xFF, 0xD8, 0xFF, 0xE0, //
  ...List.generate(4096, (i) => (i * 7 + 3) & 0xFF),
  0xFF, 0xD9,
]);

/// A "random" that always answers the same, so the file name is known.
class _FixedRandom implements Random {
  const _FixedRandom(this.value);

  final int value;

  @override
  bool nextBool() => value.isOdd;

  @override
  double nextDouble() => value / 256;

  @override
  int nextInt(int max) => value % max;
}

void main() {
  late Directory root;
  late InMemoryVaultKeyStore keys;

  EncryptedShotVault vault({VaultKeyStore? keyStore, Random? random}) =>
      EncryptedShotVault(
        directory: () => Directory('${root.path}/vault'),
        keys: keyStore ?? keys,
        random: random,
      );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('carrete_vault_test_');
    keys = InMemoryVaultKeyStore();
  });

  tearDown(() => root.delete(recursive: true));

  Future<File> fileOf(String path) async => File('${root.path}/vault/$path');

  test('a stored photo reads back byte for byte', () async {
    final subject = vault();
    final path = await subject.store(photo);
    expect(await subject.read(path), photo);
  });

  test('the key is created once and reused by a new vault instance', () async {
    final path = await vault().store(photo);
    final blob = keys.blob;
    expect(blob, isNotNull);
    expect(blob, hasLength(8 + 32));

    final again = vault();
    expect(await again.read(path), photo);
    expect(keys.blob, blob);
  });

  test('the file on disk is not the photo and has a fresh nonce', () async {
    final subject = vault();
    final first = await subject.store(photo);
    final second = await subject.store(photo);
    expect(first, isNot(second));

    final a = await (await fileOf(first)).readAsBytes();
    final b = await (await fileOf(second)).readAsBytes();
    // Header: magic (4), version (1), key id (8), nonce (12).
    expect(a.sublist(0, 5), b.sublist(0, 5));
    expect(a.sublist(5, 13), b.sublist(5, 13), reason: 'same key id');
    expect(a.sublist(13, 25), isNot(b.sublist(13, 25)), reason: 'nonce');
    expect(a.sublist(25), isNot(b.sublist(25)), reason: 'ciphertext');

    // The JPEG marker and its bytes are nowhere in the file.
    expect(a.sublist(25, 29), isNot([0xFF, 0xD8, 0xFF, 0xE0]));
    expect(a.length, 25 + photo.length + 16);
  });

  test('a tampered byte is reported as corrupted', () async {
    final subject = vault();
    final path = await subject.store(photo);
    final file = await fileOf(path);
    final bytes = await file.readAsBytes();
    bytes[25 + 100] ^= 0x01;
    await file.writeAsBytes(bytes, flush: true);

    await expectLater(
      subject.read(path),
      throwsA(
        isA<VaultCorruptedException>().having(
          (e) => e.reason,
          'reason',
          VaultCorruption.tampered,
        ),
      ),
    );
  });

  test('a tampered header is reported as corrupted', () async {
    final subject = vault();
    final path = await subject.store(photo);
    final file = await fileOf(path);
    final bytes = await file.readAsBytes();
    bytes[20] ^= 0x80; // inside the nonce
    await file.writeAsBytes(bytes, flush: true);

    await expectLater(
      subject.read(path),
      throwsA(
        isA<VaultCorruptedException>().having(
          (e) => e.reason,
          'reason',
          VaultCorruption.tampered,
        ),
      ),
    );
  });

  test('a truncated file is reported as corrupted', () async {
    final subject = vault();
    final path = await subject.store(photo);
    final file = await fileOf(path);
    final bytes = await file.readAsBytes();

    await file.writeAsBytes(bytes.sublist(0, bytes.length - 1), flush: true);
    await expectLater(
      subject.read(path),
      throwsA(
        isA<VaultCorruptedException>().having(
          (e) => e.reason,
          'reason',
          VaultCorruption.tampered,
        ),
      ),
    );

    await file.writeAsBytes(bytes.sublist(0, 20), flush: true);
    await expectLater(
      subject.read(path),
      throwsA(
        isA<VaultCorruptedException>().having(
          (e) => e.reason,
          'reason',
          VaultCorruption.truncated,
        ),
      ),
    );
  });

  test('a file that is not a vault file is reported as corrupted', () async {
    final subject = vault();
    final path = await subject.store(photo);
    final file = await fileOf(path);
    await file.writeAsBytes(photo, flush: true);

    await expectLater(
      subject.read(path),
      throwsA(
        isA<VaultCorruptedException>().having(
          (e) => e.reason,
          'reason',
          VaultCorruption.badHeader,
        ),
      ),
    );
  });

  test('a missing photo is reported as missing', () async {
    await expectLater(
      vault().read('0123456789abcdef0123456789abcdef'),
      throwsA(isA<VaultMissingException>()),
    );
  });

  test('a path that is not a vault name is rejected', () async {
    final subject = vault();
    for (final bad in ['../secret', 'a/b', r'..\x', 'photo.jpg', '']) {
      await expectLater(subject.read(bad), throwsArgumentError);
      await expectLater(subject.delete(bad), throwsArgumentError);
    }
  });

  test('deleting a missing photo is not an error', () async {
    final subject = vault();
    await subject.delete('0123456789abcdef0123456789abcdef');
    final path = await subject.store(photo);
    await subject.delete(path);
    await subject.delete(path);
    expect(await subject.list(), isEmpty);
  });

  test('deleteAll empties the vault, half-written files included', () async {
    final subject = vault();
    await subject.store(photo);
    await subject.store(photo);
    await File('${root.path}/vault/leftover.tmp').writeAsBytes([1, 2, 3]);
    expect(await subject.list(), hasLength(3));

    await subject.deleteAll();
    expect(await subject.list(), isEmpty);
    expect(await Directory('${root.path}/vault').exists(), isTrue);
  });

  group('a lost key', () {
    test('is reported when the keystore cannot be read', () async {
      final path = await vault().store(photo);
      keys.failing = true;

      await expectLater(
        vault().read(path),
        throwsA(isA<VaultKeyLostException>()),
      );
    });

    test('is reported when the keystore is empty (data cleared)', () async {
      final path = await vault().store(photo);
      await keys.delete();

      await expectLater(
        vault().read(path),
        throwsA(isA<VaultKeyLostException>()),
      );
    });

    test('is reported when a new key replaced the old one', () async {
      final path = await vault().store(photo);
      await keys.delete();
      final later = vault();
      final newer = await later.store(photo);

      expect(await later.read(newer), photo, reason: 'the new key works');
      await expectLater(
        later.read(path),
        throwsA(isA<VaultKeyLostException>()),
      );
    });

    test('does not hide a wrong key under the same id', () async {
      final path = await vault().store(photo);
      final blob = keys.blob!;
      blob[8] ^= 0xFF; // key bytes, not the id
      await keys.write(blob);

      await expectLater(
        vault().read(path),
        throwsA(
          isA<VaultCorruptedException>().having(
            (e) => e.reason,
            'reason',
            VaultCorruption.tampered,
          ),
        ),
      );
    });

    test(
      'is reported when the keystore fails before the first store',
      () async {
        keys.failing = true;
        await expectLater(
          vault().store(photo),
          throwsA(isA<VaultKeyLostException>()),
        );
      },
    );
  });

  test('file names are random hexadecimal and reveal nothing', () async {
    final subject = vault();
    final names = <String>{};
    for (var i = 0; i < 8; i++) {
      names.add(await subject.store(photo));
    }
    expect(names, hasLength(8));
    for (final name in names) {
      expect(name, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(name, isNot(contains('.')));
      expect(name, isNot(contains('/')));
    }
    expect(await subject.list(), unorderedEquals(names));
  });

  group('atomic write', () {
    const name = 'abababababababababababababababab';

    test('leaves no temporary file when the rename fails', () async {
      await Directory('${root.path}/vault/$name').create(recursive: true);
      final subject = vault(random: const _FixedRandom(0xAB));

      await expectLater(subject.store(photo), throwsA(isA<Exception>()));
      expect(await File('${root.path}/vault/$name.tmp').exists(), isFalse);
      expect(await subject.list(), [name]);
      expect(
        await FileSystemEntity.isDirectory('${root.path}/vault/$name'),
        isTrue,
      );
    });

    test('leaves no photo when the temporary write fails', () async {
      await Directory('${root.path}/vault/$name.tmp').create(recursive: true);
      final subject = vault(random: const _FixedRandom(0xAB));

      await expectLater(subject.store(photo), throwsA(isA<Exception>()));
      expect(await File('${root.path}/vault/$name').exists(), isFalse);
    });
  });
}
