-- MAP OBJECTS -- every map row, with an integer id. v2 of the live map editor.
--
-- v1 (2026-08-31) kept the baked array as an unaddressable cold layer and derived a
-- row's identity from its content (class|x|y|z). Every hard bug that day came from
-- that: scientific-notation keys, the negative-sign key, tombstones by occurrence
-- count for duplicate positions, two languages that had to render one string
-- identically -- and a defect it could not fix, that moving a baked object in-game
-- re-created it with an empty init. This table gives every row an id instead.
--
-- fn_mapData.sqf is GENERATED from this table at pack time (tools/map_generate.py)
-- and committed, so git still shows every map change. The generated file carries
-- AP_mapBakedRev; the runtime applies every row with rev > that.
--
-- TEXT, never jsonb: apdb re-encodes jsonb into the game's mres codec on read and a
-- double encode is silent data loss. loadout is a plain array string, read with
-- parseSimpleArray, per the greenhouse_crop precedent.
--
-- Idempotent throughout.

CREATE TABLE IF NOT EXISTS map_objects (
    id          bigserial    PRIMARY KEY,
    world       varchar(32)  NOT NULL DEFAULT 'Malden',
    classname   varchar(128) NOT NULL,
    x           double precision NOT NULL,
    y           double precision NOT NULL,
    z           double precision NOT NULL,
    vdir_x      double precision NOT NULL DEFAULT 0,
    vdir_y      double precision NOT NULL DEFAULT 1,
    vdir_z      double precision NOT NULL DEFAULT 0,
    vup_x       double precision NOT NULL DEFAULT 0,
    vup_y       double precision NOT NULL DEFAULT 0,
    vup_z       double precision NOT NULL DEFAULT 1,
    init        text         NOT NULL DEFAULT '',   -- TRUSTED WRITERS ONLY; the in-game path never sets it
    is_server   boolean      NOT NULL DEFAULT false,
    loadout     text         DEFAULT NULL,           -- plain array string; emitted as [] when NULL
    layer       varchar(64)  NOT NULL DEFAULT 'AP_MAPDATA',
    deleted     boolean      NOT NULL DEFAULT false, -- soft delete; purged by map_generate after a pack
    rev         bigint       NOT NULL DEFAULT 0,     -- set by the trigger; writers never supply it
    author_uid  varchar(20)  NOT NULL,
    updated_at  timestamptz  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS map_objects_world_rev ON map_objects (world, rev);

CREATE TABLE IF NOT EXISTS map_meta (
    world varchar(32) PRIMARY KEY,
    rev   bigint      NOT NULL DEFAULT 0
);
INSERT INTO map_meta (world, rev) VALUES ('Malden', 0) ON CONFLICT (world) DO NOTHING;

-- One trigger. Every INSERT/UPDATE bumps map_meta.rev and stamps the new value into
-- the row. A writer cannot forget to signal, and every row knows when it last changed.
-- BEFORE, so NEW.rev is set on the row being written.
CREATE OR REPLACE FUNCTION map_objects_stamp() RETURNS trigger AS $$
BEGIN
    INSERT INTO map_meta (world, rev) VALUES (NEW.world, 1)
        ON CONFLICT (world) DO UPDATE SET rev = map_meta.rev + 1
        RETURNING rev INTO NEW.rev;
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS map_objects_stamp ON map_objects;
CREATE TRIGGER map_objects_stamp BEFORE INSERT OR UPDATE ON map_objects
    FOR EACH ROW EXECUTE FUNCTION map_objects_stamp();

-- map_edit_log is unchanged from v1 and stays.

-- v1's delta tables. Both are empty; nothing reads them after this plan lands.
DROP TRIGGER IF EXISTS map_edits_bump  ON map_edits;
DROP TRIGGER IF EXISTS map_hidden_bump ON map_hidden;
DROP TABLE IF EXISTS map_edits;
DROP TABLE IF EXISTS map_hidden;
DROP FUNCTION IF EXISTS map_bump_rev();
