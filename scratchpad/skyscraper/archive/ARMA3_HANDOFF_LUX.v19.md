# Lux Tower (30F) — Claude Code handoff (OBJ/GLB → P3D)

Source: `luxury.html` viewer → **Download OBJ + MTL**. Meters, Y-up, origin at plan center,
base y=0, entrance faces **+Z**. UVs world-scaled (1 tile / 2m) EXCEPT the pinned/authentic
UV meshes flagged below. Same pipeline doctrine as the 20F tower (`ARMA3_HANDOFF.md`) —
everything below is self-contained for this building.

## Coordinate convention — READ BEFORE IMPORTING
OBJ is authored in Arma convention already: **X east, Y up, Z north**. Import RAW — NO axis
negation/mirroring. Mirrored sign text in-game ⇒ your import mirrored an axis (and the
manifest memory points no longer match the mesh). Buldozer acceptance: suite plate "07"
reads normally; each door leaf hinges on its `door_N_axis` side.

## Building facts
- 36 × 36 m plan, **2077 massing**: NW/SW/SE corners are R9 rounded-glass quarter-cylinders;
  the NE corner is **cut by a flat 45° chamfer wall** from (9,18) to (18,9) — a ~12.9 m wide,
  full-height dark billboard plane with 3 glass slits, magenta-framed, continuing as a 9 m
  blade fin above the roof. **That flat chamfer face is the reserved holographic-ad canvas —
  keep it clean, no extra geometry.**
- 30 stories: lobby 6.0 m + 29 × 3.6 m; roof deck 110.7 m; blade top ~119.9 m.
- Floor 1: double-height lobby — stone floor, glass storefront, violet neon entrance portal
  (fixed-open glass panes, NO functional ground-floor doors), canopy, reception desk, 4 columns.
- Floors 2–30: ONE full-floor suite each: fitted kitchen run on the W wall, shower + toilet in
  the bath, open living wrapping the core, master bedroom NE (door at x=10 on z=7 wall), bath (door at x=5.2),
  floor-to-ceiling glazing on all sides.
- Core every floor: switchback stair west (lanes x −5.9..−4.6 / −3.1..−1.8, run 3.2 m),
  TWIN elevator shafts east, **sealed per floor by static `F##_elevator_doors` panels**
  (scripted elevator later; shafts open top to bottom behind them).
- Roof: tiled deck, neon-edged parapet following the rounded plan, stair hut, helipad NE
  quadrant with neon ring + white H, rooftop bar + lounge SE, dance floor SW with two speaker stacks, 4 ripped AC units, vents, mast, blade fin.
- Neon: cyan slab-edge ring per floor (straight runs + faceted arc chords), magenta strips
  framing ONLY the ad corner + blade edges, violet entrance portal/lounge accents.

