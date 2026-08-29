import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../domain/entities/triage_category.dart';
import '../../../../domain/entities/victim_status.dart';

/// Severity encoding for the victim module.
///
/// Red / orange / amber / green are reserved for triage and never used for
/// decoration, so a responder can read a list at arm's length. Colour alone is
/// never the signal: every badge that uses these carries its label too.
Color triageColor(TriageCategory category) => switch (category) {
      TriageCategory.critical => AppColors.critical,
      TriageCategory.urgent => AppColors.high,
      TriageCategory.moderate => AppColors.elevated,
      TriageCategory.stable => AppColors.nominal,
    };

Color statusColor(VictimStatus status) => switch (status) {
      VictimStatus.registered => AppColors.ink400,
      VictimStatus.underTreatment => AppColors.accentSoft,
      VictimStatus.awaitingEvacuation => AppColors.elevated,
      VictimStatus.evacuated => AppColors.nominal,
      VictimStatus.deceased => AppColors.inactive,
    };

IconData statusIcon(VictimStatus status) => switch (status) {
      VictimStatus.registered => Icons.how_to_reg_outlined,
      VictimStatus.underTreatment => Icons.medical_services_outlined,
      VictimStatus.awaitingEvacuation => Icons.airport_shuttle_outlined,
      VictimStatus.evacuated => Icons.check_circle_outline,
      VictimStatus.deceased => Icons.remove_circle_outline,
    };
