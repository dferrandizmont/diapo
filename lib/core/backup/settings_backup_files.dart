import 'package:flutter/services.dart';

import 'settings_backup_codec.dart';

/// A document picker; no paths or persistent URI grants cross this interface.
/// Null/false means the user cancelled. iOS can supply another implementation.
abstract interface class SettingsBackupFiles {
  Future<bool> write({required String suggestedName, required Uint8List bytes});
  Future<Uint8List?> read();
}

class SystemSettingsBackupFiles implements SettingsBackupFiles {
  const SystemSettingsBackupFiles({
    this.channel = const MethodChannel('carrete/system'),
  });

  final MethodChannel channel;

  @override
  Future<bool> write({
    required String suggestedName,
    required Uint8List bytes,
  }) async {
    if (bytes.length > SettingsBackupCodec.maxBytes) {
      throw const SettingsBackupException(BackupErrorCode.tooLarge);
    }
    return await _invoke<bool>('exportSettings', {
          'suggestedName': suggestedName,
          'bytes': bytes,
        }) ??
        false;
  }

  @override
  Future<Uint8List?> read() async {
    final bytes = await _invoke<Uint8List>('importSettings');
    if (bytes != null && bytes.length > SettingsBackupCodec.maxBytes) {
      throw const SettingsBackupException(BackupErrorCode.tooLarge);
    }
    return bytes;
  }

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      throw SettingsBackupException(switch (error.code) {
        'too_large' => BackupErrorCode.tooLarge,
        'busy' => BackupErrorCode.busy,
        'interrupted' => BackupErrorCode.interrupted,
        _ => BackupErrorCode.storage,
      });
    } on MissingPluginException {
      throw const SettingsBackupException(BackupErrorCode.storage);
    }
  }
}
