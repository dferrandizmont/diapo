import 'dart:io';

import 'package:flutter/services.dart' show PlatformException;

/// A short, privacy-safe token for an error: its category and, when there is
/// one, its error code. Never a path, a URI or the exception's message.
String errorLogToken(Object error) {
  if (error is FileSystemException) {
    final code = error.osError?.errorCode;
    return code == null ? 'FileSystemException' : 'FileSystemException($code)';
  }
  if (error is PlatformException) {
    return 'PlatformException(${error.code})';
  }
  try {
    final code = (error as dynamic).code;
    if (code is String || code is int) {
      return '${error.runtimeType}($code)';
    }
  } on Object {
    // Not every error carries a code.
  }
  return error.runtimeType.toString();
}
