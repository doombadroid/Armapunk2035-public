# Live Map Editing v2 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In-game map edits — move, add, delete — that reach every connected client within a second, need no restart and no repack, and survive a restart.

**Architecture:** One table, `map_objects`, owns every map row and every row has an integer id. `fn_mapData.sqf` becomes a build artifact generated from that table at pack time and committed. At runtime a client binds the baked array (a snapshot at `AP_mapBakedRev`), tags every object with `AP_mapId`, then applies rows changed since that revision through one applier with two ops, `upsert` and `del`. An in-game edit is a request to the server, which writes the table by id and broadcasts the resulting op immediately. The content-derived bake key, tombstones and the baked/live split of the v1 design are deleted.

**Tech Stack:** SQF (mission + `AP_server` addon), PostgreSQL via `DB_fnc_asyncQuery`/PySQF, Python 3 with `psycopg` (in `~/pysqf-venv`) for the box-side tools.

**Spec:** `mapedit_live.md`. **Previous plan (superseded, kept for its execution record):** `mapedit_live_plan_v1.md`.

## Global Constraints

- **Work on `main` directly.** `git fetch origin` and pull before every task.
- **Commit trailers:** the repo's `Co-Authored-By: <defunct AI>` joke (rotate, no email) AND the harness-required `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>` + `Claude-Session:` lines, until the owner says otherwise.
- Client fn `core/<domain>/fn_name.sqf` → `AP_fnc_name`, registered in `Functions.h`. Server fn `server/AP_server/core/TON/fn_name.sqf` → `APS_fnc_name`, registered in `config.cpp` **inside the block whose `file` is `\AP_server\core\TON`** (line ~298, `class Renamed_TON`). The block beside `dutySRV` is `core\system` — a class registered there resolves to the wrong path and the engine logs a *warning*, not an error.
- Cross-machine calls through `AP_fnc_MP`: `[[args], "fn", target, false] spawn AP_fnc_MP`. `CfgRE.hpp` is a whitelist (`mode = 1`); `allowedTargets` `2` = client→server, `1` = server→client.
- `DB_fnc_asyncQuery` params `[sql, mode, multiarr, sqlParams]`. Mode 2 must be **spawned**. Use `%s` placeholders with the 4th argument — never interpolate a client-supplied value. **Scalars come back needing `parseNumber format ["%1", v]`**; booleans may arrive as strings — coerce with `(toLower format ["%1", v]) in ["true", "t", "1"]`.
- **The dev database is `pgm_full_scratch`**, not `armapunk`. Box-side Python reads the DSN from `PYSQF_DB_DSN`, else from `~/.pysqf_dsn` (one line, chmod 600, created once by the owner — Task 1 Step 4). The DSN is a secret; it never enters the repo.
- Schema files are PostgreSQL, applied out of band, idempotent (`IF NOT EXISTS`). `TEXT`, never `jsonb`.
- **SQF numbers are 32-bit floats.** Integer ids are exact to 16,777,216. Named ceiling; not a concern for years.
- `python3 tools/sqf_balance.py <files>` before every deploy — the *real* checker. `test_sqf_balance.py` tests the checker, not your code.
- Deploy to DEV: `bash /home/timb/arma3server_dev/reload-armapunk2035.sh`. Boot marker `grep "read from bank" /home/timb/arma3server_dev/loonydev.log` (check the timestamp — the log appends). Editor lines are tagged `[AP-MAPEDIT]`; in-game probes `diag_log` with `[AP-PROBE]`.
- Client RPT: newest by mtime under `~/.local/share/Steam/steamapps/compatdata/107410/pfx/drive_c/users/steamuser/AppData/Local/Arma 3/`.
- **No SQF test harness.** Every SQF task's red state is an observation on the dev server or a client RPT, seen before the fix.
- Out of scope: the custom `.p3d` building layer (`custom_p3ds/malden_buildings.sqf`), markers, `is_server` rows as editable objects.

## Pre-flight (do first, independent of every task)

A client probe on 2026-08-31 reported `count allLocalMapEntities` = 18768, exactly twice the 9384 rows in the repo file and the packed PBO. `core/init.sqf` runs once. Before trusting any in-game count in this plan, run in the debug console:

```sqf
diag_log format ["[AP-PROBE] n=%1 dup=%2", count allLocalMapEntities,
    (allLocalMapEntities select 0) isEqualTo (allLocalMapEntities select 9384)];
```

`n=9384 dup=false` means the earlier reading was an artefact. `n=18768 dup=true` means the runtime array is doubled today and the streamer builds the world twice — find the second writer before continuing, because every id-tagging step below assumes one copy of each row.

## File Structure

| File | Responsibility |
| --- | --- |
| `deploy/map_objects.sql` | v2 schema: `map_objects`, the rev-stamping trigger; drops `map_edits`/`map_hidden`. |
| `tools/apdb_dsn.py` | The one place a box-side tool gets the DSN from. |
| `tools/mapdata_rows.py` | Read `fn_mapData.sqf` into rows with `raw`, `gap`, `id`; write it back byte-exact. The only reader/writer of that file. |
| `tools/map_import.py` | One-time migration: rows → table, ids assigned by array order. |
| `tools/map_generate.py` | Table → `fn_mapData.sqf`: header, unchanged rows verbatim, changed rows formatted, deleted rows dropped, new rows appended; purge. |
| `mission/.../core/functions/fn_mapEditApply.sqf` | Client applier: `upsert`, `del`. Rewritten. |
| `mission/.../core/functions/fn_mapEditRemoveId.sqf` | Remove one id from every zone list and the live world. Replaces `fn_mapEditRemoveKey.sqf`. |
| `server/AP_server/core/TON/fn_mapRowOp.sqf` | DB row → `[id, rev, op]`. The one place a row becomes an op. |
| `server/AP_server/core/TON/fn_mapEditLoadOps.sqf` | Rows since `AP_mapBakedRev` → ops. Rewritten. |
| `server/AP_server/core/TON/fn_mapEditEmit.sqf` | After a write: fetch the row by id, update the cache, broadcast. |
| `server/AP_server/core/TON/fn_mapEditSRV.sqf` | Authority: `add`, `move`, `del` by id. Rewritten. |
| `server/AP_server/core/TON/fn_mapEditPoll.sqf` | Diff by id/rev. Rewritten. |
| `tools/map_push.py` | Eden → table by id. Rewritten last. |

Deleted: `tools/mapkey.py`, `tools/test_mapkey.py`, `tools/mapdelta_export.py`, `tools/test_mapdelta_export.py`, `tools/test_map_push.py` (rewritten in Task 11), `mission/.../core/functions/fn_mapKey.sqf`, `fn_mapEditRemoveKey.sqf`.

Modified: `fn_dynamicMapSystem.sqf`, `fn_mapEditLoad.sqf`, `fn_mapEditorOps.sqf`, `fn_mapEditorPanel.sqf`, `fn_mapPrune.sqf`, `fn_mapEditor.sqf`, `edenOracle.sqf`, `oracle_check.py`, `Functions.h`, `config.cpp`, `map_codegen.py`, `deploy/reload-armapunk2035.sh`.

---

## Task 1: Schema v2 and the DSN source

**Files:**
- Create: `deploy/map_objects.sql`, `tools/apdb_dsn.py`
- Test: manual, against `pgm_full_scratch`

**Interfaces:**
- Produces: table `map_objects`; `apdb_dsn.dsn() -> str`, `apdb_dsn.connect()` (psycopg connection, autocommit off).

- [ ] **Step 1: Write the schema**

```sql
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
```

- [ ] **Step 2: Apply twice; second run must be a no-op**

```bash
cd ~/Armapunk2035
docker exec -i armapunk-pg psql -U armapunk -d pgm_full_scratch -v ON_ERROR_STOP=1 < deploy/map_objects.sql
docker exec -i armapunk-pg psql -U armapunk -d pgm_full_scratch -v ON_ERROR_STOP=1 < deploy/map_objects.sql 2>&1 | grep -c "already exists, skipping"
```
Expected: first run `CREATE TABLE ... CREATE TRIGGER`, `DROP TABLE` ×2; second run prints a count ≥ 3 and exits 0. (This exact SQL, minus the drops, was applied twice to a scratch database while the plan was written: idempotent, and 2 inserts + 2 updates left `map_meta.rev = 4` with the rows stamped 3 and 4.)

- [ ] **Step 3: Confirm the trigger stamps rows**

```bash
docker exec -i armapunk-pg psql -U armapunk -d pgm_full_scratch -tA -c "
INSERT INTO map_objects (classname,x,y,z,author_uid) VALUES ('Probe_A',1,2,3,'t'),('Probe_B',4,5,6,'t');
UPDATE map_objects SET x=9 WHERE classname='Probe_A';
SELECT 'meta='||rev FROM map_meta WHERE world='Malden';
SELECT classname||' rev='||rev FROM map_objects WHERE author_uid='t' ORDER BY id;
DELETE FROM map_objects WHERE author_uid='t';"
```
Expected: the UPDATE's row has the highest `rev`, and `meta` equals it. Then the probe rows are gone.

- [ ] **Step 4: The DSN source**

