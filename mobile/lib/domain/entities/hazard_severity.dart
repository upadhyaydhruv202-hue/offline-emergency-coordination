/// How dangerous a hazard is to anyone approaching it.
///
/// Declared worst-first so `values` is already the order a responder should
/// scan, and so [priority] can be read straight off the position.
enum HazardSeverity {
  critical('CRITICAL', 'Critical', 1, 'Do not approach without equipment.'),
  high('HIGH', 'High', 2, 'Serious risk; brief every team entering.'),
  medium('MEDIUM', 'Medium', 3, 'Hazardous but passable with care.'),
  low('LOW', 'Low', 4, 'Noted for awareness.');

  const HazardSeverity(
    this.wireValue,
    this.label,
    this.priority,
    this.guidance,
  );

  final String wireValue;
  final String label;

  /// Lower sorts first. Persisted alongside the severity so "critical first" is
  /// an index-backed ORDER BY rather than a sort in the widget layer.
  final int priority;

  final String guidance;

  static HazardSeverity? tryFromWire(String? value) {
    if (value == null) return null;
    for (final severity in values) {
      if (severity.wireValue == value) return severity;
    }
    return null;
  }

  static List<HazardSeverity> get bySeverity =>
      List<HazardSeverity>.unmodifiable(values);
}
