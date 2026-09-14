/// Where a [SyncOperation] sits in the outbound (and inbound) queue.
enum SyncOperationStatus {
  pending('PENDING'),
  inFlight('IN_FLIGHT'),
  acknowledged('ACKNOWLEDGED'),
  failed('FAILED'),
  conflict('CONFLICT');

  const SyncOperationStatus(this.wireValue);

  final String wireValue;

  static SyncOperationStatus? tryFromWire(String? value) {
    if (value == null) return null;
    for (final status in values) {
      if (status.wireValue == value) return status;
    }
    return null;
  }
}
