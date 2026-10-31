# Skyscraper20 generation pipeline

> **2026-09-04:** the PARKING GARAGE (`ap_garage_5f_*`) was removed from the project
> (owner: not using it) along with its build script, harness, verifier and dumps. Anything
> below describing three buildings now describes two. Kept as a record of how it was built.

## Rev sync 2026-08-06 late: b3 / v11 / v2 — foundations + holograms
Three zips (progressive snapshots of one designer workspace; the latest,
garagev2.zip, carries the final state of all sources). All three buildings
gained a **3 m foundation plinth** (base y −3, inset 0.06) for sloped-terrain
placement — Geometry/Fire only, never Roadway; autocenter shifts −1.5, so
door-gen ZC/YC and every alt offset changed (gen_* headers updated). Built:
`Skyscraper20_r13.p3d`, `skyscraper30_r3.p3d`, `ap_garage_5f_r2.p3d` — all
three verify suites ALL PASS.

Lux v11 additionally ships the **hologram layer** (katakana ad spine, koi,
clock, crown ticker, holo-manifest.json). The animated wiring (koi orbits,
ad rotors, blink cycles, clock hands) is model.cfg = the ADDON route, so
those meshes are baked STATIC in the p3d (spinners frozen, blinks on).
The **crown ticker** uses the handoff's own no-addon route:
`tools/gen_lux_ticker.py` → `custom_p3ds/lux_ticker_data.sqf` (49 crown
path points, manifest→model frame with the r3 ZC/YC) +
`custom_p3ds/lux_ticker.sqf` (client drawIcon3D marching text, wired
per instance by the model sweep). Holo meshes are excluded from Geometry
(TICKER_band/posts stay collidable per handoff); verify_lux's exterior-plane
winding audit now skips holo-textured faces — thin blade boxes ON the facade
plane legitimately have back faces.

Garage v2: ramp lanes widened 6.9→7.95 m (wall-to-divider), parapets sunk
5 cm (z-fight), plus the foundation. Census 285→286.

Placements: the jewelry-emporium tower pair and the La Trinite garage were
DELETED (owner call — they re-place from the MaldenEdit compositions). The
owner's Latrinite lux copy was retargeted to r3 with z preserved at the
lobby plane (foundation extends below). make_compositions.py now emits a
composition for EVERY TOWER_ALT model even with zero placements — a deleted
placement must not delete the composition that would put it back — and the
stale r12/r2/r1/asylum composition folders were pruned by hand (the tool
does not prune).

## ALSO: 5-level parking garage (2026-08-06, "garagev1.zip")
`ap_garage_5f_r1.p3d` — from `garage.js` + `garage-manifest.json` +
`ARMA3_HANDOFF_GARAGE.md`. Simplest pipeline member: every mesh is ONE convex
box, so `harness_garage.mjs` (no patches — clean ESM source) → `build_garage.py`
(visual verbatim + per-mesh Geometry components + sloped-quad Roadway + Fire
copy + Shadow) → `verify_garage.py` (15 gates ALL PASS; notable: analytic
drive-path gate walks grade→roof at DESIGN heights — a nearest-height sampler
without expected heights just follows the grade slab under the ramps, and a
max-height sampler grabs the roof; stacked floors make both wrong). No doors,
no anims, no model.cfg (handoff). halfHeight 8.711. Placed [7270,7788] dir 180
(entrances face the street), z 176.121 — site picked by the in-game terrain
scan `debug/garagesite.sqf` (mapData z-spread proxies LIED: 0.2 m predicted,
1.7 m real at the first site; only getTerrainHeightASL is truth), verified by
`debug/garageprobe.sqf` (corners 0.00 spread; note: rays do NOT report
buried-below-terrain surfaces — a MISS on an underground slab is burial, not
absence). The garagev1 zip also carried a lux-tower.js HOLOGRAM layer update
(katakana ads/koi/clock/ticker + holo-manifest.json) — NOT applied, archived
as `lux-tower.js.holo-pending` + `holo-manifest.json.pending`; the committed
lux-tower.js remains the exact skyscraper30_r2 source.

