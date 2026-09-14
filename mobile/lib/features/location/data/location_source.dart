import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../domain/entities/location_fix.dart';

/// Whether the device will give this application a position.
enum LocationAccess {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

/// The platform receiver, behind an interface.
///
/// Exists so the rest of the application — and every test — can reason about
/// positions without a platform channel. The concrete implementation is the
/// only place in the codebase that imports a geolocation package.
abstract interface class LocationSource {
  Future<LocationAccess> ensureAccess();

  /// One reading from the live receiver. Never invents coordinates.
  Future<LocationFix> readFix({required Duration timeout});

  /// Continuous foreground updates while the session is subscribed.
  Stream<LocationFix> watchFixes();

  /// Last reading the platform cached, or null. May itself be mocked.
  Future<LocationFix?> readLastKnown();
}

/// [LocationSource] backed by the platform's own receiver.
class GeolocatorLocationSource implements LocationSource {
  const GeolocatorLocationSource();

  static LocationSettings preciseSettings({Duration? timeLimit}) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 3),
        timeLimit: timeLimit,
        forceLocationManager: false,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        activityType: ActivityType.otherNavigation,
        distanceFilter: 5,
        timeLimit: timeLimit,
        pauseLocationUpdatesAutomatically: true,
        allowBackgroundLocationUpdates: false,
      );
    }
    return LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 5,
      timeLimit: timeLimit,
    );
  }

  @override
  Future<LocationAccess> ensureAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse =>
        LocationAccess.granted,
      LocationPermission.deniedForever => LocationAccess.deniedForever,
      LocationPermission.denied ||
      LocationPermission.unableToDetermine =>
        LocationAccess.denied,
    };
  }

  @override
  Future<LocationFix> readFix({required Duration timeout}) async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: preciseSettings(timeLimit: timeout),
    );
    return fromPosition(position);
  }

  @override
  Stream<LocationFix> watchFixes() => Geolocator.getPositionStream(
        locationSettings: preciseSettings(),
      ).map(fromPosition);

  @override
  Future<LocationFix?> readLastKnown() async {
    final position = await Geolocator.getLastKnownPosition();
    return position == null ? null : fromPosition(position);
  }

  /// Maps a platform [Position] without altering its coordinates.
  static LocationFix fromPosition(Position position) {
    final mocked = position.isMocked;
    return LocationFix(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: position.timestamp.toUtc(),
      source: mocked
          ? 'mock'
          : defaultTargetPlatform == TargetPlatform.android
              ? 'fused'
              : 'gps',
      isMocked: mocked,
    );
  }
}
