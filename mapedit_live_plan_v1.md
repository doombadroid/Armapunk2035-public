# Live Map Editor (DB-backed) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An in-game, admin-gated map editor that places, moves, hides and deletes world objects live, persisting every edit to PostgreSQL instead of `mission.sqm` — with no server restart and no repack.

**Architecture:** **3DEN is the editor UI.** No gizmo gets built — the repo already drives the map from Eden through `tools/map_watch.py`, and the only broken part of that loop is its last mile: repack, restart, ~90 s, everyone reconnects. This plan replaces that last mile with a database push.

The baked world (`mission.sqm` + `core/config/fn_mapData.sqf`) stays exactly where it is and becomes the COLD layer. Postgres holds a HOT delta layer: `map_edits` (additions) and `map_hidden` (tombstones for baked rows, because a row inside a PBO array cannot be deleted). A save in 3DEN diffs the edit mission against the delta and writes the difference; a `map_meta.rev` counter bumps; the server notices on its next poll and broadcasts. Edits reach clients as ops (`add` / `del` / `move` / `hide`) through one applier, `AP_fnc_mapEditApply` — the same one a joining client replays to catch up, so there is exactly one code path for "a row changed" and no init-ordering hazard. Objects remain **client-local** (`AP_fnc_createVehicleLocal`), so an edit costs one local create per client and nothing on the network.

**Tech Stack:** SQF (mission + `AP_server` addon), PostgreSQL via `DB_fnc_asyncQuery`/PySQF, Python 3 for the offline bake-down and key tooling.

## Global Constraints

Copied from `CLAUDE.md` and the repo's own precedents. Every task inherits these.

- **Work on `main` directly.** `git fetch origin` + pull before starting any task.
- **Commit trailer:** `Co-Authored-By: <funny defunct AI>` (Tay, SmarterChild, ELIZA, Clippy, Dr. Sbaitso…), name only, **no email**, rotate. This overrides the harness default — do not emit a Claude/Anthropic trailer.
- Client fn `core/<domain>/fn_name.sqf` → `AP_fnc_name`, **must** be registered in `Functions.h`.
- Server fn `server/AP_server/core/TON/fn_name.sqf` → `APS_fnc_name`, **must** be registered in `server/AP_server/config.cpp`.
- Cross-machine calls go through `AP_fnc_MP`, never raw `remoteExec`: `[[args], "fn_name", target, false] spawn AP_fnc_MP` (target `2` = server, `0` = all clients, or an owner id).
- `CfgRE.hpp` is `mode = 1` (whitelist). A function without an entry silently fails. `allowedTargets`: `2` = client→server, `1` = server→client, `0` = any.
- **Schema files are PostgreSQL-flavoured** and applied out of band (precedent: `deploy/faction_war.sql`, `deploy/hud_layout.sql`). **Runtime SQL inside SQF stays MariaDB-flavoured** — `apdb_sql.py` translates it. Keep runtime statements to plain `SELECT`/`INSERT`/`DELETE` with `%s` placeholders, which are valid in both.
- **TEXT, never `jsonb`.** apdb re-encodes `jsonb` columns into the game's mres codec on read and the double encode is silent data loss.
- `varchar` columns are read `QUOTE()`-wrapped; mres-blob `text` columns are read **bare**. Getting these backwards is a documented footgun.
- `DB_fnc_asyncQuery` params: `[sql, mode, multiarr, sqlParams]`. Mode 2 (read) **must be spawned** — an unscheduled mode-2 call is refused and logged `[DBGUARD]`. The 4th argument is the injection-proof path and only works on the Postgres engine.
- Never persist code or action strings that a client supplied. Store IDs, resolve against server-side data at use time.
- **Before every deploy:** brace/bracket balance check with the Arma-aware tokenizer (`python3 tools/test_sqf_balance.py`). `""` is an escaped quote, not `\"`.
- **The dev database is `pgm_full_scratch`, not `armapunk`.** Verified from the running PySQF daemon's `PYSQF_DB_DSN` (up since 2026-08-27) and confirmed by content: `pgm_full_scratch` has 67 tables and 5 rows in `players_global`; `armapunk` has 17 tables and an empty `players_global`. The container's `POSTGRES_DB` default is `armapunk`, which is the trap — every `psql` command in this plan names the database explicitly for that reason. (The name is a leftover from the Postgres migration; worth renaming one day, out of scope here.)
- Deploy to DEV: `bash /home/timb/arma3server_dev/reload-armapunk2035.sh`. Success marker: `grep "read from bank" /home/timb/arma3server_dev/loonydev.log` (40–90 s). **Never** `reload-loonydev.sh` — that packs the other project.
- Client RPT: newest by mtime under `~/.local/share/Steam/steamapps/compatdata/107410/pfx/drive_c/users/steamuser/AppData/Local/Arma 3/*.rpt`. In-game probes `diag_log` with an `[AP-PROBE]` tag.
- **No test harness exists for SQF.** Every SQF task's "failing test" is an observed red state on the dev server (a probe line in the RPT / `loonydev.log`) — the red state must be SEEN before the fix, not assumed.

## Scope

**In scope (this plan):** the delta layer, the transport, the Eden push path, and a small in-world prune tool. On completion, a save in 3DEN lands on the running dev server in seconds, with no repack and no restart, and survives a reboot.

**Where the gate moved.** The original framing was "an in-game editor gated behind admin ranks". With 3DEN as the UI the primary write path never enters the game: `tools/map_push.py` runs on the box and talks to Postgres directly, so the gate on it is SSH and database access, not `adminlevel`. That is a **smaller** attack surface than an in-game write RPC, not a larger one. Task 6 keeps an in-game rank-gated path for the one thing Eden is bad at — pruning a prop you are standing in front of — and it is the door Zeus would come through later. **Task 6 is optional**: skip it and the Eden loop is complete on its own.

**Explicitly out of scope, and why:**

- **A hand-built transform gizmo.** Was Task 7 of the first draft; deleted. 3DEN already has the transformation widget, snapping, numeric attributes, asset browser search, multi-select, copy/paste, undo, layers and this repo's ~100 named compositions. Rebuilding a worse version of that was the most work in the plan for the least result.
- **Zeus / curator.** The repo has no curator wiring at all today (verified: zero matches in `mission/` and `server/`). Zeus is a reasonable *later* addition as a second in-world authoring surface — it would write the same `map_edits` rows through the same authority — but it is not needed for the Eden loop and it is not free (ZEN, for numeric transforms, is a mod that needs its key server-side).

