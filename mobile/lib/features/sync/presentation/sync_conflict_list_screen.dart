import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../application/sync_providers.dart';

class SyncConflictListScreen extends ConsumerWidget {
  const SyncConflictListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflicts = ref.watch(syncConflictsProvider);
    return conflicts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('$error')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Text(
              'No conflicts recorded on this device.',
              style: TextStyle(color: AppColors.ink400),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final conflict = items[index];
            return Card(
              child: ListTile(
                title: Text(conflict.entityId),
                subtitle: Text(
                  '${conflict.entityType.wireValue} · ${conflict.resolution.wireValue}',
                ),
                onTap: () => context.push(
                  AppRoute.syncConflictDetailPath(conflict.id),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
