import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../domain/entities/sos_event.dart';
import '../../../domain/entities/sos_status.dart';
import '../../../shared/widgets/detail_row.dart';
import '../../../shared/widgets/operational_panel.dart';
import '../../../shared/widgets/ops_visuals.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../incidents/application/incident_providers.dart';
import '../application/sos_providers.dart';

/// One distress call, and the actions the raising responder can take on it.
class SosDetailScreen extends ConsumerWidget {
  const SosDetailScreen({required this.sosId, super.key});

  final String sosId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = ref.watch(sosEventProvider(sosId));

    return Scaffold(
      appBar: AppBar(title: Text(event.value?.sosCode ?? 'SOS')),
      body: SafeArea(
        child: event.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => CenteredMessage(text: error.toString()),
          data: (record) => record == null
              ? const CenteredMessage(
                  text: 'This SOS is not held on this device.',
                )
              : _SosDetail(event: record),
        ),
      ),
    );
  }
}

class _SosDetail extends ConsumerWidget {
  const _SosDetail({required this.event});

  final SosEvent event;

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    SosStatus status,
  ) async {
    await ref.read(sosServiceProvider).changeStatus(event, status);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.navy800,
        content: Text('${event.sosCode} marked ${status.label.toLowerCase()}'),
      ),
    );
  }

  String _incidentLabel(WidgetRef ref) {
    final incidentId = event.incidentId;
    if (incidentId == null) {
      return 'Not linked — no incident was selected on this device when the '
          'call was raised';
    }

    final incident = ref.watch(incidentProvider(incidentId)).value;
    return incident == null
        ? incidentId
        : '${incident.incidentCode} · ${incident.title}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priorityColor = sosPriorityColor(event.priority);
    final position = event.position;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          event.sosCode,
          style: const TextStyle(
            color: AppColors.ink100,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusChip(label: event.priority.wireValue, color: priorityColor),
            StatusChip(
              label: event.status.label.toUpperCase(),
              color: sosStatusColor(event.status),
            ),
            SyncStatusChip(event.syncStatus),
            const StatusChip(
              label: 'LOCAL DATA',
              color: AppColors.accentSoft,
              icon: Icons.sd_storage_outlined,
            ),
          ],
        ),
        const SizedBox(height: 18),

        OperationalPanel(
          label: 'Priority',
          value: event.priority.label,
          detail: event.priority.guidance,
          accent: priorityColor,
        ),
        const SizedBox(height: 10),
        OperationalPanel(
          label: 'Position',
          value: position == null
              ? 'Not attached'
              : '${position.latitudeLabel}  ${position.longitudeLabel}',
          detail: position == null
              ? 'The device had no reading when the call was raised. The call '
                  'was stored anyway.'
              : 'Accuracy ${position.accuracyLabel} · taken '
                  '${position.timeLabel}',
          accent: position == null ? AppColors.ink500 : AppColors.accent,
        ),

        if (event.message != null) ...[
          const SizedBox(height: 10),
          OperationalPanel(
            label: 'Message',
            value: event.message!,
            accent: AppColors.ink400,
          ),
        ],

        const SizedBox(height: 20),
        const FieldLabel('Update status'),
        const SizedBox(height: 4),
        const Text(
          'Recorded on this device only. Acknowledgement here means somebody '
          'told you over the radio that the call was heard.',
          style: TextStyle(color: AppColors.ink500, fontSize: 11, height: 1.45),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final status in SosStatus.values)
              if (status != event.status)
                OutlinedButton(
                  onPressed: () => _setStatus(context, ref, status),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    foregroundColor: sosStatusColor(status),
                    side: BorderSide(
                      color: sosStatusColor(status).withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text('Mark ${status.label}'),
                ),
          ],
        ),

        const SizedBox(height: 24),
        const FieldLabel('Record'),
        const SizedBox(height: 8),
        DetailRow(label: 'SOS code', value: event.sosCode),
        DetailRow(label: 'Record id', value: event.id),
        DetailRow(label: 'Incident', value: _incidentLabel(ref)),
        DetailRow(
          label: 'Raised at',
          value: '${event.raisedAt.toIso8601String()} UTC',
        ),
        DetailRow(
          label: 'Last updated',
          value: '${event.updatedAt.toIso8601String()} UTC',
        ),
        DetailRow(label: 'Raised by', value: event.createdBy),
        DetailRow(label: 'Data', value: 'LOCAL'),

        const SizedBox(height: 22),
        const Text(
          'This call lives in the local SQLite database. It has not been sent: '
          'there is no transport in this build, and the record exists so that '
          'the event is timestamped, positioned and recoverable.',
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
