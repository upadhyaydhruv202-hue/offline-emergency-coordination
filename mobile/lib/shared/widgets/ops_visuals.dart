import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../domain/entities/hazard_severity.dart';
import '../../domain/entities/hazard_status.dart';
import '../../domain/entities/hazard_type.dart';
import '../../domain/entities/incident_status.dart';
import '../../domain/entities/responder_status.dart';
import '../../domain/entities/sos_priority.dart';
import '../../domain/entities/sos_status.dart';
import '../../domain/entities/sync_status.dart';
import '../../domain/entities/task_priority.dart';
import '../../domain/entities/task_status.dart';
import 'status_chip.dart';

/// Severity encoding for the field operations modules.
///
/// Hazard severity, SOS priority and task priority are three different scales
/// that a responder reads on the same screen, so they are defined together here:
/// keeping them in one file is what makes it checkable that CRITICAL means the
/// same red everywhere. Red, orange, amber and green are reserved for severity
/// and status and are never used for decoration.
///
/// Colour is never the only signal. Every badge built on these carries its
/// label, because a handset in direct sunlight, a cracked screen or a
/// colour-blind responder must not change what the interface communicates.
Color hazardSeverityColor(HazardSeverity severity) => switch (severity) {
      HazardSeverity.critical => AppColors.critical,
      HazardSeverity.high => AppColors.high,
      HazardSeverity.medium => AppColors.elevated,
      HazardSeverity.low => AppColors.nominal,
    };

Color sosPriorityColor(SosPriority priority) => switch (priority) {
      SosPriority.critical => AppColors.critical,
      SosPriority.high => AppColors.high,
      SosPriority.medium => AppColors.elevated,
    };

Color taskPriorityColor(TaskPriority priority) => switch (priority) {
      TaskPriority.critical => AppColors.critical,
      TaskPriority.high => AppColors.high,
      TaskPriority.medium => AppColors.elevated,
      TaskPriority.low => AppColors.nominal,
    };

Color hazardStatusColor(HazardStatus status) => switch (status) {
      HazardStatus.reported => AppColors.elevated,
      HazardStatus.verified => AppColors.accentSoft,
      HazardStatus.resolved => AppColors.nominal,
    };

Color sosStatusColor(SosStatus status) => switch (status) {
      SosStatus.created => AppColors.critical,
      SosStatus.acknowledged => AppColors.elevated,
      SosStatus.resolved => AppColors.nominal,
    };

Color taskStatusColor(TaskStatus status) => switch (status) {
      TaskStatus.pending => AppColors.ink400,
      TaskStatus.accepted => AppColors.accentSoft,
      TaskStatus.inProgress => AppColors.elevated,
      TaskStatus.completed => AppColors.nominal,
      TaskStatus.cancelled => AppColors.inactive,
    };

Color incidentStatusColor(IncidentStatus status) => switch (status) {
      IncidentStatus.active => AppColors.high,
      IncidentStatus.paused => AppColors.elevated,
      IncidentStatus.resolved => AppColors.nominal,
    };

/// [ResponderStatus.needsAssistance] is red because a responder in trouble is
/// the most urgent thing on any screen it appears on.
Color responderStatusColor(ResponderStatus status) => switch (status) {
      ResponderStatus.available => AppColors.nominal,
      ResponderStatus.enRoute => AppColors.accentSoft,
      ResponderStatus.onMission => AppColors.elevated,
      ResponderStatus.needsAssistance => AppColors.critical,
      ResponderStatus.offDuty => AppColors.inactive,
    };

IconData hazardTypeIcon(HazardType type) => switch (type) {
      HazardType.flood => Icons.water_outlined,
      HazardType.fire => Icons.local_fire_department_outlined,
      HazardType.smoke => Icons.cloud_outlined,
      HazardType.roadBlocked => Icons.block_outlined,
      HazardType.partiallyAccessible => Icons.traffic_outlined,
      HazardType.buildingDamage => Icons.domain_disabled_outlined,
      HazardType.bridgeRisk => Icons.dangerous_outlined,
      HazardType.landslide => Icons.terrain_outlined,
      HazardType.electricalHazard => Icons.electric_bolt_outlined,
      HazardType.chemicalHazard => Icons.science_outlined,
      HazardType.other => Icons.report_problem_outlined,
    };

IconData responderStatusIcon(ResponderStatus status) => switch (status) {
      ResponderStatus.available => Icons.check_circle_outline,
      ResponderStatus.enRoute => Icons.directions_run_outlined,
      ResponderStatus.onMission => Icons.engineering_outlined,
      ResponderStatus.needsAssistance => Icons.priority_high,
      ResponderStatus.offDuty => Icons.bedtime_outlined,
    };

/// Where a record stands with respect to leaving the device.
///
/// Amber for anything outstanding rather than red: holding unsent records is the
/// normal, expected condition in this build, not a fault the responder should be
/// alarmed by. Green is reserved for records a peer has actually confirmed.
Color syncStatusColor(SyncStatus status) =>
    status.isConfirmed ? AppColors.nominal : AppColors.elevated;

class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip(this.status, {super.key});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    return StatusChip(
      label: status.label.toUpperCase(),
      color: syncStatusColor(status),
      icon: status.isConfirmed ? Icons.cloud_done_outlined : Icons.cloud_off,
    );
  }
}
