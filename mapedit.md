# Map editing: the editor as the source of truth (D2)

**Status:** design, approved 2026-07-31. Implementation plan: `mapedit_plan.md` (not yet written).
**Supersedes in intent:** the four separate round-trips documented in `tools/MAP_EDITING.md`.

## The problem

Every custom object on Malden is code, not Eden placement, and it lives in four different homes with
four different round-trips:

| Content | Count | Home | Round-trip today |
|---|---|---|---|
| Props / buildings | **8,717** rows | `core/config/fn_mapData.sqf` | `mapImportAll.sqf` / `mapExportAll.sqf` |
| Shop NPCs | 64 init rows | same array, 4th field | `edenNPC_import/export/refresh.sqf` |
| Custom `.p3d` buildings | 55 | `custom_p3ds/malden_buildings.sqf` | `edenCB_import/export/refresh.sqf` |
| Composition zones | per zone | `compositions/zone_*.sqf` | `compExport.sqf` / `compImport.sqf` |

Editing the map is therefore: run a Python stager, paste a line into the 3DEN debug console, edit,
paste another line, copy the clipboard to a file, run a Python applier — per subsystem, four times
over, each with its own footguns (select-all-or-lose, TILT flattening, frame mismatches).

## The design

Make the editor the source of truth. Two missions, one generated:

- **Shipped** — `mission/Armapunk2035.Malden/mission.sqm`. The designer's map layer. Its role does
  not change, and it never contains code-spawned content.
- **Edit** — `MaldenEdit.Malden/mission.sqm`. **Generated, never packed, never shipped.** It is the
  shipped sqm plus every code-spawned object as a real, draggable Eden entity in tagged layers.

```
  code arrays ──stage──> MaldenEdit.Malden ──(3DEN: drag things, save)──> ──apply──> code arrays
                                    (never packed)
```

Because the edit mission is never packed, the double-spawn that option D1 (one mission, strip at
pack) has to guard against is **structurally impossible** rather than merely prevented. This repo has
twice shipped damage of exactly that class — the Eden re-bake that added 15,642 objects, and the
class+XY join that duplicated 838 rows and lost 835 — which is why the variant that cannot express
the failure is the one being built.

## Why this works: the frames are proven

Measured 2026-07-31 (`tools/frame_solve.py` header carries the full result; probe is
`debug/frame_angles.sqf`, sampler `tools/sqm_frame_sample.py`):

- **Position.** The sqm's `position[]` is `{x, elevation, y}` and holds the **model centre** — the
  `getPosWorld` frame. Max error over 43 measured objects: **6.1e-5 m**. No terrain height is ever
  needed to place an object from the sqm.
- **Rotation.** `R = Rx(-angles[0]) · Ry(-angles[2]) · Rz(-angles[1])`, with
  `vectorDir = R·(0,1,0)` and `vectorUp = R·(0,0,1)`. Reproduces **43/43** measured objects to
  8.5e-7; the next best of 288 candidate conventions fits only 30/43. Cross-checked independently
  against the engine's `getDir` (worst bearing error 4.0e-5°). The inverse round-trips to 4.6e-7, so
  **writing** the sqm is exact too.

