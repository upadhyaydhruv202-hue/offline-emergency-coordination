import 'package:drift/drift.dart';

import '../../../domain/entities/sos_priority.dart';
import '../../../domain/entities/sos_status.dart';
import '../../../domain/entities/sync_status.dart';

/// Distress calls raised on this device.
///
/// Nothing in this slice transmits them. The row existing, with its position
/// and the moment it was raised, is the whole deliverable: it is what a
/// responder can show, and what the synchronisation slice will carry.
@DataClassName('SosEventRow')
class SosEvents extends Table {
  TextColumn get id => text()();

  /// Short label for the radio. Unique on this device.
  TextColumn get sosCode => text().withLength(min: 3, max: 32).unique()();

  /// Session id of the responder in trouble.
  TextColumn get createdBy => text().withLength(min: 1, max: 128)();

  TextColumn get incidentId => text().withLength(max: 64).nullable()();

  RealColumn get latitude => real().nullable()();

  RealColumn get longitude => real().nullable()();

  RealColumn get accuracy => real().nullable()();

  /// When the responder raised it.
  DateTimeColumn get raisedAt => dateTime()();

  TextColumn get priority => textEnum<SosPriority>()();

  /// Denormalised from [priority] so "most urgent first" is an index-backed
  /// ORDER BY rather than a sort in the widget layer.
  IntColumn get priorityRank => integer()();

  TextColumn get message => text().withLength(max: 500).nullable()();

  TextColumn get status => textEnum<SosStatus>()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  TextColumn get syncStatus => textEnum<SyncStatus>()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
