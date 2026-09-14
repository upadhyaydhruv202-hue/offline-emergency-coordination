import 'package:drp_mobile/domain/entities/sync_entity_type.dart';
import 'package:drp_mobile/domain/entities/sync_operation.dart';
import 'package:drp_mobile/domain/entities/sync_operation_status.dart';
import 'package:drp_mobile/domain/entities/sync_operation_type.dart';
import 'package:drp_mobile/domain/entities/sync_status.dart';
import 'package:drp_mobile/features/sync/crdt/crdt_engine.dart';
import 'package:drp_mobile/features/sync/crdt/operation_order.dart';
import 'package:flutter_test/flutter_test.dart';

SyncOperation op({
  required String operationId,
  required String deviceId,
  required int logical,
  required Map<String, Object?> payload,
  String entityId = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0012',
  SyncOperationType type = SyncOperationType.update,
  int? parentVersion,
}) {
  final now = DateTime.utc(2026, 9, 14, 12);
  return SyncOperation(
    id: operationId,
    operationId: operationId,
    deviceId: deviceId,
    actorId: 'actor-$deviceId',
    entityType: SyncEntityType.hazard,
    entityId: entityId,
    operationType: type,
    payload: payload,
    createdAt: now,
    updatedAt: now,
    syncStatus: SyncStatus.pending,
    queueStatus: SyncOperationStatus.pending,
    version: logical,
    logicalTimestamp: logical,
    parentVersion: parentVersion,
  );
}

