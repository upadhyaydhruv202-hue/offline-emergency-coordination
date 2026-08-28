import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/config/app_config.dart';
import '../../../data/local/database_providers.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responder = ref.watch(authControllerProvider).responderOrNull;
    final health = ref.watch(localDatabaseHealthProvider).valueOrNull;

    if (responder == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  responder.fullName,
                  style: const TextStyle(
                    color: AppColors.ink100,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  responder.email,
                  style: const TextStyle(
                    color: AppColors.ink400,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusChip(
                      label: responder.role.wireValue,
                      color: AppColors.accentSoft,
                    ),
                    StatusChip(
                      label: responder.isOfflineDemo
                          ? 'LOCAL DEMO SESSION'
                          : 'BACKEND AUTHENTICATED',
                      color: responder.isOfflineDemo
                          ? AppColors.elevated
                          : AppColors.nominal,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        const FieldLabel('Session'),
        const SizedBox(height: 8),
        _DetailRow(
          label: 'Responder id',
          value: responder.id,
        ),
        _DetailRow(
          label: 'Signed in',
          value: '${responder.signedInAt.toIso8601String()} UTC',
        ),

        const SizedBox(height: 20),
        const FieldLabel('Device'),
        const SizedBox(height: 8),
        _DetailRow(label: 'Device id', value: health?.deviceId ?? 'unknown'),
        _DetailRow(
          label: 'Local schema',
          value: health == null ? 'unknown' : 'v${health.schemaVersion}',
        ),
        _DetailRow(
          label: 'Local tables',
          value: health == null ? 'unknown' : health.tables.join(', '),
        ),
        _DetailRow(label: 'Backend', value: AppConfig.apiBaseUrl),

        const SizedBox(height: 28),
        OutlinedButton.icon(
          onPressed: () async {
            await ref.read(authControllerProvider.notifier).signOut();
            if (context.mounted) context.go(AppRoute.login.path);
          },
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('Sign out and clear local session'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.critical,
            side: BorderSide(
              color: AppColors.critical.withValues(alpha: 0.5),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Signing out deletes the session and stored tokens from this device. '
          'Operational records are not affected.',
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
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.ink500,
                fontSize: 12,
              ),
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
