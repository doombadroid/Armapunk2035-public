# mapdb.md — DB-driven map init: zero map data in the client PBO (design, 2026-09-04)

Plan with tasks and proofs: `mapdb_plan.md`. Visual: https://claude.ai/code/artifact/3f4181eb-16b4-4a4b-bb3b-39ba46551f6e

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
  25 PySQF chunks — inside the envelope web-serve exercises daily). Builds, in `localNamespace`
  (D6), `APS_mapRows` (id → wire row), `APS_mapText` (id → row text), `APS_mapCells` (key →
  [ids]), `APS_mapBlobs` (key → [rev, packed, n]) lazily, plus `APS_mapLive`, `APS_mapFetchRate`,
  `APS_mapRev`, `APS_mapSelectCols` and `APS_mapReady`. Purges tombstones > 7 days. Sets the compatibility snapshot
  `APS_mapEntities = values APS_mapRows`, also in `localNamespace` (five server fns read it by class:
  `fn_loonyBinSRV`, `fn_maldenJewelSRV`, `fn_cyberdeckSRV`, `fn_atmSkimSRV`, `fn_mapBake`), publishes
  `AP_exchangeSpots` (was derived client-side from the baked array), then after `uiSleep 3`
  spawns `is_server` rows (global) and `on_server` rows (local) through `AP_fnc_createVehicleLocal`,
  tracking them in `APS_mapLive` (the spawn pass walks its private reference, never the
  client-overwritable global). `APS_mapReady` is set before the settle sleep; `AP_mapFarDone` after
  the spawn pass.
- `APS_fnc_mapBlob [key]` → `[rev, packed, n]`: joins the cell's row texts, `Deflate`, caches.
  Permanent self-check: `parseSimpleArray (Inflate packed) isEqualTo rows` — logs
  `[AP-MAP] ROUNDTRIP FAIL` and refuses the blob on mismatch. Raw > 600 KB warns, > 900 KB refuses
  (engine Inflate cap 1 MB; measured max 191 KB).
- `APS_fnc_mapFetch [kind, keys, unit]` (CfgRE `allowedTargets = 2`): requester =
  `remoteExecutedOwner`, headless fallback via the named unit exactly as `mapEditLoad` did; waits
  for `APS_mapReady`; validates keys (`regexMatch "-?\d+_-?\d+"`, ≤ 64); rate limit 6 requests /
  10 s per owner; kinds `far`, `cells`, `index` (self-test: every non-empty key + row count +
  rev). Replies go to the requester only: `AP_fnc_mapCellRecv [key, rev, packed, n]` and
  `AP_fnc_mapIndexRecv [keys, count, rev]`, both server-origin only (see D6) — rows carry
  `init` CODE that clients compile, so no client may ever push a blob at another.
- `APS_fnc_mapRowUpdate [triple, broadcast]`: the single mutator of the in-memory maps. Removes
  the old row from its cell, stores the new one, invalidates both blobs, re-spawns the server's
  own copy if `is_server`/`on_server`, and (when `broadcast`) sends
  `[op, payload, rev]` → `AP_fnc_mapEditApply` to target 0.
- `APS_fnc_mapEditPoll`: unchanged shape (poll one integer every 10 s) but on change reads only
  `rev > APS_mapRev` (deleted included) and pushes each through `mapRowUpdate`. The last polled
  rev is the loop's own local.
- `APS_fnc_mapEditEmit`: reads the row by id → `mapRowUpdate` (broadcast). `APS_fnc_mapEditSRV`
  and `APS_fnc_mapEditAudit` unchanged. `fn_mapEditLoad.sqf` and `fn_mapEditLoadOps.sqf` deleted.

### D5. Client (`core/functions/`)

- `AP_fnc_mapStream` = `mapStreamInit` + `while {true} do { uiSleep poll; call AP_fnc_mapTick }`.
  Started from `core/init.sqf` where the baked array used to be bound.
