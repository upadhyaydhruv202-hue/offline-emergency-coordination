import 'package:drift/drift.dart';

import '../../../domain/entities/responder_status.dart';
import '../../../domain/entities/sync_status.dart';

/// Operational status, one row per responder.
///
/// The class is plural to match the rest of the schema; the table it creates is
/// `responder_status`, singular, because it holds one current state per
/// responder rather than a history.
@DataClassName('ResponderStatusRow')
class ResponderStatuses extends Table {
  @override
  String get tableName => 'responder_status';

  TextColumn get responderId => text().withLength(min: 1, max: 128)();

  TextColumn get status => textEnum<ResponderStatus>()();

  TextColumn get incidentId => text().withLength(max: 64).nullable()();

  TextColumn get note => text().withLength(max: 300).nullable()();

  DateTimeColumn get updatedAt => dateTime()();

  TextColumn get syncStatus => textEnum<SyncStatus>()();

  @override
  Set<Column<Object>> get primaryKey => {responderId};
}
