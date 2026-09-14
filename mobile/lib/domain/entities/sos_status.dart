/// What has happened to a distress call since it was raised.
///
/// In this slice only the raising device can move it: there is no transport, so
/// [acknowledged] is set by a responder who was told over the radio that it was
/// heard. Recording that is honest; inventing a remote acknowledgement would
/// not be.
enum SosStatus {
  created('CREATED', 'Created'),
  acknowledged('ACKNOWLEDGED', 'Acknowledged'),
  resolved('RESOLVED', 'Resolved');

  const SosStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  bool get isOpen => this != SosStatus.resolved;

  static SosStatus? tryFromWire(String? value) {
    if (value == null) return null;
    for (final status in values) {
      if (status.wireValue == value) return status;
    }
    return null;
  }
}
