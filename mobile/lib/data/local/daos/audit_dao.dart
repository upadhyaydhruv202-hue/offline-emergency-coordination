import 'package:drift/drift.dart';

import '../../../domain/entities/audit_event.dart';
import '../app_database.dart';

/// Every statement that touches the `audit_events` table.
///
/// Insert and read only. An audit trail that can be edited is not one.
class AuditDao {
  const AuditDao(this._db);

  final AppDatabase _db;

  Future<void> insertEvent(AuditEvent event) =>
      _db.into(_db.auditEvents).insert(_toCompanion(event));

  /// The trail, most recent first.
  Future<List<AuditEvent>> readRecent({int limit = 100}) async {
    final rows = await (_db.select(_db.auditEvents)
          ..orderBy([(event) => OrderingTerm.desc(event.timestamp)])
          ..limit(limit))
        .get();
    return rows.map(_toEvent).toList(growable: false);
  }

  Stream<List<AuditEvent>> watchRecent({int limit = 100}) =>
      (_db.select(_db.auditEvents)
            ..orderBy([(event) => OrderingTerm.desc(event.timestamp)])
            ..limit(limit))
          .watch()
          .map((rows) => rows.map(_toEvent).toList(growable: false));

  /// Everything recorded against one record, oldest first, which is the order
  /// somebody reconstructing what happened needs to read it in.
  Future<List<AuditEvent>> readForEntity(String entityId) async {
    final rows = await (_db.select(_db.auditEvents)
          ..where((event) => event.entityId.equals(entityId))
          ..orderBy([(event) => OrderingTerm.asc(event.timestamp)]))
        .get();
    return rows.map(_toEvent).toList(growable: false);
  }

  Future<int> countAll() async {
    final count = _db.auditEvents.id.count();
    final query = _db.selectOnly(_db.auditEvents)..addColumns([count]);
    return (await query.getSingle()).read(count) ?? 0;
  }

  static AuditEvent _toEvent(AuditEventRow row) => AuditEvent(
        id: row.id,
        eventType: row.eventType,
        entityType: row.entityType,
        entityId: row.entityId,
        actorId: row.actorId,
        timestamp: row.timestamp,
        metadata: row.metadata,
        syncStatus: row.syncStatus,
      );

  static AuditEventsCompanion _toCompanion(AuditEvent event) =>
      AuditEventsCompanion.insert(
        id: event.id,
        eventType: event.eventType,
        entityType: event.entityType,
        entityId: event.entityId,
        actorId: event.actorId,
        timestamp: event.timestamp,
        metadata: Value(event.metadata),
        syncStatus: event.syncStatus,
      );
}
