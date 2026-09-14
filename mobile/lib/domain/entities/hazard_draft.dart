import 'hazard.dart';
import 'hazard_severity.dart';
import 'hazard_status.dart';
import 'hazard_type.dart';
import 'location_fix.dart';

/// What a responder fills in on the hazard report form.
///
/// The position is carried as a whole [LocationFix] rather than a pair of
/// doubles so a report either has a real reading, with its accuracy and the
/// moment it was taken, or has none at all. A half-recorded position is worse
/// than no position, because someone would trust it.
class HazardDraft {
  const HazardDraft({
    required this.type,
    required this.severity,
    this.description,
    this.status = HazardStatus.reported,
    this.position,
  });

  factory HazardDraft.from(Hazard hazard) => HazardDraft(
        type: hazard.type,
        severity: hazard.severity,
        description: hazard.description,
        status: hazard.status,
        position: hazard.hasPosition
            ? LocationFix(
                latitude: hazard.latitude!,
                longitude: hazard.longitude!,
                accuracy: hazard.accuracy,
                timestamp: hazard.observedAt,
              )
            : null,
      );

  final HazardType type;
  final HazardSeverity severity;
  final String? description;
  final HazardStatus status;
  final LocationFix? position;

  HazardDraft copyWith({
    HazardType? type,
    HazardSeverity? severity,
    String? description,
    HazardStatus? status,
    LocationFix? position,
    bool clearPosition = false,
  }) =>
      HazardDraft(
        type: type ?? this.type,
        severity: severity ?? this.severity,
        description: description ?? this.description,
        status: status ?? this.status,
        position: clearPosition ? null : (position ?? this.position),
      );
}
