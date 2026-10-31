# 3D map: real low-poly building silhouettes (replaces extruded boxes)

2026-08-27. Owner request: the MALDEN GRID 3D map (`ui/html/map.html`) should draw
every building as a low-poly version of its real model instead of an oriented box.
Same positions as today's rows. Source models = the island's own building p3ds.
Constraint driving "low-poly": renderer performance (and asset size — everything
ships as text assets read via `A3API.RequestFile`).

Approach chosen (owner-approved): **own-LOD pipeline** — every Arma model already
contains artist-made coarse resolution LODs; extract each distinct model's
coarsest visual LOD from the game PBOs, color it from the texture mirror, ship a
mesh library, and have the page batch real silhouettes exactly where it batches
boxes today. No per-building art, deterministic, box fallback everywhere.

## 1. Bake (SQF + harvester)

- `server/AP_server/core/TON/fn_mapBake.sqf`: every `[BLDUMP]` row gains a 9th
  field = the object's model path (`getModelInfo` on real objects; for the
  designer-table section the path is captured from the one-shot measurement
  spawn, cached per class). Synthetic rows (road-derived bridge decks, the
  hand-measured fed crossing) carry no path.
- `tools/harvest_map_bake.py`: assigns a mesh id (`mid`) per distinct path
  (first-occurrence order), writes
  - `ui/html/malden_bld.txt` — rows gain a trailing `mid` column (−1 = no mesh);
    old 7/8-column parsing stays valid, the page tolerates both,
  - `tools/map_model_paths.txt` — `mid<TAB>path` table for the mesh baker.
- Re-run once on the dev server (temporary boot call, then removed), harvest,
  done. Heightfield regenerates as a side effect; format unchanged.

## 2. Mesh baker — new `tools/bake_map_meshes.py` (offline)

Input: `tools/map_model_paths.txt`. Output:
`mission/Armapunk2035.Malden/ui/html/malden_msh.txt`.

Per distinct model:
- **Locate**: `a3\…` paths → search the game install's PBOs (base `Addons/` +
  DLC dirs; prefix from each PBO's `prefix` property) using the
  `~/blender_work/pboread.py` reader. Mission paths (custom skyline) → the
  mission's own MLOD files under `custom_p3ds/`.
- **Parse**: ODOL v64–74 via the decoder in `~/blender_work/odol73_to_mlod.py`
  (used as a library — we only need one visual LOD's triangles, not a full MLOD
  write). MLOD files parse via `~/blender_work/mlod_rw.py`.
- **LOD pick**: the coarsest *resolution* LOD (highest numeric resolution below
  the special-LOD band). Weld duplicate verts, drop degenerate faces, triangulate
  quads. Decimate only when over budget (~200 tris target; the generated
  single-LOD mission towers will need it, most terrain models won't — the baker
  reports the real distribution).
- **Color**: per-face texture → `textures_png/INDEX.txt` mirror → cached average
  color; `#(argb,…)color(r,g,b,a,…)` procedural textures → the literal color;
  no texture/no mirror hit → the model's kind color at page time. Quantized
  rgb444 per face, converted to per-vertex color in the page's VBO.
- **Frame**: verts emitted in page axes — `(east, north, up)` =
  p3d `(x, z, y − minY)`; plan coords relative to the model origin, up relative
  to the bbox floor, centimetre ints. Page rotates by the row's `dir` (clockwise
  from north) with the same 2D rotation it applies to box corners, seats the
  floor on the heightfield (or the row's absolute base), identical to boxes.

Format (`malden_msh.txt`): `# nModels`, then per model
`M mid nv nf` / vert lines (`x,y,z` cm ints, comma-joined groups) / face lines
(`a,b,c,rgb444hex`). Budget ≤ ~1.5 MB; if over, first lower the tri budget, then
tighten packing (base36 varints) — measured, not assumed.

## 3. Renderer — `ui/html/map.html`

- Close tier (< 10 m/px, today's extruded boxes): sector VBO builder consumes the
  mesh library — transform per instance (rotate `dir`, translate, seat base),
  per-vertex color attribute replaces the kind-color uniform lookup; lambert,
  fog, night rim and kind-4 acid/cyan treatment unchanged (kind still rides each
  vertex).
- Mid tier (flat footprints) and far tier (off): untouched — bbox columns remain
  in every row.
- Fallback: `mid == −1`, mesh missing from the library, or `malden_msh.txt`
  absent/failed parse → today's box path (per building; wholesale on parse
  failure). The page must render correctly with the old asset files alone.
- Budget: the per-sector draw cap counts triangles (~350k drawn ceiling) instead
  of buildings.
- Standalone stub: a few synthetic meshes so the page still reviews in a plain
  browser without game assets.

## 4. Errors / coverage / validation

- Baker prints a coverage table: models found / missing / fallback, tri stats
  (min/med/max, before/after decimate), output bytes. A missing model is a
  warning + box fallback, never a hole in the skyline.
- Mechanical cross-check: per model, mesh extents vs the bld rows' `sx,sy,sz`
  (median across instances of that mid). Loose tolerance (LODs shrink a little);
  gross mismatch (>25% or axis swap) = drop to box + loud report. This catches
  wrong pairing, axis-order and rotation-convention bugs offline.

## 5. Testing

- Golden: `tools/test_bake_map_meshes.py` — parse one known terrain model,
  assert tris ≤ budget, extents match its bld row; procedural-color and
  missing-texture paths covered.
- Visual: offline matplotlib/PIL render of a few baked meshes (silhouette
  eyeball), then the standalone page in a browser, then dev deploy + owner
  in-game look.
- Perf: the page's debug readout gains a drawn-tri counter; compare motion fps
  box vs mesh build.

## v2 (2026-08-27, same day): detail bump + fences + landmark shapes

- Tri budget 200 -> 500; LOD pick prefers the coarsest LOD with >=140 tris
  (small houses take a finer LOD when their far LOD is crude).
- A visual pick over 4000 tris swaps to the model's **shadow LOD** (res
  1e4..2e4, >=100 tris) with per-face colors transferred from the finest
  visual LOD by nearest centroid -- this is what gives the Grand Palace (and
  Bank/HQ/Jewelry) their real massing instead of a box or slab stack. The
  generated towers ship a 24-tri box shadow, so they keep the profile stack
  (now gated to tall models only: height > 1.3x plan span).
