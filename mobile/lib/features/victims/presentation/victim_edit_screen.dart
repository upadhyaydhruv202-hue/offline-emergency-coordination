import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../domain/entities/victim_draft.dart';
import '../application/victim_providers.dart';
import 'widgets/victim_form.dart';

/// Corrects an existing record, including its triage category and status.
class VictimEditScreen extends ConsumerWidget {
  const VictimEditScreen({required this.victimId, super.key});

  final String victimId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final victim = ref.watch(victimProvider(victimId));

    return Scaffold(
      appBar: AppBar(title: const Text('Update Victim')),
      body: SafeArea(
        child: victim.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.ink400,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          data: (record) {
            if (record == null) {
              return const Center(
                child: Text(
                  'This record is not held on this device.',
                  style: TextStyle(color: AppColors.ink400, fontSize: 13),
                ),
              );
            }

            return VictimForm(
              // Keyed by record so the controllers reload if the underlying
              // row is replaced while the form is open.
              key: ValueKey(record.id),
              initial: VictimDraft.from(record),
              submitLabel: 'Save changes',
              showStatus: true,
              onSubmit: (draft) async {
                try {
                  await ref.read(victimEditorProvider).update(record, draft);
                  if (!context.mounted) return null;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.navy800,
                      content: Text('${record.temporaryId} updated'),
                    ),
                  );
                  context.pop();
                  return null;
                } on Exception catch (error) {
                  return 'The change could not be written to this device: '
                      '$error';
                }
              },
            );
          },
        ),
      ),
    );
  }
}
