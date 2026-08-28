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

## Slice 2 — Incidents, victims and triage

- Incident declaration, lifecycle and sector breakdown
- Responder roster, check-in, task assignment
- Victim registration with offline-safe identifiers
- START / jumpSTART triage capture, append-only
- Mobile: full offline authoring of the above
- Web: live incident and responder views replacing the placeholders

## Slice 3 — Spatial awareness

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

## Slice 5 — Mesh transport

- Bluetooth / BLE peer discovery and transfer
- Wi-Fi Direct for bulk payloads
- Store-carry-forward across a courier device
- Multi-hop routing between devices with no infrastructure

## Grand Finale candidates

LoRa and Wi-Fi HaLow carriage, Raspberry Pi / Jetson edge nodes, on-device
inference, the Digital Twin and decision support, hardened cryptography, device
trust and reputation, advanced identity, logistics verification.
