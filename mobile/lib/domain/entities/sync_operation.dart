import 'sync_entity_type.dart';
import 'sync_operation_status.dart';
import 'sync_operation_type.dart';
import 'sync_status.dart';

/// A locally authored mutation that may later travel to a peer.
///
/// [logicalTimestamp] is a per-device monotonic counter, not a wall clock.
/// Ordering between devices is `compareOperations` in the CRDT engine: counter,
/// then device id, then operation id. Wall-clock [createdAt] is for humans.
class SyncOperation {
  const SyncOperation({
    required this.id,
    required this.operationId,
    required this.deviceId,
    required this.actorId,
    required this.entityType,
    required this.entityId,
    required this.operationType,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
    required this.queueStatus,
    required this.version,
    required this.logicalTimestamp,
    this.parentVersion,
    this.failureReason,
  });

  final String id;

  /// Immutable origin id. Duplicates of this value are the same mutation.
  final String operationId;

  final String deviceId;
  final String actorId;
  final SyncEntityType entityType;
  final String entityId;
  final SyncOperationType operationType;

  /// Snapshot of the entity after this mutation. Treated as untrusted input
  /// when it arrives from a peer.
  final Map<String, Object?> payload;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Record-level flag mirrored onto the entity this mutation produced.
  final SyncStatus syncStatus;

  final SyncOperationStatus queueStatus;

  /// Entity version after this mutation (the writer's logical counter).
  final int version;

  /// Writer's logical counter. Together with [deviceId] this is the LWW key.
  final int logicalTimestamp;

  /// Entity version the writer observed before this mutation, if any.
  final int? parentVersion;

  final String? failureReason;

  SyncOperation copyWith({
    SyncStatus? syncStatus,
    SyncOperationStatus? queueStatus,
    DateTime? updatedAt,
    String? failureReason,
    bool clearFailure = false,
  }) {
    return SyncOperation(
      id: id,
      operationId: operationId,
      deviceId: deviceId,
      actorId: actorId,
      entityType: entityType,
      entityId: entityId,
      operationType: operationType,
      payload: payload,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      queueStatus: queueStatus ?? this.queueStatus,
      version: version,
      logicalTimestamp: logicalTimestamp,
      parentVersion: parentVersion,
      failureReason:
          clearFailure ? null : (failureReason ?? this.failureReason),
    );
  }
}