## ALSO IN THIS DIRECTORY: Skyscraper30 "Lux" (2026-08-06)
`skyscraper30_r1.p3d` — 30-story luxury tower from "30-Story Luxury Skyscraper
Model.zip" (`lux-tower.js` + `lux-doors-manifest.json` + `ARMA3_HANDOFF_LUX.md`
+ the designer's `LESSONS.md`, which distills this whole project's doctrine).
Pipeline: `harness_lux.mjs` -> `build_lux.py` -> `verify_lux.py` (40 gates ALL
PASS). Notables: geometry uses a HYBRID scheme — axis-aligned islands go
through merged-column pooling, rotated prisms are template-stretched runs, and
the whole facade/glazing/parapet is an analytic full-height PERIMETER SHELL
(~35 convex prisms: 4 walls + 3x8 arc chords + NE chamfer) because per-facet
components exploded the file to 361 MB (selection taggs are quadratic). Glass
is SOLID (documented deviation: full-height suite glazing with no body
collision = fall hazard). The lux source authors sign chirality CORRECTLY
(LESSONS applied upstream), so the segDigits inversion patch is 20F-ONLY —
harness_lux omits it. 88 doors via the same no-addon system (`lux_doors.sqf`,
own AP_LUXDOOR_* state, three synthesized metal leaves lux_leaf_92/94/106);
per-machine calibration measured the lux leaf policy independently (2.160 vs
the 20F leaf's 2.198). Probe: 363/364 traversal over 30 floors (the F1
slip-under artifact only), doors swing exactly -100 deg, terrain spread 2.5 m
at [7499.5, 10443.8] dir 40 (SE of the 20F tower). The zip also ships a
REFACTORED 20F tower.js — NOT applied; the archived tower.js here remains the
exact r12 source.


`Skyscraper20_r6.p3d` (mission root) is **generated** — do not hand-edit the p3d.
Source of truth is the owner's three.js prototype (`tower.js` + `ac-unit-data.js`
+ `doors-manifest.json`, delivered 2026-08-05 as "20-Story Skyscraper Model.zip",
sixth drop; each drop replaces the previous one) plus the converter here.

r6 (sixth drop, 2026-08-05): 100 swinging doors wired for the ENGINE-door addon
route (`doors-manifest.json` + `model.cfg` + `config.cpp`, all archived here).
`createSimpleObject` cannot animate, so until the owner picks a door
architecture (see PR #7) every leaf is **baked static at 165 deg open** — sign
per model.cfg, magnitude ours: at the manifest's 100 deg animation end-stop a
static leaf stands ajar, and the stairwell leaves jutted into the north-landing
walk line (probe b0296). `door_3` (S exit) additionally flips inward so the
open leaf cannot extend the bbox — the model AUTOCENTERS, so a grown bbox
silently slides the whole placed building (~0.5 m; asserted now).

**Stairwell is traversal-PROVEN**: `debug/stairprobe.sqf` walks an
animation-driven AI capsule lobby -> roof-hut -> helipad and back, 244/244
waypoint segments (dev b0298). Three findings baked into the converter:
(1) roadway stairs are PER-TREAD step quads — ramp roadway stalls the walking
capsule (F1 flight is 43.9 deg, standard flights 33.2 deg); geometry keeps the
solid wedges under the treads; (2) `_stair_rails` are fully excluded from
Geometry per the handoff (well-guard boxes left ~0.59 m end-gaps at the
mid-landing turn — capsule-diameter squeeze); (3) probe drives must use
playMoveNow root motion, never setVelocity — raw velocity bypasses the engine's
step-up logic and cannot climb any staircase, which reads as phantom collision.

r5 (fifth drop, 2026-08-05): elevator shaft SEALED by fake `F##_elevator_door`
panels (rollup_combo_co slats; separate named meshes per floor for a future
scripted elevator — they get one collision box each). Stairs split into
`_stairA/_stairB/_stairLand` meshes per floor — converter now reads those
registry keys directly (no x-filtering) and asserts 20 flight sets, so a rename
re-drop fails loudly instead of silently building zero stair collision. All
wall/slab UVs are world-aligned via the prototype's new `alignUV` (continuous
bands across segments; our V-flip preserves continuity). BB() was rewritten in
the drop (inline BoxGeometry + alignUV) — the negative-size normalization patch
moved to the new needle; the swapped-bounds bug is still in the design source.
Roadway verified coordinate-identical across the stair restructure.

