import '../../../core/utils/identifiers.dart';
import '../../../data/local/daos/location_dao.dart';
import '../../../domain/entities/location_fix.dart';
import '../../../domain/entities/location_record.dart';
import '../../../domain/entities/sync_status.dart';
import 'location_service.dart';

/// Captures a position and writes it down.
///
/// The service reads the receiver; this decides what is kept. Splitting them is
/// what lets a screen ask for "the current position, recorded against the
/// current incident" without knowing anything about permissions, and lets a
/// test exercise persistence without a platform channel.
class LocationRepository {
  const LocationRepository({required this.locations, required this.service});

  final LocationDao locations;
  final LocationService service;

  Stream<LocationRecord?> watchLatestFor(String responderId) =>
      locations.watchLatestFor(responderId);

  Future<LocationRecord?> readLatestFor(String responderId) =>
      locations.readLatestFor(responderId);

  Future<List<LocationRecord>> readHistoryFor(
    String responderId, {
    int limit = 50,
  }) =>
      locations.readHistoryFor(responderId, limit: limit);

  /// Takes a reading and stores it.
  ///
  /// Throws [LocationUnavailableException] when the device cannot produce a
  /// fix. Nothing is written in that case: an invented position is far worse
  /// than none, because somebody would go to it.
  Future<LocationRecord> capture({
    required String responderId,
    String? incidentId,
    DateTime? now,
  }) async {
    final fix = await service.currentFix();
    return store(
      fix: fix,
      responderId: responderId,
      incidentId: incidentId,
      now: now,
    );
  }

  /// Persists a fix that has already been read.
  ///
  /// Separate from [capture] so a form that captured a position while the
  /// responder was filling it in can commit that exact reading, rather than
  /// taking a second one from a different doorway.
  Future<LocationRecord> store({
    required LocationFix fix,
    required String responderId,
    String? incidentId,
    DateTime? now,
  }) async {
    final record = LocationRecord(
      id: generateUuidV4(),
      responderId: responderId,
      incidentId: incidentId,
      latitude: fix.latitude,
      longitude: fix.longitude,
      accuracy: fix.accuracy,
      timestamp: fix.timestamp,
      createdAt: (now ?? DateTime.now()).toUtc(),
      syncStatus: SyncStatus.pending,
      source: fix.source,
      isMocked: fix.isMocked,
    );

    await locations.insertLocation(record);
    return record;
  }
}
