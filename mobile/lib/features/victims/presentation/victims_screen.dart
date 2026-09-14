import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../domain/entities/triage_category.dart';
import '../../../domain/entities/victim_board.dart';
import '../../../domain/entities/victim_status.dart';
import '../../../shared/widgets/count_tile.dart';
import '../../../shared/widgets/filter_chip_row.dart';
import '../../../shared/widgets/list_message.dart';
import '../../../shared/widgets/local_data_banner.dart';
import '../../../shared/widgets/ops_search_field.dart';
import '../application/victim_providers.dart';
import 'widgets/victim_list_tile.dart';
import 'widgets/victim_visuals.dart';

/// Every victim this device knows about, most urgent first.
///
/// Reads exclusively from local storage. With the radio off, the aeroplane
/// symbol showing and the backend unreachable, this screen is unchanged.
class VictimsScreen extends ConsumerWidget {
  const VictimsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final victims = ref.watch(victimListProvider);
    final board = ref.watch(victimBoardProvider).value ?? VictimBoard.empty;
    final query = ref.watch(victimQueryProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoute.victimRegister.path),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Register Victim'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          const LocalDataBanner(),
          const SizedBox(height: 14),

          _TriageBoard(board: board),
          const SizedBox(height: 14),

          OpsSearchField(
            hintText: 'Search name, id or injury',
            initial: query.search,
            onChanged: (value) =>
                ref.read(victimQueryProvider.notifier).search(value),
          ),
          const SizedBox(height: 10),

          _TriageFilterRow(
            selected: query.triage,
            onSelected: (category) =>
                ref.read(victimQueryProvider.notifier).filterByTriage(category),
          ),
          const SizedBox(height: 8),

          _StatusFilterRow(
            selected: query.status,
            onSelected: (status) =>
                ref.read(victimQueryProvider.notifier).filterByStatus(status),
          ),
          const SizedBox(height: 14),

          victims.when(
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
                ? _EmptyState(filtered: query.isFiltered)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, left: 2),
                        child: Text(
                          '${records.length} shown · ${board.total} on this device',
                          style: const TextStyle(
                            color: AppColors.ink500,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      for (final victim in records)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: VictimListTile(
                            victim: victim,
                            onTap: () => context.push(
                              AppRoute.victimDetailPath(victim.id),
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

/// Counts by category. The point of a triage system is that this row tells a
/// commander what the sector looks like in one glance.
class _TriageBoard extends StatelessWidget {
  const _TriageBoard({required this.board});

  final VictimBoard board;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final category in TriageCategory.byUrgency) ...[
          Expanded(
            child: CountTile(
              label: category.wireValue,
              count: board.countOf(category),
              color: triageColor(category),
            ),
          ),
          if (category != TriageCategory.byUrgency.last)
            const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _TriageFilterRow extends StatelessWidget {
  const _TriageFilterRow({required this.selected, required this.onSelected});

  final TriageCategory? selected;
  final ValueChanged<TriageCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChipRow(
      children: [
        OpsFilterChip(
          label: 'All triage',
          color: AppColors.accentSoft,
          selected: selected == null,
          onTap: () => onSelected(null),
        ),
        for (final category in TriageCategory.byUrgency)
          OpsFilterChip(
            label: category.wireValue,
            color: triageColor(category),
            selected: selected == category,
            onTap: () => onSelected(selected == category ? null : category),
          ),
      ],
    );
  }
}

class _StatusFilterRow extends StatelessWidget {
  const _StatusFilterRow({required this.selected, required this.onSelected});

  final VictimStatus? selected;
  final ValueChanged<VictimStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChipRow(
      children: [
        OpsFilterChip(
          label: 'All statuses',
          color: AppColors.accentSoft,
          selected: selected == null,
          onTap: () => onSelected(null),
        ),
        for (final status in VictimStatus.values)
          OpsFilterChip(
            label: status.label,
            color: statusColor(status),
            selected: selected == status,
            onTap: () => onSelected(selected == status ? null : status),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return ListMessage(
      icon: filtered ? Icons.filter_alt_off_outlined : Icons.person_off_outlined,
      color: AppColors.ink500,
      title: filtered
          ? 'No victims match this filter'
          : 'No victims registered on this device',
      detail: filtered
          ? 'Clear the search or the filters to see every record held locally.'
          : 'Register the first one with the button below. It will be stored '
              'on this device immediately, with or without a network.',
    );
  }
}