r12 / handoff v9, NO-ADDON doors (owner pivot, 2026-08-05 night): the addon
route (model.cfg/config.cpp engine doors) was briefly built and then reverted
on the owner's call — the mission must stay vanilla-client. Final architecture:
- `Skyscraper20_r12.p3d` — building with door leaves EXCLUDED from every LOD
  (doorways open, frames/signs/entrance panes stay) + a Fire Geometry LOD.
- `door_leaf_wide.p3d` (1.065, from door_20) + `door_leaf_narrow.p3d` (0.965,
  from door_1): hinge re-origined to the local Y axis, leaf +X, pink multi2
  rvmat, LODs resolution/Geometry(1 box)/View/Fire.
- `tools/gen_skyscraper_doors.py` → `custom_p3ds/skyscraper_doors_data.sqf`
  (96 × [hinge modelToWorld coords, yawAdd, kind, openAngle], from the manifest).
- `custom_p3ds/skyscraper_doors.sqf` — per-machine local leaf spawner +
  addAction Open/Close + 0.6 s lerp + vanilla door sounds + ap_doorLocked flag;
  state = public array AP_SKYDOOR_STATE (JIP-safe). The engine AUTOCENTERS
  simple objects, so every animation frame sets dir AND pos (center = hinge +
  R(yaw)·centerOffset) — the pivot is the true hinge regardless.
Probe-verified on dev b0309: 96 leaves spawn, state-flip swings measured at
exactly -100.0° on both test doors, stairwell 241/244 with the hut door
scripted open (3 fails = the known F1 slip-under artifact). The leaf p3ds log
a benign "2nd UV set needed" warning (multi rvmat wants UV2 — same class as
the palace baseline warnings).

