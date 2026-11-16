import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the Ko-fi page of the developer in the system browser.
///
/// The app has no internet permission: the browser does the loading. Android
/// only, on purpose: App Store guideline 3.1.1 does not allow a link to
/// donations for an individual developer, so iOS never gets this row and the
/// Swift side has no `openKofi`. The method lives in `MainActivity.kt`, which holds
/// the address itself, so the channel cannot be asked to open anything else. Where it is not available [canOpen] is false and
/// the settings do not show the row.
class ExternalLinks {
  const ExternalLinks();

  static const MethodChannel _channel = MethodChannel('carrete/system');

  /// Whether this platform can open the link.
  bool get canOpen =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// A second tap this soon after the first one opens nothing: a quick double
  /// tap would otherwise open the page twice.
  static const Duration repeatGuard = Duration(seconds: 1);

  static DateTime? _lastOpen;

  /// Forgets the last open, so each test starts without the guard.
  @visibleForTesting
  static void resetRepeatGuard() => _lastOpen = null;

  /// Opens the Ko-fi page. False when the system could not.
  Future<bool> openKofi() async {
    if (!canOpen) return false;
    final now = DateTime.now();
    final last = _lastOpen;
    if (last != null && now.difference(last) < repeatGuard) return true;
    _lastOpen = now;
    try {
      return await _channel.invokeMethod<bool>('openKofi') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

/// The links that leave the app. The tests override it.
final externalLinksProvider = Provider<ExternalLinks>(
  (ref) => const ExternalLinks(),
);
