/// Whether a locally authored record has reached the coordination backend.
///
/// Slice 2 only ever writes [pending]: there is no synchronisation yet, and
/// pretending otherwise would misrepresent the state of the response. The
/// field exists now because the responder has to be able to see, at a glance,
/// that what they captured is held on this device alone.
enum SyncStatus {
  pending('PENDING', 'Sync pending'),
  synced('SYNCED', 'Synced');

  const SyncStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static SyncStatus? tryFromWire(String? value) {
    if (value == null) return null;
    for (final status in values) {
      if (status.wireValue == value) return status;
    }
    return null;
  }
}
