import 'package:diapo/platform/gallery_images.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('carrete/media');
  late List<MethodCall> calls;
  late Object? Function(MethodCall call) answer;

  setUp(() {
    calls = <MethodCall>[];
    answer = (call) => Uint8List.fromList([1, 2, 3]);
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

  test('asks the native side for a thumbnail of the requested size', () async {
    final images = NativeGalleryImages(extent: 200);
    final bytes = await images.thumbnail('content://media/1');
    expect(bytes, [1, 2, 3]);
    expect(calls.single.method, 'loadThumbnail');
    expect(calls.single.arguments, {'uri': 'content://media/1', 'extent': 200});
  });

  test('keeps thumbnails in memory and reads each one once', () async {
    final images = NativeGalleryImages();
    await images.thumbnail('content://media/1');
    await images.thumbnail('content://media/1');
    expect(calls, hasLength(1));
  });

  test('shares a read that is already running', () async {
    final images = NativeGalleryImages();
    final both = await Future.wait([
      images.thumbnail('content://media/1'),
      images.thumbnail('content://media/1'),
    ]);
    expect(both.every((b) => b != null), isTrue);
    expect(calls, hasLength(1));
  });

  test('forgets the oldest thumbnail when the cache is full', () async {
    final images = NativeGalleryImages(cacheSize: 2);
    await images.thumbnail('a');
    await images.thumbnail('b');
    await images.thumbnail('a'); // a is now the most recent
    await images.thumbnail('c'); // b goes
    calls.clear();
    await images.thumbnail('a');
    expect(calls, isEmpty);
    await images.thumbnail('b');
    expect(calls, hasLength(1));
  });

  test('a deleted photo is remembered for thumbnails and the viewer', () async {
    answer = (call) =>
        throw PlatformException(code: 'not_found', message: 'gone');
    final images = NativeGalleryImages();
    expect(await images.thumbnail('content://media/9'), isNull);
    expect(await images.thumbnail('content://media/9'), isNull);
    expect(await images.full('content://media/9'), isNull);
    expect(calls, hasLength(1));
  });

  test('a missing full image evicts its previously cached thumbnail', () async {
    final images = NativeGalleryImages();
    expect(await images.thumbnail('photo'), isNotNull);
    answer = (_) => throw PlatformException(code: 'not_found');
    expect(await images.full('photo'), isNull);
    expect(await images.thumbnail('photo'), isNull);
    expect(calls.map((c) => c.method), ['loadThumbnail', 'readImage']);
  });

  test('the missing memo evicts its oldest entry when full', () async {
    answer = (_) => throw PlatformException(code: 'not_found');
    final images = NativeGalleryImages(cacheSize: 2);
    for (final location in ['a', 'b', 'c', 'b', 'c']) {
      expect(await images.thumbnail(location), isNull);
    }
    expect(calls, hasLength(3));
    answer = (_) => Uint8List.fromList([1, 2, 3]);
    expect(await images.thumbnail('a'), [1, 2, 3]);
    expect(calls, hasLength(4));
  });

  test('resuming retries a photo after not_found', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(galleryImagesProvider, (_, _) {});
    addTearDown(subscription.close);
    answer = (_) => throw PlatformException(code: 'not_found');
    expect(await subscription.read().thumbnail('restored'), isNull);
    answer = (_) => Uint8List.fromList([1, 2, 3]);
    expect(await subscription.read().thumbnail('restored'), isNull);
    expect(calls, hasLength(1));

    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      WidgetsBinding.instance.handleAppLifecycleStateChanged(state);
    }
    await container.pump();
    expect(await subscription.read().thumbnail('restored'), [1, 2, 3]);
    expect(calls, hasLength(2));
  });

  test('temporary read failures can be retried', () async {
    final images = NativeGalleryImages();
    answer = (_) => throw PlatformException(code: 'not_allowed');
    expect(await images.thumbnail('photo'), isNull);
    answer = (_) => Uint8List.fromList([1, 2, 3]);
    expect(await images.thumbnail('photo'), [1, 2, 3]);
    expect(calls, hasLength(2));
  });

  test('any other native failure also answers null', () async {
    answer = (call) =>
        throw PlatformException(code: 'not_allowed', message: 'no');
    expect(await NativeGalleryImages().full('/x/y.jpg'), isNull);
  });

  test('reads the whole photo without caching it', () async {
    final images = NativeGalleryImages();
    expect(await images.full('content://media/1'), [1, 2, 3]);
    expect(await images.full('content://media/1'), [1, 2, 3]);
    expect(calls.map((c) => c.method), ['readImage', 'readImage']);
  });

  test('a platform without the native side answers null', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    expect(await NativeGalleryImages().thumbnail('x'), isNull);
  });
}
