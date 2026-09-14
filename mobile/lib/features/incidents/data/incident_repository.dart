import '../../../core/utils/identifiers.dart';
import '../../../data/local/daos/app_metadata_dao.dart';
import '../../../data/local/daos/incident_dao.dart';
import '../../../data/local/field_code_minter.dart';
import '../../../data/local/tables/app_metadata.dart';
import '../../../domain/entities/incident.dart';
import '../../../domain/entities/incident_draft.dart';
import '../../../domain/entities/incident_status.dart';
import '../../../domain/entities/sync_status.dart';
import '../../../domain/entities/sync_entity_type.dart';
import '../../../domain/entities/sync_operation_type.dart';
import '../../sync/data/entity_payloads.dart';
import '../../sync/data/sync_journal.dart';

/// How an incident comes into existence, changes, and becomes the device's
/// current operation.
///
/// The rule this file exists to enforce: **declaring and adopting an incident
/// completes against local storage and nothing else**. A team that is first on
/// scene opens the response on their own handset; reconciling that with the
/// command centre's version of the same event is the synchronisation slice's
/// job, not a precondition for starting work.
class IncidentRepository {
  IncidentRepository({
    required this.incidents,
    required this.metadata,
    this.journal,
  }) : _codes = FieldCodeMinter(metadata);

  final IncidentDao incidents;
  final AppMetadataDao metadata;
  final SyncJournal? journal;
  final FieldCodeMinter _codes;

  Stream<List<Incident>> watchIncidents() => incidents.watchIncidents();

  Future<List<Incident>> readIncidents() => incidents.readIncidents();

  Stream<Incident?> watchIncident(String id) => incidents.watchIncident(id);

  Future<Incident?> readIncident(String id) => incidents.readIncident(id);

  /// The incident the responder is operating in, or null when none has been
  /// adopted.
  ///
  /// Resolved from the stored id on every emission rather than cached, so an
  /// edit to the incident is reflected wherever "current operation" is shown.
  Stream<Incident?> watchCurrentIncident() => metadata
      .watch(AppMetadataKeys.currentIncidentId)
      .asyncExpand(
        (id) => id == null
            ? Stream<Incident?>.value(null)
            : incidents.watchIncident(id),
      );

  Future<Incident?> readCurrentIncident() async {
    final id = await metadata.read(AppMetadataKeys.currentIncidentId);
    return id == null ? null : incidents.readIncident(id);
  }

  Future<String?> readCurrentIncidentId() =>
      metadata.read(AppMetadataKeys.currentIncidentId);

  /// Declares a new incident on this device and returns the stored record.
  Future<Incident> declare({
    required IncidentDraft draft,
    required String createdBy,
    DateTime? now,
  }) async {
    final timestamp = (now ?? DateTime.now()).toUtc();

    final incident = Incident(
      id: generateUuidV4(),
      incidentCode: await _nextCode(),
      title: draft.title.trim(),
      disasterType: draft.disasterType,
      description: _clean(draft.description),
      status: draft.status,
      assignedZone: _clean(draft.assignedZone),
      latitude: draft.latitude,
      longitude: draft.longitude,
      createdAt: timestamp,
      updatedAt: timestamp,
      createdBy: createdBy,
      // Nothing has been synchronised, because nothing can be yet.
      syncStatus: SyncStatus.pending,
    );

    await incidents.insertIncident(incident);
    await journal?.record(
      entityType: SyncEntityType.incident,
      entityId: incident.id,
      operationType: SyncOperationType.create,
      payload: incidentPayload(incident),
      actorId: createdBy,
      now: timestamp,
    );
    return incident;
  }

  Future<Incident> update({
    required Incident incident,
    required IncidentDraft draft,
    required String modifiedBy,
    DateTime? now,
  }) async {
    final description = _clean(draft.description);
    final assignedZone = _clean(draft.assignedZone);

    final updated = incident.copyWith(
      title: draft.title.trim(),
      disasterType: draft.disasterType,
      description: description,
      clearDescription: description == null,
      status: draft.status,
      assignedZone: assignedZone,
      clearAssignedZone: assignedZone == null,
      latitude: draft.latitude,
      longitude: draft.longitude,
      updatedAt: (now ?? DateTime.now()).toUtc(),
      lastModifiedBy: modifiedBy,
      syncStatus: SyncStatus.pending,
    );

    await incidents.updateIncident(updated);
    await journal?.record(
      entityType: SyncEntityType.incident,
      entityId: updated.id,
      operationType: SyncOperationType.update,
      payload: incidentPayload(updated),
      actorId: modifiedBy,
      now: updated.updatedAt,
    );
    return updated;
  }

  Future<Incident> changeStatus({
    required Incident incident,
    required IncidentStatus status,
    required String modifiedBy,
    DateTime? now,
  }) async {
    final updated = incident.copyWith(
      status: status,
      updatedAt: (now ?? DateTime.now()).toUtc(),
      lastModifiedBy: modifiedBy,
      syncStatus: SyncStatus.pending,
    );

    await incidents.updateIncident(updated);
    await journal?.record(
      entityType: SyncEntityType.incident,
      entityId: updated.id,
      operationType: SyncOperationType.update,
      payload: incidentPayload(updated),
      actorId: modifiedBy,
      now: updated.updatedAt,
    );
    return updated;
  }

  /// Adopts [incidentId] as the device's current operation.
  ///
  /// Written to the database rather than held in memory, which is the whole
  /// reason the selection survives the application being killed.
  Future<void> selectCurrent(String incidentId) =>
      metadata.write(AppMetadataKeys.currentIncidentId, incidentId);

  /// Stands the device down from whatever it was working.
  Future<void> clearCurrent() =>
      metadata.delete(AppMetadataKeys.currentIncidentId);

  Future<String> _nextCode() => _codes.next(
        prefix: 'INC',
        sequenceKey: AppMetadataKeys.incidentSequence,
        isTaken: (candidate) async =>
            await incidents.readByCode(candidate) != null,
      );

  /// Blank input is stored as null rather than an empty string, so "not
  /// recorded" is one state in the database instead of two.
  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