- `AP_fnc_mapStreamInit`: creates, in `localNamespace` (D6), `AP_mapRows`, `AP_mapCellRows`,
  `AP_mapCells` (key → `wanted|loaded`), `AP_mapCellAsked`, `AP_mapCellRev`, `AP_mapPending`,
  `AP_mapLive` (id → obj), `AP_mapDirty` (ids to recreate); reads `AP_mapDetail` from the settings
  slot, requests `far`. Readers bind a store once per call (`localNamespace getVariable`) and
  mutate it in place; nothing reassigns one after init.
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
- `AP_fnc_mapCellRecv` / `AP_fnc_mapIndexRecv` / `AP_fnc_mapEditApply` / `AP_fnc_mapSelfTest`
  are server-origin only: NOT in CfgRE (the server needs no entry; CfgRemoteExec binds clients
  only), and each opens with `if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};`.
  `mapEditApply` also admits `mapCellRecv`'s pending replay (a nested `call` that may run after a
  suspension) by that caller's private `_mapCellReplay` marker, which no network call can carry.
  `allowedTargets = 1` was never the control — it limits the target, not the sender, so while
  they were listed any client could push a row with an `init` string at every other client
  (audit 2026-09-26).
- The streamer's stores (D5) live in `localNamespace`, never `missionNamespace`: as globals, one
  client's `publicVariable "AP_mapRows"` (or `AP_mapPending`, replayed inside a genuine server
  blob) reached every client's compile of row `init`, and a forged `AP_mapLive`/`AP_mapDirty`
  drove `deleteVehicle` on arbitrary objects (audit 2026-09-26). `localNamespace` cannot be
  written over the network. Do not move them back.
- The server's stores (D4) live in `localNamespace` too: as globals, one client's
  `publicVariableServer` of `APS_mapBlobs` (served verbatim by `mapFetch` under owner 2, past every
  client gate), `APS_mapText`/`APS_mapRows` (rebuilt into the next blob) or `APS_mapSelectCols`
  (concatenated into the poll's SELECT, so an attacker-chosen `init` column was re-read, compiled
  on the server and broadcast to every client) reached the same compile (audit 2026-09-26).
  The by-class snapshot went the same way (audit r2heist): as the `missionNamespace` global
  `allLocalMapEntities`, one client publish forged the ATM whitelist / skimmer ATM check and the heist
  prop lookups, so it is `localNamespace` `APS_mapEntities` now and the old global no longer exists.
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


## Measurements (dev, loopback, headless client, 2026-09-04)

| what | value |
|---|---|
| server boot load | 9,469 rows in 10 pages, 45 cells, far bucket 707 rows, 11.5 s (`[AP-MAP] boot:`) |
| far bucket | 707 rows, 16,844 packed chars, 0.18 s after the request |
| every cell (`index` + 45 keys) | 9,469 rows, 290,456 packed chars total, 4.0 s |
| largest cell `11_4` | 1,549 rows, 42,564 packed chars, 0.64 s |
| first create pass at La Trinite | 1,200 live objects, 6.2 s after init (`[AP-MAP] join:`) |
| in-game edit path | migration's 792 writes reached the running server and a client in one 10 s poll |
| PBO | 79,040,558 B (b0934) → 73,963,985 B (b0941): 2,174 entries, no placement data, dev payload excluded, Skyscraper20 gone |
| final headless self-test (b0941) | 9/9 PASS; far 0.18 s, all cells 4.0 s, first pass 6.3 s |

Budget from the plan: far ≤ 2 s, first pass ≤ 10 s. Both met. Levers if a real client misses them:
`fetchR` 2000 → 1750 (fewer cells per request), `createBatch` 20 → 40 (`fn_mapCfg.sqf`).

## Playtest (owner, one real client)

1. Join at civ spawn: RPT has `[AP-MAP] cell far …` then `[AP-MAP] join: …` under 10 s; the world
   at the spawn looks as before (buildings, NPC shops trade — their `init` ran).
2. Drive to La Trinite: cells arrive as you go (`[AP-MAP] cell 7_10 …`), the palace plaza, bridges
   and HQ walls are there, the lux tower's lobby doors open and close.
3. Jail area: the 622 static rows are present on teleport (they are always loaded).
4. F12: move a bench; a second client (or the HC log) shows `[AP-MAPEDIT] apply upsert` within 1 s.
5. `UPDATE map_objects SET stream_r = 300 WHERE id = <that bench>` → it vanishes beyond 550 m and
   returns inside 300 m, within 10 s of the write. Set it back to NULL.
