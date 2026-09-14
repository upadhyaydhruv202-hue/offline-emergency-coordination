import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../application/sync_providers.dart';

class SyncPendingScreen extends ConsumerWidget {
  const SyncPendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operations = ref.watch(syncOperationsProvider);
    return operations.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('$error')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Text(
              'No operations on the queue.',
              style: TextStyle(color: AppColors.ink400),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final op = items[index];
            return Card(
              child: ListTile(
                title: Text(
                  '${op.entityType.wireValue} ${op.operationType.wireValue}',
                ),
                subtitle: Text(
                  '${op.queueStatus.wireValue} · ${op.deviceId}\n'
                  '${op.entityId}',
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}