Owner, once, by hand (the value is in the running daemon's environment; never commit it):

```bash
# Anchor to the interpreter path. An unanchored pgrep -f matches BOTH the root-owned
# supervise-daemon parent (environ unreadable) AND the shell running this very command
# (its own command line contains the pattern) -- the repo's documented pgrep self-match.
tr '\0' '\n' < /proc/$(pgrep -f '^/home/timb/pysqf-venv/bin/python pysqfd.py' | head -1)/environ | grep '^PYSQF_DB_DSN=' | cut -d= -f2- > ~/.pysqf_dsn
chmod 600 ~/.pysqf_dsn
grep -c 'dbname=pgm_full_scratch' ~/.pysqf_dsn
```
Expected: `1`.

Then `tools/apdb_dsn.py`:

```python
#!/usr/bin/env python3
"""Where a box-side tool gets the database DSN. The only place.

Env first (a caller can always override), then ~/.pysqf_dsn, which the owner
writes once from the running daemon's environment and chmods 600. The real DSN
lives in root-only /etc/conf.d/pysqfd and is a secret; it never enters the repo.
"""
import os
import sys

DSN_FILE = os.path.expanduser("~/.pysqf_dsn")


def dsn():
    v = os.environ.get("PYSQF_DB_DSN", "").strip()
    if v:
        return v
    try:
        with open(DSN_FILE, encoding="utf-8") as fh:
            v = fh.read().strip()
    except OSError:
        v = ""
    if not v:
        sys.exit("no DSN: set PYSQF_DB_DSN or write ~/.pysqf_dsn (see tools/apdb_dsn.py)")
    return v


def connect():
    import psycopg
    return psycopg.connect(dsn(), autocommit=False)
```

- [ ] **Step 5: Verify the helper connects**

```bash
cd ~/Armapunk2035/tools && ~/pysqf-venv/bin/python -c "import apdb_dsn; c=apdb_dsn.connect(); print(c.execute('select count(*) from map_objects').fetchone()); c.close()"
```
Expected: `(0,)`.

- [ ] **Step 6: Commit**

```bash
cd ~/Armapunk2035 && git add deploy/map_objects.sql tools/apdb_dsn.py && git commit -m "feat(map): v2 schema -- one table, every row an id, trigger-stamped rev

Co-Authored-By: Microsoft Tay
Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Vcvr7nHWNbXPgmLXVsEgYj"
```

---

## Task 2: `mapdata_rows.py` — the one reader/writer of `fn_mapData.sqf`

**Files:**
- Create: `tools/mapdata_rows.py`, `tools/test_mapdata_rows.py`

**Interfaces:**
- Consumes: `mapdata_migrate.parse_rows(src)` (exists; returns dicts with `cls, pos, vec, init, server, tail, raw`).
- Produces:
  - `read(path) -> Doc` where `Doc(header: str, rows: list[Row], trailer: str, baked_rev: int)` and `Row(cls, pos, vdir, vup, init, is_server: bool, loadout: str, id: int|None, raw: str, gap: str)`. `gap` is the source text immediately before the row (its separating comma and any comment). `loadout` is the literal text or `""`.
  - `emit(header, pieces, trailer) -> str` where each piece is `(gap, text)`.
  - `format_row(cls, pos, vdir, vup, init, is_server, loadout, id) -> str`.
  - `splice_id(raw, id) -> str` — append `,[],<id>` inside a 5-element row.

The file holds the owner's inline comments between rows. `parse_rows` drops them; this module recovers them by locating each row's `raw` text in the source and keeping what lies between. Yesterday's emitter proved this reproduces the file byte-for-byte; today it is the reader for every tool that touches the array.

- [ ] **Step 1: Write the failing tests**

```python
# tools/test_mapdata_rows.py
import os
import tempfile
import unittest

import mapdata_rows as mr

MAPDATA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "mission",
                       "Armapunk2035.Malden", "core", "config", "fn_mapData.sqf")

SAMPLE = ('AP_mapBakedRev = 17;\n'
          'allLocalMapEntities=[["Land_A_F",[1.000,2.000,3.000],[[0.0000,1.0000,0.0000],[0.0000,0.0000,1.0000]],"",false,[],1],\n'
          '// owner comment\n'
          '["Land_B_F",[4.000,5.000,6.000],[[0.0000,1.0000,0.0000],[0.0000,0.0000,1.0000]],"say ""hi""",true,[],2]];\n')


class TestRead(unittest.TestCase):
    def test_header_rows_gaps_and_ids(self):
        fd, p = tempfile.mkstemp(suffix=".sqf"); os.close(fd)
        open(p, "w").write(SAMPLE)
        d = mr.read(p); os.unlink(p)
        self.assertEqual(d.baked_rev, 17)
        self.assertEqual([r.id for r in d.rows], [1, 2])
        self.assertEqual(d.rows[0].gap, "")
        self.assertEqual(d.rows[1].gap, ",\n// owner comment\n")
        self.assertEqual(d.rows[1].init, 'say "hi"')
        self.assertTrue(d.rows[1].is_server)
        self.assertEqual(d.rows[1].vdir, (0.0, 1.0, 0.0))
        self.assertEqual(d.trailer, "];\n")

    def test_real_file_round_trips_byte_exact(self):
        src = open(MAPDATA, encoding="utf-8", errors="replace").read()
        d = mr.read(MAPDATA)
        self.assertEqual(len(d.rows), 9384)
        self.assertEqual(d.baked_rev, 0)          # pre-migration file has no header
        out = mr.emit(d.header, [(r.gap, r.raw) for r in d.rows], d.trailer)
        self.assertEqual(out, src)

    def test_five_element_rows_have_no_id(self):
        d = mr.read(MAPDATA)
        self.assertTrue(all(r.id is None for r in d.rows))


class TestWrite(unittest.TestCase):
    def test_format_row(self):
        self.assertEqual(
            mr.format_row("Land_C_F", (8100.0, 7700.0, 20.5), (0, 1, 0), (0, 0, 1), 'a "b"', False, "", 42),
            '["Land_C_F",[8100.000,7700.000,20.500],[[0.0000,1.0000,0.0000],[0.0000,0.0000,1.0000]],"a ""b""",false,[],42]')

    def test_splice_id_into_five_element_row(self):
        raw = '["Land_A_F",[1.000,2.000,3.000],[[0,1,0],[0,0,1]],"",false]'
        self.assertEqual(mr.splice_id(raw, 7), '["Land_A_F",[1.000,2.000,3.000],[[0,1,0],[0,0,1]],"",false,[],7]')

    def test_splice_refuses_a_row_that_already_has_an_id(self):
        with self.assertRaises(ValueError):
            mr.splice_id('["Land_A_F",[1,2,3],[[0,1,0],[0,0,1]],"",false,[],7]', 8)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd ~/Armapunk2035/tools && python3 test_mapdata_rows.py -v`
Expected: FAIL, `ModuleNotFoundError: No module named 'mapdata_rows'`

- [ ] **Step 3: Implement**

```python
#!/usr/bin/env python3
"""The one reader/writer of core/config/fn_mapData.sqf.

Rows come from mapdata_migrate.parse_rows, which returns each row's text verbatim
(`raw`) plus its parsed fields. That parser drops what lies BETWEEN rows -- the
separating comma and the owner's inline comments -- and a rewriter that loses those
erodes the comments one run at a time. read() recovers each row's gap by locating its
raw text in the source, in order, so emit() reproduces the file byte-for-byte when
nothing changed. That identity is the test.

Row shape after migration: [class, pos, [vdir,vup], init, isServer, loadout, id].
Pre-migration rows have five elements and id None.
"""
import collections
import re

import mapdata_migrate

Row = collections.namedtuple("Row", "cls pos vdir vup init is_server loadout id raw gap")
Doc = collections.namedtuple("Doc", "header rows trailer baked_rev")

_VEC = re.compile(r"\[\[([-\d.eE,]+)\],\[([-\d.eE,]+)\]\]$")
_REV = re.compile(r"AP_mapBakedRev\s*=\s*(\d+)\s*;")


def _split_tail(tail):
    """',<loadout>,<id>' -> (loadout_text, id). '' -> ('', None)."""
    if not tail:
        return "", None
    t = tail[1:] if tail.startswith(",") else tail
    lo, _, rid = t.rpartition(",")
    return lo, int(rid)


def read(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        src = fh.read()
    rows = mapdata_migrate.parse_rows(src)
    k = src.index("allLocalMapEntities")
    header = src[:k]
    pos = src.index("[", k) + 1
    out = []
    for r in rows:
        at = src.index(r["raw"], pos)
        gap = src[pos:at]
        pos = at + len(r["raw"])
        m = _VEC.match(r["vec"])
        if not m:
            raise ValueError("row has a scalar direction, not vectors: %s" % r["raw"][:100])
        vdir = tuple(float(v) for v in m.group(1).split(","))
        vup = tuple(float(v) for v in m.group(2).split(","))
        loadout, rid = _split_tail(r["tail"])
        out.append(Row(r["cls"], r["pos"], vdir, vup, r["init"], r["server"] == "true",
                       loadout, rid, r["raw"], gap))
    trailer = src[pos:]
    rm = _REV.search(header)
    return Doc(header, out, trailer, int(rm.group(1)) if rm else 0)


def emit(header, pieces, trailer):
    body = []
    for i, (gap, text) in enumerate(pieces):
        if i == 0:
            # The first surviving row must not open with the comma that separated it
            # from a row that no longer exists -- nor with the whitespace that comma
            # dragged along. A comment in that gap survives; it just moves up.
            gap = re.sub(r"^\s*,\s*", "", gap, count=1)
        body.append(gap + text)
    return header + "allLocalMapEntities=[" + "".join(body) + trailer


def format_row(cls, pos, vdir, vup, init, is_server, loadout, rid):
    return ('["%s",[%.3f,%.3f,%.3f],[[%.4f,%.4f,%.4f],[%.4f,%.4f,%.4f]],"%s",%s,%s,%d]'
            % (cls, pos[0], pos[1], pos[2], vdir[0], vdir[1], vdir[2], vup[0], vup[1], vup[2],
               init.replace('"', '""'), "true" if is_server else "false", loadout or "[]", rid))


def splice_id(raw, rid):
    """Append ',[],<id>' to a five-element row. Refuses a row that already carries one."""
    if not raw.endswith("]"):
        raise ValueError("not a row: %s" % raw[:60])
    if re.search(r",(true|false),.*\]$", raw):
        raise ValueError("row already has a tail: %s" % raw[:60])
    return raw[:-1] + ",[],%d]" % rid
```

- [ ] **Step 4: Run the tests**

Run: `cd ~/Armapunk2035/tools && python3 test_mapdata_rows.py -v`
Expected: `Ran 6 tests` / `OK`. The real-file round trip is the one that matters: 1,086,657 characters, byte-identical.

- [ ] **Step 5: Commit**

```bash
cd ~/Armapunk2035 && git add tools/mapdata_rows.py tools/test_mapdata_rows.py && git commit -m "feat(map): one reader/writer for fn_mapData.sqf, byte-exact with comments and ids

Co-Authored-By: SmarterChild
Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Vcvr7nHWNbXPgmLXVsEgYj"
```

---

## Task 3: `map_import.py` — the one-time migration into the table

**Files:**
- Create: `tools/map_import.py`, `tools/test_map_import.py`

**Interfaces:**
- Consumes: `mapdata_rows.read`, `apdb_dsn.connect`.
- Produces: `rows_to_params(rows, world) -> list[tuple]` (pure); `main()` with `--dry-run`.

Discipline from `mapdata_migrate.py`: pair by array order, assert per row, abort on any mismatch, never resync. The table must be **empty** — ids are assigned by the serial in insertion order and must come out 1…N; if they do not, the table was not empty and the run aborts before generation.

- [ ] **Step 1: Write the failing test**

```python
# tools/test_map_import.py
import unittest

import map_import
import mapdata_rows as mr


class TestParams(unittest.TestCase):
    def test_row_becomes_insert_params_in_order(self):
        r = mr.Row("Land_A_F", (1.0, 2.0, 3.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0),
                   'say "hi"', True, "", None, "", "")
        p = map_import.rows_to_params([r], "Malden")
        self.assertEqual(p, [("Malden", "Land_A_F", 1.0, 2.0, 3.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0,
                              'say "hi"', True, None, "AP_MAPDATA", "migration")])

    def test_refuses_rows_that_already_have_ids(self):
        r = mr.Row("Land_A_F", (1, 2, 3), (0, 1, 0), (0, 0, 1), "", False, "", 5, "", "")
        with self.assertRaises(ValueError):
            map_import.rows_to_params([r], "Malden")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd ~/Armapunk2035/tools && python3 test_map_import.py -v`
Expected: FAIL, `ModuleNotFoundError: No module named 'map_import'`

- [ ] **Step 3: Implement**

```python
#!/usr/bin/env python3
"""ONE-TIME: import fn_mapData.sqf into map_objects, ids assigned by array order.

Follows mapdata_migrate.py's discipline: rows go in array order, the table must be
empty so the serial hands back exactly 1..N, and any deviation aborts. Nothing here
guesses, resyncs or skips -- a single silent shift moves thousands of objects.

    ~/pysqf-venv/bin/python tools/map_import.py --dry-run     # count only
    ~/pysqf-venv/bin/python tools/map_import.py               # import

After this, run tools/map_generate.py --migrate --write to put the ids into the file.
"""
import argparse
import os
import sys

import apdb_dsn
import mapdata_rows as mr

MAPDATA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "mission",
                       "Armapunk2035.Malden", "core", "config", "fn_mapData.sqf")

COLS = ("world, classname, x, y, z, vdir_x, vdir_y, vdir_z, vup_x, vup_y, vup_z, "
        "init, is_server, loadout, layer, author_uid")


def rows_to_params(rows, world):
    out = []
    for r in rows:
        if r.id is not None:
            raise ValueError("row already carries id %d -- this file has been migrated" % r.id)
        out.append((world, r.cls, r.pos[0], r.pos[1], r.pos[2],
                    r.vdir[0], r.vdir[1], r.vdir[2], r.vup[0], r.vup[1], r.vup[2],
                    r.init, r.is_server, r.loadout or None, "AP_MAPDATA", "migration"))
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--world", default="Malden")
    args = ap.parse_args(argv)

    doc = mr.read(MAPDATA)
    params = rows_to_params(doc.rows, args.world)
    print("rows to import: %d" % len(params))
    if args.dry_run:
        return 0

    conn = apdb_dsn.connect()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT count(*) FROM map_objects WHERE world = %s", (args.world,))
            (n,) = cur.fetchone()
            if n:
                sys.exit("refusing: map_objects already holds %d rows for %s. Ids are assigned "
                         "by insertion order and must come out 1..N; this is a one-time import "
                         "into an EMPTY table." % (n, args.world))
            # An empty table does not mean a fresh sequence: any probe row ever inserted and
            # deleted has advanced it, and the ids then come back 3..N+2 and the run aborts.
            # The table is empty (just checked), so restarting the sequence is safe.
            cur.execute("ALTER SEQUENCE map_objects_id_seq RESTART WITH 1")
            ids = []
            for p in params:
                cur.execute("INSERT INTO map_objects (%s) VALUES (%s) RETURNING id"
                            % (COLS, ",".join(["%s"] * 16)), p)
                ids.append(cur.fetchone()[0])
            if ids != list(range(1, len(params) + 1)):
                conn.rollback()
                sys.exit("refusing: ids came back %s..%s, not 1..%d. Rolled back."
                         % (ids[:1], ids[-1:], len(params)))
            cur.execute("SELECT rev FROM map_meta WHERE world = %s", (args.world,))
            (rev,) = cur.fetchone()
        conn.commit()
        print("imported %d rows, ids 1..%d, map_meta.rev = %d" % (len(ids), len(ids), rev))
    finally:
        conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run the tests**

Run: `cd ~/Armapunk2035/tools && python3 test_map_import.py -v`
Expected: `Ran 2 tests` / `OK`

- [ ] **Step 5: Dry-run against the real file**

Run: `cd ~/Armapunk2035 && ~/pysqf-venv/bin/python tools/map_import.py --dry-run`
Expected: `rows to import: 9384`

- [ ] **Step 6: Commit** (do NOT import yet — Task 5 does that after the generator exists)

```bash
cd ~/Armapunk2035 && git add tools/map_import.py tools/test_map_import.py && git commit -m "feat(map): one-time import of the baked array into map_objects, ids by array order

Co-Authored-By: Clippy
Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Vcvr7nHWNbXPgmLXVsEgYj"
```

---

## Task 4: `map_generate.py` — the table becomes the file

**Files:**
- Create: `tools/map_generate.py`, `tools/test_map_generate.py`

**Interfaces:**
- Consumes: `mapdata_rows` (`read`, `emit`, `format_row`, `splice_id`), `apdb_dsn.connect`.
- Produces: `plan(doc, db_rows, new_rev) -> (pieces, stats)` (pure); `migrate_pieces(doc, db_ids) -> pieces` (pure); `main()` with `--write`, `--migrate`, `--dry-run`.

Where `db_rows` is `{id: dict(classname, x, y, z, vdir, vup, init, is_server, loadout, deleted, rev)}`.

Rules, in order, for each row in the **file's** order:
1. id not in `db_rows` → the row was purged: drop it (and its gap).
2. `deleted` → drop it.
3. `db.rev <= doc.baked_rev` → unchanged since the file was generated: emit `raw` verbatim (with its gap).
4. else → emit `format_row` from the table (with its gap).
Then every table row whose id is not in the file and not deleted → append, formatted, with gap `,\n`.

Header is `AP_mapBakedRev = <new_rev>;\n`. `new_rev` is `map_meta.rev` read **before** the rows, so anything written during generation has `rev > new_rev` and lands in the next delta.

- [ ] **Step 1: Write the failing tests**

```python
# tools/test_map_generate.py
import unittest

import map_generate as mg
import mapdata_rows as mr


def row(rid, cls="Land_A_F", gap=",\n", raw=None):
    raw = raw or '["%s",[1.000,2.000,3.000],[[0.0000,1.0000,0.0000],[0.0000,0.0000,1.0000]],"",false,[],%d]' % (cls, rid)
    return mr.Row(cls, (1.0, 2.0, 3.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0), "", False, "", rid, raw, gap)


def db(rid, rev, cls="Land_A_F", deleted=False, x=1.0):
    return {"classname": cls, "x": x, "y": 2.0, "z": 3.0, "vdir": (0.0, 1.0, 0.0), "vup": (0.0, 0.0, 1.0),
            "init": "", "is_server": False, "loadout": "", "deleted": deleted, "rev": rev}


class TestPlan(unittest.TestCase):
    def test_unchanged_rows_are_emitted_verbatim(self):
        doc = mr.Doc("AP_mapBakedRev = 5;\n", [row(1, gap=""), row(2)], "];\n", 5)
        pieces, st = mg.plan(doc, {1: db(1, 3), 2: db(2, 5)}, 9)
        self.assertEqual([p[1] for p in pieces], [doc.rows[0].raw, doc.rows[1].raw])
        self.assertEqual(st, {"kept": 2, "changed": 0, "dropped": 0, "added": 0})

    def test_changed_row_is_reformatted_from_the_table(self):
        doc = mr.Doc("AP_mapBakedRev = 5;\n", [row(1, gap="")], "];\n", 5)
        pieces, st = mg.plan(doc, {1: db(1, 7, x=9.0)}, 9)
        self.assertIn("[9.000,2.000,3.000]", pieces[0][1])
        self.assertEqual(st["changed"], 1)

    def test_deleted_and_purged_rows_are_dropped_with_their_gap(self):
        doc = mr.Doc("AP_mapBakedRev = 5;\n", [row(1, gap=""), row(2, gap=",\n// c\n"), row(3)], "];\n", 5)
        pieces, st = mg.plan(doc, {1: db(1, 5, deleted=True), 3: db(3, 5)}, 9)   # 2 purged, 1 deleted
        self.assertEqual(len(pieces), 1)
        self.assertEqual(pieces[0][1], doc.rows[2].raw)
        self.assertEqual(st["dropped"], 2)

    def test_first_survivor_loses_its_leading_comma(self):
        doc = mr.Doc("AP_mapBakedRev = 5;\n", [row(1, gap=""), row(2)], "];\n", 5)
        pieces, _ = mg.plan(doc, {2: db(2, 5)}, 9)
        out = mr.emit("H\n", pieces, "];\n")
        self.assertEqual(out, "H\nallLocalMapEntities=[" + doc.rows[1].raw + "];\n")

    def test_new_table_rows_are_appended(self):
        doc = mr.Doc("AP_mapBakedRev = 5;\n", [row(1, gap="")], "];\n", 5)
        pieces, st = mg.plan(doc, {1: db(1, 5), 2: db(2, 8, cls="Land_New_F")}, 9)
        self.assertEqual(len(pieces), 2)
        self.assertEqual(pieces[1][0], ",\n")
        self.assertIn('"Land_New_F"', pieces[1][1])
        self.assertEqual(st["added"], 1)


class TestMigrate(unittest.TestCase):
    def test_ids_spliced_by_order_with_class_assertion(self):
        raw = '["Land_A_F",[1.000,2.000,3.000],[[0,1,0],[0,0,1]],"",false]'
        doc = mr.Doc("", [mr.Row("Land_A_F", (1, 2, 3), (0, 1, 0), (0, 0, 1), "", False, "", None, raw, "")], "];\n", 0)
        pieces = mg.migrate_pieces(doc, [(1, "Land_A_F")])
        self.assertEqual(pieces[0][1], raw[:-1] + ",[],1]")

    def test_class_mismatch_aborts(self):
        raw = '["Land_A_F",[1,2,3],[[0,1,0],[0,0,1]],"",false]'
        doc = mr.Doc("", [mr.Row("Land_A_F", (1, 2, 3), (0, 1, 0), (0, 0, 1), "", False, "", None, raw, "")], "];\n", 0)
        with self.assertRaises(SystemExit):
            mg.migrate_pieces(doc, [(1, "Land_B_F")])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd ~/Armapunk2035/tools && python3 test_map_generate.py -v`
Expected: FAIL, `ModuleNotFoundError: No module named 'map_generate'`

- [ ] **Step 3: Implement**

```python
#!/usr/bin/env python3
"""Generate core/config/fn_mapData.sqf from map_objects.

The table owns the rows; this file is a build artifact that is regenerated at pack
time and committed, so git keeps showing every map change as a diff. Rows the table
has not touched since the file was last generated are emitted VERBATIM, comments and
all -- a generated file from an unchanged table is byte-identical to the last one.

    ~/pysqf-venv/bin/python tools/map_generate.py --dry-run          # stats only
    ~/pysqf-venv/bin/python tools/map_generate.py --write            # write + purge
    ~/pysqf-venv/bin/python tools/map_generate.py --migrate --write  # ONE-TIME, after map_import

--migrate pairs the file's five-element rows with table ids BY ARRAY ORDER, asserts
the class on every row, and splices ',[],<id>' into each. Anything off aborts.
"""
import argparse
import os
import shutil
import sys

import apdb_dsn
import mapdata_rows as mr

MAPDATA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "mission",
                       "Armapunk2035.Malden", "core", "config", "fn_mapData.sqf")


