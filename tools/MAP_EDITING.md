# Editing the map (current pipeline)

    tools/edit-map.sh            # stage MaldenEdit.Malden from the TABLE (map_objects)
    tools/edit-map.sh watch      # leave running in a terminal
    # ...open MaldenEdit in 3DEN, drag things, Ctrl+S...
    #    -> the watcher PUSHES the diff to the table; the running server sees it within 10 s
    #       (its poll), every connected client within a second after that. No pack, no deploy.

**mapdb (2026-09-04): the table is the only source of placed objects.** There is no
`fn_mapData.sqf` and no `malden_buildings.sqf` any more; the mission PBO carries no placement
data at all. The server loads `map_objects` at boot and serves 1 km cells to clients; every row
has its own stream radius (`stream_r`) and detail tier (`lod`). Design: `mapdb.md`.

Per edit there is nothing to run with the watcher up: every save is diffed against the table BY
ID and pushed (`push` to do one save by hand; `apply` is retired and says so). Live is never
touched. A push refuses when the table moved on since you staged (`staged_from_rev`); re-stage.

The committed snapshot `deploy/map_snapshot/map_objects.sqf` is regenerated on every dev deploy
by `tools/map_generate.py --write` so `git log` still shows every map change; nothing loads it.

Placing content is drag-and-drop from Asset Browser -> Compositions -> Custom
(`python3 tools/make_compositions.py` regenerates them; ~100 entries, display-named):

  MAD Building - <name>     the custom .p3d buildings
  MAD NPC - <role>          every shop/service/civic role (live array + the Altis catalogue,
                            validated against this mission's own switch statements)
  MAD Garage - <kind>       vehicle shops/garages, WITH their spawn pads embedded
  MAD Spawn Pad - <kind>    extra car_spawn / air_spawn / boat_spawn pad markers
  MAD Light - <kind>        always-on lamps (init pre-set -- a bare lamp row becomes a simple
                            object, and simple objects cannot emit light at all)

Garages are self-wiring: their spawns argument is empty and npcs/fn_nearSpawns.sqf resolves the
nearest markers named car_spawn.. / air_spawn.. / boat_spawn.. within 150 m at init time. Ground
garages also use air pads (a car fits on a helipad; a heli does not fit on a car pad). Drop a
garage composition, nudge its pads where vehicles should appear, done -- add more pads with the
Spawn Pad compositions anywhere nearby. A garage with NO pads in range says so in chat and logs
loudly instead of spawning at [0,0,0].

New objects are picked up WHEREVER 3DEN puts them -- composition drops land in auto-created layers
and that is fine. Vanilla props dragged from the asset browser become map rows too; real AI units
(grouped) stay mission content. **Markers and modules are NOT pushed** (they never were rows):
the marker/module sync that `apply` used to do into the shipped mission.sqm is a follow-up
(`map_codegen.py` still has the helpers; `push` does not call them). Until then, place a marker in
Eden, then splice it into the shipped sqm with `tools/sqm_splice.py` by hand.

Everything code-spawned is in there: the 9,384 class rows (layer `AP_MAPDATA`) and the 85 custom
`.p3d` buildings (`AP_CUSTOM_P3D`), every entity stamped `AP_ID=<row id>` in its Description.
Two optional tokens set the new columns from Eden: `AP_LOD=<0-3>` (detail tier) and
`AP_R=<metres>` (stream radius, 0 = always loaded). Design and rationale: `mapedit.md` (the
editor), `mapedit_live.md` (ids), `mapdb.md` (the table as the only source).
Frames: `tools/sqm_frame.py`. Tests: `python3 tools/test_*.py`.

In the editor, once per session, Debug Console:

    call compile preprocessFileLineNumbers "edenDraw.sqf";

The NPC and building anchors render as nothing, so this draws their real models on them and keeps
the models FOLLOWING the anchors as you drag. Without it you are moving invisible objects with no
feedback, which silently threw an NPC 548 m across the map the first time it was tried.

## Two missions, one rule each

* `mission/Armapunk2035.Malden/mission.sqm` — the SHIPPED file. **Never save it from 3DEN.** A
  save re-bakes the script-spawned world into it; an autosave did exactly that on 2026-07-26 and
  `git checkout` was the recovery.
* `MaldenEdit.Malden` — GENERATED, never packed, git-ignored. **Saving it is the point.**

## The three things that will bite you

1. **Close the scenario before re-staging.** 3DEN saves from its in-memory copy, so a mission opened
   before a staging writes that older state back over it -- resurrecting whatever was in it. Staging
   cannot detect this; it refuses only when the file on disk has unapplied edits.
2. **Only edit entities that carry `AP_ID=` (or a fresh composition drop).** `push` writes rows
   alone. An edit to one of the designer's own mission.sqm entities is written nowhere -- it lives
   in the edit mission and nowhere else.
3. **Re-run `edenDraw.sqf` after reopening**, and after big moves, to resnap the models.

## Adding a new custom .p3d building -- the easy way

Run once per machine:

    python3 tools/make_compositions.py

That writes one 3DEN **Custom Composition** per building model into
`Documents/Arma 3/compositions/`. Restart Arma and they appear in the Asset Browser under
**Compositions > Custom** as `MAD_Bank`, `MAD_PoliceHQWallLong`, and so on. Drag one into the
scene and it IS a configured anchor -- nothing to type, no mod, and it works for anyone you hand
the job to (copy the folders, or publish them to the Workshop from the asset browser).

Then just save and `tools/edit-map.sh push`. Placements are found by their DESCRIPTION wherever
they sit, so it does not matter which layer 3DEN drops the composition into -- relevant because
3DEN gives each placed composition its own layer unless "Automatic Composition Layering" is off.
A new anchor becomes a row with `model = custom_p3ds\<Model>.p3d`, `on_server = true`,
`stream_r = 0` (always loaded), `lod = 0`.

Re-run `make_compositions.py` after adding a new model so it gets an entry.

## Adding a new custom .p3d building -- by hand

1. Put `<ModelName>.p3d` under **`mission/Armapunk2035.Malden/custom_p3ds/`**, alongside
   `Bank.p3d`, `HQMesh.p3d` and the rest. Rows reference it as `custom_p3ds\<ModelName>.p3d`
   and the factory resolves that with `getMissionPath` on every machine.
2. In 3DEN, place a **`Land_HelipadEmpty_F`** where you want the building, and put it in the
   **`AP_CUSTOM_P3D`** layer.
3. Set its **Description** attribute to:

       AP_P3D=ModelName|AP_SCALE=1

   Model name only -- no path, no `.p3d`. Scale is usually 1; the existing set uses 0.7 and 1.5 too.
4. Save, then `tools/edit-map.sh push`. The new placement is one INSERT into `map_objects`.
5. Re-run `edenDraw.sqf` to see the model appear on the anchor.

The anchor renders as nothing until step 5, so place it by the ground marker and check afterwards.
`push` warns and skips an anchor whose description names no model.

Deleting a building is the reverse: delete its anchor, save, push (a soft delete, `deleted = true`;
the server drops it on its next poll). Moving one is just dragging it.

## What it will not do

* **Composition zones** were retired with mapdb (the only registered zone was a disabled example).
  `compositions/cryptorig.sqf` is the mining rig's part list, not map data, and stays.
* **Markers, cartel flags, `replace_sheds`, atmosphere** stay code, deliberately -- see `mapedit.md`.
* **Row 8607** (`Land_RepairDepot_01_civ_F`) has vectors that are not a valid rotation
  (`|up|`=0.410). The sqm cannot represent that, so staging snaps it and says so. Pre-existing.

---

# SUPERSEDED pipelines (kept deliberately)

Everything below predates `tools/edit-map.sh` and is no longer the way to edit the map. It is kept
because all of it runs IN THE ENGINE, which is the only way to recover if the offline conversion is
ever in doubt -- and because the frame notes in it are still accurate. Note that
`edenCB_refresh.sqf` and `edenNPC_refresh.sqf` belong to these older flows and do NOT work with
anchors staged by `map_codegen.py`; use `edenDraw.sqf` for those.

## Editing code-spawned map objects (Athira PD, shops, props)

Every custom object on Altis — the Athira PD buildings, shop NPCs, props — is **data**, not
Eden placement. It lives in one array, `allLocalMapEntities`, in
`mission/LooneyBin.Altis/core/config/fn_mapData.sqf` (~7000 entries), and is spawned locally
per-machine via `createVehicleLocal` (zero network/JIP cost — that's why it's an array and not
`mission.sqm`; don't "fix" that). Because it's an array, the objects don't show in Eden and
you can't drag them.

This round-trip pulls a **region** into the 3DEN editor, lets you edit visually, and writes the
result back into the array. The engine does all height math; the Python tool only filters by
region and moves text.

```
   fn_mapData.sqf  --extract-->  3DEN editor  --edit-->  clipboard  --apply-->  fn_mapData.sqf
```

Entry format: `["class",[x,y,z],[[dirX,dirY,dirZ],[upX,upY,upZ]],"init",false]`
(z is ATL/above-ground; the 4th field `init` is the shop/NPC logic; 5th picks server vs client spawn.)

---

## 0. Get the region coords

You need a centre `X Y` and radius `R`. Stand at the spot in-game and run in the debug console:

```sqf
copyToClipboard str (getPosATL player)      // -> [X, Y, Z]; use the first two
```

Or aim at an object and use `copyToClipboard str (getPosATL cursorObject)`.
Pick `R` to just cover what you want (e.g. `120` for a compound). **Keep it tight** — a big radius
pulls in terrain-follower props (kerbs/walls) that are tilted (see the TILT note).

## 1. Extract the region

```bash
python3 tools/eden_region.py extract 3900 12900 120
```

It writes `edenImport_data.sqf` into your 3DEN editor mission folder and copies
`edenImport.sqf` + `edenExport.sqf` there. It reports:
- how many entries, and how many carry an **init** string (shops/NPCs — keep those on export),
- how many are **TILTED** (import flattens them — see below).

Add `--skip-tilted` to leave tilted props verbatim in the array (not imported, not editable this pass,
but guaranteed unchanged):

```bash
python3 tools/eden_region.py extract 3900 12900 120 --skip-tilted
```

If your editor mission is elsewhere: `AP_PROTON_MISSION=/path/to/mpmissions/LooneyBin.Altis python3 ...`

## 2. Import into 3DEN

Open **the LooneyBin mission in the 3DEN editor** (Eden), then Tools → Debug Console:

```sqf
call compile preprocessFileLineNumbers "edenImport.sqf"
```

Objects appear in a layer named **`ArrayImport`**, named `imp_0, imp_1, …`, at correct heights.

## 3. Edit freely

Move / rotate / add / delete objects. To **add** a new object, just place it (it'll be exported too).
For a shop NPC's behaviour, set its **Init** field — use `_this` (not `this`), e.g.
`[_this,'STAND_U1','wongs'] call NPC_fnc_shops;`

## 4. Export back to code

Select the objects to keep — **Edit → Select All** inside the `ArrayImport` layer, **plus** anything
you added. Then Tools → Debug Console:

```sqf
call compile preprocessFileLineNumbers "edenExport.sqf"
```

The array entries are now on your clipboard (and in the RPT between `AP_EDEN_EXPORT` markers).
Save them:

```bash
wl-paste > /tmp/eden_export.sqf        # (or xclip -o -selection clipboard > ...)
```

## 5. Apply back into fn_mapData.sqf

```bash
python3 tools/eden_region.py apply /tmp/eden_export.sqf
```

It removes the exact originals it staged and appends your edited entries. It prints a summary:
`removed N -> adding M = net ±K`, writes `fn_mapData.sqf.bak`, and re-parses to confirm the count.

**Deleting objects is gated.** If the export has fewer entries than were imported (usually because you
forgot to select some), it **ABORTS and writes nothing**. If you really meant to delete them:

```bash
python3 tools/eden_region.py apply /tmp/eden_export.sqf --allow-deletes
```

## 6. Ship it

`fn_mapData.sqf` is packed into the mission PBO, so the change goes live on the next repack/restart —
same as any code change (commit on `doomba`, PR to `main`, deploy). Reboot required (the array spawns at load).

---

## Footguns (all handled, but know them)

- **Select-all-or-lose.** `apply` replaces the *whole imported set*. Anything you don't re-export is a
  deletion. The tool now aborts on a net-deletion unless you pass `--allow-deletes`.
- **TILT.** `edenImport` sets **yaw only** — it flattens pitch/roll. Terrain-followers (kerbs, walls on
  slopes) will un-tilt if you import + re-export them. Options: keep them out with `--skip-tilted`, use a
  tight radius that misses them, or re-orient them by hand in 3DEN. `extract` warns with a count + examples.
- **Init strings = shop logic.** The 4th field drives NPC shops/services. Losing it is how the Athira cop
  shop got wiped once. The round-trip preserves it (`get3DENAttribute "init"` in 3DEN, verbatim text on
  apply); just don't strip Init fields in the editor. `extract` tells you how many entries carry one.
- **Separate editor mission ("Proton split").** You edit in a *standalone* 3DEN mission, not the live
  server mission. `extract` copies the staging files into it; `apply` writes the repo's `fn_mapData.sqf`.
  They're linked only through this tool — don't hand-copy between them.
- **Backups.** `apply` writes `fn_mapData.sqf.bak` before every change. `git diff` before committing.

---

# Composition zones (compExport / compImport) — owner 2026-07-10

The second pipeline. `fn_mapData` (above) is for the *always-loaded* shop/NPC/prop array. **Composition
zones** are for *object compositions* — bases, HQ prop sets, decoration clusters — that should only exist
around players: each client spawns its own **local** copies (`createSimpleObject` = no network, no sim
cost) when within the zone radius and deletes them when they leave. Data lives in
`mission/LooneyBin.Altis/compositions/zone_<name>.sqf`, one file per zone, listed in
`compositions/zones.sqf`. Loader: `AP_fnc_compZones` (client streaming loop + server boot pass).

**Why it round-trips perfectly where edenImport can't:** transforms are `getPosWorld` +
`vectorDir`/`vectorUp` end-to-end — the engine's raw world frame. No ATL/ASL conversion (the sea-level
elevation footgun is structurally impossible) and full pitch/bank fidelity (no TILT flattening — the
import writes Eden's rotation attribute *from the engine's read of the placed object*).

## Build a new composition

1. Open the editor mission in 3DEN, build the composition normally.
2. Select all its pieces → Debug Console → paste `tools/compExport.sqf` (edit `_zoneName` at its top first)
   → LOCAL EXEC. Full zone-file text lands on the clipboard (centre + radius auto-computed).
3. Paste into `mission/LooneyBin.Altis/compositions/zone_<name>.sqf`, add the path to
   `compositions/zones.sqf`, delete the pieces from the editor mission (they live in the zone file now).
4. Commit; next repack streams it live.

## Edit an existing composition

1. Copy the zone file's whole text onto the clipboard.
2. In 3DEN: Debug Console → paste `tools/compImport.sqf` → LOCAL EXEC. Pieces appear in layer
   `comp_<name>`, exact tilt included.
3. Edit visually. Select the layer's contents → run `compExport.sqf` again → paste over the zone file.
4. **DELETE the `comp_<name>` layer before saving the mission** — else Eden bakes a second copy into
   `mission.sqm` and it doubles up with the streamed one in-game.

## Knobs (zone file fields)

- `radius <= 0` → always loaded (spawned once at client init; use for stuff visible from far away).
- `enabled=false` → registered but spawns nothing (stage work-in-progress safely).
- `serverSide=true` → also spawned on the dedicated server at boot — only when server-side logic must
  collide with or `nearestObjects`-find the pieces (spawn-point clearance, house tagging, AI). Default off.
- Per-object 5th field `false` → `createVehicleLocal` instead of simple object (working doors/animation,
  still local-only). List such classes in compExport's `_needSim`. Use sparingly.

## Footguns

- **Simple objects have no animations** — doors won't open. That's the `_needSim`/5th-field escape hatch.
- **Don't hand-author entries** — always round-trip through Eden so posWorld/vectors stay engine-computed.
- **The comp_ layer** is scaffolding, never mission content. Export → delete layer → save.
- Zone objects are exempted from the server ownerless-object reap (`owner=AP_compzone`), same idiom as
  `custom_p3ds`.

---

# Full-map round-trip (mapdata_all / mapImportAll / mapExportAll) — owner 2026-07-10

The whole-array version of the region pipeline — ALL ~7000 `allLocalMapEntities` at once,
**full tilt fidelity** (vectorDir + vectorUp both ways; nothing gets flattened, unlike the
region importer's yaw-only TILT limitation).

```
python3 tools/mapdata_all.py extract          # stages everything into the editor mission
# 3DEN Debug Console:
call compile preprocessFileLineNumbers "mapImportAll.sqf"   # -> layer 'MapDataAll' (~7000, be patient)
# edit; then (no selecting needed):
call compile preprocessFileLineNumbers "mapExportAll.sqf"
# shell:
wl-paste > /tmp/mapdata_all_export.sqf
python3 tools/mapdata_all.py apply /tmp/mapdata_all_export.sqf
```

## Just ADDING objects — the short path (owner 2026-07-26)

You no longer import 15,000 entries or select anything to add a few props. Every entity the mission's
own `mission.sqm` ships with carries an Eden id, and `get3DENEntityID` gives the editor the same
number back, so the export can work out what is new on its own.

```
python3 tools/mapdata_all.py baseline         # once (re-run after mission.sqm changes)
# open the mission in 3DEN, PLACE YOUR OBJECTS, then Debug Console:
call compile preprocessFileLineNumbers "mapExportAll.sqf"
# shell:
wl-paste > /tmp/mapdata_add.sqf
python3 tools/mapdata_all.py apply /tmp/mapdata_add.sqf     # APPENDS, does not replace
```

With nothing imported, the export runs in **add-only mode**: it emits just your new objects and marks
the text `AP_MAPALL_MODE_APPEND`, which `apply` detects and appends to the array. The >2% deletion
guard does not apply (nothing was replaced); instead it refuses an "add-only" export carrying more
than 2000 entries, which would mean the baseline was stale or missing.

## No clipboard at all: leave the watcher running

`mapExportAll` already logs the export to the RPT between `AP_MAPALL_BEGIN`/`END` markers, so it can
be picked up without you touching the clipboard:

```
python3 tools/mapdata_watch.py          # leave this in a terminal
#   --dry-run   report what it would apply, write nothing
#   --once      apply the next export then exit
#   --backfill  also replay the last block already in the log
```

Then the loop is: place objects in 3DEN -> Debug Console ->
`call compile preprocessFileLineNumbers "mapExportAll.sqf"` -> **it is already in fn_mapData.sqf**.
It follows log rotation (an Arma restart makes a new .rpt), ignores a block it has already applied,
and prints a loud REFUSED line instead of writing when the deletion guard or the add-only cap trips.
Override the log folder with `AP_RPT_DIR=` if your prefix differs.

---

# Taking map work from the designer (Windows, no Python, no console)

They never run anything. Their job is what it already was: **place objects, save, send you the
`mission.sqm`**. Everything else happens here.

```
python3 tools/mapdata_all.py delivery <their PREVIOUS .sqm> <their NEW .sqm>
```

reports ADDED / REMOVED / moved / retyped by Eden id -- read it before you apply anything. Removals
matter most: an add-only apply cannot see them, so if they deleted a row of buildings you have to
decide that deliberately.

```
python3 tools/mapdata_all.py baseline --from <their PREVIOUS .sqm>
# open THEIR NEW file in 3DEN, then Debug Console:
call compile preprocessFileLineNumbers "mapExportAll.sqf"
```

with `mapdata_watch.py` running, that is the whole job. The `--from` baseline is the trick: Eden ids
are stable inside their mission too, so the ids their new file has and the old one doesn't are exactly
what they added -- no position matching, no class+XY join (the thing that once collapsed 838 stacked
objects into each other). Opening their file in 3DEN is only there to let the engine work out ATL
heights; converting those offline from the sqm's `atlOffset` was measured at 56% accurate (median
2 mm but p90 14 m), so don't.

If `delivery` reports **no shared Eden ids**, the two files are not the same lineage (they rebuilt the
mission, or it came from somewhere else). The id baseline cannot help there -- import the new file and
export the whole array instead.

**DO NOT SAVE the SHIPPED mission in 3DEN** (`mission/Armapunk2035.Malden/mission.sqm`; the
generated `MaldenEdit.Malden` is the one you do save -- see the top of this file). The map layer is script-spawned, so a save writes all 15k objects
back into `mission.sqm` as real entities (they then exist twice at runtime). An autosave did exactly
that on 2026-07-26 — `git checkout` on `mission.sqm` is the recovery. Placing and exporting without
saving is safe; the editor folder is a symlink to the repo, so a save lands straight in git.

- The server-spawn flag (5th entry field) rides in each entity's **description** attribute
  (`AP_SERVERSIDE`) — don't clear descriptions in the editor.
- `apply` replaces the ENTIRE array: it aborts on a >2% net deletion unless `--allow-deletes`,
  and always writes `fn_mapData.sqf.bak` first.
- Init fields are shop/NPC logic — preserved verbatim; use `_this` not `this` in new ones.
- Exclusion list (classes never exported) at the top of `mapExportAll.sqf`.

## Terrain deformation (Deformer mod) + binarized saves — 2026-08-02

- Terrain edits made with the **Deformer** mod (Greenfist, workshop 2822758266) live in a scenario
  attribute (`GF_deformMission >> GF_deformString`). `apply` ships that block into the shipped sqm
  (`sync_scenario_attrs`), and `terrainDeform.sqf` (wired from init.sqf) re-applies it at mission
  start **server-only, no mod needed anywhere** — `setTerrainHeight` is serverExec with global,
  JIP-persistent effect. The editor needs the mod to SCULPT; the server/clients never do.
- Objects re-seat onto deformed ground in 3DEN, so a big sculpt session legitimately rewrites
  thousands of mapData Z values — that diff noise is real terrain-following, not drift.
- If 3DEN saves the edit mission **binarized** (raP; editor preference, can be flipped by a mod
  install session), `apply` self-heals by derapifying via armake2 (`cargo install --git
  https://github.com/KoffeinFlummi/armake2 --locked`). Digest bookkeeping stays on the original
  binary file, so the stage/apply guards keep working.
