# LESSONS.md — Arma 3 building pipeline, distilled from the 20-story skyscraper project
For starting the luxury skyscraper (or any enterable Arma building) with zero re-learning.

## What the deliverable is
- `tower.js` — fully parametric three.js model (all dims are constants; a luxury remix starts by editing these). Every mesh/material NAMED; names become OBJ `o`/`usemtl`.
- `skyscraper.html` — three-d-stage viewer; user downloads OBJ+MTL from its toolbar after EVERY change.
- `doors-manifest.json` — single source of truth for doors (leaf box, hinge axis line, trigger point, open angle, kind). model.cfg + config.cpp + SQF spawners are all GENERATED from it; never hand-write per-door config.
- `ARMA3_HANDOFF.md` — the contract with Claude Code (texture table, LOD mapping, coordinate rules, checklists).
- Ripped-asset data files (reusable as-is in the new project): `ac-unit-data.js` (jewelry AC unit), `door-leaf-data.js` (House_Big02 green door leaf).
- Process rule: fresh zip ("handoff vN") after every change + fresh OBJ export; Claude Code converts to .p3d (we cannot emit .p3d directly).

## Textures (base game only)
- Verify paths by extracting them from reference MLOD p3ds — never guess. Known-good set used here: i_barracks_v1_walls_co (interior plaster), concrete_clean_co (facade), concrete_floor_03_co (slabs/stairs), hotel_02_floor_co (room parquet), tile_04a_co (lobby), airport_02_terminal_bitumen_co (roof), rollup_combo_co (metal/elevator panels), window_set_dark_2_ca + glass.rvmat (glazing), wooden_bridge_co (door frames).
- Procedural colors `#(argb,8,8,3)color(r,g,b,1,co)` are base-legal (use for trim/markings; pair metals with metalclean1.rvmat).
- ATLAS textures (office_addons_co, window_set_dark_2_ca, house atlases) look like garbage with world-scaled UVs — either rip authentic UVs from a donor mesh, or pin each face's UVs into a measured clean region (glass: u .46–.62, v .44–.77 OBJ-space of window_set_dark_2).
- House_Big02-style assets are MULTIMATERIAL: face texture is EMPTY, the whole look lives in the rvmat (e.g. i_house_big_02_b_pink_multi2.rvmat). Map explicitly or converters fall back to a random texture (the "roof tile doors" bug).
- Tiling textures on segmented walls need WORLD-ALIGNED UVs (uv = worldCoord/2m chosen per face normal axis), not per-box 0-based UVs — else the texture bands misalign at every doorway.