- **Full `mission.sqm` evacuation** (moving the designer's 4464 objects and 303 markers into the DB, reducing the sqm to a ~100 KB stub of slots + attributes). It is feasible — playable slots and mission attributes are the only things that genuinely cannot leave — but it is a separate migration with its own risk surface, it depends on the delta layer being proven first, and it collides with the standing MARKERS-IN-MAP-LAYER order (see the note at the end of this plan). Separate plan, after Phase 2 ships.
- **The asset split** (moving heavy `.p3d`/`.paa` into `@Armapunk2035` so Steam does delta updates instead of re-shipping ~27 MB per build). Owner deferred, 2026-08-31.
- **`is_server = true` rows.** The editor refuses them in this plan. They need a global, replicated object and a matching `initServer` spawn path; local-only keeps the perf model intact.

## File Structure

| File | Responsibility |
| --- | --- |
| `deploy/map_edits.sql` | Idempotent Postgres schema for the three new tables. |
| `tools/mapkey.py` | The `bake_key` derivation, plus the parity probe generator. One definition, imported by everything Python. |
| `tools/test_mapkey.py` | Proves the derivation against the real 9384-row `fn_mapData.sqf`. |
| `tools/mapdelta_export.py` | Offline bake-down: DB delta → mapdata rows, tombstones applied. |
| `mission/.../core/functions/fn_mapZoneFor.sqf` | `AP_fnc_mapZoneFor` — the single zone-resolution rule, extracted from `fn_dynamicMapSystem`. |
| `mission/.../core/functions/fn_mapEditApply.sqf` | `AP_fnc_mapEditApply` — applies one op to this client's live world. The only writer of live map state. |
| `mission/.../core/admin/fn_mapPrune.sqf` | `AP_fnc_mapPrune` — the in-world prune tool (look at a prop, delete it). Optional, Task 6. |
| `server/AP_server/core/TON/fn_mapEditSRV.sqf` | `APS_fnc_mapEditSRV` — the in-game authority. Rank gate, validation, persist, broadcast. Optional, Task 6. |
| `server/AP_server/core/TON/fn_mapEditLoad.sqf` | `APS_fnc_mapEditLoad` — boot load + the per-client catch-up reply. |
| `server/AP_server/core/TON/fn_mapEditPoll.sqf` | `APS_fnc_mapEditPoll` — watch `map_meta.rev`, broadcast what changed out of band. |
| `tools/map_push.py` | Diff the 3DEN edit mission against the delta and write the difference. The Eden loop's last mile. |

Modified: `fn_dynamicMapSystem.sqf` (delegate zone resolution, tag created objects), `Functions.h`, `config.cpp`, `CfgRE.hpp`, `core/init.sqf`, `tools/edit-map.sh`, `tools/map_watch.py`.

---

## Task 1: Schema

**Files:**
- Create: `deploy/map_edits.sql`
- Test: manual, against the local `armapunk-pg` container

**Interfaces:**
- Produces: tables `map_edits`, `map_hidden`, `map_edit_log`.

`map_hidden.occurrences` exists because the baked array contains genuine duplicate rows — measured, not assumed: 9384 rows collapse to 9355 distinct keys, 29 keys carrying 2 identical rows each. Hiding one of a co-located identical pair must be able to say "hide both".

- [ ] **Step 1: Write the schema**

```sql
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
```

- [ ] **Step 2: Apply it twice and confirm the second run is a no-op**

Run:
```bash
docker exec -i armapunk-pg psql -U armapunk -d pgm_full_scratch -v ON_ERROR_STOP=1 < ~/Armapunk2035/deploy/map_edits.sql
docker exec -i armapunk-pg psql -U armapunk -d pgm_full_scratch -v ON_ERROR_STOP=1 < ~/Armapunk2035/deploy/map_edits.sql
```
Expected: first run prints `CREATE TABLE`/`CREATE INDEX`; second prints `NOTICE: relation "..." already exists, skipping` for every object and exits 0. (Both runs verified against a scratch database while this plan was written.)

- [ ] **Step 3: Confirm a row round-trips**

Run:
```bash
docker exec -i armapunk-pg psql -U armapunk -d pgm_full_scratch \
  -c "INSERT INTO map_edits (classname,x,y,z,author_uid) VALUES ('Land_Cargo20_blue_F',8100.5,7700.25,20.125,'76561190000000001') RETURNING id,classname,x,y,z,layer;" \
  -c "DELETE FROM map_edits WHERE classname='Land_Cargo20_blue_F';"
```
Expected: one row back with `layer = AP_LIVE`, then `DELETE 1`.

- [ ] **Step 3b: Confirm the revision counter bumps on every write**

Run:
```bash
docker exec -i armapunk-pg psql -U armapunk -d pgm_full_scratch \
  -c "SELECT rev AS start_rev FROM map_meta WHERE world='Malden';" \
  -c "INSERT INTO map_edits (classname,x,y,z,author_uid) VALUES ('Land_A_F',1,2,3,'u');" \
  -c "INSERT INTO map_hidden (bake_key,author_uid) VALUES ('land_b_f|1|2|3','u');" \
  -c "UPDATE map_edits SET x=9 WHERE classname='Land_A_F';" \
  -c "DELETE FROM map_edits WHERE classname='Land_A_F';" \
  -c "DELETE FROM map_hidden WHERE bake_key='land_b_f|1|2|3';" \
  -c "SELECT rev AS end_rev FROM map_meta WHERE world='Malden';"
```
Expected: `end_rev` is exactly `start_rev + 5` — one per write, including the deletes. (Verified against a scratch database while this plan was written: 4 writes moved rev 0 → 4, and re-applying the whole schema file was a clean no-op both times.)

- [ ] **Step 4: Commit**

```bash
cd ~/Armapunk2035
git add deploy/map_edits.sql
git commit -m "feat(map): schema for the live map-edit delta layer"
```

---

## Task 2: The bake key

**Files:**
- Create: `tools/mapkey.py`, `tools/test_mapkey.py`

**Interfaces:**
- Produces: `mapkey.bake_key(classname, x, y, z) -> str`, `mapkey.parse_key(k) -> (cls, x, y, z)`, `mapkey.iter_mapdata(path)`.

A baked row has no id, so a tombstone needs a key derived from its content. **The SQF and Python derivations must agree exactly**, so the rounding is pinned rather than left to each language's default: `floor(v * 1000 + 0.5)`. Python's built-in `round()` is banker's rounding and SQF's is not — do not use either.

- [ ] **Step 1: Write the failing test**

```python
# tools/test_mapkey.py
import collections
import os
import unittest

import mapkey

MAPDATA = os.path.join(os.path.dirname(__file__), "..", "mission",
                       "Armapunk2035.Malden", "core", "config", "fn_mapData.sqf")


class TestBakeKey(unittest.TestCase):
    def test_format_is_pinned(self):
        self.assertEqual(
            mapkey.bake_key("Land_D_Stone_Shed_V1_F", 8091.356, 7738.700, 206.944),
            "land_d_stone_shed_v1_f|8091356|7738700|206944")

    def test_half_rounds_away_from_zero_not_to_even(self):
        # round() would give 0 here; SQF gives 1. The key must match SQF.
        self.assertEqual(mapkey.bake_key("x", 0.0005, 0.0015, 0.0025),
                         "x|1|2|3")

    def test_round_trips(self):
        k = mapkey.bake_key("Land_Foo_F", -1234.567, 89.001, 0.0)
        self.assertEqual(mapkey.parse_key(k), ("land_foo_f", -1234.567, 89.001, 0.0))

    def test_real_mapdata_collision_rate_is_known(self):
        keys = [mapkey.bake_key(c, x, y, z)
                for (c, x, y, z) in mapkey.iter_mapdata(MAPDATA)]
        counts = collections.Counter(keys)
        dupes = {k: v for k, v in counts.items() if v > 1}
        self.assertEqual(len(keys), 9384)
        self.assertEqual(len(counts), 9355)
        # 29 keys carry exactly 2 identical rows -- this is what map_hidden.occurrences
        # exists for. If this number MOVES, the baked array changed and the bake-down
        # in mapdelta_export.py needs re-checking.
        self.assertEqual(len(dupes), 29)
        self.assertTrue(all(v == 2 for v in dupes.values()))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd ~/Armapunk2035/tools && python3 test_mapkey.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'mapkey'`

- [ ] **Step 3: Write the implementation**

```python
# tools/mapkey.py
"""The bake key: a stable identity for a row of the BAKED map arrays.

A baked row lives inside the PBO and has no database id, so a tombstone in
map_hidden has to name it by content. Both SQF and Python compute this key, so
the rounding is pinned here rather than left to either language's default --
Python's round() is banker's rounding, SQF's is not, and the two disagree on
exact halves. floor(v*1000 + 0.5) is what the SQF side does; match it.

The map arrays carry three decimals, so the *1000 quantum is lossless in
practice; it exists to keep float noise out of the key, not to bucket.
"""
import math
import re

_ROW = re.compile(r'\["([^"]+)",\[(-?[\d.]+),(-?[\d.]+),(-?[\d.]+)\]')


def _q(v):
    return int(math.floor(v * 1000.0 + 0.5))


def bake_key(classname, x, y, z):
    return "%s|%d|%d|%d" % (classname.lower(), _q(x), _q(y), _q(z))


def parse_key(k):
    cls, x, y, z = k.split("|")
    return (cls, int(x) / 1000.0, int(y) / 1000.0, int(z) / 1000.0)


def iter_mapdata(path):
    """Yield (classname, x, y, z) for every row of an allLocalMapEntities file."""
    with open(path, encoding="utf-8", errors="replace") as fh:
        src = fh.read()
    for m in _ROW.finditer(src):
        yield (m.group(1), float(m.group(2)), float(m.group(3)), float(m.group(4)))
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd ~/Armapunk2035/tools && python3 test_mapkey.py -v`
Expected: `Ran 4 tests` / `OK`

- [ ] **Step 5: Commit**

```bash
cd ~/Armapunk2035
git add tools/mapkey.py tools/test_mapkey.py
git commit -m "feat(map): pinned bake-key derivation with collision measurement"
```

---

## Task 3: `AP_fnc_mapZoneFor` — one zone rule, two callers

**Files:**
- Create: `mission/Armapunk2035.Malden/core/functions/fn_mapZoneFor.sqf`
- Modify: `mission/Armapunk2035.Malden/core/functions/fn_dynamicMapSystem.sqf`
- Modify: `mission/Armapunk2035.Malden/Functions.h`

**Interfaces:**
- Produces: `[_pos, _isServer, _initCode] call AP_fnc_mapZoneFor` → zone id string (`"static"` or a `dynamicMap_zoneLocations` id).

Today the zone rule is inline in `fn_dynamicMapSystem`'s binning loop. The editor has to bin new rows the same way; two copies of that rule would drift and objects would land in a zone that never loads them. Extract it, then have both callers use it.

- [ ] **Step 1: Observe the red state — no such function**

Deploy the current build and run in the debug console (in-game):

```sqf
diag_log format ["[AP-PROBE] mapZoneFor exists: %1", !isNil "AP_fnc_mapZoneFor"];
```
Expected in the client RPT: `[AP-PROBE] mapZoneFor exists: false`

- [ ] **Step 2: Write the function**

```sqf
/*
    File: fn_mapZoneFor.sqf  (AP_fnc_mapZoneFor)
    Which streaming zone does a map row belong to?

    Extracted VERBATIM from fn_dynamicMapSystem's binning loop so the live map
    editor bins a new row exactly the way the baked array was binned. Two copies
    of this rule would drift, and a row binned into a zone that never loads it is
    invisible with no error -- the object exists in the list and is simply never
    created.

    Order matters and is the original's: server rows and rows whose init marks
    them static are never streamed; so is anything within 110 m of the Loony Bin
    jail marker. Otherwise the FIRST zone whose radius contains the position wins.

    params: 0 = position (world frame), 1 = isServer flag, 2 = init code string
    returns: the zone id string
*/
params [["_pos", [], [[]]], ["_isServer", false, [false]], ["_code", "", [""]]];

if (_pos isEqualTo []) exitWith { "static" };
if (_isServer) exitWith { "static" };
if ((_code find "_isStatic = true") > -1) exitWith { "static" };
if (isNil "dynamicMap_zoneLocations") exitWith { "static" };
if ((_pos distance2D (getMarkerPos "jail_marker_loonybin")) <= 110) exitWith { "static" };

private _zone = "static";
{
    _x params ["_zonePos", "_zoneRadius", "_zoneID"];
    if ((_zonePos distance2D _pos) < _zoneRadius) exitWith { _zone = _zoneID; };
} forEach dynamicMap_zoneLocations;

_zone
```

- [ ] **Step 3: Register it**

In `mission/Armapunk2035.Malden/Functions.h`, in the same block that holds `class dynamicMapSystem {};` (line ~478), add directly beneath it:

```cpp
 class mapZoneFor {};   // AP_fnc_mapZoneFor -- the single zone-binning rule, shared by the streamer and the live editor
```

- [ ] **Step 4: Make `fn_dynamicMapSystem` delegate**

In `fn_dynamicMapSystem.sqf`, replace the binning block. The existing code reads:

```sqf
    _x params["_xObjectStr", "_xPos", "_xVectorDirAndUp", "_xCode", "_xIsServer"];
    _zone = "static";
    if !(_xIsServer) then {if ((_xCode find "_isStatic = true") isEqualTo - 1) then {
            if (_xPos distance2D(getMarkerPos "jail_marker_loonybin") > 110) then {for "_i"
                from 0 to((count dynamicMap_zoneLocations) - 1) do {_zoneCheck = (dynamicMap_zoneLocations select _i);
                    if (((_zoneCheck select 0) distance2D _xPos) < (_zoneCheck select 1)) exitWith {_zone = _zoneCheck select 2;};};};};
```

Replace those lines with:

```sqf
    _x params["_xObjectStr", "_xPos", "_xVectorDirAndUp", "_xCode", "_xIsServer"];
    _zone = [_xPos, _xIsServer, _xCode] call AP_fnc_mapZoneFor;
    if !(_xIsServer) then {
```

Leave everything from `if (_xObjectStr in _decorObjects)` onward untouched — the decor-thinning and the two `pushBack` branches are unchanged.

- [ ] **Step 5: Tag created objects with their key**

Still in `fn_dynamicMapSystem.sqf`, in `dynamicMap_fnc_loadArea`. The real line (verified against the file, which is more minified than a first reading suggests) is:

```sqf
        if !(isNull _object) then {private _objects = missionNamespace getVariable[format["dynamicMap_%1_activeObjects", _this], []];
```

Replace it with:

```sqf
        if !(isNull _object) then {
            // Live-editor identity. A baked row is named by its bake key; a row the editor
            // added carries its own key as an optional 7th element ("live:<db id>"). Without
            // this, deleting one object means matching by position against activeObjects,
            // which is a guess -- and activeObjects drifts out of step with objectList
            // whenever a create returns objNull. Local setVariable, never published.
            private _mk = _x param [6, ""];
            if (_mk isEqualTo "") then {
                _mk = format ["%1|%2|%3|%4",
                    toLower (_x select 0),
                    floor (((_x select 1) select 0) * 1000 + 0.5),
                    floor (((_x select 1) select 1) * 1000 + 0.5),
                    floor (((_x select 1) select 2) * 1000 + 0.5)];
            };
            _object setVariable ["AP_mapKey", _mk];
            private _objects = missionNamespace getVariable[format["dynamicMap_%1_activeObjects", _this], []];
```

A 7th element is used, not the 6th: rows are 5 or 6 long already (`[class, pos, vdirup, init, isServer]`, optional 6th = a unit loadout), and `AP_fnc_createVehicleLocal` only reads indices 0–5, so index 6 is invisible to it.

**Brace discipline for Step 4 and Step 5 both:** verify the replacement by comparing the NET brace delta of the old and new text as whole strings, never per line. The Step 4 block opens 5 and closes 4 (net +1, leaving `if !(_xIsServer) then {` open for the decor branch below it); its replacement must also be net +1. This repo has a standing rule about exactly this failure.

- [ ] **Step 6: Verify the extraction changed nothing**

Deploy to dev, then in the debug console:

```sqf
private _n = 0; private _bad = 0;
{
    _x params ["_c", "_p", "", "_code", "_srv"];
    private _new = [_p, _srv, _code] call AP_fnc_mapZoneFor;
    private _old = "static";
    if !(_srv) then { if ((_code find "_isStatic = true") isEqualTo -1) then {
        if (_p distance2D (getMarkerPos "jail_marker_loonybin") > 110) then {
            for "_i" from 0 to ((count dynamicMap_zoneLocations) - 1) do {
                private _zc = dynamicMap_zoneLocations select _i;
                if (((_zc select 0) distance2D _p) < (_zc select 1)) exitWith { _old = _zc select 2; };
            };};};};
    _n = _n + 1;
    if !(_new isEqualTo _old) then { _bad = _bad + 1; };
} forEach allLocalMapEntities;
diag_log format ["[AP-PROBE] zoneFor parity: %1 rows, %2 mismatches", _n, _bad];
```
Expected in the RPT: `[AP-PROBE] zoneFor parity: 9384 rows, 0 mismatches`

- [ ] **Step 7: Verify keys were tagged**

```sqf
private _tagged = { !((_x getVariable ["AP_mapKey", "" ]) isEqualTo "") } count (dynamicMap_static_activeObjects);
diag_log format ["[AP-PROBE] static zone tagged: %1 / %2", _tagged, count dynamicMap_static_activeObjects];
```
Expected: both numbers equal and non-zero.

- [ ] **Step 8: Commit**

```bash
cd ~/Armapunk2035
python3 tools/test_sqf_balance.py
git add mission/Armapunk2035.Malden/core/functions/fn_mapZoneFor.sqf \
        mission/Armapunk2035.Malden/core/functions/fn_dynamicMapSystem.sqf \
        mission/Armapunk2035.Malden/Functions.h
git commit -m "refactor(map): extract AP_fnc_mapZoneFor and tag streamed objects with their key"
```

---

## Task 4: `AP_fnc_mapEditApply` — the client applier

**Files:**
- Create: `mission/Armapunk2035.Malden/core/functions/fn_mapEditApply.sqf`
- Modify: `mission/Armapunk2035.Malden/Functions.h`
- Modify: `mission/Armapunk2035.Malden/CfgRE.hpp`

**Interfaces:**
- Consumes: `AP_fnc_mapZoneFor` (Task 3), `AP_fnc_createVehicleLocal`.
- Produces: `[_op, _payload] call AP_fnc_mapEditApply` where `_op` is `"add"`, `"del"`, `"move"` or `"hide"`.
  - `"add"` → `[_id, _class, _pos, _vdirup, _init]`
  - `"del"` → `[_id]` (a live row)
  - `"hide"` → `[_bakeKey, _occurrences]` (a baked row)
  - `"move"` → `[_id, _pos, _vdirup]`

This is the only writer of live map state, and it is used by both the runtime broadcast and the join-time catch-up. A joining client replays the whole delta through it, which is why there is no init-ordering hazard: the delta does not have to arrive before `fn_dynamicMapSystem` bins the baked array.

- [ ] **Step 1: Observe the red state**

In the debug console on dev:

```sqf
diag_log format ["[AP-PROBE] mapEditApply exists: %1", !isNil "AP_fnc_mapEditApply"];
```
Expected: `[AP-PROBE] mapEditApply exists: false`

- [ ] **Step 2: Write the function**

```sqf
/*
    File: fn_mapEditApply.sqf  (AP_fnc_mapEditApply)
    Apply ONE map-edit op to this client's world.

    The single writer of live map state, used by two callers that must not diverge:
    the server's runtime broadcast after an edit, and a joining client replaying the
    whole delta to catch up. One path means join-time and edit-time can never drift,
    and it removes the init-ordering hazard entirely -- the delta does not have to
    beat fn_dynamicMapSystem's binning pass, because it is expressed as edits TO the
    binned result rather than as input to it.

    Objects here are CLIENT-LOCAL (AP_fnc_createVehicleLocal), so an op costs one
    local create or delete and nothing on the network.

    A row is identified by AP_mapKey, set on every object at creation
    (fn_dynamicMapSystem). Baked rows carry their derived bake key; editor rows
    carry "live:<db id>". Matching by position instead would be a guess, and
    activeObjects drifts out of step with objectList whenever a create returns null.

    params: 0 = op string, 1 = payload array
*/
params [["_op", "", [""]], ["_payload", [], [[]]]];
if (!hasInterface) exitWith {};
if (isNil "dynamicMap_zoneLocations") exitWith {};   // streamer not up yet; the join replay will re-run

private _fnc_zoneList = {
    missionNamespace getVariable [format ["dynamicMap_%1_objectList", _this], []]
};
private _fnc_zoneActive = {
    missionNamespace getVariable [format ["dynamicMap_%1_activeObjects", _this], []]
};
private _fnc_isLoaded = {
    (missionNamespace getVariable [format ["dynamicMap_%1_status", _this], "idle"]) isEqualTo "active"
};

switch (toLower _op) do {

    case "add": {
        _payload params [["_id", -1, [0]], ["_class", "", [""]], ["_pos", [], [[]]],
                         ["_vdirup", [[0,1,0],[0,0,1]], [[]]], ["_init", "", [""]]];
        if (_id < 0 || {_class isEqualTo ""} || {count _pos < 3}) exitWith {};
        private _key = format ["live:%1", _id];
        private _row = [_class, _pos, _vdirup, _init, false, [], _key];
        private _zone = [_pos, false, _init] call AP_fnc_mapZoneFor;

        private _list = _zone call _fnc_zoneList;
        // Idempotent: a replay must not double-add. Editor rows are keyed, so this
        // is an exact test rather than a position guess.
        if ((_list findIf { (_x param [6, ""]) isEqualTo _key }) > -1) exitWith {};
        _list pushBack _row;
        missionNamespace setVariable [format ["dynamicMap_%1_objectList", _zone], _list];

        if (_zone call _fnc_isLoaded) then {
            private _obj = _row call AP_fnc_createVehicleLocal;
            if !(isNull _obj) then {
                _obj setVariable ["AP_mapKey", _key];
                private _act = _zone call _fnc_zoneActive;
                _act pushBack _obj;
                missionNamespace setVariable [format ["dynamicMap_%1_activeObjects", _zone], _act];
            };
        };
    };

    case "move": {
        _payload params [["_id", -1, [0]], ["_pos", [], [[]]], ["_vdirup", [], [[]]]];
        if (_id < 0 || {count _pos < 3}) exitWith {};
        // A move can cross a zone boundary, so it is a delete followed by an add
        // rather than an in-place edit. Doing it in place would leave the row in
        // its old zone's list and the object would vanish on the next unload.
        private _old = [];
        {
            private _l = _x call _fnc_zoneList;
            private _i = _l findIf { (_x param [6, ""]) isEqualTo (format ["live:%1", _id]) };
            if (_i > -1) exitWith { _old = _l select _i; };
        } forEach (["static"] + (dynamicMap_zoneLocations apply { _x select 2 }));
        if (_old isEqualTo []) exitWith {};
        ["del", [_id]] call AP_fnc_mapEditApply;
        ["add", [_id, _old select 0, _pos, _vdirup, _old select 3]] call AP_fnc_mapEditApply;
    };

    case "del": {
        _payload params [["_id", -1, [0]]];
        if (_id < 0) exitWith {};
        [format ["live:%1", _id], 1] call AP_fnc_mapEditRemoveKey;
    };

    case "hide": {
        _payload params [["_key", "", [""]], ["_n", 1, [0]]];
        if (_key isEqualTo "") exitWith {};
        [_key, _n] call AP_fnc_mapEditRemoveKey;
    };
};
```

- [ ] **Step 3: Write the shared removal helper**

Create `mission/Armapunk2035.Malden/core/functions/fn_mapEditRemoveKey.sqf`:

```sqf
/*
    File: fn_mapEditRemoveKey.sqf  (AP_fnc_mapEditRemoveKey)
    Remove up to N rows carrying a given AP_mapKey, from whichever zone holds them.

    Shared by "del" (a live editor row, N always 1) and "hide" (a baked row, where N
    can be 2). N exists because the baked array contains genuine duplicates: 9384
    rows collapse to 9355 distinct keys, with 29 keys carrying two IDENTICAL rows.
    Hiding "the object here" must be able to mean both of a co-located pair.

    Removes from the zone's objectList (so a later reload does not resurrect it) AND
    deletes the live object if that zone is currently loaded. Doing only the first
    leaves the object standing until the next unload; only the second makes it come
    back on the next pass.

    params: 0 = key, 1 = how many matching rows to remove
*/
params [["_key", "", [""]], ["_n", 1, [0]]];
if (_key isEqualTo "" || {_n < 1}) exitWith { 0 };
// The streamer owns dynamicMap_zoneLocations. Step 6 below calls this function straight
// from the debug console, so guard rather than throw on the zone list.
if (isNil "dynamicMap_zoneLocations") exitWith { 0 };

private _removed = 0;
private _zones = ["static"] + (dynamicMap_zoneLocations apply { _x select 2 });

{
    private _zone = _x;
    private _listVar = format ["dynamicMap_%1_objectList", _zone];
    private _actVar  = format ["dynamicMap_%1_activeObjects", _zone];
    private _list = missionNamespace getVariable [_listVar, []];

    private _keep = [];
    {
        private _rowKey = _x param [6, ""];
        if (_rowKey isEqualTo "") then {
            _rowKey = format ["%1|%2|%3|%4",
                toLower (_x select 0),
                floor (((_x select 1) select 0) * 1000 + 0.5),
                floor (((_x select 1) select 1) * 1000 + 0.5),
                floor (((_x select 1) select 2) * 1000 + 0.5)];
        };
        if (_rowKey isEqualTo _key && {_removed < _n}) then {
            _removed = _removed + 1;
        } else {
            _keep pushBack _x;
        };
    } forEach _list;

    if (_removed > 0) then {
        missionNamespace setVariable [_listVar, _keep];
        private _act = missionNamespace getVariable [_actVar, []];
        private _keepAct = [];
        private _killed = 0;
        {
            if ((_x getVariable ["AP_mapKey", ""]) isEqualTo _key && {_killed < _n}) then {
                deleteVehicle _x;
                _killed = _killed + 1;
            } else {
                _keepAct pushBack _x;
            };
        } forEach _act;
        missionNamespace setVariable [_actVar, _keepAct];
    };

    if (_removed >= _n) exitWith {};
} forEach _zones;

_removed
```

- [ ] **Step 4: Register both functions**

In `Functions.h`, beside the `mapZoneFor` entry from Task 3:

```cpp
 class mapEditApply {};      // AP_fnc_mapEditApply -- the ONLY writer of live map state (server broadcast + join replay)
 class mapEditRemoveKey {};  // AP_fnc_mapEditRemoveKey -- remove N rows by AP_mapKey from whichever zone holds them
```

In `CfgRE.hpp`, inside `class Functions`:

```cpp
    // Live map editor. The server is the only legitimate caller -- a client that could
    // remoteExec this would spawn arbitrary classnames on everyone else's screen, so it
    // is server -> clients only. The client's REQUEST path is APS_fnc_mapEditSRV below.
    class AP_fnc_mapEditApply {allowedTargets = 1;};
```

- [ ] **Step 5: Verify with a hand-driven op**

Deploy to dev. Stand somewhere open, note your position, then in the debug console:

```sqf
private _p = getPosWorld player vectorAdd [5,0,0];
["add", [999001, "Land_Cargo20_blue_F", _p, [[0,1,0],[0,0,1]], ""]] call AP_fnc_mapEditApply;
uiSleep 1;
diag_log format ["[AP-PROBE] add: object present = %1",
    ({ (_x getVariable ["AP_mapKey",""]) isEqualTo "live:999001" } count dynamicMap_static_activeObjects)];
["del", [999001]] call AP_fnc_mapEditApply;
uiSleep 1;
diag_log format ["[AP-PROBE] del: object present = %1",
    ({ (_x getVariable ["AP_mapKey",""]) isEqualTo "live:999001" } count dynamicMap_static_activeObjects)];
```
Expected in the RPT: a blue container appears 5 m east, `add: object present = 1`, the container vanishes, `del: object present = 0`.

- [ ] **Step 6: Verify hide against a real baked object**

Look at a baked prop, then:

```sqf
private _o = cursorObject;
private _k = _o getVariable ["AP_mapKey", ""];
diag_log format ["[AP-PROBE] hide target key = %1", _k];
private _r = [_k, 1] call AP_fnc_mapEditRemoveKey;
diag_log format ["[AP-PROBE] hide removed = %1, obj null = %2", _r, isNull _o];
```
Expected: a non-empty key, `hide removed = 1`, `obj null = true`, and the prop gone from the world. It returns on the next mission restart — persistence is Task 5.

- [ ] **Step 7: Commit**

```bash
cd ~/Armapunk2035
python3 tools/test_sqf_balance.py
git add mission/Armapunk2035.Malden/core/functions/fn_mapEditApply.sqf \
        mission/Armapunk2035.Malden/core/functions/fn_mapEditRemoveKey.sqf \
        mission/Armapunk2035.Malden/Functions.h mission/Armapunk2035.Malden/CfgRE.hpp
git commit -m "feat(map): client-side applier for live map-edit ops"
```

---

## Task 5: `APS_fnc_mapEditLoad` — boot load and join catch-up

**Files:**
- Create: `server/AP_server/core/TON/fn_mapEditLoad.sqf`
- Modify: `server/AP_server/config.cpp`, `mission/Armapunk2035.Malden/CfgRE.hpp`, `mission/Armapunk2035.Malden/core/init.sqf`

**Interfaces:**
- Consumes: `DB_fnc_asyncQuery`, `AP_fnc_mapEditApply` (Task 4).
- Produces: `APS_fnc_mapEditLoad` — no args from a client; derives the caller from `remoteExecutedOwner` and replies to that owner only. Server-side cache in `APS_mapDelta` (array of ops).

- [ ] **Step 1: Observe the red state**

Restart dev and grep the server log:

```bash
grep "AP-MAPEDIT" /home/timb/arma3server_dev/loonydev.log
```
Expected: no output — nothing loads the delta yet.

- [ ] **Step 2: Write the server function**

```sqf
/*
    File: fn_mapEditLoad.sqf  (APS_fnc_mapEditLoad)
    Load the map-edit delta from the database, and serve it to one joining client.

    Two jobs on purpose, because they must not answer differently: the boot read
    fills APS_mapDelta once, and every join replays that same cached array. A join
    that re-queried could see a different world from the one already broadcast to
    everyone else mid-session.

    Called with no arguments by a client (CfgRE allowedTargets = 2); the caller is
    derived from remoteExecutedOwner and NEVER from the payload -- the payload
    carries nothing, which is the strongest version of that rule.

    Mode 2 reads must be scheduled (spawn, not call): fn_asyncQuery refuses an
    unscheduled mode-2 query and returns [], which is indistinguishable from
    "no rows" at the call site.
*/
params [["_boot", false, [false]]];
if (!isServer) exitWith {};

private _world = worldName;

if (_boot) exitWith {
    private _ops = [];

    private _adds = [
        "SELECT id, classname, x, y, z, vdir_x, vdir_y, vdir_z, vup_x, vup_y, vup_z, init FROM map_edits WHERE world = %s",
        2, true, [_world]
    ] call DB_fnc_asyncQuery;
    {
        _x params ["_id", "_class", "_x", "_y", "_z", "_dx", "_dy", "_dz", "_ux", "_uy", "_uz", "_init"];
        _ops pushBack ["add", [_id, _class, [_x, _y, _z],
                               [[_dx, _dy, _dz], [_ux, _uy, _uz]], _init]];
    } forEach _adds;

    private _hides = [
        "SELECT bake_key, occurrences FROM map_hidden WHERE world = %s",
        2, true, [_world]
    ] call DB_fnc_asyncQuery;
    {
        _x params ["_key", "_n"];
        _ops pushBack ["hide", [_key, _n]];
    } forEach _hides;

    APS_mapDelta = _ops;
    diag_log format ["[AP-MAPEDIT] delta loaded: %1 adds, %2 hides", count _adds, count _hides];
};

// --- the join path -------------------------------------------------------
private _owner = remoteExecutedOwner;
if (_owner isEqualTo 0) exitWith {};   // not a remote call; boot uses the branch above
private _ops = missionNamespace getVariable ["APS_mapDelta", []];
if (_ops isEqualTo []) exitWith {};
{
    [_x, "AP_fnc_mapEditApply", _owner, false] spawn AP_fnc_MP;
    uiSleep 0.01;   // do not burst a few hundred ops into one frame on a joining client
} forEach _ops;
diag_log format ["[AP-MAPEDIT] replayed %1 ops to owner %2", count _ops, _owner];
```

**Note:** `_x` is already `[op, payload]`, which is exactly `AP_fnc_mapEditApply`'s parameter list, so it passes straight through as the args array.

- [ ] **Step 3: Register the server function**

In `server/AP_server/config.cpp`, inside `class TONServer`'s TON block (beside `class dutySRV {};`):

```cpp
class mapEditLoad {};  // live map editor: boot-load the delta, and replay it to one joining client
```

- [ ] **Step 4: Whitelist the request**

In `CfgRE.hpp`:

```cpp
    // Live map editor: the client asks for the delta and gets it replayed. The request
    // carries NO arguments at all, so there is nothing in it the server could trust
    // wrongly; the reply target is remoteExecutedOwner.
    class APS_fnc_mapEditLoad {allowedTargets = 2;};
```

- [ ] **Step 5: Boot-load on the server**

In `server/AP_server/init.sqf` (or wherever the server's own startup sequence runs after the DB engine is decided), add:

```sqf
[true] spawn APS_fnc_mapEditLoad;   // live map editor delta -> APS_mapDelta
```

**Implementer:** confirm placement is AFTER `AP_db_engineDecided` is set; a delta read that beats the engine decision lands on whichever database happens to be selected at that instant.

- [ ] **Step 6: Request it on the client**

In `mission/Armapunk2035.Malden/core/init.sqf`, after the `[] spawn AP_fnc_dynamicMapSystem;` line (~86):

```sqf
// Live map editor: ask the server for the delta and replay it. This runs AFTER the
// streamer has binned the baked array, and that ordering is deliberate -- every op
// is an edit TO the binned result, so there is no race to win.
[] spawn {
    waitUntil { !isNil "dynamicMap_zoneLocations" };
    uiSleep 2;
    [[], "APS_fnc_mapEditLoad", 2, false] spawn AP_fnc_MP;
};
```

- [ ] **Step 7: Verify the round trip**

Insert a row by hand, restart dev, join:

```bash
docker exec -i armapunk-pg psql -U armapunk -d pgm_full_scratch -c \
  "INSERT INTO map_edits (world,classname,x,y,z,author_uid) VALUES ('Malden','Land_Cargo20_blue_F',8100,7700,20,'76561190000000001');"
bash /home/timb/arma3server_dev/reload-armapunk2035.sh
grep "read from bank" /home/timb/arma3server_dev/loonydev.log
grep "AP-MAPEDIT" /home/timb/arma3server_dev/loonydev.log
```
Expected: `[AP-MAPEDIT] delta loaded: 1 adds, 0 hides`, then after joining, `[AP-MAPEDIT] replayed 1 ops to owner <n>`, and a blue container standing at 8100/7700.

- [ ] **Step 8: Commit**

```bash
cd ~/Armapunk2035
python3 tools/test_sqf_balance.py
git add server/AP_server/core/TON/fn_mapEditLoad.sqf server/AP_server/config.cpp \
        server/AP_server/init.sqf mission/Armapunk2035.Malden/CfgRE.hpp \
        mission/Armapunk2035.Malden/core/init.sqf
git commit -m "feat(map): load the map-edit delta at boot and replay it to joining clients"
```

---

## Task 6 (OPTIONAL): `APS_fnc_mapEditSRV` — the in-game authority

> **Skippable.** The Eden loop (Tasks 7–8) never calls this — `map_push.py` writes the tables directly and the gate on it is SSH plus database access. Build this only for the in-world prune tool, or as the door Zeus comes through later. If you skip it, skip `AP_fnc_mapPrune` with it and go straight to Task 7.
>
> **One rule survives the skip, and it is the important one:** if this path IS built, it must still refuse to accept an `init` string from a client. `map_edits.init` is `compile`d and `spawn`ed on every client by `AP_fnc_createVehicleLocal`. `map_push.py` writing that column is fine — it is a trusted tool on the box, at the same trust level as editing `fn_mapData.sqf` by hand is today. A *client* writing it is remote code execution against everyone on the server. The two paths are not equivalent and must not be given equivalent validation.

**Files:**
- Create: `server/AP_server/core/TON/fn_mapEditSRV.sqf`
- Modify: `server/AP_server/config.cpp`, `mission/Armapunk2035.Malden/CfgRE.hpp`

**Interfaces:**
- Consumes: `DB_fnc_asyncQuery`, `AP_fnc_mapEditApply`.
- Produces: `[[_op, _payload], "APS_fnc_mapEditSRV", 2, false] spawn AP_fnc_MP` from the client. Server validates, persists, broadcasts to `0` (all clients).

**This is the security boundary of the whole feature.** Three separate vectors, all closed here:

1. **Caller spoofing.** The caller's UID comes from `remoteExecutedOwner`, never from the payload. Your own `fn_adminKickBan.sqf` and `fn_adminPlayerQuerySRV.sqf` carry headers about exactly this bug — a client-passed unit object was being fed into the adminlevel lookup, so any player could pass a real admin's object and inherit their level.
2. **Arbitrary spawning.** An ungated edit RPC is a classname spawner: vehicles, weapon crates, ammo boxes, anywhere on the map. The class allowlist below restricts it to inert world geometry.
3. **Stored code execution.** `map_edits.init` is executed on every client by `AP_fnc_createVehicleLocal` (`_vehicle spawn (compile _plb_code)`). **A client must never be able to write that column.** In this plan the editor cannot set `init` at all — new rows get `""`, and anything needing an init line comes from a server-side preset resolved by id. That closes the vector completely rather than trying to sanitise SQF.

- [ ] **Step 1: Observe the red state**

```sqf
diag_log format ["[AP-PROBE] mapEditSRV exists: %1", !isNil "APS_fnc_mapEditSRV"];
```
Expected: `false`.

- [ ] **Step 2: Write the function**

```sqf
/*
    File: fn_mapEditSRV.sqf  (APS_fnc_mapEditSRV)
    The authority for every live map edit. Validate, persist, broadcast.

    THE CALLER IS DERIVED FROM remoteExecutedOwner AND NOTHING ELSE. The payload
    carries no identity, no level and no code. This repo has already been bitten by
    the other shape twice (fn_adminKickBan.sqf, fn_adminPlayerQuerySRV.sqf both
    took a client-passed unit OBJECT into the adminlevel lookup, so any player could
    pass a real admin's object and inherit their level) -- do not reintroduce it.

    THE CLIENT CANNOT SET `init`. That column is compiled and spawned on every
    client by AP_fnc_createVehicleLocal, so a client-writable init is client-side
    RCE against everyone on the server. New rows get "". Anything that needs an
    init line is a server-side PRESET, chosen by id, resolved here.

    THE CLASS ALLOWLIST is what stops this being a vehicle/crate spawner. Inert
    world geometry only; anything alive, drivable or lootable is refused.

    params: 0 = op string ("add" | "move" | "del" | "hide"), 1 = payload
*/
params [["_op", "", [""]], ["_payload", [], [[]]]];
if (!isServer) exitWith {};

private _owner = remoteExecutedOwner;
if (_owner isEqualTo 0) exitWith {};
private _uid = getPlayerUID (_owner call BIS_fnc_getUnitByUID);   // see Step 3 note
if (isNil "_uid" || {_uid isEqualTo ""}) exitWith {};

// --- rank gate ----------------------------------------------------------
// Re-read from the database every call. A cached level is a level that survives a
// demotion.
private _rows = [
    "SELECT adminlevel FROM players_global WHERE playerid = %s", 2, false, [_uid]
] call DB_fnc_asyncQuery;
private _level = _rows param [0, 0];
if (_level < 5) exitWith {
    diag_log format ["[AP-MAPEDIT] REFUSED %1 from uid %2 (level %3)", _op, _uid, _level];
};

// --- rate limit ---------------------------------------------------------
// A stuck client or a hijacked admin session should not be able to write ten
// thousand rows before anyone notices.
private _bucketVar = format ["APS_mapEditBucket_%1", _uid];
private _bucket = missionNamespace getVariable [_bucketVar, [0, 0]];
_bucket params ["_windowStart", "_count"];
if ((diag_tickTime - _windowStart) > 60) then { _windowStart = diag_tickTime; _count = 0; };
if (_count >= 60) exitWith {
    diag_log format ["[AP-MAPEDIT] RATE LIMIT uid %1", _uid];
};
missionNamespace setVariable [_bucketVar, [_windowStart, _count + 1]];

private _world = worldName;

switch (toLower _op) do {

    case "add": {
        _payload params [["_class", "", [""]], ["_pos", [], [[]]], ["_vdirup", [], [[]]]];
        if (_class isEqualTo "" || {count _pos < 3} || {count _vdirup < 2}) exitWith {};

        // Class allowlist. Inert world geometry only -- this is what keeps the
        // editor from being a vehicle and crate spawner for anyone who gets a
        // level-5 session.
        if !(isClass (configFile >> "CfgVehicles" >> _class)) exitWith {
            diag_log format ["[AP-MAPEDIT] unknown class refused: %1", _class];
        };
        private _ok = (_class isKindOf "Building") || (_class isKindOf "Static") || (_class isKindOf "Thing");
        private _bad = (_class isKindOf "AllVehicles") || (_class isKindOf "CAManBase")
                    || (_class isKindOf "ReammoBox_F") || (_class isKindOf "WeaponHolder");
        if (!_ok || _bad) exitWith {
            diag_log format ["[AP-MAPEDIT] class refused by allowlist: %1 (uid %2)", _class, _uid];
        };

        _vdirup params ["_vdir", "_vup"];
        private _ins = [
            "INSERT INTO map_edits (world, classname, x, y, z, vdir_x, vdir_y, vdir_z, vup_x, vup_y, vup_z, author_uid) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)",
            1, false,
            [_world, _class, _pos select 0, _pos select 1, _pos select 2,
             _vdir select 0, _vdir select 1, _vdir select 2,
             _vup select 0, _vup select 1, _vup select 2, _uid]
        ] call DB_fnc_asyncQuery;

        // Read the id back. On the Postgres engine mode 1 does report failure, but
        // it does not hand back the serial, and the id IS the row's identity for
        // every later move and delete -- so read, do not assume.
        private _idRows = [
            "SELECT id FROM map_edits WHERE world = %s AND author_uid = %s ORDER BY id DESC LIMIT 1",
            2, false, [_world, _uid]
        ] call DB_fnc_asyncQuery;
        private _id = _idRows param [0, -1];
        if (_id < 0) exitWith {
            diag_log format ["[AP-MAPEDIT] INSERT did not land for uid %1 class %2", _uid, _class];
        };

        private _op2 = ["add", [_id, _class, _pos, _vdirup, ""]];
        APS_mapDelta pushBack _op2;
        [_op2, "AP_fnc_mapEditApply", 0, false] spawn AP_fnc_MP;
        [_uid, "add", _class, format ["%1", _pos]] spawn APS_fnc_mapEditAudit;
    };

    case "move": {
        _payload params [["_id", -1, [0]], ["_pos", [], [[]]], ["_vdirup", [], [[]]]];
        if (_id < 0 || {count _pos < 3} || {count _vdirup < 2}) exitWith {};
        _vdirup params ["_vdir", "_vup"];
        [
            "UPDATE map_edits SET x=%s, y=%s, z=%s, vdir_x=%s, vdir_y=%s, vdir_z=%s, vup_x=%s, vup_y=%s, vup_z=%s WHERE id=%s AND world=%s",
            1, false,
            [_pos select 0, _pos select 1, _pos select 2,
             _vdir select 0, _vdir select 1, _vdir select 2,
             _vup select 0, _vup select 1, _vup select 2, _id, _world]
        ] call DB_fnc_asyncQuery;

        {
            if ((_x select 0) isEqualTo "add" && {((_x select 1) select 0) isEqualTo _id}) then {
                (_x select 1) set [2, _pos];
                (_x select 1) set [3, _vdirup];
            };
        } forEach APS_mapDelta;

        private _op2 = ["move", [_id, _pos, _vdirup]];
        [_op2, "AP_fnc_mapEditApply", 0, false] spawn AP_fnc_MP;
        [_uid, "move", str _id, format ["%1", _pos]] spawn APS_fnc_mapEditAudit;
    };

    case "del": {
        _payload params [["_id", -1, [0]]];
        if (_id < 0) exitWith {};
        ["DELETE FROM map_edits WHERE id = %s AND world = %s", 1, false, [_id, _world]]
            call DB_fnc_asyncQuery;
        APS_mapDelta = APS_mapDelta select {
            !((_x select 0) isEqualTo "add" && {((_x select 1) select 0) isEqualTo _id})
        };
        private _op2 = ["del", [_id]];
        [_op2, "AP_fnc_mapEditApply", 0, false] spawn AP_fnc_MP;
        [_uid, "del", str _id, ""] spawn APS_fnc_mapEditAudit;
    };

    case "hide": {
        _payload params [["_key", "", [""]], ["_n", 1, [0]]];
        // The key is client-supplied, so it is validated as a SHAPE, not trusted as
        // a fact: four pipe-separated fields, three of them integers. It only ever
        // reaches the database as a bound parameter.
        private _parts = _key splitString "|";
        if (count _parts != 4) exitWith {};
        if (_n < 1 || _n > 8) exitWith {};
        [
            "INSERT INTO map_hidden (world, bake_key, occurrences, author_uid) VALUES (%s,%s,%s,%s)",
            1, false, [_world, _key, _n, _uid]
        ] call DB_fnc_asyncQuery;
        private _op2 = ["hide", [_key, _n]];
        APS_mapDelta pushBack _op2;
        [_op2, "AP_fnc_mapEditApply", 0, false] spawn AP_fnc_MP;
        [_uid, "hide", _key, str _n] spawn APS_fnc_mapEditAudit;
    };
};
```

- [ ] **Step 3: Resolve the caller UID correctly**

`remoteExecutedOwner` returns an owner id, not a unit. Replace the `_uid` line in Step 2 with the repo's existing idiom — check how `fn_adminNdSRV.sqf` does it and copy that exactly rather than inventing one. If it has no helper, the correct form is:

```sqf
private _caller = objNull;
{ if (owner _x isEqualTo _owner) exitWith { _caller = _x; }; } forEach allPlayers;
if (isNull _caller) exitWith {};
private _uid = getPlayerUID _caller;
if (_uid isEqualTo "") exitWith {};
```

**This step is not optional and not cosmetic** — `BIS_fnc_getUnitByUID` as written in Step 2 is a placeholder and takes a UID, not an owner id. Verify the real form against `fn_adminNdSRV.sqf` before running anything.

- [ ] **Step 4: Write the audit helper**

Create `server/AP_server/core/TON/fn_mapEditAudit.sqf`:

```sqf
/*
    File: fn_mapEditAudit.sqf  (APS_fnc_mapEditAudit)
    One row per accepted map edit. The editor is a level-5 tool that rewrites the
    world for everyone, so "who moved the bank" has to be answerable from the
    database rather than from whoever happened to be watching the RPT that day.
*/
params [["_uid", "", [""]], ["_op", "", [""]], ["_target", "", [""]], ["_detail", "", [""]]];
if (!isServer || {_uid isEqualTo ""}) exitWith {};
[
    "INSERT INTO map_edit_log (world, author_uid, op, target, detail) VALUES (%s,%s,%s,%s,%s)",
    1, false, [worldName, _uid, _op, _target, _detail]
] call DB_fnc_asyncQuery;
```

- [ ] **Step 5: Register and whitelist**

`server/AP_server/config.cpp`, in the TON block:

```cpp
class mapEditSRV {};    // live map editor: the authority -- caller from remoteExecutedOwner, level 5 re-read per call, class allowlist, no client-supplied init
class mapEditAudit {};  // live map editor: one map_edit_log row per accepted edit
```

`CfgRE.hpp`:

```cpp
    // Live map editor. Client -> server REQUEST only. The server derives the caller from
    // remoteExecutedOwner, re-reads adminlevel from the database, refuses any class outside
    // the inert-geometry allowlist, and never accepts an init string -- so the payload
    // carries nothing that grants anything.
    class APS_fnc_mapEditSRV {allowedTargets = 2;};
```

`APS_fnc_mapEditAudit` gets **no** CfgRE entry — it is server-internal and must not be remote-callable.

- [ ] **Step 6: Verify the gate refuses a non-admin**

On dev, from a client whose `players_global.adminlevel` is below 5:

```sqf
[["add", ["Land_Cargo20_blue_F", getPosWorld player, [[0,1,0],[0,0,1]]]], "APS_fnc_mapEditSRV", 2, false] spawn AP_fnc_MP;
```
Then: `grep "AP-MAPEDIT" /home/timb/arma3server_dev/loonydev.log`
Expected: `[AP-MAPEDIT] REFUSED add from uid <uid> (level 0)` and **no** object, **no** `map_edits` row.

- [ ] **Step 7: Verify the allowlist refuses a vehicle**

As a level-5 admin:

```sqf
[["add", ["B_MBT_01_cannon_F", getPosWorld player, [[0,1,0],[0,0,1]]]], "APS_fnc_mapEditSRV", 2, false] spawn AP_fnc_MP;
```
Expected: `[AP-MAPEDIT] class refused by allowlist: B_MBT_01_cannon_F (uid ...)`, no tank.

- [ ] **Step 8: Verify a real edit persists and broadcasts**

As a level-5 admin, with a second client connected:

```sqf
[["add", ["Land_Cargo20_blue_F", getPosWorld player vectorAdd [6,0,0], [[0,1,0],[0,0,1]]]], "APS_fnc_mapEditSRV", 2, false] spawn AP_fnc_MP;
```
Expected: the container appears on **both** clients; `SELECT * FROM map_edits;` shows one row with the right author_uid; `SELECT * FROM map_edit_log;` shows one `add`. Restart dev and confirm it is still there.

- [ ] **Step 9: Write the in-world prune tool**

Create `mission/Armapunk2035.Malden/core/admin/fn_mapPrune.sqf`:

```sqf
/*
    File: fn_mapPrune.sqf  (AP_fnc_mapPrune)
    Delete the map object you are looking at.

    The one thing 3DEN is bad at: you are standing in the world, a prop is in the
    wrong place or should not exist, and finding it again in the editor means
    matching a position by eye. This asks the server to hide it, right now.

    It is a REQUEST. The world does not change here -- APS_fnc_mapEditSRV decides,
    persists, and the change arrives back through AP_fnc_mapEditApply like any
    other edit, so the admin sees exactly what every other player sees.

    Level 5 is re-checked server-side; the client-side check only decides whether the
    action does anything locally, so a modified client gains nothing by lying to itself.
    Read it with `call AP_adminLevel` -- it is a FUNCTION in this codebase, not a plain
    mission variable, and getVariable on that name returns 0 for everyone.
*/
if (!hasInterface) exitWith {};
if ((call AP_adminLevel) < 5) exitWith {};

private _obj = cursorObject;
if (isNull _obj) exitWith { hint "Prune: nothing under the cursor."; };

private _key = _obj getVariable ["AP_mapKey", ""];
if (_key isEqualTo "") exitWith {
    hint "Prune: that is not a map object (no AP_mapKey) -- it is mission content, a vehicle or a player.";
};

if ((_key select [0, 5]) isEqualTo "live:") then {
    private _id = parseNumber (_key select [5]);
    [["del", [_id]], "APS_fnc_mapEditSRV", 2, false] spawn AP_fnc_MP;
    hint format ["Prune: requested delete of live row %1", _id];
} else {
    [["hide", [_key, 1]], "APS_fnc_mapEditSRV", 2, false] spawn AP_fnc_MP;
    hint format ["Prune: requested hide of baked row%1%2", endl, _key];
};
```

Register in `Functions.h` beside the other admin entries:

```cpp
 class mapPrune {};   // AP_fnc_mapPrune -- level-5 "delete what I am looking at"; a REQUEST, the server decides
```

No `CfgRE.hpp` entry — this function is local to the client that runs it and is never remote-called.

- [ ] **Step 10: Bind it and verify**

Add to the level-5 branch of `evh/fn_keyDownHandler.sqf`, or as a button in the level-5 section of `core/admin/fn_adminMenu.sqf` — follow whichever pattern the existing level-5 admin actions use rather than inventing a third.

Verify in-game as a level-5 admin: look at a baked prop, fire the action. Expected: the prop vanishes on **both** connected clients, a `map_hidden` row appears with your UID, a `map_edit_log` row records the `hide`, and the prop is still gone after a dev restart.

Then verify as a non-admin: the same action does nothing, and `loonydev.log` shows `[AP-MAPEDIT] REFUSED hide from uid <uid> (level 0)`.

- [ ] **Step 11: Commit**

```bash
cd ~/Armapunk2035
python3 tools/test_sqf_balance.py
git add server/AP_server/core/TON/fn_mapEditSRV.sqf \
        server/AP_server/core/TON/fn_mapEditAudit.sqf \
        mission/Armapunk2035.Malden/core/admin/fn_mapPrune.sqf \
        server/AP_server/config.cpp mission/Armapunk2035.Malden/CfgRE.hpp \
        mission/Armapunk2035.Malden/Functions.h
git commit -m "feat(map): in-game authority and level-5 prune tool for live map edits"
```

---

## Task 7: `APS_fnc_mapEditPoll` — notice edits made out of band

**Files:**
- Create: `server/AP_server/core/TON/fn_mapEditPoll.sqf`
- Modify: `server/AP_server/config.cpp`, `server/AP_server/init.sqf`

**Interfaces:**
- Consumes: `DB_fnc_asyncQuery`, `APS_mapDelta` (Task 5), `AP_fnc_mapEditApply` (Task 4).
- Produces: a server-side loop. No client-callable surface, no `CfgRE.hpp` entry.

The primary authoring path — 3DEN, then `map_push.py` — writes the tables from outside the game entirely. Nothing in the mission knows it happened. This is the piece that closes that gap, and it is what makes a save in the editor land on a running server without a restart.

It polls one integer. `map_meta.rev` is bumped by a database trigger (Task 1), so a writer cannot forget to signal.

- [ ] **Step 1: Observe the red state**

Write a row from outside the game while dev is running, then watch nothing happen:

```bash
docker exec -i armapunk-pg psql -U armapunk -d pgm_full_scratch -c \
  "INSERT INTO map_edits (world,classname,x,y,z,author_uid) VALUES ('Malden','Land_Cargo20_yellow_F',8110,7700,20,'manual');"
sleep 30
grep "AP-MAPEDIT" /home/timb/arma3server_dev/loonydev.log | tail -3
```
Expected: no new log line, and no yellow container in-game. That is the gap.

- [ ] **Step 2: Write the poller**

```sqf
/*
    File: fn_mapEditPoll.sqf  (APS_fnc_mapEditPoll)
    Notice map edits this server did not make, and broadcast what changed.

    The primary authoring path is 3DEN -> tools/map_push.py -> Postgres, which never
    touches the game. Without this loop those edits sit in the database until the next
    mission restart -- which is exactly the 90-second repack cycle this feature exists
    to remove.

    Polls ONE INTEGER. map_meta.rev is bumped by a database TRIGGER on every write to
    map_edits and map_hidden, so no writer can forget to signal and no writer needs to
    know this loop exists.

    Broadcasts the DIFFERENCE, never the whole delta: re-sending every op on each bump
    would delete and recreate the entire live layer on every client every time anyone
    nudged one object. Ops carry an identity -- "live:<id>" for an add, the bake key for
    a hide -- so the comparison is an exact set difference and not a guess.

    NOTE: the key helper is defined INSIDE the spawned block. `spawn` does not inherit
    the caller's local variables (only `call` does), so a helper defined outside would
    be nil in here and every op would key as "".

    Server-only. No CfgRE entry: nothing may call this remotely.
*/
if (!isServer) exitWith {};

APS_mapPollRev = -1;

[] spawn {
    private _fnc_opKey = {
        params ["_op"];
        _op params ["_kind", "_pl"];
        if (_kind isEqualTo "add")  exitWith { format ["live:%1", _pl select 0] };
        if (_kind isEqualTo "hide") exitWith { _pl select 0 };
        ""
    };

    private _world = worldName;
    while {true} do {
        uiSleep 10;

        private _row = ["SELECT rev FROM map_meta WHERE world = %s", 2, false, [_world]] call DB_fnc_asyncQuery;
        private _rev = parseNumber format ["%1", _row param [0, -1]];

        if (_rev >= 0 && {!(_rev isEqualTo APS_mapPollRev)}) then {
            if (APS_mapPollRev < 0) then {
                // First pass after boot adopts whatever the boot load already put in
                // APS_mapDelta -- same data, nothing to broadcast.
                APS_mapPollRev = _rev;
                diag_log format ["[AP-MAPEDIT] poll baseline rev=%1", _rev];
            } else {
                private _fresh = [] call APS_fnc_mapEditLoadOps;
                private _oldKeys = APS_mapDelta apply { _x call _fnc_opKey };
                private _newKeys = _fresh apply { _x call _fnc_opKey };

                private _added = 0;
                {
                    if !((_x call _fnc_opKey) in _oldKeys) then {
                        [_x, "AP_fnc_mapEditApply", 0, false] spawn AP_fnc_MP;
                        _added = _added + 1;
                        uiSleep 0.01;
                    };
                } forEach _fresh;

                private _gone = 0;
                {
                    private _k = _x call _fnc_opKey;
                    if !(_k in _newKeys) then {
                        // An op that left the delta means its row was deleted. An add
                        // becomes a del. A hide that vanished means a baked row was
                        // UN-hidden, and that cannot be undone live -- the row is not in
                        // any zone list any more. Say so rather than pretend.
                        _x params ["_kind", "_pl"];
                        if (_kind isEqualTo "add") then {
                            [["del", [_pl select 0]], "AP_fnc_mapEditApply", 0, false] spawn AP_fnc_MP;
                            _gone = _gone + 1;
                        } else {
                            diag_log format ["[AP-MAPEDIT] un-hide of %1 needs a restart to take effect", _k];
                        };
                        uiSleep 0.01;
                    };
                } forEach APS_mapDelta;

                APS_mapDelta = _fresh;
                APS_mapPollRev = _rev;
                diag_log format ["[AP-MAPEDIT] rev=%1 applied: %2 new, %3 removed", _rev, _added, _gone];
            };
        };
    };
};
```

- [x] **Step 3: Factor the delta read out of Task 5** — done up front in Task 5; `APS_fnc_mapEditLoadOps` was written as its own file rather than inlined and then extracted.

Both the boot load and the poll need the same two queries turned into the same op array, and two copies would drift. Move the body of `APS_fnc_mapEditLoad`'s `_boot` branch into `server/AP_server/core/TON/fn_mapEditLoadOps.sqf` as `APS_fnc_mapEditLoadOps`, returning `_ops` rather than assigning `APS_mapDelta`. `APS_fnc_mapEditLoad`'s boot branch becomes:

```sqf
if (_boot) exitWith {
    APS_mapDelta = [] call APS_fnc_mapEditLoadOps;
    diag_log format ["[AP-MAPEDIT] delta loaded: %1 ops", count APS_mapDelta];
};
```

Register `class mapEditLoadOps {};` in `config.cpp`. No `CfgRE.hpp` entry — server-internal.

- [ ] **Step 4: Start the loop at boot**

In `server/AP_server/init.sqf`, immediately after the boot load added in Task 5 Step 5:

```sqf
[] call APS_fnc_mapEditPoll;   // watch map_meta.rev for edits made outside the game
```

- [ ] **Step 5: Verify the gap closed**

With dev running and a client joined:

```bash
docker exec -i armapunk-pg psql -U armapunk -d pgm_full_scratch -c \
  "INSERT INTO map_edits (world,classname,x,y,z,author_uid) VALUES ('Malden','Land_Cargo20_yellow_F',8110,7700,20,'manual');"
sleep 15
grep "AP-MAPEDIT" /home/timb/arma3server_dev/loonydev.log | tail -3
```
Expected: `[AP-MAPEDIT] rev=<n> applied: 1 new, 0 removed`, and a yellow container standing at 8110/7700 **on the already-connected client, with no restart**. That single line is the whole point of this plan.

Then delete it and confirm the reverse:

```bash
docker exec -i armapunk-pg psql -U armapunk -d pgm_full_scratch -c \
  "DELETE FROM map_edits WHERE author_uid='manual';"
sleep 15
grep "AP-MAPEDIT" /home/timb/arma3server_dev/loonydev.log | tail -2
```
Expected: `applied: 0 new, 1 removed`, container gone live.

- [ ] **Step 6: Verify the poll is not expensive**

```bash
grep -c "SELECT rev FROM map_meta" /home/timb/arma3server_dev/loonydev.log
```
`fn_asyncQuery` logs every statement, so this counts the polls directly. Expected: roughly `uptime_seconds / 10` and nothing else attributable to the loop. If the count is right but the server log is now unreadable, raise the interval rather than removing the logging — the statement log is load-bearing elsewhere.

- [ ] **Step 7: Commit**

```bash
cd ~/Armapunk2035
python3 tools/test_sqf_balance.py
git add server/AP_server/core/TON/fn_mapEditPoll.sqf \
        server/AP_server/core/TON/fn_mapEditLoadOps.sqf \
        server/AP_server/core/TON/fn_mapEditLoad.sqf \
        server/AP_server/config.cpp server/AP_server/init.sqf
git commit -m "feat(map): poll map_meta.rev so out-of-band edits land without a restart"
```

---

## Task 8: `tools/map_push.py` — the Eden loop's last mile

**Files:**
- Create: `tools/map_push.py`, `tools/test_map_push.py`
- Modify: `tools/edit-map.sh`, `tools/map_watch.py`

**Interfaces:**
- Consumes: `mapkey` (Task 2), `map_codegen.read_layer` and `map_codegen.read_mapdata` (both already exist).
- Produces: `python3 tools/map_push.py [--dry-run]` — writes the difference between the 3DEN edit mission and the current delta.

This replaces `apply → repack → restart` with `apply → push`. Everything upstream of it is unchanged: `MaldenEdit.Malden`, the `AP_*` layers, the compositions, `edenDraw.sqf`, the two-missions rule.

**The diff is by bake key, and that makes moves free.** The key contains the position, so an object the designer dragged has a different key than it had before: it reads as one gone and one new, which is exactly the pair of ops that reproduces the move. No move detection, no heuristics, no matching-by-proximity.

**Baseline** = the baked array, minus `map_hidden`, plus `map_edits`. **Target** = the `AP_MAPDATA` layer of the edit mission. Then:

| Difference | Written as |
| --- | --- |
| in target, not in baseline | `INSERT INTO map_edits` |
| in baseline as a live row, not in target | `DELETE FROM map_edits WHERE id = …` |
| in baseline as a baked row, not in target | `INSERT INTO map_hidden` |

- [ ] **Step 1: Write the failing test**

```python
# tools/test_map_push.py
import unittest

import map_push


class TestDiff(unittest.TestCase):
    def _baked(self):
        return [("Land_A_F", 1.0, 2.0, 3.0), ("Land_B_F", 4.0, 5.0, 6.0)]

    def test_new_object_becomes_an_insert(self):
        target = self._baked() + [("Land_C_F", 7.0, 8.0, 9.0)]
        ops = map_push.diff(self._baked(), {}, [], target)
        self.assertEqual(ops["add"], [("Land_C_F", 7.0, 8.0, 9.0)])
        self.assertEqual(ops["hide"], [])
        self.assertEqual(ops["del"], [])

    def test_removed_baked_object_becomes_a_tombstone(self):
        target = [("Land_A_F", 1.0, 2.0, 3.0)]
        ops = map_push.diff(self._baked(), {}, [], target)
        self.assertEqual(ops["hide"], [("land_b_f|4000|5000|6000", 1)])
        self.assertEqual(ops["add"], [])

    def test_removed_live_row_becomes_a_delete_by_id(self):
        live = [(41, "Land_C_F", 7.0, 8.0, 9.0)]
        ops = map_push.diff(self._baked(), {}, live, self._baked())
        self.assertEqual(ops["del"], [41])

    def test_a_move_is_a_delete_plus_an_add(self):
        # the designer dragged Land_B_F two metres east
        target = [("Land_A_F", 1.0, 2.0, 3.0), ("Land_B_F", 6.0, 5.0, 6.0)]
        ops = map_push.diff(self._baked(), {}, [], target)
        self.assertEqual(ops["hide"], [("land_b_f|4000|5000|6000", 1)])
        self.assertEqual(ops["add"], [("Land_B_F", 6.0, 5.0, 6.0)])

    def test_already_hidden_rows_are_not_re_tombstoned(self):
        hidden = {"land_b_f|4000|5000|6000": 1}
        target = [("Land_A_F", 1.0, 2.0, 3.0)]
        ops = map_push.diff(self._baked(), hidden, [], target)
        self.assertEqual(ops["hide"], [])

    def test_no_change_produces_no_ops(self):
        ops = map_push.diff(self._baked(), {}, [], self._baked())
        self.assertEqual(ops, {"add": [], "del": [], "hide": []})


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd ~/Armapunk2035/tools && python3 test_map_push.py -v`
Expected: FAIL, `ModuleNotFoundError: No module named 'map_push'`

- [ ] **Step 3: Implement `diff`**

Write `tools/map_push.py` with `diff(baked, hidden, live, target)` returning `{"add": [...], "del": [...], "hide": [...]}`. Build the baseline as a multiset of bake keys (baked minus hidden, plus live), the target likewise, and take the two differences. Live rows carry their database id so a removal can name it.

Keep `diff` pure — no database, no filesystem. That is what makes the six tests above possible at all, and it is the only part of this task with logic worth testing.

- [ ] **Step 4: Run the tests**

Run: `cd ~/Armapunk2035/tools && python3 test_map_push.py -v`
Expected: `Ran 6 tests` / `OK`

- [ ] **Step 5: Wire the I/O around it**

Add `main()`: read the baked array via `map_codegen.read_mapdata()`, the edit mission's `AP_MAPDATA` layer via `map_codegen.read_layer()`, and `map_edits` / `map_hidden` from the database — using whichever client the repo's existing DB tooling uses; check before choosing rather than adding a dependency. Then apply the three op lists in one transaction.

`--dry-run` prints the counts and writes nothing. Make it the default for the first week.

**Refuse to push a diff larger than 500 ops unless `--force` is given.** A staging accident, a designer delivery, or the shipped mission opened in the wrong slot all produce enormous diffs, and the failure mode of pushing one is a world that no longer matches any file in git. This repo has already lost a mission to a save it did not expect (the 2026-07-26 Eden re-bake, 15,642 objects).

- [ ] **Step 6: Add the `push` subcommand**

In `tools/edit-map.sh`, add `push` alongside `apply`, calling `python3 tools/map_push.py "$@"`. In `tools/map_watch.py`, add `--push`: run `map_push.py` in place of the codegen-apply-and-reload chain, keeping the existing brace-balance check and the desktop notification. Leave the current behaviour as the default — `--push` is opt-in until it has been driven for a while.

- [ ] **Step 7: Verify the whole loop end to end**

This is the acceptance test for the entire plan.

1. `bash /home/timb/arma3server_dev/reload-armapunk2035.sh`, wait for `read from bank`, join.
2. `python3 tools/map_watch.py --push` in a terminal.
3. Open `MaldenEdit.Malden` in 3DEN, run `edenDraw.sqf` once, drag one prop somewhere obvious inside an `AP_*` layer, Ctrl+S.
4. Watch the terminal, then the game.

Expected: the watcher reports a 2-op diff (one hide, one add); within ~15 s of the save the prop has moved **on the already-connected client**; no repack, no restart, nobody disconnected. `SELECT * FROM map_edits;` and `SELECT * FROM map_hidden;` each show one row. Restart dev and confirm it is still moved.

- [ ] **Step 8: Verify the guardrail**

Delete twenty props in 3DEN and save. Expected: `map_push.py` refuses, names the op count, and writes nothing until `--force`.

- [ ] **Step 9: Commit**

```bash
cd ~/Armapunk2035
git add tools/map_push.py tools/test_map_push.py tools/edit-map.sh tools/map_watch.py
git commit -m "feat(map): push 3DEN saves straight to the delta, no repack or restart"
```

---

## Task 9: `tools/mapdelta_export.py` — bake-down

**Files:**
- Create: `tools/mapdelta_export.py`, `tools/test_mapdelta_export.py`

**Interfaces:**
- Consumes: `mapkey` (Task 2).
- Produces: mapdata rows on stdout, ready to fold into `core/config/fn_mapData.sqf`.

Without this, the delta only ever grows: join-time replay gets slower, and git stops describing the world. The bake-down folds the hot layer back into the cold one — read `map_edits` + `map_hidden`, emit a new `allLocalMapEntities` with the adds appended and the tombstoned rows dropped, then clear the folded rows and let the next deploy carry them.

Run it whenever the delta gets large, or before any deploy that repacks anyway.

- [ ] **Step 1: Write the failing test**

```python
# tools/test_mapdelta_export.py
import unittest

import mapdelta_export as mde


class TestBakeDown(unittest.TestCase):
    def test_row_formatting_matches_mapdata(self):
        row = mde.format_row("Land_Cargo20_blue_F", (8100.0, 7700.0, 20.5),
                             ((0.0, 1.0, 0.0), (0.0, 0.0, 1.0)), "")
        self.assertEqual(
            row,
            '["Land_Cargo20_blue_F",[8100.000,7700.000,20.500],'
            '[[0.0000,1.0000,0.0000],[0.0000,0.0000,1.0000]],"",false]')

    def test_hidden_rows_are_dropped_up_to_occurrences(self):
        baked = [("Land_A_F", 1.0, 2.0, 3.0), ("Land_A_F", 1.0, 2.0, 3.0),
                 ("Land_B_F", 9.0, 9.0, 9.0)]
        hidden = {"land_a_f|1000|2000|3000": 1}
        kept = mde.apply_tombstones(baked, hidden)
        self.assertEqual(len(kept), 2)
        self.assertEqual([r[0] for r in kept], ["Land_A_F", "Land_B_F"])

    def test_occurrences_two_drops_both(self):
        baked = [("Land_A_F", 1.0, 2.0, 3.0), ("Land_A_F", 1.0, 2.0, 3.0)]
        hidden = {"land_a_f|1000|2000|3000": 2}
        self.assertEqual(mde.apply_tombstones(baked, hidden), [])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd ~/Armapunk2035/tools && python3 test_mapdelta_export.py -v`
Expected: FAIL, `ModuleNotFoundError: No module named 'mapdelta_export'`

- [ ] **Step 3: Implement**

Write `tools/mapdelta_export.py` with `format_row`, `apply_tombstones`, and a `main()` that reads the two tables and writes the merged array. Number formatting must match the existing array exactly: positions at three decimals, vectors at four.

- [ ] **Step 4: Run the tests**

Run: `cd ~/Armapunk2035/tools && python3 test_mapdelta_export.py -v`
Expected: `Ran 3 tests` / `OK`

- [ ] **Step 5: Verify a real bake-down is lossless**

```bash
cd ~/Armapunk2035/tools
python3 mapdelta_export.py --dry-run | python3 -c "import sys; print(sum(1 for _ in sys.stdin))"
```
Expected: `9384` plus the current `map_edits` count, minus the tombstoned rows. Re-run `test_mapkey.py` afterwards; if its `9384` assertion now fails, the bake-down landed and the constant needs updating in the same commit — that failure is the intended signal, not a bug.

- [ ] **Step 6: Commit**

```bash
cd ~/Armapunk2035
git add tools/mapdelta_export.py tools/test_mapdelta_export.py
git commit -m "feat(map): fold the live delta back into the baked map array"
```

---

## Execution status — 2026-08-31

All nine tasks' code is written, committed to `main`, and passes every gate that does not
need a running game. **No in-game step has run: the dev server was down for this session and
launching the owner's Arma client unprompted was out of scope.**

**Verified by execution:**

| What | Evidence |
| --- | --- |
| Schema applies, idempotent | Applied twice to `pgm_full_scratch` AND `armapunk`; second pass all-skips |
| `map_meta.rev` trigger | 5 writes across both tables → rev +5, including deletes |
| Bake key | 4/4 tests, incl. the 9384/9355/29 collision assertion on the real array |
| `map_push.diff` | 6/6 tests; move-is-del+add, tombstone, no-op all pinned |
| `map_push` end to end | Dry-run against the real edit mission + dev DB: 9 add / 0 del / 14 hide |
| Staleness guard | Fires on the real stale mission, names both timestamps |
| Bake-down losslessness | Output vs `fn_mapData.sqf`: **byte-identical**, 1,086,657 chars, 9384 rows |
| Brace balance | `sqf_balance.py` ok on all 12 touched SQF files |
| Repo tests | 8/8 suites pass, including the 4 pre-existing map suites |

**Found during execution, fixed:**

1. **The dev database is `pgm_full_scratch`, not `armapunk`.** The container default is the trap.
2. **`spawn` does not inherit local variables.** The poller's key helper had to move inside the spawned block or every op would key as `""`.
3. **Admin level is `call AP_adminLevel`, a function** — `getVariable` on that name returns 0 for everyone, so the prune tool was silently dead.
4. **`read_layer` returns dicts, not tuples**, and there is no `EDIT_SQM` constant. Adapted at the boundary; `diff` stayed pinned.
5. **Staleness is a data-loss bug, not a nuisance.** The edit mission on this box was staged 08-20; `fn_mapData` moved 08-22. A push would have tombstoned 5 real rows (an NPC and four tablets, added under the Grand Exchange comment). Now refused.
6. **The array contains comments.** Re-emitting rows without the inter-row source text erodes them one bake-down at a time.
7. **Mode-2 scalars need `parseNumber`** before they compare as numbers.

**Not run — the in-game gates:**

Task 3 Steps 6–7 · Task 4 Steps 5–6 · Task 5 Step 7 · Task 6 Steps 6–8 and 10 · Task 7 Steps 1, 5, 6 · Task 8 Steps 7–8.

Task 7 Step 5 is the one that matters: insert a row by hand, wait 15 s, and see it appear on an already-connected client. Until that line appears in `loonydev.log`, this feature is unproven.

**Deliberately not done:**

- `map_watch.py --push` is NOT wired. Auto-pushing on every Ctrl+S is the right end state and the wrong thing to enable before the loop has been driven by hand.
- `AP_fnc_mapPrune` is written and registered but **bound to nothing**. Keybind vs admin-menu button is a placement call; every DIK case already taken is in `fn_keyDownHandler.sqf` (1, 5, 6, 7, 9, 10, 11, 20, 21, 33, 35, 38).
- **The SQF↔Python bake-key parity check still has not run.** It is the highest-consequence unverified item in the plan and needs a live client.

---

## Self-Review

**Spec coverage.** DB schema and change signal → Task 1. Bake key / tombstone identity → Task 2. Zone-stream transport → Tasks 3–5. In-game rank gate and prune tool → Task 6 (optional). Out-of-band change detection → Task 7. Editor UI → **3DEN**, wired by Task 8. Round-trip to git → Task 9. The asset split is out of scope by the owner's instruction; full sqm evacuation is deferred with its reasons stated.

**What the revision changed.** The first draft's Task 7 built a transform gizmo from scratch. It is gone. `tools/map_watch.py` was already driving the map from 3DEN — the loop's only defect was its last mile, so the last mile is what this plan replaces. Net effect: the largest and least-specified task in the plan was deleted, and the two that replaced it are both small and both testable.

**Executed rather than proofread** (per the plan-code-is-unexecuted-code rule):

- The Task 1 DDL was applied twice against a scratch database on `armapunk-pg` — both passes verified, second is a clean no-op, and an insert/round-trip was checked.
- The Task 2 collision numbers (9384 rows / 9355 keys / 29 duplicate pairs) were **measured** against the real `fn_mapData.sqf`, not estimated. They are the reason `map_hidden.occurrences` exists.
- The Task 1 `map_meta` / `map_bump_rev` / trigger block was applied to a scratch database and driven: four writes across both tables moved `rev` 0 → 4, and re-applying the whole file was a clean no-op both times.
- The repo has **no curator or Zeus wiring at all** — zero matches for `curator`/`zeus` across `mission/` and `server/`, and zero in `mission.sqm`. Any Zeus option is greenfield, which is why it is named as a later addition rather than an alternative to Task 8.
- Task 2's `mapkey.py` and `test_mapkey.py` were extracted verbatim from this plan and run: all 4 tests pass, including the half-rounding case and the collision-rate assertion against the real 9384-row array. The code in Task 2 is the code that passed.

**Explicitly unverified — the implementer must confirm these before relying on them:**

- Every SQF file in this plan is unrun. Nothing here has been loaded by the engine.
- `BIS_fnc_getUnitByUID` in Task 6 Step 2 is a **known-wrong placeholder**; Task 6 Step 3 exists solely to replace it against the repo's real idiom.
- The `server/AP_server/init.sqf` insertion point in Task 5 Step 5 is named by role, not by verified line number.
- The Task 3 Step 5 edit is given twice — the second form is the correct one; the first is shown only so the diff against the current code is legible.
- The SQF-side bake-key derivation is pinned to `floor(v*1000 + 0.5)` to match Python, but **SQF and Python have never been compared on the same data**. Do this before trusting Task 8, not after: dump 20 keys from SQF via `diag_log` and diff them against `mapkey.bake_key` on the same rows. A silent mismatch means tombstones stop matching, hidden objects come back, and `map_push.py` re-tombstones them on every save. This is the single highest-consequence unverified item in the plan — Task 8's whole diff rests on the two languages agreeing.
- `map_codegen.read_layer()` and `read_mapdata()` exist and are named correctly, but their **return shapes have not been inspected**. Task 8 Step 5 assumes they yield something `diff()` can consume; read them first and adapt at the boundary rather than changing `diff`, which the tests pin.
- The claim that 3DEN cannot be entered from a running multiplayer session is **structural, not cited**. No BIKI page states it in one sentence; it rests on 3DEN being a separate display whose entity tree is the editor's scenario, not a live world. It matters only as the reason this plan takes the offline-Eden route, and the route stands on its own merits regardless.

---

## Deferred: full `mission.sqm` evacuation

Recorded here so the reasoning is not lost, not decomposed into tasks.

The sqm is 2.4 MB / 5504 items: 4464 Objects, 303 Markers, 244 Logics, 81 Groups, 34 Layers, 1 Trigger. Objects, markers, layers and the trigger can all be created at runtime and could move to the DB on this plan's machinery. **Playable slots cannot** — the MP slot list is read from `mission.sqm` at server load and no runtime API creates one — and neither can mission attributes or engine-bound modules. Realistic floor is a ~100 KB stub.

The blocker is not technical. It is that **markers going in the map layer is a standing owner order** (2026-07-30), and its stated reason is that runtime markers are invisible to 3DEN, which is where the map gets edited. An in-game DB editor satisfies that reason — markers become editable in the tool that matters — but it is the owner's rule and the migration list inside it is still the outstanding backlog either way. Put the inversion to him explicitly before writing a line of it.

One incidental finding from Task 2's measurement, unrelated to this plan and worth a separate look: **58 rows of the baked array are 29 exact duplicate pairs** — identical class at an identical position, rendered twice, on every client.
