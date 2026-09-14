import 'dart:async';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/gps_status.dart';
import '../../../domain/entities/location_fix.dart';
import 'location_source.dart';

/// Reads the device's own position.
///
/// **This does not use the internet.** GPS is a satellite service. Nothing here
/// invents coordinates, and nothing here substitutes a demo point when the
/// receiver fails.
class LocationService {
  const LocationService({
    this.source = const GeolocatorLocationSource(),
    this.timeout = AppConfig.locationTimeout,
  });

  final LocationSource source;
  final Duration timeout;

  Future<LocationAccess> ensureAccess() => source.ensureAccess();

  LocationAccessState toAccessState(LocationAccess access) => switch (access) {
        LocationAccess.granted => LocationAccessState.granted,
        LocationAccess.denied => LocationAccessState.denied,
        LocationAccess.deniedForever => LocationAccessState.deniedForever,
        LocationAccess.serviceDisabled => LocationAccessState.serviceDisabled,
      };

  Future<LocationFix> currentFix() async {
    await _requireAccess();
    try {
      return await source.readFix(timeout: timeout);
    } on TimeoutException {
      throw LocationUnavailableException(
        'No fix in ${timeout.inSeconds} seconds. Move into the open and try '
        'again, or continue without a position.',
      );
    } on LocationUnavailableException {
      rethrow;
    } on Exception catch (error) {
      throw LocationUnavailableException(
        'The device could not produce a position: $error',
      );
    }
  }

  /// Foreground stream. Stops when the subscriber cancels.
  Stream<LocationFix> watchFixes() async* {
    await _requireAccess();
    yield* source.watchFixes();
  }

  Future<LocationFix?> lastKnownFix() async {
    try {
      return await source.readLastKnown();
    } on Exception {
      return null;
    }
  }

  Future<void> _requireAccess() async {
    final access = await source.ensureAccess();
    switch (access) {
      case LocationAccess.serviceDisabled:
        throw const LocationUnavailableException(
          'Location services are switched off. Turn them on in the device '
          'settings to record positions; everything else keeps working '
          'without them.',
        );
      case LocationAccess.deniedForever:
        throw const LocationUnavailableException(
          'This app has been permanently denied access to location. Grant it '
          'in the device settings to record positions.',
          isPermanent: true,
        );
      case LocationAccess.denied:
        throw const LocationUnavailableException(
          'Location permission was not granted. Records will be stored '
          'without a position until it is.',
        );
      case LocationAccess.granted:
        return;
    }
  }
}