## Material → texture map (Face Properties)
| usemtl | texture | rvmat |
|---|---|---|
| concrete_panels_co | `a3\structures_f_enoch\data\concrete\concrete_panels_co.paa` | — |
| gallery_wall_plaster_a_co | `a3\structures_f_aow\civilian\gallery_01\data\gallery_wall_plaster_a_co.paa` | `a3\structures_f\data\metal\metalclean1.rvmat` (satin paint) |
| glass_blackout_proc | `#(argb,8,8,3)color(0.02,0.03,0.04,0.94,ca)` | `a3\structures_f_exp\data\glass\glass.rvmat` (blackout mirror: super-glossy, near-opaque) |
| glass_interior_proc | `#(argb,8,8,3)color(0.81,0.89,0.92,0.16,ca)` | `a3\structures_f_exp\data\glass\glass.rvmat` (interior panes: light uniform tint) |
| concrete_floor_02_co | `a3\structures_f_enoch\data\floor\concrete\concrete_floor_02_co.paa` | — |
| gallery_floor_parquet_b_co | `a3\structures_f_aow\civilian\gallery_01\data\gallery_floor_parquet_b_co.paa` | — |
| marble_tiles_01_co | `a3\structures_f_exp\data\tiles\marble_tiles_01_co.paa` | — |
| marble_tiles_02_co | `a3\structures_f_exp\data\tiles\marble_tiles_02_co.paa` | `a3\structures_f\data\metal\metalclean1.rvmat` |
| house_big02_multi2 | `a3\structures_f_enoch\data\wood\woodfine_01_co.paa` | `a3\structures_f\data\metal\metalclean1.rvmat` (satin lacquer) |
| door_brass_proc | `#(argb,8,8,3)color(0.75,0.63,0.35,1.0,co)` | `a3\structures_f\data\metal\metalclean1.rvmat` |
| rollup_combo_co | `a3\structures_f\data\metal\rollup_combo_co.paa` | — |
| office_addons_co | `a3\structures_f\civ\offices\data\office_addons_co.paa` | `a3\structures_f\data\metal\metalclean1.rvmat` |
| metal_grey_proc | `#(argb,8,8,3)color(0.55,0.57,0.59,1.0,co)` | `a3\structures_f\data\metal\metalclean1.rvmat` |
| metal_elevator_proc | `#(argb,8,8,3)color(0.78,0.80,0.82,1.0,co)` | `a3\structures_f\data\metal\metalclean1.rvmat` |
| metal_dark_proc | `#(argb,8,8,3)color(0.14,0.15,0.18,1.0,co)` | `a3\structures_f\data\metal\metalclean1.rvmat` |
| white_marking_proc | `#(argb,8,8,3)color(0.90,0.90,0.88,1.0,co)` | — |
| neon_cyan_proc | `#(argb,8,8,3)color(0.050,0.720,1.000,1.0,co)` | `mpmissions\__cur_mp.Malden\neon_cyan.rvmat` |
| neon_magenta_proc | `#(argb,8,8,3)color(1.000,0.060,0.550,1.0,co)` | `mpmissions\__cur_mp.Malden\neon_magenta.rvmat` |
| neon_violet_proc | `#(argb,8,8,3)color(0.620,0.250,1.000,1.0,co)` | `mpmissions\__cur_mp.Malden\neon_violet.rvmat` |
| dancefloor_proc | `#(argb,8,8,3)color(0.20,0.10,0.40,1.0,co)` | `mpmissions\__cur_mp.Malden\neon_violet.rvmat` |

Notes:
- The three neon rvmats are MISSION-LOCAL files that already ship in your Malden mission
  (same paths your Grand Palace p3d uses). If this building becomes an addon, either keep
  the mission paths (works when the mission is loaded) or copy the rvmats into the addon
  and repath.
- **Glazing is TWO panes.** `*_glass` is the outer skin (blackout mirror — what the street sees);
  `*_glass_inner` is the same plan shrunk 8 cm inboard, carrying the light uniform interior tint
  (what occupants see). Both are untextured proc colors — no UV work needed, and nothing is
  coplanar between them. Keep both, or the facade reads black from one side.
- **`door_N` leaves**: dark walnut veneer slab + a proud moulding frame on BOTH faces (two
  panels split by a mid rail), material `house_big02_multi2` (woodfine_01 tinted, satin rvmat).
- **`door_N_hw`**: the brass hardware for that leaf — lever sets + rose plates on both faces,
  kick plates, latch-edge strip; material `door_brass_proc`. It is a SEPARATE object so it can
  carry the brass material, but it belongs to the SAME selection as the leaf: assign both
  `door_N` and `door_N_hw` to selection `door_N` so the hardware swings with the door.
- **`ROOF_ac_01..04`**: authentic office_addons atlas UVs — do not re-UV; if they render as
  a wrong texture, your mapping fell back.
- AC Geometry: plain 1.45×1.07×2.94 boxes, not the detailed meshes.

