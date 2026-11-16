import 'package:carrete/platform/photo_actions.dart';

/// Photo actions that remember what was deleted and answer what they are told.
class FakePhotoActions implements PhotoActions {
  /// What every delete answers.
  PhotoDeletion deletion = PhotoDeletion.deleted;

  /// The places that were asked to be deleted, in order.
  final List<String> deleted = <String>[];

  @override
  Future<PhotoDeletion> delete(String location) async {
    deleted.add(location);
    return deletion;
  }

  @override
  Future<bool> share(String location) async => true;

  @override
  Future<bool> shareFile(String path) async => true;

  @override
  Future<Set<String>> missing(Iterable<String> locations) async =>
      const <String>{};
}
