import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/daos/sync_conflict_dao.dart';
import '../../../data/local/daos/sync_entity_head_dao.dart';
import '../../../data/local/daos/sync_operation_dao.dart';
import '../../../data/local/database_providers.dart';
import '../../../domain/entities/sync_conflict.dart';
import '../../../domain/entities/sync_operation.dart';
import '../../../domain/entities/sync_operation_status.dart';
import '../../audit/application/audit_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../crdt/crdt_engine.dart';
import '../data/entity_applier.dart';
import '../data/sync_journal.dart';
import 'sync_service.dart';

final syncOperationDaoProvider = Provider(
  (ref) => SyncOperationDao(ref.watch(appDatabaseProvider)),
);

final syncConflictDaoProvider = Provider(
  (ref) => SyncConflictDao(ref.watch(appDatabaseProvider)),
);

final syncEntityHeadDaoProvider = Provider(
  (ref) => SyncEntityHeadDao(ref.watch(appDatabaseProvider)),
);

final syncJournalProvider = Provider<SyncJournal>(
  (ref) => SyncJournal(
    metadata: ref.watch(appMetadataDaoProvider),
    operations: ref.watch(syncOperationDaoProvider),
    heads: ref.watch(syncEntityHeadDaoProvider),
    audit: ref.watch(auditRepositoryProvider),
  ),
);

final entityApplierProvider = Provider<EntityApplier>(
  (ref) => EntityApplier(
    hazards: ref.watch(hazardDaoProvider),
    victims: ref.watch(victimDaoProvider),
    incidents: ref.watch(incidentDaoProvider),
    tasks: ref.watch(taskDaoProvider),
    sos: ref.watch(sosDaoProvider),
    responderStatuses: ref.watch(responderStatusDaoProvider),
    heads: ref.watch(syncEntityHeadDaoProvider),
  ),
);

final syncServiceProvider = Provider<SyncService>((ref) {
  final actor = ref.watch(authControllerProvider).responderOrNull?.id ?? 'device';
  return SyncService(
    database: ref.watch(appDatabaseProvider),
    metadata: ref.watch(appMetadataDaoProvider),
    operations: ref.watch(syncOperationDaoProvider),
    conflicts: ref.watch(syncConflictDaoProvider),
    heads: ref.watch(syncEntityHeadDaoProvider),
    engine: const CrdtEngine(),
    applier: ref.watch(entityApplierProvider),
    audit: ref.watch(auditRepositoryProvider),
    actorId: actor,
  );
});

final pendingSyncOperationsCountProvider = StreamProvider<int>(
  (ref) => ref
      .watch(syncOperationDaoProvider)
      .watchCount(SyncOperationStatus.pending),
);

final syncOperationsProvider = StreamProvider<List<SyncOperation>>(
  (ref) => ref.watch(syncOperationDaoProvider).watchAll(),
);

final syncConflictsProvider = StreamProvider<List<SyncConflict>>((ref) {
  final dao = ref.watch(syncConflictDaoProvider);
  final operations = ref.watch(syncOperationDaoProvider);
  return dao.watchRows().asyncMap(
        (rows) => hydrateConflicts(
          rows: rows,
          readOperation: operations.readByOperationId,
        ),
      );
});

final syncStatisticsProvider = FutureProvider<SyncStatistics>(
  (ref) => ref.watch(syncServiceProvider).getSyncStatistics(),
);
