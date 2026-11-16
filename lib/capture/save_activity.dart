import 'package:flutter/foundation.dart';

/// The photos of a roll that are being put away right now.
///
/// A roll frame does not go through the capture queue: it is encrypted into
/// the vault by the roll service. This keeps count of those frames so the
/// camera can say that something is being saved, and tells the recovery scan
/// which camera originals are in use (they are not failures). It holds file
/// paths and a count, never the content of a photo.
class SaveActivity {
  final ValueNotifier<int> _saving = ValueNotifier<int>(0);
  final List<String> _paths = <String>[];

  /// How many frames are being saved.
  ValueListenable<int> get saving => _saving;

  /// Says that the frame whose camera original is [path] is being saved.
  void begin(String path) {
    _paths.add(path);
    _saving.value = _paths.length;
  }

  /// Says that the frame of [path] is done, whatever the outcome.
  void end(String path) {
    _paths.remove(path);
    _saving.value = _paths.length;
  }

  /// Whether the frame of [path] is being saved.
  bool isActive(String path) => _paths.contains(path);

  void dispose() => _saving.dispose();
}
