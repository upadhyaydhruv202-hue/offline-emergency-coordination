import 'package:drift/drift.dart';

import '../../../domain/entities/sync_status.dart';
import '../../../domain/entities/task_priority.dart';
import '../../../domain/entities/task_status.dart';

/// Work this device is tracking.
@DataClassName('TaskRow')
class Tasks extends Table {
  TextColumn get id => text()();

  /// Short label for the radio. Unique on this device.
  TextColumn get taskCode => text().withLength(min: 3, max: 32).unique()();

  TextColumn get incidentId => text().withLength(max: 64).nullable()();

  /// Session id of the responder holding the task, or null when unassigned.
  TextColumn get assignedTo => text().withLength(max: 128).nullable()();

  TextColumn get title => text().withLength(min: 1, max: 200)();

  TextColumn get description => text().withLength(max: 1000).nullable()();

  TextColumn get priority => textEnum<TaskPriority>()();

  /// Denormalised from [priority] so the list can be ordered by the database.
  IntColumn get rank => integer()();

  TextColumn get status => textEnum<TaskStatus>()();

  /// Free text a responder can be given over a radio, not a coordinate pair.
  TextColumn get location => text().withLength(max: 200).nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  TextColumn get syncStatus => textEnum<SyncStatus>()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
