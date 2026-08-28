import 'package:drift/native.dart';
import 'package:drp_mobile/data/local/app_database.dart';

/// A throwaway in-memory database with the real schema and migrations applied.
///
/// Unit tests run in the Dart VM rather than on a device, so they do not get
/// the SQLite binaries that `drift_flutter` bundles into the app. The `sqlite3`
/// dev dependency supplies its own through a build hook, which is why no
/// library override is needed here.
AppDatabase openTestDatabase() => AppDatabase(NativeDatabase.memory());
