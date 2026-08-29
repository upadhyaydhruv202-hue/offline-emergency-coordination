import 'package:drift/drift.dart';

import '../../../domain/entities/sync_status.dart';
import '../../../domain/entities/triage_category.dart';
import '../../../domain/entities/victim_demographics.dart';
import '../../../domain/entities/victim_status.dart';

/// People registered by this device.
///
/// The authoritative copy of a casualty record lives here, not on the server.
/// Every column is written from the responder's own input or from something
/// the device derived; none of it is ever filled in by a backend response.
@DataClassName('VictimRow')
class Victims extends Table {
  /// Device-minted UUID, so records authored on disconnected devices merge
  /// without collision when synchronisation arrives.
  TextColumn get id => text()();

  /// Short label for the triage tag and the radio. Unique on this device.
  TextColumn get temporaryId => text().withLength(min: 3, max: 32).unique()();

  /// Null when the person is unidentified, which must never block registering
  /// them.
  TextColumn get name => text().withLength(max: 160).nullable()();

  IntColumn get age => integer().nullable()();

  TextColumn get ageGroup => textEnum<AgeGroup>()();

  TextColumn get gender => textEnum<Gender>()();

  TextColumn get medicalCondition => text().withLength(max: 500).nullable()();

  TextColumn get injuryType => text().withLength(max: 200).nullable()();

  TextColumn get triageCategory => textEnum<TriageCategory>()();

  /// Denormalised from [triageCategory] so "critical first" is an index-backed
  /// ORDER BY rather than a sort in the widget layer.
  IntColumn get priority => integer()();

  TextColumn get assistanceRequired => text().withLength(max: 300).nullable()();

  TextColumn get status => textEnum<VictimStatus>()();

  /// Reserved for the spatial slice. Slice 2 records no position.
  RealColumn get latitude => real().nullable()();

  RealColumn get longitude => real().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  /// Session id of the authoring responder, including the local id of an
  /// offline demo session.
  TextColumn get createdBy => text().withLength(min: 1, max: 128)();

  TextColumn get syncStatus => textEnum<SyncStatus>()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
