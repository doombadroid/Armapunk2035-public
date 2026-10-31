# Live map editing — design (v2, 2026-09-01)

**Goal:** edit the map in-game, with no server restart and no repack. Move, add and delete
world objects from inside a running session; every connected client sees the change within a
second; the change survives a restart.

**Supersedes** the delta-layer design executed on 2026-08-31 (`mapedit_live_plan.md`, tasks
1–9 plus the editor). That design was sound in shape and wrong in one primitive: baked rows had
no identity, so identity was derived from content (`class|x|y|z`). Every hard bug that day —
scientific-notation keys, the negative-sign key, duplicate-position tombstones, two languages
that had to render one string identically — descended from that choice, and it left a defect
that design cannot fix: moving a baked object in-game re-created it with an empty `init`, so a
dragged shop-NPC anchor became a bare mannequin. This design gives every row an integer ID and
deletes the content key entirely.

## 1. Data model

One table owns every map row. `fn_mapData.sqf` becomes a build artifact generated from it.

```sql
map_objects
  id          bigserial PRIMARY KEY
  world       varchar(32)  NOT NULL DEFAULT 'Malden'
  classname   varchar(128) NOT NULL
  x, y, z     double precision NOT NULL          -- world frame (model centre), as today
  vdir_x/y/z, vup_x/y/z  double precision NOT NULL -- orthonormalised before any write
  init        text        NOT NULL DEFAULT ''     -- TRUSTED WRITERS ONLY (see §4)
  is_server   boolean     NOT NULL DEFAULT false
  loadout     text        NULL                    -- plain array string; emitted as [] when NULL
  layer       varchar(64) NOT NULL DEFAULT 'AP_MAPDATA'
  deleted     boolean     NOT NULL DEFAULT false  -- soft delete; purged after a pack
  rev         bigint      NOT NULL                -- stamped by trigger on every write
  author_uid  varchar(20) NOT NULL
  updated_at  timestamptz NOT NULL DEFAULT now()

map_meta (world PK, rev bigint)                   -- unchanged
map_edit_log                                      -- unchanged
map_edits, map_hidden                             -- DROPPED. Both are empty.
```

One trigger on `map_objects`: every INSERT/UPDATE bumps `map_meta.rev` and writes the new value
into the row's `rev`. Writers never supply `rev`. A writer cannot forget to signal, and every row
knows when it last changed.

`TEXT`, never `jsonb` (apdb re-encodes jsonb into the mres codec on read; double encode is
silent data loss). `loadout` is a plain array string, read with `parseSimpleArray`, per the
existing convention for `greenhouse_crop`.

**Representation ceiling.** SQF numbers are 32-bit floats: integers are exact only to
16,777,216. IDs will sit under 100,000 for years; the ceiling is named here because a design
that silently rounds an ID is one that silently edits the wrong object.

## 2. The generated file

`core/config/fn_mapData.sqf` is regenerated from `map_objects` at pack time and committed, so
git continues to show every map change as a diff. Two elements are appended to the row shape:

```
[class, pos, [vdir, vup], init, isServer, loadout, id]
```

First line of the file: `AP_mapBakedRev = <map_meta.rev at generation>;` — the PBO knows which
revision it is. `AP_fnc_createVehicleLocal` reads indices 0–5 and is untouched; index 6 is
invisible to it. Rows with `deleted = true` are excluded from the file. After a successful
generation the generator purges deleted rows whose `rev` is at or below the new `AP_mapBakedRev`
— nothing else deletes from the table.

