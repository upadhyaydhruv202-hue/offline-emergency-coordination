import 'conflict_resolution.dart';
import 'sync_entity_type.dart';
import 'sync_operation.dart';
import 'sync_status.dart';

/// A recorded disagreement about one entity, even when it was auto-resolved.
class SyncConflict {
  const SyncConflict({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operationA,
    required this.operationB,
    required this.detectedAt,
    required this.resolution,
    required this.winnerOperation,
    required this.loserOperation,
    required this.reason,
    this.resolvedAt,
    this.syncStatus = SyncStatus.pending,
  });

  final String id;
  final SyncEntityType entityType;
  final String entityId;
  final SyncOperation operationA;
  final SyncOperation operationB;
  final DateTime detectedAt;
  final ConflictResolution resolution;
  final SyncOperation winnerOperation;
  final SyncOperation loserOperation;
  final String reason;
  final DateTime? resolvedAt;
  final SyncStatus syncStatus;
}
