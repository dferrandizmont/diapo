import 'package:flutter/services.dart';

import 'photo_location.dart';

enum LocationPermission { granted, coarseOnly, denied, permanentlyDenied }

/// The permission observed while reading a fix, including a missing fix.
class LocationReading {
  const LocationReading(this.permission, this.fix);

  final LocationPermission permission;
  final PhotoLocation? fix;
}

abstract interface class LocationSource {
  Future<LocationPermission> permission({bool request = false});

  /// Idempotently keeps provider updates running until [stop].
  Future<void> start();

  /// Reads the newest usable fix without waiting for a provider.
  Future<LocationReading> current();
  Future<void> stop();
}

/// Android LocationManager; no plugin, Play services or background service.
class NativeLocationSource implements LocationSource {
  static const channel = MethodChannel('carrete/location');

  @override
  Future<void> start() => _command('start');

  @override
  Future<LocationPermission> permission({bool request = false}) async {
    try {
      final answer = await channel.invokeMethod<String>(
        request ? 'requestPermission' : 'permission',
      );
      return LocationPermission.values.asNameMap()[answer] ??
          LocationPermission.denied;
    } on PlatformException {
      return LocationPermission.denied;
    } on MissingPluginException {
      return LocationPermission.denied;
    }
  }

  @override
  Future<LocationReading> current() async {
    try {
      final answer = await channel.invokeMapMethod<String, Object?>('current');
      return LocationReading(
        LocationPermission.values.asNameMap()[answer?['permission']] ??
            LocationPermission.denied,
        PhotoLocation.fromJson(answer?['fix']),
      );
    } on PlatformException {
      return const LocationReading(LocationPermission.denied, null);
    } on MissingPluginException {
      return const LocationReading(LocationPermission.denied, null);
    }
  }

  @override
  Future<void> stop() => _command('stop');

  Future<void> _command(String method) async {
    try {
      await channel.invokeMethod<void>(method);
    } on PlatformException {
      // A missing provider is equivalent to no location.
    } on MissingPluginException {
      // Other platforms currently save without a device fix.
    }
  }
}
