import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../domain/entities/sync_conflict.dart';
import '../../../shared/widgets/status_chip.dart';
import '../application/road_r12_demo.dart';
import '../application/sync_providers.dart';

class SyncConflictDetailScreen extends ConsumerWidget {
  const SyncConflictDetailScreen({required this.conflictId, super.key});

  final String conflictId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflicts = ref.watch(syncConflictsProvider).value ?? [];
    SyncConflict? item;
    for (final candidate in conflicts) {
      if (candidate.id == conflictId) {
        item = candidate;
        break;
      }
    }
    if (item == null) {
      return const Center(child: Text('Conflict not on this device.'));
    }
    final a = item.operationA;
    final b = item.operationB;
    final winner = item.winnerOperation;
    final road = item.entityId == RoadR12Demo.entityId;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const StatusChip(
          label: 'CONFLICT DETECTED',
          color: AppColors.critical,
          icon: Icons.warning_amber_outlined,
        ),
        const SizedBox(height: 12),
        Text(
          road ? 'ROAD R-12' : item.entityType.wireValue,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const Divider(height: 32),
        _Side(
          title: 'DEVICE ${a.deviceId}',
          type: '${a.payload['type'] ?? a.operationType.wireValue}',
          severity: '${a.payload['severity'] ?? ''}',
          at: a.createdAt,
        ),
        const Divider(height: 32),
        _Side(
          title: 'DEVICE ${b.deviceId}',
          type: '${b.payload['type'] ?? b.operationType.wireValue}',
          severity: '${b.payload['severity'] ?? ''}',
          at: b.createdAt,
        ),
        const Divider(height: 32),
        const Text('RESOLUTION', style: TextStyle(fontWeight: FontWeight.w700)),
        Text(item.resolution.wireValue.replaceAll('_', ' ')),
        const SizedBox(height: 8),
        Text('WINNER: ${winner.deviceId}'),
        Text(
          'FINAL STATE: ${winner.payload['type']} · ${winner.payload['severity']}',
        ),
        const SizedBox(height: 8),
        Text(item.reason, style: const TextStyle(color: AppColors.ink400)),
        const SizedBox(height: 16),
        const StatusChip(
          label: 'DEVICES CONVERGED · SIMULATED SYNC',
          color: AppColors.nominal,
          icon: Icons.check,
        ),
      ],
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({
    required this.title,
    required this.type,
    required this.severity,
    required this.at,
  });

  final String title;
  final String type;
  final String severity;
  final DateTime at;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(type.replaceAll('_', ' ')),
        if (severity.isNotEmpty) Text(severity),
        Text(
          at.toUtc().toIso8601String(),
          style: const TextStyle(color: AppColors.ink500, fontSize: 12),
        ),
      ],
    );
  }
}