r10 / drop 7 (2026-08-05 late): 96 doors (ground floor is deliberately
door-free: fixed open `F01_entrance_leaves` panes + open passages), wood leaves
ripped verbatim from `i_House_Big_02_b_pink_F.p3d` — the pink house we
unbinarized earlier the same evening fed the designer's tool
(`door-leaf-data.js`, MULTIMATERIAL: empty texture + the pink multi2 rvmat;
UVs proven pre-flipped 8/8 like the ACs, so the global V-flip restores them).
Manifest angleDeg is now SIGNED (single source of truth; model.cfg
cross-checked). 7-segment signage meshes (`_sign_plates`/`_sign_digits`) are
visual-only per the handoff — the suffix filters exclude them from
Geometry/Roadway automatically. config.cpp switched to `source="user"`
AnimationSources + 192 UserActions with `door_N_trigger` memory points (still
the addon route, awaiting the owner's architecture call). Stair fix verified
untouched: headroom gate 0 blocked, roadway + stair-shaft geometry
value-identical to r9 (the only delta is F1's removed stairwell door leaf),
traversal probe 241/244 (F1 slip-under artifact ×2 + one 1-in-40 diagonal
corner shave on the owner-approved guard slab end).

r4 (fourth drop, 2026-08-05): glass UVs pinned into the clean pane region of
`window_set_dark_2_ca` (the rest of that texture is painted frames; the drop's
new screenshots show the jewelry storefront target look). Implementing it
surfaced the **UV V-convention bug**: three.js/OBJ v runs bottom-up, p3d v runs
top-down, and r1–r3 wrote viewer v verbatim — every generated texture shipped
v-inverted (invisible on symmetric concrete/tile; the r3 ACs sampled the wrong
atlas rows). Proven by provenance: each distinctive `ac-unit-data.js` v exists
in the jewelry p3d only as `1-v`. The visual-LOD write now flips (`1 - v`,
tiling-safe), and verify pins both regions in arma space: glass u .46–.62 /
v .232–.557, ACs v .745–1.0 (= the jewelry original). A missing OR doubled flip
now fails the suite. The zip also carries a `CLAUDE.md` note for the designer's
own viewer-side agent (zip/OBJ export reminders) — deliberately not copied here.

r3 (third drop, 2026-08-05, after the owner's in-game playtest of r2): glass
REVERTED to `window_set_dark_2_ca` + `glass.rvmat` — the r2 procedural
armored-glass combo rendered as an opaque lavender wall in game (the drop's
`uploads/*.png` are the owner's screenshots of it). Roof AC units are now
verbatim JewelryBuildingModel meshes (`ac-unit-data.js`, authentic
`office_addons_co` atlas UVs — never re-UV them); their collision is a plain
asserted 1.45 x 1.07 x 2.94 box each per the handoff. The viewer now pre-splits
collision groups into one object per box (`F07_slab_c00`...) for the Object
Builder route; our harness records the registry at `mesh()` ENTRY, keyed by the
BASE name, so the synthesis keys are unchanged — build_p3d iterates the registry,
not the scene names. `package.json` is committed and must keep
`"type": "module"` (`ac-unit-data.js` is ESM in a `.js` file; npm-init's
`"type": "commonjs"` default breaks the import).

r2 (second drop, 2026-08-05): stair flights became thin floating treads
(collision is unchanged wedge ramps, so the visually open under-stair triangle is
still solid — deliberate: per-tread components would stutter movement and ~triple
component count; r3's handoff now explicitly blesses the ramp approach). Floor
level per flight is derived from tread TOPS (uniform-spacing assert) because
tread bottoms hang 0.16 m below the floor line.

## Regenerate

```bash
npm install                        # once, in this directory (package.json pins three + type:module)
node harness.mjs tower_dump.json   # headless geometry export (browser stage replaced)
python3 build_p3d.py               # tower_dump.json -> Skyscraper20_rN.p3d
python3 verify_p3d.py              # structural checks vs reference conventions — must ALL PASS
```

Then copy the p3d into `mission/Armapunk2035.Malden/`, **bump the `_rN` suffix**
(Arma caches models by path — p3dmemories.md §2) and update the filename plus the
printed `halfHeight` in `custom_p3ds/malden_buildings.sqf`.

Note: `build_p3d.py`/`verify_p3d.py` resolve `tower_dump.json` and the output p3d
relative to their own directory (run them from any checkout). The reference p3ds
are read from `uploads/` if that dir exists (the zip layout), else from the
mission root, where the same two files ship byte-identically.

## What the pieces do

- `skyscraper.html` + `three-d-stage.js` — the original browser viewer (kept for
  provenance; not used by the pipeline).
- `tower.js` — pristine design source, never edited. `harness.mjs` patches it AT
  LOAD (each patch asserts its needle matches exactly once): normalizes the
  negative-size `BB()` calls (the prototype's south/west facade is inside-out and
  invisible in the browser — winding AND normals mirrored), and records a
  per-primitive registry used to synthesize collision.
- `build_p3d.py` — builds the 4-LOD MLOD (visual 1.0 / shadow 11002 / Geometry 1e13 /
  Roadway 3e15) with the conventions measured off the palace + jewelry models
  (`analyze_refs.py`): inward RH winding, stored normal = winding normal,
  partitioned ComponentNN selections, uniform #Mass# 1e10, computed #SharpEdges#,
  roadway faces wound down with the concrete penetration rvmat.
- Geometry components are vertically MERGED (identical plan footprints across
  floors fuse into columns; selection taggs cost npts+nfaces bytes EACH, so
  component count is quadratic in file size: unmerged 1103 comps = 22.8 MB,
  merged 598 = 11.8 MB). Stairs are wedge prisms; sloped handrails and window
  mullions have no collision by design. Glass IS solid in the Geometry LOD
  (windows block movement and bullets; the open elevator shaft stays open).

## Known deltas from the handoff doc

`ARMA3_HANDOFF.md` assumed the Object Builder + addon (config.cpp) route. This
repo ships mission-embedded MLOD via `createSimpleObject` instead — same route as
the ten designer buildings, no mod required. No Fire Geometry / View Geometry /
Memory / Paths LODs (references ship without them too; Geometry is the bullet
fallback). Interior door lintels DO have collision (headers kept per floor).
