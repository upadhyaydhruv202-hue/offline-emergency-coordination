import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/local/database_providers.dart';
import '../../../data/local/local_database_health.dart';
import '../../../domain/entities/field_ops_boards.dart';
import '../../../domain/entities/field_task.dart';
import '../../../domain/entities/gps_status.dart';
import '../../../domain/entities/incident.dart';
import '../../../domain/entities/location_record.dart';
import '../../../domain/entities/responder.dart';
import '../../../domain/entities/responder_status.dart';
import '../../../domain/entities/triage_category.dart';
import '../../../domain/entities/victim_board.dart';
import '../../../shared/widgets/count_tile.dart';
import '../../../shared/widgets/operational_panel.dart';
import '../../../shared/widgets/ops_visuals.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../connectivity/connectivity_providers.dart';
import '../../connectivity/connectivity_status.dart';
import '../../hazards/application/hazard_providers.dart';
import '../../incidents/application/incident_providers.dart';
import '../../location/application/location_providers.dart';
import '../../responder/application/responder_status_providers.dart';
import '../../responder/presentation/widgets/responder_status_sheet.dart';
import '../../sync/application/pending_changes_provider.dart';
import '../../tasks/application/task_providers.dart';
import '../../victims/application/victim_providers.dart';

/// The operational field dashboard: who is holding the device, what they are
/// working on, and what they have captured locally.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responder = ref.watch(authControllerProvider).responderOrNull;
    final connectivity = ref.watch(connectivityStatusProvider).value;
    final databaseHealth = ref.watch(localDatabaseHealthProvider);
    final incident = ref.watch(currentIncidentProvider).value;
    final status = ref.watch(responderStatusProvider).value ??
        ResponderStatus.initial;
    final location = ref.watch(latestLocationProvider).value;
    final capture = ref.watch(locationCaptureProvider);
    final pending = ref.watch(pendingChangesProvider);
    final victims = ref.watch(victimBoardProvider).value ?? VictimBoard.empty;
    final hazards = ref.watch(hazardBoardProvider).value ?? HazardBoard.empty;
    final tasks = ref.watch(taskBoardProvider).value ?? TaskBoard.empty;
    final activeTasks = ref.watch(activeTasksProvider).value ?? const [];

    if (responder == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(connectivityServiceProvider).refresh();
        ref.invalidate(localDatabaseHealthProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          const FieldLabel('Field responder'),
          const SizedBox(height: 8),
          _ResponderHeader(responder: responder),
          const SizedBox(height: 14),

          _StatusPanel(status: status),
          const SizedBox(height: 10),

          _IncidentPanel(incident: incident),
          const SizedBox(height: 10),

          _ConnectivityPanel(
            status: connectivity,
            pending: pending,
            health: databaseHealth.value,
          ),
          const SizedBox(height: 10),

          _LocationPanel(
            record: location,
            capture: capture,
            session: ref.watch(locationSessionProvider),
            allowMock: ref.watch(locationAllowMockProvider).value ?? false,
            offline: connectivity == ConnectivityStatus.offline,
          ),
          const SizedBox(height: 14),

          _CountsRow(victims: victims, hazards: hazards, tasks: tasks),
          const SizedBox(height: 16),

          _QuickActions(),
          const SizedBox(height: 18),

          _ActiveTasksPanel(tasks: activeTasks),
          const SizedBox(height: 20),

          const _ArchitectureNote(),
        ],
      ),
    );
  }
}

class _ResponderHeader extends StatelessWidget {
  const _ResponderHeader({required this.responder});

  final Responder responder;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                responder.fullName,
                style: const TextStyle(
                  color: AppColors.ink100,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                responder.role.label.toUpperCase(),
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
        if (responder.isOfflineDemo)
          const StatusChip(
            label: 'DEMO SESSION',
            color: AppColors.elevated,
          ),
      ],
    );
  }
}

class _StatusPanel extends ConsumerWidget {
  const _StatusPanel({required this.status});

  final ResponderStatus status;

