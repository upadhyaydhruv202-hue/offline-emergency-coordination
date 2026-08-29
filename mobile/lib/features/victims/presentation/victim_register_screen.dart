import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../domain/entities/triage_category.dart';
import '../../../domain/entities/victim_draft.dart';
import '../application/victim_providers.dart';
import 'widgets/victim_form.dart';

/// Registers a new victim against local storage.
///
/// There is no "saving…" round trip and no way for this screen to fail because
/// of the network: the only thing between the responder and a stored record is
/// a SQLite write.
class VictimRegisterScreen extends ConsumerWidget {
  const VictimRegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register Victim')),
      body: SafeArea(
        child: VictimForm(
          initial: const VictimDraft(triageCategory: TriageCategory.urgent),
          submitLabel: 'Save to this device',
          onSubmit: (draft) async {
            try {
              final victim =
                  await ref.read(victimEditorProvider).register(draft);
              if (!context.mounted) return null;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.navy800,
                  content: Text(
                    '${victim.temporaryId} registered on this device',
                  ),
                ),
              );
              context.pushReplacement(
                AppRoute.victimDetailPath(victim.id),
              );
              return null;
            } on Exception catch (error) {
              return 'The record could not be written to this device: $error';
            }
          },
        ),
      ),
    );
  }
}
