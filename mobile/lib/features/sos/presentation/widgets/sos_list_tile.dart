import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../domain/entities/sos_event.dart';
import '../../../../shared/widgets/ops_visuals.dart';
import '../../../../shared/widgets/status_chip.dart';

/// One distress call in the history.
class SosListTile extends StatelessWidget {
  const SosListTile({required this.event, required this.onTap, super.key});

  final SosEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final priorityColor = sosPriorityColor(event.priority);
    final position = event.position;

    return Semantics(
      button: true,
      label: '${event.sosCode}, ${event.priority.label} priority, '
          '${event.status.label}',
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 3, color: priorityColor),
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
                                event.sosCode,
                                style: const TextStyle(
                                  color: AppColors.ink100,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            Text(
                              event.raisedAt.toLocal().toString().substring(
                                    0,
                                    16,
                                  ),
                              style: const TextStyle(
                                color: AppColors.ink500,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        if (event.message != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            event.message!,
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
                              label: event.priority.wireValue,
                              color: priorityColor,
                            ),
                            StatusChip(
                              label: event.status.label.toUpperCase(),
                              color: sosStatusColor(event.status),
                            ),
                            SyncStatusChip(event.syncStatus),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          position == null
                              ? 'No position attached'
                              : '${position.latitudeLabel}  '
                                  '${position.longitudeLabel} · accuracy '
                                  '${position.accuracyLabel}',
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
