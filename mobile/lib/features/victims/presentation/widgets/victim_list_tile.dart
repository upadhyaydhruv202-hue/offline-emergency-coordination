import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../domain/entities/sync_status.dart';
import '../../../../domain/entities/victim.dart';
import '../../../../shared/widgets/status_chip.dart';
import 'victim_visuals.dart';

/// One casualty in the list.
///
/// The severity bar runs the full height on the left so the shape of a sector
/// is readable while scrolling, without reading a single word.
class VictimListTile extends StatelessWidget {
  const VictimListTile({required this.victim, required this.onTap, super.key});

  final Victim victim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final severity = triageColor(victim.triageCategory);
    final closed = victim.status.isClosed;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Opacity(
          opacity: closed ? 0.72 : 1,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: severity),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                victim.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.ink100,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            StatusChip(
                              label: victim.triageCategory.wireValue,
                              color: severity,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _subtitle(victim),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.ink400,
                            fontSize: 12,
                          ),
                        ),
                        if (victim.injuryType != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            victim.injuryType!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.ink500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            StatusChip(
                              label: victim.status.label.toUpperCase(),
                              color: statusColor(victim.status),
                              icon: statusIcon(victim.status),
                            ),
                            if (victim.syncStatus == SyncStatus.pending)
                              const StatusChip(
                                label: 'SYNC PENDING',
                                color: AppColors.elevated,
                                icon: Icons.cloud_upload_outlined,
                              ),
                          ],
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

  static String _subtitle(Victim victim) {
    final age = victim.age == null
        ? victim.ageGroup.label
        : '${victim.age} · ${victim.ageGroup.label}';
    return '${victim.temporaryId} · $age · ${victim.gender.label}';
  }
}
