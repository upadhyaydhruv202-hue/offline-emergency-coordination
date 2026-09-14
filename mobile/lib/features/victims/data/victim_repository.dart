import '../../../core/utils/identifiers.dart';
import '../../../data/local/daos/app_metadata_dao.dart';
import '../../../data/local/daos/victim_dao.dart';
import '../../../data/local/tables/app_metadata.dart';
import '../../../domain/entities/location_fix.dart';
import '../../../domain/entities/sync_status.dart';
import '../../../domain/entities/triage_category.dart';
import '../../../domain/entities/victim.dart';
import '../../../domain/entities/victim_board.dart';
import '../../../domain/entities/victim_draft.dart';
import '../../../domain/entities/victim_query.dart';
import '../../../domain/entities/victim_status.dart';

/// How a victim record comes into existence and changes.
///
/// The rule this file exists to enforce: **registration completes against
/// local storage and nothing else**. There is no network call here, no write
/// waiting on confirmation, and no failure mode that involves the backend. A
/// responder in a basement with no signal gets the same result as one standing
/// next to a working uplink.
class VictimRepository {
  const VictimRepository({required this.victims, required this.metadata});

  final VictimDao victims;
  final AppMetadataDao metadata;

  /// Short ids to try before falling back to a randomised one. A clash needs
  /// the counter and the table to have drifted apart — a restore from backup
  /// would do it — so this is rare, but a casualty must never fail to register
  /// over a naming detail.
  static const int _temporaryIdAttempts = 5;

  Stream<List<Victim>> watchVictims(VictimQuery query) =>
      victims.watchVictims(query);

  Stream<Victim?> watchVictim(String id) => victims.watchVictim(id);

  Stream<VictimBoard> watchBoard() => victims.watchBoard();

  Future<Victim?> readVictim(String id) => victims.readVictim(id);

  Future<List<Victim>> readVictims([
    VictimQuery query = const VictimQuery(),
  ]) =>
      victims.readVictims(query);

  /// Writes a new victim to the device and returns the stored record.
  ///
  /// [incidentId] and [position] are the operational context the device already
  /// holds, not extra questions asked of the responder. Both are optional: a
  /// casualty registered before an incident was declared, or in a stairwell
  /// with no fix, is still a casualty, and refusing the record would be the
  /// worst possible response to missing metadata.
  Future<Victim> register({
    required VictimDraft draft,
    required String createdBy,
    String? incidentId,
    LocationFix? position,
    DateTime? now,
  }) async {
    final timestamp = (now ?? DateTime.now()).toUtc();

    final victim = Victim(
      id: generateUuidV4(),
      temporaryId: await _nextTemporaryId(),
      name: _clean(draft.name),
      age: draft.age,
      ageGroup: draft.ageGroup,
      gender: draft.gender,
      medicalCondition: _clean(draft.medicalCondition),
      injuryType: _clean(draft.injuryType),
      triageCategory: draft.triageCategory,
      priority: draft.triageCategory.priority,
      assistanceRequired: _clean(draft.assistanceRequired),
      status: draft.status,
      incidentId: incidentId,
      latitude: position?.latitude,
      longitude: position?.longitude,
      locationAccuracy: position?.accuracy,
      createdAt: timestamp,
      updatedAt: timestamp,
      createdBy: createdBy,
      // Nothing has been synchronised, because nothing can be yet.
      syncStatus: SyncStatus.pending,
    );

    await victims.insertVictim(victim);
    return victim;
  }

  /// Applies an edited form to an existing record.
  Future<Victim> update({
    required Victim victim,
    required VictimDraft draft,
    DateTime? now,
  }) async {
    final name = _clean(draft.name);
    final medicalCondition = _clean(draft.medicalCondition);
    final injuryType = _clean(draft.injuryType);
    final assistanceRequired = _clean(draft.assistanceRequired);

    final updated = victim.copyWith(
      name: name,
      clearName: name == null,
      age: draft.age,
      clearAge: draft.age == null,
      ageGroup: draft.ageGroup,
      gender: draft.gender,
      medicalCondition: medicalCondition,
      clearMedicalCondition: medicalCondition == null,
      injuryType: injuryType,
      clearInjuryType: injuryType == null,
      triageCategory: draft.triageCategory,
      assistanceRequired: assistanceRequired,
      clearAssistanceRequired: assistanceRequired == null,
      status: draft.status,
      updatedAt: (now ?? DateTime.now()).toUtc(),
      syncStatus: SyncStatus.pending,
    );

    await victims.updateVictim(updated);
    return updated;
  }

  /// Re-triage after reassessment. Separate from [update] because it is one
  /// tap in the field and must not mean re-entering the whole form.
  Future<Victim> reassess({
    required Victim victim,
    required TriageCategory category,
    DateTime? now,
  }) async {
    final updated = victim.copyWith(
      triageCategory: category,
      updatedAt: (now ?? DateTime.now()).toUtc(),
      syncStatus: SyncStatus.pending,
    );

    await victims.updateVictim(updated);
    return updated;
  }

  /// Moves a victim through the response: under treatment, awaiting
  /// evacuation, evacuated, deceased.
  Future<Victim> changeStatus({
    required Victim victim,
    required VictimStatus status,
    DateTime? now,
  }) async {
    final updated = victim.copyWith(
      status: status,
      updatedAt: (now ?? DateTime.now()).toUtc(),
      syncStatus: SyncStatus.pending,
    );

    await victims.updateVictim(updated);
    return updated;
  }

  Future<String> _nextTemporaryId() async {
    final deviceId = await metadata.readOrCreate(
      AppMetadataKeys.deviceId,
      generateDeviceId,
    );

    var sequence = 0;
    for (var attempt = 0; attempt < _temporaryIdAttempts; attempt++) {
      sequence = await metadata.nextSequence(AppMetadataKeys.victimSequence);
      final candidate = formatTemporaryId(
        deviceId: deviceId,
        sequence: sequence,
      );
      if (await victims.readByTemporaryId(candidate) == null) {
        return candidate;
      }
    }

    // Every candidate was taken. Registering the person matters more than a
    // tidy sequence, so the id gets a random discriminator and stays unique.
    return formatTemporaryId(
      deviceId: deviceId,
      sequence: sequence,
      discriminator: generateUuidV4().substring(0, 4),
    );
  }

  /// Blank input is stored as null rather than an empty string, so "not
  /// recorded" is one state in the database instead of two.
  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
