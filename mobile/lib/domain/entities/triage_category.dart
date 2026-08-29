/// Triage categories a responder assigns in the field.
///
/// This is a coordination prototype, not a clinical decision system: the
/// category is what the responder judged, and the app records it faithfully.
/// It never infers, overrides or second-guesses that judgement.
enum TriageCategory {
  critical(
    'CRITICAL',
    'Critical',
    1,
    'Immediate. Life threatening; treat and evacuate first.',
  ),
  urgent(
    'URGENT',
    'Urgent',
    2,
    'Serious injury that can tolerate a short delay.',
  ),
  moderate(
    'MODERATE',
    'Moderate',
    3,
    'Walking wounded. Treatment can be delayed.',
  ),
  stable(
    'STABLE',
    'Stable',
    4,
    'No immediate intervention required.',
  );

  const TriageCategory(
    this.wireValue,
    this.label,
    this.priority,
    this.guidance,
  );

  /// Contract with the backend. Not to be renamed casually.
  final String wireValue;

  final String label;

  /// Lower sorts first. Persisted alongside the category so ordering a victim
  /// list is a database concern rather than something every screen re-derives.
  final int priority;

  final String guidance;

  static TriageCategory? tryFromWire(String? value) {
    if (value == null) return null;
    for (final category in values) {
      if (category.wireValue == value) return category;
    }
    return null;
  }

  /// Categories in the order a responder should scan them.
  static List<TriageCategory> get byUrgency =>
      List<TriageCategory>.unmodifiable(values);
}
