-- MAP EDITS -- the live map-editor delta layer.
--
-- The world ships in two baked places: mission.sqm (the designer's layer) and
-- core/config/fn_mapData.sqf (allLocalMapEntities, ~9384 rows). Neither can be
-- written at runtime -- both live inside the PBO. This is the HOT layer on top:
-- additions live in map_edits, subtractions of BAKED rows live in map_hidden as
-- tombstones (you cannot DELETE a row out of a PBO array).
--
-- TEXT everywhere, never jsonb: apdb re-encodes jsonb columns into the game's own
-- mres codec on read and the double encode is silent data loss (deploy/faction_war.sql
-- records the same rule).
--
-- Idempotent throughout: IF NOT EXISTS on every object, so re-running against a
-- database that already has half of this applied is a no-op, not a failure.

CREATE TABLE IF NOT EXISTS map_edits (
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
    init        text         NOT NULL DEFAULT '',
    preset      varchar(64)  DEFAULT NULL,
    layer       varchar(64)  NOT NULL DEFAULT 'AP_LIVE',
    author_uid  varchar(20)  NOT NULL,
    created_at  timestamptz  NOT NULL DEFAULT now(),
    updated_at  timestamptz  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS map_edits_world_xy ON map_edits (world, x, y);

CREATE TABLE IF NOT EXISTS map_hidden (
    world       varchar(32)  NOT NULL DEFAULT 'Malden',
    bake_key    varchar(160) NOT NULL,
    occurrences smallint     NOT NULL DEFAULT 1,
    author_uid  varchar(20)  NOT NULL,
    created_at  timestamptz  NOT NULL DEFAULT now(),
    PRIMARY KEY (world, bake_key)
);

CREATE TABLE IF NOT EXISTS map_edit_log (
    id          bigserial    PRIMARY KEY,
    world       varchar(32)  NOT NULL DEFAULT 'Malden',
    author_uid  varchar(20)  NOT NULL,
    op          varchar(16)  NOT NULL,
    target      varchar(160) NOT NULL,
    detail      text         NOT NULL DEFAULT '',
    at          timestamptz  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS map_edit_log_at ON map_edit_log (at DESC);

-- ---------------------------------------------------------------- change signal
-- The server has to notice edits it did not make itself: the primary authoring
-- path is 3DEN -> tools/map_push.py -> these tables, which never touches the game.
-- A revision counter is what it polls (one integer, once every ten seconds).
--
-- The bump is a TRIGGER rather than a line in each writer. There are two writers
-- already (map_push.py and APS_fnc_mapEditSRV) and a third is foreseeable, and a
-- writer that forgets to bump produces edits that land in the database and never
-- reach the running server -- silently, and looking exactly like "the poll is
-- broken". The database is the only place that cannot forget.

CREATE TABLE IF NOT EXISTS map_meta (
    world varchar(32) PRIMARY KEY,
    rev   bigint      NOT NULL DEFAULT 0
);

INSERT INTO map_meta (world, rev) VALUES ('Malden', 0)
    ON CONFLICT (world) DO NOTHING;

CREATE OR REPLACE FUNCTION map_bump_rev() RETURNS trigger AS $$
BEGIN
    INSERT INTO map_meta (world, rev)
        VALUES (COALESCE(NEW.world, OLD.world), 1)
    ON CONFLICT (world) DO UPDATE SET rev = map_meta.rev + 1;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS map_edits_bump  ON map_edits;
DROP TRIGGER IF EXISTS map_hidden_bump ON map_hidden;

CREATE TRIGGER map_edits_bump  AFTER INSERT OR UPDATE OR DELETE ON map_edits
    FOR EACH ROW EXECUTE FUNCTION map_bump_rev();
CREATE TRIGGER map_hidden_bump AFTER INSERT OR UPDATE OR DELETE ON map_hidden
    FOR EACH ROW EXECUTE FUNCTION map_bump_rev();
