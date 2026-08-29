import 'sync_status.dart';
import 'triage_category.dart';
import 'victim_demographics.dart';
import 'victim_status.dart';

/// A person registered by a responder on this device.
///
/// The record is complete and authoritative the moment it is written to local
/// storage. Nothing here waits on, or is corrected by, the backend.
class Victim {
  const Victim({
    required this.id,
    required this.temporaryId,
    required this.ageGroup,
    required this.gender,
    required this.triageCategory,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.syncStatus,
    this.name,
    this.age,
    this.medicalCondition,
    this.injuryType,
    this.assistanceRequired,
    this.latitude,
    this.longitude,
  });

  /// Device-minted UUID. Stable for the life of the record, across devices.
  final String id;

  /// Short human-readable label, e.g. `V-8C1F-007`. What goes on the triage
  /// tag and gets read out over the radio.
  final String temporaryId;

  /// Null when the person could not be identified, which is common and is not
  /// a reason to delay registering them.
  final String? name;

  final int? age;
  final AgeGroup ageGroup;
  final Gender gender;
  final String? medicalCondition;
  final String? injuryType;
  final TriageCategory triageCategory;

  /// Mirrors [TriageCategory.priority]. Persisted so the list can be ordered
  /// by the database rather than in memory.
  final int priority;

  final String? assistanceRequired;
  final VictimStatus status;

  /// Reserved for the spatial slice. Slice 2 captures no position, so these
  /// are null on every record it writes.
  final double? latitude;
  final double? longitude;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Identifier of the responder session that authored the record. Carries an
  /// offline demo session's local id unchanged, so provenance survives.
  final String createdBy;

  final SyncStatus syncStatus;

  /// What to show when the person has no recorded name.
  String get displayName {
    final trimmed = name?.trim();
    return (trimmed == null || trimmed.isEmpty) ? 'Unidentified' : trimmed;
  }

  bool get hasPosition => latitude != null && longitude != null;

  Victim copyWith({
    String? name,
    bool clearName = false,
    int? age,
    bool clearAge = false,
    AgeGroup? ageGroup,
    Gender? gender,
    String? medicalCondition,
    bool clearMedicalCondition = false,
    String? injuryType,
    bool clearInjuryType = false,
    TriageCategory? triageCategory,
    String? assistanceRequired,
    bool clearAssistanceRequired = false,
    VictimStatus? status,
    double? latitude,
    double? longitude,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) {
    final category = triageCategory ?? this.triageCategory;
    return Victim(
      id: id,
      temporaryId: temporaryId,
      name: clearName ? null : (name ?? this.name),
      age: clearAge ? null : (age ?? this.age),
      ageGroup: ageGroup ?? this.ageGroup,
      gender: gender ?? this.gender,
      medicalCondition: clearMedicalCondition
          ? null
          : (medicalCondition ?? this.medicalCondition),
      injuryType: clearInjuryType ? null : (injuryType ?? this.injuryType),
      triageCategory: category,
      priority: category.priority,
      assistanceRequired: clearAssistanceRequired
          ? null
          : (assistanceRequired ?? this.assistanceRequired),
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Victim &&
          other.id == id &&
          other.temporaryId == temporaryId &&
          other.name == name &&
          other.age == age &&
          other.ageGroup == ageGroup &&
          other.gender == gender &&
          other.medicalCondition == medicalCondition &&
          other.injuryType == injuryType &&
          other.triageCategory == triageCategory &&
          other.priority == priority &&
          other.assistanceRequired == assistanceRequired &&
          other.status == status &&
          other.latitude == latitude &&
          other.longitude == longitude &&
          other.updatedAt == updatedAt &&
          other.syncStatus == syncStatus;

  @override
  int get hashCode => Object.hash(
        id,
        temporaryId,
        name,
        age,
        ageGroup,
        gender,
        medicalCondition,
        injuryType,
        triageCategory,
        status,
        assistanceRequired,
        latitude,
        longitude,
        updatedAt,
        syncStatus,
      );
}
