import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../domain/entities/field_task.dart';
import '../../../../shared/widgets/ops_visuals.dart';
import '../../../../shared/widgets/status_chip.dart';

/// One task in the list.
///
/// Laid out to be scanned rather than read: code, title, then priority and
/// status as chips, which is the order a responder checking their next job
/// actually needs.
class TaskListTile extends StatelessWidget {
  const TaskListTile({
    required this.task,
    required this.onTap,
    this.dense = false,
    super.key,
  });

  final FieldTask task;
  final VoidCallback onTap;

  /// Trims the tile for the home dashboard, where space is scarce.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final priorityColor = taskPriorityColor(task.priority);

    return Semantics(
      button: true,
      label: '${task.taskCode}, ${task.title}, ${task.priority.label} '
          'priority, ${task.status.label}',
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
                    padding: EdgeInsets.fromLTRB(14, dense ? 10 : 12, 12,
                        dense ? 10 : 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${task.taskCode}',
                          style: const TextStyle(
                            color: AppColors.ink500,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          task.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.ink100,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            StatusChip(
                              label: task.priority.wireValue,
                              color: priorityColor,
                            ),
                            StatusChip(
                              label: task.status.label.toUpperCase(),
                              color: taskStatusColor(task.status),
                            ),
                            if (!dense) SyncStatusChip(task.syncStatus),
                          ],
                        ),
                        if (!dense && task.location != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            task.location!,
                            style: const TextStyle(
                              color: AppColors.ink500,
                              fontSize: 11,
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