## Ripping from reference p3ds (MLOD only)
- MLOD layout: "MLOD" + lodCount @8; per LOD "P3DM", nPoints@+12, nNormals@+16, nFaces@+20, data @+28; points 16B (xyz+flag); normals 12B; face = nVerts u32 + 4×(point u32, normal u32, u f32, v f32) + flags u32 + texture asciiz + rvmat asciiz; then "TAGG" list (1B active + name asciiz + size u32 + data), selection data = nPoints weight bytes then nFaces bytes, until #EndOfFile#, then resolution f32, next LOD.
- Memory LOD (resolution ~1e15) holds door_N_axis / door_N_trigger POINTS — rip these to learn BI's hinge conventions.
- ODOL (binarized) is effectively unreadable (LZO-compressed arrays) — demand an MLOD conversion; check magic, don't trust filenames ("ignore the header" was wrong once).
- Tool-converted MLODs may ZERO all selection weights — fall back to geometric hunting: union-find connected components over shared points, filter by bbox (door ≈ 1.0×2.1×thin, at ground y).
- Flip V (v' = 1−v) when exporting UVs to three.js/OBJ space. Reverse quad winding ([0,2,1],[0,3,2]) for outward normals.
- PBO header file listing is readable via TEXT reads (filenames are ASCII at the top) — good for inventory even when the binary is too big to copy (30 MiB copy limit).

## Collision doctrine (the invisible-wall saga)
- EVERY Geometry LOD component must be one convex box. Pre-split all collision meshes into per-box objects (`F07_slab_c03`) in the export so no converter ever hulls a merged group — hulling fills stair holes/doorways ("invisible wall").
- Stairs: one mesh PER FLIGHT (`_stairA/_stairB/_stairLand`) — a per-flight hull degrades to a walkable ramp wedge, never a ceiling over the mid-landing.
- Flights are sloped-waist tread stacks (box per tread, bottom = top − rise − 0.16), NEVER solid-from-floor stacks — solid stacks put the next story's mass into the stairwell headroom (you bonk at the mid-landing).
- Exclude from Geometry: stair rails, window frames/mullions, signage. Roadway = top faces of slabs/coverings/treads/landings. Fire = Geometry + glass as separate penetrable components.
- Audit recipe: any Geometry component intersecting the stair shaft must match a visible box 1:1; anything bigger is a stray hull.

## Doors
- Working engine doors need FOUR things: door_N selection in resolution LOD, door_N_axis (2 pts) + door_N_trigger (1 pt) in Memory LOD, model.cfg skeleton bone + rotation anim per door, config.cpp AnimationSources (source="user", animPeriod, sound + soundPosition) PLUS UserActions Open/Close pair (condition on animationPhase, statement `this animate`). AnimationSources without UserActions = doors defined but untriggerable (first failure).
- model.cfg CfgModels class name MUST equal the p3d filename, and model.cfg must sit beside the p3d at pack/binarize time — silent no-op otherwise.
- BI's richer vanilla pattern (from House_Big02 config): triple sources (Door_N_sound_source/_noSound/_locked), BIS_fnc_Door statements, bis_disabled_Door_N lock variable — regenerate to this pattern when lockable apartments are wanted.
- CONFIG DOORS REQUIRE AN ADDON PBO loaded by server+clients. Mission-folder p3ds spawned as simple objects have NO simulation → config doors can never work there. No-addon route: strip leaves from the building, export leaf as its own p3d (hinge line re-origined to local Y axis at 0,0,0), spawn per doorway from the manifest via SQF (modelToWorld, setVectorDirAndUp, addAction, per-frame lerp, JIP publicVariable state).
- Hinge convention used everywhere: axis at the min-x jamb (doors along X), leaf extends +X; angle sign = right-hand rule about axis bottom→top (+y): N-side doors −100°, S-side +100°; rotate the ripped leaf 180°/±90° for other orientations rather than mirroring (mirroring breaks winding).
- Scale a ripped leaf from its hinge to overlap the frame's inner faces by ~15 mm — a verbatim leaf leaves a visible gap (and can bury itself in the wall on narrower openings).

## Coordinates & mirroring
- Author in Arma convention directly: X east, Y up, Z north, meters, origin at plan center, base y=0. Import RAW — no negation.
- Mirrored in-game TEXT is the canary for an axis-negating import; it also strands manifest memory points on the wrong side (doors hinge wrong / misfit). Mesh and manifest must share one coordinate space.
- Readable-text mirroring in the SOURCE: a sign viewed from the −normal side reads backwards; glyphs on faces whose normal is −z must be built mirrored (flip param). Verify per sign which side the viewer stands on.

## Z-fighting rules (also helps in-game)
- Never butt-join coplanar faces: overlap intersecting walls by ~0.05 into each other; sink glass/mullions/columns 5 mm into surrounding solids; float coverings 2–5 mm above slabs; door frames overlap 20 mm INTO their openings (kills jamb flicker).
- 7-seg digit signage from boxes = base-legal numerals (plates metal-dark proc, digits white proc); readable, exports clean.
- Glow/neon strips: never lay them flush ON a face (coplanar z-fight in-game) — recess them in a groove: split the host band into lower/upper boxes leaving a slot, glow box outer face ~.04 behind the band face.
- Faceted arc bands: place chord boxes so OUTER CORNERS sit on the target circle (r_center = R·cos(step/2) − t/2) — centering boxes ON the circle makes corners bulge past the facade (flicker, collision lumps, footprint overshoot).

## This tower's specs (baseline for the luxury remix)
24×24 m, 20 stories: lobby 5.0 m + 19×3.4 m, roof 69.9 m, parapet 71.16. Slab 0.28. Core 9×5.2 at center: switchback stair west (lanes 1.3 m, run 2.6, mid-landing S), elevator shaft east (sealed per floor by rollup panels — scripted elevator planned). Ring corridor 2 m; 4 L-shaped rooms/floor, doors at x=±3.3 on ring N/S walls; signage: floor number in corridor + stairwell, room plates NN01–NN04. Facade: concrete spandrels + 1.5 m ribbon glazing + mullions; lobby storefront + canopy + fixed-open glass panes (no ground-floor functional doors). Roof: hut over stairs, helipad E, 3 ripped AC units W, vents, mast. 96 wired doors (19 stair + 76 room + 1 hut), green House_Big02 leaf.

## Session workflow lessons
- One parametric source file beats hand-edits; every fix was a constant or rule change.
- Verify interiors with throwaway debug HTML (own camera/clipping) — the stage only shows the exterior.
- Iterate against the USER'S in-game screenshots; every "texture looks wrong" had a mechanical cause (atlas UVs, material fallback, mirroring).
- Keep handoff + generated configs in lockstep with the model in every zip; Claude Code follows the handoff literally — make failure symptoms explicit in it.
