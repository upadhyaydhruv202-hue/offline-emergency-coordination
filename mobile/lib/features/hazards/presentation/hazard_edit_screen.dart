import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../domain/entities/hazard_draft.dart';
import '../../../shared/widgets/detail_row.dart';
import '../application/hazard_providers.dart';
import 'widgets/hazard_form.dart';

/// Amends a hazard report already held on this device.
class HazardEditScreen extends ConsumerWidget {
  const HazardEditScreen({required this.hazardId, super.key});

  final String hazardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hazard = ref.watch(hazardProvider(hazardId));

    return Scaffold(
      appBar: AppBar(title: const Text('Update Hazard')),
      body: SafeArea(
        child: hazard.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => CenteredMessage(text: error.toString()),
          data: (record) => record == null
              ? const CenteredMessage(
                  text: 'This hazard is not held on this device.',
                )
              : HazardForm(
                  initial: HazardDraft.from(record),
                  submitLabel: 'Save to this device',
                  showStatus: true,
                  onSubmit: (draft) async {
                    try {
                      await ref
                          .read(hazardServiceProvider)
                          .update(record, draft);
                      if (!context.mounted) return null;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.navy800,
                          content: Text('${record.hazardCode} updated'),
                        ),
                      );
                      context.pop();
                      return null;
                    } on Exception catch (error) {
                      return 'The change could not be written to this device: '
                          '$error';
                    }
                  },
                ),
        ),
      ),
    );
  }
}
