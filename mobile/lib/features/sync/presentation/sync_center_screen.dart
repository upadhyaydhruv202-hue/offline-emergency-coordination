import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../hazards/application/hazard_providers.dart';
import '../application/road_r12_demo.dart';
import '../application/sync_providers.dart';
import '../application/sync_service.dart';
import 'widgets/sync_architecture_visual.dart';

class SyncCenterScreen extends ConsumerStatefulWidget {
  const SyncCenterScreen({super.key});

  @override
  ConsumerState<SyncCenterScreen> createState() => _SyncCenterScreenState();
}

class _SyncCenterScreenState extends ConsumerState<SyncCenterScreen> {
  String? _demoLog;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(syncStatisticsProvider);
    final pending = ref.watch(syncOperationsProvider).value ?? [];
    final conflicts = ref.watch(syncConflictsProvider).value ?? [];
    final localHazard = ref.watch(hazardProvider(RoadR12Demo.entityId)).value;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        const StatusChip(
          label: 'DEVELOPMENT / DEMO TOOL',
          color: AppColors.elevated,
          icon: Icons.science_outlined,
        ),
        const SizedBox(height: 8),
        const Text(
          'Simulated synchronisation. This is not mesh, BLE, or a live peer '
          'network. Both devices use the same CRDT engine the eventual '
          'transport will call.',
          style: TextStyle(color: AppColors.ink400, height: 1.45),
        ),
        const SizedBox(height: 16),
        const SyncArchitectureVisual(),
        const SizedBox(height: 16),
        stats.when(
          data: (value) => _StatsCard(stats: value, conflicts: conflicts.length),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('$error'),
        ),
        if (localHazard != null) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('Road R-12 on this device'),
              subtitle: Text(
                '${localHazard.type.label} · ${localHazard.severity.label}',
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _runDemo,
          child: Text(_busy ? 'Running…' : 'SIMULATE SYNC (Road R-12)'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => context.push(AppRoute.syncConflicts.path),
          child: Text('VIEW CONFLICTS (${conflicts.length})'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => context.push(AppRoute.syncPending.path),
          child: Text('VIEW PENDING (${pending.length})'),
        ),
        if (kDebugMode) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : _confirmReset,
            child: const Text('RESET DEMO'),
          ),
        ],
        if (_demoLog != null) ...[
          const SizedBox(height: 16),
          Text(_demoLog!, style: const TextStyle(color: AppColors.ink200, height: 1.5)),
        ],
      ],
    );
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset demo queue?'),
        content: const Text(
          'Deletes local sync operations and conflict records on this device. '
          'Operational incidents and hazards are kept. Development only.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(syncOperationDaoProvider).deleteAll();
    await ref.read(syncConflictDaoProvider).deleteAll();
    await ref.read(syncEntityHeadDaoProvider).deleteAll();
    ref.invalidate(syncStatisticsProvider);
    setState(() => _demoLog = 'Demo queue cleared.');
  }

  Future<void> _runDemo() async {
    setState(() => _busy = true);
    try {
      final run = await runRoadR12Scenario();
      final winner = run.result.winners[RoadR12Demo.entityId];
      final type = winner?.payload['type'];
      final severity = winner?.payload['severity'];
      final exchanged = [
        ...await run.a.operations.readAll(),
        ...await run.b.operations.readAll(),
      ];
      await run.a.close();
      await run.b.close();
      await ref.read(syncServiceProvider).applyRemoteOperations(exchanged);
      ref.invalidate(syncStatisticsProvider);
      if (!mounted) return;
      setState(() {
        _demoLog =
            'CONFLICT DETECTED on Road R-12.\n'
            'Resolution: DETERMINISTIC MERGE (${run.result.conflicts.isEmpty ? 'none' : run.result.conflicts.first.resolution.wireValue}).\n'
            'Winner device: ${winner?.deviceId}\n'
            'Final state: $type / $severity\n'
            'Both isolated databases converged. SIMULATED SYNC — not mesh.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _demoLog = 'Demo failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats, required this.conflicts});

  final SyncStatistics stats;
  final int conflicts;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DEVICE ${stats.deviceId}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('PENDING ${stats.pending}'),
            Text('ACKNOWLEDGED ${stats.acknowledged}'),
            Text('CONFLICTS $conflicts'),
            Text(
              'LAST SYNC ${stats.lastSyncAt?.toIso8601String() ?? 'Never'}'
              '${stats.lastSyncKind == null ? '' : ' · ${stats.lastSyncKind}'}',
            ),
            Text('LOCAL OPERATIONS ${stats.localRecordCount}'),
          ],
        ),
      ),
    );
  }
}
