# Offline-First Disaster Response & Emergency Coordination Platform

**SIH 2026 prototype — Slice 2: Offline victim registration and digital triage**

> **Field devices must remain operational even when disconnected from the internet.**

---

## The problem

When an earthquake, flood or cyclone takes out the local network, the tools a
response team depends on stop working — at exactly the moment coordination
matters most. Teams fall back to paper and radio, casualty records are lost or
duplicated, hazards go unreported, and the command centre operates on a picture
that is hours stale.

The usual "offline mode" does not solve this. Caching the last server response
is useless to a responder who needs to *create* fifty triage records in a
basement with no signal.

## The core innovation

The field device's own database is the **primary operational datastore**, not a
cache.

```
Mobile → Local DB → (later) Sync Layer → Backend
```

and never

```
Mobile → Backend → Database
```

A responder registers a casualty and records a triage category against local
storage. The record is complete and authoritative the moment it is written.
Synchronisation, when a link appears, reconciles peers — it is never a
precondition for doing the work.

This is now demonstrable rather than aspirational. Put the device in aeroplane
mode, register ten casualties, triage them, kill the app, reopen it: everything
is there, ordered critical-first, marked `SYNC PENDING`. Nothing in that path
touches the backend.

The backend is a coordination **peer**: it holds the shared operational picture
and serves the command centre. It is not in the critical path of a responder in
the field.

## The field application

| Victim roster | Register | Record |
| --- | --- | --- |
| ![Victim roster](docs/screenshots/mobile-victims.png) | ![Register a casualty](docs/screenshots/mobile-register.png) | ![Casualty record](docs/screenshots/mobile-victim-detail.png) |

Captured on a device with no network interface. The roster is sorted
critical-first and headed by a live triage board; the registration form leads
with the triage decision because that is the one field that must not be skipped;
the record carries both the field id read aloud over radio (`V-CBEC-004`) and
the UUID that will survive reconciliation.

## The command centre

![Command centre dashboard](docs/screenshots/web-dashboard.png)

![Casualty roster](docs/screenshots/web-victims.png)

The Victims page and the two victim tiles on the dashboard are read from the
backend and marked `LIVE`. Incident, responder, hazard and synchronisation
figures are still hard-coded and carry the slice that will replace them — see
[`docs/screenshots/`](docs/screenshots) for the sign-in and placeholder pages.

## Architecture

```
FIELD DEVICE
    ↓
LOCAL DATABASE            ← implemented (Slice 1)
    ↓
LOCAL OPERATIONAL STATE   ← implemented (Slice 2: victims and triage)
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

The first two stages are built; the structure the rest attach to is in place.
Full detail in [`docs/architecture.md`](docs/architecture.md).

## Technology

| Layer | Stack |
| --- | --- |
| Mobile | Flutter · Dart · Riverpod · GoRouter · Drift/SQLite |
| Web | React · Vite · TypeScript · Tailwind CSS · React Router |
| Backend | Python 3.13 · FastAPI · SQLAlchemy 2 · Alembic · PyJWT · bcrypt |
| Database | PostgreSQL 16 · PostGIS 3.4 |
| Infrastructure | Docker Compose |

## Repository structure

```
disaster-response-platform/
├── mobile/              Flutter field application
├── web/                 React command centre
├── backend/             FastAPI coordination service
├── database/            PostGIS init scripts
├── docs/                architecture, slices, API
├── docker-compose.yml
├── .env.example
└── README.md
```

## Development setup

### Prerequisites

| Tool | Version | Needed for |
| --- | --- | --- |
| Python | 3.11+ (verified on 3.13.13) | backend |
| Node.js | 20+ (verified on 24.12) | web |
| Flutter SDK | 3.44+ (verified on 3.47.2 / Dart 3.13.2) | mobile |
| Docker Desktop | any current | PostgreSQL/PostGIS |

The backend and web app run without Docker or Flutter — see the notes under each
section.

**Windows only.** Building the mobile app for a device needs symlink support,
which means Developer Mode must be on (`start ms-settings:developers`). Without
it `flutter create` cannot link plugins; `flutter analyze` and `flutter test`
are unaffected.

### 1. Environment files

```bash
cp .env.example .env                  # docker-compose
cp backend/.env.example backend/.env  # backend
cp web/.env.example web/.env.local    # web (optional)
```

Generate the secrets:

```bash
python -c "import secrets; print(secrets.token_urlsafe(24))"   # POSTGRES_PASSWORD
python -c "import secrets; print(secrets.token_urlsafe(48))"   # JWT_SECRET_KEY
```

`JWT_SECRET_KEY` may be left blank in development — an ephemeral key is minted
per process, which means tokens do not survive a restart. Staging and production
refuse to start without one of at least 32 characters.

### 2. Start PostgreSQL + PostGIS

```bash
docker compose up -d db
docker compose logs -f db     # wait for "database system is ready to accept connections"
```

Data persists in the named volume `drp_db_data`. `docker compose down -v` wipes
it and re-runs `database/init/` on the next start.

### 3. Backend

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate            # Windows
source .venv/bin/activate         # macOS / Linux

pip install -r requirements-dev.txt
alembic upgrade head
python -m app.db.seed
uvicorn app.main:app --reload
```

