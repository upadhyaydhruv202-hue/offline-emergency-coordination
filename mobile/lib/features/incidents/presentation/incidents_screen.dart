import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/list_message.dart';
import '../../../shared/widgets/local_data_banner.dart';
import '../application/incident_providers.dart';
import 'widgets/incident_list_tile.dart';

/// Every incident declared on this device, running responses first.
///
/// Reads exclusively from local storage. With the radio off and the backend
/// unreachable, this screen is unchanged.
class IncidentsScreen extends ConsumerWidget {
  const IncidentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidents = ref.watch(incidentListProvider);
    final current = ref.watch(currentIncidentProvider).value;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoute.incidentNew.path),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_alert_outlined),
        label: const Text('Declare Incident'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          const LocalDataBanner(
            message: 'Incidents are declared on this device. Selecting one '
                'scopes every victim, hazard, SOS and task captured here to it, '
                'and the selection survives the application being closed.',
          ),
          const SizedBox(height: 14),

          incidents.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => ListMessage(
              icon: Icons.error_outline,
              color: AppColors.critical,
              title: 'The local database could not be read',
              detail: error.toString(),
            ),
            data: (records) => records.isEmpty
                ? const ListMessage(
                    icon: Icons.crisis_alert_outlined,
                    color: AppColors.ink500,
                    title: 'No incident declared on this device',
                    detail: 'Declare the first one with the button below. It '
                        'will be stored here immediately, with or without a '
                        'network, and can be adopted as the current operation.',
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, left: 2),
                        child: Text(
                          '${records.length} on this device',
                          style: const TextStyle(
                            color: AppColors.ink500,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      for (final incident in records)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: IncidentListTile(
                            incident: incident,
                            isCurrent: incident.id == current?.id,
                            onTap: () => context.push(
                              AppRoute.incidentDetailPath(incident.id),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