  Future<void> _change(BuildContext context, WidgetRef ref) async {
    final next = await showModalBottomSheet<ResponderStatus>(
      context: context,
      backgroundColor: AppColors.navy900,
      isScrollControlled: true,
      builder: (context) => ResponderStatusSheet(current: status),
    );
    if (next == null || next == status) return;

    await ref.read(responderStatusServiceProvider).setStatus(next);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.navy800,
        content: Text('Status set to ${next.label} on this device'),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OperationalPanel(
      label: 'Responder status',
      value: status.label.toUpperCase(),
      detail: status.guidance,
      accent: responderStatusColor(status),
      trailing: TextButton(
        onPressed: () => _change(context, ref),
        child: const Text('Change'),
      ),
    );
  }
}

class _IncidentPanel extends StatelessWidget {
  const _IncidentPanel({required this.incident});

  final Incident? incident;

  @override
  Widget build(BuildContext context) {
    final record = incident;
    if (record == null) {
      return OperationalPanel(
        label: 'Current incident',
        value: 'No current operation',
        detail: 'Declare or select an incident. Records captured now will not '
            'be scoped to one.',
        accent: AppColors.ink500,
        trailing: TextButton(
          onPressed: () => context.go(AppRoute.incidents.path),
          child: const Text('Select'),
        ),
      );
    }

    return OperationalPanel(
      label: 'Current incident',
      value: record.title,
      detail: '${record.incidentCode}\n${record.zoneLabel}',
      accent: incidentStatusColor(record.status),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          StatusChip(
            label: record.status.wireValue,
            color: incidentStatusColor(record.status),
          ),
          TextButton(
            onPressed: () =>
                context.push(AppRoute.incidentDetailPath(record.id)),
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }
}

class _ConnectivityPanel extends StatelessWidget {
  const _ConnectivityPanel({
    required this.status,
    required this.pending,
    required this.health,
  });

  final ConnectivityStatus? status;
  final int pending;
  final LocalDatabaseHealth? health;

  @override
  Widget build(BuildContext context) {
    final (color, detail) = switch (status) {
      ConnectivityStatus.online => (
          AppColors.nominal,
          'Coordination backend reachable. Synchronisation is not in this slice.',
        ),
      ConnectivityStatus.degraded => (
          AppColors.elevated,
          'A link exists but the backend did not answer. Keep working.',
        ),
      ConnectivityStatus.offline => (
          AppColors.critical,
          'No network interface. This is a supported operating mode.',
        ),
      null => (AppColors.ink500, 'Evaluating available links…'),
    };

    final dbReady = health?.isReady ?? false;
    final pendingLabel = pending == 0
        ? 'NOTHING PENDING'
        : '$pending ${pending == 1 ? 'CHANGE' : 'CHANGES'} PENDING';

    return OperationalPanel(
      label: 'Connectivity',
      value: status?.label ?? 'CHECKING',
      detail: '$detail\n'
          'Local database ${dbReady ? 'READY' : (health?.state.label ?? 'CHECKING')}'
          ' · $pendingLabel',
      accent: color,
      trailing: StatusChip(
        label: dbReady ? 'READY' : (health?.state.label ?? 'CHECKING'),
        color: dbReady ? AppColors.nominal : AppColors.ink500,
      ),
    );
  }
}

class _LocationPanel extends ConsumerWidget {
  const _LocationPanel({
    required this.record,
    required this.capture,
    required this.session,
    required this.allowMock,
    required this.offline,
  });

  final LocationRecord? record;
  final LocationCaptureState capture;
  final LocationSessionState session;
  final bool allowMock;
  final bool offline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classified = classifyCurrentGps(
      record: record,
      session: session,
      capture: capture,
      allowMock: allowMock,
      now: DateTime.now(),
    );
    final shown = classified.record;
    final fix = shown?.fix;
    final status = classified.status;
    final color = switch (status) {
      GpsStatus.liveGps => AppColors.nominal,
      GpsStatus.gpsWeak => AppColors.elevated,
      GpsStatus.lastKnown => AppColors.accent,
      GpsStatus.permissionDenied => AppColors.critical,
      GpsStatus.unavailable => AppColors.ink500,
      GpsStatus.demoMode => AppColors.elevated,
      GpsStatus.mockLocation => AppColors.high,
    };

    final detail = StringBuffer();
    if (fix != null) {
      detail.writeln('Accuracy: ${fix.accuracyLabel}');
      detail.writeln(
        'Updated: ${locationAgeLabel(fix.timestamp, DateTime.now())}',
      );
      detail.writeln('Source: ${fix.source}');
    }
    detail.write(classified.guidance);
    if (offline) {
      detail.write('\nRadio is OFFLINE. GPS does not need the internet.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OperationalPanel(
          label: 'Current location',
          value: fix == null
              ? 'No position recorded'
              : '${fix.latitudeLabel}\n${fix.longitudeLabel}',
          detail: detail.toString().trim(),
          accent: color,
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusChip(label: status.label, color: color),
              if (offline) ...[
                const SizedBox(height: 6),
                const StatusChip(label: 'OFFLINE', color: AppColors.critical),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            key: const Key('home-refresh-location'),
            onPressed: capture.isCapturing
                ? null
                : () => ref.read(locationCaptureProvider.notifier).refresh(),
            icon: capture.isCapturing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_outlined, size: 18),
            label: Text(
              capture.isCapturing ? 'Capturing…' : 'Refresh location',
            ),
          ),
        ),
      ],
    );
  }
}