## Mesh naming
`F{01..30}_*` + `ROOF_*` + `NEON_corners` + `FOUNDATION_c*` (3 m deep concrete plinth under
the whole footprint, inset 0.06 from the facade line — for placement on sloped terrain;
base y = −3): `_slab`, `_walls_interior`, `_floor_wood`/`_floor_bath`/
`F01_floor_stone`, `_ceiling` (flush plaster panels 4 mm under the slab above — visual only, same material as the walls),
`_stairA/B/Land`, `_stair_rails`, `_elevator_doors`,
`_sign_plates`/`_sign_digits`, `_facade_dark`, `_glass`, `_glass_inner`, `_window_frames`, `_neon_ring`,
`_door_frames`, `F01_reception*`, `F01_columns`, `ROOF_bar*`, `ROOF_lounge*`, `ROOF_helipad_*`, `ROOF_hut`,
`ROOF_ac_01..04`, `door_1..door_88`. Collision groups are pre-split one object per convex box (`_cNN`).
SLABS are the exception since v18: `F##_slab` / `F##_floor_*` / `F##_ceiling` are ONE
plan-shaped object each (extruded outline, real shaft holes — concave, Resolution LOD only).
Their convex collision lives in the hidden `GEO_F##_slab_c*` boxes nested inside each slab:
import those into Geometry/Fire, and DELETE every `GEO_*` object from Resolution 1.0.

## Curved geometry — conversion notes
- Rounded corners are built collision-safe: slabs/coverings use **solid quarter-cylinder
  wedges (8 segments, convex — one Geometry component each)**; spandrel/parapet arcs are
  **faceted chord boxes placed so their OUTER CORNERS sit exactly on the plan circle**
  (r_center = R·cos(δ/2) − t/2) — nothing bulges past the facade plane or the footprint.
  The NE chamfer is rotated boxes, wall inset so its outer face lies ON the chamfer line.
  All convex, all 1:1 components.
- **All neon strips sit in recessed grooves**: spandrel and parapet bands are split into
  lower/upper `_c*` boxes with a 0.12 m slot; the glow box's outer face is 0.04 m behind the
  band face. Nothing coplanar → no flicker; neon stays excluded from Geometry.
- The blade fin IS the parapet along the chamfer (no separate parapet boxes there; it sits
  slightly proud of the billboard plane).
- Only the **glass** arcs are smooth cylinder shells — glass is Fire-Geometry-only anyway;
  approximate each shell with its chord boxes there if needed.
- Do NOT re-tessellate or hull the arcs; the facet count is deliberate (polycount budget).

## Per-floor fixtures (floors 2–30)
Each suite carries three instanced fixtures, cloned from their own viewers — geometry and
materials are SHARED in the viewer, so all 29 copies are one geometry each:
| group | source | placement (floor-local) |
|---|---|---|
| `F##_KITCHEN` | kitchen.html / ARMA3_HANDOFF_KITCHEN.md | x −17.25, z 0, rotated 90° (back to W wall) |
| `F##_SHOWER` | shower.html / ARMA3_HANDOFF_SHOWER.md | x 5.99, z 11.19, rotated 180° (bath far wall, right corner) |
| `F##_TOILET` | toilet.html / ARMA3_HANDOFF_TOILET.md | x 4.20, z 11.56, rotated 180° (bath far wall, left of the shower) |

Mesh names are prefixed: `F02_SHOWER_SHW_tray`, `F02_TOILET_TLT_bowl_outer`, etc. Materials,
LOD rules and collision recipes come from each fixture's own handoff — they are unchanged here.
**For the P3D: do NOT import 29 copies.** Build each fixture as its own p3d once and place them
with proxies (or as separate editor objects); the OBJ carries all 29 only because the viewer
needs to show them. Fixture Geometry never merges into the tower's slab components.

