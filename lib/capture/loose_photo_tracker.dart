import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings/first_minute.dart';
import 'capture_providers.dart';

/// Counts the loose photos that were durably saved, for the offer of a first
/// roll. It lives with the app and not with the camera screen, so a photo
/// saved while the camera is not on screen, or one recovered after a restart
/// (its earlier attempt failed and was never counted), is counted too, once
/// per capture.
///
/// Read it once when the app starts, before the failed shots are retried.
final loosePhotoTrackerProvider = Provider<void>((ref) {
  final queue = ref.watch(captureQueueProvider);
  final subscription = queue.events.listen((event) {
    if (!event.ok) return;
    // Old jobs may have no capture id. Deduplicate them through a stable
    // identity: the saved gallery URI, or the location of the shot, so a
    // photo that is saved once and recorded on a later run counts once.
    final job = event.job;
    String? identity = job.captureId;
    identity ??= event.uri;
    if (identity == null && job.location != null) {
      final location = job.location!;
      identity =
          'loc:${location.latitude},${location.longitude},'
          '${location.time.millisecondsSinceEpoch}';
    }
    ref.read(firstMinuteProvider.notifier).countLoosePhoto(identity);
  });
  ref.onDispose(() => unawaited(subscription.cancel()));
});
