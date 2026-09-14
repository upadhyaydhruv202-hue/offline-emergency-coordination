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
LOCAL OPERATIONAL STATE   ← Slice 2–3 (implemented: victims, incidents, SOS, hazards, tasks)
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

Slice 1 built the first stage and the scaffolding the rest attach to. Slice 2
made the second stage real: a responder now creates operational records — not
just a session — with no network at all.

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

Consequences that are already visible in the code:

| Decision | Where | Why |
| --- | --- | --- |
| The session is read from SQLite on start-up, not from `/auth/me` | `AuthRepository.restoreSession` | A device that reboots in a dead zone still knows who is holding it. |
| Login *writes* to the local database; nothing reads back from the network afterwards | `AuthRepository.signIn` | The network is an input, never a dependency. |
| Offline demo mode creates a real local session | `AuthRepository.startOfflineDemoSession` | The offline path is exercised by default, not bolted on later. |
| Primary keys are UUIDs, not sequences | `UuidPrimaryKeyMixin`, `LocalSessions.id`, `Victims.id` | Records authored on disconnected devices must merge without collision. |
| A link that fails a backend probe reports `DEGRADED`, not `ONLINE` | `resolveConnectivityStatus` | Captive portals and dead uplinks are normal in a disaster zone. |
| Registering a victim makes no network call, not even an optimistic one | `VictimRepository.register` | The record is authoritative when it is written, not when it is acknowledged. |
| The device mints its own human-readable tag from a local counter | `AppMetadataDao.nextSequence`, `formatTemporaryId` | The number on the triage tag has to exist before any server sees the casualty. |
| Every victim row carries `syncStatus`, and the UI shows `SYNC PENDING` | `Victims.syncStatus`, `LocalDataBanner` | A responder is told what has and has not left the handset, rather than being left to assume. |
| Uploading the same victim id twice updates rather than conflicts | `VictimService.register` | A device retrying an upload it could not confirm must not create a duplicate casualty. |

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

## Data model

**Backend (PostgreSQL)** — `users` and `victims`, plus the `user_role`,
`triage_category`, `victim_status`, `age_group` and `gender` enums. PostGIS,
`pgcrypto` and `pg_trgm` are installed at first boot because enabling an
extension later needs superuser rights the application role will not hold.

**Mobile (SQLite, schema v3)** — `app_metadata`, `local_sessions`, `victims`,
`incidents`, `locations`, `sos_events`, `hazards`, `tasks`, `responder_status`,
`audit_events`.

The two `victims` tables carry the same fields under the same names, because a
device's row is uploaded verbatim in Slice 4. Both key on the UUID the device
minted, so the record has one identity for its whole life.

Slice 2 deliberately does **not** add a separate `triage_records` table.
Reassessment overwrites the category on the victim and bumps `updated_at`; an
append-only clinical history is worth building once synchronisation exists to
merge two devices' versions of it, and not before.

Planned tables and the slice that introduces them:

| Table | Slice | Notes |
| --- | --- | --- |
| `incidents` | 3 | Scope for every other operational record. Implemented. |
| `tasks` | 3 | Work a responder holds. Implemented. |
| `sos_events` | 3 | Local distress calls. Implemented. |
| `hazards` | 3 | Local hazard reports. Implemented. |
| `locations` | 3 | Device GPS fixes. Implemented on the handset. |
| `responder_status` | 3 | One current status per responder, on the device. |
| `audit_events` | 3 | Lightweight local trail. Shared peer log is Slice 4. |
| `sync_operations` | 4 | The outbound queue; the unit of synchronisation. |
| `sync_conflicts` | 4 | Divergences a human must adjudicate. |
| `triage_records` | 4 | Append-only reassessment history, once merge exists. |

`victims.latitude`, `victims.longitude` and `victims.incident_id` are written
when a casualty is registered against the current operation and last known
fix. They stay null when those facts were not available — that is the truth
about how the record was captured.

## Security posture

Implemented:

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