class _CountsRow extends StatelessWidget {
  const _CountsRow({
    required this.victims,
    required this.hazards,
    required this.tasks,
  });

  final VictimBoard victims;
  final HazardBoard hazards;
  final TaskBoard tasks;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CountTile(
            label: 'ACTIVE TASKS',
            count: tasks.active,
            color: AppColors.accent,
            onTap: () => context.go(AppRoute.tasks.path),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: CountTile(
            label: 'CRITICAL VICTIMS',
            count: victims.countOf(TriageCategory.critical),
            color: AppColors.critical,
            onTap: () => context.go(AppRoute.victims.path),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: CountTile(
            label: 'ACTIVE HAZARDS',
            count: hazards.open,
            color: AppColors.high,
            onTap: () => context.go(AppRoute.hazards.path),
          ),
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('Quick actions'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'REGISTER VICTIM',
                icon: Icons.person_add_alt_1_outlined,
                color: AppColors.accent,
                onTap: () => context.push(AppRoute.victimRegister.path),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                label: 'REPORT HAZARD',
                icon: Icons.report_problem_outlined,
                color: AppColors.high,
                onTap: () => context.push(AppRoute.hazardReport.path),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'CREATE SOS',
                icon: Icons.emergency_outlined,
                color: AppColors.critical,
                onTap: () => context.go(AppRoute.sos.path),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                label: 'MY TASKS',
                icon: Icons.assignment_outlined,
                color: AppColors.elevated,
                onTap: () => context.go(AppRoute.tasks.path),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveTasksPanel extends StatelessWidget {
  const _ActiveTasksPanel({required this.tasks});

  final List<FieldTask> tasks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: FieldLabel('My active tasks')),
            TextButton(
              onPressed: () => context.go(AppRoute.tasks.path),
              child: const Text('All'),
            ),
          ],
        ),
        if (tasks.isEmpty)
          const Text(
            'No accepted or in-progress tasks on this device.',
            style: TextStyle(color: AppColors.ink500, fontSize: 12, height: 1.4),
          )
        else
          for (final task in tasks.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => context.push(AppRoute.taskDetailPath(task.id)),
                borderRadius: BorderRadius.circular(6),
                child: OperationalPanel(
                  label: '#${task.taskCode}',
                  value: task.title,
                  detail: '${task.priority.wireValue} · ${task.status.label}',
                  accent: taskPriorityColor(task.priority),
                ),
              ),
            ),
      ],
    );
  }
}

class _ArchitectureNote extends StatelessWidget {
  const _ArchitectureNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.navy700),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FieldLabel('Architecture invariant'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.only(left: 10),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.accent, width: 2),
              ),
            ),
            child: const Text(
              'Field devices must remain operational even when disconnected '
              'from the internet.',
              style: TextStyle(
                color: AppColors.ink200,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Everything on this screen was read from the local database. The '
            'backend was not required to render it.',
            style: TextStyle(
              color: AppColors.ink500,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
