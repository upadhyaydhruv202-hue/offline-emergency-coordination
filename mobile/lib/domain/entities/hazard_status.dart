/// Whether a reported hazard has been confirmed or cleared.
enum HazardStatus {
  reported('REPORTED', 'Reported'),
  verified('VERIFIED', 'Verified'),
  resolved('RESOLVED', 'Resolved');

  const HazardStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  /// True once the hazard no longer constrains movement.
  bool get isClosed => this == HazardStatus.resolved;

  static HazardStatus? tryFromWire(String? value) {
    if (value == null) return null;
    for (final status in values) {
      if (status.wireValue == value) return status;
    }
    return null;
  }
}
