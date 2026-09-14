import '../../../core/utils/identifiers.dart';
import '../../../data/local/daos/audit_dao.dart';
import '../../../domain/entities/audit_event.dart';
import '../../../domain/entities/sync_status.dart';

/// The device's local record of what it was asked to do.
///
/// Every write goes through here rather than through the DAO directly, so the
/// trail is produced in exactly one place and cannot acquire two different
/// notions of what an actor or a timestamp is.
///
/// Recording is deliberately **best effort**: a failure to append to the trail
/// must never take down the operational write it describes. Losing an audit row
/// is a bookkeeping problem; losing a casualty record because the audit table
/// was locked would be a catastrophic one.
class AuditRepository {
  const AuditRepository(this.events);

  final AuditDao events;

  Future<AuditEvent?> record({
    required AuditEventType eventType,
    required AuditEntityType entityType,
    required String entityId,
    required String actorId,
    Map<String, Object?> metadata = const {},
    DateTime? now,
  }) async {
    final event = AuditEvent(
      id: generateUuidV4(),
      eventType: eventType,
      entityType: entityType,
      entityId: entityId,
      actorId: actorId,
      timestamp: (now ?? DateTime.now()).toUtc(),
      metadata: formatMetadata(metadata),
      syncStatus: SyncStatus.pending,
    );

    try {
      await events.insertEvent(event);
      return event;
    } on Exception {
      return null;
    }
  }

  Future<List<AuditEvent>> readRecent({int limit = 100}) =>
      events.readRecent(limit: limit);

  Stream<List<AuditEvent>> watchRecent({int limit = 100}) =>
      events.watchRecent(limit: limit);

  Future<List<AuditEvent>> readForEntity(String entityId) =>
      events.readForEntity(entityId);

  /// Flattens detail into one string, dropping nulls so an absent value and an
  /// empty one are not two different things to read later.
  static String? formatMetadata(Map<String, Object?> metadata) {
    final parts = metadata.entries
        .where((entry) => entry.value != null)
        .map((entry) => '${entry.key}=${entry.value}')
        .toList(growable: false);
    return parts.isEmpty ? null : parts.join('; ');
  }
}
