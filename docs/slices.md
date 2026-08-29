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

## Slice 3 — Incidents and spatial awareness

- Incident declaration, lifecycle and sector breakdown
- Responder roster, check-in, task assignment
- `locations` on PostGIS `geography(Point, 4326)`
- SOS beacons: raise, relay, acknowledge, stand down
- Hazard reporting with exclusion radius and expiry
- Leaflet map in the command centre
- Offline tile caching on the field device

## Slice 4 — Synchronisation

- `sync_operations` outbound queue on the device
- Backend sync endpoint with idempotent, ordered application
- Deterministic conflict resolution; `sync_conflicts` for human adjudication
- Append-only `audit_events`
- Real "pending synchronisation" figure on the dashboard
- Victims registered offline finally reach the command centre on their own

## Slice 5 — Mesh transport

- Bluetooth / BLE peer discovery and transfer
- Wi-Fi Direct for bulk payloads
- Store-carry-forward across a courier device
- Multi-hop routing between devices with no infrastructure

## Grand Finale candidates

LoRa and Wi-Fi HaLow carriage, Raspberry Pi / Jetson edge nodes, on-device
inference, the Digital Twin and decision support, hardened cryptography, device
trust and reputation, advanced identity, logistics verification.
