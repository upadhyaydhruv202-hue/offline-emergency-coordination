import 'package:drift/drift.dart';

import '../../../domain/entities/disaster_type.dart';
import '../../../domain/entities/incident_status.dart';
import '../../../domain/entities/sync_status.dart';

/// Incidents this device knows about.
///
/// Declared on the device, so the id is a device-minted UUID and no column is
/// ever filled in by a backend response. Which of these rows is the responder's
/// current operation is not a column here — it is a single key in
/// `app_metadata`, because "current" is a property of the device, not of the
/// incident.
@DataClassName('IncidentRow')
class Incidents extends Table {
  TextColumn get id => text()();

  /// Short label a commander says out loud. Unique on this device.
  TextColumn get incidentCode => text().withLength(min: 3, max: 32).unique()();

  TextColumn get title => text().withLength(min: 1, max: 200)();

  TextColumn get disasterType => textEnum<DisasterType>()();

  TextColumn get description => text().withLength(max: 2000).nullable()();

  TextColumn get status => textEnum<IncidentStatus>()();

  /// The sector this device is working within the incident.
  TextColumn get assignedZone => text().withLength(max: 120).nullable()();

  RealColumn get latitude => real().nullable()();

  RealColumn get longitude => real().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  /// Session id of the responder who declared the incident.
  TextColumn get createdBy => text().withLength(min: 1, max: 128)();

  TextColumn get lastModifiedBy =>
      text().withLength(min: 1, max: 128).nullable()();

  TextColumn get syncStatus => textEnum<SyncStatus>()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
