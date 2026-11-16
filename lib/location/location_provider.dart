import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'location_source.dart';
import 'photo_location.dart';

export 'location_source.dart' show LocationPermission;

final locationSourceProvider = Provider<LocationSource>(
  (ref) => NativeLocationSource(),
);

final locationControllerProvider = Provider<LocationController>((ref) {
  final controller = LocationController(ref.watch(locationSourceProvider));
  ref.onDispose(controller.dispose);
  return controller;
});

/// Observes revocation without changing the persisted saveLocation setting.
final locationPermissionProvider = StreamProvider<LocationPermission>((ref) {
  final controller = ref.watch(locationControllerProvider);
  return controller.permissions;
});

/// Holds fixes only in memory. Neither permission checks nor opening the
/// camera ever requests permission; only the settings action does that.
class LocationController {
  LocationController(this.source, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;

  final LocationSource source;
  final DateTime Function() clock;
  final _permissions = StreamController<LocationPermission>.broadcast();
  LocationPermission permission = LocationPermission.denied;
  PhotoLocation? _lastFix;
  Timer? _timer;
  bool _active = false;
  bool _disposed = false;
  int _generation = 0;
  int _permissionRevision = 0;

  Stream<LocationPermission> get permissions async* {
    yield await refreshPermission();
    yield* _permissions.stream;
  }

  Future<LocationPermission> refreshPermission({bool request = false}) async {
    final next = await source.permission(request: request);
    if (_disposed) return next;
    _observePermission(next);
    return next;
  }

  void _observePermission(LocationPermission next) {
    if (next != permission) {
      _lastFix = null;
      _permissionRevision++;
      if (permission == LocationPermission.granted ||
          permission == LocationPermission.coarseOnly) {
        unawaited(source.stop());
      }
    }
    permission = next;
    _permissions.add(next);
  }

  void setActive(bool active) {
    if (_disposed || _active == active) return;
    _active = active;
    _generation++;
    _timer?.cancel();
    _timer = null;
    if (!active) {
      _lastFix = null;
      unawaited(source.stop());
      return;
    }
    unawaited(_update(_generation));
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_update(_generation));
    });
  }

  Future<void> _update(int generation) async {
    final status = await refreshPermission();
    if (_disposed ||
        !_active ||
        generation != _generation ||
        (status != LocationPermission.granted &&
            status != LocationPermission.coarseOnly)) {
      return;
    }
    final permissionRevision = _permissionRevision;
    await source.start();
    if (_disposed ||
        !_active ||
        generation != _generation ||
        permissionRevision != _permissionRevision) {
      return;
    }
    final reading = await source.current();
    if (_disposed ||
        !_active ||
        generation != _generation ||
        permissionRevision != _permissionRevision) {
      return;
    }
    if (reading.permission != permission) {
      _observePermission(reading.permission);
    }
    final fix = reading.fix;
    if (fix == null) {
      // Native expiry uses the boot clock, even if wall time moved backwards.
      _lastFix = null;
      return;
    }
    final now = clock();
    if ((permission != LocationPermission.granted &&
            permission != LocationPermission.coarseOnly) ||
        (permission == LocationPermission.coarseOnly && !fix.approximate) ||
        !fix.isUsableAt(now)) {
      return;
    }
    final previous = _lastFix?.isUsableAt(now) == true ? _lastFix : null;
    if (previous == null ||
        fix.time.isAfter(previous.time) ||
        (fix.time == previous.time && fix.accuracy < previous.accuracy)) {
      _lastFix = fix;
    }
  }

  /// Synchronous and bounded: never asks for a fix at the shutter.
  PhotoLocation? at(DateTime shutter) {
    if (!_active) return null;
    final fix = _lastFix;
    return fix != null && fix.isUsableAt(shutter) ? fix : null;
  }

  @visibleForTesting
  Future<void> update() => _update(_generation);

  void dispose() {
    setActive(false);
    _disposed = true;
    unawaited(_permissions.close());
  }
}
