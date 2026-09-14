import 'package:drift/drift.dart';

import '../../../domain/entities/audit_event.dart';
import '../../../domain/entities/sync_status.dart';

/// Append-only trail of the operational decisions taken on this device.
///
/// Written on the same transaction as the change it describes, so the trail
/// cannot claim something the database does not hold. No signing and no hash
/// chain: tamper-evidence is a hardening-slice concern, and pretending
/// otherwise would overstate what this build guarantees.
@DataClassName('AuditEventRow')
class AuditEvents extends Table {
  TextColumn get id => text()();

  TextColumn get eventType => textEnum<AuditEventType>()();

  TextColumn get entityType => textEnum<AuditEntityType>()();

  TextColumn get entityId => text().withLength(min: 1, max: 64)();

  /// Session id of the responder who took the action.
  TextColumn get actorId => text().withLength(min: 1, max: 128)();

  DateTimeColumn get timestamp => dateTime()();

  TextColumn get metadata => text().withLength(max: 1000).nullable()();

  TextColumn get syncStatus => textEnum<SyncStatus>()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
