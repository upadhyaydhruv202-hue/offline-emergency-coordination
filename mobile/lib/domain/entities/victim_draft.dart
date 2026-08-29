import 'triage_category.dart';
import 'victim.dart';
import 'victim_demographics.dart';
import 'victim_status.dart';

/// What a responder actually types on the registration form.
///
/// Everything the device derives — identifiers, priority, timestamps,
/// provenance, sync state — is deliberately absent: a draft is an intention,
/// and the repository is the only thing that turns one into a [Victim].
class VictimDraft {
  const VictimDraft({
    required this.triageCategory,
    this.name,
    this.age,
    this.gender = Gender.unknown,
    this.medicalCondition,
    this.injuryType,
    this.assistanceRequired,
    this.status = VictimStatus.registered,
  });

  /// Pre-fills the form when an existing record is edited.
  factory VictimDraft.from(Victim victim) => VictimDraft(
        triageCategory: victim.triageCategory,
        name: victim.name,
        age: victim.age,
        gender: victim.gender,
        medicalCondition: victim.medicalCondition,
        injuryType: victim.injuryType,
        assistanceRequired: victim.assistanceRequired,
        status: victim.status,
      );

  final TriageCategory triageCategory;
  final String? name;
  final int? age;
  final Gender gender;
  final String? medicalCondition;
  final String? injuryType;
  final String? assistanceRequired;
  final VictimStatus status;

  /// The band implied by [age]. Kept derived so the two can never disagree.
  AgeGroup get ageGroup => AgeGroup.fromAge(age);

  VictimDraft copyWith({
    TriageCategory? triageCategory,
    String? name,
    int? age,
    bool clearAge = false,
    Gender? gender,
    String? medicalCondition,
    String? injuryType,
    String? assistanceRequired,
    VictimStatus? status,
  }) =>
      VictimDraft(
        triageCategory: triageCategory ?? this.triageCategory,
        name: name ?? this.name,
        age: clearAge ? null : (age ?? this.age),
        gender: gender ?? this.gender,
        medicalCondition: medicalCondition ?? this.medicalCondition,
        injuryType: injuryType ?? this.injuryType,
        assistanceRequired: assistanceRequired ?? this.assistanceRequired,
        status: status ?? this.status,
      );
}
