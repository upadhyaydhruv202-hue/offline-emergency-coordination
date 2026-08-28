import 'package:drift/drift.dart';

import '../../../domain/entities/responder.dart';
import '../../../domain/entities/responder_role.dart';
import '../app_database.dart';

/// Reads and writes the single locally persisted session.
///
/// Only one session may exist at a time: signing in replaces whatever was
/// there, so a handset handed to a different responder cannot surface the
/// previous one's identity.
class SessionDao {
  const SessionDao(this._db);

  final AppDatabase _db;

  Future<Responder?> readActiveSession() async {
    final row = await (_db.select(_db.localSessions)..limit(1))
        .getSingleOrNull();
    return row == null ? null : _toResponder(row);
  }

  Stream<Responder?> watchActiveSession() =>
      (_db.select(_db.localSessions)..limit(1))
          .watchSingleOrNull()
          .map((row) => row == null ? null : _toResponder(row));

  Future<void> saveSession(Responder responder) async {
    await _db.transaction(() async {
      await _db.delete(_db.localSessions).go();
      await _db.into(_db.localSessions).insert(
            LocalSessionsCompanion.insert(
              id: responder.id,
              email: responder.email,
              fullName: responder.fullName,
              role: responder.role,
              isOfflineDemo: Value(responder.isOfflineDemo),
              signedInAt: Value(responder.signedInAt),
              lastSeenAt: Value(DateTime.now().toUtc()),
            ),
          );
    });
  }

  Future<void> updateRole(String sessionId, ResponderRole role) async {
    await (_db.update(_db.localSessions)
          ..where((tbl) => tbl.id.equals(sessionId)))
        .write(LocalSessionsCompanion(role: Value(role)));
  }

  Future<void> touch(String sessionId) async {
    await (_db.update(_db.localSessions)
          ..where((tbl) => tbl.id.equals(sessionId)))
        .write(
      LocalSessionsCompanion(lastSeenAt: Value(DateTime.now().toUtc())),
    );
  }

  Future<void> clear() => _db.delete(_db.localSessions).go();

  static Responder _toResponder(LocalSession row) => Responder(
        id: row.id,
        email: row.email,
        fullName: row.fullName,
        role: row.role,
        signedInAt: row.signedInAt,
        isOfflineDemo: row.isOfflineDemo,
      );
}
