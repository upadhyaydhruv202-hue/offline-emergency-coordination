/// Whether a locally authored record has reached the coordination backend.
///
/// Slices 2 and 3 only ever write [pending]: there is no synchronisation yet,
/// and pretending otherwise would misrepresent the state of the response. The
/// field exists now because the responder has to be able to see, at a glance,
/// that what they captured is held on this device alone.
///
/// The four operational values are [localOnly], [pending], [sent] and
/// [acknowledged]. [synced] predates them and is retained so a device carrying
/// records written by an earlier build still reads them back.
enum SyncStatus {
  /// Deliberately never leaving this device.
  localOnly('LOCAL_ONLY', 'Local only'),

  /// Queued for the synchronisation layer that Slice 4 delivers.
  pending('PENDING', 'Sync pending'),

  /// Handed to a transport, outcome unknown.
  sent('SENT', 'Sent'),

  /// A peer confirmed receipt.
  acknowledged('ACKNOWLEDGED', 'Acknowledged'),

  /// Legacy spelling of [acknowledged], written by Slice 2 builds.
  synced('SYNCED', 'Synced');

  const SyncStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  /// True once a peer has confirmed it holds the record.
  ///
  /// Everything else counts as an outstanding change, which is what the
  /// "N CHANGES PENDING" indicator reports.
  bool get isConfirmed =>
      this == SyncStatus.acknowledged || this == SyncStatus.synced;

  /// Records the responder should understand as still held on this device only.
  bool get isOutstanding => !isConfirmed && this != SyncStatus.localOnly;

  static SyncStatus? tryFromWire(String? value) {
    if (value == null) return null;
    for (final status in values) {
      if (status.wireValue == value) return status;
    }
    return null;
  }
}
