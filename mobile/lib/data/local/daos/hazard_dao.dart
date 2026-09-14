import 'package:drift/drift.dart';

import '../../../domain/entities/field_ops_boards.dart';
import '../../../domain/entities/hazard.dart';
import '../../../domain/entities/hazard_query.dart';
import '../../../domain/entities/hazard_severity.dart';
import '../../../domain/entities/hazard_status.dart';
import '../../../domain/entities/sync_status.dart';
import '../app_database.dart';

/// Every statement that touches the `hazards` table.
class HazardDao {
  const HazardDao(this._db);

  final AppDatabase _db;

  /// Live hazard list for [query], ordered the way a responder plans a route:
  /// hazards still standing first, most severe first within that, most recently
  /// observed first within that.
  Stream<List<Hazard>> watchHazards([
    HazardQuery query = const HazardQuery(),
  ]) =>
      _selectFor(query).watch().map(_toList);

  Future<List<Hazard>> readHazards([
    HazardQuery query = const HazardQuery(),
  ]) async =>
      _toList(await _selectFor(query).get());

  Stream<Hazard?> watchHazard(String id) =>
      (_db.select(_db.hazards)..where((row) => row.id.equals(id)))
          .watchSingleOrNull()
          .map((row) => row == null ? null : _toHazard(row));

  Future<Hazard?> readHazard(String id) async {
    final row = await (_db.select(_db.hazards)
          ..where((hazard) => hazard.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toHazard(row);
  }

  Future<Hazard?> readByCode(String hazardCode) async {
    final row = await (_db.select(_db.hazards)
          ..where((hazard) => hazard.hazardCode.equals(hazardCode)))
        .getSingleOrNull();
    return row == null ? null : _toHazard(row);
  }

  Future<void> insertHazard(Hazard hazard) =>
      _db.into(_db.hazards).insert(_toCompanion(hazard));

  Future<void> updateHazard(Hazard hazard) async {
    await _db.update(_db.hazards).replace(_toCompanion(hazard));
  }

  Future<int> countAll() async {
    final count = _db.hazards.id.count();
    final query = _db.selectOnly(_db.hazards)..addColumns([count]);
    return (await query.getSingle()).read(count) ?? 0;
  }

  /// Live counts across every hazard on the device, ignoring the active filter.
  Stream<HazardBoard> watchBoard() {
    final hazards = _db.hazards;

    final total = hazards.id.count();
    final open = hazards.id.count(filter: _isResolved().not());
    final pending = hazards.id.count(filter: _outstanding());
    final perSeverity = <HazardSeverity, Expression<int>>{
      for (final severity in HazardSeverity.values)
        severity: hazards.id.count(
          filter: hazards.severity.equalsValue(severity),
        ),
    };

    final query = _db.selectOnly(hazards)
      ..addColumns([total, open, pending, ...perSeverity.values]);

    return query.watchSingle().map(
          (row) => HazardBoard(
            total: row.read(total) ?? 0,
            open: row.read(open) ?? 0,
            pendingSync: row.read(pending) ?? 0,
            bySeverity: {
              for (final entry in perSeverity.entries)
                entry.key: row.read(entry.value) ?? 0,
            },
          ),
        );
  }

  Stream<int> watchPendingCount() {
    final count = _db.hazards.id.count(filter: _outstanding());
    final query = _db.selectOnly(_db.hazards)..addColumns([count]);
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  SimpleSelectStatement<$HazardsTable, HazardRow> _selectFor(
    HazardQuery query,
  ) {
    final select = _db.select(_db.hazards);

    final type = query.type;
    if (type != null) {
      select.where((hazard) => hazard.type.equalsValue(type));
    }

    final severity = query.severity;
    if (severity != null) {
      select.where((hazard) => hazard.severity.equalsValue(severity));
    }

    final status = query.status;
    if (status != null) {
      select.where((hazard) => hazard.status.equalsValue(status));
    }

    if (query.hasSearch) {
      final term = '%${query.normalisedSearch}%';
      select.where(
        (hazard) =>
            hazard.hazardCode.lower().like(term) |
            hazard.description.lower().like(term),
      );
    }

    select.orderBy([
      // false (0) before true (1): live hazards above cleared ones.
      (_) => OrderingTerm.asc(_isResolved()),
      (hazard) => OrderingTerm.asc(hazard.priority),
      (hazard) => OrderingTerm.desc(hazard.observedAt),
    ]);

    return select;
  }

  Expression<bool> _isResolved() =>
      _db.hazards.status.equalsValue(HazardStatus.resolved);

  Expression<bool> _outstanding() {
    final syncStatus = _db.hazards.syncStatus;
    return syncStatus.equalsValue(SyncStatus.pending) |
        syncStatus.equalsValue(SyncStatus.sent);
  }

  static List<Hazard> _toList(List<HazardRow> rows) =>
      rows.map(_toHazard).toList(growable: false);

  static Hazard _toHazard(HazardRow row) => Hazard(
        id: row.id,
        hazardCode: row.hazardCode,
        incidentId: row.incidentId,
        reportedBy: row.reportedBy,
        type: row.type,
        severity: row.severity,
        priority: row.priority,
        description: row.description,
        latitude: row.latitude,
        longitude: row.longitude,
        accuracy: row.accuracy,
        observedAt: row.observedAt,
        status: row.status,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        syncStatus: row.syncStatus,
      );

  static HazardsCompanion _toCompanion(Hazard hazard) =>
      HazardsCompanion.insert(
        id: hazard.id,
        hazardCode: hazard.hazardCode,
        incidentId: Value(hazard.incidentId),
        reportedBy: hazard.reportedBy,
        type: hazard.type,
        severity: hazard.severity,
        priority: hazard.priority,
        description: Value(hazard.description),
        latitude: Value(hazard.latitude),
        longitude: Value(hazard.longitude),
        accuracy: Value(hazard.accuracy),
        observedAt: hazard.observedAt,
        status: hazard.status,
        createdAt: hazard.createdAt,
        updatedAt: hazard.updatedAt,
        syncStatus: hazard.syncStatus,
      );
}
