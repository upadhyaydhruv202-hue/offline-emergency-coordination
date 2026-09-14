import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../domain/entities/field_ops_boards.dart';
import '../../../domain/entities/task_priority.dart';
import '../../../domain/entities/task_status.dart';
import '../../../shared/widgets/count_tile.dart';
import '../../../shared/widgets/filter_chip_row.dart';
import '../../../shared/widgets/list_message.dart';
import '../../../shared/widgets/local_data_banner.dart';
import '../../../shared/widgets/ops_search_field.dart';
import '../../../shared/widgets/ops_visuals.dart';
import '../application/task_providers.dart';
import 'widgets/task_list_tile.dart';

/// Every task on this device, outstanding work first.
class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskListProvider);
    final board = ref.watch(taskBoardProvider).value ?? TaskBoard.empty;
    final query = ref.watch(taskQueryProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoute.taskNew.path),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task_outlined),
        label: const Text('New Task'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          const LocalDataBanner(
            message: 'Tasks will arrive from the command centre once '
                'synchronisation exists. Until then they are raised on this '
                'device to track work agreed over the radio, and every status '
                'change is stored locally.',
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              for (final status in const [
                TaskStatus.pending,
                TaskStatus.accepted,
                TaskStatus.inProgress,
                TaskStatus.completed,
              ]) ...[
                Expanded(
                  child: CountTile(
                    label: status.wireValue,
                    count: board.countOf(status),
                    color: taskStatusColor(status),
                  ),
                ),
                if (status != TaskStatus.completed) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 14),

          OpsSearchField(
            hintText: 'Search task code, title or location',
            initial: query.search,
            onChanged: (value) =>
                ref.read(taskQueryProvider.notifier).search(value),
          ),
          const SizedBox(height: 10),

          FilterChipRow(
            children: [
              OpsFilterChip(
                label: 'All priorities',
                color: AppColors.accentSoft,
                selected: query.priority == null,
                onTap: () =>
                    ref.read(taskQueryProvider.notifier).filterByPriority(null),
              ),
              for (final priority in TaskPriority.byUrgency)
                OpsFilterChip(
                  label: priority.wireValue,
                  color: taskPriorityColor(priority),
                  selected: query.priority == priority,
                  onTap: () => ref
                      .read(taskQueryProvider.notifier)
                      .filterByPriority(
                        query.priority == priority ? null : priority,
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
                    ref.read(taskQueryProvider.notifier).filterByStatus(null),
              ),
              for (final status in TaskStatus.values)
                OpsFilterChip(
                  label: status.label,
                  color: taskStatusColor(status),
                  selected: query.status == status,
                  onTap: () => ref
                      .read(taskQueryProvider.notifier)
                      .filterByStatus(query.status == status ? null : status),
                ),
            ],
          ),
          const SizedBox(height: 14),

          tasks.when(
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
                        : Icons.task_alt_outlined,
                    color: AppColors.ink500,
                    title: query.isFiltered
                        ? 'No tasks match this filter'
                        : 'No tasks on this device',
                    detail: query.isFiltered
                        ? 'Clear the search or the filters to see every task '
                            'held locally.'
                        : 'Raise one with the button below to track work you '
                            'have been given. It will be stored on this device '
                            'immediately, with or without a network.',
                    action: query.isFiltered
                        ? TextButton(
                            onPressed: () =>
                                ref.read(taskQueryProvider.notifier).clear(),
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
                          'device · ${board.active} being worked',
                          style: const TextStyle(
                            color: AppColors.ink500,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      for (final task in records)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TaskListTile(
                            task: task,
                            onTap: () => context.push(
                              AppRoute.taskDetailPath(task.id),
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
