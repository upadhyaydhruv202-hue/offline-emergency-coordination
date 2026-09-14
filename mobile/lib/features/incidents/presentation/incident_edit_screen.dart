import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../domain/entities/incident_draft.dart';
import '../../../shared/widgets/detail_row.dart';
import '../../location/application/location_providers.dart';
import '../application/incident_providers.dart';
import 'widgets/incident_form.dart';

/// Amends an incident already held on this device.
class IncidentEditScreen extends ConsumerWidget {
  const IncidentEditScreen({required this.incidentId, super.key});

  final String incidentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incident = ref.watch(incidentProvider(incidentId));

    return Scaffold(
      appBar: AppBar(title: const Text('Update Incident')),
      body: SafeArea(
        child: incident.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => CenteredMessage(text: error.toString()),
          data: (record) => record == null
              ? const CenteredMessage(
                  text: 'This incident is not held on this device.',
                )
              : IncidentForm(
                  initial: IncidentDraft.from(record),
                  submitLabel: 'Save to this device',
                  showStatus: true,
                  position: ref.watch(latestLocationProvider).value,
                  onSubmit: (draft) async {
                    try {
                      await ref
                          .read(incidentServiceProvider)
                          .update(record, draft);
                      if (!context.mounted) return null;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.navy800,
                          content: Text('${record.incidentCode} updated'),
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