## LOD mesh mapping
- **Geometry**: all `_c*` objects from `*_slab`, `*_walls_interior`, `*_facade_dark`,
  `*_stairA/B/Land`, `F01_reception`, `F01_columns`, `ROOF_edge_band`,
  `ROOF_parapet`, `ROOF_hut`, `ROOF_bar_c*`, `ROOF_bar_stools_c*`, `ROOF_lounge_c*`, `ROOF_lounge_table_c*`, `ROOF_dancefloor`, `ROOF_dancefloor_frame_c*`, `ROOF_speaker_1_c*`, `ROOF_speaker_2_c*`, `ROOF_equipment` + each `door_N` leaf as its
  own convex component (named `door_N`) + `*_elevator_doors`. **1:1 box→component; NEVER hull
  merged groups** (fills stair holes/doorways = invisible walls). EXCLUDE: rails, window
  frames, signs, neon, bar/table tops, deck/floor coverings, `*_ceiling`.
- **Roadway**: `F*_slab` tops (one piece), floor coverings, `*_stairA/B/Land_c*`, `ROOF_slab` top (one piece; convex Geometry = hidden `GEO_ROOF_slab_c*`),
  `ROOF_deck_tile`, `ROOF_dancefloor` top — top faces only. FOUNDATION is Geometry/Fire
  only, never Roadway.
- **Fire**: Geometry set + `*_glass` and `*_glass_inner` as separate penetrable components.
- **View**: `*_facade_dark_c*`, `*_walls_interior_c*`, `*_slab_c*`.

## Dance floor + speakers (party scripting hooks)
- `ROOF_dancefloor` is a 6×6 m platform at the SW roof (center −11, −10.5). Its TOP face keeps a
  clean 0..1 UV map across the whole floor — built for texture swapping: name its faces as a
  selection `dancefloor`, add `hiddenSelections[] = {"dancefloor"}` +
  `hiddenSelectionsTextures[] = {"#(argb,8,8,3)color(0.2,0.1,0.4,1.0,co)"}` to the CfgVehicles
  class, then script the disco pattern by cycling frames:
  `tower setObjectTextureGlobal [0, "disco_frame_3.paa"]` (PAA files don't animate by themselves —
  cycle 4–8 frames on a timer). Grid/frame/neon meshes around it are separate and static.
- Speakers: `ROOF_speaker_1` at [−14.9, 111.7, −7.0], `ROOF_speaker_2` at [−7.1, 111.7, −14.0]
  (y = mid-cabinet). Add Memory LOD points `speaker_1_pos` / `speaker_2_pos` at those coordinates
  so mission scripts can `say3D` / attach the radio sound source there. Cabinets are convex
  Geometry components; cone discs are visual only.

## Doors — 88 wired (source of truth: lux-doors-manifest.json)
29 stairwell (floors 2–30) + 29 bath + 29 bedroom + 1 roof hut. Per door: keep `door_N` mesh
as a named selection; add `door_N_axis` (2 pts) + `door_N_trigger` (1 pt) to Memory LOD from
the manifest (same coordinate space as the OBJ — no transform); matching `door_N` components
in Geometry/Fire. Use `lux-model.cfg` (CfgModels class `skyscraper_lux` — rename to the actual
p3d filename if it differs; file must sit beside the p3d when packing) and `lux-config.cpp`
(88 AnimationSources `source="user"` + 176 UserActions). Ground floor: no functional doors —
`F01_entrance_leaves` are decorative fixed-open panes; do NOT wire them.

## Conversion checklist
1. Import OBJ raw (no mirror). Scale check: 112 m tall, 36 m square, base extends to y −3
   (foundation). Sink the model so terrain cuts the plinth, never the lobby floor.
2. Resolution LOD: textures per table; keep pinned/authentic UV meshes untouched.
3. Geometry/Fire/Roadway/View per mapping above; mass ~900000; `class=house`, `map=building`.
4. Memory LOD: door axis + trigger points from manifest.
5. lux-model.cfg + lux-config.cpp; pack as its own addon PBO (config doors need the addon
   route; for the no-addon simple-object route strip door leaves and use the SQF approach
   from the 20F project instead).
6. In-game acceptance: suite signs read correctly (not mirrored); doors open ~100° with
   collision; stairwell climbable ground→roof; elevators sealed; neon glows at night;
   rooftop bar/lounge is solid and walkable.
