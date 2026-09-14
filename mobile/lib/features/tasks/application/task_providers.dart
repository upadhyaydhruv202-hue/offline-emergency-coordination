import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database_providers.dart';
import '../../../domain/entities/field_ops_boards.dart';
import '../../../domain/entities/field_task.dart';
import '../../../domain/entities/task_priority.dart';
import '../../../domain/entities/task_query.dart';
import '../../../domain/entities/task_status.dart';
import '../../audit/application/audit_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../field_ops/application/operating_context.dart';
import '../data/task_repository.dart';
import 'task_service.dart';

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(
    tasks: ref.watch(taskDaoProvider),
    metadata: ref.watch(appMetadataDaoProvider),
  ),
);

final taskQueryProvider = NotifierProvider<TaskQueryController, TaskQuery>(
  TaskQueryController.new,
);

class TaskQueryController extends Notifier<TaskQuery> {
  @override
  TaskQuery build() => const TaskQuery();

  void search(String value) => state = state.copyWith(search: value);

  /// Null selects every priority.
  void filterByPriority(TaskPriority? priority) => state = priority == null
      ? state.copyWith(clearPriority: true)
      : state.copyWith(priority: priority);

  /// Null selects every status.
  void filterByStatus(TaskStatus? status) => state = status == null
      ? state.copyWith(clearStatus: true)
      : state.copyWith(status: status);

  void clear() => state = const TaskQuery();
}

final taskListProvider = StreamProvider<List<FieldTask>>(
  (ref) => ref.watch(taskRepositoryProvider).watchTasks(
        ref.watch(taskQueryProvider),
      ),
);

final taskBoardProvider = StreamProvider<TaskBoard>(
  (ref) => ref.watch(taskRepositoryProvider).watchBoard(),
);

final taskProvider = StreamProvider.family<FieldTask?, String>(
  (ref, id) => ref.watch(taskRepositoryProvider).watchTask(id),
);

/// The work this responder is holding, for the home dashboard.
final activeTasksProvider = StreamProvider<List<FieldTask>>((ref) {
  final responderId = ref.watch(authControllerProvider).responderOrNull?.id;
  if (responderId == null) return Stream<List<FieldTask>>.value(const []);
  return ref.watch(taskRepositoryProvider).watchActiveFor(responderId);
});

final taskServiceProvider = Provider<TaskService>(
  (ref) => TaskService(
    repository: ref.watch(taskRepositoryProvider),
    audit: ref.watch(auditRepositoryProvider),
    context: ref.watch(operatingContextProvider),
  ),
);
