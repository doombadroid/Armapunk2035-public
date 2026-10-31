-- FACTION TERRITORIES, ALIGNMENT AND THE WEEKLY WAR.
--
-- Two halves, deliberately in one file.
--
-- HALF ONE -- the columns that were never delivered.
--   gangs.faction, gangs.faction_rep, players.faction_rep and
--   players.faction_talents are written by live SQF today
--   (fn_gangAlignSRV.sqf, fn_aqRep.sqf, fn_buyFactionPerkSRV.sqf) and exist on
--   the dev database because somebody ALTERed it by hand. They are in no
--   migration file and in no generated schema, so any OTHER database this
--   project is ever stood up on gets a server that aligns a gang, reports
--   success, and writes the alignment nowhere. NEEDSFIX.md records the same
--   thing about the armaquest_state migration.
--
--   They are NOT in tools/pgmigrate/target_schema.sql and cannot be: that file
--   is GENERATED from mysqldumps of the frozen live box, and those dumps predate
--   every column here. Hand-editing a generated file would be undone by the next
--   regeneration with no error. deploy/hud_layout.sql set the precedent -- a
--   feature that adds schema ships its own idempotent .sql.
--
-- HALF TWO -- what the war itself needs.
--
-- Idempotent throughout: IF NOT EXISTS on every add, so re-running against dev
-- (where half one is already applied) is a no-op rather than a failure.

-- ---------------------------------------------------------------- half one
-- mres-encoded blobs, shaped [[factionId, value], ...]. TEXT, never jsonb:
-- apdb re-encodes jsonb columns into the game's own mres codec on read, and a
-- double encode is silent data loss. Read BARE, never QUOTE()-wrapped
-- (fn_aqRep.sqf's header records the two times that drew blood).
ALTER TABLE players ADD COLUMN IF NOT EXISTS faction_rep      text DEFAULT NULL;
ALTER TABLE players ADD COLUMN IF NOT EXISTS faction_talents  text DEFAULT NULL;
ALTER TABLE gangs   ADD COLUMN IF NOT EXISTS faction_rep      text DEFAULT NULL;

-- A plain VARCHAR, so this one IS QUOTE()d on read -- the inverse of the rule
-- directly above it, and getting the two backwards is the documented footgun.
ALTER TABLE gangs   ADD COLUMN IF NOT EXISTS faction          varchar(32) DEFAULT NULL;

-- ---------------------------------------------------------------- half two
-- Defection cooldown. NULL means "never realigned", which reads as "no cooldown
-- outstanding" -- the same absence-is-the-neutral-state discipline the mres rep
-- blobs use, and it means a gang aligning for the FIRST time is never charged a
-- cooldown it could not have known about.
ALTER TABLE gangs   ADD COLUMN IF NOT EXISTS faction_changed  timestamptz DEFAULT NULL;

-- The week's matchup and the score that decides the next one. Single row,
-- id = 1, modelled on cartel_state and gangfort -- the two world-state tables
-- this codebase already restores at boot.
--
-- week_key is an ISO year-week STRING ('2026-W35'), not a timestamp, and the
-- rollover job compares it for INEQUALITY rather than counting elapsed time.
-- That is what makes the rollover survive a restart, a server that was down
-- across the boundary, and a clock that moved: the question "is the stored week
-- the current week" has the same answer however long the process has been up.
--
-- scores is jsonb and is the ONE place that is safe, because nothing decodes it
-- through the mres path -- the rollover job reads it server-side and no client
-- ever sees the column. Shape: {"f_neon": 1200, "f_dock": 900, "f_pharma": 40}.
-- A faction absent from the object scores zero.
CREATE TABLE IF NOT EXISTS faction_war (
  id         integer     NOT NULL,
  week_key   text        NOT NULL DEFAULT '',
  aggressor  text        NOT NULL DEFAULT '',
  defender   text        NOT NULL DEFAULT '',
  neutral    text        NOT NULL DEFAULT '',
  started    timestamptz NOT NULL DEFAULT now(),
  scores     jsonb       NOT NULL DEFAULT '{}'::jsonb,
  updated    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT faction_war_pkey PRIMARY KEY (id)
);

-- Seed the single row empty. The rollover job fills it on its first tick,
-- because an empty week_key can never equal the current one -- so a fresh
-- database schedules a war without needing a separate bootstrap path.
INSERT INTO faction_war (id) VALUES (1) ON CONFLICT (id) DO NOTHING;
