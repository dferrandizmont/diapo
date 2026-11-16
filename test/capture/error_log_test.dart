import 'dart:io';

import 'package:diapo/capture/error_log.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// An error with a code and a message of its own.
class _CodedError implements Exception {
  _CodedError(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'CodedError($code, $message)';
}

void main() {
  group('the token of an error', () {
    test(
      'of a file system exception keeps neither the path nor the message',
      () {
        final token = errorLogToken(
          FileSystemException(
            'Cannot open the original',
            '/storage/emulated/0/DCIM/Carrete/CAP1.jpg',
            const OSError('No such file or directory', 2),
          ),
        );
        expect(token, 'FileSystemException(2)');
        expect(token, isNot(contains('/storage')));
        expect(token, isNot(contains('CAP1.jpg')));
        expect(token, isNot(contains('Cannot open')));
      },
    );

    test('of a file system exception without a code is only its type', () {
      final token = errorLogToken(
        FileSystemException('Disk full', '/storage/emulated/0/CAP1.jpg'),
      );
      expect(token, 'FileSystemException');
      expect(token, isNot(contains('/storage')));
      expect(token, isNot(contains('Disk full')));
    });

    test(
      'of a platform exception keeps neither the message nor the details',
      () {
        final token = errorLogToken(
          PlatformException(
            code: 'lookup_failed',
            message: 'The file /storage/emulated/0/CAP1.jpg is gone',
            details: 'content://media/external/images/media/42',
          ),
        );
        expect(token, 'PlatformException(lookup_failed)');
        expect(token, isNot(contains('/storage')));
        expect(token, isNot(contains('CAP1.jpg')));
        expect(token, isNot(contains('content://')));
      },
    );

    test('of any other error is its type, never its message', () {
      final token = errorLogToken(
        StateError('The vault /data/user/0/carrete/vault.key is closed'),
      );
      expect(token, 'StateError');
      expect(token, isNot(contains('/data')));
      expect(token, isNot(contains('vault.key')));
      expect(token, isNot(contains('closed')));
    });

    test('of an error with a code keeps the code and drops the message', () {
      final token = errorLogToken(
        _CodedError('disk_full', 'There is no space left in /storage'),
      );
      expect(token, contains('disk_full'));
      expect(token, isNot(contains('/storage')));
      expect(token, isNot(contains('space left')));
    });
  });
}
