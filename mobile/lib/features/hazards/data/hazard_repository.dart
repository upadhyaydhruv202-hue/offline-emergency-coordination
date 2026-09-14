import '../../../core/utils/identifiers.dart';
import '../../../data/local/daos/app_metadata_dao.dart';
import '../../../data/local/daos/hazard_dao.dart';
import '../../../data/local/field_code_minter.dart';
import '../../../data/local/tables/app_metadata.dart';
import '../../../domain/entities/field_ops_boards.dart';
import '../../../domain/entities/hazard.dart';
import '../../../domain/entities/hazard_draft.dart';
import '../../../domain/entities/hazard_query.dart';
import '../../../domain/entities/hazard_status.dart';
import '../../../domain/entities/sync_status.dart';

/// How a hazard report comes into existence and changes.
///
/// The rule this file exists to enforce: **reporting a hazard completes against
/// local storage and nothing else**. The value of the report is in how early it
/// exists; making it wait for a network would mean the team that needed the
/// warning has already walked into the thing being reported.
class HazardRepository {
  HazardRepository({required this.hazards, required this.metadata})
      : _codes = FieldCodeMinter(metadata);

  final HazardDao hazards;
  final AppMetadataDao metadata;
  final FieldCodeMinter _codes;

  Stream<List<Hazard>> watchHazards(HazardQuery query) =>
      hazards.watchHazards(query);

  Future<List<Hazard>> readHazards([
    HazardQuery query = const HazardQuery(),
  ]) =>
      hazards.readHazards(query);

  Stream<Hazard?> watchHazard(String id) => hazards.watchHazard(id);

  Future<Hazard?> readHazard(String id) => hazards.readHazard(id);

  Stream<HazardBoard> watchBoard() => hazards.watchBoard();

  /// Writes a new hazard to the device and returns the stored record.
  Future<Hazard> report({
    required HazardDraft draft,
    required String reportedBy,
    String? incidentId,
    DateTime? now,
  }) async {
    final timestamp = (now ?? DateTime.now()).toUtc();
    final position = draft.position;

    final hazard = Hazard(
      id: generateUuidV4(),
      hazardCode: await _nextCode(),
      incidentId: incidentId,
      reportedBy: reportedBy,
      type: draft.type,
      severity: draft.severity,
      priority: draft.severity.priority,
      description: _clean(draft.description),
      latitude: position?.latitude,
      longitude: position?.longitude,
      accuracy: position?.accuracy,
      observedAt: timestamp,
      status: draft.status,
      createdAt: timestamp,
      updatedAt: timestamp,
      // Nothing has been synchronised, because nothing can be yet.
      syncStatus: SyncStatus.pending,
    );

    await hazards.insertHazard(hazard);
    return hazard;
  }

  /// Applies an edited form to an existing report.
  Future<Hazard> update({
    required Hazard hazard,
    required HazardDraft draft,
    DateTime? now,
  }) async {
    final description = _clean(draft.description);
    final position = draft.position;

    final updated = hazard.copyWith(
      type: draft.type,
      severity: draft.severity,
      description: description,
      clearDescription: description == null,
      status: draft.status,
      latitude: position?.latitude,
      longitude: position?.longitude,
      accuracy: position?.accuracy,
      updatedAt: (now ?? DateTime.now()).toUtc(),
      syncStatus: SyncStatus.pending,
    );

    await hazards.updateHazard(updated);
    return updated;
  }

  /// Verification and clearance, which are one tap each in the field.
  Future<Hazard> changeStatus({
    required Hazard hazard,
    required HazardStatus status,
    DateTime? now,
  }) async {
    final updated = hazard.copyWith(
      status: status,
      updatedAt: (now ?? DateTime.now()).toUtc(),
      syncStatus: SyncStatus.pending,
    );

    await hazards.updateHazard(updated);
    return updated;
  }

  Future<String> _nextCode() => _codes.next(
        prefix: 'HZ',
        sequenceKey: AppMetadataKeys.hazardSequence,
        isTaken: (candidate) async =>
            await hazards.readByCode(candidate) != null,
      );

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
