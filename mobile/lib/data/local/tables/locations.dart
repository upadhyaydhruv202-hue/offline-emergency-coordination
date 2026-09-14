import 'package:drift/drift.dart';

import '../../../domain/entities/sync_status.dart';

/// Position readings captured on this device.
///
/// Append-only: a fix is an observation, and correcting one after the fact
/// would destroy the only evidence of where a responder actually was.
///
/// [incidentId] is a plain nullable identifier rather than a foreign key. A
/// reading taken before any incident was declared is still worth keeping, and a
/// device must never be prevented from writing what its receiver reported
/// because a related row has not arrived yet.
@DataClassName('LocationRow')
class Locations extends Table {
  TextColumn get id => text()();

  /// Session id of the responder the reading belongs to.
  TextColumn get responderId => text().withLength(min: 1, max: 128)();

  TextColumn get incidentId => text().withLength(max: 64).nullable()();

  RealColumn get latitude => real()();

  RealColumn get longitude => real()();

  /// Radius of 68% confidence in metres, when the platform estimates one.
  RealColumn get accuracy => real().nullable()();

  /// Platform provider (`gps`, `fused`, `network`, `mock`, `unknown`).
  TextColumn get provider => text().withDefault(const Constant('unknown'))();

  BoolColumn get isMocked =>
      boolean().withDefault(const Constant(false))();

  /// When the receiver produced the reading.
  DateTimeColumn get timestamp => dateTime()();

  /// When this device wrote it down.
  DateTimeColumn get createdAt => dateTime()();

  TextColumn get syncStatus => textEnum<SyncStatus>()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
