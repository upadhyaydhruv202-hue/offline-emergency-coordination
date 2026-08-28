import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/app_metadata.dart';

/// Key/value access to [AppMetadata].
class AppMetadataDao {
  const AppMetadataDao(this._db);

  final AppDatabase _db;

  Future<String?> read(String key) async {
    final row = await (_db.select(_db.appMetadata)
          ..where((tbl) => tbl.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> write(String key, String value) async {
    await _db.into(_db.appMetadata).insertOnConflictUpdate(
          AppMetadataCompanion.insert(
            key: key,
            value: value,
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  /// Writes [value] only if [key] has never been set, and returns the value in
  /// force afterwards. Used to mint the device identifier exactly once.
  Future<String> readOrCreate(String key, String Function() value) async {
    final existing = await read(key);
    if (existing != null) return existing;

    final created = value();
    await write(key, created);
    return created;
  }

  Future<int> count() async {
    final query = _db.selectOnly(_db.appMetadata)
      ..addColumns([_db.appMetadata.key.count()]);
    final row = await query.getSingle();
    return row.read(_db.appMetadata.key.count()) ?? 0;
  }
}
