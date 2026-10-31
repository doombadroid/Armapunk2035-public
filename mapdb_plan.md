# DB-driven map init — zero map data in the client PBO

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> At execution time copy this file to `~/Armapunk2035/mapdb_plan.md` and the Design section to
> `~/Armapunk2035/mapdb.md` (repo convention: root-level design + plan docs; `docs/` is gitignored).
>
> **Artifact:** the visual plan page is written at
> `/tmp/claude-1000/-home-timb/a21f33ac-00d4-4d9a-b326-6f67951c48bb/scratchpad/malden-grid-init.html`
> ("Malden Grid Init": grid heatmap from the real cell histogram, join ladder, tasks with proofs).
> Publishing is refused while plan mode is active in this session, so publishing it is the FIRST
> action after approval, before Task 0.

**Goal:** the mission PBO ships no placement data at all; every placed object, custom model and
composition-derived row is initialised at runtime from Postgres `map_objects`, with a per-object
detail tier (LOD) and a per-object stream-in radius (render distance) stored in the table.

**Architecture:** the server loads the whole table into memory at boot, bins rows into 1 km grid
cells plus a "far" bucket, and hands each cell to clients on demand as one engine-deflated blob.
Clients keep a per-object streamer (create within `stream_r`, delete beyond `stream_r + hysteresis`,
skip rows above the chosen detail tier). Live edits keep the existing broadcast path; the join
delta and `AP_mapBakedRev` disappear because there is no baked copy to be behind.

**Tech stack:** SQF (mission + `AP_server` addon), PySQF → Postgres (`pgm_full_scratch` on dev),
Python 3 tools under `tools/`, `deploy/pack_pbo.py`, headless-client self-test via `bot_commands`.

## Global constraints (from repo rules — part of the problem statement)

- Work on `main` directly (owner 2026-08-21); `git fetch`/pull before starting.
- Commit trailer: `Co-Authored-By: <funny defunct AI>` (name only, rotate; never the Claude trailer).
- Never name other Arma servers in tracked files. Never credit Infamous.
- `mission.sqm` is SHIPPED text; never save it from 3DEN. Markers stay in the map layer.
- Every new client fn → `Functions.h`; every server fn → `server/AP_server/config.cpp` (in the
  `\AP_server\core\TON` block); every cross-machine fn → `CfgRE.hpp` (mode 1 whitelist,
  `allowedTargets`: 1 = server→clients only, 2 = clients→server only).
- Call remote fns through `AP_fnc_MP`. `remoteExec`'d FUNCTIONS run in the scheduled environment
  (BIKI) — they can interleave with any other scheduled script.
- Dev DB is `pgm_full_scratch`. DSN: `~/.pysqf_dsn` (tools) / daemon env. Never touch live `.96`.
- SQF numbers are float32; `str`/`format` print SIX significant figures — never serialise a
  coordinate through them; use `toFixed`.
- Before every deploy: `tools/run_checks.sh` (brace balance etc.) must be green.
- Deploy to dev ONLY with `bash /home/timb/arma3server_dev/reload-armapunk2035.sh`.

---

## Context