void main() {
  const engine = CrdtEngine();
  const road = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0012';
  const blocked = {'id': road, 'type': 'ROAD_BLOCKED', 'severity': 'HIGH'};
  const partial = {
    'id': road,
    'type': 'PARTIALLY_ACCESSIBLE',
    'severity': 'MEDIUM',
  };

  test('1 single operation merge', () {
    final a = op(
      operationId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0001',
      deviceId: 'DRP-AAAA',
      logical: 1,
      payload: blocked,
    );
    final result = engine.merge(local: [a], incoming: const []);
    expect(result.winners[road]?.operationId, a.operationId);
    expect(result.conflicts, isEmpty);
  });

  test('2 two non-conflicting operations on different entities', () {
    final a = op(
      operationId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0001',
      deviceId: 'DRP-AAAA',
      logical: 1,
      payload: blocked,
    );
    final b = op(
      operationId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0002',
      deviceId: 'DRP-BBBB',
      logical: 1,
      payload: {'id': 'bbbbbbbb-bbbb-4ccc-8ddd-eeeeeeee0002', 'type': 'FIRE'},
      entityId: 'bbbbbbbb-bbbb-4ccc-8ddd-eeeeeeee0002',
    );
    final result = engine.merge(local: [a], incoming: [b]);
    expect(result.winners.length, 2);
    expect(result.conflicts, isEmpty);
  });

  test('3 same entity, different devices', () {
    final a = op(
      operationId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0001',
      deviceId: 'DRP-AAAA',
      logical: 2,
      payload: blocked,
    );
    final b = op(
      operationId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0002',
      deviceId: 'DRP-BBBB',
      logical: 1,
      payload: partial,
    );
    final result = engine.merge(local: [a], incoming: [b]);
    expect(result.winners[road]?.deviceId, 'DRP-AAAA');
    expect(result.conflicts, isNotEmpty);
  });

  test('4 same logical timestamp uses device id', () {
    final a = op(
      operationId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0001',
      deviceId: 'DRP-AAAA',
      logical: 4,
      payload: blocked,
    );
    final b = op(
      operationId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0002',
      deviceId: 'DRP-BBBB',
      logical: 4,
      payload: partial,
    );
    expect(compareOperations(a, b), lessThan(0));
    final result = engine.merge(local: [a], incoming: [b]);
    expect(result.winners[road]?.deviceId, 'DRP-BBBB');
    expect(result.conflicts.single.resolution.wireValue, 'DEVICE_TIE_BREAK');
  });

  test('5 device id tie-break is deterministic', () {
    final a = op(
      operationId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0001',
      deviceId: 'DRP-ZZZZ',
      logical: 1,
      payload: blocked,
    );
    final b = op(
      operationId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0002',
      deviceId: 'DRP-AAAA',
      logical: 1,
      payload: partial,
    );
    expect(
      engine.merge(local: [a], incoming: [b]).winners[road]?.deviceId,
      'DRP-ZZZZ',
    );
  });

  test('6 operation id tie-break', () {
    final a = op(
      operationId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0001',
      deviceId: 'DRP-SAME',
      logical: 1,
      payload: blocked,
    );
    final b = op(
      operationId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0002',
      deviceId: 'DRP-SAME',
      logical: 1,
      payload: partial,
    );
    // Same device sequential-ish: no conflict pair (same device skipped).
    final result = engine.merge(local: [a], incoming: [b]);
    expect(result.winners[road]?.operationId, b.operationId);
  });

  test('7 idempotence merge(A,A)=A', () {
    final a = op(
      operationId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0001',
      deviceId: 'DRP-AAAA',
      logical: 1,
      payload: blocked,
    );
    final once = engine.merge(local: [a], incoming: const []);
    final twice = engine.merge(local: [a], incoming: [a]);
    expect(once.winners[road]?.operationId, twice.winners[road]?.operationId);
    expect(twice.accepted.length, 1);
  });

  test('8 commutativity merge(A,B)=merge(B,A)', () {
    final a = op(
      operationId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0001',
      deviceId: 'DRP-AAAA',
      logical: 3,
      payload: blocked,
    );
    final b = op(
      operationId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0002',
      deviceId: 'DRP-BBBB',
      logical: 2,
      payload: partial,
    );
    final ab = engine.merge(local: [a], incoming: [b]);
    final ba = engine.merge(local: [b], incoming: [a]);
    expect(ab.winners[road]?.operationId, ba.winners[road]?.operationId);
  });

  test('9 convergence / associativity of winners', () {
    final a = op(
      operationId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0001',
      deviceId: 'DRP-AAAA',
      logical: 1,
      payload: blocked,
    );
    final b = op(
      operationId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0002',
      deviceId: 'DRP-BBBB',
      logical: 2,
      payload: partial,
    );
    final c = op(
      operationId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0003',
      deviceId: 'DRP-CCCC',
      logical: 3,
      payload: {'id': road, 'type': 'FIRE', 'severity': 'CRITICAL'},
    );
    final left = engine.merge(
      local: engine.merge(local: [a], incoming: [b]).accepted,
      incoming: [c],
    );
    final right = engine.merge(
      local: [a],
      incoming: engine.merge(local: [b], incoming: [c]).accepted,
    );
    expect(left.winners[road]?.operationId, right.winners[road]?.operationId);
    expect(left.winners[road]?.operationId, c.operationId);
  });

  test('10 duplicate operation handling', () {
    final a = op(
      operationId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0001',
      deviceId: 'DRP-AAAA',
      logical: 1,
      payload: blocked,
    );
    final dup = op(
      operationId: a.operationId,
      deviceId: 'DRP-BBBB',
      logical: 9,
      payload: partial,
    );
    final result = engine.merge(local: [a], incoming: [dup]);
    expect(result.accepted.length, 1);
    expect(result.winners[road]?.deviceId, 'DRP-AAAA');
  });

  test('11 out-of-order operations still pick max', () {
    final late = op(
      operationId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0009',
      deviceId: 'DRP-AAAA',
      logical: 9,
      payload: blocked,
    );
    final early = op(
      operationId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0001',
      deviceId: 'DRP-BBBB',
      logical: 1,
      payload: partial,
    );
    final result = engine.merge(local: [late], incoming: [early]);
    expect(result.winners[road]?.logicalTimestamp, 9);
  });

  test('12 delete / tombstone handling', () {
    final update = op(
      operationId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0001',
      deviceId: 'DRP-AAAA',
      logical: 1,
      payload: blocked,
    );
    final del = op(
      operationId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0002',
      deviceId: 'DRP-BBBB',
      logical: 2,
      payload: {'id': road},
      type: SyncOperationType.delete,
    );
    final result = engine.merge(local: [update], incoming: [del]);
    expect(result.winners[road]?.operationType, SyncOperationType.delete);
  });

  test('13 malformed operation rejection', () {
    final bad = op(
      operationId: 'not-a-uuid',
      deviceId: 'DRP-AAAA',
      logical: 1,
      payload: blocked,
    );
    final result = engine.merge(local: const [], incoming: [bad]);
    expect(result.rejected, isNotEmpty);
    expect(result.winners, isEmpty);
  });

  test('14 conflict record generation', () {
    final a = op(
      operationId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0001',
      deviceId: 'DRP-AAAA',
      logical: 5,
      payload: blocked,
    );
    final b = op(
      operationId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0002',
      deviceId: 'DRP-BBBB',
      logical: 5,
      payload: partial,
    );
    final result = engine.merge(local: [a], incoming: [b]);
    expect(result.conflicts, hasLength(1));
    expect(result.conflicts.single.winnerOperation.deviceId, 'DRP-BBBB');
    expect(result.conflicts.single.loserOperation.deviceId, 'DRP-AAAA');
  });

  test('15 causal parentVersion is not a conflict', () {
    final a = op(
      operationId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0001',
      deviceId: 'DRP-AAAA',
      logical: 1,
      payload: blocked,
    );
    final b = op(
      operationId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0002',
      deviceId: 'DRP-BBBB',
      logical: 2,
      payload: partial,
      parentVersion: 1,
    );
    final result = engine.merge(local: [a], incoming: [b]);
    expect(result.winners[road]?.operationId, b.operationId);
    expect(result.conflicts, isEmpty);
  });
}