Generation preserves each row's original text for every element that did not change, and
preserves the inter-row source text (commas and the owner's inline comments) — the byte-exact
emitter written on 2026-08-31 is reused. A generation from an unchanged database reproduces the
file byte-for-byte apart from the header and the two new elements.

## 3. Runtime

**Join.** The client binds the baked array exactly as today (`fn_dynamicMapSystem`), and tags
every created object with `AP_mapId` = row element 6. It then asks the server for the delta as
`[false, player]` — boot flag first, then its own unit. The server resolves the requester from
`remoteExecutedOwner`, falling back to the named unit's owner only when the engine supplies 0
(it does so for every request from a headless client, by design) and only after confirming the
unit is a connected player. The replay is idempotent and carries nothing sensitive, which is why
this request alone may name its caller; the authority never does. The delta query is —
`SELECT ... FROM map_objects WHERE world = ? AND rev > AP_mapBakedRev` — and applies each row
through the one applier. The join replay and a live edit use the same applier, so the two cannot
drift and there is no init-ordering race: every op is an edit to the binned result.

**In-game edit.** Client → `APS_fnc_mapEditSRV` → `UPDATE` / `INSERT` / soft `DELETE` by id →
the server broadcasts the resulting op to all clients immediately → each client applies it.
Latency is one round trip. The revision poll (`APS_fnc_mapEditPoll`, 10 s) stays only for
writers outside the game (§6); the in-game path does not wait for it. The server updates its own
delta cache when it broadcasts an in-game edit, so the next poll sees no difference and does not
broadcast the same change twice.

**Applier** (`AP_fnc_mapEditApply`) has two ops:

- `upsert [row]` — remove any existing object carrying that id from every zone list and the
  live world, bin the row by `AP_fnc_mapZoneFor`, create it if that zone is currently loaded. A
  move is an upsert; a move across a zone boundary is handled by construction.
- `del [id]` — remove from zone lists and the live world.

There is no `hide`, no occurrence count, and no baked/live distinction anywhere in the runtime.

**Server rows.** The 11 `is_server` rows are spawned by `initServer.sqf` from the same array,
unchanged. In-game editing of them is refused: they are replicated objects with a different
performance model, and the editor is for client-local geometry.

**Delta size.** The join delta is every row changed since the last pack. It is small if packs
happen with normal deploy cadence; the server logs a warning when it exceeds 500 rows, which is
the signal to pack.

## 4. Security

- The caller of `APS_fnc_mapEditSRV` is derived from `remoteExecutedOwner` and never from the
  payload; `adminlevel` is re-read from the database on every call; level 5 is required.
- The class allowlist is `AP_fnc_mapPlaceable`, the single definition shared with the client
  catalogue. Inert world geometry only — nothing drivable, alive, or lootable.
- **The in-game path never writes `init`.** A move is an `UPDATE` of transform columns only, so
  a moved row keeps whatever `init` it had. A new in-game placement is inserted with `init = ''`.
  `init` is compiled and spawned on every client by `AP_fnc_createVehicleLocal`; a client that
  could write it would have code execution on every connected machine.
- Only trusted tools running on the box — the migration, the Eden push — write `init`. This is
  the same rule as before, now enforceable by column rather than by op shape.
- A headless client can never be an editor: the engine hands the authority `remoteExecutedOwner`
  = 0 for its requests, and the authority refuses (and logs) a caller it cannot identify.
- Every accepted edit writes one `map_edit_log` row. Refusals log to `-SEC-` with the subject
  taken from the caller.

## 5. Migration

One-time, following `mapdata_migrate.py`'s discipline: rows are read in array order, each row's
class is asserted against what is written back, any mismatch aborts, and nothing resyncs or
skips — a single silent shift would move thousands of objects.

1. Apply the new schema (idempotent SQL in `deploy/`). Drop `map_edits` and `map_hidden`.
2. Parse the 9384 rows of `fn_mapData.sqf`; assign ids 1…9384 in array order; insert them.
3. Set `map_meta.rev` to 1 and stamp every row `rev = 1`.
4. Regenerate the file. The diff against the previous file must show exactly: the new header
   line, and one appended `,[],<id>` per row. Anything else aborts the migration.
5. Deploy. Verify `[AP-MAPEDIT] delta loaded: 0 rows` and, in-game, that every streamed object
   carries a numeric `AP_mapId`.

The custom `.p3d` building layer (`custom_p3ds/malden_buildings.sqf`, 86 rows, its own loader,
`createSimpleObject` by model path) is **out of scope**. Markers stay in the map layer per the
standing rule.

## 6. Eden — a second authoring surface, built after §3–5

Staging stamps `AP_ID=<id>` into each entity's description — the field 3DEN preserves verbatim,
already used for `AP_NPC=` — and writes the list of staged ids to `AP_stage.txt`. The push diffs
Eden against the table **by id**: transform or init changed → `UPDATE`; new entity without an
`AP_ID` → `INSERT`; an id that was staged and is now absent → soft `DELETE`. Deletion is
therefore exact. Staging records the file's `AP_mapBakedRev` as `staged_from_rev`, and a push
**refuses** (never merely warns) when any table row has `rev` above it: the edit mission is a
snapshot, and a push would write it back over every edit made since. That happened once, on
2026-09-01, before the guard existed. The sequence is always pack → stage → edit → push;
`--force` is the only override. The push runs on the box
with database access and is a trusted writer.

## 7. Relationship to the 2026-08-31 work

Deleted: `tools/mapkey.py`, `tools/test_mapkey.py`, `fn_mapKey.sqf`, the bake-key check in the
oracle, `map_hidden`, `occurrences`, the hide+add conversion, every `IsLive` branch, and the N
parameter of `fn_mapEditRemoveKey`.

Kept with small edits: the schema pattern and trigger, `APS_fnc_mapEditPoll`,
`AP_fnc_mapEditApply`, `APS_fnc_mapEditSRV` and its audit, `AP_fnc_mapZoneFor`, the freecam,
modal grab and panel, `AP_fnc_mapEditorCatalog`, `AP_fnc_mapPlaceable`, the frame oracle
(`test_frame_oracle.py`, `edenOracle.sqf`, `oracle_check.py` minus check 1), and the byte-exact
emitter from `mapdelta_export.py`, which becomes the generator.

## 8. Testing

Python, runnable without a game:
- Migration round trip: file → table → file is byte-identical apart from the header line and
  the appended elements.
- Generator: shape of every emitted row; deleted rows excluded; comments preserved.
- Push diff by id: changed/new/absent each produce exactly one op; unstaged ids are never
  deleted.
- Frame oracle, unchanged.

In-game, each with an observable red state before the fix:
- Edit on one client → visible on a second within a second, before any poll tick.
- Join against a PBO whose `AP_mapBakedRev` is deliberately behind the table → the delta replays
  and the world matches.
- Move an NPC anchor in-game → its `init` is intact afterwards (the defect this design exists
  to fix).
- Restart → every edit survives.

## 9. Build order

1. Schema + migration + generator (§1, §2, §5). The in-game tool works the moment this lands.
2. Runtime: applier by id, server authority by id, immediate broadcast, join delta (§3, §4).
3. Editor: remove the baked/live branching; everything is a move.
4. Pack-time regeneration hook.
5. Eden staging and push by id (§6).

## Open item, independent of this design

A client probe on 2026-08-31 reported `count allLocalMapEntities` = 18768, exactly twice the
9384 rows in both the repo file and the packed PBO. `core/init.sqf` runs once. If the runtime
array is genuinely doubled, the streamer is building the world twice today. Resolve before
trusting any in-game count:

```sqf
diag_log format ["[AP-PROBE] n=%1 dup=%2", count allLocalMapEntities,
    (allLocalMapEntities select 0) isEqualTo (allLocalMapEntities select 9384)];
```