- API: <http://localhost:8000>
- Interactive docs: <http://localhost:8000/docs>
- Health: <http://localhost:8000/health>

**Without Docker.** Point `DATABASE_URL` at SQLite in `backend/.env`; every
command above works unchanged:

```
DATABASE_URL=sqlite+pysqlite:///./drp_dev.sqlite3
```

**Seeding.** `python -m app.db.seed` creates one account per role at
`@drp.example`. The password comes from `SEED_PASSWORD`; leave it blank and a
strong one is generated and printed once. No credential is ever committed.

`python -m app.db.seed --victims` additionally inserts five demo casualties so
the command centre's Victims page has something to show. They are tagged
`V-SEED-*` and attributed to `seed`, so they can never be mistaken for records
a responder actually registered. It is opt-in because the mobile app does not
upload yet: without it the page is legitimately empty, and that emptiness is
the honest state of the system.

### 4. Web command centre

```bash
cd web
npm install
npm run dev
```

<http://localhost:5173>. Sign in with a seeded account.

### 5. Mobile field app

The repository tracks `lib/`, `test/` and the pubspec. Native platform folders
and the Drift generated code are produced on your machine:

```powershell
cd mobile
./tool/bootstrap.ps1        # Windows
```

```bash
cd mobile
./tool/bootstrap.sh         # macOS / Linux
```

Then:

```bash
flutter analyze
flutter test
flutter run --dart-define=DRP_API_BASE_URL=http://10.0.2.2:8000/api/v1
```

`10.0.2.2` is the Android emulator's alias for the host loopback; use
`http://127.0.0.1:8000/api/v1` on desktop or the LAN address on a handset.

The app runs with **no backend at all** — choose *Continue in Offline Demo Mode*.
See [`mobile/README.md`](mobile/README.md).

### Everything at once

```bash
docker compose up -d --build     # PostGIS + API
cd web && npm run dev            # command centre
cd mobile && flutter run         # field device
```

## Environment variables

### Root `.env` (docker-compose)

| Variable | Default | Notes |
| --- | --- | --- |
| `POSTGRES_DB` | `drp` | |
| `POSTGRES_USER` | `drp_app` | |
| `POSTGRES_PASSWORD` | — | **Required.** Compose refuses to start without it. |
| `POSTGRES_PORT` | `5432` | Host port. |
| `API_PORT` | `8000` | Host port. |
| `ENVIRONMENT` | `development` | `development` · `test` · `staging` · `production` |
| `JWT_SECRET_KEY` | — | Required outside development. |
| `CORS_ORIGINS` | `http://localhost:5173,...` | Comma-separated. |
| `SEED_PASSWORD` | — | Blank generates one and prints it once. |

