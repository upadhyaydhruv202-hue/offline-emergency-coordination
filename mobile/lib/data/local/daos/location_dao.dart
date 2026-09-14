import 'package:drift/drift.dart';

import '../../../domain/entities/location_record.dart';
import '../../../domain/entities/sync_status.dart';
import '../app_database.dart';

/// Every statement that touches the `locations` table.
///
/// There is no update and no delete: a position reading is an observation, and
/// the only honest operations on one are "write it down" and "read it back".
class LocationDao {
  const LocationDao(this._db);

  final AppDatabase _db;

  Future<void> insertLocation(LocationRecord record) =>
      _db.into(_db.locations).insert(_toCompanion(record));

  /// The most recent reading for [responderId], or null if none was ever taken.
  Stream<LocationRecord?> watchLatestFor(String responderId) =>
      (_db.select(_db.locations)
            ..where((row) => row.responderId.equals(responderId))
            ..orderBy([(row) => OrderingTerm.desc(row.timestamp)])
            ..limit(1))
          .watchSingleOrNull()
          .map((row) => row == null ? null : _toRecord(row));

  Future<LocationRecord?> readLatestFor(String responderId) async {
    final row = await (_db.select(_db.locations)
          ..where((location) => location.responderId.equals(responderId))
          ..orderBy([(location) => OrderingTerm.desc(location.timestamp)])
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _toRecord(row);
  }

  /// The trail for [responderId], most recent first.
  Future<List<LocationRecord>> readHistoryFor(
    String responderId, {
    int limit = 50,
  }) async {
    final rows = await (_db.select(_db.locations)
          ..where((location) => location.responderId.equals(responderId))
          ..orderBy([(location) => OrderingTerm.desc(location.timestamp)])
          ..limit(limit))
        .get();
    return rows.map(_toRecord).toList(growable: false);
  }

  Future<int> countAll() async {
    final count = _db.locations.id.count();
    final query = _db.selectOnly(_db.locations)..addColumns([count]);
    return (await query.getSingle()).read(count) ?? 0;
  }

  Stream<int> watchPendingCount() {
    final syncStatus = _db.locations.syncStatus;
    final count = _db.locations.id.count(
      filter: syncStatus.equalsValue(SyncStatus.pending) |
          syncStatus.equalsValue(SyncStatus.sent),
    );
    final query = _db.selectOnly(_db.locations)..addColumns([count]);
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  static LocationRecord _toRecord(LocationRow row) => LocationRecord(
        id: row.id,
        responderId: row.responderId,
        incidentId: row.incidentId,
        latitude: row.latitude,
        longitude: row.longitude,
        accuracy: row.accuracy,
        timestamp: row.timestamp,
        createdAt: row.createdAt,
        syncStatus: row.syncStatus,
        source: row.provider,
        isMocked: row.isMocked,
      );

  static LocationsCompanion _toCompanion(LocationRecord record) =>
      LocationsCompanion.insert(
        id: record.id,
        responderId: record.responderId,
        incidentId: Value(record.incidentId),
        latitude: record.latitude,
        longitude: record.longitude,
        accuracy: Value(record.accuracy),
        timestamp: record.timestamp,
        createdAt: record.createdAt,
        syncStatus: record.syncStatus,
        provider: Value(record.source),
        isMocked: Value(record.isMocked),
      );
}
