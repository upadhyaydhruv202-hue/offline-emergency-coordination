/// Whether the device's primary datastore is usable.
enum LocalDatabaseState {
  initialising('INITIALISING'),
  ready('READY'),
  failed('FAILED');

  const LocalDatabaseState(this.label);

  final String label;
}

/// Snapshot of the local datastore, surfaced on the responder home screen.
///
/// A field responder needs to know this before they start recording anything:
/// if the local database is not ready, nothing they capture will survive.
class LocalDatabaseHealth {
  const LocalDatabaseHealth({
    required this.state,
    required this.schemaVersion,
    required this.tables,
    this.deviceId,
    this.detail,
  });

  const LocalDatabaseHealth.failed(String this.detail)
      : state = LocalDatabaseState.failed,
        schemaVersion = 0,
        tables = const <String>[],
        deviceId = null;

  final LocalDatabaseState state;
  final int schemaVersion;
  final List<String> tables;
  final String? deviceId;
  final String? detail;

  bool get isReady => state == LocalDatabaseState.ready;
}
