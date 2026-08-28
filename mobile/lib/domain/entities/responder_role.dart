/// The five operational roles recognised in Slice 1.
///
/// [wireValue] is the contract with the backend and must not be renamed
/// casually; the Dart identifier is what Drift persists.
enum ResponderRole {
  rescueTeam('RESCUE_TEAM', 'Rescue Team'),
  medicalTeam('MEDICAL_TEAM', 'Medical Team'),
  volunteer('VOLUNTEER', 'Volunteer'),
  incidentCommander('INCIDENT_COMMANDER', 'Incident Commander'),
  admin('ADMIN', 'Administrator');

  const ResponderRole(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static ResponderRole? tryFromWire(String? value) {
    if (value == null) return null;
    for (final role in values) {
      if (role.wireValue == value) return role;
    }
    return null;
  }

  /// Roles that may run a response rather than execute tasks within one.
  bool get isCommand =>
      this == ResponderRole.incidentCommander || this == ResponderRole.admin;
}
