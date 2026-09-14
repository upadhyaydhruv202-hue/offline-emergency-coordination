/// Operational records the synchronisation layer is allowed to carry.
enum SyncEntityType {
  incident('INCIDENT'),
  victim('VICTIM'),
  hazard('HAZARD'),
  task('TASK'),
  sos('SOS'),
  responderStatus('RESPONDER_STATUS');

  const SyncEntityType(this.wireValue);

  final String wireValue;

  static SyncEntityType? tryFromWire(String? value) {
    if (value == null) return null;
    for (final type in values) {
      if (type.wireValue == value) return type;
    }
    return null;
  }
}
