/// How urgently a task needs starting.
///
/// Declared worst-first so `values` is already the order the list is drawn in.
enum TaskPriority {
  critical('CRITICAL', 'Critical', 1),
  high('HIGH', 'High', 2),
  medium('MEDIUM', 'Medium', 3),
  low('LOW', 'Low', 4);

  const TaskPriority(this.wireValue, this.label, this.rank);

  final String wireValue;
  final String label;

  /// Lower sorts first. Persisted so the task list is ordered by the database.
  final int rank;

  static TaskPriority? tryFromWire(String? value) {
    if (value == null) return null;
    for (final priority in values) {
      if (priority.wireValue == value) return priority;
    }
    return null;
  }

  static List<TaskPriority> get byUrgency =>
      List<TaskPriority>.unmodifiable(values);
}
