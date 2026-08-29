/// Where a victim is in the response, independent of how badly they are hurt.
///
/// Triage says how urgent; status says what has happened so far. They move
/// independently: a CRITICAL victim can be EVACUATED, and a STABLE one can
/// still be awaiting transport.
enum VictimStatus {
  registered('REGISTERED', 'Registered'),
  underTreatment('UNDER_TREATMENT', 'Under treatment'),
  awaitingEvacuation('AWAITING_EVACUATION', 'Awaiting evacuation'),
  evacuated('EVACUATED', 'Evacuated'),
  deceased('DECEASED', 'Deceased');

  const VictimStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  /// True once the responder has no further action for this record.
  ///
  /// Closed records sort below open ones so a full sector list still opens on
  /// the people who still need something.
  bool get isClosed =>
      this == VictimStatus.evacuated || this == VictimStatus.deceased;

  static VictimStatus? tryFromWire(String? value) {
    if (value == null) return null;
    for (final status in values) {
      if (status.wireValue == value) return status;
    }
    return null;
  }
}
