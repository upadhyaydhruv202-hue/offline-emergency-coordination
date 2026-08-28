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
}
