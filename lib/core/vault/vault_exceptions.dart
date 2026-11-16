/// The errors of the vault of undeveloped photos.
///
/// The vault never returns garbage: a file that cannot be opened throws one
/// of these, so the roll UI can tell the user what happened.
sealed class VaultException implements Exception {
  const VaultException(this.path);

  /// The path of the photo, relative to the vault folder.
  final String path;
}

/// There is no file at the path.
final class VaultMissingException extends VaultException {
  const VaultMissingException(super.path);

  @override
  String toString() => 'VaultMissingException: no photo at "$path"';
}

/// The file is truncated, tampered with or not a vault file at all.
final class VaultCorruptedException extends VaultException {
  const VaultCorruptedException(super.path, this.reason);

  /// Why the file could not be opened.
  final VaultCorruption reason;

  @override
  String toString() =>
      'VaultCorruptedException: "$path" is ${reason.name} and cannot be read';
}

/// The ways a vault file can be unreadable.
enum VaultCorruption {
  /// Shorter than a header plus an authentication tag.
  truncated,

  /// Not a vault file, or a format version this build does not know.
  badHeader,

  /// The authentication tag does not match: a changed byte, or a wrong key.
  tampered,
}

/// The key of the vault is gone or cannot be read, so the photo cannot be
/// decrypted.
///
/// It happens when the data of the app was cleared, the platform keystore was
/// reset (a device restored from a backup, for example) or the key was
/// replaced after one of those: the roll cannot be developed any more.
final class VaultKeyLostException extends VaultException {
  const VaultKeyLostException(super.path, [this.cause]);

  /// The platform error, when there was one.
  final Object? cause;

  @override
  String toString() =>
      'VaultKeyLostException: the key that protects "$path" is not available'
      '${cause == null ? '' : ' ($cause)'}';
}
