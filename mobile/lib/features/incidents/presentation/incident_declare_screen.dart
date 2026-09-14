import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../domain/entities/disaster_type.dart';
import '../../../domain/entities/incident_draft.dart';
import '../../location/application/location_providers.dart';
import '../application/incident_providers.dart';
import 'widgets/incident_form.dart';

/// Declares a new incident against local storage and adopts it.
///
/// Declaring and selecting are one action here on purpose: a responder opening a
/// response is, by definition, working in it, and making them tap "select"
/// afterwards would be a step that exists only because the data model has two
/// fields.
class IncidentDeclareScreen extends ConsumerWidget {
  const IncidentDeclareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Declare Incident')),
      body: SafeArea(
        child: IncidentForm(
          initial: const IncidentDraft(
            title: '',
            disasterType: DisasterType.earthquake,
          ),
          submitLabel: 'Declare and set as current',
          position: ref.watch(latestLocationProvider).value,
          onSubmit: (draft) async {
            try {
              final service = ref.read(incidentServiceProvider);
              final incident = await service.declare(draft);
              await service.select(incident);

              if (!context.mounted) return null;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.navy800,
                  content: Text(
                    '${incident.incidentCode} declared on this device and set '
                    'as the current operation',
                  ),
                ),
              );
              context.pushReplacement(
                AppRoute.incidentDetailPath(incident.id),
              );
              return null;
            } on Exception catch (error) {
              return 'The incident could not be written to this device: $error';
            }
          },
        ),
      ),
    );
  }
}
