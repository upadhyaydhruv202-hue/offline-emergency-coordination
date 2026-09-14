import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../domain/entities/hazard.dart';
import '../../../domain/entities/hazard_status.dart';
import '../../../shared/widgets/detail_row.dart';
import '../../../shared/widgets/operational_panel.dart';
import '../../../shared/widgets/ops_visuals.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../incidents/application/incident_providers.dart';
import '../application/hazard_providers.dart';

/// One hazard report, and the actions a responder can take on it.
class HazardDetailScreen extends ConsumerWidget {
  const HazardDetailScreen({required this.hazardId, super.key});

  final String hazardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hazard = ref.watch(hazardProvider(hazardId));

    return Scaffold(
      appBar: AppBar(
        title: Text(hazard.value?.hazardCode ?? 'Hazard'),
        actions: [
          if (hazard.value != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit report',
              onPressed: () => context.push(AppRoute.hazardEditPath(hazardId)),
            ),
        ],
      ),
      body: SafeArea(
        child: hazard.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => CenteredMessage(text: error.toString()),
          data: (record) => record == null
              ? const CenteredMessage(
                  text: 'This hazard is not held on this device.',
                )
              : _HazardDetail(hazard: record),
        ),
      ),
    );
  }
}

class _HazardDetail extends ConsumerWidget {
  const _HazardDetail({required this.hazard});

  final Hazard hazard;

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    HazardStatus status,
  ) async {
    await ref.read(hazardServiceProvider).changeStatus(hazard, status);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.navy800,
        content: Text('${hazard.hazardCode} marked ${status.label.toLowerCase()}'),
      ),
    );
  }

  String _incidentLabel(WidgetRef ref) {
    final incidentId = hazard.incidentId;
    if (incidentId == null) {
      return 'Not linked — no incident was selected on this device when the '
          'hazard was reported';
    }

    final incident = ref.watch(incidentProvider(incidentId)).value;
    return incident == null
        ? incidentId
        : '${incident.incidentCode} · ${incident.title}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final severityColor = hazardSeverityColor(hazard.severity);
    final position = hazard.position;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(
          children: [
            Icon(hazardTypeIcon(hazard.type), size: 26, color: severityColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hazard.type.label,
                    style: const TextStyle(
                      color: AppColors.ink100,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    hazard.hazardCode,
                    style: const TextStyle(
                      color: AppColors.ink400,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusChip(label: hazard.severity.wireValue, color: severityColor),
            StatusChip(
              label: hazard.status.label.toUpperCase(),
              color: hazardStatusColor(hazard.status),
            ),
            SyncStatusChip(hazard.syncStatus),
            const StatusChip(
              label: 'LOCAL DATA',
              color: AppColors.accentSoft,
              icon: Icons.sd_storage_outlined,
            ),
          ],
        ),
        const SizedBox(height: 18),

        OperationalPanel(
          label: 'Severity',
          value: hazard.severity.label,
          detail: hazard.severity.guidance,
          accent: severityColor,
        ),
        const SizedBox(height: 10),
        OperationalPanel(
          label: 'Position',
          value: position == null
              ? 'Not attached'
              : '${position.latitudeLabel}  ${position.longitudeLabel}',
          detail: position == null
              ? 'The device had no reading when the report was filed.'
              : 'Accuracy ${position.accuracyLabel} · taken '
                  '${position.timeLabel}',
          accent: position == null ? AppColors.ink500 : AppColors.accent,
        ),

        if (hazard.description != null) ...[
          const SizedBox(height: 10),
          OperationalPanel(
            label: 'Description',
            value: hazard.description!,
            accent: AppColors.ink400,
          ),
        ],

        const SizedBox(height: 20),
        const FieldLabel('Update status'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final status in HazardStatus.values)
              if (status != hazard.status)
                OutlinedButton(
                  onPressed: () => _setStatus(context, ref, status),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    foregroundColor: hazardStatusColor(status),
                    side: BorderSide(
                      color: hazardStatusColor(status).withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text('Mark ${status.label}'),
                ),
          ],
        ),

        const SizedBox(height: 24),
        const FieldLabel('Record'),
        const SizedBox(height: 8),
        DetailRow(label: 'Hazard code', value: hazard.hazardCode),
        DetailRow(label: 'Record id', value: hazard.id),
        DetailRow(label: 'Type', value: hazard.type.label),
        DetailRow(label: 'Incident', value: _incidentLabel(ref)),
        DetailRow(
          label: 'Observed',
          value: '${hazard.observedAt.toIso8601String()} UTC',
        ),
        DetailRow(
          label: 'Last updated',
          value: '${hazard.updatedAt.toIso8601String()} UTC',
        ),
        DetailRow(label: 'Reported by', value: hazard.reportedBy),
        DetailRow(label: 'Data', value: 'LOCAL'),

        const SizedBox(height: 22),
        const Text(
          'This report lives in the local SQLite database. It survives a '
          'restart, an airplane-mode toggle and a dead uplink, and it does not '
          'become more authoritative once it synchronises.',
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
