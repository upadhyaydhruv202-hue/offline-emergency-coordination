import 'package:drp_mobile/domain/entities/location_fix.dart';
import 'package:drp_mobile/features/location/data/location_source.dart';

/// A location source that needs no device and no permission dialog.
///
/// Coordinates here are test fixtures only. They are never used by the shipping
/// application.
class FakeLocationSource implements LocationSource {
  FakeLocationSource({
    this.access = LocationAccess.granted,
    Stream<LocationFix>? updates,
    LocationFix? fix,
  })  : _updates = updates,
        fix = fix ??
            LocationFix(
              latitude: 12.0,
              longitude: 77.0,
              accuracy: 8,
              timestamp: DateTime.utc(2026, 9, 8, 11, 12, 18),
              source: 'test',
              isMocked: false,
            );

  final LocationAccess access;
  final LocationFix fix;
  final Stream<LocationFix>? _updates;

  @override
  Future<LocationAccess> ensureAccess() async => access;

  @override
  Future<LocationFix> readFix({required Duration timeout}) async {
    if (access != LocationAccess.granted) {
      throw StateError('readFix called without access');
    }
    return fix;
  }

  @override
  Stream<LocationFix> watchFixes() => _updates ?? Stream<LocationFix>.value(fix);

  @override
  Future<LocationFix?> readLastKnown() async =>
      access == LocationAccess.granted ? fix : null;
}