def _fmt(rid, d):
    return mr.format_row(d["classname"], (d["x"], d["y"], d["z"]), d["vdir"], d["vup"],
                         d["init"], d["is_server"], d["loadout"], rid)


def plan(doc, db_rows, new_rev):
    pieces, st = [], {"kept": 0, "changed": 0, "dropped": 0, "added": 0}
    seen = set()
    for r in doc.rows:
        d = db_rows.get(r.id)
        if d is None or d["deleted"]:
            st["dropped"] += 1
            continue
        seen.add(r.id)
        if d["rev"] <= doc.baked_rev:
            pieces.append((r.gap, r.raw)); st["kept"] += 1
        else:
            pieces.append((r.gap, _fmt(r.id, d))); st["changed"] += 1
    for rid in sorted(db_rows):
        d = db_rows[rid]
        if rid in seen or d["deleted"]:
            continue
        pieces.append((",\n", _fmt(rid, d))); st["added"] += 1
    return pieces, st


def migrate_pieces(doc, db_ids):
    """db_ids: [(id, classname)] ORDER BY id. Pairs by position; asserts class per row."""
    if len(db_ids) != len(doc.rows):
        sys.exit("refusing: %d rows in the file, %d in the table" % (len(doc.rows), len(db_ids)))
    pieces = []
    for i, (r, (rid, cls)) in enumerate(zip(doc.rows, db_ids)):
        if r.cls != cls:
            sys.exit("refusing: row %d is %s in the file but id %d is %s in the table -- "
                     "the pairing is off, nothing written" % (i, r.cls, rid, cls))
        pieces.append((r.gap, mr.splice_id(r.raw, rid)))
    return pieces


