# Development slices

The platform is built as vertical slices. Each one is shippable and honest: a
feature is either implemented or visibly absent, never simulated.

## Slice 1 — Foundation (complete)

Repository structure, three runnable applications, and the architecture the
rest hangs off.

**Backend**

- FastAPI application factory, layered `api / services / repositories / models`
- `GET /health`, `GET /health/ready`
- `POST /auth/login`, `POST /auth/refresh`, `GET /auth/me`
- `users` table, five-role enum, `require_roles` authorisation primitive
- bcrypt hashing, JWT issue/verify, CORS, validation, uniform error envelope
- Alembic migration `0001_initial_users`, environment-driven seeding
- 36 tests

**Web**

- Vite + React + TypeScript + Tailwind command-centre shell
- Login against the backend, protected routes, session restore
- Dashboard with the five required metrics, every figure labelled as demo data
- Placeholder pages for Incidents, Responders, Victims, Map, Resources, Settings
- 24 tests

**Mobile**

- Splash with real session restoration from SQLite
- Login and offline demo mode
- Role display and, for local sessions, role selection
- Responder home: name, role, incident, connectivity, local database status
- Profile and sign-out
- Drift schema v1 (`app_metadata`, `local_sessions`)
- `ONLINE` / `DEGRADED` / `OFFLINE` connectivity service
- GoRouter across all eleven destinations
- 3 test suites

**Infrastructure**

- Docker Compose: PostgreSQL 16 + PostGIS 3.4 with a persistent volume, and the API
- First-boot extension provisioning

## Slice 2 — Offline victim registration and digital triage (complete)

A responder registers, triages and updates casualties with the network off.
The record is written to the device's own SQLite and is complete the moment it
is saved.

**Mobile**

- Victim list, register, detail and edit/reassess screens
- Four triage categories: `CRITICAL`, `URGENT`, `MODERATE`, `STABLE`
- Five statuses: `REGISTERED`, `UNDER_TREATMENT`, `AWAITING_EVACUATION`,
  `EVACUATED`, `DECEASED`
- Device-minted UUIDs and radio-readable temporary ids (`V-8C1F-007`)
- Search, filter by triage and status, critical-first ordering
- `OFFLINE`, `LOCAL DATA` and `SYNC PENDING` shown on every victim surface
- Drift schema v2: the `victims` table and its migration
- 34 additional tests, including the full offline register → restart → reassess
  journey through the real app widget

**Backend**

- `victims` table, `triage_category` / `victim_status` / `age_group` / `gender`
  enums, Alembic migration `0002_victims`
- `GET /api/v1/victims`, `GET /api/v1/victims/board`,
  `GET /api/v1/victims/{id}`, `POST /api/v1/victims`,
  `PATCH /api/v1/victims/{id}`
- Idempotent upload: re-sending a record a device is unsure landed updates it
  rather than conflicting
- 24 additional tests

**Web**

- Victims page: counts for every triage category and the casualty roster
- Search and filter, delegated to the backend query
- Live victim counts on the dashboard, replacing two fabricated tiles
- 10 additional tests

Not in this slice, by design: peer synchronisation, position capture, incident
scoping. A device's records stay on the device until Slice 4 gives them a way
to travel.

## Slice 3 — Field operations (complete)

A responder operates a real incident offline: declare and adopt it, capture a
position, raise SOS, report hazards, walk a task through its lifecycle, and
change their own status. Every write is local SQLite. Nothing is sent.

**Mobile**

- Incident list, declare, detail and current-operation selection (persists)
- Manual GPS capture via `geolocator`; stored in `locations`
- SOS with confirmation, history and local resolve
- Hazard report / list / filters, severity-first
- Task create / accept / start / complete
- Responder status on Home
- Victims inherit current incident, responder and last known position
- Drift schema v3: `incidents`, `locations`, `sos_events`, `hazards`, `tasks`,
  `responder_status`, `audit_events` plus `victims.incident_id`
- Home is the field dashboard: incident, status, location, pending count,
  quick actions
- **No step of this calls the backend.**

Screenshots: [`mobile-home.png`](screenshots/mobile-home.png),
[`mobile-incidents.png`](screenshots/mobile-incidents.png),
[`mobile-incident-detail.png`](screenshots/mobile-incident-detail.png),
[`mobile-sos.png`](screenshots/mobile-sos.png),
[`mobile-hazards.png`](screenshots/mobile-hazards.png),
[`mobile-tasks.png`](screenshots/mobile-tasks.png),
[`web-dashboard.png`](screenshots/web-dashboard.png),
[`web-incidents.png`](screenshots/web-incidents.png),
[`web-responders.png`](screenshots/web-responders.png),
[`web-hazards.png`](screenshots/web-hazards.png),
[`web-sos.png`](screenshots/web-sos.png),
[`web-tasks.png`](screenshots/web-tasks.png).

**Backend**

- `incidents`, `hazards`, `sos_events`, `tasks` tables; Alembic `0003_field_operations`
- List, board, read, idempotent upload and patch for each
- `GET /responders` roster (the `users` table)
- Optional seed: `python -m app.db.seed --field-ops`

**Web**

- Incidents, Responders, Hazards, SOS and Tasks pages
- Live incident / responder / hazard counts on the dashboard
- Map remains an honest Slice 5 placeholder

Not in this slice, by design: peer synchronisation, CRDT, mesh, live map,
automatic SOS transmission.

## Slice 4 — Local-first synchronisation

Implemented. Devices remain operational authorities while disconnected. When
operations are exchanged (today through a **simulated transport**, later through
BLE / Wi-Fi Direct / LoRa), a transport-independent `SyncService` feeds a
state-based LWW-register CRDT. Conflicts are **detected and recorded** even when
they are resolved automatically. Equal logical timestamps still converge because
ordering is `logicalTimestamp → deviceId → operationId`.

This is **deterministic conflict resolution** / **conflict-free convergence after
synchronisation**. It is **not** mesh networking and **not** a claim of zero
conflicts.

**Mobile**

- Persistent `device.id` (UUID, not email)
- `SyncOperation` journal on every Slice 2/3 mutation
- Drift schema v5: `sync_operations`, `sync_conflicts`, `sync_entity_heads`
  (tombstones live on heads; garbage collection is future work)
- `CrdtEngine` with no Flutter widgets
- Sync Center, pending queue, conflict viewer, Road R-12 demo
- Status copy: LOCAL / SIMULATED SYNC / SYNCHRONIZED — never "real mesh"

**Backend**

- Alembic `0004_sync`
- `POST /api/v1/sync/push`, `POST /api/v1/sync/pull`, status and conflicts
- Development scenario `GET /api/v1/sync/demo-scenario`
- Optional seed: `python -m app.db.seed --sync-demo`

**Web**

- Synchronisation dashboard and conflict viewer
- Live pending/conflict counts on the dashboard

Not in this slice, by design: BLE, Wi-Fi Direct, LoRa, mesh routing,
store-carry-forward, IBLT, Merkle DAG, PBFT, HLC.

## Slice 5 — Mesh transport

- Bluetooth / BLE peer discovery and transfer
- Wi-Fi Direct for bulk payloads
- Store-carry-forward across a courier device
- Multi-hop routing between devices with no infrastructure

## Grand Finale candidates

LoRa and Wi-Fi HaLow carriage, Raspberry Pi / Jetson edge nodes, on-device
inference, the Digital Twin and decision support, hardened cryptography, device
trust and reputation, advanced identity, logistics verification.
