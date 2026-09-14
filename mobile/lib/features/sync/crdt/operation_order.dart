import '../../../domain/entities/sync_operation.dart';

/// Deterministic total order over sync operations.
///
/// Wall clocks are **not** consulted. Two devices that tick at the same
/// millisecond must still agree. The order is:
///
/// 1. [SyncOperation.logicalTimestamp] — per-device monotonic counter
/// 2. [SyncOperation.deviceId] — lexicographic, so equal counters still sort
/// 3. [SyncOperation.operationId] — lexicographic, last-chance uniqueness
///
/// Because every key is a totally ordered scalar (or a UUID string), the
/// comparison is a mathematical total order: antisymmetric, transitive,
/// defined for every pair. That is what makes Last-Writer-Wins converge.
int compareOperations(SyncOperation a, SyncOperation b) {
  final byTime = a.logicalTimestamp.compareTo(b.logicalTimestamp);
  if (byTime != 0) return byTime;
  final byDevice = a.deviceId.compareTo(b.deviceId);
  if (byDevice != 0) return byDevice;
  return a.operationId.compareTo(b.operationId);
}

bool isSameOperation(SyncOperation a, SyncOperation b) =>
    a.operationId == b.operationId;
