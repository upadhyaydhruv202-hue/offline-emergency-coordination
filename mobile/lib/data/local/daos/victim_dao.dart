import 'package:drift/drift.dart';

import '../../../domain/entities/sync_status.dart';
import '../../../domain/entities/triage_category.dart';
import '../../../domain/entities/victim.dart';
import '../../../domain/entities/victim_board.dart';
import '../../../domain/entities/victim_query.dart';
import '../../../domain/entities/victim_status.dart';
import '../app_database.dart';

/// Every statement that touches the `victims` table.
///
/// Screens and controllers call this; none of them build SQL. That boundary is
/// what will let the synchronisation slice write to the same table without any
/// widget changing.
class VictimDao {
  const VictimDao(this._db);

  final AppDatabase _db;

  /// Live victim list for [query], ordered the way a responder triages:
  /// people who still need something first, most critical first within that,
  /// most recently touched first within that.
  Stream<List<Victim>> watchVictims([
    VictimQuery query = const VictimQuery(),
  ]) =>
      _selectFor(query).watch().map(_toVictims);

  Future<List<Victim>> readVictims([
    VictimQuery query = const VictimQuery(),
  ]) async =>
      _toVictims(await _selectFor(query).get());

  Stream<Victim?> watchVictim(String id) =>
      (_db.select(_db.victims)..where((row) => row.id.equals(id)))
          .watchSingleOrNull()
          .map((row) => row == null ? null : _toVictim(row));

  Future<Victim?> readVictim(String id) async {
    final row = await (_db.select(_db.victims)
          ..where((victim) => victim.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toVictim(row);
  }

  Future<Victim?> readByTemporaryId(String temporaryId) async {
    final row = await (_db.select(_db.victims)
          ..where((victim) => victim.temporaryId.equals(temporaryId)))
        .getSingleOrNull();
    return row == null ? null : _toVictim(row);
  }

  /// Inserts a new record. Throws if [Victim.temporaryId] is already taken,
  /// which the repository turns into a retry rather than a lost registration.
  Future<void> insertVictim(Victim victim) =>
      _db.into(_db.victims).insert(_toCompanion(victim));

  /// Overwrites an existing record wholesale. Casualty records are corrected
  /// in place; a reassessment is not a new person.
  Future<void> updateVictim(Victim victim) async {
    await _db.update(_db.victims).replace(_toCompanion(victim));
  }

  Future<int> countAll() async {
    final count = _db.victims.id.count();
    final query = _db.selectOnly(_db.victims)..addColumns([count]);
    return (await query.getSingle()).read(count) ?? 0;
  }

  /// Live counts for the summary strip above the list.
  Stream<VictimBoard> watchBoard() {
    final victims = _db.victims;

    final total = victims.id.count();
    final open = victims.id.count(filter: _isClosed().not());
    final pending = victims.id.count(
      filter: victims.syncStatus.equalsValue(SyncStatus.pending),
    );
    final perCategory = <TriageCategory, Expression<int>>{
      for (final category in TriageCategory.values)
        category: victims.id.count(
          filter: victims.triageCategory.equalsValue(category),
        ),
    };

    final query = _db.selectOnly(victims)
      ..addColumns([total, open, pending, ...perCategory.values]);

    return query.watchSingle().map(
          (row) => VictimBoard(
            total: row.read(total) ?? 0,
            open: row.read(open) ?? 0,
            pendingSync: row.read(pending) ?? 0,
            byTriage: {
              for (final entry in perCategory.entries)
                entry.key: row.read(entry.value) ?? 0,
            },
          ),
        );
  }

  SimpleSelectStatement<$VictimsTable, VictimRow> _selectFor(
    VictimQuery query,
  ) {
    final select = _db.select(_db.victims);

    final triage = query.triage;
    if (triage != null) {
      select.where((victim) => victim.triageCategory.equalsValue(triage));
    }

    final status = query.status;
    if (status != null) {
      select.where((victim) => victim.status.equalsValue(status));
    }

    if (query.hasSearch) {
      final term = '%${query.normalisedSearch}%';
      select.where(
        (victim) =>
            victim.name.lower().like(term) |
            victim.temporaryId.lower().like(term) |
            victim.injuryType.lower().like(term) |
            victim.medicalCondition.lower().like(term),
      );
    }

    select.orderBy([
      // false (0) before true (1): open records above closed ones.
      (_) => OrderingTerm.asc(_isClosed()),
      (victim) => OrderingTerm.asc(victim.priority),
      (victim) => OrderingTerm.desc(victim.updatedAt),
    ]);

    return select;
  }

  Expression<bool> _isClosed() {
    final status = _db.victims.status;
    return status.equalsValue(VictimStatus.evacuated) |
        status.equalsValue(VictimStatus.deceased);
  }

  static List<Victim> _toVictims(List<VictimRow> rows) =>
      rows.map(_toVictim).toList(growable: false);

  static Victim _toVictim(VictimRow row) => Victim(
        id: row.id,
        temporaryId: row.temporaryId,
        name: row.name,
        age: row.age,
        ageGroup: row.ageGroup,
        gender: row.gender,
        medicalCondition: row.medicalCondition,
        injuryType: row.injuryType,
        triageCategory: row.triageCategory,
        priority: row.priority,
        assistanceRequired: row.assistanceRequired,
        status: row.status,
        incidentId: row.incidentId,
        latitude: row.latitude,
        longitude: row.longitude,
        locationAccuracy: row.locationAccuracy,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        createdBy: row.createdBy,
        syncStatus: row.syncStatus,
      );

  static VictimsCompanion _toCompanion(Victim victim) => VictimsCompanion.insert(
        id: victim.id,
        temporaryId: victim.temporaryId,
        name: Value(victim.name),
        age: Value(victim.age),
        ageGroup: victim.ageGroup,
        gender: victim.gender,
        medicalCondition: Value(victim.medicalCondition),
        injuryType: Value(victim.injuryType),
        triageCategory: victim.triageCategory,
        priority: victim.priority,
        assistanceRequired: Value(victim.assistanceRequired),
        status: victim.status,
        incidentId: Value(victim.incidentId),
        latitude: Value(victim.latitude),
        longitude: Value(victim.longitude),
        locationAccuracy: Value(victim.locationAccuracy),
        createdAt: victim.createdAt,
        updatedAt: victim.updatedAt,
        createdBy: victim.createdBy,
        syncStatus: victim.syncStatus,
      );
}
