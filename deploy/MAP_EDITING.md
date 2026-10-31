# Editing code-spawned map objects (Athira PD, shops, props)

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
# edit; then SELECT THE WHOLE LAYER (+ new stuff) and:
call compile preprocessFileLineNumbers "mapExportAll.sqf"
# shell:
wl-paste > /tmp/mapdata_all_export.sqf
python3 tools/mapdata_all.py apply /tmp/mapdata_all_export.sqf
```

- The server-spawn flag (5th entry field) rides in each entity's **description** attribute
  (`AP_SERVERSIDE`) — don't clear descriptions in the editor.
- `apply` replaces the ENTIRE array: it aborts on a >2% net deletion unless `--allow-deletes`,
  and always writes `fn_mapData.sqf.bak` first.
- Init fields are shop/NPC logic — preserved verbatim; use `_this` not `this` in new ones.
- Exclusion list (classes never exported) at the top of `mapExportAll.sqf`.
