import 'location_record.dart';

/// What the location panel is allowed to claim about the current reading.
///
/// LIVE GPS is reserved for a fresh, non-mocked receiver reading. Emulator
/// defaults, mock providers and stored leftovers must never inherit that label.
enum GpsStatus {
  liveGps('LIVE GPS'),
  gpsWeak('GPS WEAK'),
  lastKnown('LAST KNOWN LOCATION'),
  permissionDenied('LOCATION PERMISSION DENIED'),
  unavailable('LOCATION UNAVAILABLE'),
  demoMode('DEMO MODE'),
  mockLocation('MOCK LOCATION — NOT LIVE GPS');

  const GpsStatus(this.label);

  final String label;

  bool get isLive => this == GpsStatus.liveGps || this == GpsStatus.gpsWeak;
}

/// Pure classification so tests can cover every state without a device.
class GpsClassification {
  const GpsClassification({
    required this.status,
    required this.record,
    required this.guidance,
  });

  final GpsStatus status;
  final LocationRecord? record;
  final String guidance;

  static const weakAccuracyMeters = 50.0;
  static const staleAfter = Duration(seconds: 45);

  static GpsClassification classify({
    required DateTime now,
    required bool allowMock,
    LocationRecord? record,
    LocationAccessState access = LocationAccessState.unknown,
    bool listening = false,
    String? failure,
  }) {
    if (access == LocationAccessState.denied ||
        access == LocationAccessState.deniedForever) {
      final real = _realStored(record);
      if (real != null) {
        return GpsClassification(
          status: GpsStatus.lastKnown,
          record: real,
          guidance: access == LocationAccessState.deniedForever
              ? 'Permission is permanently denied. Last known real GPS is shown. '
                  'Grant location in device settings to resume live updates.'
              : 'Permission denied. Last known real GPS is shown. Grant location '
                  'to resume live updates.',
        );
      }
      return GpsClassification(
        status: GpsStatus.permissionDenied,
        record: null,
        guidance: access == LocationAccessState.deniedForever
            ? 'This app has been permanently denied location. Grant it in the '
                'device settings. Records can still be filed without a position.'
            : 'Location permission was not granted. Records can still be filed '
                'without a position.',
      );
    }

    if (access == LocationAccessState.serviceDisabled) {
      final real = _realStored(record);
      if (real != null) {
        return GpsClassification(
          status: GpsStatus.lastKnown,
          record: real,
          guidance:
              'Location services are off. Last known real GPS is shown. Turn '
              'them on to resume live updates.',
        );
      }
      return const GpsClassification(
        status: GpsStatus.unavailable,
        record: null,
        guidance:
            'Location services are switched off. Turn them on to capture a '
            'position. Everything else keeps working.',
      );
    }

    if (allowMock) {
      return GpsClassification(
        status: GpsStatus.demoMode,
        record: record,
        guidance: record == null
            ? 'Developer demo toggle is on. Mock GPS is accepted and will never '
                'be labelled LIVE GPS.'
            : 'Developer demo toggle is on. These coordinates are not claimed '
                'as live GPS.',
      );
    }

    if (record != null && record.fix.isEffectivelyMocked) {
      return GpsClassification(
        status: GpsStatus.mockLocation,
        record: record,
        guidance:
            'The platform reported a mock or emulator location. It is shown '
            'honestly and is not live GPS. Enable the developer mock-GPS '
            'toggle only if you intend to test with it.',
      );
    }

    if (record == null) {
      return GpsClassification(
        status: GpsStatus.unavailable,
        record: null,
        guidance: failure ??
            'No GPS reading yet. Stay in the open if a fix is slow; GPS does '
            'not need the internet.',
      );
    }

    final age = now.difference(record.timestamp);
    final stale = !listening || age > staleAfter;
    if (stale) {
      return GpsClassification(
        status: GpsStatus.lastKnown,
        record: record,
        guidance:
            'Last known real GPS. Live updates will resume when the receiver '
            'produces a fresh reading.',
      );
    }

    final accuracy = record.accuracy;
    if (accuracy != null && accuracy > weakAccuracyMeters) {
      return GpsClassification(
        status: GpsStatus.gpsWeak,
        record: record,
        guidance:
            'A live reading is arriving but the error radius is large. Move '
            'into the open for a tighter fix.',
      );
    }

    return GpsClassification(
      status: GpsStatus.liveGps,
      record: record,
      guidance: 'Live reading from this device\'s receiver.',
    );
  }

  static LocationRecord? _realStored(LocationRecord? record) {
    if (record == null || record.fix.isEffectivelyMocked) return null;
    return record;
  }
}

/// Permission / service state independent of the last stored row.
enum LocationAccessState {
  unknown,
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

/// `3 seconds ago` — what "last updated" means while the session is live.
String locationAgeLabel(DateTime timestamp, DateTime now) {
  final seconds = now.difference(timestamp).inSeconds;
  if (seconds <= 0) return 'just now';
  if (seconds == 1) return '1 second ago';
  if (seconds < 60) return '$seconds seconds ago';
  final minutes = seconds ~/ 60;
  if (minutes == 1) return '1 minute ago';
  if (minutes < 60) return '$minutes minutes ago';
  return timestamp.toLocal().toIso8601String();
}