def fetch(conn, world):
    with conn.cursor() as cur:
        cur.execute("SELECT rev FROM map_meta WHERE world = %s", (world,))
        (rev,) = cur.fetchone()
        cur.execute("SELECT id, classname, x, y, z, vdir_x, vdir_y, vdir_z, vup_x, vup_y, vup_z,"
                    " init, is_server, COALESCE(loadout,''), deleted, rev"
                    " FROM map_objects WHERE world = %s", (world,))
        rows = {}
        for (i, c, x, y, z, dx, dy, dz, ux, uy, uz, init, srv, lo, dele, rrev) in cur.fetchall():
            rows[i] = {"classname": c, "x": float(x), "y": float(y), "z": float(z),
                       "vdir": (float(dx), float(dy), float(dz)), "vup": (float(ux), float(uy), float(uz)),
                       "init": init, "is_server": bool(srv), "loadout": lo, "deleted": bool(dele), "rev": int(rrev)}
    return rev, rows


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--migrate", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--world", default="Malden")
    args = ap.parse_args(argv)

    doc = mr.read(MAPDATA)
    conn = apdb_dsn.connect()
    try:
        new_rev, db_rows = fetch(conn, args.world)
        if args.migrate:
            if any(r.id is not None for r in doc.rows):
                sys.exit("refusing --migrate: the file already carries ids")
            with conn.cursor() as cur:
                cur.execute("SELECT id, classname FROM map_objects WHERE world = %s ORDER BY id", (args.world,))
                pieces = migrate_pieces(doc, cur.fetchall())
            st = {"migrated": len(pieces)}
        else:
            if all(r.id is None for r in doc.rows) and doc.rows:
                sys.exit("refusing: the file has no ids. Run map_import.py, then --migrate --write.")
            pieces, st = plan(doc, db_rows, new_rev)
        out = mr.emit("AP_mapBakedRev = %d;\n" % new_rev, pieces, doc.trailer)
        print("baked_rev %d -> %d | %s | %d chars" % (doc.baked_rev, new_rev, st, len(out)), file=sys.stderr)
        if args.dry_run or not args.write:
            return 0
        shutil.copy(MAPDATA, MAPDATA + ".bak")
        with open(MAPDATA, "w", encoding="utf-8") as fh:
            fh.write(out)
        with conn.cursor() as cur:
            cur.execute("DELETE FROM map_objects WHERE world = %s AND deleted AND rev <= %s", (args.world, new_rev))
            purged = cur.rowcount
        conn.commit()
        print("written; purged %d deleted row(s) at or below rev %d" % (purged, new_rev), file=sys.stderr)
    finally:
        conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run the tests**

Run: `cd ~/Armapunk2035/tools && python3 test_map_generate.py -v`
Expected: `Ran 7 tests` / `OK`

- [ ] **Step 5: Commit**

```bash
cd ~/Armapunk2035 && git add tools/map_generate.py tools/test_map_generate.py && git commit -m "feat(map): generate fn_mapData.sqf from map_objects, verbatim where unchanged

Co-Authored-By: Dr. Sbaitso
Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Vcvr7nHWNbXPgmLXVsEgYj"
```

---

## Task 5: Run the migration

**Files:**
- Modify: `mission/Armapunk2035.Malden/core/config/fn_mapData.sqf` (generated)
- Delete: `tools/mapkey.py`, `tools/test_mapkey.py`, `tools/mapdelta_export.py`, `tools/test_mapdelta_export.py`, `tools/test_map_push.py`

**Interfaces:**
- Produces: a migrated file with `AP_mapBakedRev` and ids on every row; a populated table.

- [ ] **Step 1: Import**

```bash
cd ~/Armapunk2035 && ~/pysqf-venv/bin/python tools/map_import.py
```
Expected: `imported 9384 rows, ids 1..9384, map_meta.rev = N` — N is 9384 plus every write the trigger has ever counted (probe rows included); it only has to be ≥ every row's rev.

- [ ] **Step 2: Generate with ids**

```bash
~/pysqf-venv/bin/python tools/map_generate.py --migrate --write
```
Expected: `baked_rev 0 -> N | {'migrated': 9384} | ...` with the same N.

- [ ] **Step 3: The diff must be exactly the shape the spec demands**

```bash
git diff --stat mission/Armapunk2035.Malden/core/config/fn_mapData.sqf
head -c 80 mission/Armapunk2035.Malden/core/config/fn_mapData.sqf; echo
python3 - <<'PY'
import re
s=open('/home/timb/Armapunk2035/mission/Armapunk2035.Malden/core/config/fn_mapData.sqf',encoding='utf-8',errors='replace').read()
print("header ok :", bool(re.match(r"AP_mapBakedRev = \d+;\n", s)))
print("id tails  :", len(re.findall(r',(?:true|false),\[\],\d+\]', s)), "(expect 9384)")
PY
cd tools && python3 test_mapdata_rows.py 2>&1 | tail -1
```
Expected: the header is present, 9384 id tails, and **`test_mapdata_rows` now FAILS on `test_five_element_rows_have_no_id` and on `baked_rev == 0`** — those two assertions describe the pre-migration file. That failure is the intended signal. Update both tests to the migrated truth (`[r.id for r in d.rows] == list(range(1, 9385))`, `baked_rev == 9384`) and re-run: `OK`.

- [ ] **Step 4: Confirm the Eden pipeline still reads the file**

```bash
cd ~/Armapunk2035/tools && python3 test_map_codegen.py 2>&1 | tail -1 && python3 -c "import map_codegen; e=map_codegen.read_mapdata(); print(len(e), e[0]['cls'])"
```
Expected: `0 failure(s)` and `9384 C_Man_formal_2_F_afro`. (`parse_rows` tolerates the header and the 7-element tail — verified while writing this plan.)

- [ ] **Step 5: Delete the content-key tooling**

```bash
cd ~/Armapunk2035 && git rm -q tools/mapkey.py tools/test_mapkey.py tools/mapdelta_export.py tools/test_mapdelta_export.py tools/test_map_push.py
grep -rn "import mapkey\|mapdelta_export" tools/*.py | grep -vE "^tools/(map_push|oracle_check).py" || echo "no stale imports"
```
`map_push.py` still imports `mapkey` until Task 11 rewrites it, and `oracle_check.py` until Task 9 trims it; both are expected and neither is run before then.

- [ ] **Step 6: Deploy and verify the migrated file boots**

```bash
bash /home/timb/arma3server_dev/reload-armapunk2035.sh
until grep -a "read from bank" /home/timb/arma3server_dev/loonydev.log | tail -1 | grep -q "b08"; do sleep 3; done
grep -a "AP-MAPEDIT\|fn_mapData" /home/timb/arma3server_dev/loonydev.log | tail -3
```
Expected: a fresh `read from bank`, and no `Error` mentioning `fn_mapData`. The v1 loader still runs at this point and logs `delta loaded: 0 ops` (its tables are gone; the query returns `[]`), which is fine for one deploy — Task 7 replaces it. What this step verifies is that the migrated file **parses and boots**.

- [ ] **Step 7: Commit the migrated file**

```bash
cd ~/Armapunk2035 && git add -A mission/Armapunk2035.Malden/core/config/fn_mapData.sqf tools/ && git commit -m "feat(map): migrate the baked array -- every row carries its id, file carries AP_mapBakedRev

Co-Authored-By: ELIZA
Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Vcvr7nHWNbXPgmLXVsEgYj"
```

---

## Task 6: Client runtime by id

**Files:**
- Modify: `mission/Armapunk2035.Malden/core/functions/fn_dynamicMapSystem.sqf`
- Rewrite: `mission/Armapunk2035.Malden/core/functions/fn_mapEditApply.sqf`
- Create: `mission/Armapunk2035.Malden/core/functions/fn_mapEditRemoveId.sqf`
- Delete: `fn_mapEditRemoveKey.sqf`, `fn_mapKey.sqf`
- Modify: `Functions.h`

**Interfaces:**
- Consumes: `AP_fnc_mapZoneFor` (unchanged), `AP_fnc_createVehicleLocal`.
- Produces: `["upsert", [_row]] call AP_fnc_mapEditApply` and `["del", [_id]] call AP_fnc_mapEditApply`; `[_id] call AP_fnc_mapEditRemoveId -> count removed`. Every streamed object carries `AP_mapId` (number).

- [ ] **Step 1: Observe the red state**

Join dev (post-Task-5 build). Debug console:

```sqf
private _o = cursorObject;
diag_log format ["[AP-PROBE] key=%1 id=%2", _o getVariable ["AP_mapKey","-"], _o getVariable ["AP_mapId","-"]];
```
Expected in the RPT: a v1 string key and `id=-`. That is the state this task replaces.

- [ ] **Step 2: Tag by id in the streamer**

In `fn_dynamicMapSystem.sqf`, `dynamicMap_fnc_loadArea`, replace the v1 tagging block:

```sqf
            private _mk = _x param [6, ""];
            if (_mk isEqualTo "") then { _mk = [_x select 0, _x select 1] call AP_fnc_mapKey; };
            _object setVariable ["AP_mapKey", _mk];
```
with:
```sqf
            // Row identity is element 6 -- the integer id the row carries in the table and
            // in the generated file. Nothing is derived; a row without one is a row the
            // migration missed, and that is worth a log line rather than a guess.
            private _mid = _x param [6, -1];
            if (!(_mid isEqualType 0) || {_mid < 1}) then {
                diag_log format ["[AP-MAPEDIT] row without id: %1", _x select [0, 2]];
            };
            _object setVariable ["AP_mapId", _mid];
```

- [ ] **Step 3: The remover**

`fn_mapEditRemoveId.sqf`:

```sqf
/*
    File: fn_mapEditRemoveId.sqf  (AP_fnc_mapEditRemoveId)
    Remove one map row, by id, from whichever zone list holds it and from the live world.

    Both halves, always: removing only from the list leaves the object standing until the
    zone unloads; removing only the object brings it back on the next load.

    Known limit: a zone that is mid-load (status "creating") is iterating its list with
    uiSleep between creates. Removing from that list while it iterates can leave one
    live object behind until the zone next unloads. Admin-tool scale; not worth a lock.

    params: 0 = id
    returns: rows removed (0 or 1)
*/
params [["_id", -1, [0]]];
if (_id < 1 || {isNil "dynamicMap_zoneLocations"}) exitWith { 0 };

private _removed = 0;
{
    private _lv = format ["dynamicMap_%1_objectList", _x];
    private _av = format ["dynamicMap_%1_activeObjects", _x];
    private _list = missionNamespace getVariable [_lv, []];
    private _i = _list findIf { (_x param [6, -1]) isEqualTo _id };
    if (_i > -1) then {
        _list deleteAt _i;
        missionNamespace setVariable [_lv, _list];
        private _act = missionNamespace getVariable [_av, []];
        private _j = _act findIf { (_x getVariable ["AP_mapId", -1]) isEqualTo _id };
        if (_j > -1) then {
            deleteVehicle (_act select _j);
            _act deleteAt _j;
            missionNamespace setVariable [_av, _act];
        };
        _removed = 1;
    };
    if (_removed > 0) exitWith {};
} forEach (["static"] + (dynamicMap_zoneLocations apply { _x select 2 }));
_removed
```

- [ ] **Step 4: The applier**

`fn_mapEditApply.sqf`, whole file:

