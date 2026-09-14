# API reference

Interactive documentation is served at `http://localhost:8000/docs` while the
backend is running.

Base URL: `http://localhost:8000`, versioned prefix `/api/v1`.

## Health

| Method | Path | Auth | Description |
| --- | --- | --- | --- |
| `GET` | `/health` | none | Liveness. Touches nothing. |
| `GET` | `/health/ready` | none | Readiness. Executes `SELECT 1`. |

```json
{
  "status": "ok",
  "service": "Disaster Response Platform API",
  "version": "0.1.0",
  "environment": "development",
  "timestamp": "2026-08-28T17:52:49.279234Z"
}
```

`/health/ready` adds `database`, `dialect` and, on failure, `detail`. It returns
HTTP 200 with `"status": "degraded"` when the database is unreachable, so a load
balancer can distinguish "process dead" from "dependency dead".

## Authentication

| Method | Path | Auth | Description |
| --- | --- | --- | --- |
| `POST` | `/api/v1/auth/login` | none | Exchange credentials for tokens. |
| `POST` | `/api/v1/auth/refresh` | none | Rotate an access token. |
| `GET` | `/api/v1/auth/me` | bearer | Profile of the caller. |

`POST /auth/login` and `GET /health` are also mounted without the version
prefix, matching the paths named in the Slice 1 specification. They are hidden
from the OpenAPI schema so `/api/v1/...` stays the single documented surface.

### `POST /api/v1/auth/login`

```json
{ "email": "commander@drp.example", "password": "..." }
```

```json
{
  "access_token": "eyJhbGciOi...",
  "refresh_token": "eyJhbGciOi...",
  "token_type": "bearer",
  "expires_in": 3600,
  "user": {
    "email": "commander@drp.example",
    "full_name": "A. Rathore",
    "role": "INCIDENT_COMMANDER",
    "id": "1e2c2592-f9f4-4e2a-b4d7-2ee717510eca",
    "is_active": true,
    "created_at": "2026-08-28T17:52:08Z"
  }
}
```

A wrong password and an unknown email both return HTTP 401 with the same body,
and take the same time — the service hashes a throwaway value when no account
matches.

### `POST /api/v1/auth/refresh`

```json
{ "refresh_token": "eyJhbGciOi..." }
```

Returns a fresh token pair. Presenting an **access** token here returns 401: the
`type` claim is checked, so the two are not interchangeable.

## Victims

| Method | Path | Auth | Description |
| --- | --- | --- | --- |
| `GET` | `/api/v1/victims` | bearer | Roster plus counts. Most urgent first. |
| `GET` | `/api/v1/victims/board` | bearer | Counts by triage category only. |
| `GET` | `/api/v1/victims/{id}` | bearer | One record. |
| `POST` | `/api/v1/victims` | bearer | Upload a record registered on a device. |
| `PATCH` | `/api/v1/victims/{id}` | bearer | Reassess triage, change status, correct details. |

These endpoints serve the command centre and receive uploads. **They are not on
the critical path for a responder.** A handset registers casualties into its own
SQLite and stays fully usable with this API unreachable; nothing in the mobile
victim flow calls it.

### `POST /api/v1/victims`

The device supplies the identifiers, because the record already exists there
and is already known by those identifiers on the radio and on the triage tag.

```json
{
  "id": "6b1f8c2e-3d4a-4f21-9c77-0b2f1d5a8e33",
  "temporary_id": "V-8C1F-007",
  "name": "A. Sharma",
  "age": 41,
  "age_group": "ADULT",
  "gender": "FEMALE",
  "injury_type": "Crush injury to left leg",
  "triage_category": "CRITICAL",
  "created_by": "e0b1...device-session-id",
  "created_at": "2026-08-29T08:12:00Z"
}
```

Only `id`, `temporary_id`, `triage_category` and `created_by` are required. An
unidentified casualty must never be harder to register than a named one.

Re-posting the same `id` **updates** the stored record instead of returning 409.
A device with an intermittent link retries uploads it cannot confirm, and that
retry has to be harmless.

`priority` is derived from `triage_category` and returned with every record —
it is the sort key, lowest first, and cannot be set by a client.

### `GET /api/v1/victims`

| Query | Values |
| --- | --- |
| `search` | Matched against name, temporary id and injury type. |
| `triage` | `CRITICAL` · `URGENT` · `MODERATE` · `STABLE` |
| `status` | `REGISTERED` · `UNDER_TREATMENT` · `AWAITING_EVACUATION` · `EVACUATED` · `DECEASED` |
| `limit` | 1–500, default 100 |
| `offset` | default 0 |

```json
{
  "items": [ { "...": "one VictimRead per row" } ],
  "board": {
    "total": 12,
    "open_cases": 9,
    "evacuated": 3,
    "by_triage": { "critical": 4, "urgent": 3, "moderate": 2, "stable": 3 }
  },
  "total": 12
}
```

