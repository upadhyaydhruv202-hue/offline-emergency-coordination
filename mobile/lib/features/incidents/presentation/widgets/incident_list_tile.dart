import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../domain/entities/incident.dart';
import '../../../../shared/widgets/ops_visuals.dart';
import '../../../../shared/widgets/status_chip.dart';

/// One incident in the list.
///
/// The code is shown as prominently as the title because it is what gets read
/// over a radio, and a responder joining a response mid-shift is more likely to
/// have been given the code than the name.
class IncidentListTile extends StatelessWidget {
  const IncidentListTile({
    required this.incident,
    required this.isCurrent,
    required this.onTap,
    super.key,
  });

  final Incident incident;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = incidentStatusColor(incident.status);

    return Semantics(
      button: true,
      label: '${incident.title}, ${incident.incidentCode}, '
          '${incident.status.label}${isCurrent ? ', current operation' : ''}',
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 3,
                  color: isCurrent ? AppColors.accent : statusColor,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                incident.incidentCode,
                                style: const TextStyle(
                                  color: AppColors.ink400,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            if (isCurrent)
                              const StatusChip(
                                label: 'CURRENT',
                                color: AppColors.accent,
                                icon: Icons.my_location,
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          incident.title,
                          style: const TextStyle(
                            color: AppColors.ink100,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            StatusChip(
                              label: incident.status.wireValue,
                              color: statusColor,
                            ),
                            StatusChip(
                              label: incident.disasterType.label.toUpperCase(),
                              color: AppColors.ink400,
                            ),
                            SyncStatusChip(incident.syncStatus),
                          ],
                        ),
                        if (incident.assignedZone != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            incident.assignedZone!,
                            style: const TextStyle(
                              color: AppColors.ink400,
                              fontSize: 12,
                            ),
                          ),
                        ],
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