```sqf
/*
    File: fn_mapEditApply.sqf  (AP_fnc_mapEditApply)
    Apply ONE map op to this client's world. Two ops, both by id.

    The single writer of live map state, used by two callers that must not diverge: the
    server's broadcast after an edit, and a joining client replaying every row changed
    since its PBO's AP_mapBakedRev. One path means join-time and edit-time cannot drift,
    and every op is an edit TO the binned result, so there is no race with the streamer.

      upsert [row]   row = [class, pos, [vdir,vup], init, isServer, loadout, id]
                     removes any object already carrying that id, bins the row, creates
                     it if its zone is loaded. A move is an upsert. A move across a zone
                     boundary is handled by construction.
      del [id]

    Objects are CLIENT-LOCAL, so an op costs one local create or delete and nothing on
    the network. Server rows (isServer) are never created here.
*/
params [["_op", "", [""]], ["_payload", [], [[]]]];
if (!hasInterface) exitWith {};
if (isNil "dynamicMap_zoneLocations") exitWith {};   // streamer not up; the join replay re-runs

switch (toLower _op) do {
    case "upsert": {
        _payload params [["_row", [], [[]]]];
        if (count _row < 7) exitWith { diag_log format ["[AP-MAPEDIT] upsert with %1 elements refused", count _row]; };
        private _id = _row select 6;
        if (!(_id isEqualType 0) || {_id < 1}) exitWith {};
        [_id] call AP_fnc_mapEditRemoveId;
        _row params ["_cls", "_pos", "", "_init", "_srv"];
        if (_srv) exitWith {};   // replicated by the server, not local
        private _zone = [_pos, _srv, _init] call AP_fnc_mapZoneFor;
        private _lv = format ["dynamicMap_%1_objectList", _zone];
        private _list = missionNamespace getVariable [_lv, []];
        _list pushBack _row;
        missionNamespace setVariable [_lv, _list];
        if ((missionNamespace getVariable [format ["dynamicMap_%1_status", _zone], "idle"]) isEqualTo "active") then {
            private _obj = _row call AP_fnc_createVehicleLocal;
            if (!isNull _obj) then {
                _obj setVariable ["AP_mapId", _id];
                private _av = format ["dynamicMap_%1_activeObjects", _zone];
                private _act = missionNamespace getVariable [_av, []];
                _act pushBack _obj;
                missionNamespace setVariable [_av, _act];
            };
        };
    };
    case "del": {
        _payload params [["_id", -1, [0]]];
        [_id] call AP_fnc_mapEditRemoveId;
    };
    default { diag_log format ["[AP-MAPEDIT] unknown op %1", _op]; };
};
```

- [ ] **Step 5: Registrations and deletions**

`Functions.h`: replace the `mapEditRemoveKey` line with
```cpp
 class mapEditRemoveId {};   // AP_fnc_mapEditRemoveId -- remove one row by id from its zone list and the live world
```
and delete the `class mapKey {};` line.

```bash
cd ~/Armapunk2035 && git rm -q mission/Armapunk2035.Malden/core/functions/fn_mapEditRemoveKey.sqf mission/Armapunk2035.Malden/core/functions/fn_mapKey.sqf
grep -rn "mapEditRemoveKey\|AP_fnc_mapKey\|AP_mapKey" mission/Armapunk2035.Malden --include=*.sqf --include=*.h
```
Expected: hits only in `fn_mapEditorOps.sqf`, `fn_mapEditorPanel.sqf`, `fn_mapPrune.sqf`, `fn_mapEditor.sqf`, `edenOracle.sqf` — Tasks 8 and 9 clean those.

- [ ] **Step 6: Brace gate, deploy, verify**

```bash
python3 tools/sqf_balance.py mission/Armapunk2035.Malden/core/functions/fn_dynamicMapSystem.sqf mission/Armapunk2035.Malden/core/functions/fn_mapEditApply.sqf mission/Armapunk2035.Malden/core/functions/fn_mapEditRemoveId.sqf
bash /home/timb/arma3server_dev/reload-armapunk2035.sh
```
Join. Console:
```sqf
private _o = cursorObject;
diag_log format ["[AP-PROBE] id=%1 rowsWithoutId=%2", _o getVariable ["AP_mapId","-"],
    { !((_x param [6,-1]) isEqualType 0) } count allLocalMapEntities];
["upsert", [["Land_Cargo20_blue_F", getPosWorld player vectorAdd [5,0,0], [[0,1,0],[0,0,1]], "", false, [], 999001]]] call AP_fnc_mapEditApply;
uiSleep 1;
diag_log format ["[AP-PROBE] add present=%1", { (_x getVariable ["AP_mapId",-1]) isEqualTo 999001 } count dynamicMap_static_activeObjects];
["del", [999001]] call AP_fnc_mapEditApply;
uiSleep 1;
diag_log format ["[AP-PROBE] del present=%1", { (_x getVariable ["AP_mapId",-1]) isEqualTo 999001 } count dynamicMap_static_activeObjects];
```
Expected: a numeric id, `rowsWithoutId=0`, a container appears (`add present=1`) and vanishes (`del present=0`).

- [ ] **Step 7: Commit**

```bash
cd ~/Armapunk2035 && git add -A mission/Armapunk2035.Malden && git commit -m "feat(map): client runtime by id -- upsert/del, AP_mapId on every streamed object

Co-Authored-By: Bonzi Buddy
Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Vcvr7nHWNbXPgmLXVsEgYj"
```

---

## Task 7: Server by id — load, emit, authority, poll

**Files:**
- Create: `server/AP_server/core/TON/fn_mapRowOp.sqf`, `server/AP_server/core/TON/fn_mapEditEmit.sqf`
- Rewrite: `fn_mapEditLoadOps.sqf`, `fn_mapEditSRV.sqf`, `fn_mapEditPoll.sqf`
- Modify: `fn_mapEditLoad.sqf`, `server/AP_server/config.cpp`

**Interfaces:**
- Consumes: `DB_fnc_asyncQuery`, `AP_fnc_mapPlaceable`, `AP_fnc_MP`, `APS_fnc_mapEditAudit` (unchanged), `AP_mapBakedRev` (set when `AP_fnc_mapData` runs on the server in `initServer.sqf`).
- Produces: `APS_mapDelta` — a HashMap `id -> [rev, op]`; `[_dbRow] call APS_fnc_mapRowOp -> [id, rev, op]`; `[_id] call APS_fnc_mapEditEmit`; `APS_fnc_mapEditSRV` ops `add [cls,pos,vdu]`, `move [id,pos,vdu]`, `del [id]`.

**Coercion rule for this task:** every scalar from a mode-2 query goes through `parseNumber format ["%1", v]` and every boolean through `(toLower format ["%1", v]) in ["true","t","1"]`. The first deploy of Task 7 Step 7 must include a `diag_log` of one raw row so the actual shapes PySQF returns are recorded in the RPT; adjust the coercions if they differ, then remove the log line.

- [ ] **Step 1: Observe the red state**

`grep -a "AP-MAPEDIT" /home/timb/arma3server_dev/loonydev.log | tail -2` on the Task 6 build: `delta loaded: 0 ops` from the v1 loader whose tables no longer exist. Nothing reads `map_objects`.

- [ ] **Step 2: Row → op, in one place**

`fn_mapRowOp.sqf`:

```sqf
/*
    File: fn_mapRowOp.sqf  (APS_fnc_mapRowOp)
    One database row of map_objects -> [id, rev, op] for AP_fnc_mapEditApply.

    The ONLY place a row becomes an op. The boot load, the poll and every in-game
    write all pass through here, so a client can never receive two shapes for one row.

    Column order is fixed and shared by every SELECT that feeds this:
      id, classname, x, y, z, vdir_x, vdir_y, vdir_z, vup_x, vup_y, vup_z,
      init, is_server, COALESCE(loadout,''), deleted, rev
    Scalars are coerced through format/parseNumber and booleans through a string test,
    because the transport's typing has to be observed, not assumed.
*/
params [["_r", [], [[]]]];
if (count _r < 16) exitWith { [] };
private _n = { parseNumber format ["%1", _this] };
private _b = { (toLower format ["%1", _this]) in ["true", "t", "1"] };
_r params ["_id", "_cls", "_px", "_py", "_pz", "_dx", "_dy", "_dz", "_ux", "_uy", "_uz",
           "_init", "_srv", "_lo", "_del", "_rev"];
_id = _id call _n; _rev = _rev call _n;
if (_del call _b) exitWith { [_id, _rev, ["del", [_id]]] };
private _loadout = if ((format ["%1", _lo]) isEqualTo "") then { [] } else { parseSimpleArray (format ["%1", _lo]) };
[_id, _rev, ["upsert", [[
    format ["%1", _cls],
    [_px call _n, _py call _n, _pz call _n],
    [[_dx call _n, _dy call _n, _dz call _n], [_ux call _n, _uy call _n, _uz call _n]],
    format ["%1", _init],
    _srv call _b,
    _loadout,
    _id]]]]
```

- [ ] **Step 3: The loader**

`fn_mapEditLoadOps.sqf`, whole file:

```sqf
/*
    File: fn_mapEditLoadOps.sqf  (APS_fnc_mapEditLoadOps)
    Every row changed since this PBO was generated, as [id, rev, op] triples.

    AP_mapBakedRev is set by the generated fn_mapData.sqf when initServer runs it. A PBO
    from before the migration has none and gets 0, which replays every row -- safe, and
    loud in the log so nobody mistakes it for normal.

    Mode-2 reads must be scheduled. Server-only. No CfgRE entry.
*/
if (!isServer) exitWith { [] };
private _baked = missionNamespace getVariable ["AP_mapBakedRev", 0];
if (_baked isEqualTo 0) then { diag_log "[AP-MAPEDIT] WARNING: AP_mapBakedRev is 0 -- replaying the whole table"; };
private _rows = [
    "SELECT id, classname, x, y, z, vdir_x, vdir_y, vdir_z, vup_x, vup_y, vup_z, init, is_server, COALESCE(loadout,''), deleted, rev FROM map_objects WHERE world = %s AND rev > %s ORDER BY id",
    2, true, [worldName, _baked]
] call DB_fnc_asyncQuery;
private _ops = [];
{ private _t = [_x] call APS_fnc_mapRowOp; if (_t isNotEqualTo []) then { _ops pushBack _t; }; } forEach _rows;
if (count _ops > 500) then { diag_log format ["[AP-MAPEDIT] WARNING: delta is %1 rows -- time to pack", count _ops]; };
_ops
```

`fn_mapEditLoad.sqf` — replace the `_boot` branch and the replay loop:

```sqf
if (_boot) exitWith {
    APS_mapDelta = createHashMap;
    { APS_mapDelta set [_x select 0, [_x select 1, _x select 2]]; } forEach ([] call APS_fnc_mapEditLoadOps);
    diag_log format ["[AP-MAPEDIT] delta loaded: %1 rows since rev %2", count APS_mapDelta, missionNamespace getVariable ["AP_mapBakedRev", 0]];
};
private _owner = remoteExecutedOwner;
if (_owner isEqualTo 0) exitWith {};
private _n = 0;
{
    [_y select 1, "AP_fnc_mapEditApply", _owner, false] spawn AP_fnc_MP;
    _n = _n + 1;
    uiSleep 0.01;
} forEach (missionNamespace getVariable ["APS_mapDelta", createHashMap]);
diag_log format ["[AP-MAPEDIT] replayed %1 rows to owner %2", _n, _owner];
```

- [ ] **Step 4: Emit after a write**

`fn_mapEditEmit.sqf`:

```sqf
/*
    File: fn_mapEditEmit.sqf  (APS_fnc_mapEditEmit)
    After the authority writes a row: fetch it back, update the cache, broadcast.

    The write itself cannot return the row on this transport, so it is read back by id.
    Updating APS_mapDelta here is what stops the next poll re-broadcasting an edit the
    server already sent -- the poll compares revs, and the cached rev now matches.

    Server-only. No CfgRE entry.
*/
params [["_id", -1, [0]]];
if (!isServer || {_id < 1}) exitWith {};
private _rows = [
    "SELECT id, classname, x, y, z, vdir_x, vdir_y, vdir_z, vup_x, vup_y, vup_z, init, is_server, COALESCE(loadout,''), deleted, rev FROM map_objects WHERE world = %s AND id = %s",
    2, true, [worldName, _id]
] call DB_fnc_asyncQuery;
if (_rows isEqualTo []) exitWith { diag_log format ["[AP-MAPEDIT] emit: id %1 not found after write", _id]; };
private _t = [_rows select 0] call APS_fnc_mapRowOp;
if (_t isEqualTo []) exitWith {};
APS_mapDelta set [_t select 0, [_t select 1, _t select 2]];
[_t select 2, "AP_fnc_mapEditApply", 0, false] spawn AP_fnc_MP;
```

