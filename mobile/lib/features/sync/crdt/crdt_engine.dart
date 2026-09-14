import '../../../domain/entities/conflict_resolution.dart';
import '../../../domain/entities/sync_conflict.dart';
import '../../../domain/entities/sync_operation.dart';
import '../../../domain/entities/sync_operation_status.dart';
import '../../../domain/entities/sync_operation_type.dart';
import '../../../domain/entities/sync_status.dart';
import 'operation_order.dart';
import 'operation_validator.dart';

class MergeResult {
  const MergeResult({
    required this.accepted,
    required this.winners,
    required this.conflicts,
    required this.rejected,
  });

  /// Unique operations that passed validation, including ones that lost LWW.
  final List<SyncOperation> accepted;

  /// One surviving operation per entity.
  final Map<String, SyncOperation> winners;

  final List<SyncConflict> conflicts;

  /// Malformed operations, keyed by operationId, with the reason.
  final Map<String, String> rejected;

  SyncOperation? winnerFor(String entityId) => winners[entityId];
}

/// State-based LWW-Register over whole entity snapshots.
///
/// This is not a research CRDT (no HLC, no Merkle DAG). It is a total order
/// over operations plus a per-entity last-writer-wins register. Properties:
///
/// * **Idempotent**: applying the same operation twice does not change the
///   winner, because operations are keyed by [SyncOperation.operationId].
/// * **Commutative**: the winner of a set of operations does not depend on
///   the order they are presented, because they are sorted by
///   [compareOperations] before reduction.
/// * **Associative on winners**: `winner(winner(A,B), C) == winner(A, winner(B,C))`
///   because max() over a total order is associative.
///
/// Limitation: this merges **whole snapshots**, not field-wise. Two devices
/// editing different fields of the same victim still produce a conflict and
/// one snapshot wins. A true multi-value register per field is future work.
class CrdtEngine {
  const CrdtEngine();

  MergeResult merge({
    required List<SyncOperation> local,
    required List<SyncOperation> incoming,
    DateTime? now,
  }) {
    final detectedAt = (now ?? DateTime.now()).toUtc();
    final rejected = <String, String>{};
    final byId = <String, SyncOperation>{};

    void consider(SyncOperation operation) {
      try {
        validateOperation(operation);
      } on SyncValidationException catch (error) {
        rejected[operation.operationId] = error.message;
        return;
      }
      byId.putIfAbsent(operation.operationId, () => operation);
    }

    for (final operation in local) {
      consider(operation);
    }
    for (final operation in incoming) {
      consider(operation);
    }

    final accepted = byId.values.toList(growable: false);
    final grouped = <String, List<SyncOperation>>{};
    for (final operation in accepted) {
      grouped.putIfAbsent(operation.entityId, () => []).add(operation);
    }

    final winners = <String, SyncOperation>{};
    final conflicts = <SyncConflict>[];

    for (final entry in grouped.entries) {
      final ops = [...entry.value]..sort(compareOperations);
      final winner = ops.last;
      winners[entry.key] = winner;

      final concurrent = _concurrentPairs(ops);
      for (final pair in concurrent) {
        final ordered = [...pair]..sort(compareOperations);
        final loser = ordered.first;
        final winnerOp = ordered.last;
        conflicts.add(
          SyncConflict(
            id: '${loser.operationId}:${winnerOp.operationId}',
            entityType: winnerOp.entityType,
            entityId: winnerOp.entityId,
            operationA: ordered[0],
            operationB: ordered[1],
            detectedAt: detectedAt,
            resolution: _resolution(loser, winnerOp),
            winnerOperation: winnerOp,
            loserOperation: loser,
            reason: _reason(loser, winnerOp),
            resolvedAt: detectedAt,
            syncStatus: SyncStatus.pending,
          ),
        );
      }
    }

    return MergeResult(
      accepted: accepted,
      winners: winners,
      conflicts: conflicts,
      rejected: rejected,
    );
  }

  static List<List<SyncOperation>> _concurrentPairs(List<SyncOperation> ops) {
    final pairs = <List<SyncOperation>>[];
    for (var i = 0; i < ops.length; i++) {
      for (var j = i + 1; j < ops.length; j++) {
        final a = ops[i];
        final b = ops[j];
        if (a.deviceId == b.deviceId) continue;
        if (a.operationType == SyncOperationType.create &&
            b.operationType == SyncOperationType.create &&
            a.operationId != b.operationId) {
          // Two creates of the same id from different devices still conflict.
        }
        if (_isCausal(a, b) || _isCausal(b, a)) continue;
        pairs.add([a, b]);
      }
    }
    return pairs;
  }

  /// B is a later edit of A if it names A's version as its parent.
  static bool _isCausal(SyncOperation earlier, SyncOperation later) {
    return later.parentVersion != null &&
        later.parentVersion == earlier.version &&
        compareOperations(earlier, later) < 0;
  }

  static ConflictResolution _resolution(SyncOperation loser, SyncOperation winner) {
    if (loser.logicalTimestamp != winner.logicalTimestamp) {
      return ConflictResolution.lastWriterWins;
    }
    if (loser.deviceId != winner.deviceId) {
      return ConflictResolution.deviceTieBreak;
    }
    return ConflictResolution.operationTieBreak;
  }

  static String _reason(SyncOperation loser, SyncOperation winner) {
    if (loser.logicalTimestamp != winner.logicalTimestamp) {
      return 'Higher logical timestamp wins '
          '(${winner.logicalTimestamp} > ${loser.logicalTimestamp}).';
    }
    if (loser.deviceId != winner.deviceId) {
      return 'Equal logical timestamps; device id tie-break '
          '(${winner.deviceId} > ${loser.deviceId}).';
    }
    return 'Equal logical timestamp and device; operation id tie-break '
        '(${winner.operationId} > ${loser.operationId}).';
  }
}

extension SyncOperationMarking on SyncOperation {
  SyncOperation asAcknowledged(DateTime now) => copyWith(
        queueStatus: SyncOperationStatus.acknowledged,
        syncStatus: SyncStatus.acknowledged,
        updatedAt: now,
        clearFailure: true,
      );

  SyncOperation asConflict(DateTime now) => copyWith(
        queueStatus: SyncOperationStatus.conflict,
        updatedAt: now,
      );

  SyncOperation asFailed(String reason, DateTime now) => copyWith(
        queueStatus: SyncOperationStatus.failed,
        failureReason: reason,
        updatedAt: now,
      );
}
