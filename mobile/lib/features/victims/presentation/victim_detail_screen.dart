import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../domain/entities/sync_status.dart';
import '../../../domain/entities/triage_category.dart';
import '../../../domain/entities/victim.dart';
import '../../../domain/entities/victim_status.dart';
import '../../../shared/widgets/operational_panel.dart';
import '../../../shared/widgets/status_chip.dart';
import '../application/victim_providers.dart';
import 'widgets/triage_selector.dart';
import 'widgets/victim_visuals.dart';

/// One casualty record, and the actions a responder can take on it.
///
/// Reassessment and status changes are one tap each: in the field they happen
/// far more often than a full edit, and making them cheap is what keeps the
/// record honest.
class VictimDetailScreen extends ConsumerWidget {
  const VictimDetailScreen({required this.victimId, super.key});

  final String victimId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final victim = ref.watch(victimProvider(victimId));

    return Scaffold(
      appBar: AppBar(
        title: Text(victim.value?.temporaryId ?? 'Victim'),
        actions: [
          if (victim.value != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit record',
              onPressed: () =>
                  context.push(AppRoute.victimEditPath(victimId)),
            ),
        ],
      ),
      body: SafeArea(
        child: victim.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _Message(text: error.toString()),
          data: (record) => record == null
              ? const _Message(
                  text: 'This record is not held on this device.',
                )
              : _VictimDetail(victim: record),
        ),
      ),
    );
  }
}

class _VictimDetail extends ConsumerWidget {
  const _VictimDetail({required this.victim});

  final Victim victim;

  Future<void> _reassess(BuildContext context, WidgetRef ref) async {
    final category = await showModalBottomSheet<TriageCategory>(
      context: context,
      backgroundColor: AppColors.navy900,
      builder: (context) => _ReassessSheet(current: victim.triageCategory),
    );
    if (category == null || category == victim.triageCategory) return;

    await ref.read(victimEditorProvider).reassess(victim, category);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.navy800,
        content: Text('Triage reassessed as ${category.wireValue}'),
      ),
    );
  }

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    VictimStatus status,
  ) async {
    await ref.read(victimEditorProvider).changeStatus(victim, status);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.navy800,
        content: Text('Status set to ${status.label}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final severity = triageColor(victim.triageCategory);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          victim.displayName,
          style: const TextStyle(
            color: AppColors.ink100,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusChip(label: victim.triageCategory.wireValue, color: severity),
            StatusChip(
              label: victim.status.label.toUpperCase(),
              color: statusColor(victim.status),
              icon: statusIcon(victim.status),
            ),
            StatusChip(
              label: victim.syncStatus == SyncStatus.pending
                  ? 'SYNC PENDING'
                  : 'SYNCED',
              color: victim.syncStatus == SyncStatus.pending
                  ? AppColors.elevated
                  : AppColors.nominal,
              icon: Icons.cloud_upload_outlined,
            ),
            const StatusChip(
              label: 'LOCAL DATA',
              color: AppColors.accentSoft,
              icon: Icons.sd_storage_outlined,
            ),
          ],
        ),
        const SizedBox(height: 18),

        OperationalPanel(
          label: 'Triage',
          value: victim.triageCategory.label,
          detail: victim.triageCategory.guidance,
          accent: severity,
          trailing: TextButton(
            onPressed: () => _reassess(context, ref),
            child: const Text('Reassess'),
          ),
        ),
        const SizedBox(height: 10),
        OperationalPanel(
          label: 'Status',
          value: victim.status.label,
          detail: 'Field id ${victim.temporaryId}',
          accent: statusColor(victim.status),
        ),

        const SizedBox(height: 20),
        const FieldLabel('Move status'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final status in VictimStatus.values)
              if (status != victim.status)
                OutlinedButton(
                  onPressed: () => _setStatus(context, ref, status),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    foregroundColor: statusColor(status),
                    side: BorderSide(
                      color: statusColor(status).withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    status == VictimStatus.evacuated
                        ? 'Mark Evacuated'
                        : status.label,
                  ),
                ),
          ],
        ),

        const SizedBox(height: 24),
        const FieldLabel('Record'),
        const SizedBox(height: 8),
        _DetailRow(label: 'Field id', value: victim.temporaryId),
        _DetailRow(label: 'Record id', value: victim.id),
        _DetailRow(
          label: 'Age',
          value: victim.age == null
              ? victim.ageGroup.label
              : '${victim.age} · ${victim.ageGroup.label}',
        ),
        _DetailRow(label: 'Gender', value: victim.gender.label),
        _DetailRow(
          label: 'Injury',
          value: victim.injuryType ?? 'Not recorded',
        ),
        _DetailRow(
          label: 'Condition',
          value: victim.medicalCondition ?? 'Not recorded',
        ),
        _DetailRow(
          label: 'Assistance',
          value: victim.assistanceRequired ?? 'Not recorded',
        ),
        _DetailRow(
          label: 'Position',
          value: victim.hasPosition
              ? '${victim.latitude}, ${victim.longitude}'
              : 'Not recorded — positions arrive with the spatial slice',
        ),
        _DetailRow(
          label: 'Registered',
          value: '${victim.createdAt.toIso8601String()} UTC',
        ),
        _DetailRow(
          label: 'Last updated',
          value: '${victim.updatedAt.toIso8601String()} UTC',
        ),
        _DetailRow(label: 'Authored by', value: victim.createdBy),

        const SizedBox(height: 22),
        const Text(
          'This record lives in the local SQLite database. It survives a '
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

class _ReassessSheet extends StatelessWidget {
  const _ReassessSheet({required this.current});

  final TriageCategory current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Reassess triage',
              style: TextStyle(
                color: AppColors.ink100,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            // The sheet is capped at half the screen; on a short handset the
            // four options have to scroll rather than be clipped.
            Flexible(
              child: SingleChildScrollView(
                child: TriageSelector(
                  selected: current,
                  onChanged: (category) => Navigator.of(context).pop(category),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.ink500, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.ink200,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.ink400, fontSize: 13),
        ),
      ),
    );
  }
}
