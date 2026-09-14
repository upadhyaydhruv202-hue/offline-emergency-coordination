import 'package:drift/drift.dart';

import '../../../domain/entities/incident.dart';
import '../../../domain/entities/incident_status.dart';
import '../../../domain/entities/sync_status.dart';
import '../app_database.dart';

/// Every statement that touches the `incidents` table.
///
/// Screens and controllers call this; none of them build SQL. That boundary is
/// what will let the synchronisation slice write to the same table without any
/// widget changing.
class IncidentDao {
  const IncidentDao(this._db);

  final AppDatabase _db;

  /// Live incident list, ordered the way a responder scans it: the responses
  /// still running first, most recently declared first within that.
  Stream<List<Incident>> watchIncidents() => _ordered().watch().map(_toList);

  Future<List<Incident>> readIncidents() async => _toList(await _ordered().get());

  Stream<Incident?> watchIncident(String id) =>
      (_db.select(_db.incidents)..where((row) => row.id.equals(id)))
          .watchSingleOrNull()
          .map((row) => row == null ? null : _toIncident(row));

  Future<Incident?> readIncident(String id) async {
    final row = await (_db.select(_db.incidents)
          ..where((incident) => incident.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toIncident(row);
  }

  Future<Incident?> readByCode(String incidentCode) async {
    final row = await (_db.select(_db.incidents)
          ..where((incident) => incident.incidentCode.equals(incidentCode)))
        .getSingleOrNull();
    return row == null ? null : _toIncident(row);
  }

  Future<void> insertIncident(Incident incident) =>
      _db.into(_db.incidents).insert(_toCompanion(incident));

  Future<void> updateIncident(Incident incident) async {
    await _db.update(_db.incidents).replace(_toCompanion(incident));
  }

  Future<int> countAll() async {
    final count = _db.incidents.id.count();
    final query = _db.selectOnly(_db.incidents)..addColumns([count]);
    return (await query.getSingle()).read(count) ?? 0;
  }

  /// Live count of incidents this device has authored or changed and not yet
  /// handed to a peer.
  Stream<int> watchPendingCount() {
    final count = _db.incidents.id.count(filter: _outstanding());
    final query = _db.selectOnly(_db.incidents)..addColumns([count]);
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  SimpleSelectStatement<$IncidentsTable, IncidentRow> _ordered() {
    final select = _db.select(_db.incidents);
    select.orderBy([
      // false (0) before true (1): running responses above stood-down ones.
      (_) => OrderingTerm.asc(_isClosed()),
      (incident) => OrderingTerm.desc(incident.createdAt),
    ]);
    return select;
  }

  Expression<bool> _isClosed() =>
      _db.incidents.status.equalsValue(IncidentStatus.resolved);

  Expression<bool> _outstanding() {
    final syncStatus = _db.incidents.syncStatus;
    return syncStatus.equalsValue(SyncStatus.pending) |
        syncStatus.equalsValue(SyncStatus.sent);
  }

  static List<Incident> _toList(List<IncidentRow> rows) =>
      rows.map(_toIncident).toList(growable: false);

  static Incident _toIncident(IncidentRow row) => Incident(
        id: row.id,
        incidentCode: row.incidentCode,
        title: row.title,
        disasterType: row.disasterType,
        description: row.description,
        status: row.status,
        assignedZone: row.assignedZone,
        latitude: row.latitude,
        longitude: row.longitude,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        createdBy: row.createdBy,
        lastModifiedBy: row.lastModifiedBy,
        syncStatus: row.syncStatus,
      );

  static IncidentsCompanion _toCompanion(Incident incident) =>
      IncidentsCompanion.insert(
        id: incident.id,
        incidentCode: incident.incidentCode,
        title: incident.title,
        disasterType: incident.disasterType,
        description: Value(incident.description),
        status: incident.status,
        assignedZone: Value(incident.assignedZone),
        latitude: Value(incident.latitude),
        longitude: Value(incident.longitude),
        createdAt: incident.createdAt,
        updatedAt: incident.updatedAt,
        createdBy: incident.createdBy,
        lastModifiedBy: Value(incident.lastModifiedBy),
        syncStatus: incident.syncStatus,
      );
}