`board` counts every record regardless of the active filter, and always carries
all four categories. A command centre filtered to `STABLE` still needs to see
that four criticals are outstanding, and an empty `CRITICAL` column must not be
indistinguishable from a broken query.

### `PATCH /api/v1/victims/{id}`

A partial update; omitted fields are left alone. `id`, `temporary_id`,
`created_by`, `created_at` and `priority` are ignored if sent — identity and
provenance travel with the record from the device and are not the server's to
rewrite.

```json
{ "triage_category": "CRITICAL", "status": "AWAITING_EVACUATION" }
```

## Roles

`RESCUE_TEAM`, `MEDICAL_TEAM`, `VOLUNTEER`, `INCIDENT_COMMANDER`, `ADMIN`.

The role is carried in the token's `role` claim. Routes declare which roles they
accept with a single primitive:

```python
@router.get("/incidents", dependencies=[Depends(require_roles(UserRole.INCIDENT_COMMANDER, UserRole.ADMIN))])
```

This stays coarse on purpose: the victim endpoints admit any authenticated
responder, because in a mass-casualty incident anyone holding a device may be
the one who finds the casualty. Per-incident scoping and delegated command are a
later slice and will build on `require_roles`, not replace it.

## Errors

Every failure uses one envelope:

```json
{
  "error": {
    "code": "authentication_failed",
    "message": "Invalid email or password",
    "details": null
  }
}
```

| Code | Status | Meaning |
| --- | --- | --- |
| `validation_error` | 422 | Request body failed schema validation; `details` carries the field errors. |
| `authentication_failed` | 401 | Missing, malformed, expired or wrong-type token, or bad credentials. |
| `not_authorized` | 403 | Authenticated, but the role is not permitted. |
| `not_found` | 404 | No such resource. |
| `conflict` | 409 | Uniqueness violation, e.g. duplicate email. |
| `service_unavailable` | 503 | A dependency is down. |
| `internal_error` | 500 | Unexpected. Logged with a stack trace; the response body never leaks internals. |

## Field operations

These endpoints serve the command centre and receive uploads. **They are not on
the critical path for a responder.** The mobile app does not call them in this
slice.

| Method | Path | Auth | Description |
| --- | --- | --- | --- |
| `GET` | `/api/v1/incidents` | bearer | Roster, most recent first. |
| `GET` | `/api/v1/incidents/board` | bearer | Counts by status. |
| `GET` | `/api/v1/incidents/{id}` | bearer | One incident. |
| `POST` | `/api/v1/incidents` | bearer | Idempotent upload of a device-declared incident. |
| `PATCH` | `/api/v1/incidents/{id}` | bearer | Partial update. |
| `GET` | `/api/v1/hazards` | bearer | Roster, most severe first. `type`, `severity`, `status`. |
| `GET` | `/api/v1/hazards/board` | bearer | Counts by severity and status. |
| `POST` / `PATCH` | `/api/v1/hazards` | bearer | Idempotent upload / partial update. |
| `GET` | `/api/v1/sos` | bearer | Queue, most urgent first. |
| `GET` | `/api/v1/sos/board` | bearer | Counts by priority and status. |
| `POST` / `PATCH` | `/api/v1/sos` | bearer | Idempotent upload / partial update. |
| `GET` | `/api/v1/tasks` | bearer | Board, highest priority first. |
| `GET` | `/api/v1/tasks/board` | bearer | Counts by status. |
| `POST` / `PATCH` | `/api/v1/tasks` | bearer | Idempotent upload / partial update. |
| `GET` | `/api/v1/responders` | bearer | Account roster. Read-only. |
| `GET` | `/api/v1/sync/status` | bearer | Queue counts. Peer ingest, not mesh. |
| `GET` | `/api/v1/sync/conflicts` | bearer | Recorded conflicts. |
| `GET` | `/api/v1/sync/demo-scenario` | bearer | Road R-12 development story. |
| `GET` | `/api/v1/sync/operations` | bearer | Ingested sync journal. |
| `GET` | `/api/v1/command/snapshot` | bearer | Common operational picture (KPIs, markers, alerts, activity). |
| `GET` | `/api/v1/facilities` | bearer | Hospitals, shelters, resource caches. Filter `kind`. |
| `POST` / `PATCH` | `/api/v1/facilities` | commander/admin | Create or update a facility. |
| `GET` | `/api/v1/audit/events` | bearer | COP activity feed. |
| `PATCH` | `/api/v1/responders/{id}/presence` | self or commander | Last known status and position. |

`POST /sync/push` records a conflict when two devices updated the same entity.
Duplicate `operation_id` values are ignored. Empty payloads are rejected.

## Not implemented yet

Mesh radios (BLE / Wi-Fi Direct / LoRa), Digital Twin intelligence, and Edge AI
are Slice 6. See [`slices.md`](./slices.md).