### `backend/.env`

Everything above, plus `DATABASE_URL`, `DATABASE_ECHO`, `LOG_LEVEL`,
`API_V1_PREFIX`, `ACCESS_TOKEN_EXPIRE_MINUTES`, `REFRESH_TOKEN_EXPIRE_MINUTES`.
See [`backend/.env.example`](backend/.env.example).

### `web/.env.local`

| Variable | Default |
| --- | --- |
| `VITE_API_BASE_URL` | `http://127.0.0.1:8000/api/v1` |
| `VITE_COMMAND_CENTRE_NAME` | `State EOC — Gandhinagar` |

Only `VITE_*` variables reach the browser. Never put a secret in them.

### Mobile

Configuration is compile-time, via `--dart-define`:

| Variable | Default |
| --- | --- |
| `DRP_API_BASE_URL` | `http://10.0.2.2:8000/api/v1` |

## Tests

```bash
cd backend && pytest        # 60 tests
cd web     && npm test      # 34 tests
cd mobile  && flutter test  # 79 tests
```

| Suite | Tests | Covers |
| --- | --- | --- |
| `backend/tests/test_health.py` | 3 | Liveness, readiness, versioned alias |
| `backend/tests/test_auth.py` | 20 | Login, refresh, `/me`, token typing, hashing, validation |
| `backend/tests/test_roles.py` | 4 | The five roles and `require_roles` |
| `backend/tests/test_config.py` | 9 | Secret-key and CORS configuration guards |
| `backend/tests/test_victims.py` | 24 | Upload, idempotent retry, reassessment, ordering, counts, filters |
| `web/src/app/routing.test.tsx` | 10 | Startup, protected-route redirects |
| `web/src/app/authenticatedRoutes.test.tsx` | 11 | Session restore, dashboard, live victim counts, placeholders, sign-out |
| `web/src/features/auth/LoginPage.test.tsx` | 3 | Credential success, rejection, unreachable backend |
| `web/src/features/victims/VictimsPage.test.tsx` | 10 | Triage counts, roster, ordering, filters, unreachable backend |
| `mobile/test/app_smoke_test.dart` | 7 | Boots the real app: splash, login, offline demo, home, placeholders, restart |
| `mobile/test/local_database_test.dart` | 11 | Drift init, schema, session persistence |
| `mobile/test/connectivity_test.dart` | 15 | `ONLINE`/`DEGRADED`/`OFFLINE` resolution |
| `mobile/test/auth_flow_test.dart` | 12 | Offline demo, sign-in, role model, redirect policy |
| `mobile/test/victim_store_test.dart` | 26 | Schema v2, registration, persistence, reassessment, ordering, filters, counts |
| `mobile/test/victim_offline_flow_test.dart` | 8 | The whole offline journey through the real app widget |

The backend suite runs against a temporary SQLite file, and the mobile suite
against an in-memory SQLite database, so neither needs Docker or PostgreSQL.

`mobile/test/app_smoke_test.dart` and `victim_offline_flow_test.dart` pump the
real `DisasterResponseApp` widget and override only what needs a physical
device — the database location and the platform connectivity channel. The
victim flow test additionally forces *no transport at all* and a backend probe
that always fails, so if any step of registering, listing, reassessing or
reopening a casualty needed the backend, none of those eight tests would pass.

The acceptance run in the Slice 2 brief is `victim_offline_flow_test.dart`
verbatim: boot offline, open Victims, register, tear the app down, boot it
again over the same database, confirm the record is still there, change the
triage category, restart again, confirm the change survived — for all four
categories.

## Implemented

### Slice 1 — Foundation

**Backend** — layered FastAPI service; `/health` and `/health/ready`;
`/auth/login`, `/auth/refresh`, `/auth/me`; `users` table and five-role enum;
bcrypt hashing; JWT with enforced token typing; `require_roles` authorisation;
CORS; request validation; uniform error envelope; Alembic migration;
environment-driven seeding.

