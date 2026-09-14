import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database_providers.dart';
import '../../../domain/entities/incident.dart';
import '../../audit/application/audit_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../sync/application/sync_providers.dart';
import '../data/incident_repository.dart';
import 'incident_service.dart';

final incidentRepositoryProvider = Provider<IncidentRepository>(
  (ref) => IncidentRepository(
    incidents: ref.watch(incidentDaoProvider),
    metadata: ref.watch(appMetadataDaoProvider),
    journal: ref.watch(syncJournalProvider),
  ),
);

/// Every incident on the device, running responses first. Backed by a database
/// stream, so declaring one anywhere in the app is reflected here without a
/// manual refresh.
final incidentListProvider = StreamProvider<List<Incident>>(
  (ref) => ref.watch(incidentRepositoryProvider).watchIncidents(),
);

/// The responder's current operation, or null when none has been adopted.
///
/// Read from the database rather than held in memory, which is what makes the
/// selection survive the application being killed.
final currentIncidentProvider = StreamProvider<Incident?>(
  (ref) => ref.watch(incidentRepositoryProvider).watchCurrentIncident(),
);

final incidentProvider = StreamProvider.family<Incident?, String>(
  (ref, id) => ref.watch(incidentRepositoryProvider).watchIncident(id),
);

/// Live count of incident rows this device has authored or changed and not yet
/// handed to a peer.
final incidentPendingCountProvider = StreamProvider<int>(
  (ref) => ref.watch(incidentDaoProvider).watchPendingCount(),
);

final incidentServiceProvider = Provider<IncidentService>(
  (ref) => IncidentService(
    repository: ref.watch(incidentRepositoryProvider),
    audit: ref.watch(auditRepositoryProvider),
    currentResponderId: () =>
        ref.read(authControllerProvider).responderOrNull?.id,
  ),
);
