import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../domain/entities/field_ops_boards.dart';
import '../../../domain/entities/hazard_severity.dart';
import '../../../domain/entities/hazard_status.dart';
import '../../../domain/entities/hazard_type.dart';
import '../../../shared/widgets/count_tile.dart';
import '../../../shared/widgets/filter_chip_row.dart';
import '../../../shared/widgets/list_message.dart';
import '../../../shared/widgets/local_data_banner.dart';
import '../../../shared/widgets/ops_search_field.dart';
import '../../../shared/widgets/ops_visuals.dart';
import '../application/hazard_providers.dart';
import 'widgets/hazard_list_tile.dart';

/// Every hazard this device knows about, most severe first.
///
/// Reads exclusively from local storage. With the radio off and the backend
/// unreachable, this screen is unchanged.
class HazardsScreen extends ConsumerWidget {
  const HazardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hazards = ref.watch(hazardListProvider);
    final board = ref.watch(hazardBoardProvider).value ?? HazardBoard.empty;
    final query = ref.watch(hazardQueryProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoute.hazardReport.path),
        backgroundColor: AppColors.high,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.warning_amber_outlined),
        label: const Text('Report Hazard'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          const LocalDataBanner(),
          const SizedBox(height: 14),

          Row(
            children: [
              for (final severity in HazardSeverity.bySeverity) ...[
                Expanded(
                  child: CountTile(
                    label: severity.wireValue,
                    count: board.countOf(severity),
                    color: hazardSeverityColor(severity),
                  ),
                ),
                if (severity != HazardSeverity.bySeverity.last)
                  const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 14),

          OpsSearchField(
            hintText: 'Search hazard code or description',
            initial: query.search,
            onChanged: (value) =>
                ref.read(hazardQueryProvider.notifier).search(value),
          ),
          const SizedBox(height: 10),

          FilterChipRow(
            children: [
              OpsFilterChip(
                label: 'All severities',
                color: AppColors.accentSoft,
                selected: query.severity == null,
                onTap: () =>
                    ref.read(hazardQueryProvider.notifier).filterBySeverity(null),
              ),
              for (final severity in HazardSeverity.bySeverity)
                OpsFilterChip(
                  label: severity.wireValue,
                  color: hazardSeverityColor(severity),
                  selected: query.severity == severity,
                  onTap: () => ref
                      .read(hazardQueryProvider.notifier)
                      .filterBySeverity(
                        query.severity == severity ? null : severity,
                      ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          FilterChipRow(
            children: [
              OpsFilterChip(
                label: 'All statuses',
                color: AppColors.accentSoft,
                selected: query.status == null,
                onTap: () =>
                    ref.read(hazardQueryProvider.notifier).filterByStatus(null),
              ),
              for (final status in HazardStatus.values)
                OpsFilterChip(
                  label: status.label,
                  color: hazardStatusColor(status),
                  selected: query.status == status,
                  onTap: () => ref
                      .read(hazardQueryProvider.notifier)
                      .filterByStatus(query.status == status ? null : status),
                ),
            ],
          ),
          const SizedBox(height: 8),

          FilterChipRow(
            children: [
              OpsFilterChip(
                label: 'All types',
                color: AppColors.accentSoft,
                selected: query.type == null,
                onTap: () =>
                    ref.read(hazardQueryProvider.notifier).filterByType(null),
              ),
              for (final type in HazardType.values)
                OpsFilterChip(
                  label: type.label,
                  color: AppColors.ink300,
                  selected: query.type == type,
                  onTap: () => ref
                      .read(hazardQueryProvider.notifier)
                      .filterByType(query.type == type ? null : type),
                ),
            ],
          ),
          const SizedBox(height: 14),

          hazards.when(
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
                ? ListMessage(
                    icon: query.isFiltered
                        ? Icons.filter_alt_off_outlined
                        : Icons.warning_amber_outlined,
                    color: AppColors.ink500,
                    title: query.isFiltered
                        ? 'No hazards match this filter'
                        : 'No hazards reported on this device',
                    detail: query.isFiltered
                        ? 'Clear the search or the filters to see every report '
                            'held locally.'
                        : 'Report the first one with the button below. It will '
                            'be stored on this device immediately, with or '
                            'without a network.',
                    action: query.isFiltered
                        ? TextButton(
                            onPressed: () =>
                                ref.read(hazardQueryProvider.notifier).clear(),
                            child: const Text('Clear filters'),
                          )
                        : null,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, left: 2),
                        child: Text(
                          '${records.length} shown · ${board.total} on this '
                          'device · ${board.open} unresolved',
                          style: const TextStyle(
                            color: AppColors.ink500,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      for (final hazard in records)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: HazardListTile(
                            hazard: hazard,
                            onTap: () => context.push(
                              AppRoute.hazardDetailPath(hazard.id),
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