Today three separate file-based placement systems ship inside the 75 MB mission PBO, and a fourth
(the designer's `mission.sqm`) stays by owner decision:

| system | data file | rows | spawned by | machine |
|---|---|---|---|---|
| mapData | `core/config/fn_mapData.sqf` (1.11 MB, `AP_mapBakedRev=10718`) | 9,384 (11 `is_server`) | `AP_fnc_dynamicMapSystem` → `AP_fnc_createVehicleLocal` | each client, 19 hand-placed zone circles; server spawns the 11 |
| custom p3d | `custom_p3ds/malden_buildings.sqf` (+ dead `load.sqf`) | 85 `createSimpleObject` lines, 12 models | execVM from `initServer.sqf:336` + `initPlayerLocal.sqf:442` | server AND every client, always on |
| compositions | `compositions/zones.sqf` → `zone_example.sqf` | 0 live (example disabled) | `AP_fnc_compZones` | dead code |
| designer layer | `mission.sqm` (2.45 MB text) | 4,464 Objects, 303 Markers, 245 Logic | engine | stays (owner: keep) |

`fn_mapData.sqf` is already GENERATED from `map_objects` at pack (`tools/map_generate.py`), and the
live editor already streams edits by id (`APS_fnc_mapEditSRV` → `AP_fnc_mapEditApply`). What still
forces a repack and a 75 MB re-download per map change is the baked copy itself, and the only
"LOD" in the runtime is a random 80 % cull of a 200-class decor list, different every session.

Measured facts the design rests on (2026-09-04):

- 9,384 rows, avg 122 bytes as SQF text; whole table deflates 5.7× (1.15 MB → 204 KB).
- 1 km cells: 44 non-empty; largest = 1,549 rows = 191 KB raw / 31 KB deflated; median 64 rows.
- Web-serve precedent: engine `Deflate`/`Inflate` on `controlNull` works on server and client;
  Inflate output capped at 1 MB; 121 KB deflated ≈ 3 s on loopback (Arma paces guaranteed msgs).
- Current join replay: 1 remoteExec per row, `uiSleep 0.01` → ~94 s for the whole table. That loop
  is the bottleneck, not PySQF (result chunking 8 KB, ~400 KB proven daily by web-serve).
- `DB_fnc_asyncQuery` is a global server mutex (`DB_Async_Active`): clients must never trigger a
  DB read; the server serves from memory.
- Engine has NO per-object LOD command; `setFeatureType` (cap 500) is the only per-object
  visibility primitive and the owner did not ask for it. "LOD" = detail tier, "render distance"
  = stream-in radius (owner decisions below).

### Owner decisions (2026-09-04, AskUserQuestion)

1. Scope: mapData rows + custom p3d placements + compositions move to the table. `mission.sqm`
   keeps its designer objects, markers, logic, slots. Models/textures stay in the PBO.
2. LOD = **detail tier** `lod` 0–3 per row, client picks max tier; replaces the random cull.
3. Render distance = **stream-in radius** `stream_r` per row (NULL = default, 0 = always).
4. Transport = **grid cells on demand** (1 km cells + far bucket, deflated once per rev).
5. Keep a committed snapshot of the table OUTSIDE the mission (`deploy/map_snapshot/`).
6. Default detail = tier 2 (spawn everything the designers placed as decor).
7. `Skyscraper20_r14.p3d` is unplaced: **drop the model and its door scripts** from the PBO.
8. In-game editor controls for tier/radius: later. This pass writes them via migration, SQL and
   Eden push tokens only.

---

## Design

### D1. Data model (`deploy/map_objects_v3.sql`, idempotent)

```sql
ALTER TABLE map_objects ALTER COLUMN classname SET DEFAULT '';
ALTER TABLE map_objects ADD COLUMN IF NOT EXISTS model     text     NOT NULL DEFAULT '';  -- mission-relative .p3d ('custom_p3ds\Bank.p3d'); '' = classname row
ALTER TABLE map_objects ADD COLUMN IF NOT EXISTS scale     real     NOT NULL DEFAULT 1;   -- setObjectScale, applied AFTER orientation
ALTER TABLE map_objects ADD COLUMN IF NOT EXISTS lod       smallint NOT NULL DEFAULT 1;   -- 0 always, 1 normal, 2 decor, 3 never-by-default
ALTER TABLE map_objects ADD COLUMN IF NOT EXISTS stream_r  real     NULL;                 -- metres; NULL = default (1500), 0 = always loaded
ALTER TABLE map_objects ADD COLUMN IF NOT EXISTS on_server boolean  NOT NULL DEFAULT false; -- ALSO spawn a LOCAL copy on the dedicated server (custom buildings: collision for AI/vehicles)
DO $$ BEGIN
  ALTER TABLE map_objects ADD CONSTRAINT map_objects_ident_ck  CHECK (classname <> '' OR model <> '');
  ALTER TABLE map_objects ADD CONSTRAINT map_objects_lod_ck    CHECK (lod BETWEEN 0 AND 3);
  ALTER TABLE map_objects ADD CONSTRAINT map_objects_stream_ck CHECK (stream_r IS NULL OR stream_r >= 0);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
CREATE INDEX IF NOT EXISTS map_objects_world_live ON map_objects (world, id) WHERE NOT deleted;
```

`is_server` keeps its meaning (server-GLOBAL `createVehicle`, never on clients). `on_server` is
new: a client-style local object on the server too (today's custom-p3d behaviour). Soft deletes
stay; the pack-time purge is replaced by a boot purge of tombstones older than 7 days.

### D2. Wire row (12 elements; indices 0–6 unchanged so every existing reader still works)

```
[class, [x,y,z] world frame, [[vdir],[vup]], init, isServer, loadout, id,
 model, scale, lod, streamR (-1 = default), onServer]
```

Row text is produced by ONE function, `AP_fnc_mapRowText`, with `toFixed` (3 decimals for
positions, 4 for vectors) — `str`/`format` print six significant figures and would round
`7216.602` to `7216.6`. Strings/booleans/loadout go through `str` (which escapes `"` as `""`);
`parseSimpleArray` reverses it exactly (BIKI: numbers, strings, booleans, nested arrays).

### D3. Cells (`AP_fnc_mapCfg`, `AP_fnc_mapCellFor`, `AP_fnc_mapCellsNear` — mission-side, ONE definition used by server, clients, HC)

| constant | value | why |
|---|---|---|
| `cell` | 1000 m | 44 non-empty cells on Malden; largest blob 31 KB deflated |
| `far` | 2000 m | rows with `stream_r > far` or `= 0` live in the "far" bucket sent at join |
| `defaultR` | 1500 m | matches today's zone IN threshold (r 500 + 1000) |
| `hyst` | 250 m | delete only beyond `stream_r + hyst` (today: +250) |
| `fetchR` | 2000 m | cells whose square is within this of the focus are fetched (≥ defaultR + hyst) |
| `poll` | 2 s | streamer tick (unchanged) |
| `retry` | 15 s | re-request a cell that never answered |
| `createBatch` | 20 | creates per `uiSleep` (today: 1 per frame → a 1,500-row zone took ~25 s) |

Cell key = `"<floor(x/1000)>_<floor(y/1000)>"`, or `"far"`. A row's cell is a pure function of
`(x, y, stream_r)` so the server index, the client index and the editor cannot disagree.

### D4. Server (`server/AP_server/core/TON/`)

- `APS_fnc_mapLoad` (boot, replaces `mapEditLoad [true]`): reads `map_meta.rev` FIRST, then pages
  `SELECT … WHERE world=? AND NOT deleted AND id > ? ORDER BY id LIMIT 1000` (1,000 rows ≈ 200 KB ≈
  25 PySQF chunks — inside the envelope web-serve exercises daily). Builds `APS_mapRows` (id →
  wire row), `APS_mapText` (id → row text), `APS_mapCells` (key → [ids]), `APS_mapBlobs` (key →
  [rev, packed, n]) lazily. Purges tombstones > 7 days. Sets the compatibility array
  `allLocalMapEntities = values APS_mapRows` (four server fns read it by class:
  `fn_loonyBinSRV`, `fn_maldenJewelSRV`, `fn_cyberdeckSRV`, `fn_mapBake`), publishes
  `AP_exchangeSpots` (was derived client-side from the baked array), then after `uiSleep 3`
  spawns `is_server` rows (global) and `on_server` rows (local) through `AP_fnc_createVehicleLocal`,
  tracking them in `APS_mapLive`. Finally `APS_mapReady = true; AP_mapFarDone = true`.
- `APS_fnc_mapBlob [key]` → `[rev, packed, n]`: joins the cell's row texts, `Deflate`, caches.
  Permanent self-check: `parseSimpleArray (Inflate packed) isEqualTo rows` — logs
  `[AP-MAP] ROUNDTRIP FAIL` and refuses the blob on mismatch. Raw > 600 KB warns, > 900 KB refuses
  (engine Inflate cap 1 MB; measured max 191 KB).
- `APS_fnc_mapFetch [kind, keys, unit]` (CfgRE `allowedTargets = 2`): requester =
  `remoteExecutedOwner`, headless fallback via the named unit exactly as `mapEditLoad` did; waits
  for `APS_mapReady`; validates keys (`regexMatch "-?\d+_-?\d+"`, ≤ 64); rate limit 6 requests /
  10 s per owner; kinds `far`, `cells`, `index` (self-test: every non-empty key + row count +
  rev). Replies go to the requester only: `AP_fnc_mapCellRecv [key, rev, packed, n]` and
  `AP_fnc_mapIndexRecv [keys, count, rev]`, both `allowedTargets = 1` — rows carry `init`
  CODE that clients compile, so no client may ever push a blob at another.
- `APS_fnc_mapRowUpdate [triple, broadcast]`: the single mutator of the in-memory maps. Removes
  the old row from its cell, stores the new one, invalidates both blobs, re-spawns the server's
  own copy if `is_server`/`on_server`, and (when `broadcast`) sends
  `[op, payload, rev]` → `AP_fnc_mapEditApply` to target 0.
- `APS_fnc_mapEditPoll`: unchanged shape (poll one integer every 10 s) but on change reads only
  `rev > APS_mapRev` (deleted included) and pushes each through `mapRowUpdate`.
- `APS_fnc_mapEditEmit`: reads the row by id → `mapRowUpdate` (broadcast). `APS_fnc_mapEditSRV`
  and `APS_fnc_mapEditAudit` unchanged. `fn_mapEditLoad.sqf` and `fn_mapEditLoadOps.sqf` deleted.

### D5. Client (`core/functions/`)

- `AP_fnc_mapStream` = `mapStreamInit` + `while {true} do { uiSleep poll; call AP_fnc_mapTick }`.
  Started from `core/init.sqf` where the baked array used to be bound.
- `AP_fnc_mapStreamInit`: creates `AP_mapRows`, `AP_mapCellRows`, `AP_mapCells` (key →
  `wanted|loaded`), `AP_mapCellAsked`, `AP_mapCellRev`, `AP_mapPending`, `AP_mapLive` (id → obj),
  `AP_mapDirty` (ids to recreate), reads `AP_mapDetail` from the settings slot, requests `far`.
- `AP_fnc_mapTick` — the ONLY code that creates or deletes map objects on a client:
  1. focus = `AP_mapFocus` override (self-test) or the old loop's logic (respawn suppression
     within 600 m of `respawn_civilian`, `suspectESP_suspectObj`, `AP_ses_last_pos`);
  2. missing cells within `fetchR` → one `APS_fnc_mapFetch ["cells", keys, player]`;
  3. dirty ids → delete live object;
  4. delete pass over every live object: gone from rows, tier above `AP_mapDetail`, or beyond
     `stream_r + hyst` from focus (held while within that of `AP_dynamicMap_lastVehicle`);
  5. create pass over `far` + in-range cells: not live, tier ok, `stream_r = 0` or within
     `stream_r`; sorted nearest-first; `createBatch` creates per `uiSleep`;
  6. after the first pass that follows the far blob: `AP_mapFarDone = true`.
- `AP_fnc_mapCellRecv`: `Inflate` → `parseSimpleArray` → rows into the maps, cell `loaded` with
  its rev, then replays `AP_mapPending[key]` ops with `rev > blob rev` (the fetch/edit race).
  A cell is fetched once per session; inflate failure resets it to unrequested for a retry.
- `AP_fnc_mapEditApply [op, payload, rev]` (rev appended so old callers still work): mutates the
  row maps and marks the id dirty; NEVER creates objects itself (it runs scheduled and would
  interleave with the tick). Ops for a cell that is `wanted` are buffered; for an unrequested
  cell they are dropped (the future fetch already contains the row).
- `AP_fnc_mapEditRemoveId [id]` reimplemented over the hashmaps; `AP_fnc_mapWaitLoaded
  [pos, timeout]` for `fn_initCiv.sqf:77-79` (waits until the cell holding `pos` is loaded and one
  tick has run).
- `AP_fnc_createVehicleLocal` gains params 6–11; model rows use the proven custom-p3d recipe
  (final position passed to `createSimpleObject`, orientation, THEN `setObjectScale`); class rows
  unchanged plus scale after `setPosWorld`; on the dedicated server `is_server` → global,
  `on_server` → local simple.
- Door sweep (`custom_p3ds/door_sweep.sqf`): the model sweep block from `malden_buildings.sqf`
  with the Skyscraper20 entry removed, gated on `AP_mapFarDone`, execVM'd on server and clients.

### D6. Security (what must not drift)

- Fetch is read-only; requester from `remoteExecutedOwner`; reply to requester only.
- `AP_fnc_mapCellRecv` / `AP_fnc_mapIndexRecv` / `AP_fnc_mapEditApply` are `allowedTargets = 1`.
- `init` stays trusted-writer-only (`APS_fnc_mapEditSRV` never writes it) — unchanged.
- Rate limits: fetch 6 / 10 s per owner, ≤ 64 keys; edits 60 / 60 s (unchanged).

### D7. Tools and PBO

- `tools/map_generate.py` → writes `deploy/map_snapshot/map_objects.sqf` (12-element rows,
  header `AP_mapSnapshotRev = N;`), no purge. Committed on every deploy (git keeps map history).
- `tools/map_codegen.py stage` reads rows from the DB (`read_mapdata_db`, `read_p3d_db`) and
  stamps `AP_ID=` into the `AP_CUSTOM_P3D` anchors too; `staged_from_rev = map_meta.rev`.
  `apply` is retired (it wrote the deleted files). `tools/map_push.py` diffs BOTH layers by id;
  model rows update transform + scale, new anchors INSERT with `model`, `on_server = true`,
  `stream_r = 0`, `lod = 0`; description tokens `AP_LOD=` / `AP_R=` set the new columns.
- `tools/map_watch.py` becomes push-only (a saved MaldenEdit reaches the game via the 10 s poll;
  no deploy). `.map_watch_deployed` retired.
- `tools/fab_check.py`, `tools/test_mapdata_rows.py`, `tools/test_frame_oracle.py`,
  `tools/make_compositions.py` read the snapshot / DB instead of `fn_mapData.sqf`.
- `deploy/pack_pbo.py` gains `--exclude-list=<file>` (relative paths, exact, case-insensitive);
  `deploy/pbo_exclude.txt` lists the dev payload (`mapImportAll_data.sqf` 0.94 MB, `mapImportAll.sqf`,
  `mapExportAll.sqf`, `edenDraw.sqf`, `mapBaseline_ids.sqf`). `debug/` stays (five boot execVMs).
- `tools/map_pbo_gate.py` in `run_checks.sh`: the forbidden files do not exist in `mission/` and
  every path in `pbo_exclude.txt` is in the exclude list the reload script passes.
- Deleted from the mission: `core/config/fn_mapData.sqf` (+`.bak`), `core/config/fn_dynamicMapCfg.sqf`,
  `core/functions/fn_dynamicMapSystem.sqf`, `fn_mapZoneFor.sqf`, `fn_compZones.sqf`,
  `custom_p3ds/load.sqf`, `custom_p3ds/malden_buildings.sqf`, `custom_p3ds/Skyscraper20_r14.p3d`,
  `custom_p3ds/skyscraper_doors.sqf`, `custom_p3ds/skyscraper_doors_data.sqf`, the 20F leaf p3ds
  if nothing else references them, `compositions/zones.sqf`, `compositions/zone_example.sqf`.
  **`compositions/cryptorig.sqf` STAYS** — `fn_miningSRV.sqf:48` reads it (mining rig, not map).

### D8. Migration (`tools/map_migrate_v3.py`, dry-run by default)

1. Apply `deploy/map_objects_v3.sql`.
2. Parse `custom_p3ds/malden_buildings.sqf` placement lines (85; assert the count equals the
   number of non-comment lines containing `createSimpleObject`); INSERT rows: `classname ''`,
   `model 'custom_p3ds\<Name>.p3d'`, position as written, `vdir = [sin dir, cos dir, 0]`,
   `vup = [0,0,1]`, `scale`, `lod 0`, `stream_r 0`, `on_server true`, `layer 'AP_CUSTOM_P3D'`,
   `author_uid 'migration'`. Refuses if any `AP_CUSTOM_P3D` row exists (idempotence).
3. Extract `_decorObjects` / `_shitObjects` from `fn_dynamicMapSystem.sqf` (assert 200 / 85
   entries): `lod = 3` for classes in both lists (today: never spawned), `lod = 2` for the rest
   of the decor list (today: random 20 %).
4. `stream_r = 0` for rows the old rule made static: `init LIKE '%_isStatic = true%'`, and rows
   within 110 m of marker `jail_marker_loonybin` (position read from `mission.sqm` with
   `tools/sqm_read.py`; assert the marker exists).
5. Print counts; `--write` commits in one transaction. Expected after write: 9,384 + 85 rows,
   `model <> ''` = 85, `lod = 3` ≈ rows of the 85 overlap classes, `lod = 2` the rest of decor.

### D9. Join sequence (what a client experiences)

```
client init.sqf            server
  mapStreamInit ── far ──▶ mapFetch: blob("far") = custom p3ds + static rows   (~85+ rows, <10 KB)
  ◀── mapCellRecv("far") ── AP_mapReady
  tick #1: cells within 2 km of spawn ── ["cells", ~9-15 keys] ──▶ one blob per key (30 KB max each)
  ◀── mapCellRecv × N ── objects created nearest-first, 20 per frame
  door_sweep waits AP_mapFarDone → wires lux tower doors on this machine
  every 2 s: new cells as the player travels; edits arrive as [op,payload,rev] → dirty → next tick
```

Budget (loopback, HC): far ≤ 2 s, first cells ≤ 10 s. Measured by the `[AP-MAP] join:` log line.

---

## File map

Create — mission `core/functions/`: `fn_mapCfg.sqf`, `fn_mapCellFor.sqf`, `fn_mapCellsNear.sqf`,
`fn_mapRowText.sqf`, `fn_mapStream.sqf`, `fn_mapStreamInit.sqf`, `fn_mapTick.sqf`,
`fn_mapFocus.sqf`, `fn_mapCellRecv.sqf`, `fn_mapIndexRecv.sqf`, `fn_mapWaitLoaded.sqf`;
`custom_p3ds/door_sweep.sqf`. Server `core/TON/`: `fn_mapLoad.sqf`, `fn_mapBlob.sqf`,
`fn_mapFetch.sqf`, `fn_mapRowUpdate.sqf`. Tools: `deploy/map_objects_v3.sql`,
`tools/map_migrate_v3.py`, `tools/test_map_migrate_v3.py`, `tools/map_pbo_gate.py`,
`deploy/pbo_exclude.txt`, `deploy/map_snapshot/map_objects.sqf` (generated).

Modify: `fn_createVehicleLocal.sqf`, `fn_mapEditApply.sqf`, `fn_mapEditRemoveId.sqf`,
`fn_mapSelfTest.sqf`, `fn_dynamicMapVehicleFix.sqf`, `core/fn_initCiv.sqf:77-79`,
`core/init.sqf:73-95`, `initServer.sqf` (264-266, 336-338, 376), `initPlayerLocal.sqf` (442-443,
472), `Functions.h`, `CfgRE.hpp`, `core/web/fn_deckSettings.sqf`, `core/web/fn_deckSettingsSet.sqf`,
`core/configuration.sqf` (`AP_clientDefaultSettings` slot 7); server `fn_mapRowOp.sqf`,
`fn_mapEditPoll.sqf`, `fn_mapEditEmit.sqf`, `config.cpp`, `server/AP_server/init.sqf:140-141`;
tools `map_generate.py`, `mapdata_rows.py`, `map_codegen.py`, `map_push.py`, `map_watch.py`,
`make_compositions.py`, `fab_check.py`, `test_mapdata_rows.py`, `test_frame_oracle.py`,
`test_map_generate.py`, `test_map_push.py`, `run_checks.sh`, `deploy/pack_pbo.py`,
`deploy/reload-armapunk2035.sh` (+ its byte-identical copy in `/home/timb/arma3server_dev/`).

Delete: listed in D7.

---

## Tasks

Each task ends with `tools/run_checks.sh` green and a commit. Engine-side tasks (5–9) are proven
on the dev server + headless client, never by reading the code alone. "Observe red" steps name the
exact log line that must be ABSENT before the task and PRESENT after.

### Task 0: Baseline measurements and the fetch/pull

**Files:** none (read-only).

- [ ] `cd ~/Armapunk2035 && git fetch origin && git pull && git status` (expect clean except the
      regenerated `fn_mapData.sqf` — commit it as `chore(map): bake rev 10718` if dirty).
- [ ] Record the pre-change join cost on the HC: `bash /home/timb/arma3server_dev/hc_launch_once.sh`
      → in `loonyhc_direct.log` note the timestamp gap between `headless client online` and the last
      `[AP-MAPEDIT] apply` line. Keep the number in the commit message of Task 9.
- [ ] `ls -l /home/timb/arma3server_dev/mpmissions/ | tail -1` → note PBO size (79,040,558 at b0934).

### Task 1: Schema v3 + migration tool (Python, TDD)

**Files:** Create `deploy/map_objects_v3.sql`, `tools/map_migrate_v3.py`, `tools/test_map_migrate_v3.py`.
**Interfaces produced:** table columns per D1; `map_migrate_v3.parse_placements(src) -> list[dict]`
(`model, x, y, z, dir, scale`), `decor_lists(src) -> (decor, shit)`, `static_ids(conn, marker_pos)`.

- [ ] **Step 1 — failing tests** (`tools/test_map_migrate_v3.py`, pytest style like `test_map_push.py`):

```python
import math, textwrap
import map_migrate_v3 as M

FIX = textwrap.dedent('''
    private _MALDEN = getMissionPath "custom_p3ds\\";
    // comment mentioning createSimpleObject must not count
    _o = createSimpleObject [_MALDEN + "Bank.p3d", [7051.480, 10254.300, 71.500], true]; _o setDir 90; _o setObjectScale 1;
    _o = createSimpleObject [_MALDEN + "BridgeMiddle.p3d",   [8912.527, 3765, 0], true]; _o setDir 0; _o setObjectScale 1; // The Middle Piece
    _o = createSimpleObject [_MALDEN + "FederalReserveSign.p3d", [7000.1, 7000.2, 100.3], true]; _o setDir 45.5; _o setObjectScale 1.5;
''')

def test_parse_placements_counts_and_values():
    rows = M.parse_placements(FIX)
    assert [r["model"] for r in rows] == ["custom_p3ds\\Bank.p3d", "custom_p3ds\\BridgeMiddle.p3d", "custom_p3ds\\FederalReserveSign.p3d"]
    assert rows[0]["x"] == 7051.480 and rows[0]["dir"] == 90 and rows[2]["scale"] == 1.5

def test_parse_refuses_partial_parse():
    bad = FIX + '\n_o = createSimpleObject [_MALDEN + "X.p3d", [1,2], true];\n'
    try:
        M.parse_placements(bad); assert False, "expected SystemExit"
    except SystemExit: pass

def test_dir_to_vectors():
    d, u = M.dir_to_vectors(90)
    assert abs(d[0] - 1) < 1e-9 and abs(d[1]) < 1e-9 and u == (0, 0, 1)

def test_decor_lists():
    src = 'private _shitObjects = ["A", "B"];\nprivate _decorObjects = ["A", "C", "D"]; {\n'
    decor, shit = M.decor_lists(src)
    assert decor == ["A", "C", "D"] and shit == ["A", "B"]
    assert M.tier_updates(decor, shit) == {3: ["A"], 2: ["C", "D"]}
```

- [ ] **Step 2 — run, expect ImportError**: `cd ~/Armapunk2035/tools && python3 -m pytest test_map_migrate_v3.py -q` → `ModuleNotFoundError: map_migrate_v3`.
- [ ] **Step 3 — write `deploy/map_objects_v3.sql`** exactly as in D1 (plus a header comment naming this plan).
- [ ] **Step 4 — write `tools/map_migrate_v3.py`**:

```python
#!/usr/bin/env python3
"""map_objects v3 migration: custom .p3d placements -> rows; detail tiers; static radii.
Dry-run by default. --write commits ONE transaction. Idempotent: refuses if AP_CUSTOM_P3D rows exist."""
import argparse, math, os, re, sys
import apdb_dsn
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sqm_read  # existing shared parser (text + binarized)

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
MIS = os.path.join(ROOT, "mission", "Armapunk2035.Malden")
P3D_FILE = os.path.join(MIS, "custom_p3ds", "malden_buildings.sqf")
STREAM_FILE = os.path.join(MIS, "core", "functions", "fn_dynamicMapSystem.sqf")
SQM = os.path.join(MIS, "mission.sqm")
SQL = os.path.join(ROOT, "deploy", "map_objects_v3.sql")

_LINE = re.compile(r'^\s*_o\s*=\s*createSimpleObject\s*\[\s*_MALDEN\s*\+\s*"([^"]+\.p3d)"\s*,\s*'
                   r'\[\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\]\s*,\s*true\s*\]\s*;'
                   r'\s*_o\s+setDir\s+(-?[\d.]+)\s*;\s*_o\s+setObjectScale\s+([\d.]+)\s*;')

def parse_placements(src):
    want = sum(1 for l in src.splitlines() if "createSimpleObject" in l and not l.strip().startswith("//"))
    rows = []
    for l in src.splitlines():
        m = _LINE.match(l)
        if m:
            rows.append({"model": "custom_p3ds\\" + m.group(1), "x": float(m.group(2)), "y": float(m.group(3)),
                         "z": float(m.group(4)), "dir": float(m.group(5)), "scale": float(m.group(6))})
    if len(rows) != want:
        sys.exit("ABORT: %d placements parsed but %d lines create a simple object" % (len(rows), want))
    return rows

def dir_to_vectors(deg):
    r = math.radians(deg)
    return (math.sin(r), math.cos(r), 0.0), (0, 0, 1)

def _arr(src, name):
    m = re.search(r'private\s+%s\s*=\s*\[(.*?)\];' % name, src, re.S)
    return re.findall(r'"([^"]+)"', m.group(1)) if m else []

def decor_lists(src):
    return _arr(src, "_decorObjects"), _arr(src, "_shitObjects")

def tier_updates(decor, shit):
    both = [c for c in decor if c in shit]
    return {3: both, 2: [c for c in decor if c not in shit]}

def marker_pos(sqm_path, name):
    """(x, y) of a named marker. Same walk as tools/bake_territory.py:49-70; Eden stores
    position as [x, elevation, y], so the map pair is indices 0 and 2."""
    for node in sqm_read.walk(sqm_read.parse(sqm_path)):
        props = node["props"]
        if props.get("name") == name and isinstance(props.get("position"), (list, tuple)):
            pos = props["position"]
            return (float(pos[0]), float(pos[2]))
    sys.exit("ABORT: marker %s not found in mission.sqm" % name)

def main(argv=None):
    ap = argparse.ArgumentParser(); ap.add_argument("--write", action="store_true"); ap.add_argument("--world", default="Malden")
    a = ap.parse_args(argv)
    p3d = parse_placements(open(P3D_FILE, encoding="utf-8").read())
    decor, shit = decor_lists(open(STREAM_FILE, encoding="utf-8").read())
    assert len(decor) == 200 and len(shit) == 85, (len(decor), len(shit))
    tiers = tier_updates(decor, shit)
    jail = marker_pos(SQM, "jail_marker_loonybin")
    conn = apdb_dsn.connect()
    try:
        with conn.cursor() as cur:
            cur.execute(open(SQL, encoding="utf-8").read())
            cur.execute("SELECT count(*) FROM map_objects WHERE world=%s AND layer='AP_CUSTOM_P3D'", (a.world,))
            if cur.fetchone()[0]:
                sys.exit("refusing: AP_CUSTOM_P3D rows already exist")
            for r in p3d:
                d, u = dir_to_vectors(r["dir"])
                cur.execute("INSERT INTO map_objects (world, classname, model, x, y, z, vdir_x, vdir_y, vdir_z, vup_x, vup_y, vup_z,"
                            " scale, lod, stream_r, on_server, layer, author_uid) VALUES (%s,'',%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,0,0,true,'AP_CUSTOM_P3D','migration')",
                            (a.world, r["model"], r["x"], r["y"], r["z"], *d, *u, r["scale"]))
            for tier, classes in tiers.items():
                cur.execute("UPDATE map_objects SET lod=%s WHERE world=%s AND classname = ANY(%s)", (tier, a.world, classes))
                print("lod=%d: %d rows" % (tier, cur.rowcount), file=sys.stderr)
            cur.execute("UPDATE map_objects SET stream_r=0 WHERE world=%s AND stream_r IS NULL AND init LIKE %s", (a.world, "%_isStatic = true%"))
            print("static by init: %d" % cur.rowcount, file=sys.stderr)
            cur.execute("UPDATE map_objects SET stream_r=0 WHERE world=%s AND stream_r IS NULL AND sqrt((x-%s)^2+(y-%s)^2) <= 110", (a.world, jail[0], jail[1]))
            print("static by jail radius: %d" % cur.rowcount, file=sys.stderr)
            cur.execute("SELECT count(*), count(*) FILTER (WHERE model<>''), count(*) FILTER (WHERE stream_r=0), count(*) FILTER (WHERE lod=2), count(*) FILTER (WHERE lod=3) FROM map_objects WHERE world=%s AND NOT deleted", (a.world,))
            print("rows=%d model=%d always=%d lod2=%d lod3=%d" % cur.fetchone(), file=sys.stderr)
        if a.write: conn.commit(); print("COMMITTED", file=sys.stderr)
        else: conn.rollback(); print("dry-run: rolled back", file=sys.stderr)
    finally:
        conn.close()

if __name__ == "__main__":
    sys.exit(main())
```

  `marker_pos` uses the walk `tools/bake_territory.py:49-70` already uses on the same parser.
  Note: SQF's `jail_marker_loonybin` distance rule used `distance2D` on the world-frame row position
  and the marker's 2D position, so the SQL uses x/y only. `DB_fnc_asyncQuery` mode 1 with args:
  confirm the positional shape `[sql, 1, false, [args]]` against `server/AP_server/core/DB/fn_asyncQuery.sqf`
  before relying on it in `fn_mapLoad.sqf` (the mode-2 shape is proven by `fn_mapEditPoll.sqf:34`).
- [ ] **Step 5 — tests pass**: `python3 -m pytest test_map_migrate_v3.py -q` → `4 passed`.
- [ ] **Step 6 — dry-run against dev**: `~/pysqf-venv/bin/python tools/map_migrate_v3.py` →
      stderr shows `lod=3: N rows`, `lod=2: N rows`, `rows=9469 model=85 …`, `dry-run: rolled back`.
      `psql … -c "SELECT count(*) FROM map_objects"` still 9384 (rolled back).
- [ ] **Step 7 — commit** `feat(map): schema v3 + migration tool (custom p3d rows, detail tiers, static radii)`.
      Do NOT `--write` yet — the runtime that reads the new columns lands in Tasks 3–6.

### Task 2: Shared SQF primitives (cfg, cell rule, row text) + factory params

**Files:** Create `core/functions/fn_mapCfg.sqf`, `fn_mapCellFor.sqf`, `fn_mapCellsNear.sqf`,
`fn_mapRowText.sqf`; Modify `core/functions/fn_createVehicleLocal.sqf`, `Functions.h:462+`.
**Interfaces produced:** `call AP_fnc_mapCfg` → hashmap; `[pos, streamR] call AP_fnc_mapCellFor` →
string; `[pos, radius] call AP_fnc_mapCellsNear` → [keys]; `[row] call AP_fnc_mapRowText` → string;
`row call AP_fnc_createVehicleLocal` accepts 12 elements.

- [ ] **Step 1 — `fn_mapCfg.sqf`**:

```sqf
/*
    AP_fnc_mapCfg -- streaming constants. ONE definition for server, clients, headless client and
    the self-test; every consumer reads by name. Values and their reasons: mapdb.md D3.
*/
createHashMapFromArray [
    ["cell", 1000], ["far", 2000], ["defaultR", 1500], ["hyst", 250], ["fetchR", 2000],
    ["poll", 2], ["retry", 15], ["createBatch", 20]
]
```

- [ ] **Step 2 — `fn_mapCellFor.sqf`**:

```sqf
/*
    AP_fnc_mapCellFor -- which cell holds a row. A pure function of (x, y, stream_r), so the
    server index, the client index and the editor cannot disagree.
    params: 0 = position (world frame), 1 = stream_r (-1 = default, 0 = always)
    returns: "far" or "<cx>_<cy>"
*/
params [["_pos", [], [[]]], ["_r", -1, [0]]];
private _cfg = call AP_fnc_mapCfg;
if (_r < 0) then { _r = _cfg get "defaultR"; };
if (_r isEqualTo 0 || {_r > (_cfg get "far")}) exitWith { "far" };
private _c = _cfg get "cell";
format ["%1_%2", floor ((_pos select 0) / _c), floor ((_pos select 1) / _c)]
```

- [ ] **Step 3 — `fn_mapCellsNear.sqf`**:

```sqf
/*
    AP_fnc_mapCellsNear -- every cell whose square comes within _rad of _pos (nearest-edge test).
    params: 0 = position, 1 = radius (m)
    returns: [keys], never includes "far"
*/
params [["_pos", [], [[]]], ["_rad", 0, [0]]];
private _c = (call AP_fnc_mapCfg) get "cell";
private _x0 = _pos select 0; private _y0 = _pos select 1;
private _out = [];
for "_cx" from floor ((_x0 - _rad) / _c) to floor ((_x0 + _rad) / _c) do {
    for "_cy" from floor ((_y0 - _rad) / _c) to floor ((_y0 + _rad) / _c) do {
        private _nx = (_x0 max (_cx * _c)) min ((_cx + 1) * _c);
        private _ny = (_y0 max (_cy * _c)) min ((_cy + 1) * _c);
        if (([_x0, _y0, 0] distance2D [_nx, _ny, 0]) <= _rad) then { _out pushBack format ["%1_%2", _cx, _cy]; };
    };
};
_out
```

- [ ] **Step 4 — `fn_mapRowText.sqf`** (the ONLY row serialiser; `str`/`format` would round to
      six significant figures):

```sqf
/*
    AP_fnc_mapRowText -- one wire row -> its SQF literal, parseable by parseSimpleArray.
    toFixed for every number (str/format print 6 significant figures: 7216.602 -> "7216.6").
    str for strings/booleans/loadout (escapes " as "", which parseSimpleArray reverses).
*/
params [["_r", [], [[]]]];
_r params ["_cls", "_p", "_du", "_init", "_srv", "_lo", "_id", ["_model", "", [""]], ["_scale", 1, [0]],
           ["_lod", 1, [0]], ["_sr", -1, [0]], ["_os", false, [false]]];
_du params [["_d", [0,1,0], [[]]], ["_u", [0,0,1], [[]]]];
"[" + (str _cls) + ",[" + ((_p select 0) toFixed 3) + "," + ((_p select 1) toFixed 3) + "," + ((_p select 2) toFixed 3)
    + "],[[" + ((_d select 0) toFixed 4) + "," + ((_d select 1) toFixed 4) + "," + ((_d select 2) toFixed 4)
    + "],[" + ((_u select 0) toFixed 4) + "," + ((_u select 1) toFixed 4) + "," + ((_u select 2) toFixed 4)
    + "]]," + (str _init) + "," + (str _srv) + "," + (str _lo) + "," + (_id toFixed 0)
    + "," + (str _model) + "," + (_scale toFixed 3) + "," + (_lod toFixed 0) + "," + (_sr toFixed 1) + "," + (str _os) + "]"
```

- [ ] **Step 5 — extend `fn_createVehicleLocal.sqf`**. Replace lines 1–3 with:

```sqf
params[["_className", "", [""]], ["_position", [], [[]]
], ["_direction", 0, [0, []]], ["_code", "", [""]], ["_xIsServer", false], ["_loadout", [], [[]]],
    ["_id", -1, [0]], ["_model", "", [""]], ["_scale", 1, [0]], ["_lod", 1, [0]], ["_streamR", -1, [0]], ["_onServer", false, [false]]];
if ((_className isEqualTo "" && {_model isEqualTo ""}) || _position isEqualTo[]) exitWith {objNull};
// Which machine spawns what: is_server rows are GLOBAL on the dedicated server and never on a
// client; on_server rows are a LOCAL copy on the server (custom buildings: AI/vehicle collision)
// and a local copy on every client; everything else is client-only.
if (isDedicated && !_xIsServer && !_onServer) exitWith {objNull};
if (!isDedicated && _xIsServer) exitWith {objNull};
// Custom .p3d row: the recipe proven by custom_p3ds since 2026-06 -- the FINAL position goes to
// createSimpleObject (setPosASL does not move a fresh simple object), orientation next, and
// setObjectScale LAST (setDir rebuilds the matrix and resets scale to 1).
if (_model isNotEqualTo "") exitWith {
    private _o = createSimpleObject [getMissionPath _model, _position, true];
    if (isNull _o) exitWith { diag_log format ["[AP-MAP] model failed to load: %1", _model]; objNull };
    if (_direction isEqualType []) then { _o setVectorDirAndUp _direction; } else { _o setDir _direction; };
    if (_scale isNotEqualTo 1) then { _o setObjectScale _scale; };
    _o setVariable ["owner", "AP_customBuilding"];   // exempt from fn_cleanup's ownerless reap
    _o setVariable ["AP_mapId", _id];
    if !(_code isEqualTo "") then { private _c = _code; _o spawn (compile _c); };
    _o
};
```

  Change line 25's global branch to key on the row, not the machine:
  `if (isDedicated && _xIsServer) then {_className createVehicle[random 100, random 100, random 100];} else {`
  and line 41 likewise (`if (isDedicated && _xIsServer) then {_vehicle enableSimulation true;} else {...}`).
  After line 58 (`_vehicle setPosWorld _position;`) add:
  `if (_scale isNotEqualTo 1) then { _vehicle setObjectScale _scale; };` and
  `_vehicle setVariable ["AP_mapId", _id];`.
- [ ] **Step 6 — register** in `Functions.h` inside `class Functions {file = "core\functions";`:
      `class mapCfg {}; class mapCellFor {}; class mapCellsNear {}; class mapRowText {};`.
- [ ] **Step 7 — observe**: `bash tools/run_checks.sh` green (balance). Nothing calls the new fns
      yet; engine proof comes with Task 8's self-test (`parseSimpleArray` round trip of `mapRowText`).
- [ ] **Step 8 — commit** `feat(map): cell rule, row serialiser, factory params for model/scale/tier`.

### Task 3: Server cache, blob and fetch

**Files:** Create `server/AP_server/core/TON/fn_mapLoad.sqf`, `fn_mapBlob.sqf`, `fn_mapFetch.sqf`,
`fn_mapRowUpdate.sqf`; Modify `fn_mapRowOp.sqf`, `fn_mapEditPoll.sqf`, `fn_mapEditEmit.sqf`,
`server/AP_server/config.cpp:303-309`, `server/AP_server/init.sqf:140-141`, `mission/.../CfgRE.hpp`;
Delete `fn_mapEditLoad.sqf`, `fn_mapEditLoadOps.sqf`.
**Interfaces produced:** `APS_mapSelectCols` (string), `APS_mapRows/APS_mapText/APS_mapCells/
APS_mapBlobs/APS_mapLive` hashmaps, `APS_mapRev`, `APS_mapReady`; `[triple, broadcast] call
APS_fnc_mapRowUpdate`; `[key] call APS_fnc_mapBlob` → `[rev, packed, n]`; remote
`APS_fnc_mapFetch [kind, keys, unit]` replying `AP_fnc_mapCellRecv [key, rev, packed, n]` /
`AP_fnc_mapIndexRecv [keys, count, rev]`.

- [ ] **Step 1 — `fn_mapRowOp.sqf`**: change the guard to `if (count _r < 21) exitWith { [] };`,
      extend `params` with `"_model", "_scale", "_lod", "_sr", "_os"` after `"_rev"`, document the
      new column order (`…, rev, model, scale, lod, COALESCE(stream_r,-1), on_server`) and extend
      the upsert row with `format ["%1", _model], _scale call _n, _lod call _n, _sr call _n, _os call _b`.
      (`COALESCE(stream_r,-1)` in every SELECT: a NULL through `parseNumber` would become 0 = "always".)
- [ ] **Step 2 — `fn_mapRowUpdate.sqf`**:

```sqf
/*
    APS_fnc_mapRowUpdate -- the single mutator of the server's in-memory map.
    params: 0 = [id, rev, op] from APS_fnc_mapRowOp, 1 = broadcast to clients (false at boot)
    Removes the old row from its cell, stores the new one, invalidates both cell blobs,
    re-spawns the server's own copy for is_server / on_server rows, broadcasts [op, payload, rev].
*/
params [["_t", [], [[]]], ["_broadcast", true, [true]]];
_t params ["_id", "_rev", "_op"];
private _cellDel = { params ["_k", "_id"]; private _ids = APS_mapCells getOrDefault [_k, []]; private _i = _ids find _id;
    if (_i > -1) then { _ids deleteAt _i; if (_ids isEqualTo []) then { APS_mapCells deleteAt _k; } else { APS_mapCells set [_k, _ids]; }; };
    APS_mapBlobs deleteAt _k; };
private _old = APS_mapRows get _id;
if (!isNil "_old") then {
    [[_old select 1, _old select 10] call AP_fnc_mapCellFor, _id] call _cellDel;
    APS_mapRows deleteAt _id; APS_mapText deleteAt _id;
    private _o = APS_mapLive get _id; if (!isNil "_o") then { deleteVehicle _o; APS_mapLive deleteAt _id; };
};
if ((_op select 0) isEqualTo "upsert") then {
    private _row = (_op select 1) select 0;
    APS_mapRows set [_id, _row]; APS_mapText set [_id, [_row] call AP_fnc_mapRowText];
    private _k = [_row select 1, _row select 10] call AP_fnc_mapCellFor;
    private _ids = APS_mapCells getOrDefault [_k, []]; _ids pushBackUnique _id; APS_mapCells set [_k, _ids];
    APS_mapBlobs deleteAt _k;
    if ((_row select 4) || {_row select 11}) then {
        private _o = _row call AP_fnc_createVehicleLocal; if (!isNull _o) then { APS_mapLive set [_id, _o]; };
    };
};
if (_broadcast) then {
    if (_rev > APS_mapRev) then { APS_mapRev = _rev; };
    [[_op select 0, _op select 1, _rev], "AP_fnc_mapEditApply", 0, false] call AP_fnc_MP;
};
```

- [ ] **Step 3 — `fn_mapLoad.sqf`**:

```sqf
/*
    APS_fnc_mapLoad -- boot. Every live row into memory, indexed by cell; the server's own rows
    spawned. Clients never touch the database: they fetch from this cache (APS_fnc_mapFetch).
    Scheduled (mode-2 reads). Server-only, no CfgRE entry.
*/
if (!isServer) exitWith {};
private _t0 = diag_tickTime;
private _world = worldName;
APS_mapSelectCols = "id, classname, x, y, z, vdir_x, vdir_y, vdir_z, vup_x, vup_y, vup_z, init, is_server, COALESCE(loadout,''), deleted, rev, model, scale, lod, COALESCE(stream_r,-1), on_server";
// rev FIRST: anything written while we page lands in the first poll delta instead of being lost
private _mr = ["SELECT rev FROM map_meta WHERE world = %s", 2, false, [_world]] call DB_fnc_asyncQuery;
APS_mapRev = parseNumber format ["%1", _mr param [0, 0]];
APS_mapRows = createHashMap; APS_mapText = createHashMap; APS_mapCells = createHashMap;
APS_mapBlobs = createHashMap; APS_mapLive = createHashMap; APS_mapFetchRate = createHashMap;
["DELETE FROM map_objects WHERE world = %s AND deleted AND updated_at < now() - interval '7 days'", 1, false, [_world]] call DB_fnc_asyncQuery;
private _last = 0; private _pages = 0; private _n = 0;
while {true} do {
    private _rows = ["SELECT " + APS_mapSelectCols + " FROM map_objects WHERE world = %s AND NOT deleted AND id > %s ORDER BY id LIMIT 1000",
                     2, true, [_world, _last]] call DB_fnc_asyncQuery;
    if (_rows isEqualTo []) exitWith {};
    _pages = _pages + 1;
    { private _t = [_x] call APS_fnc_mapRowOp; if (_t isNotEqualTo []) then { [_t, false] call APS_fnc_mapRowUpdate; _last = _t select 0; _n = _n + 1; }; } forEach _rows;
};
// Compatibility: four server fns look rows up by class in allLocalMapEntities (indices 0-6 unchanged)
allLocalMapEntities = values APS_mapRows;
AP_exchangeSpots = (allLocalMapEntities select { ((_x param [3, ""]) find "civExchange") > -1 }) apply { _x param [1, [0,0,0]] };
publicVariable "AP_exchangeSpots";
diag_log format ["[AP-MAP] boot: %1 rows in %2 pages, rev %3, %4 cells, far %5, %6 s", _n, _pages, APS_mapRev, count APS_mapCells, count (APS_mapCells getOrDefault ["far", []]), (diag_tickTime - _t0) toFixed 1];
APS_mapReady = true;
uiSleep 3;   // let the world finish loading before spawning (custom_p3ds/load.sqf precedent)
private _g = 0; private _l = 0;
{ if ((_x select 4) || {_x select 11}) then {
    private _o = _x call AP_fnc_createVehicleLocal;
    if (!isNull _o) then { APS_mapLive set [_x select 6, _o]; if (_x select 4) then { _g = _g + 1 } else { _l = _l + 1 }; };
    uiSleep 0.0005; }; } forEach allLocalMapEntities;
AP_mapFarDone = true;
diag_log format ["[AP-MAP] boot: spawned %1 global + %2 local server rows", _g, _l];
```

  Note `mapRowUpdate` is called with `broadcast=false` at boot, so it does not spawn there; the
  spawn loop above is the boot path (spawning inside the page loop would run before `uiSleep 3`).
  Add to `mapRowUpdate`'s spawn branch the guard `if (missionNamespace getVariable ["APS_mapReady", false])`
  so boot rows are not spawned twice.
- [ ] **Step 4 — `fn_mapBlob.sqf`**:

```sqf
/*
    APS_fnc_mapBlob -- one cell as an engine-deflated SQF literal, cached per rev.
    params: 0 = cell key ("far" or "<cx>_<cy>")   returns: [rev, packed, rowCount]
    Permanent self-check: what a client will parse is exactly what this server holds.
*/
params [["_k", "", [""]]];
private _have = APS_mapBlobs get _k;
if (!isNil "_have") exitWith { _have };
private _ids = APS_mapCells getOrDefault [_k, []];
private _e = [APS_mapRev, "", count _ids];
if (_ids isNotEqualTo []) then {
    private _txt = "[" + ((_ids apply { APS_mapText get _x }) joinString ",") + "]";
    if (count _txt > 600000) then { diag_log format ["[AP-MAP] WARNING cell %1 is %2 chars raw", _k, count _txt]; };
    if (count _txt > 900000) then {
        diag_log format ["[AP-MAP] REFUSED cell %1: %2 chars raw (engine Inflate cap 1 MB)", _k, count _txt];
    } else {
        private _packed = controlNull ctrlWebBrowserAction ["Deflate", _txt];
        private _back = parseSimpleArray (controlNull ctrlWebBrowserAction ["Inflate", _packed]);
        if (_back isEqualTo (_ids apply { APS_mapRows get _x })) then { _e set [1, _packed]; }
        else { diag_log format ["[AP-MAP] ROUNDTRIP FAIL cell %1 (%2 rows) -- blob refused", _k, count _ids]; };
    };
};
APS_mapBlobs set [_k, _e];
_e
```

  `isEqualTo` on the parsed rows is exact only because `APS_mapRows` holds rows that came in
  through `mapRowOp`'s `parseNumber format` coercion with ≤ 4 decimals; if the check fails for a
  legitimate float-noise reason, store `parseSimpleArray (APS_mapText get id)` as the canonical
  row in `mapRowUpdate` instead (then the comparison is identity by construction).
- [ ] **Step 5 — `fn_mapFetch.sqf`**:

```sqf
/*
    APS_fnc_mapFetch -- a client asks for map cells; the server answers from memory.
    CfgRE allowedTargets = 2. Read-only. Requester = remoteExecutedOwner; a HEADLESS client's
    request arrives with owner 0 (engine, by design) and may name its own unit, as mapEditLoad did.
    params: 0 = "far" | "cells" | "index", 1 = [keys] for "cells", 2 = requester unit (HC only)
*/
params [["_kind", "", [""]], ["_keys", [], [[]]], ["_unit", objNull, [objNull]]];
if (!isServer) exitWith {};
private _owner = remoteExecutedOwner;
if (_owner isEqualTo 0 && {!isNull _unit} && {_unit in allPlayers}) then { _owner = owner _unit; };
if (_owner isEqualTo 0) exitWith { diag_log "[AP-MAP] fetch: no resolvable requester -- refused"; };
if (isNil "APS_mapReady") then { private _t = diag_tickTime; waitUntil { !isNil "APS_mapReady" || {diag_tickTime - _t > 120} }; };
if (isNil "APS_mapReady") exitWith { diag_log format ["[AP-MAP] fetch: cache not ready, owner %1 refused", _owner]; };
private _rl = APS_mapFetchRate getOrDefault [_owner, [0, diag_tickTime]];
if (diag_tickTime - (_rl select 1) > 10) then { _rl = [0, diag_tickTime]; };
_rl set [0, (_rl select 0) + 1]; APS_mapFetchRate set [_owner, _rl];
if ((_rl select 0) > 6) exitWith { diag_log format ["[AP-MAP] fetch: owner %1 rate-limited (%2 in 10 s)", _owner, _rl select 0]; };
if (_kind isEqualTo "index") exitWith {
    [[keys APS_mapCells, count APS_mapRows, APS_mapRev], "AP_fnc_mapIndexRecv", _owner, false] call AP_fnc_MP;
};
private _list = switch (_kind) do {
    case "far":   { ["far"] };
    case "cells": { (_keys select { _x isEqualType "" && {count _x <= 12} && {_x regexMatch "-?\d+_-?\d+"} }) select [0, 64] };
    default { [] };
};
private _chars = 0;
{
    private _b = [_x] call APS_fnc_mapBlob;
    _chars = _chars + count (_b select 1);
    [[_x, _b select 0, _b select 1, _b select 2], "AP_fnc_mapCellRecv", _owner, false] call AP_fnc_MP;
} forEach _list;
diag_log format ["[AP-MAP] fetch owner=%1 kind=%2 keys=%3 packed=%4 chars", _owner, _kind, count _list, _chars];
```

- [ ] **Step 6 — `fn_mapEditPoll.sqf`**: keep the loop; replace lines 44–57 with

```sqf
private _fresh = ["SELECT " + APS_mapSelectCols + " FROM map_objects WHERE world = %s AND rev > %s ORDER BY rev", 2, true, [_world, APS_mapRev]] call DB_fnc_asyncQuery;
private _sent = 0;
{ private _t = [_x] call APS_fnc_mapRowOp; if (_t isNotEqualTo []) then { [_t, true] call APS_fnc_mapRowUpdate; _sent = _sent + 1; uiSleep 0.01; }; } forEach _fresh;
APS_mapPollRev = _rev;
diag_log format ["[AP-MAP] rev=%1 applied: %2 row(s)", _rev, _sent];
```

  and delete the `APS_mapPollRev < 0` baseline branch (the boot load already set `APS_mapRev`;
  initialise `APS_mapPollRev = APS_mapRev`).
- [ ] **Step 7 — `fn_mapEditEmit.sqf`**: SELECT with `APS_mapSelectCols`; replace lines 20–21
      with `[_t, true] call APS_fnc_mapRowUpdate;`.
- [ ] **Step 8 — wiring**: `config.cpp` — delete `mapEditLoad`, `mapEditLoadOps`; add
      `class mapLoad {}; class mapRowUpdate {}; class mapBlob {}; class mapFetch {};` in the same
      TON block. `server/AP_server/init.sqf:140-141` →
      `[] spawn { [] call APS_fnc_mapLoad; [] call APS_fnc_mapEditPoll; };`.
      `CfgRE.hpp`: remove `APS_fnc_mapEditLoad`; add
      `class APS_fnc_mapFetch {allowedTargets = 2;};`,
      `class AP_fnc_mapCellRecv {allowedTargets = 1;};`, `class AP_fnc_mapIndexRecv {allowedTargets = 1;};`
      with a comment: rows carry init code compiled on clients, so blobs are server→client only.
- [ ] **Step 9 — delete** `fn_mapEditLoad.sqf`, `fn_mapEditLoadOps.sqf`; grep `mapEditLoad` across
      `mission/ server/ tools/` → only `core/init.sqf:93` and `fn_mapSelfTest.sqf` remain (Tasks 4, 8).
- [ ] **Step 10 — observe on dev** (the client still runs the OLD streamer at this point, so the
      world is unchanged): `bash /home/timb/arma3server_dev/reload-armapunk2035.sh`, wait for
      `read from bank`, then `grep -E '\[AP-MAP\] boot|Script .* not found|ROUNDTRIP' /home/timb/arma3server_dev/loonydev.log`.
      Expected: `[AP-MAP] boot: 9384 rows in 10 pages, rev 10718, 45 cells, far N, S s` (N ≥ the
      static rows; 9469 rows once Task 1's migration is written), `spawned 11 global + 0 local`,
      no `not found`, no `ROUNDTRIP`. `run_checks.sh` green.
- [ ] **Step 11 — commit** `feat(map): server-side cell cache, deflated blobs, fetch endpoint`.

### Task 4: Client streamer

**Files:** Create `core/functions/fn_mapStream.sqf`, `fn_mapStreamInit.sqf`, `fn_mapTick.sqf`,
`fn_mapFocus.sqf`, `fn_mapCellRecv.sqf`, `fn_mapIndexRecv.sqf`, `fn_mapWaitLoaded.sqf`;
Modify `fn_mapEditApply.sqf`, `fn_mapEditRemoveId.sqf`, `fn_dynamicMapVehicleFix.sqf`,
`core/fn_initCiv.sqf:77-79`, `core/init.sqf:73-95`, `Functions.h`.
**Interfaces produced:** globals `AP_mapRows`, `AP_mapCellRows`, `AP_mapCells`, `AP_mapLive`,
`AP_mapDirty`, `AP_mapPending`, `AP_mapReady`, `AP_mapFarDone`, `AP_mapDetail`, `AP_mapFocus`
(override), `AP_mapIndex`; `[] call AP_fnc_mapTick` runs one tick.

- [ ] **Step 1 — `fn_mapStreamInit.sqf`**:

```sqf
/*
    AP_fnc_mapStreamInit -- per-machine streamer state + the first request (the far bucket).
    Runs on every client and, driven by the self-test, on a headless client. Never on the server.
*/
if (isDedicated) exitWith {};
AP_mapRows = createHashMap;       // id -> wire row
AP_mapCellRows = createHashMap;   // cell key -> [ids]
AP_mapCells = createHashMap;      // cell key -> "wanted" | "loaded"
AP_mapCellAsked = createHashMap;  // cell key -> tick when requested
AP_mapCellRev = createHashMap;    // cell key -> rev of the blob we hold
AP_mapPending = createHashMap;    // cell key -> [[rev, op, payload]] edits that raced the fetch
AP_mapLive = createHashMap;       // id -> local object
AP_mapDirty = [];                 // ids whose live object must be deleted next tick
AP_mapReady = false; AP_mapFarDone = false;
private _slot = (profileNamespace getVariable ["PLBClientSettings", AP_clientDefaultSettings]) param [7, 0];
AP_mapDetail = if (_slot < 1) then { 2 } else { (round _slot) min 3 };
AP_mapCells set ["far", "wanted"]; AP_mapCellAsked set ["far", diag_tickTime];
[["far", [], player], "APS_fnc_mapFetch", 2, false] call AP_fnc_MP;
```

- [ ] **Step 2 — `fn_mapFocus.sqf`** — lift lines 64–76 of the old `fn_dynamicMapSystem.sqf`
      verbatim into a function returning `_playerPos` (or `[]` when `!alive player`), with one
      addition at the top: `if (!isNil "AP_mapFocus") exitWith { AP_mapFocus };`.
- [ ] **Step 3 — `fn_mapTick.sqf`**:

```sqf
/*
    AP_fnc_mapTick -- one streamer tick. The ONLY code that creates or deletes map objects on
    this machine (AP_fnc_mapEditApply only marks rows dirty -- remoteExec'd functions run
    scheduled and would interleave with this).
*/
if (isDedicated) exitWith {};
private _cfg = call AP_fnc_mapCfg;
private _focus = call AP_fnc_mapFocus;
if (_focus isEqualTo []) exitWith {};
if ((_focus distance2D getMarkerPos "respawn_civilian") <= 600 && {AP_effSide isEqualTo civilian}) exitWith {};   // old loop's suppression
// 1. cells we do not hold yet (or asked for and never got)
private _need = [_focus, _cfg get "fetchR"] call AP_fnc_mapCellsNear;
private _ask = _need select {
    private _st = AP_mapCells getOrDefault [_x, "none"];
    _st isEqualTo "none" || {_st isEqualTo "wanted" && {diag_tickTime - (AP_mapCellAsked getOrDefault [_x, 0]) > (_cfg get "retry")}}
};
if (_ask isNotEqualTo []) then {
    { AP_mapCells set [_x, "wanted"]; AP_mapCellAsked set [_x, diag_tickTime]; } forEach _ask;
    [["cells", _ask, player], "APS_fnc_mapFetch", 2, false] call AP_fnc_MP;
};
// 2. edits: the live object goes; step 4 recreates it if still wanted
{ private _o = AP_mapLive get _x; if (!isNil "_o") then { deleteVehicle _o; AP_mapLive deleteAt _x; }; } forEach AP_mapDirty;
AP_mapDirty = [];
// 3. delete pass over everything live
private _hold = if (isNull AP_dynamicMap_lastVehicle) then { [] } else { getPosWorld AP_dynamicMap_lastVehicle };
private _hyst = _cfg get "hyst"; private _defR = _cfg get "defaultR";
private _del = [];
{
    private _row = AP_mapRows get _x;
    if (isNil "_row") then { _del pushBack _x; } else {
        private _r = _row select 10; if (_r < 0) then { _r = _defR; };
        private _out = _r > 0 && {(_focus distance2D (_row select 1)) > _r + _hyst}
                       && {_hold isEqualTo [] || {(_hold distance2D (_row select 1)) > _r + _hyst}};
        if (_out || {(_row select 9) > AP_mapDetail}) then { _del pushBack _x; };
    };
} forEach (keys AP_mapLive);
private _nd = 0;
{ private _o = AP_mapLive get _x; if (!isNil "_o") then { deleteVehicle _o; }; AP_mapLive deleteAt _x; _nd = _nd + 1; if (_nd mod (_cfg get "createBatch") == 0) then { uiSleep 0.002; }; } forEach _del;
// 4. create pass over the far bucket + in-range cells, nearest first
private _mk = [];
{
    {
        if !(_x in AP_mapLive) then {
            private _row = AP_mapRows get _x;
            if (!isNil "_row" && {!(_row select 4)} && {(_row select 9) <= AP_mapDetail}) then {
                private _r = _row select 10; if (_r < 0) then { _r = _defR; };
                private _d = _focus distance2D (_row select 1);
                if (_r isEqualTo 0 || {_d < _r}) then { _mk pushBack [_d, _x]; };
            };
        };
    } forEach (AP_mapCellRows getOrDefault [_x, []]);
} forEach (["far"] + _need);
_mk sort true;
private _nc = 0;
{
    private _row = AP_mapRows get (_x select 1);
    if (!isNil "_row") then {
        private _o = _row call AP_fnc_createVehicleLocal;
        if (!isNull _o) then { AP_mapLive set [_x select 1, _o]; };
        _nc = _nc + 1; if (_nc mod (_cfg get "createBatch") == 0) then { uiSleep 0.001; };
    };
} forEach _mk;
if (AP_mapReady && {!AP_mapFarDone}) then {
    AP_mapFarDone = true;
    private _loaded = count ((keys AP_mapCells) select { (AP_mapCells get _x) isEqualTo "loaded" });
    diag_log format ["[AP-MAP] join: far %1 rows, %2 cells loaded, %3 live after first pass, %4 s since init", count (AP_mapCellRows getOrDefault ["far", []]), _loaded, count AP_mapLive, (diag_tickTime - AP_mapT0) toFixed 1];
};
if (_nc + _nd > 0) then { diag_log format ["[AP-MAP] tick: +%1 -%2 live=%3", _nc, _nd, count AP_mapLive]; };
```

  Set `AP_mapT0 = diag_tickTime` in `mapStreamInit`. (`condition count …` accepts ARRAYS only —
  BIKI `count` syntax 2 — hence the `keys … select` form.)
- [ ] **Step 4 — `fn_mapStream.sqf`**:

```sqf
if (isDedicated) exitWith {};
[] call AP_fnc_mapStreamInit;
private _poll = (call AP_fnc_mapCfg) get "poll";
while {true} do {
    uiSleep _poll;
    if (AP_inCombat && (diag_tickTime - AP_inCombatTime >= 30)) then { AP_inCombat = false };   // kept from the old loop
    [] call AP_fnc_mapTick;
};
```

- [ ] **Step 5 — `fn_mapCellRecv.sqf`**:

```sqf
/*
    AP_fnc_mapCellRecv -- one cell blob from the server (CfgRE allowedTargets = 1: server -> this
    client only; rows carry init code that this machine compiles).
    params: 0 = key, 1 = rev the blob was built at, 2 = deflated literal ("" = empty cell), 3 = rows
*/
params [["_k", "", [""]], ["_rev", -1, [0]], ["_packed", "", [""]], ["_n", 0, [0]]];
if (isDedicated || {isNil "AP_mapRows"}) exitWith {};
private _t0 = AP_mapCellAsked getOrDefault [_k, diag_tickTime];
private _rows = [];
private _txt = if (_packed isEqualTo "") then { "[]" } else { controlNull ctrlWebBrowserAction ["Inflate", _packed] };
if (_txt isEqualTo "") exitWith { diag_log format ["[AP-MAP] inflate FAILED cell %1 (%2 chars) -- will re-request", _k, count _packed]; AP_mapCells set [_k, "none"]; };
_rows = parseSimpleArray _txt;
if (!(_rows isEqualType []) || {count _rows != _n}) exitWith { diag_log format ["[AP-MAP] cell %1: parsed %2 rows, server said %3 -- refused", _k, count _rows, _n]; AP_mapCells set [_k, "none"]; };
private _ids = [];
{ if (_x isEqualType [] && {count _x >= 12}) then { AP_mapRows set [_x select 6, _x]; _ids pushBack (_x select 6); }; } forEach _rows;
AP_mapCellRows set [_k, _ids];
AP_mapCells set [_k, "loaded"]; AP_mapCellRev set [_k, _rev];
{ _x params ["_r", "_op", "_pl"]; if (_r > _rev) then { [_op, _pl, _r] call AP_fnc_mapEditApply; }; } forEach (AP_mapPending getOrDefault [_k, []]);
AP_mapPending deleteAt _k;
if (_k isEqualTo "far") then { AP_mapReady = true; };
diag_log format ["[AP-MAP] cell %1 rev %2: %3 rows, %4 packed chars, %5 s", _k, _rev, count _ids, count _packed, (diag_tickTime - _t0) toFixed 2];
```

- [ ] **Step 6 — `fn_mapIndexRecv.sqf`**: `params [["_keys",[],[[]]],["_n",0,[0]],["_rev",-1,[0]]]; AP_mapIndex = [_keys, _n, _rev];`
- [ ] **Step 7 — `fn_mapEditApply.sqf`** — replace the body from line 19:

```sqf
params [["_op", "", [""]], ["_payload", [], [[]]], ["_rev", -1, [0]]];
if (isDedicated) exitWith {};
if (isNil "AP_mapRows") exitWith {};   // streamer not up
switch (toLower _op) do {
    case "upsert": {
        _payload params [["_row", [], [[]]]];
        if (count _row < 12) exitWith { diag_log format ["[AP-MAPEDIT] upsert with %1 elements refused", count _row]; };
        private _id = _row select 6;
        if (!(_id isEqualType 0) || {_id < 1}) exitWith {};
        private _k = [_row select 1, _row select 10] call AP_fnc_mapCellFor;
        private _st = AP_mapCells getOrDefault [_k, "none"];
        if (_st isEqualTo "wanted") exitWith {   // raced a fetch: the blob's rev decides, on arrival
            private _p = AP_mapPending getOrDefault [_k, []]; _p pushBack [_rev, "upsert", _payload]; AP_mapPending set [_k, _p];
        };
        [_id] call AP_fnc_mapEditRemoveId;
        if (_st isEqualTo "none") exitWith {};   // never fetched: the fetch will carry this row
        AP_mapRows set [_id, _row];
        private _ids = AP_mapCellRows getOrDefault [_k, []]; _ids pushBackUnique _id; AP_mapCellRows set [_k, _ids];
        diag_log format ["[AP-MAPEDIT] apply upsert id=%1 cell=%2 rev=%3", _id, _k, _rev];
    };
    case "del": {
        _payload params [["_id", -1, [0]]];
        private _n = [_id] call AP_fnc_mapEditRemoveId;
        diag_log format ["[AP-MAPEDIT] apply del id=%1 removed=%2", _id, _n];
    };
    default { diag_log format ["[AP-MAPEDIT] unknown op %1", _op]; };
};
```

- [ ] **Step 8 — `fn_mapEditRemoveId.sqf`** body:

```sqf
params [["_id", -1, [0]]];
if (_id < 1 || {isNil "AP_mapRows"}) exitWith { 0 };
private _row = AP_mapRows get _id;
if (isNil "_row") exitWith { 0 };
private _k = [_row select 1, _row select 10] call AP_fnc_mapCellFor;
private _ids = AP_mapCellRows getOrDefault [_k, []];
private _i = _ids find _id; if (_i > -1) then { _ids deleteAt _i; AP_mapCellRows set [_k, _ids]; };
AP_mapRows deleteAt _id;
if (_id in AP_mapLive) then { AP_mapDirty pushBackUnique _id; };
1
```

- [ ] **Step 9 — `fn_mapWaitLoaded.sqf`**: `params [["_pos",[],[[]]],["_timeout",20,[0]]]; private _k = [_pos, -1] call AP_fnc_mapCellFor; private _t = diag_tickTime; waitUntil { uiSleep 0.5; ((AP_mapCells getOrDefault [_k, "none"]) isEqualTo "loaded" && {AP_mapFarDone}) || {diag_tickTime - _t > _timeout} }; (AP_mapCells getOrDefault [_k, "none"]) isEqualTo "loaded"`.
      Then in `core/fn_initCiv.sqf:77-79` replace the `dynamicMap_%1_status` wait with
      `[_spawnPos, 20] call AP_fnc_mapWaitLoaded;` (read those three lines first for the exact
      variable that holds the spawn position).
- [ ] **Step 10 — `fn_dynamicMapVehicleFix.sqf`**: read it; keep only what sets
      `AP_dynamicMap_lastVehicle` (the hold rule now lives in the tick); delete zone references.
- [ ] **Step 11 — `core/init.sqf:73-95`**: replace `[] call AP_fnc_mapData;`, the `AP_exchangeSpots`
      derivation, `[] spawn AP_fnc_dynamicMapSystem;` and the join-delta spawn block with
      `[] spawn AP_fnc_mapStream;` and a comment pointing at `mapdb.md`. `AP_exchangeSpots` now
      arrives as a server publicVariable (JIP-synced before init runs).
- [ ] **Step 12 — `Functions.h`**: add `class mapStream {}; class mapStreamInit {}; class mapTick {};
      class mapFocus {}; class mapCellRecv {}; class mapIndexRecv {}; class mapWaitLoaded {};`;
      remove `class dynamicMapSystem {};`, `class mapZoneFor {};`, `class compZones {};`, and the
      Config block's `class mapData {};`, `class dynamicMapCfg {};`. Delete those five files.
      `grep -rn 'dynamicMap_\|mapZoneFor\|dynamicMapCfg\|compZones\|allLocalMapEntities' mission/`
      → remaining hits only in `fn_mapSelfTest.sqf` (Task 8), `debug/*` (dev probes, leave),
      comments, and `fn_dynamicMapVehicleFix.sqf` if any (fix).
- [ ] **Step 13 — observe red then green on dev**: deploy; join with the owner client (or the HC
      via Task 8 once it exists). Client RPT must show `[AP-MAP] cell far rev …`, then
      `[AP-MAP] join: far … s since init`, then `[AP-MAP] tick: +N …`. The world at La Trinite
      must look as before (buildings, NPC shops, lux tower present). Server log:
      `[AP-MAP] fetch owner=… kind=far`, `kind=cells keys=N`. Red state to have seen first: before
      this task's deploy, a client shows NO `[AP-MAP]` lines and the world is built by
      `[AP-MAPEDIT]`/zone loads.
- [ ] **Step 14 — commit** `feat(map): per-object streamer fed by server cells; baked array retired on clients`.

### Task 5: Custom p3d rows live; door sweep; migration written

**Files:** Create `custom_p3ds/door_sweep.sqf`; Modify `initServer.sqf`, `initPlayerLocal.sqf`;
Delete `custom_p3ds/load.sqf`, `custom_p3ds/malden_buildings.sqf`, `custom_p3ds/Skyscraper20_r14.p3d`,
`custom_p3ds/skyscraper_doors.sqf`, `custom_p3ds/skyscraper_doors_data.sqf`.

- [ ] **Step 1 — migration write**: `~/pysqf-venv/bin/python tools/map_migrate_v3.py --write` →
      `COMMITTED`, `rows=9469 model=85`. Within 10 s the running dev server logs
      `[AP-MAP] rev=N applied: 85+ row(s)` (poll) — and, because clients get `on_server`/model
      rows as upserts, every connected client logs `[AP-MAPEDIT] apply upsert … cell=far`.
- [ ] **Step 2 — `custom_p3ds/door_sweep.sqf`**: the `[] spawn { sleep 2; … }` block from
      `malden_buildings.sqf:236-262` with the `skyscraper20_r14` entry removed and `sleep 2`
      replaced by `waitUntil { uiSleep 1; missionNamespace getVariable ["AP_mapFarDone", false] }; sleep 2;`.
      Keep the comment about not naming the spawn command (the count gate is gone, but the
      lesson is cheap). Header: runs on the server AND every client; towers are `on_server` rows.
- [ ] **Step 3 — `initServer.sqf`**: delete 264–266 (mapData block) and 336–338's `load.sqf` +
      `malden_buildings.sqf` lines (keep `malden_markers.sqf`); add `[] execVM "custom_p3ds\door_sweep.sqf";`
      AFTER the `fn_suiteData` load at :327 (lux door ordering); delete `["server"] call AP_fnc_compZones;`.
      Leave `lux_footprint.sqf` (:454) and add a comment: its `_centre` literal duplicates the
      skyscraper30 row — if the tower is moved in the table, move it there too.
- [ ] **Step 4 — `initPlayerLocal.sqf`**: delete 442–443, add `[] execVM "custom_p3ds\door_sweep.sqf";`
      in their place, delete line 472 (`compZones`).
- [ ] **Step 5 — delete** the five files; `grep -rn 'skyscraper20\|Skyscraper20\|door_leaf_wide2\|door_leaf_narrow2\|skyscraper_doors' mission/ tools/ scratchpad/ --include=*.sqf --include=*.py --include=*.txt`
      → remove `Skyscraper20_r14` from `tools/make_compositions.py` `TOWER_ALT` and from
      `tools/map_model_paths.txt` if listed; if the two 20F leaf p3ds have no remaining reader,
      delete them too (2 files). Delete the stale `MAD Building - Skyscraper20…` composition
      folder under `~/.local/share/Steam/…/Documents/Arma 3/compositions/` by hand (never auto-pruned).
      If `map_model_paths.txt` changed, rerun `tools/bake_map_meshes.py` (run_checks gates it).
- [ ] **Step 6 — observe**: deploy; server log `[AP-MAP] boot: 9469 rows … far ≥ 85`,
      `spawned 11 global + 85 local server rows`, `[APDOORS] skyscraper30_r17: wired 1 instance(s)`
      on BOTH server log and client RPT; client at the lux tower [7216,7777]: tower present, lobby
      doors open/close, `custom_p3ds` bank/palace/HQ walls/bridges present. Red state before:
      with `malden_buildings.sqf` deleted but rows not written, the tower is ABSENT.
- [ ] **Step 7 — commit** `feat(map): custom .p3d placements are table rows; door sweep waits for the far bucket`.

### Task 6: Detail-tier setting

**Files:** Modify `core/web/fn_deckSettings.sqf:41-45`, `core/web/fn_deckSettingsSet.sqf:43-74`,
`core/configuration.sqf` (`AP_clientDefaultSettings` slot 7 → `2`).

- [ ] Add the row `["mapTier", 7, "Map detail", "range", 1, 3, "tier"]` to the VIEW DISTANCE
      group's `_view` list (read `fn_deckSettings.sqf:32-45` for `_row`'s arity).
- [ ] `fn_deckSettingsSet.sqf`: map entry `["mapTier", [7, "tier"]]`; clamp `case "tier": { (round _v max 1) min 3 }`;
      live effect `case "mapTier": { AP_mapDetail = _v; }` (the next tick applies it: tier-3 rows
      vanish / tier-2 rows appear within 2 s).
- [ ] Observe: deck → Settings → drag Map detail 2 → 1 → decor disappears within 2 s
      (`[AP-MAP] tick: +0 -N`); back to 2 → returns. Commit `feat(map): map detail tier setting (slot 7)`.

### Task 7: Tools — snapshot, staging/push by id for both layers, gates, PBO exclusions

**Files:** Modify `tools/map_generate.py`, `tools/mapdata_rows.py`, `tools/map_codegen.py`,
`tools/map_push.py`, `tools/map_watch.py`, `tools/make_compositions.py`, `tools/fab_check.py:437`,
`tools/test_mapdata_rows.py`, `tools/test_frame_oracle.py`, `tools/test_map_generate.py`,
`tools/test_map_push.py`, `tools/run_checks.sh`, `deploy/pack_pbo.py`,
`deploy/reload-armapunk2035.sh` + `/home/timb/arma3server_dev/reload-armapunk2035.sh`;
Create `deploy/pbo_exclude.txt`, `tools/map_pbo_gate.py`, `deploy/map_snapshot/map_objects.sqf`.

- [ ] **Step 1 — `git check-ignore -v deploy/map_snapshot/map_objects.sqf`** → no output (not ignored). If ignored, pick `tools/map_snapshot/` and update every path below.
- [ ] **Step 2 — `mapdata_rows.py`**: `format_row` gains `model, scale, lod, stream_r, on_server`
      (`"%s",%.3f,%d,%s,%s` with `stream_r` emitted as `-1` for NULL, booleans `true/false`);
      `read()` parses both 7- and 12-element rows (the id is still the LAST integer before `]`
      in the 7-shape, and element 6 in the 12-shape — detect by element count). Header regex accepts
      `AP_mapSnapshotRev` as well as `AP_mapBakedRev`. Tests in `test_mapdata_rows.py` switch their
      fixture path to the snapshot and add one 12-element round-trip case.
- [ ] **Step 3 — `map_generate.py`**: `MAPDATA` → `deploy/map_snapshot/map_objects.sqf`; header
      `AP_mapSnapshotRev = %d;`; select the five new columns; remove the purge (server boot purges);
      first run writes every row in the 12-shape (one-time full diff). Run it:
      `~/pysqf-venv/bin/python tools/map_generate.py --write` → file exists, 9,469 rows.
- [ ] **Step 4 — `map_codegen.py`**: add `read_mapdata_db()` / `read_p3d_db()` (psycopg via
      `apdb_dsn`) returning the same shapes `read_mapdata()` and `parse_p3d()` return today
      (read `:170-250` for those shapes; a model row maps to `(Model name without dir/ext, x, y, z, dir from vdir, scale)`
      and carries its id); `stage()` uses them and stamps `AP_ID=<id>` into `AP_CUSTOM_P3D`
      descriptions (`AP_ID=<id>|AP_P3D=<Model>|AP_SCALE=<s>`); `staged_from_rev` = `map_meta.rev`.
      `apply` exits with `"apply is retired: use push (mapdb.md D7)"`. Delete `write_p3d()`,
      `_p3d_expected_count()`, `P3D_FILE`, `MAPDATA` and the `AP_mapBakedRev` reader.
- [ ] **Step 5 — `map_push.py`**: read BOTH layers; for `AP_CUSTOM_P3D` entities diff by id:
      transform/scale change → `UPDATE x,y,z,vdir_*,vup_*,scale`; new anchor → `INSERT … model='custom_p3ds\<Model>.p3d', classname='', on_server=true, stream_r=0, lod=0, layer='AP_CUSTOM_P3D'`;
      staged-and-absent → soft delete. Description tokens `AP_LOD=<0-3>` and `AP_R=<metres>` on
      any entity set `lod` / `stream_r` (validated ranges). `test_map_push.py`: one case per branch.
- [ ] **Step 6 — `map_watch.py`**: delete `TARGETS`, the digest/deploy branch and `BOOT_MARKER`
      wait; the loop is now "sqm digest changed → `map_push.py`" (what `--push` did). Remove
      `/home/timb/arma3server_dev/.map_watch_deployed` (`rm`, it is state, not code).
- [ ] **Step 7 — `make_compositions.py`**: `MC.read_p3d()` → `read_p3d_db()`; `derived_roles()`
      reads the snapshot via `mapdata_rows.read`. `fab_check.py:437` → snapshot path.
      `test_frame_oracle.py:23` → snapshot path.
- [ ] **Step 8 — `pack_pbo.py`**: add `--exclude-list=<file>`: one relative path per line
      (`#` comments), matched exactly, case-insensitive, forward slashes, in the same place the
      `.bak` test runs. `deploy/pbo_exclude.txt`:

```
# dev-only round-trip payload; never read at runtime (mapdb.md D7)
mapImportAll_data.sqf
mapImportAll.sqf
mapExportAll.sqf
edenDraw.sqf
mapBaseline_ids.sqf
```

      Both reload scripts pass `--exclude-list="$SRC/deploy/pbo_exclude.txt"` and replace the
      `map_generate.py --write` gate with the snapshot regeneration (still `|| exit 1`), then
      `git -C "$SRC" add deploy/map_snapshot/map_objects.sqf` is NOT automated — the operator
      commits the snapshot (matches how `fn_mapData.sqf` was committed).
- [ ] **Step 9 — `tools/map_pbo_gate.py`** + `run_checks.sh` line: fails if any of
      `core/config/fn_mapData.sqf`, `core/config/fn_dynamicMapCfg.sqf`, `core/functions/fn_dynamicMapSystem.sqf`,
      `custom_p3ds/malden_buildings.sqf`, `custom_p3ds/load.sqf`, `compositions/zones.sqf`,
      `custom_p3ds/Skyscraper20_r14.p3d` exists under `mission/`, or if any path in
      `pbo_exclude.txt` is missing from the tree (a typo would silently ship the file).
- [ ] **Step 10 — observe**: `bash tools/run_checks.sh` green; `edit-map.sh stage` produces a
      MaldenEdit whose `AP_CUSTOM_P3D` layer has 85 anchors with `AP_ID=`; move one bank anchor
      2 m in 3DEN, save, `edit-map.sh push` → `[AP-MAP] rev=N applied: 1 row(s)` on the server
      within 10 s and the bank moves on a connected client — with NO deploy.
      `ls -l mpmissions/ | tail -1`: PBO ≈ 79.0 MB − (1.11 + 0.94 + 2.72 + ~0.1) MB ≈ 74.2 MB.
      Confirm `unzip -l`-equivalent (the packer's `--list` if present, else
      `python3 -c "import deploy.pack_pbo"` header parse) shows none of the gate's files.
- [ ] **Step 11 — commit** `feat(map): table is the only source -- snapshot outside the mission, stage/push both layers by id, PBO exclusions`.

### Task 8: Headless self-test rewrite + measurement lines

**Files:** Modify `core/functions/fn_mapSelfTest.sqf` (phases `core`, `terrain`, `cargo`; `authority`
verification), `CfgRE.hpp` (unchanged entries), `server/AP_server/init.sqf:1377-1382` (unchanged verb).

- [ ] **Step 1 — helper** at the top of the spawned body: `_fetchAll` = `[] call AP_fnc_mapStreamInit`
      (if `AP_mapRows` nil), wait `AP_mapReady` ≤ 30 s, request `["index", [], player]`, wait
      `AP_mapIndex` ≤ 10 s, request the keys in batches of 64 with `uiSleep 3` between batches,
      wait until every key is `loaded` ≤ 90 s; `_say` the totals and the elapsed seconds.
- [ ] **Step 2 — `core` phase**:
      (1) `_fetchAll` → PASS if `count AP_mapRows == AP_mapIndex select 1` (server row count) and
      no `ROUNDTRIP`/`refused` line was needed;
      (2) `AP_mapFocus = [7500, 10500, 0]` (La Trinite); `[] call AP_fnc_mapTick` → PASS if
      `count AP_mapLive > 500`; `AP_mapFocus = [100, 100, 0]`; tick → PASS if
      `count AP_mapLive == {(_y select 10) isEqualTo 0} count AP_mapRows` (only "always" rows);
      (3) synthetic row id 999001 (`Land_Bucket_F` at the focus, lod 1, r −1) via
      `["upsert", [_row], 1] call AP_fnc_mapEditApply` on a `loaded` cell → tick → PASS if live;
      `["del", [999001], 2]` → tick → PASS if gone;
      (4) race: pick an unheld key `"0_0"`, `AP_mapCells set ["0_0", "wanted"]`, apply an upsert with
      rev 999999999 for a row inside it, then `["0_0", 1, "", 0] call AP_fnc_mapCellRecv` → PASS if
      the row is in `AP_mapRows` afterwards (pending replay), FAIL if dropped;
      (5) unprivileged `add` → `APS_fnc_mapEditSRV` REFUSED (unchanged from today);
      (6) tier: `AP_mapDetail = 0`, focus La Trinite, tick → PASS if every live row has lod 0;
      restore 2.
- [ ] **Step 3 — `terrain` / `cargo`**: replace `[] call AP_fnc_mapData … forEach allLocalMapEntities`
      with `_fetchAll` then `forEach (values AP_mapRows)`; field indices unchanged.
- [ ] **Step 4 — `authority`**: after each `add`/`move`/`del` through `APS_fnc_mapEditSRV`,
      `uiSleep 3; [] call AP_fnc_mapTick;` then verify via `AP_mapLive`/`AP_mapRows`.
- [ ] **Step 5 — observe red→green**: `bash /home/timb/arma3server_dev/hc_launch_once.sh`; wait
      `headless client online`; `psql … -c "INSERT INTO bot_commands (command,arg1) VALUES ('mapselftest','core')"`;
      `psql … -c "SELECT ts, msg FROM log WHERE tag='-MAPTEST-' ORDER BY ts DESC LIMIT 40"` → every
      step PASS, plus `[AP-MAP] join:` and the `_fetchAll` timing in `loonyhc_direct.log`. Red first:
      run the SAME verb against the Task-4 build with `mapSelfTest` still calling `AP_fnc_mapData`
      → `Script … mapData not found` / FAIL lines.
- [ ] **Step 6 — commit** `test(map): headless self-test drives the cell streamer end to end`.

### Task 9: Measurements, docs, hand-off

**Files:** Create `mapdb.md` (this plan's Design + decisions), `mapdb_plan.md` (this file);
Modify `tools/MAP_EDITING.md` (workflow: stage → edit → push; apply retired; new tokens), `HANDOFF.md`
(new section), `CLAUDE.md` directory map line for `tools/`, memory file `armapunk-live-map-editor`.

- [ ] Record in `mapdb.md` §Measurements: HC `_fetchAll` seconds for all 45 keys; owner-client
      `[AP-MAP] join:` line (far seconds + first-pass live count); server `[AP-MAP] boot:` seconds;
      PBO size before/after; `fetch … packed=N chars` for a La Trinite join. Budget: far ≤ 2 s,
      first pass ≤ 10 s on loopback. If over budget, the first lever is `fetchR` 2000 → 1750
      (fewer cells per request), the second is `createBatch` 20 → 40.
- [ ] Owner playtest checklist (in `mapdb.md` §Playtest): join at civ spawn → La Trinite drive →
      lux tower doors → jail area (static rows present on teleport) → F12 move a bench, second
      client sees it in ≤ 1 s → `UPDATE map_objects SET stream_r=300 WHERE id=<that bench>` →
      bench vanishes when > 550 m away and returns inside 300 m → settings Map detail 1/2 →
      restart → everything identical (no baked copy exists to be stale).
- [ ] Commit `docs(map): mapdb design + plan, MAP_EDITING workflow, handoff`.

---

## Verification (end to end)

1. `cd ~/Armapunk2035 && bash tools/run_checks.sh` — all green including `map_pbo_gate.py` and
   the four map test files.
2. `~/pysqf-venv/bin/python tools/map_generate.py --write && git diff --stat deploy/map_snapshot/`
   — a regeneration from an unchanged table is a no-op diff.
3. Deploy dev; server log has exactly one `[AP-MAP] boot:` with `9469 rows`, no
   `Script … not found`, no `ROUNDTRIP FAIL`, `[APDOORS] skyscraper30_r17: wired 1 instance(s)`.
4. HC self-test `core`, `authority`, `terrain`, `cargo`: all PASS in the `log` table.
5. Owner client: RPT `[AP-MAP] join:` under budget; world visually identical at La Trinite, the
   palace plaza, the jail, the bridges; lux doors work; NPC shops trade (their `init` ran).
6. Live edit round trip without deploy: 3DEN push AND F12 move both land on a second client
   within 10 s / 1 s respectively.
7. PBO listing contains no file from the gate list; size ≈ 74 MB.
8. Restart the server: same `boot:` counts; a client rejoin shows the same world (no baked rev to
   fall behind).

## Risks and the measured answer to each

- **Blob text vs six-significant-figure rounding** — `toFixed` everywhere; the server's blob
  round-trip assert refuses any cell that does not parse back identically.
- **Inflate on a headless client** — unproven until Task 8 step 5; if it fails there but works on
  a full client, the HC self-test falls back to requesting blobs with `packed = ""` semantics… no:
  it FAILS loudly and the plan stops until the mechanism is understood (an HC that cannot inflate
  cannot run the acceptance test).
- **Join slower than today's zone load** — the `[AP-MAP] join:` line is the meter; levers named in
  Task 9. Today's zone load paces ONE create per frame, so 20 per `uiSleep` is expected to be faster.
- **`lux_footprint.sqf` literal** — duplicates the skyscraper30 row position; noted in
  `initServer.sqf` and `mapdb.md`. Moving the tower needs both edits.
- **Server rows edited in-game** — `mapRowUpdate` re-spawns the server copy; `APS_fnc_mapEditSRV`
  still refuses `is_server` rows (unchanged).
- **Eden compositions** for towers carry `TOWER_ALT` z-offsets in `make_compositions.py`; unaffected
  (they produce anchors, and push turns anchors into model rows).

## Out of scope (follow-ups, not started)

- In-game editor panel fields for `lod` / `stream_r` (owner: later).
- `ui/html/malden_{msh,bld,hf}.txt` (3.8 MB of derived data for the HTML map) could be served by
  `fn_webPageSRV` instead of shipped; separate change.
- `mission.sqm` designer objects (4,464) stay engine-placed (owner decision).
- `setFeatureType` landmark tier (not requested).
- `images/` 25.6 MB is the largest non-map download cost (owner: keep all images).

## Observations for the observation log (task-observer) — flush after plan mode exits

- Monitor task `bhvysg7jj` (another session) reports `Error in expression <_pl) then {` every 6 min
  on the dev server — pre-existing, not this plan's; note for the owner (not a skill observation).
- brainstorming-extras "representation limits": the design nearly serialised coordinates through
  `str`/`format` (six significant figures → 7216.602 becomes 7216.6). The rule names currency
  ceilings, precision and ID widths; it should also name the SERIALISATION PATH the design will
  use (which string conversion, which parser) as a representation limit to check before the
  transport is chosen. Caught here only because the memory index carried the money footgun.
- superpowers:dispatching-parallel-agents / using-superpowers: one of three parallel `Agent`
  launches failed with `InputValidationError: prompt missing` inside the batch and the other two
  ran on; the missing scout was noticed only from the error text. After any parallel launch,
  verify one agentId came back PER intended scout before proceeding.
- superpowers:brainstorming in plan mode: bundled AskUserQuestion rounds (4 axes, then 4 residuals)
  after exploration worked well — every answer changed the plan and no recorded intent was re-asked.
  Confirms extras #37/#96; no change needed.