- [ ] **Step 5: The authority**

`fn_mapEditSRV.sqf`, whole file. Header comment and the caller/rank/rate-limit block are unchanged from v1 (copy them verbatim from the current file); replace everything from `private _world = worldName;` down:

```sqf
private _world = worldName;

switch (toLower _op) do {

    case "add": {
        _payload params [["_class", "", [""]], ["_pos", [], [[]]], ["_vdirup", [], [[]]]];
        if (_class isEqualTo "" || {count _pos < 3} || {count _vdirup < 2}) exitWith {};
        if !([_class] call AP_fnc_mapPlaceable) exitWith {
            diag_log format ["[AP-MAPEDIT] class refused by allowlist: %1 (uid %2)", _class, _uid];
            [["-SEC-", _caller, name _caller, format ["BLOCKED mapEditSRV: class %1 outside the inert-geometry allowlist", _class]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
        };
        _vdirup params ["_vdir", "_vup"];
        // init is NOT a column here. It is compiled and spawned on every client; a client
        // that could set it would have code execution on every connected machine.
        [
            "INSERT INTO map_objects (world, classname, x, y, z, vdir_x, vdir_y, vdir_z, vup_x, vup_y, vup_z, author_uid) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)",
            1, false,
            [_world, _class, _pos select 0, _pos select 1, _pos select 2,
             _vdir select 0, _vdir select 1, _vdir select 2, _vup select 0, _vup select 1, _vup select 2, _uid]
        ] call DB_fnc_asyncQuery;
        private _idRow = ["SELECT id FROM map_objects WHERE world = %s AND author_uid = %s ORDER BY id DESC LIMIT 1", 2, false, [_world, _uid]] call DB_fnc_asyncQuery;
        private _id = parseNumber format ["%1", _idRow param [0, -1]];
        if (_id < 1) exitWith { diag_log format ["[AP-MAPEDIT] INSERT did not land for uid %1 class %2", _uid, _class]; };
        [_id] call APS_fnc_mapEditEmit;
        [_uid, "add", _class, format ["%1 id=%2", _pos, _id]] spawn APS_fnc_mapEditAudit;
    };

    case "move": {
        _payload params [["_id", -1, [0]], ["_pos", [], [[]]], ["_vdirup", [], [[]]]];
        if (_id < 1 || {count _pos < 3} || {count _vdirup < 2}) exitWith {};
        _vdirup params ["_vdir", "_vup"];
        // Transform columns only. init, loadout, layer are untouched -- a moved NPC anchor
        // keeps its behaviour. Server rows and deleted rows are excluded by the WHERE.
        [
            "UPDATE map_objects SET x=%s, y=%s, z=%s, vdir_x=%s, vdir_y=%s, vdir_z=%s, vup_x=%s, vup_y=%s, vup_z=%s, author_uid=%s WHERE id=%s AND world=%s AND deleted=false AND is_server=false",
            1, false,
            [_pos select 0, _pos select 1, _pos select 2, _vdir select 0, _vdir select 1, _vdir select 2,
             _vup select 0, _vup select 1, _vup select 2, _uid, _id, _world]
        ] call DB_fnc_asyncQuery;
        [_id] call APS_fnc_mapEditEmit;
        [_uid, "move", str _id, format ["%1", _pos]] spawn APS_fnc_mapEditAudit;
    };

    case "del": {
        _payload params [["_id", -1, [0]]];
        if (_id < 1) exitWith {};
        ["UPDATE map_objects SET deleted=true, author_uid=%s WHERE id=%s AND world=%s AND is_server=false", 1, false, [_uid, _id, _world]] call DB_fnc_asyncQuery;
        [_id] call APS_fnc_mapEditEmit;
        [_uid, "del", str _id, ""] spawn APS_fnc_mapEditAudit;
    };
};
```

- [ ] **Step 6: The poll**

`fn_mapEditPoll.sqf` — replace the spawned body's diff (everything from `private _fresh = ...` to the `APS_mapPollRev = _rev;` line) with:

```sqf
                private _fresh = [] call APS_fnc_mapEditLoadOps;
                private _sent = 0;
                {
                    _x params ["_id", "_rev", "_op"];
                    private _have = APS_mapDelta getOrDefault [_id, [-1, []]];
                    if !((_have select 0) isEqualTo _rev) then {
                        APS_mapDelta set [_id, [_rev, _op]];
                        [_op, "AP_fnc_mapEditApply", 0, false] spawn AP_fnc_MP;
                        _sent = _sent + 1;
                        uiSleep 0.01;
                    };
                } forEach _fresh;
                APS_mapPollRev = _rev;
                diag_log format ["[AP-MAPEDIT] rev=%1 applied: %2 row(s)", _rev, _sent];
```
and delete the `_fnc_opKey` helper — identity is the id.

- [ ] **Step 7: Register, brace gate, deploy, verify**

`config.cpp`, in the `\AP_server\core\TON` block beside the existing `mapEdit*` lines:
```cpp
class mapRowOp {};        // live map editor: ONE place a map_objects row becomes an op (server-local; NO CfgRE entry)
class mapEditEmit {};     // live map editor: after a write, read the row back, update the cache, broadcast (server-local; NO CfgRE entry)
```
Add a temporary `diag_log format ["[AP-MAPEDIT] RAWROW %1", _rows select 0];` in `fn_mapEditLoadOps` for this deploy only.

```bash
python3 tools/sqf_balance.py server/AP_server/core/TON/fn_mapRowOp.sqf server/AP_server/core/TON/fn_mapEditEmit.sqf server/AP_server/core/TON/fn_mapEditLoadOps.sqf server/AP_server/core/TON/fn_mapEditLoad.sqf server/AP_server/core/TON/fn_mapEditSRV.sqf server/AP_server/core/TON/fn_mapEditPoll.sqf
bash /home/timb/arma3server_dev/reload-armapunk2035.sh
docker exec -i armapunk-pg psql -U armapunk -d pgm_full_scratch -q -c "INSERT INTO map_objects (world,classname,x,y,z,author_uid) VALUES ('Malden','Land_Cargo20_yellow_F',8110,7700,20,'checklist');"
until grep -a "AP-MAPEDIT] rev=" /home/timb/arma3server_dev/loonydev.log | tail -1 | grep -q "applied: 1"; do sleep 3; done
grep -a "AP-MAPEDIT" /home/timb/arma3server_dev/loonydev.log | tail -4
```
Expected: `delta loaded: 0 rows since rev N`, no `Script ... not found`, a `RAWROW` line showing the actual value shapes, then `rev=N+1 applied: 1 row(s)`. Record the RAWROW shapes in the commit message, fix the coercions if they were wrong, remove the log line.

Then, with two clients connected, from one:
```sqf
[["add", ["Land_Cargo20_blue_F", getPosWorld player vectorAdd [6,0,0], [[0,1,0],[0,0,1]]]], "APS_fnc_mapEditSRV", 2, false] spawn AP_fnc_MP;
```
Expected: the container appears on **both** within a second, before any poll tick; the next poll logs `applied: 0 row(s)` (the cache already had it); `SELECT id, rev FROM map_objects ORDER BY id DESC LIMIT 1` shows it.

Then move an NPC anchor by id (pick one: `SELECT id, classname, init FROM map_objects WHERE init <> '' LIMIT 1`), from the console with its id and a position 2 m away:
```sqf
[["move", [<id>, <pos>, [[0,1,0],[0,0,1]]]], "APS_fnc_mapEditSRV", 2, false] spawn AP_fnc_MP;
```
Expected: `SELECT init FROM map_objects WHERE id = <id>` is **unchanged** — the defect this design exists to fix.

- [ ] **Step 8: Commit**

```bash
cd ~/Armapunk2035 && git add -A server/AP_server && git commit -m "feat(map): server by id -- load since AP_mapBakedRev, emit on write, poll by rev

Co-Authored-By: Prodigy
Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Vcvr7nHWNbXPgmLXVsEgYj"
```

---

## Task 8: Editor — everything is a move

**Files:**
- Modify: `core/admin/fn_mapEditorOps.sqf`, `core/admin/fn_mapEditorPanel.sqf`, `core/admin/fn_mapPrune.sqf`, `core/admin/fn_mapEditor.sqf`

**Interfaces:**
- Consumes: `AP_mapId` on objects; `APS_fnc_mapEditSRV` ops from Task 7.

- [ ] **Step 1: Observe the red state**

F12, select a prop, G, move, LMB. On the Task 7 build the client still sends v1's `hide`+`add` (the server's `switch` has no `hide` case → silently nothing). Expected: the object snaps back and stays. That silence is the state this task fixes.

- [ ] **Step 2: Ops**

In `fn_mapEditorOps.sqf`:

Replace the three helpers
```sqf
AP_fnc_mapEdKeyOf   = { (_this getVariable ["AP_mapKey", ""]) };
AP_fnc_mapEdIsLive  = { ((_this call AP_fnc_mapEdKeyOf) select [0,5]) isEqualTo "live:" };
AP_fnc_mapEdIdOf    = { parseNumber ((_this call AP_fnc_mapEdKeyOf) select [5]) };
```
with
```sqf
AP_fnc_mapEdIdOf = { _this getVariable ["AP_mapId", -1] };
```

Replace the body of `AP_fnc_mapEdCommitGrab` from `_o setPosWorld _old;` to the end of the function with:
```sqf
    _o setPosWorld _old;
    private _id = _o call AP_fnc_mapEdIdOf;
    if (_id < 1) exitWith { systemChat "not a map row (no id)"; };
    AP_mapEd_undo pushBack ["move", [_id, _old, [vectorDir _o, vectorUp _o]]];
    [["move", [_id, _new, _vdu]], "APS_fnc_mapEditSRV", 2, false] spawn AP_fnc_MP;
    systemChat format ["move requested (row %1)", _id];
};
```

Replace `AP_fnc_mapEdDelete` with:
```sqf
AP_fnc_mapEdDelete = {
    if (isNull AP_mapEd_sel) exitWith {};
    private _id = AP_mapEd_sel call AP_fnc_mapEdIdOf;
    if (_id < 1) exitWith { systemChat "not a map row (no id)"; };
    [["del", [_id]], "APS_fnc_mapEditSRV", 2, false] spawn AP_fnc_MP;
    systemChat format ["delete requested (row %1)", _id];
    AP_mapEd_sel = objNull;
};
```

