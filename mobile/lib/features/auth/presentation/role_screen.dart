import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../domain/entities/responder_role.dart';
import '../../../shared/widgets/status_chip.dart';
import '../application/auth_controller.dart';
import '../application/auth_state.dart';

/// Shows the role in force and, for a local demo session, allows changing it.
///
/// A backend-issued role is not editable here: it is a claim in the token and
/// changing it is an administrative action, not a device preference.
class RoleScreen extends ConsumerWidget {
  const RoleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responder = ref.watch(authControllerProvider).responderOrNull;

    if (responder == null) {
      return const Scaffold(
        body: Center(child: Text('No active session on this device.')),
      );
    }

    final editable = responder.isOfflineDemo;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Role'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoute.home.path),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FieldLabel('Current role'),
                    const SizedBox(height: 8),
                    Text(
                      responder.role.label,
                      style: const TextStyle(
                        color: AppColors.ink100,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      responder.role.wireValue,
                      style: const TextStyle(
                        color: AppColors.ink500,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 14),
                    StatusChip(
                      label: responder.isOfflineDemo
                          ? 'LOCAL DEMO SESSION'
                          : 'BACKEND ISSUED',
                      color: responder.isOfflineDemo
                          ? AppColors.elevated
                          : AppColors.nominal,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const FieldLabel('Available roles'),
            const SizedBox(height: 10),
            for (final role in ResponderRole.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    onTap: editable
                        ? () => ref
                            .read(authControllerProvider.notifier)
                            .changeRole(role)
                        : null,
                    enabled: editable || role == responder.role,
                    leading: Icon(
                      role == responder.role
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: role == responder.role
                          ? AppColors.accentSoft
                          : AppColors.ink500,
                      size: 20,
                    ),
                    title: Text(role.label),
                    subtitle: Text(
                      role.isCommand ? 'Command role' : 'Field role',
                      style: const TextStyle(
                        color: AppColors.ink500,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
            if (!editable) ...[
              const SizedBox(height: 8),
              const Text(
                'This role was issued by the coordination backend and cannot be '
                'changed on the device. Ask an administrator to reassign it.',
                style: TextStyle(
                  color: AppColors.ink500,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'Slice 1 keeps authorisation coarse: the role is recorded and '
              'displayed, and the backend enforces it per route. Fine-grained, '
              'per-incident permissions are a later slice.',
              style: TextStyle(
                color: AppColors.ink500,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
