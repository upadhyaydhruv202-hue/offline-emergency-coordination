import 'package:drift/drift.dart';

/// Key/value store for device-scoped facts: schema provenance, the device's
/// own identifier, the last successful synchronisation, and so on.
@DataClassName('AppMetadataEntry')
class AppMetadata extends Table {
  TextColumn get key => text().withLength(min: 1, max: 64)();

  TextColumn get value => text()();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Well-known [AppMetadata] keys.
class AppMetadataKeys {
  const AppMetadataKeys._();

  static const String deviceId = 'device.id';
  static const String schemaInitialisedAt = 'schema.initialised_at';
  static const String lastSyncAt = 'sync.last_completed_at';

  /// Counter behind the short victim identifier printed on a triage tag.
  static const String victimSequence = 'victim.sequence';

  /// Id of the incident the responder is currently operating in.
  ///
  /// "Current" is a property of the device, not of the incident, so it lives
  /// here rather than as a column on `incidents`. Storing it in the database
  /// rather than in memory is what makes the selection survive a restart.
  static const String currentIncidentId = 'incident.current_id';

  /// Counters behind the short codes printed on, and read out for, each kind
  /// of field record.
  static const String incidentSequence = 'incident.sequence';
  static const String sosSequence = 'sos.sequence';
  static const String hazardSequence = 'hazard.sequence';
  static const String taskSequence = 'task.sequence';
}
