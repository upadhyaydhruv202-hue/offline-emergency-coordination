# API reference (Slice 1)

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

## Roles

`RESCUE_TEAM`, `MEDICAL_TEAM`, `VOLUNTEER`, `INCIDENT_COMMANDER`, `ADMIN`.

The role is carried in the token's `role` claim. Routes declare which roles they
accept with a single primitive:

```python
@router.get("/incidents", dependencies=[Depends(require_roles(UserRole.INCIDENT_COMMANDER, UserRole.ADMIN))])
```

Slice 1 keeps this coarse on purpose. Per-incident scoping and delegated command
are a later slice and will build on `require_roles`, not replace it.

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

## Not implemented in Slice 1

Incidents, victims, triage, SOS, hazards, tasks, resources, locations and the
synchronisation endpoint. They arrive with their slices — see
[`slices.md`](./slices.md).
