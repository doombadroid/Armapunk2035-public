-- MAP OBJECTS v3 -- the table is the ONLY source of placement data (mapdb.md, 2026-09-04).
--
-- v2 generated fn_mapData.sqf from this table at pack time and shipped it in the mission PBO.
-- v3 ships nothing: the server loads every live row at boot (APS_fnc_mapLoad), bins it into
-- 1 km grid cells, and clients fetch cells on demand (APS_fnc_mapFetch). Three things a row
-- could not say before are columns now:
--   model     -- a mission-relative .p3d path for custom buildings (custom_p3ds/malden_buildings.sqf
--                used to be a separate file-based loader; those 85 placements are rows now)
--   lod       -- detail tier: 0 always, 1 normal, 2 decor, 3 never by default. Replaces the
--                random 80 % decor cull in the old streamer with something editable.
--   stream_r  -- per-object stream-in radius in metres. NULL = default (1500), 0 = always
--                loaded, above 2000 = far bucket sent at join. Replaces the 19 zone circles.
-- on_server marks rows that ALSO get a local copy on the dedicated server (custom buildings:
-- AI and vehicle collision). is_server keeps its v2 meaning (server-global, never on clients).
--
-- Soft deletes stay. The pack-time purge is gone with the pack; APS_fnc_mapLoad purges
-- tombstones older than 7 days at boot. Idempotent throughout.

ALTER TABLE map_objects ALTER COLUMN classname SET DEFAULT '';
ALTER TABLE map_objects ADD COLUMN IF NOT EXISTS model     text     NOT NULL DEFAULT '';
ALTER TABLE map_objects ADD COLUMN IF NOT EXISTS scale     real     NOT NULL DEFAULT 1;
ALTER TABLE map_objects ADD COLUMN IF NOT EXISTS lod       smallint NOT NULL DEFAULT 1;
ALTER TABLE map_objects ADD COLUMN IF NOT EXISTS stream_r  real     NULL;
ALTER TABLE map_objects ADD COLUMN IF NOT EXISTS on_server boolean  NOT NULL DEFAULT false;

DO $$ BEGIN
    ALTER TABLE map_objects ADD CONSTRAINT map_objects_ident_ck  CHECK (classname <> '' OR model <> '');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
    ALTER TABLE map_objects ADD CONSTRAINT map_objects_lod_ck    CHECK (lod BETWEEN 0 AND 3);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
    ALTER TABLE map_objects ADD CONSTRAINT map_objects_stream_ck CHECK (stream_r IS NULL OR stream_r >= 0);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS map_objects_world_live ON map_objects (world, id) WHERE NOT deleted;