6. Deck → Settings → Map detail 1 → decor disappears within 2 s; 2 → returns.
7. Restart the server → identical world on rejoin (there is no baked copy to fall behind).

## Owner playtest 2026-09-04 (b0942/b0943) — two fixes

1. **Empty town.** The tick had kept the old loop's "skip within 600 m of respawn_civilian" rule and
   its AP_ses_last_pos swap. On Malden that marker is in the plaza; the old streamer survived it only
   because everything outside a zone circle was *static* (loaded once). Removed both; fn_initCiv's
   pre-load is explicit through `AP_fnc_mapWaitLoaded`. Self-test step 7 now runs the production
   focus path. Verified: owner client 2,282 live objects within 10 s of init.
2. **Splash-screen hang.** `fn_settingsInit.sqf` validated settings slot 7 as a legacy admin-only
   boolean; the tier default of 2 threw and aborted `core/init.sqf`. Slot 7 now validates 0..3 and an
   old `false` resets silently.

Also: the `mapselftest` verb reaches every client; on an admin client its "unprivileged add" inserted
a row (9650, soft-deleted). The self-test is headless-only now.

## 2026-09-09: the scenario's plain props moved into the table

`tools/map_migrate_props.py` moved 3,907 of the 4,367 objects `mission.sqm` still placed itself
into `map_objects` (author `migrate-props-0909`, layer AP_MAPDATA, lod from the frozen decor
lists, stream_r NULL) and deleted them from the scenario by Eden id, so they are live-editable
from Eden Live and F12 like every other row. The table went 9,585 -> 13,492 rows (rev 12841 ->
16748), the server boots them in ~17 s in 56 cells, and the editor sees the same 13,952 objects
as before, 13,492 of them tagged.

**Pass 2, the same evening** (`--pass2`, author `migrate-p2-0909`): 214 objects the designer had
marked `_serverObject = true` -- the fed's gates, ring safes, dome and centre, the bank's back-alley
gate, the emporium's gates, the evidence lockup, the gang compounds, the bridge -- became
`is_server` rows (the server spawns them with a global `createVehicle`, exactly one copy in the
world, clients never stream them), and 96 tree anchors became model rows pointing at the game's own
tree models (`a3\plants_f\tree\...p3d`, a bare name still means `custom_p3ds\`) with the init's
height offset, heading and scale, plus 75 class rows for the visible grates and bins. 310 entities
left the scenario; the table is 13,877 rows at rev 17133; the server boots 225 global + 94 local
server rows about 25 s after mission start.

**Boot order matters now.** `APS_fnc_mapLoad` spawns the `is_server` rows after the table read and a
3 s settle, so anything in `init.sqf` that resolves world objects synchronously at mission start
sees none of them. The Reserve, bank and emporium boots (`APS_fnc_maldenFedSRV ["boot"]`,
`APS_fnc_maldenBankSRV ["boot"]`, `APS_fnc_maldenJewelSRV`) and the police bar-gate opener now run
in one detached spawn that waits for `AP_mapFarDone`. That also fixed a bug older than the props
move: the fed's DOME and CENTRE anchors (`migration` rows, `is_server` since 9/4) had resolved NULL
at every boot since the mapdb move. Any new boot-time `nearestObjects` / `allMissionObjects` reader
of a table-placed object needs the same wait. And the server's object now SURVIVES a geometry
edit: `APS_fnc_mapRowUpdate` keeps the live object and moves it with `AP_fnc_mapPlace` (the one
placement rule, shared with `AP_fnc_createVehicleLocal`) when class, init, flags, loadout and
model are unchanged, so the resolvers' handles stay valid across an Eden drag; a change to any
of those, a model row or a simple object recreates as before. Log line: `[AP-MAP] row N (class)
moved in place, object kept`.

What the scenario still places, deliberately: units and their groups, the 60 player slots,
markers, logics, 68 crates / cargo nets / boats / scooters (a streamed one is a different local
object on every client) and the one named boat.

Undo, newest first: `tools/map_migrate_props.py --undo scratchpad/map_delivery/undo_props_20260909-162016.json`
then `... --undo scratchpad/map_delivery/undo_props_20260909-160200.json` (each soft-deletes its
rows and restores the scenario from the backup the log names), then redeploy.
