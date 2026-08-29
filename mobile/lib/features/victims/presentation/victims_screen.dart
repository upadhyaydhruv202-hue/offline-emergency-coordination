import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../domain/entities/triage_category.dart';
import '../../../domain/entities/victim_board.dart';
import '../../../domain/entities/victim_status.dart';
import '../application/victim_providers.dart';
import 'widgets/local_data_banner.dart';
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

          _SearchField(
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
            error: (error, _) => _ListMessage(
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
            child: _TriageCount(
              category: category,
              count: board.countOf(category),
            ),
          ),
          if (category != TriageCategory.byUrgency.last)
            const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _TriageCount extends StatelessWidget {
  const _TriageCount({required this.category, required this.count});

  final TriageCategory category;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = triageColor(category);

    return Semantics(
      label: '${category.label}: $count',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.navy850,
          border: Border.all(color: AppColors.navy700),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    category.wireValue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: const TextStyle(
                color: AppColors.ink100,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({required this.initial, required this.onChanged});

  final String initial;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search name, id or injury',
        prefixIcon: const Icon(Icons.search, size: 18),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Clear search',
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                  setState(() {});
                },
              ),
      ),
    );
  }
}

class _TriageFilterRow extends StatelessWidget {
  const _TriageFilterRow({required this.selected, required this.onSelected});

  final TriageCategory? selected;
  final ValueChanged<TriageCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    return _FilterScroller(
      children: [
        _FilterChip(
          label: 'All triage',
          color: AppColors.accentSoft,
          selected: selected == null,
          onTap: () => onSelected(null),
        ),
        for (final category in TriageCategory.byUrgency)
          _FilterChip(
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
    return _FilterScroller(
      children: [
        _FilterChip(
          label: 'All statuses',
          color: AppColors.accentSoft,
          selected: selected == null,
          onTap: () => onSelected(null),
        ),
        for (final status in VictimStatus.values)
          _FilterChip(
            label: status.label,
            color: statusColor(status),
            selected: selected == status,
            onTap: () => onSelected(selected == status ? null : status),
          ),
      ],
    );
  }
}

class _FilterScroller extends StatelessWidget {
  const _FilterScroller({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) => children[index],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.14)
                : Colors.transparent,
            border: Border.all(
              color: selected ? color : AppColors.navy600,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : AppColors.ink400,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return _ListMessage(
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

class _ListMessage extends StatelessWidget {
  const _ListMessage({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.navy700),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.ink200,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.ink500,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
