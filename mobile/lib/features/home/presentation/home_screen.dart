import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/local/database_providers.dart';
import '../../../data/local/local_database_health.dart';
import '../../../domain/entities/demo_data.dart';
import '../../../domain/entities/triage_category.dart';
import '../../../domain/entities/victim_board.dart';
import '../../../shared/widgets/demo_data_banner.dart';
import '../../../shared/widgets/operational_panel.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../connectivity/connectivity_providers.dart';
import '../../connectivity/connectivity_status.dart';
import '../../victims/application/victim_providers.dart';

/// The responder's operational summary: who they are, what they are assigned
/// to, and whether the device can be relied on.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responder = ref.watch(authControllerProvider).responderOrNull;
    final connectivity = ref.watch(connectivityStatusProvider).value;
    final databaseHealth = ref.watch(localDatabaseHealthProvider);

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
          Row(
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
                      responder.email,
                      style: const TextStyle(
                        color: AppColors.ink500,
                        fontSize: 12,
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
          ),
          const SizedBox(height: 18),

          OperationalPanel(
            label: 'Incident',
            value: demoIncident.name,
            detail: demoIncident.sector,
            accent: AppColors.high,
            trailing: const StatusChip(
              label: 'DEMO',
              color: AppColors.elevated,
            ),
          ),
          const SizedBox(height: 10),

          OperationalPanel(
            label: 'Role',
            value: responder.role.label,
            detail: responder.role.isCommand
                ? 'Command role'
                : 'Field role',
            accent: AppColors.accent,
            trailing: TextButton(
              onPressed: () => context.go(AppRoute.role.path),
              child: const Text('Change'),
            ),
          ),
          const SizedBox(height: 10),

          _ConnectivityPanel(status: connectivity),
          const SizedBox(height: 10),

          databaseHealth.when(
            data: (health) => _DatabasePanel(health: health),
            loading: () => const OperationalPanel(
              label: 'Local database',
              value: 'INITIALISING',
              detail: 'Opening the on-device datastore',
              accent: AppColors.ink500,
            ),
            error: (error, _) => OperationalPanel(
              label: 'Local database',
              value: 'FAILED',
              detail: error.toString(),
              accent: AppColors.critical,
            ),
          ),
          const SizedBox(height: 10),

          _VictimsPanel(board: ref.watch(victimBoardProvider).value),

          const SizedBox(height: 20),
          const DemoDataBanner(
            message:
                'the incident above is fabricated. The incident, SOS and '
                'hazard modules are not implemented in this slice. Victim '
                'records are real and were authored on this device.',
          ),

          const SizedBox(height: 20),
          const _ArchitectureNote(),
        ],
      ),
    );
  }
}

class _ConnectivityPanel extends StatelessWidget {
  const _ConnectivityPanel({required this.status});

  final ConnectivityStatus? status;

  @override
  Widget build(BuildContext context) {
    final (color, detail) = switch (status) {
      ConnectivityStatus.online => (
          AppColors.nominal,
          'Coordination backend reachable. Synchronisation will run here in a later slice.',
        ),
      ConnectivityStatus.degraded => (
          AppColors.elevated,
          'A link exists but the backend did not answer. Keep working; the device is authoritative.',
        ),
      ConnectivityStatus.offline => (
          AppColors.critical,
          'No network interface. This is a supported operating mode, not a fault.',
        ),
      null => (AppColors.ink500, 'Evaluating available links…'),
    };

    return OperationalPanel(
      label: 'Connectivity',
      value: status?.label ?? 'CHECKING',
      detail: detail,
      accent: color,
    );
  }
}

class _VictimsPanel extends StatelessWidget {
  const _VictimsPanel({required this.board});

  final VictimBoard? board;

  @override
  Widget build(BuildContext context) {
    final counts = board ?? VictimBoard.empty;
    final critical = counts.countOf(TriageCategory.critical);

    return OperationalPanel(
      label: 'Victims',
      value: '${counts.total} registered',
      detail: counts.total == 0
          ? 'Nothing recorded on this device yet.'
          : '$critical critical · ${counts.open} still open · '
              '${counts.pendingSync} awaiting synchronisation',
      accent: critical > 0 ? AppColors.critical : AppColors.accent,
      trailing: TextButton(
        onPressed: () => context.go(AppRoute.victims.path),
        child: const Text('Open'),
      ),
    );
  }
}

class _DatabasePanel extends StatelessWidget {
  const _DatabasePanel({required this.health});

  final LocalDatabaseHealth health;

  @override
  Widget build(BuildContext context) {
    final deviceId = health.deviceId ?? 'unknown';
    final detail = health.isReady
        ? 'Schema v${health.schemaVersion} · '
            '${health.tables.length} tables · device $deviceId'
        : health.detail ?? 'The on-device datastore could not be opened.';

    return OperationalPanel(
      label: 'Local database',
      value: health.state.label,
      detail: detail,
      accent: health.isReady ? AppColors.nominal : AppColors.critical,
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
