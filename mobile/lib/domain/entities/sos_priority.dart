/// How hard a distress call is pressing.
///
/// Three levels rather than four: an SOS is already an escalation, and asking
/// someone who is in trouble to choose between four shades of urgency is a
/// design failure.
enum SosPriority {
  critical('CRITICAL', 'Critical', 1, 'Life at immediate risk.'),
  high('HIGH', 'High', 2, 'Serious, cannot be resolved by this team alone.'),
  medium('MEDIUM', 'Medium', 3, 'Assistance needed, situation contained.');

  const SosPriority(this.wireValue, this.label, this.priority, this.guidance);

  final String wireValue;
  final String label;

  /// Lower sorts first. Persisted alongside the priority so ordering the
  /// history is a database concern rather than something each screen redoes.
  final int priority;

  final String guidance;

  static SosPriority? tryFromWire(String? value) {
    if (value == null) return null;
    for (final item in values) {
      if (item.wireValue == value) return item;
    }
    return null;
  }

  static List<SosPriority> get byUrgency =>
      List<SosPriority>.unmodifiable(values);
}
