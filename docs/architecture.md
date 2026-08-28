# Architecture

## The invariant

> **Field devices must remain operational even when disconnected from the internet.**

Everything below follows from that single sentence. Any change that makes the
mobile app depend on the backend for a field operation is a regression,
regardless of how convenient it is.

## The pipeline

```
FIELD DEVICE
    ↓
LOCAL DATABASE            ← Slice 1 (implemented)
    ↓
LOCAL OPERATIONAL STATE   ← Slice 1 (implemented)
    ↓
PEER SYNCHRONISATION
    ↓
CONFLICT RESOLUTION
    ↓
SHARED OPERATIONAL STATE
    ↓
DIGITAL TWIN
    ↓
DECISION SUPPORT
    ↓
COORDINATED RESPONSE
```

Slice 1 builds the first two stages and the scaffolding the rest attach to.

## What "local-first" means here

The mobile app's SQLite database is the **primary operational datastore**, not a
cache of the server.

```
Mobile → Local DB → (later) Sync Layer → Backend
```

and never

```
Mobile → Backend → Database
```

Consequences that are already visible in the Slice 1 code:

| Decision | Where | Why |
| --- | --- | --- |
| The session is read from SQLite on start-up, not from `/auth/me` | `AuthRepository.restoreSession` | A device that reboots in a dead zone still knows who is holding it. |
| Login *writes* to the local database; nothing reads back from the network afterwards | `AuthRepository.signIn` | The network is an input, never a dependency. |
| Offline demo mode creates a real local session | `AuthRepository.startOfflineDemoSession` | The offline path is exercised by default, not bolted on later. |
| Primary keys are UUIDs, not sequences | `UuidPrimaryKeyMixin`, `LocalSessions.id` | Records authored on disconnected devices must merge without collision. |
| A link that fails a backend probe reports `DEGRADED`, not `ONLINE` | `resolveConnectivityStatus` | Captive portals and dead uplinks are normal in a disaster zone. |

The backend is a **synchronisation and command-centre peer**. It holds the
shared operational picture and serves the web command centre. It is not in the
critical path of a responder recording a casualty.

## Components

| Component | Stack | Role |
| --- | --- | --- |
| `mobile/` | Flutter, Riverpod, GoRouter, Drift/SQLite | Field device. Authoritative for what it records. |
| `web/` | React, Vite, TypeScript, Tailwind | Command centre. Read-heavy, always online. |
| `backend/` | FastAPI, SQLAlchemy, PostgreSQL/PostGIS | Coordination peer. Identity, shared state, later the sync endpoint. |
| `database/` | PostgreSQL 16 + PostGIS 3.4 | Durable shared state and geospatial queries. |

## Layering

Both the backend and the mobile app enforce the same separation:

```
presentation / API routes      HTTP and widgets only
        ↓
services / controllers         use-cases, no SQL, no widgets
        ↓
repositories / DAOs            all database access
        ↓
models / tables                schema
```

A route never opens a session; a widget never writes SQL. This is what makes
the sync layer insertable later without rewriting the UI.

## Data model roadmap

Slice 1 ships the minimum that authentication and device metadata require.

**Backend (PostgreSQL)** — `users` only, plus the `user_role` enum. PostGIS,
`pgcrypto` and `pg_trgm` are installed at first boot because enabling an
extension later needs superuser rights the application role will not hold.

**Mobile (SQLite, schema v1)** — `app_metadata`, `local_sessions`.

Planned tables and the slice that introduces them:

| Table | Slice | Notes |
| --- | --- | --- |
| `incidents` | 2 | Scope for every other operational record. |
| `responders` | 2 | Roster, check-in, assignment. |
| `tasks` | 2 | Work assigned to a responder. |
| `victims` | 2 | Offline-safe identifiers. |
| `triage_records` | 2 | START / jumpSTART categories, append-only. |
| `sos_events` | 3 | Distress beacons, relayed between devices. |
| `hazards` | 3 | Zones with an exclusion radius and expiry. |
| `locations` | 3 | PostGIS `geography(Point, 4326)` on the server. |
| `sync_operations` | 4 | The outbound queue; the unit of synchronisation. |
| `sync_conflicts` | 4 | Divergences a human must adjudicate. |
| `audit_events` | 4 | Append-only, attributable action log. |

None of these are stubbed in code. They appear when their slice lands, together
with a migration and tests.

## Security posture

Implemented in Slice 1:

- All configuration and every credential from the environment; nothing in source.
- bcrypt password hashing, with inputs over 72 bytes rejected rather than silently truncated.
- JWT access and refresh tokens, with the token type checked on use so a refresh token cannot authenticate a request.
- A blank `JWT_SECRET_KEY` is treated as unset: development mints an ephemeral key, staging and production refuse to start.
- Role-based authorisation through one primitive, `require_roles`.
- CORS restricted to configured origins.
- Request validation at the schema boundary; a uniform error envelope that never leaks internals.
- Timing-equalised login, so a wrong email and a wrong password are indistinguishable.
- Tokens on device in the Keystore/Keychain, deliberately outside the Drift database so a database export cannot leak them.

Explicitly **not** implemented, and not faked: zero-knowledge proofs,
decentralised identifiers, WebAuthn, blockchain anchoring, device attestation,
trust and reputation scoring.

## Deferred to the Grand Finale build

Bluetooth/BLE, Wi-Fi Direct, LoRa, Wi-Fi HaLow, multi-hop mesh routing,
store-carry-forward, CRDT merge strategies, Raspberry Pi / Jetson edge nodes,
on-device AI, the Digital Twin, and logistics verification.

The connectivity model already anticipates the first group: `ConnectivityTransport`
enumerates link types rather than a boolean, and Bluetooth alone already resolves
to `DEGRADED` — a real link, but not an internet path.
