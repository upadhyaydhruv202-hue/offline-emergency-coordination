import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../domain/entities/hazard.dart';
import '../../../../shared/widgets/ops_visuals.dart';
import '../../../../shared/widgets/status_chip.dart';

/// One hazard in the list.
class HazardListTile extends StatelessWidget {
  const HazardListTile({
    required this.hazard,
    required this.onTap,
    this.reporterLabel,
    super.key,
  });

  final Hazard hazard;
  final VoidCallback onTap;

  /// Who reported it, resolved to a name where the device knows one.
  final String? reporterLabel;

  @override
  Widget build(BuildContext context) {
    final severityColor = hazardSeverityColor(hazard.severity);
    final position = hazard.position;

    return Semantics(
      button: true,
      label: '${hazard.type.label}, ${hazard.severity.label} severity, '
          '${hazard.status.label}',
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 3, color: severityColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              hazardTypeIcon(hazard.type),
                              size: 18,
                              color: severityColor,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                hazard.type.label,
                                style: const TextStyle(
                                  color: AppColors.ink100,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              hazard.hazardCode,
                              style: const TextStyle(
                                color: AppColors.ink500,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        if (hazard.description != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            hazard.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.ink300,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            StatusChip(
                              label: hazard.severity.wireValue,
                              color: severityColor,
                            ),
                            StatusChip(
                              label: hazard.status.label.toUpperCase(),
                              color: hazardStatusColor(hazard.status),
                            ),
                            SyncStatusChip(hazard.syncStatus),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          [
                            position == null
                                ? 'No position'
                                : '${position.latitudeLabel} '
                                    '${position.longitudeLabel}',
                            hazard.observedAt
                                .toLocal()
                                .toString()
                                .substring(0, 16),
                            ?reporterLabel,
                          ].join(' · '),
                          style: const TextStyle(
                            color: AppColors.ink500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