In `AP_fnc_mapEdUndo`, remove the `"add"` case (a placement's id is not known client-side until the broadcast arrives; undo covers moves) and update the header comment's undo paragraph to say so.

- [ ] **Step 3: Panel apply**

In `fn_mapEditorPanel.sqf`, `AP_fnc_mapEditorPanelApply`, replace the `if (_o call AP_fnc_mapEdIsLive) then { ... } else { ... };` block with:
```sqf
    private _id = _o call AP_fnc_mapEdIdOf;
    if (_id < 1) exitWith { hint "Not a map row."; };
    AP_mapEd_undo pushBack ["move", [_id, _old, [vectorDir _o, vectorUp _o]]];
    [["move", [_id, _new, _vdu]], "APS_fnc_mapEditSRV", 2, false] spawn AP_fnc_MP;
```

- [ ] **Step 4: Prune, selection, label**

`fn_mapPrune.sqf` — replace everything from `private _key = ...` to the end with:
```sqf
private _id = _obj getVariable ["AP_mapId", -1];
if (_id < 1) exitWith { hint "Prune: that is not a map object (no AP_mapId) -- mission content, a vehicle or a player."; };
[["del", [_id]], "APS_fnc_mapEditSRV", 2, false] spawn AP_fnc_MP;
hint format ["Prune: requested delete of row %1", _id];
```
`fn_mapEditor.sqf` — in `AP_fnc_mapEdUnderCursor` replace `!((_o getVariable ["AP_mapKey", ""]) isEqualTo "")` with `(_o getVariable ["AP_mapId", -1]) >= 1`; in the Draw3D label replace `_k = AP_mapEd_sel getVariable ["AP_mapKey", "?"]` with `_k = format ["row %1", AP_mapEd_sel getVariable ["AP_mapId", "?"]]`.
`fn_mapEditorPanel.sqf` — in `AP_fnc_mapEditorPanelSync` replace `AP_mapEd_sel getVariable ["AP_mapKey", "?"]` with `format ["row %1", AP_mapEd_sel getVariable ["AP_mapId", "?"]]`.

```bash
grep -rn "AP_mapKey\|IsLive\|mapEdKeyOf" mission/Armapunk2035.Malden/core/admin/ || echo "clean"
```
Expected: `clean`.

- [ ] **Step 5: Brace gate, deploy, verify — the acceptance test of the whole plan**

```bash
python3 tools/sqf_balance.py mission/Armapunk2035.Malden/core/admin/*.sqf
bash /home/timb/arma3server_dev/reload-armapunk2035.sh
```
Two clients. On one: F12, select a prop, G, move it, LMB. Expected: it snaps back for a beat, then reappears at the new position **on both clients**, within a second, no restart. `SELECT id, x, y, rev FROM map_objects ORDER BY rev DESC LIMIT 1` shows the move. TAB → type coordinates → APPLY → same. DEL → gone on both. Restart dev, rejoin: every edit is still there (`delta loaded: <count> rows since rev N`).

- [ ] **Step 6: Commit**

```bash
cd ~/Armapunk2035 && git add -A mission/Armapunk2035.Malden && git commit -m "feat(map): editor by id -- every edit is a move or a del; baked/live split gone

Co-Authored-By: Microsoft Bob
Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Vcvr7nHWNbXPgmLXVsEgYj"
```

---

## Task 9: Oracle — keep the frame check, drop the key check

**Files:**
- Modify: `mission/Armapunk2035.Malden/edenOracle.sqf`, `tools/oracle_check.py`

- [ ] **Step 1: Remove the key from the probe**

In `edenOracle.sqf` delete the `_fnc_axis`, `_key`, `_fnc_parts` and `_parts` blocks, and emit `ROW~id~cls~pw~vd~vu~sp~sa~attrOk` (8 fields). Update the header comment: the probe now verifies frame agreement and orthonormality only; identity is an integer and needs no oracle.

- [ ] **Step 2: Remove check 1 from the checker**

In `oracle_check.py` delete the bake-key section of `check()` and `main()`, the `mapkey` import, and the `parts` parsing. Renumber the remaining sections 1 and 2.

- [ ] **Step 3: Verify**

```bash
cd ~/Armapunk2035/tools && python3 test_frame_oracle.py 2>&1 | tail -1 && python3 -c "import oracle_check" && python3 sqf_balance.py ../mission/Armapunk2035.Malden/edenOracle.sqf
```
Expected: `OK`, no import error, `ok`.

- [ ] **Step 4: Commit**

```bash
cd ~/Armapunk2035 && git add -A tools/oracle_check.py mission/Armapunk2035.Malden/edenOracle.sqf && git commit -m "refactor(map): oracle keeps the frame check; identity is an integer now

Co-Authored-By: Tamagotchi
Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Vcvr7nHWNbXPgmLXVsEgYj"
```

---

## Task 10: Pack-time regeneration

**Files:**
- Modify: `deploy/reload-armapunk2035.sh` (and its deployed copy at `/home/timb/arma3server_dev/reload-armapunk2035.sh` — diff them first; edit the repo copy; copy over)

- [ ] **Step 1: Confirm which copy is canonical**

```bash
diff <(sed 's/^\s*//' ~/Armapunk2035/deploy/reload-armapunk2035.sh) <(sed 's/^\s*//' /home/timb/arma3server_dev/reload-armapunk2035.sh) && echo IDENTICAL || echo DIFFER
```
If they differ, read both before editing; the repo copy is the one to change, then copy it over.

- [ ] **Step 2: Hook**

Immediately before the `pack_pbo.py` line for the mission (line ~29):

```bash
# Live map editor: the baked array is GENERATED from map_objects. Regenerate before packing so
# the PBO's AP_mapBakedRev matches the table and the join delta starts empty. A failure here
# must stop the pack -- a stale array with a stale rev would replay every edit to every joiner.
echo "[mad] regenerating fn_mapData.sqf from map_objects ..."
"$HOME/pysqf-venv/bin/python" "$SRC/tools/map_generate.py" --write || { echo "[mad] FATAL: map_generate failed"; exit 1; }
```

- [ ] **Step 3: Verify**

```bash
cp ~/Armapunk2035/deploy/reload-armapunk2035.sh /home/timb/arma3server_dev/reload-armapunk2035.sh
bash /home/timb/arma3server_dev/reload-armapunk2035.sh 2>&1 | grep -A1 "regenerating"
cd ~/Armapunk2035 && head -c 40 mission/Armapunk2035.Malden/core/config/fn_mapData.sqf && git status --short mission/Armapunk2035.Malden/core/config/fn_mapData.sqf
until grep -a "AP-MAPEDIT] delta loaded" /home/timb/arma3server_dev/loonydev.log | tail -1 | grep -q "0 rows"; do sleep 3; done; echo "delta empty after pack"
```
Expected: the generate line reports `baked_rev N -> M` with M ≥ N, the file header carries M, git shows it modified (the owner commits it with the next commit — the reload script never commits), and the server boots with `delta loaded: 0 rows since rev M`.

- [ ] **Step 4: Commit**

```bash
cd ~/Armapunk2035 && git add deploy/reload-armapunk2035.sh mission/Armapunk2035.Malden/core/config/fn_mapData.sqf && git commit -m "feat(map): regenerate the baked array from the table at pack time

Co-Authored-By: Ask Jeeves
Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Vcvr7nHWNbXPgmLXVsEgYj"
```

---

## Task 11: Eden by id (second authoring surface)

**Files:**
- Modify: `tools/map_codegen.py` (`read_mapdata`, `read_layer`, the `AP_stage.txt` writer in `stage()`, new `read_staged_ids()`)
- Rewrite: `tools/map_push.py`; Create: `tools/test_map_push.py`

**Interfaces:**
- Consumes: `mapdata_rows.read` (ids), `apdb_dsn.connect`.
- Produces: `map_push.diff(staged_ids, table, target) -> {"update": [(id, ent)], "insert": [ent], "delete": [id]}` (pure); `map_codegen.read_layer` entities carry `"ap_id": int|None`; `map_codegen.read_staged_ids() -> set[int]`.

- [ ] **Step 1: Write the failing tests**

```python
# tools/test_map_push.py
import unittest

import map_push


def ent(ap_id, cls="Land_A_F", x=1.0, init=""):
    return {"ap_id": ap_id, "cls": cls, "world": (x, 2.0, 3.0), "dir": (0.0, 1.0, 0.0), "up": (0.0, 0.0, 1.0), "init": init}


def tbl(cls="Land_A_F", x=1.0, init=""):
    return {"classname": cls, "x": x, "y": 2.0, "z": 3.0, "vdir": (0.0, 1.0, 0.0), "vup": (0.0, 0.0, 1.0), "init": init, "deleted": False}


class TestDiff(unittest.TestCase):
    def test_unchanged_produces_nothing(self):
        ops = map_push.diff({1}, {1: tbl()}, [ent(1)])
        self.assertEqual(ops, {"update": [], "insert": [], "delete": []})

    def test_moved_entity_is_an_update_by_id(self):
        ops = map_push.diff({1}, {1: tbl()}, [ent(1, x=5.0)])
        self.assertEqual([i for i, _ in ops["update"]], [1])

    def test_changed_init_is_an_update(self):
        ops = map_push.diff({1}, {1: tbl()}, [ent(1, init="call X")])
        self.assertEqual(len(ops["update"]), 1)

    def test_new_entity_without_id_is_an_insert(self):
        ops = map_push.diff({1}, {1: tbl()}, [ent(1), ent(None, cls="Land_New_F")])
        self.assertEqual([r["cls"] for r in ops["insert"]], ["Land_New_F"])

    def test_staged_id_now_absent_is_a_delete(self):
        ops = map_push.diff({1, 2}, {1: tbl(), 2: tbl()}, [ent(1)])
        self.assertEqual(ops["delete"], [2])

    def test_unstaged_id_absent_is_NOT_a_delete(self):
        # id 2 exists in the table but was never staged into this edit mission
        ops = map_push.diff({1}, {1: tbl(), 2: tbl()}, [ent(1)])
        self.assertEqual(ops["delete"], [])

    def test_position_within_a_millimetre_is_not_a_change(self):
        ops = map_push.diff({1}, {1: tbl()}, [ent(1, x=1.0004)])
        self.assertEqual(ops["update"], [])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd ~/Armapunk2035/tools && python3 test_map_push.py -v`
Expected: FAIL — `map_push` still imports the deleted `mapkey`: `ModuleNotFoundError: No module named 'mapkey'`.

- [ ] **Step 3: Carry the id through Eden**

In `map_codegen.py`:

`read_mapdata()` — use `mapdata_rows` and add the id token:
```python
def read_mapdata():
    """fn_mapData rows as entity dicts. Positions are world-frame."""
    import mapdata_rows
    ents = []
    for r in mapdata_rows.read(MAPDATA).rows:
        toks = []
        if r.id is not None:
            toks.append("AP_ID=%d" % r.id)
        if is_person(r.cls):
            toks.append("AP_NPC=" + r.cls)
        if r.is_server:
            toks.append("AP_SERVERSIDE")
        ents.append({"cls": r.cls, "world": r.pos, "dir": r.vdir, "up": r.vup,
                     "init": r.init, "desc": "|".join(toks), "ap_id": r.id})
    return ents
```

`read_layer()` — after `desc = attrs.get("description", "")` add:
```python
            ap_id = next((int(x[len("AP_ID="):]) for x in _tokens(desc) if x.startswith("AP_ID=")), None)
```
and include `"ap_id": ap_id` in the appended dict.

`stage()` — where `AP_stage.txt` is written (grep `rows=` in `map_codegen.py`), add a line `ids=` followed by the comma-joined `ap_id` of every staged mapdata entity. Add:
```python
def read_staged_ids():
    """The ids staged into the current edit mission, from AP_stage.txt. Empty set if none."""
    p = os.path.join(EDIT_DIR, "AP_stage.txt")
    try:
        for line in open(p, encoding="utf-8"):
            if line.startswith("ids="):
                v = line[4:].strip()
                return {int(t) for t in v.split(",") if t}
    except OSError:
        pass
    return set()
```

- [ ] **Step 4: Rewrite `map_push.py`**

```python
#!/usr/bin/env python3
"""map_push -- Eden edits into map_objects, by id.

Second authoring surface. The in-game editor is the first; both write the same table
and the running server broadcasts either within seconds.

Every entity staged into MaldenEdit carries AP_ID=<id> in its description (the field
3DEN preserves verbatim). The diff is therefore EXACT:
    staged id, transform or init changed  -> UPDATE
    entity with no AP_ID                  -> INSERT (a new placement)
    id that was staged and is now absent  -> soft DELETE
An id that was never staged into this edit mission is never touched.

This tool runs on the box with database access and is a TRUSTED writer: it may write
init. The in-game path may not.
"""
import argparse
import os
import sys

import apdb_dsn
import map_codegen

EPS = 0.0005   # a millimetre; the file stores three decimals


def _close(a, b):
    return all(abs(x - y) < EPS for x, y in zip(a, b))


def diff(staged_ids, table, target):
    ops = {"update": [], "insert": [], "delete": []}
    seen = set()
    for e in target:
        rid = e.get("ap_id")
        if rid is None:
            ops["insert"].append(e)
            continue
        seen.add(rid)
        t = table.get(rid)
        if t is None or t["deleted"]:
            ops["insert"].append(e)   # purged or deleted under it; re-create
            continue
        if (e["cls"] != t["classname"] or e.get("init", "") != t["init"]
                or not _close(e["world"], (t["x"], t["y"], t["z"]))
                or not _close(e["dir"], t["vdir"]) or not _close(e["up"], t["vup"])):
            ops["update"].append((rid, e))
    for rid in sorted(staged_ids - seen):
        if rid in table and not table[rid]["deleted"]:
            ops["delete"].append(rid)
    return ops


def read_table(conn, world):
    with conn.cursor() as cur:
        cur.execute("SELECT id, classname, x, y, z, vdir_x, vdir_y, vdir_z, vup_x, vup_y, vup_z, init, deleted"
                    " FROM map_objects WHERE world = %s", (world,))
        return {i: {"classname": c, "x": float(x), "y": float(y), "z": float(z),
                    "vdir": (float(dx), float(dy), float(dz)), "vup": (float(ux), float(uy), float(uz)),
                    "init": init, "deleted": bool(d)}
                for (i, c, x, y, z, dx, dy, dz, ux, uy, uz, init, d) in cur.fetchall()}


def apply_ops(conn, world, ops, author):
    with conn.cursor() as cur:
        for rid, e in ops["update"]:
            cur.execute("UPDATE map_objects SET classname=%s, x=%s, y=%s, z=%s, vdir_x=%s, vdir_y=%s, vdir_z=%s,"
                        " vup_x=%s, vup_y=%s, vup_z=%s, init=%s, author_uid=%s WHERE id=%s AND world=%s",
                        (e["cls"], *e["world"], *e["dir"], *e["up"], e.get("init", ""), author, rid, world))
        for e in ops["insert"]:
            cur.execute("INSERT INTO map_objects (world, classname, x, y, z, vdir_x, vdir_y, vdir_z, vup_x, vup_y, vup_z, init, author_uid)"
                        " VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)",
                        (world, e["cls"], *e["world"], *e["dir"], *e["up"], e.get("init", ""), author))
        for rid in ops["delete"]:
            cur.execute("UPDATE map_objects SET deleted=true, author_uid=%s WHERE id=%s AND world=%s", (author, rid, world))
    conn.commit()


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--world", default="Malden")
    ap.add_argument("--author", default="map_push")
    args = ap.parse_args(argv)

    edit_sqm = os.path.join(map_codegen.EDIT_DIR, "mission.sqm")
    if not os.path.exists(edit_sqm):
        sys.exit("no edit mission at %s -- stage it first with tools/edit-map.sh" % edit_sqm)
    target = map_codegen.read_layer(edit_sqm, map_codegen.LAYER_MAPDATA)
    staged = map_codegen.read_staged_ids()

    conn = apdb_dsn.connect()
    try:
        ops = diff(staged, read_table(conn, args.world), target)
        print("diff: %d update, %d insert, %d delete" % (len(ops["update"]), len(ops["insert"]), len(ops["delete"])))
        if args.dry_run:
            return 0
        apply_ops(conn, args.world, ops, args.author)
        print("pushed. the server picks it up on its next poll (<=10s).")
    finally:
        conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 5: Run the tests**

Run: `cd ~/Armapunk2035/tools && python3 test_map_push.py -v && python3 test_map_codegen.py 2>&1 | tail -1`
Expected: `Ran 7 tests` / `OK`, `0 failure(s)`.

- [ ] **Step 6: End to end**

```bash
cd ~/Armapunk2035 && tools/edit-map.sh stage
~/pysqf-venv/bin/python tools/map_push.py --dry-run
```
Expected on a freshly staged mission: `diff: 0 update, 0 insert, 0 delete`. Then open `MaldenEdit.Malden` in 3DEN, run `edenDraw.sqf`, drag one prop, Ctrl+S, and re-run without `--dry-run`: `1 update`, and within ~15 s the prop has moved on a connected client with no restart.

- [ ] **Step 7: Commit**

```bash
cd ~/Armapunk2035 && git add -A tools/ && git commit -m "feat(map): Eden pushes by id -- exact updates, inserts and deletes

Co-Authored-By: Deep Blue
Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Vcvr7nHWNbXPgmLXVsEgYj"
```

---

## Execution status — 2026-09-01

All eleven tasks executed inline, in order, committed to `main`. Every gate that does not need a
player is green; the in-game gates are listed below and await one.

**Verified by execution:**

| What | Evidence |
| --- | --- |
| Schema + trigger | applied twice to `pgm_full_scratch`; probe writes stamped `rev` correctly |
| Reader/writer | real-file round trip byte-identical, 9384 rows |
| Migration | 9384 rows imported, ids 1…9384 in order; file body minus spliced tails byte-identical to the original |
| Server by id | `delta loaded: 0 rows since rev 9390`; out-of-band INSERT → `rev=9391 applied: 1 row(s)` |
| PySQF value shapes | OBSERVED via the RAWROW probe: numbers as numbers, strings as strings, booleans as `0`/`1` |
| Pack-time regeneration | `baked_rev 9390 → 9391`, 1 row appended, b0812 boots with an empty delta |
| Eden by id | staged 9385 ids; 9385 `AP_ID=` tokens in the `.sqm`; dry-run push `0/0/0` |
| Python suites | `test_mapdata_rows`, `test_map_import`, `test_map_generate`, `test_map_push`, `test_map_codegen`, `test_frame_oracle` all green |

**Found during execution, fixed in the plan and the code:**

1. `pgrep -f pysqfd.py` matched the root-owned supervise-daemon parent, then the shell running the command itself. Anchored to the interpreter path.
2. An empty table is not a fresh sequence: Task 1's probe rows advanced the serial and the importer refused with ids 3…9386 — the guard worked, nothing was written. The importer now restarts the sequence after confirming the table is empty.
3. `map_meta.rev` after import is 9384 plus every probe write, not 9384. Plan expectations generalised to N.
4. `oracle_check.py` also imported `mapkey`; the plan's stale-import expectation named only `map_push`.
5. The trimmed oracle probe moved `attrOk` from field 8 to 7; the checker's parser had to follow.

**Headless-client self-test (added after the plan, `AP_fnc_mapSelfTest` via the `mapselftest` verb), b0817:**

| Gate | Result |
| --- | --- |
| Pre-flight | `rows=9386 rowsWithoutId=0 dup0v9384=false` — the array is NOT doubled; the 18768 reading was an artefact |
| Task 6 Step 6 (applier) | `upsert → created=true` at the exact position, `del → removed=1` |
| Task 7 join replay | `replayed 1 rows to owner 4` → `apply upsert id=9390` on the client |
| Task 7 init preserved on move | `UPDATE x` on NPC anchor 1 → poll → client applied → `init` unchanged |
| Task 7 authority gate | headless caller refused and logged (engine gives it `remoteExecutedOwner` = 0 by design) |

Two things this surfaced and fixed: the mission had never had a `HeadlessClient_F` slot (spliced, `maxPlayers` 60→61), and the join request must be `[false, player]` — the unit in the boolean slot silently defaults away.

**Owner in-game, b0820 (2026-09-01 19:03):** editor on Splendid Camera — select, grab, move, panel, delete all working. Evidence: `map_edit_log` `move 5331` / `del 5341`; the owner's RPT applied each within ~1 s of the request (`apply upsert id=5331 created=true`, `apply del id=5341 removed=1`); the poll then logged `applied: 0 row(s)` for both revs, proving the immediate path and no double broadcast. Panel warnings: none.

Along the way: the hand-rolled freecam was replaced by Splendid Camera (`BIS_fnc_camera`), whose display is #314 and whose bindings forced the editor keys to Enter/G/X/Up/Down/C/Del/Tab/Ctrl+Z; CT_LISTBOX wants `class ListScrollBar`, not `ScrollBar`.

**Restart-survives, b0821 (owner rejoined, 19:08):** the pack folded the edits in (`changed: 1, dropped: 1, purged: 1`, header `AP_mapBakedRev = 9406`), b0821 booted with an empty delta, and the owner saw the moved slab where he left it and the deleted one gone.

**`map_watch --push` wired (19:10):** fires on save, runs `map_push.py`, surfaces its output. Its first firing pushed a STALE staging (made before the owner's in-game edits) and re-created his deleted slab and the purged container — the owner had disconnected 19 s earlier and never saw it. Repaired by hand; the staleness guard the spec had demoted to a warning is now a refusal keyed on `staged_from_rev` (the file's baked rev at staging) vs the table's `rev`, proven on this incident from both sides. Sequence is pack → stage → edit → push.

**Still unobserved.** A level-0 player seeing `REFUSED (level 0)` (needs a second account) · Task 11 Step 6's 3DEN half after a fresh pack+stage (expect `0/0/0`, or a handful of paving-slab updates from Eden's own Z re-write — the 9 drift rows measured 2026-08-31 — in which case widen `EPS` to the measured 0.05 m). Deployed build: **b0821**.

---

## Self-Review

**Spec coverage.** §1 data model → Task 1. §2 generated file → Tasks 2, 4, 10. §3 runtime → Tasks 6, 7. §4 security → Task 7 Step 5 (no `init` column in `add`; `move` touches transform columns only; `is_server` excluded by WHERE) and Task 8. §5 migration → Tasks 3, 5. §6 Eden → Task 11. §7 deletions → Tasks 5, 6, 9. §8 testing → each task's red-state and verify steps; the init-preservation test is Task 7 Step 7. §9 build order → task order. Pre-flight covers the open item.

**Executed while writing this plan:** the Task 1 schema + trigger (scratch DB, idempotent, revs stamp as expected: 2 inserts + 2 updates → rows at 3 and 4, meta at 4, `rev > 2` returns exactly 2); `mapdata_migrate.parse_rows` against a header line and 7-element rows (parses; `tail` = `,[],1`). The Task 2 reader is built on that parser and its gap recovery is the same technique that produced a byte-identical round trip on 2026-08-31.

**Unverified — the implementer must confirm:**

- Every SQF file here is unrun. The riskiest line is `APS_fnc_mapRowOp`'s coercion of PySQF's returned types; Task 7 Step 7 logs one raw row on the first deploy precisely so that shape is observed, not assumed.
- `RETURNING id` in Task 3 runs through psycopg directly, not through `DB_fnc_asyncQuery`, so it is native PostgreSQL and fine. The SQF side deliberately reads the id back with a second query.
- `map_codegen.stage()`'s `AP_stage.txt` writer — Task 11 Step 3 names the addition but not its exact line; read the function before editing.
- The `deleteAt` on a zone list while `dynamicMap_fnc_loadArea` may be iterating it (Task 6) is a documented, bounded race, not a fix.

**Lifecycle owners.** The streamer (`fn_dynamicMapSystem`) creates and deletes objects on zone load/unload; the applier creates and deletes by id. Both push to and remove from the same `activeObjects` arrays and both tag `AP_mapId`, so neither can orphan the other's objects. The generator is the only deleter of table rows (purge); the authority only soft-deletes.

**Artefact paths.** Plan and spec at repo root per convention (`docs/` is gitignored). `~/.pysqf_dsn` is outside the repo by design.
