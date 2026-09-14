import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../domain/entities/field_task.dart';
import '../../../domain/entities/task_status.dart';
import '../../../shared/widgets/detail_row.dart';
import '../../../shared/widgets/operational_panel.dart';
import '../../../shared/widgets/ops_visuals.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../incidents/application/incident_providers.dart';
import '../application/task_providers.dart';

/// One task, and its lifecycle.
///
/// The next step is a single large button because in the field it is pressed
/// with one hand while the other is holding something. Cancelling is available
/// but deliberately quieter.
class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({required this.taskId, super.key});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(taskProvider(taskId));

    return Scaffold(
      appBar: AppBar(title: Text(task.value?.taskCode ?? 'Task')),
      body: SafeArea(
        child: task.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => CenteredMessage(text: error.toString()),
          data: (record) => record == null
              ? const CenteredMessage(
                  text: 'This task is not held on this device.',
                )
              : _TaskDetail(task: record),
        ),
      ),
    );
  }
}

class _TaskDetail extends ConsumerWidget {
  const _TaskDetail({required this.task});

  final FieldTask task;

  Future<void> _advance(BuildContext context, WidgetRef ref) async {
    final next = task.status.next;
    if (next == null) return;

    await ref.read(taskServiceProvider).changeStatus(task, next);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.navy800,
        content: Text('${task.taskCode} is now ${next.label.toLowerCase()}'),
      ),
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.navy900,
        title: const Text('Cancel this task?', style: TextStyle(fontSize: 16)),
        content: Text(
          '${task.taskCode} will be recorded as cancelled on this device. The '
          'record is kept either way.',
          style: const TextStyle(
            color: AppColors.ink300,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('KEEP'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('CANCEL TASK'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref
        .read(taskServiceProvider)
        .changeStatus(task, TaskStatus.cancelled);
  }

  String _incidentLabel(WidgetRef ref) {
    final incidentId = task.incidentId;
    if (incidentId == null) {
      return 'Not linked — no incident was selected on this device when the '
          'task was raised';
    }

    final incident = ref.watch(incidentProvider(incidentId)).value;
    return incident == null
        ? incidentId
        : '${incident.incidentCode} · ${incident.title}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priorityColor = taskPriorityColor(task.priority);
    final nextLabel = task.status.nextActionLabel;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          '#${task.taskCode}',
          style: const TextStyle(
            color: AppColors.ink500,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          task.title,
          style: const TextStyle(
            color: AppColors.ink100,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusChip(label: task.priority.wireValue, color: priorityColor),
            StatusChip(
              label: task.status.label.toUpperCase(),
              color: taskStatusColor(task.status),
            ),
            SyncStatusChip(task.syncStatus),
            const StatusChip(
              label: 'LOCAL DATA',
              color: AppColors.accentSoft,
              icon: Icons.sd_storage_outlined,
            ),
          ],
        ),
        const SizedBox(height: 18),

        if (nextLabel != null)
          FilledButton(
            onPressed: () => _advance(context, ref),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(nextLabel.toUpperCase()),
          )
        else
          OperationalPanel(
            label: 'Lifecycle',
            value: task.status.label,
            detail: 'No further action. The record stays on this device.',
            accent: taskStatusColor(task.status),
          ),

        if (!task.status.isClosed) ...[
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => _cancel(context, ref),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              foregroundColor: AppColors.ink400,
            ),
            child: const Text('Cancel task'),
          ),
        ],

        const SizedBox(height: 20),
        OperationalPanel(
          label: 'Priority',
          value: task.priority.label,
          detail: task.location ?? 'No location recorded',
          accent: priorityColor,
        ),

        if (task.description != null) ...[
          const SizedBox(height: 10),
          OperationalPanel(
            label: 'Detail',
            value: task.description!,
            accent: AppColors.ink400,
          ),
        ],

        const SizedBox(height: 24),
        const FieldLabel('Record'),
        const SizedBox(height: 8),
        DetailRow(label: 'Task code', value: task.taskCode),
        DetailRow(label: 'Record id', value: task.id),
        DetailRow(label: 'Incident', value: _incidentLabel(ref)),
        DetailRow(
          label: 'Assigned to',
          value: task.assignedTo ?? 'Unassigned',
        ),
        DetailRow(
          label: 'Location',
          value: task.location ?? 'Not recorded',
        ),
        DetailRow(
          label: 'Raised',
          value: '${task.createdAt.toIso8601String()} UTC',
        ),
        DetailRow(
          label: 'Last updated',
          value: '${task.updatedAt.toIso8601String()} UTC',
        ),
        DetailRow(label: 'Data', value: 'LOCAL'),

        const SizedBox(height: 22),
        const Text(
          'Every status change is written to the local SQLite database and '
          'survives a restart. Nothing here waits on the command centre.',
          style: TextStyle(
            color: AppColors.ink500,
            fontSize: 11,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
