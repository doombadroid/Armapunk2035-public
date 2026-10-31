-- PostGIS on the dev database (2026-09-04). Image: postgis/postgis:18-3.6 (deploy/postgres/compose.yml).
-- Idempotent. Applied by hand after the container swap; keep it re-runnable for any stand-up.
--
--   map_objects.geom       generated Point(x,y), SRID 0 -- Malden is a planar game world in metres.
--                          GiST-indexed: ST_DWithin / bbox / nearest queries in SQL (tools/map_query.py).
--   map_cell_key()         the streamer's cell rule in SQL. Constants MIRROR fn_mapCfg.sqf
--                          (cell 1000, far 2000); tools/test_map_cell_key.py keeps them equal.
--   faction_territory      the fixer polygons (were an SQF literal in fn_factionCfg.sqf). Baked by
--                          tools/bake_territory.py from Eden markers; the server publishes them at
--                          boot (APS_fnc_territoryLoad -> AP_factionPolys); `points` is the SQF
--                          literal the game parses, `geom` is what SQL asks (ST_Contains etc.).

CREATE EXTENSION IF NOT EXISTS postgis;

ALTER TABLE map_objects ADD COLUMN IF NOT EXISTS geom geometry(Point, 0)
    GENERATED ALWAYS AS (ST_SetSRID(ST_MakePoint(x, y), 0)) STORED;
CREATE INDEX IF NOT EXISTS map_objects_geom_gist ON map_objects USING GIST (geom) WHERE NOT deleted;

CREATE OR REPLACE FUNCTION map_cell_key(px double precision, py double precision, stream_r real)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE
        WHEN COALESCE(stream_r, -1) = 0 OR COALESCE(stream_r, -1) > 2000 THEN 'far'
        ELSE floor(px / 1000)::int::text || '_' || floor(py / 1000)::int::text
    END
$$;

CREATE TABLE IF NOT EXISTS faction_territory (
    faction_id  varchar(32) PRIMARY KEY,           -- f_neon, f_dock, f_pharma, f_maxsec (fn_factionCfg ids)
    points      text        NOT NULL,              -- SQF literal [[x,y],...], the game parses this
    geom        geometry(Polygon, 0) NOT NULL,     -- closed ring of the same points, what SQL asks
    rev         integer     NOT NULL DEFAULT 1,
    updated_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT faction_territory_valid CHECK (ST_IsValid(geom))
);
CREATE INDEX IF NOT EXISTS faction_territory_geom_gist ON faction_territory USING GIST (geom);