This closes the question that `tools/MAP_EDITING.md` records as unresolved ("converting those
offline from the sqm's `atlOffset` was measured at 56% accurate"). That measurement was of the wrong
conversion, not evidence of a hard limit: `atlOffset` is not the height, and the model centre is.

**Validation envelope.** The 43 measured rows span every yaw but only tilts up to 34°, because the
sampler excludes objects with a same-class neighbour within 1.5 m (they cannot be resolved
unambiguously) and the steepest ones are clustered. The map's steepest object is tilted 90° — close
enough to gimbal lock that an Euler ordering ambiguity could hide there. The composition is a plain
rotation matrix and should not care, but Phase 0's migration pass reads every row's true transform
from the engine anyway, so it doubles as the check: any row whose predicted vectors disagree with
the engine's is a real counter-example and must stop the migration, not be rounded away.

**`angles[]` is reordered exactly like `position[]`.** `angles[1]` is yaw about the world *up* axis,
not about the game's Y axis. Assuming otherwise fits zero yawed rows — a silent 180° mis-aim of the
entire map. This is the single most dangerous detail in the whole pipeline.

## Prerequisite: migrate `fn_mapData` to the world frame (Phase 0)

`fn_mapData` rows are applied with `setPosATL`; everything else (custom buildings, composition zones)
is already `getPosWorld`/`setPosWorld`. Converting between the two needs terrain height plus a
per-class, orientation-dependent bounding-centre offset — which cannot be done offline, and is the
one thing that would force an engine round-trip back into the pipeline.

So the array moves to the world frame **once**, with the engine's help, and never again:

1. A one-time client pass spawns the array exactly as `fn_createVehicleLocal` does and logs each
   row's `getPosWorld`. (8,717 objects — they already spawn every session.)
2. The array is rewritten offline from that log.
3. `fn_createVehicleLocal` switches `setPosATL` → `setPosWorld`.

Do **not** shortcut this with a per-class offset table: `getPosASL - getPosWorld` is constant per
class only while the object is upright, and **326 of the designer's 4,260 objects are tilted**, one
of them by 90°.

After Phase 0, every home is in one frame and all conversion is text shuffling.

## Mechanism

### Tagged layers

Generated content goes into reserved layers the designer never uses:

- `AP_MAPDATA` — the `allLocalMapEntities` rows. `type` = class, `Attributes>>init` = the init
  string, server-spawn flag rides in the entity description (`AP_SERVERSIDE`, the existing idiom).
- `AP_CUSTOM_P3D` — the 55 `.p3d` placements as `Land_HelipadEmpty_F` anchors; model name and scale
  ride in the description.
- `AP_COMP_<name>` — one layer per composition zone.

`apply` regenerates **only** from these layers and ignores everything else, so the designer's own
layers pass through untouched.

### Generation is text splicing, not re-serialisation

`tools/sqm_read.py` parses both sqm forms, but the only serialiser in the repo
(`sqm_strip_exported.py`) writes the **binarised** form, and the shipped sqm is now plain text. Rather
than write a text serialiser — a large, high-risk component whose failure mode is corrupting the
designer's file — generation copies the shipped sqm verbatim and **splices** the generated layer
subtrees into the entity list, bumping the enclosing `items=N`.

- Read path: parse (existing, proven).
- Write path: append-only splice into a copy. The designer's bytes are never rewritten.
- Generated entities take ids from a reserved high band (900000+) so they can never collide.

### Commands

```
python3 tools/map_codegen.py stage     # build MaldenEdit.Malden/mission.sqm from the code arrays
#   ...open MaldenEdit in 3DEN, drag things, save...
python3 tools/map_codegen.py apply     # rewrite the code arrays from MaldenEdit
```

`apply` regenerates `core/config/fn_mapData.sqf`, `custom_p3ds/malden_buildings.sqf` and
`compositions/zone_<name>.sqf`.

## Safety

- **Parse → re-parse invariant.** After splicing, the generated sqm must parse to the same entity-id
  set and dataType counts as the source plus exactly the generated entities. Fail loudly otherwise.
- **Deletion guard.** `apply` aborts on a >2% net row deletion unless `--allow-deletes` (the existing
  `mapdata_all.py` rule, kept).
- **Backups.** `.bak` before every write to a tracked file.
- **Text diff is the last line of defence.** `mission.sqm` is plain text by owner order precisely so
  silent damage is visible; `git diff` before committing stays mandatory.
- **`MaldenEdit.Malden` is git-ignored and never packed.** `deploy/pack_pbo.py` is not touched by this
  design — worth stating plainly, because a codegen hook there is what would reintroduce the
  double-spawn risk this variant exists to avoid.

## Known limitation: the `.p3d` anchors are invisible in 3DEN

3DEN can only place entities that have a `CfgVehicles` class from an addon. The 55 custom buildings
are raw `.p3d` files inside the mission, so they can only be represented as anchors — and
`Land_HelipadEmpty_F` renders as nothing, which makes precise placement guesswork.

Options, in preference order:

1. **`@AP_eden`, a tiny local 3DEN mod** — a `Cfg3DEN` event handler draws the real models on the
   anchors when the mission loads, and can add Import/Export toolbar buttons. This is the only option
   that keeps the "no console, ever" promise. Costs a mod folder on the launch line, and a copy for
   the designer if they ever need it.
2. **A one-line console paste** that draws the models (`edenCB_refresh.sqf` already does exactly
   this). Keeps Phase 1 shippable with no new infrastructure, at the cost of one paste.
3. **A stand-in vanilla class** with a similar bounding box, so at least something is visible. Crude,
   no infrastructure.

Phase 1 ships with (2); (1) is Phase 3. This is the one place where the design does not yet fully
deliver "no console" and it should not be papered over.

## Out of scope (stays code, deliberately)

- **Markers** — already covered by the standing rule: place in the shipped `mission.sqm` via 3DEN.
  `malden_markers.sqf` derives positions from `CfgWorlds`, so it is generative, not placement.
- **`replace_sheds.sqf`** — a runtime swap of terrain objects, not a placement.
- **Cartel flags** (`malden_cartels.sqf`) — six `createVehicle` objects with capture logic; could
  become sqm entities later, but they are gameplay state, not decoration.
- **`malden_atmosphere.sqf`** — lighting and cave setup, places nothing.
- **Dynamic gameplay spawns** — drug items, cop lights, spray paint, treasure chests, etc. These are
  runtime, not map content, and must never enter the editor.

## The designer's workflow does not change

They place objects, save, and send a `mission.sqm`. `stage` reads the shipped sqm fresh every run, so
their work flows in automatically. Eden ids are stable inside their mission, so
`mapdata_all.py delivery`'s add/remove/move diff remains the right tool for reviewing a delivery
before accepting it.

## Phases

| Phase | Deliverable |
|---|---|
| **0** | Migrate `fn_mapData` to the world frame (one-time, engine-assisted); `fn_createVehicleLocal` uses `setPosWorld` |
| **1** | `map_codegen.py stage` / `apply` for `AP_MAPDATA` + `AP_CUSTOM_P3D`; console line for `.p3d` visuals |
| **2** | Composition zones; NPC init fields verified end-to-end |
| **3** | `edit-map.sh` launcher; optional `@AP_eden` mod for auto-drawn visuals and toolbar buttons |

Phase 0 is a hard prerequisite — Phases 1+ cannot be built offline without it.

## Rule change this forces

`tools/MAP_EDITING.md` and `CLAUDE.md` both carry **"DO NOT SAVE the mission in 3DEN."** That rule
exists because the map layer is script-spawned, so a save re-bakes it into `mission.sqm`. Under D2 it
becomes two rules, one per file:

- **Shipped `mission.sqm`** — never save it from 3DEN. Unchanged, and still the rule that has been
  broken expensively.
- **`MaldenEdit.Malden`** — saving is the entire point.

Both documents must be updated in the same change that lands Phase 1; a half-updated rule here is
worse than the old one.
