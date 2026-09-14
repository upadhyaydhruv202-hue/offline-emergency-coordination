/// What the responder holding this device is currently doing.
///
/// This is the single most useful thing a commander can know about a team, and
/// the only person who can answer it truthfully is the responder. It is
/// therefore set by hand and stored locally — never inferred from position,
/// task state or connectivity.
enum ResponderStatus {
  available('AVAILABLE', 'Available', 'Ready to be tasked.'),
  enRoute('EN_ROUTE', 'En route', 'Moving to an assignment.'),
  onMission('ON_MISSION', 'On mission', 'Working an assignment now.'),
  needsAssistance(
    'NEEDS_ASSISTANCE',
    'Needs assistance',
    'This team cannot complete the task alone.',
  ),
  offDuty('OFF_DUTY', 'Off duty', 'Stood down; do not task.');

  const ResponderStatus(this.wireValue, this.label, this.guidance);

  final String wireValue;
  final String label;
  final String guidance;

  /// The status a device assumes before the responder has said otherwise.
  static const ResponderStatus initial = ResponderStatus.available;

  /// True when the status is itself a call for help, and so must be rendered
  /// with the same weight as a critical record.
  bool get isEscalation => this == ResponderStatus.needsAssistance;

  bool get isOnDuty => this != ResponderStatus.offDuty;

  static ResponderStatus? tryFromWire(String? value) {
    if (value == null) return null;
    for (final status in values) {
      if (status.wireValue == value) return status;
    }
    return null;
  }
}
