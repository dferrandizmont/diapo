import 'dart:io';

/// Remove decrypted development files left by process death. This directory
/// contains only disposable plaintext copies; encrypted sources stay in vault.
Future<void> cleanRollDevelopmentTemps(Directory cache) async {
  final directory = Directory('${cache.path}/roll-develop');
  try {
    if (!await directory.exists()) return;
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is File) {
        try {
          await entry.delete();
        } on FileSystemException {
          // Already gone or temporarily in use; a later startup retries.
        }
      }
    }
  } on FileSystemException {
    // Startup must still work if the cache is temporarily unavailable.
  }
}
