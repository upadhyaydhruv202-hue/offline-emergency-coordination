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
├── core/utils/                UUID and temporary-id generation
├── domain/entities/           Responder, Victim, TriageCategory, VictimStatus
├── features/
│   ├── auth/                  application (Riverpod) / data / presentation
│   ├── connectivity/          ONLINE · DEGRADED · OFFLINE
│   ├── home/                  responder home
│   ├── victims/               registration, triage, list, detail   <- Slice 2
│   ├── profile/               session and device detail
│   ├── placeholder/           honest stand-ins for unbuilt modules
│   └── splash/                session restoration
└── shared/widgets/            shell, panels, status chips
```

## Scope

**Slice 1**

- Splash with real session restoration from SQLite
- Login against `POST /auth/login`, plus offline demo mode
- Role display, and role selection for local demo sessions
- Responder home: name, role, connectivity, database status
- Profile with session/device detail and sign-out
- Drift schema v1: `app_metadata`, `local_sessions`
- Connectivity service: `ONLINE` / `DEGRADED` / `OFFLINE`
- GoRouter navigation for all eleven destinations

**Slice 2 — victims and triage, entirely offline**

- Victim list with search, triage and status filters, critical-first ordering
- Register, view, edit and reassess screens
- `CRITICAL` / `URGENT` / `MODERATE` / `STABLE`, and five lifecycle statuses
- Device-minted UUID plus a radio-readable tag (`V-8C1F-007`) from a local
  counter, so the number on the triage tag exists before any server sees it
- `OFFLINE`, `LOCAL DATA` and `SYNC PENDING` shown wherever victims are
- Drift schema v2: the `victims` table

Nothing in the victim flow calls the backend. `VictimRepository` has no HTTP
client and no knowledge that one exists; records are written to SQLite and
marked `pending`, and Slice 4 will be what finally moves them.

The three screenshots in [`docs/screenshots/`](../docs/screenshots) named
`mobile-*` were taken on a device with no network interface.

**Slice 3 — field operations, entirely offline**

- Incident declaration, list, detail and current-operation selection
- Manual GPS capture into `locations`
- SOS with confirmation, history and local resolve
- Hazard report / list / filters
- Task create / accept / start / complete
- Responder operational status
- Victims inherit current incident, responder and last known position
- Local audit trail
- Drift schema v3

Nothing in these flows calls the backend. `/map` still names the slice that
delivers it.

## Tests

```bash
flutter test
```

94 tests.

| File | Tests | Covers |
| --- | --- | --- |
| `test/app_smoke_test.dart` | 8 | Boots the real app: login, offline demo, home, SOS live, restart |
| `test/connectivity_test.dart` | 15 | The `ONLINE`/`DEGRADED`/`OFFLINE` rule and the service around it |
| `test/auth_flow_test.dart` | 12 | Offline demo sessions, backend sign-in, role model, redirect policy |
| `test/local_database_test.dart` | 11 | Drift initialisation, schema, session persistence, metadata |
| `test/victim_store_test.dart` | 26 | Schema v3, registration, persistence, reassessment, ordering, filters, counts |
| `test/victim_offline_flow_test.dart` | 8 | The whole offline victim journey through the real app widget |
| `test/field_ops_store_test.dart` | 13 | Incident, location, SOS, hazard, task, status, audit, victim scoping |
| `test/field_ops_offline_flow_test.dart` | 1 | Full field-ops journey with no network, then restart |

`app_smoke_test.dart` and `victim_offline_flow_test.dart` pump
`DisasterResponseApp` itself and override only the two things that need a
physical device: where the database lives, and the platform connectivity
channel. Everything else — router, theme, providers, screens — is the shipping
code.

The victim flow test goes further and supplies `ConnectivityTransport.none`
with a backend probe that always returns false. Every assertion in it therefore
holds on a handset with the radios off.

To simulate a cold start it tears the tree down with
`pumpWidget(const SizedBox.shrink())` before building it again over the same
database. Building a second app over a live one leaves the router on its
current route, which would prove nothing about what survived.

Tests run in the Dart VM rather than on a device, so the SQLite binaries that
`drift_flutter` bundles into the app are not loaded. The `sqlite3` dev
dependency supplies its own through a build hook, so no library override is
needed on any platform.

## Adding a table in a later slice

The `victims` table is the worked example: `lib/data/local/tables/victims.dart`,
its DAO, the `from < 2` branch of `migration` in `app_database.dart`, and
`test/victim_store_test.dart`.

1. Add the table under `lib/data/local/tables/`.
2. Register it in the `@DriftDatabase(tables: [...])` annotation.
3. Increment `schemaVersion` and add the matching `from` step in `migration`.
4. `dart run build_runner build`.
5. Add a DAO under `lib/data/local/daos/` and a test.

If the table uses an enum column, import that enum in `app_database.dart`: the
generated part file resolves names against the database library's imports, not
the table file's.

Never edit a released migration step.
