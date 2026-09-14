import 'responder_status.dart';
import 'sync_status.dart';

/// The persisted operational status of one responder on this device.
///
/// One row per responder rather than an append-only log: the current status is
/// what a commander acts on, and a history of it is only worth keeping once
/// there is a synchronisation layer to merge two devices' versions of it.
class ResponderStatusRecord {
  const ResponderStatusRecord({
    required this.responderId,
    required this.status,
    required this.updatedAt,
    required this.syncStatus,
    this.incidentId,
    this.note,
  });

  final String responderId;
  final ResponderStatus status;

  /// The incident the status was set against, when one had been adopted.
  final String? incidentId;

  final String? note;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  ResponderStatusRecord copyWith({
    ResponderStatus? status,
    String? incidentId,
    bool clearIncidentId = false,
    String? note,
    bool clearNote = false,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) =>
      ResponderStatusRecord(
        responderId: responderId,
        status: status ?? this.status,
        incidentId: clearIncidentId ? null : (incidentId ?? this.incidentId),
        note: clearNote ? null : (note ?? this.note),
        updatedAt: updatedAt ?? this.updatedAt,
        syncStatus: syncStatus ?? this.syncStatus,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResponderStatusRecord &&
          other.responderId == responderId &&
          other.status == status &&
          other.incidentId == incidentId &&
          other.note == note &&
          other.updatedAt == updatedAt &&
          other.syncStatus == syncStatus;

  @override
  int get hashCode => Object.hash(
        responderId,
        status,
        incidentId,
        note,
        updatedAt,
        syncStatus,
      );
}
