import 'package:drift/drift.dart';

import '../../../domain/entities/responder_role.dart';

/// The signed-in responder, persisted locally.
///
/// This is what makes the device usable after a restart with no network: the
/// session is read from SQLite, not fetched from the backend.
@DataClassName('LocalSession')
class LocalSessions extends Table {
  /// Backend user id, or a locally generated id for an offline demo session.
  TextColumn get id => text()();

  TextColumn get email => text().withLength(min: 1, max: 320)();

  TextColumn get fullName => text().withLength(min: 1, max: 160)();

  TextColumn get role => textEnum<ResponderRole>()();

  /// True when the session was never authenticated against the backend.
  BoolColumn get isOfflineDemo =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get signedInAt =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get lastSeenAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