**Web** — command-centre shell with sidebar and top bar; login; protected routes
and session restore; dashboard metrics labelled as demo data; placeholder pages
for the unbuilt modules.

**Mobile** — splash with real session restoration; login and offline demo mode;
role display and selection; responder home showing incident, role, connectivity
and local database status; profile and sign-out; Drift schema v1; connectivity
service; GoRouter across all eleven destinations.

**Infrastructure** — Docker Compose with PostgreSQL 16 + PostGIS 3.4, a
persistent volume, health checks, and first-boot extension provisioning.

### Slice 2 — Offline victim registration and digital triage

**Mobile** — victim list, register, detail and edit/reassess screens; four
triage categories and five statuses; device-minted UUIDs and radio-readable
temporary ids; search, triage and status filters, critical-first ordering;
`OFFLINE` / `LOCAL DATA` / `SYNC PENDING` on every victim surface; Drift schema
v2 with the `victims` table and its migration. **No step of this calls the
backend.**

**Backend** — `victims` table and four new enums; migration `0002_victims`;
list, board, read, upload and patch endpoints; idempotent upload so a device
retrying an unconfirmed send cannot duplicate a casualty.

**Web** — Victims page with counts for every triage category and the casualty
roster; search and filter; live victim counts on the dashboard.

## Deliberately not implemented

SOS, GPS tracking, hazard detection, incident scoping, CRDT synchronisation,
mesh networking, the Digital Twin, AI, routing, hospital and resource
management, and advanced security (ZKP, DID, WebAuthn, blockchain, device
trust).

None of it is stubbed or simulated. Every unbuilt module renders a page naming
the slice that will deliver it. See [`docs/slices.md`](docs/slices.md).

Two things are worth being explicit about, because their absence is a design
decision rather than an omission:

- **Victim records do not leave the device.** The upload endpoint exists and is
  tested, but the mobile app never calls it. Giving records a way to travel is
  Slice 4's job, and building half of it now would mean building it twice.
- **Triage history is not kept.** Reassessment overwrites the category and bumps
  `updated_at`. An append-only clinical record is worth having once there is a
  synchronisation layer to merge two devices' versions of it.

## Known limitations

- **Two API listeners may be running at once.** Docker Compose maps the API to
  `API_PORT` (this machine uses `8001` because a local `uvicorn` already holds
  `8000`). The web app's `VITE_API_BASE_URL` defaults to port `8000`. Point it
  at whichever process you intend to use.
- **First Android build is slow.** Gradle `assembleDebug` takes about a minute
  on a cold cache. Subsequent runs are much faster.
- **Development JWT keys are ephemeral.** With `JWT_SECRET_KEY` blank, restarting
  the backend invalidates every issued token. Set one to avoid this.
- **Most of the dashboard is still fabricated.** Victim counts are live; the
  incident, responder, hazard and synchronisation figures are hard-coded in
  `web/src/features/dashboard/operationalSnapshot.ts` and labelled in the UI.
- **The command centre only sees uploaded victims.** Since the mobile app does
  not upload yet, the Victims page is empty until something posts to
  `POST /api/v1/victims` — `python -m app.db.seed --victims` will. That is the
  honest state of the system until Slice 4.
- **The mobile incident is fabricated.** Single constant in
  `mobile/lib/domain/entities/demo_data.dart`, labelled in the UI.
- **Vitest uses the `threads` pool.** The default `forks` pool fails to start
  workers when the repository path contains a space.

## Documentation

- [`docs/architecture.md`](docs/architecture.md) — the invariant, layering, data-model roadmap, security posture
- [`docs/slices.md`](docs/slices.md) — what each slice delivers
- [`docs/api.md`](docs/api.md) — endpoints, error envelope, roles
- [`mobile/README.md`](mobile/README.md) — bootstrap, layout, Drift workflow
- [`database/README.md`](database/README.md) — init vs. migrations, reset
