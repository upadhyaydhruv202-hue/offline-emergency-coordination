import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../domain/entities/incident.dart';
import '../../../domain/entities/incident_status.dart';
import '../../../shared/widgets/detail_row.dart';
import '../../../shared/widgets/operational_panel.dart';
import '../../../shared/widgets/ops_visuals.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../connectivity/connectivity_providers.dart';
import '../../connectivity/connectivity_status.dart';
import '../application/incident_providers.dart';

/// One incident, and the actions a responder can take on it.
class IncidentDetailScreen extends ConsumerWidget {
  const IncidentDetailScreen({required this.incidentId, super.key});

  final String incidentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incident = ref.watch(incidentProvider(incidentId));

    return Scaffold(
      appBar: AppBar(
        title: Text(incident.value?.incidentCode ?? 'Incident'),
        actions: [
          if (incident.value != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit incident',
              onPressed: () =>
                  context.push(AppRoute.incidentEditPath(incidentId)),
            ),
        ],
      ),
      body: SafeArea(
        child: incident.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => CenteredMessage(text: error.toString()),
          data: (record) => record == null
              ? const CenteredMessage(
                  text: 'This incident is not held on this device.',
                )
              : _IncidentDetail(incident: record),
        ),
      ),
    );
  }
}

class _IncidentDetail extends ConsumerWidget {
  const _IncidentDetail({required this.incident});

  final Incident incident;

  Future<void> _select(BuildContext context, WidgetRef ref) async {
    await ref.read(incidentServiceProvider).select(incident);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.navy800,
        content: Text(
          '${incident.incidentCode} is now the current operation on this device',
        ),
      ),
    );
  }

  Future<void> _standDown(BuildContext context, WidgetRef ref) async {
    await ref.read(incidentServiceProvider).standDown();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.navy800,
        content: Text(
          'No current operation. Records captured now will not be scoped to an '
          'incident.',
        ),
      ),
    );
  }

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    IncidentStatus status,
  ) async {
    await ref.read(incidentServiceProvider).changeStatus(incident, status);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.navy800,
        content: Text('Incident status set to ${status.label}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCurrent = ref.watch(currentIncidentProvider).value?.id == incident.id;
    final connectivity = ref.watch(connectivityStatusProvider).value;
    final statusColor = incidentStatusColor(incident.status);

    final (connectivityColor, connectivityLabel) = switch (connectivity) {
      ConnectivityStatus.online => (AppColors.nominal, 'ONLINE'),
      ConnectivityStatus.degraded => (AppColors.elevated, 'DEGRADED'),
      ConnectivityStatus.offline => (AppColors.critical, 'OFFLINE'),
      null => (AppColors.ink500, 'CHECKING'),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          incident.title,
          style: const TextStyle(
            color: AppColors.ink100,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          incident.incidentCode,
          style: const TextStyle(
            color: AppColors.ink400,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusChip(label: incident.status.wireValue, color: statusColor),
            StatusChip(
              label: incident.disasterType.label.toUpperCase(),
              color: AppColors.ink400,
            ),
            if (isCurrent)
              const StatusChip(
                label: 'CURRENT OPERATION',
                color: AppColors.accent,
                icon: Icons.my_location,
              ),
            StatusChip(
              label: connectivityLabel,
              color: connectivityColor,
              icon: Icons.wifi_tethering,
            ),
            SyncStatusChip(incident.syncStatus),
            const StatusChip(
              label: 'LOCAL DATA',
              color: AppColors.accentSoft,
              icon: Icons.sd_storage_outlined,
            ),
          ],
        ),
        const SizedBox(height: 18),

        OperationalPanel(
          label: 'Assigned zone',
          value: incident.zoneLabel,
          detail: incident.disasterType.label,
          accent: AppColors.accent,
        ),
        const SizedBox(height: 10),
        OperationalPanel(
          label: 'Status',
          value: incident.status.label,
          detail: isCurrent
              ? 'This device is operating in this incident.'
              : 'This device is not currently operating in this incident.',
          accent: statusColor,
        ),

        const SizedBox(height: 20),
        if (isCurrent)
          OutlinedButton.icon(
            onPressed: () => _standDown(context, ref),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Stand down from this incident'),
          )
        else
          FilledButton.icon(
            onPressed: incident.status.isSelectable
                ? () => _select(context, ref)
                : null,
            icon: const Icon(Icons.my_location, size: 18),
            label: const Text('Set as current operation'),
          ),
        if (!isCurrent && !incident.status.isSelectable) ...[
          const SizedBox(height: 8),
          Text(
            'Only an active incident can be adopted. This one is '
            '${incident.status.label.toLowerCase()}.',
            style: const TextStyle(
              color: AppColors.ink500,
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ],

        const SizedBox(height: 24),
        const FieldLabel('Change status'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final status in IncidentStatus.values)
              if (status != incident.status)
                OutlinedButton(
                  onPressed: () => _setStatus(context, ref, status),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    foregroundColor: incidentStatusColor(status),
                    side: BorderSide(
                      color: incidentStatusColor(status)
                          .withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text('Mark ${status.label}'),
                ),
          ],
        ),

        const SizedBox(height: 24),
        const FieldLabel('Record'),
        const SizedBox(height: 8),
        DetailRow(label: 'Incident code', value: incident.incidentCode),
        DetailRow(label: 'Record id', value: incident.id),
        DetailRow(label: 'Disaster type', value: incident.disasterType.label),
        DetailRow(
          label: 'Description',
          value: incident.description ?? 'Not recorded',
        ),
        DetailRow(
          label: 'Location',
          value: incident.hasPosition
              ? '${incident.latitude!.toStringAsFixed(4)}, '
                  '${incident.longitude!.toStringAsFixed(4)}'
              : 'Not recorded',
        ),
        DetailRow(
          label: 'Declared',
          value: '${incident.createdAt.toIso8601String()} UTC',
        ),
        DetailRow(
          label: 'Last updated',
          value: '${incident.updatedAt.toIso8601String()} UTC',
        ),
        DetailRow(label: 'Declared by', value: incident.createdBy),
        DetailRow(
          label: 'Last change by',
          value: incident.lastModifiedBy ?? incident.createdBy,
        ),
        DetailRow(label: 'Data', value: 'LOCAL'),

        const SizedBox(height: 22),
        const Text(
          'This incident lives in the local SQLite database. Adopting it as the '
          'current operation is also stored locally, so the selection survives '
          'the application being closed and reopened.',
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