- **Fences/walls are kind 5**: their own bake sweep (nearestTerrainObjects
  WALL+FENCE, relaxed gate: area >=1.5 m2, height >=0.8 m) plus the designer
  table's wall/fence classes. The page draws kind 5 ONLY under 10 m/px (mesh
  tier; meshless fences get their own box sectors) -- zoomed out they are
  noise. Night window stripes are now bounded to kind 4 exactly. Vineyard
  trellises (7,348 pieces, WALL-classed crops) are dropped at harvest. Fence
  models bake at detail_min 0 / 40-tri cap -- 11.8k instances. Mesh sector
  VBOs build LAZILY on first draw (a ~1.5M-tri island cannot materialize at
  page load); near-black colors (the palace's color(0,0,0) glass facade) are
  floored to dark glass blue-grey at the bake.

## v3 (2026-08-28): code-review fixes

Bake: the ray-scan's `* (pi / 180)` is gone -- SQF trig takes DEGREES, so the
quarter-ray rotation had always been a no-op; designer fences no longer join the
ghost kill-list (they were deleting real terrain buildings standing beside them).

Baker: faces with no texture but an rvmat resolve their color through the
material's own `_co` reference (flat kind-color faces 57% -> 6.9%); `res 0`
counts as a visual LOD; both artifacts carry a `gen=` stamp hashing the path
list, and the golden test fails when they disagree (mids are positional, so a
re-harvest without a re-bake would silently put church meshes on sheds).

Harvest: a log with no model paths is refused instead of silently reverting the
whole feature to boxes.

Page: the mesh pass is PLANNED before the box pass, so any sector the tri budget
or the per-frame build limit skips still draws as boxes (nothing vanishes);
at most 2 sectors build per frame (a dense one is hundreds of ms of JS);
built mesh buffers are evicted with `gl.deleteBuffer` past ~900k resident tris;
fences draw on their own cap; a blank mid falls back to the box instead of
coercing to mesh 0; the `malden_msh.txt` fetch races a timeout so a client whose
mission predates the file cannot hang the load chain.

## v4 (2026-08-28): satellite hero window

The map layer was drawn from a 13×13 atlas of 256px tiles (~4.1 m/texel) while
the game ships those tiles at 1024² native. A 13×13 atlas of native tiles is
13312², well past what the earlier 512 attempt proved unusable. So the detail
lives in a **hero window** instead: a 3×3 window of native tiles in its own
3072² texture, re-centred on the camera under 6 m/px, cross-faded into the
atlas over the outer 6% of its edge. Inside it the ground is 1.03 m/texel —
2.5× the measured edge energy, and footpaths, individual trees and vineyard
rows appear where there was a smear.

Cells seed from whatever the atlases already hold when the window moves, so it
is never blank; tiles arriving for a window the camera has already left are
dropped; each arrival sub-uploads only its own cell; and initHero carries the
same getError halving guard the atlases use.

Verification note: `--dump-dom` headless runs never paint, so rAF never fires
and every in-page probe reads a page that never drew. Drive `draw()` from a
timer for deterministic renders.

## v5 (2026-08-28): the map opens on the player, in 3D

Owner call. The screen used to open top-down over the whole island; it now snaps
to the player at HOME_DIST 900 / HOME_TILT 52 degrees, north-up, on the first
`map` push that carries a position (position is not known before that, so the
island view is what the first frame or two shows). Any gesture, wheel or zoom
button before that push cancels the home, so it never yanks a hand already on
the map, and a >5 s gap in the 1 Hz stream re-arms it for the next open.

Top-down stays a first-class state per MAP3D_SPEC §4 -- the 2D toggle and the
tilt gesture reach it; it is simply no longer the default.

Also fixed here: the standalone stub bus exposed only on/_push, so the page's
opening `AP.call("log", ...)` threw inside the WEBUIReady .then as a silent
unhandled rejection and EVERY AP.on() below it went unregistered. Standalone
review had no self blip, no squad and no markers, which read as missing data
rather than a broken stub. The stub bus now answers call/ask/handle/get.

Out of scope: texture atlases/UVs, interiors, LOD morphing, any change to the 2D
map or the live-data bridge. Work lands on `main` (current dev rule), normal dev
deploy.
