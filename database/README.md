# Database

PostgreSQL 16 + PostGIS 3.4, run through `docker-compose.yml` at the repository root.

## Layout

| Path | Purpose |
| --- | --- |
| `init/` | SQL executed **once**, on first boot of an empty data directory. Extensions only. |
| `../backend/alembic/versions/` | Schema migrations. All tables and columns live here. |

The split matters: `init/` cannot be re-run without destroying the volume, so
anything that will ever need to change belongs in a migration instead.

## Starting it

```bash
# from the repository root, with .env present
docker compose up -d db
docker compose logs -f db          # wait for "database system is ready"
```

Data persists in the named volume `drp_db_data` across container restarts.

## Applying migrations

```bash
cd backend
alembic upgrade head
```

`alembic/env.py` reads `DATABASE_URL`, so the migration always targets the same
database the API will use.

## Resetting

```bash
docker compose down -v     # destroys drp_db_data, re-runs database/init on next up
```

## Slice 1 schema

One table, `users`, plus the `user_role` enum. The geospatial and
synchronisation tables described in `docs/architecture.md` arrive with the
slices that use them; PostGIS is installed now only because enabling an
extension later needs superuser rights the application role will not hold.
