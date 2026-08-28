# DRP Field App (Flutter)

The field responder's device. **Local-first**: it reads and writes its own SQLite
database and never requires the backend to function.

## Before the first run

The repository tracks `lib/`, `test/`, `tool/` and the pubspec only. Two things
have to be generated on your machine:

1. **Native platform folders** (`android/`, `ios/`, `windows/`) — machine- and
   SDK-specific, so they are not committed.
2. **Drift code** (`lib/data/local/app_database.g.dart`) — produced by
   `build_runner` from the table definitions.

Until both exist the project will not analyze or compile. One command does both:

```powershell
cd mobile
./tool/bootstrap.ps1        # Windows
```

```bash
cd mobile
./tool/bootstrap.sh         # macOS / Linux
```

The script backs up `lib/`, `test/`, the pubspec and `analysis_options.yaml`
before calling `flutter create` (which would otherwise replace them), restores
them whether or not that step succeeded, then runs `flutter pub get` and
`build_runner`. Re-running it is safe.

**Windows:** `flutter create` exits non-zero if it cannot symlink plugins, which
means Developer Mode is off (`start ms-settings:developers`). The script reports
this and carries on, because the platform folders are still written and neither
the analyzer nor the test suite needs the symlinks. Turn Developer Mode on
before building for a device.

### Doing it manually

```bash
flutter create --platforms=android,ios,windows --project-name drp_mobile --org com.drp .
# restore lib/, test/, pubspec.yaml and analysis_options.yaml if they were replaced
flutter pub get
dart run build_runner build
```

## Running

```bash
flutter analyze
flutter test
flutter run --dart-define=DRP_API_BASE_URL=http://10.0.2.2:8000/api/v1
```

`10.0.2.2` is the Android emulator's alias for the host loopback. Use
`http://127.0.0.1:8000/api/v1` on desktop, or the machine's LAN address on a
physical handset.

The app also runs with no backend at all — that is the point. Choose
**Continue in Offline Demo Mode** on the sign-in screen.

## Layout

```
lib/
├── main.dart                  entry point, ProviderScope
├── app/
│   ├── app.dart               MaterialApp.router
│   ├── router/                GoRouter, route table, redirect policy
│   └── theme/                 operational palette and ThemeData
├── core/
│   ├── config/                --dart-define configuration
│   └── errors/                AppException hierarchy
├── data/
│   ├── local/                 Drift database, tables, DAOs   <- authoritative
│   └── remote/                backend client                 <- optional peer
├── domain/entities/           Responder, ResponderRole, IncidentSummary
├── features/
│   ├── auth/                  application (Riverpod) / data / presentation
│   ├── connectivity/          ONLINE · DEGRADED · OFFLINE
│   ├── home/                  responder home
│   ├── profile/               session and device detail
│   ├── placeholder/           honest stand-ins for unbuilt modules
│   └── splash/                session restoration
└── shared/widgets/            shell, panels, status chips
```

## Slice 1 scope

Implemented:

- Splash with real session restoration from SQLite
- Login against `POST /auth/login`, plus offline demo mode
- Role display, and role selection for local demo sessions
- Responder home: name, role, incident (demo), connectivity, database status
- Profile with session/device detail and sign-out
- Drift schema v1: `app_metadata`, `local_sessions`
- Connectivity service: `ONLINE` / `DEGRADED` / `OFFLINE`
- GoRouter navigation for all eleven destinations

Not implemented, and not simulated — `/incidents`, `/victims`, `/sos`,
`/hazards`, `/tasks` and `/map` render a page naming the slice that delivers
them.

## Tests

```bash
flutter test
```

45 tests, all passing on Flutter 3.47.2 / Dart 3.13.2.

| File | Tests | Covers |
| --- | --- | --- |
| `test/app_smoke_test.dart` | 7 | Boots the real app: login, offline demo, home, placeholders, restart |
| `test/connectivity_test.dart` | 15 | The `ONLINE`/`DEGRADED`/`OFFLINE` rule and the service around it |
| `test/auth_flow_test.dart` | 12 | Offline demo sessions, backend sign-in, role model, redirect policy |
| `test/local_database_test.dart` | 11 | Drift initialisation, schema, session persistence, metadata |

`app_smoke_test.dart` pumps `DisasterResponseApp` itself and overrides only the
two things that need a physical device: where the database lives, and the
platform connectivity channel. Everything else — router, theme, providers,
screens — is the shipping code.

Tests run in the Dart VM rather than on a device, so the SQLite binaries that
`drift_flutter` bundles into the app are not loaded. The `sqlite3` dev
dependency supplies its own through a build hook, so no library override is
needed on any platform.

## Adding a table in a later slice

1. Add the table under `lib/data/local/tables/`.
2. Register it in the `@DriftDatabase(tables: [...])` annotation.
3. Increment `schemaVersion` and add the matching `from` step in `migration`.
4. `dart run build_runner build`.
5. Add a DAO under `lib/data/local/daos/` and a test.

If the table uses an enum column, import that enum in `app_database.dart`: the
generated part file resolves names against the database library's imports, not
the table file's.

Never edit a released migration step.
