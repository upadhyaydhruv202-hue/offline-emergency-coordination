/// Where an incident is in its lifecycle.
enum IncidentStatus {
  active('ACTIVE', 'Active'),
  paused('PAUSED', 'Paused'),
  resolved('RESOLVED', 'Resolved');

  const IncidentStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  /// Only an active incident may be adopted as the device's current operation.
  ///
  /// A paused or resolved incident stays readable — the records scoped to it
  /// do not disappear — but selecting one as the working context would let a
  /// responder file new casualties against a response that has stood down.
  bool get isSelectable => this == IncidentStatus.active;

  static IncidentStatus? tryFromWire(String? value) {
    if (value == null) return null;
    for (final status in values) {
      if (status.wireValue == value) return status;
    }
    return null;
  }
}
