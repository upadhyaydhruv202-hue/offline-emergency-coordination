-- Runs once, when the Postgres data directory is first initialised.
--
-- PostGIS is enabled now even though Slice 1 stores no geometry: adding an
-- extension later requires superuser rights the application role will not
-- have, so it is provisioned up front.

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;

-- gen_random_uuid() and digest helpers.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Trigram indexes for responder/victim name search in a later slice.
CREATE EXTENSION IF NOT EXISTS pg_trgm;

DO $$
BEGIN
    RAISE NOTICE 'PostGIS % initialised on database %', postgis_version(), current_database();
END
$$;
