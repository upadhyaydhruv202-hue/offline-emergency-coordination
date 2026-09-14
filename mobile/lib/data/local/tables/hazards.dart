import 'package:drift/drift.dart';

import '../../../domain/entities/hazard_severity.dart';
import '../../../domain/entities/hazard_status.dart';
import '../../../domain/entities/hazard_type.dart';
import '../../../domain/entities/sync_status.dart';

/// Hazards observed by this device's responder.
@DataClassName('HazardRow')
class Hazards extends Table {
  TextColumn get id => text()();

  /// Short label for the radio. Unique on this device.
  TextColumn get hazardCode => text().withLength(min: 3, max: 32).unique()();

  TextColumn get incidentId => text().withLength(max: 64).nullable()();

  /// Session id of the responder who observed it.
  TextColumn get reportedBy => text().withLength(min: 1, max: 128)();

  TextColumn get type => textEnum<HazardType>()();

  TextColumn get severity => textEnum<HazardSeverity>()();

  /// Denormalised from [severity] so "critical first" is an index-backed
  /// ORDER BY rather than a sort in the widget layer.
  IntColumn get priority => integer()();

  TextColumn get description => text().withLength(max: 1000).nullable()();

  RealColumn get latitude => real().nullable()();

  RealColumn get longitude => real().nullable()();

  RealColumn get accuracy => real().nullable()();

  /// When the responder observed it.
  DateTimeColumn get observedAt => dateTime()();

  TextColumn get status => textEnum<HazardStatus>()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  TextColumn get syncStatus => textEnum<SyncStatus>()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
