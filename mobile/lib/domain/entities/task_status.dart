/// The lifecycle of a task on the responder's own device.
///
/// The transitions are deliberately linear and few. A responder accepts work,
/// starts it, and finishes or abandons it; anything richer belongs to a
/// coordination engine this slice does not have.
enum TaskStatus {
  pending('PENDING', 'Pending'),
  accepted('ACCEPTED', 'Accepted'),
  inProgress('IN_PROGRESS', 'In progress'),
  completed('COMPLETED', 'Completed'),
  cancelled('CANCELLED', 'Cancelled');

  const TaskStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  /// True once the responder has no further action.
  ///
  /// Closed tasks sort below open ones so a long list still opens on the work
  /// that is outstanding.
  bool get isClosed =>
      this == TaskStatus.completed || this == TaskStatus.cancelled;

  /// True while the responder is actively holding the task.
  bool get isActive =>
      this == TaskStatus.accepted || this == TaskStatus.inProgress;

  /// The single next step offered as a one-tap action, or null when the task is
  /// finished. Keeping this here rather than in the widget means the screen
  /// cannot offer a transition the domain does not allow.
  TaskStatus? get next => switch (this) {
        TaskStatus.pending => TaskStatus.accepted,
        TaskStatus.accepted => TaskStatus.inProgress,
        TaskStatus.inProgress => TaskStatus.completed,
        TaskStatus.completed => null,
        TaskStatus.cancelled => null,
      };

  /// Label for the button that performs [next].
  String? get nextActionLabel => switch (this) {
        TaskStatus.pending => 'Accept Task',
        TaskStatus.accepted => 'Start Task',
        TaskStatus.inProgress => 'Complete Task',
        TaskStatus.completed => null,
        TaskStatus.cancelled => null,
      };

  static TaskStatus? tryFromWire(String? value) {
    if (value == null) return null;
    for (final status in values) {
      if (status.wireValue == value) return status;
    }
    return null;
  }
}
