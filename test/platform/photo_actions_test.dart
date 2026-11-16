import 'package:diapo/platform/photo_actions.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('carrete/media');
  late List<MethodCall> calls;
  late Object? Function(MethodCall call) answer;

  setUp(() {
    calls = <MethodCall>[];
    answer = (call) => true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return answer(call);
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('share', () {
    test('asks the native side to share the photo at its place', () async {
      expect(await NativePhotoActions().share('content://media/1'), isTrue);
      expect(calls.single.method, 'shareImage');
      expect(calls.single.arguments, {'uri': 'content://media/1'});
    });

    test('says no when the native side could not open the sheet', () async {
      answer = (call) => false;
      expect(await NativePhotoActions().share('content://media/1'), isFalse);
    });

    test('a photo that is not there, or any other failure, says no', () async {
      answer = (call) =>
          throw PlatformException(code: 'not_found', message: 'gone');
      expect(await NativePhotoActions().share('content://media/1'), isFalse);
      answer = (call) =>
          throw PlatformException(code: 'share_failed', message: 'no');
      expect(await NativePhotoActions().share('content://media/1'), isFalse);
    });
  });

  group('shareFile', () {
    const path = '/cache/contact-sheets/sheet.jpg';

    test('asks the native side to share only the given cache path', () async {
      expect(await NativePhotoActions().shareFile(path), isTrue);
      expect(calls.single.method, 'shareFile');
      expect(calls.single.arguments, {'path': path});
    });

    test('false or no native answer says no', () async {
      for (final value in [false, null]) {
        answer = (_) => value;
        expect(await NativePhotoActions().shareFile(path), isFalse);
      }
    });

    test('native errors say no', () async {
      for (final code in ['not_found', 'not_allowed', 'share_failed']) {
        answer = (_) => throw PlatformException(code: code);
        expect(await NativePhotoActions().shareFile(path), isFalse);
      }
    });

    test('a missing plugin says no', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      expect(await NativePhotoActions().shareFile(path), isFalse);
    });
  });

  group('delete', () {
    test('asks the native side to delete the photo at its place', () async {
      answer = (call) => 'deleted';
      final outcome = await NativePhotoActions().delete('content://media/1');
      expect(outcome, PhotoDeletion.deleted);
      expect(calls.single.method, 'deleteImage');
      expect(calls.single.arguments, {'uri': 'content://media/1'});
    });

    test('tells the four answers apart', () async {
      final actions = NativePhotoActions();
      answer = (call) => 'gone';
      expect(await actions.delete('x'), PhotoDeletion.gone);
      answer = (call) => 'cancelled';
      expect(await actions.delete('x'), PhotoDeletion.cancelled);
      answer = (call) => 'something else';
      expect(await actions.delete('x'), PhotoDeletion.failed);
    });

    test('a photo deleted whose original stayed is its own answer', () async {
      answer = (call) => 'deletedPhotoKeptOriginal';
      expect(
        await NativePhotoActions().delete('x'),
        PhotoDeletion.deletedKeptOriginal,
      );
    });

    test('not_found means the photo was already gone', () async {
      answer = (call) =>
          throw PlatformException(code: 'not_found', message: 'gone');
      expect(
        await NativePhotoActions().delete('content://media/9'),
        PhotoDeletion.gone,
      );
    });

    test(
      'any other native failure is a failed delete, never an exception',
      () async {
        answer = (call) =>
            throw PlatformException(code: 'not_allowed', message: 'no');
        expect(
          await NativePhotoActions().delete('content://media/9'),
          PhotoDeletion.failed,
        );
      },
    );
  });

  group('missing', () {
    test('asks which of the photos are gone and answers a set', () async {
      answer = (call) => ['content://media/2'];
      final gone = await NativePhotoActions().missing([
        'content://media/1',
        'content://media/2',
      ]);

      expect(gone, {'content://media/2'});
      expect(calls.single.method, 'missingImages');
      expect(calls.single.arguments, {
        'uris': ['content://media/1', 'content://media/2'],
      });
    });

    test('asks nothing about no photos', () async {
      expect(await NativePhotoActions().missing([]), isEmpty);
      expect(calls, isEmpty);
    });

    test('a failure reports nothing as missing', () async {
      answer = (call) =>
          throw PlatformException(code: 'lookup_failed', message: 'no');
      expect(await NativePhotoActions().missing(['x']), isEmpty);
    });
  });
}
