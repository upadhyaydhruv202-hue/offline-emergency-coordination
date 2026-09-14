import '../../../data/local/daos/responder_status_dao.dart';
import '../../../domain/entities/responder_status.dart';
import '../../../domain/entities/responder_status_record.dart';
import '../../../domain/entities/sync_status.dart';

/// How the responder's operational status is read and changed.
///
/// A device that has never been told otherwise reports
/// [ResponderStatus.initial] rather than nothing: "unknown" is not a state a
/// commander can act on, and a responder who has signed in and not said
/// otherwise is available.
class ResponderStatusRepository {
  const ResponderStatusRepository(this.statuses);

  final ResponderStatusDao statuses;

  Stream<ResponderStatus> watchStatus(String responderId) => statuses
      .watchFor(responderId)
      .map((record) => record?.status ?? ResponderStatus.initial);

  Stream<ResponderStatusRecord?> watchRecord(String responderId) =>
      statuses.watchFor(responderId);

  Future<ResponderStatus> readStatus(String responderId) async =>
      (await statuses.readFor(responderId))?.status ?? ResponderStatus.initial;

  Future<ResponderStatusRecord?> readRecord(String responderId) =>
      statuses.readFor(responderId);

  Future<ResponderStatusRecord> setStatus({
    required String responderId,
    required ResponderStatus status,
    String? incidentId,
    String? note,
    DateTime? now,
  }) async {
    final record = ResponderStatusRecord(
      responderId: responderId,
      status: status,
      incidentId: incidentId,
      note: _clean(note),
      updatedAt: (now ?? DateTime.now()).toUtc(),
      syncStatus: SyncStatus.pending,
    );

    await statuses.save(record);
    return record;
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
