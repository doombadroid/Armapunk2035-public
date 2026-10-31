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

## Budget — v19 merge pass, cuts, then the v20 detail pass
| | v18 | v19 merge | v19 + cuts | **v20 detail** |
|---|---|---|---|---|
| Resolution 1.0 objects | 3,897 | 756 | 666 | **723** |
| Resolution 1.0 tris | 136,240 | 122,908 | 88,828 | **117,944** |
| Resolution 1.0 points | 84,236 | 74,722 | 55,334 | **73,320** |
| Sections (draw calls) | 20 | 16 | 16 | **18** |
| Geometry components | 3,854 | 2,435 | 2,435 | **1,696** |

### v20 — interior collision pass
Geometry 2,372 → **1,697**. Resolution is untouched (666 objects / 117,260 tris / 72,864 points /
16 sections): this pass only changes what the hidden `GEO_*` boxes are.

**A naming bug was fixed here too.** The slabs' convex decomposition was built by a `mesh()` call
whose NAME already began with `GEO_`, so it rendered as a visible duplicate (31 meshes, 8,076
tris of Resolution that shouldn't exist) and its children came out double-prefixed
(`GEO_GEO_F##_slab_cNN`). Anyone following the "delete every `GEO_*` from Resolution 1.0"
instruction would have deleted visible floor geometry. `mesh()` now takes `'only'` as its `geo`
argument — emit the hidden boxes and no visible mesh — and the slabs use it, so the decomposition
is `GEO_F##_slab_cNN` exactly as this document always claimed. Verified: 0 double-prefixed names,
0 visible `GEO_*` objects, and the name-prefix tally and the visible/hidden tally now agree at
666 / 1,697. **Never prefix a `mesh()` name with `GEO_` yourself.**

| group | was | now | how |
|---|---|---|---|
| `F##_stairA` / `F##_stairB` | 292 + 292 | **30 + 30** | ONE inclined prism per flight instead of ~10 step boxes |
| `F##_stair_rails` | 180 | **60** | one barrier prism per rail run instead of two bars; landing rails dropped |
| `F##_walls_interior` | 592 | **592** | unchanged — door openings stay crisp, as chosen |
| `F##_stairLand` | 30 | 30 | already one box |

**Stair collision is a ramp, not steps.** This is standard practice: the Roadway LOD carries the
walk surface, so Geometry only needs a solid that fills the stair volume. The prism sits on the
tread line, oscillating between −108 mm and +87 mm against the visible treads — that spread is
inherent to representing ten 180 mm risers with one prism, and it is not worth more components.
Landing rails are excluded because the landing slab already bounds that edge.

**One trap if you retune these.** An inclined slab of thickness T sits `(T/2)/cos(th)` above its
centre line VERTICALLY, not `(T/2)*cos(th)`. Getting that backwards floats the ramp ~275 mm over
the treads, which is how the first version of this pass shipped.

### v20 — where the reclaimed budget went
The cuts freed ~34k tris; the detail pass spent 28k of it on the two things you actually stand
next to (doors) and the one silhouette everything reads against (the rounded corners).

**Doors — 60 → 340 tris each.** The leaf is now a proper two-panel door: full-height stiles and
three rails (bottom 200 mm, lock 150 mm, top 100 mm) on BOTH faces, each member a **tapered
prism** — the `taperPrism()` helper insets the proud face by 13 mm so the moulding edge reads as
a bevel instead of a flat step, at the same 12 tris a box would cost. 132 tris/leaf.
Brass (`door_N_hw`) went 24 → 208 tris: latch-edge strip, **three hinge knuckle barrels**
(5-sided, on the hinge stile), and a real lever set on each face — 6-sided rose, 5-sided shank,
6-sided grip bar pointing toward the hinge. Levers are on both faces because both sides get used.
Winding is verified in both leaf orientations (36 legitimately inward faces per leaf: the hidden
backs against the slab and the panel-field sides).

**Rounded corners.**
| | was | now |
|---|---|---|
| glass corner shells (`arcShell`) | 8 seg | **16 seg** |
| spandrel + roof-edge + parapet band arcs (`chordBoxes`) | 8 chords | **14 chords** |
| visible foundation pies | 8 seg | **16 seg** |
| Geometry pies (`pie` default) | 8 seg | 8 seg — unchanged, still one convex each |

**Neon corners are now smooth shells, not chord boxes.** `arcShell` at 20 segments costs 32 tris
where 8 chord boxes cost 96, so the neon rings got smoother AND cheaper — neon is excluded from
Geometry, so it never needed to be convex. Same swap on `ROOF_parapet_neon`.

**The swap is NOT radius-neutral — this bit me once.** `chordBoxes(r, th)` inscribes: its outer
face lands at about `r·cos(π/4n) − th/2 + th`, noticeably inside `r`. `arcShell(r)` is a
zero-thickness surface exactly ON `r`. So the shell radius must equal the straight run's OUTER
face, not the old chord `r`. Verified flush:

| ring | straight-run outer | shell radius | step |
|---|---|---|---|
| `F##_neon_ring` | 18.03 | 9.03 | 0 mm |
| `ROOF_parapet_neon` | 17.96 | **8.96** | 0 mm |

The parapet shipped at 8.99 for one build, which stood 30 mm proud of its straight strip and left
an open seam at every tangent. If you retune a neon ring, re-measure the tangent step.

**And the swap is not THICKNESS-neutral either — a shell is only safe where no inner face is ever
seen.** `neon_cyan_proc` is FrontSide, and a shell has no back face, so it simply vanishes when
viewed from behind. That is why the two rings ended up different:

| ring | corners | why |
|---|---|---|
| `F##_neon_ring` | **20-seg shell** | strip spans 17.98–18.03 against opaque facade skin at 18.00, so no inner face is ever visible from a suite. 30 floors × 3 corners is where the saving is real. |
| `ROOF_parapet_neon` | **14 chord boxes**, r 8.96, th .26 | 50 mm of strip faces the roof deck (parapet inner face 17.75, strip inner 17.70). A shell left the cyan band dying at all three corners when seen from the deck. Only 3 corners, so the shell saved nothing. |

Note the radius rule differs between the two forms, and BOTH are "flush":
a shell is flush when its radius equals the straight outer face (9.03 / 18.03).
Chord boxes inscribe, so they are flush **at the tangent** when `r` equals the straight outer face
(8.96 / 17.96) — the mid-chord face then sits ~14 mm recessed, exactly like the `ROOF_parapet`
band beside it. Do NOT instead solve for a flush mid-chord face (`r = 8.96/cos(π/56)`): that puts
the chord END corners 14 mm proud, i.e. a step precisely where the seam was.

`ROOF_edge_band` and `ROOF_parapet` now pass an explicit Geometry array (straight boxes + one
solid pie per corner) instead of `true`, so the extra Resolution chords don't become extra
collision components — that is why Geometry went DOWN to 2,372 while Resolution went up.

**72,864 points.** Still inside p3d v70, but the margin is gone: this is now a model that has to
be split, not one that could optionally be. Doors alone are 29,920 tris across 88 objects, and 87
of them sit on the repeating floors — they leave the host with the floor module.

**55,334 points is under the p3d v70 limit** (above 2^16 vertex normals since Q1 2016) with room
to spare. It would not have fit the old 32,768 DirectX-9 ceiling, and hard-edge normal splitting
still has to be watched, but res0 is no longer the blocker — the module split is now a
draw-call and repetition decision, not a "will it import" one.

What changed: every group is now ONE merged Resolution object with hidden `GEO_*` collision
boxes beside it; the spandrel band is one prism per side instead of a lower/upper pair (the neon
groove moved to `_nohq`); each rounded corner's band Geometry is one solid pie instead of 8 chord
boxes; the nine per-floor arc mullion posts are deleted; and five opaque `*_proc` solids
(metal_dark, metal_grey, metal_elevator, white_marking, door_brass) are folded into a single
16-cell palette section, colour in `_co` and roughness/metalness in `_smdi`, UVs pinned per cell.
Facade skin alone went from 21,576 tris / 1,805 objects to **11,568 tris / 30 objects**.

Four cuts on top of the merge:
- **Ceilings deleted.** `F##_ceiling` is gone; the slab above IS the ceiling (its underside was
  the only face visible from below anyway). 30 objects, 9,720 tris.
- **Suite signs are a decal.** The 7-segment digit geometry is gone. Each floor's two 0.30 × 0.20 m
  plates map palette cell `8 + floorIndex`, which carries the face "01"–"30". 7,344 → 720 tris.
- **Single glazing.** `F##_glass_inner` deleted; `glass_blackout_proc` is now one double-sided
  tinted pane, **0x0b1116 at alpha 0.50**. 8,016 → 4,008 tris, one section fewer.
  0.50 is a deliberate compromise: one alpha value cannot be near-opaque outward AND clear inward,
  which is exactly why the two-pane version existed. **Do not raise it** — at 0.82 every one of the
  29 furnished suites became a windowless black box.
  **The blackout-mirror read is the rvmat's job, not alpha's.** In game, `glass.rvmat`'s specular
  plus the sky reflection is what makes the pane read as a dark mirror from the street; the viewer
  has no environment map, so it always looks more transparent there than it will in Buldozer.
  Judge the street read in Buldozer, not in the viewer. If it still reads too open in engine, raise
  the rvmat specular first, and only then consider restoring the inner lining (4,008 tris, +1 section).
- **Door leaves simplified.** The 5-box moulding frame per face became a single mid rail per face,
  and the brass is a latch-edge strip plus one lever. 216 → 60 tris per door; 19,008 → 5,280.

### _nohq maps (authored, procedural — regenerate from the run in the project if you retune)
| map | applied to | carries |
|---|---|---|
| `ap_spandrel_nohq` | `metal_dark_proc` (facade, parapet, blade, mullions) | neon groove recess + 1 m panel seams |
| `ap_curtainwall_nohq` | (authored, not yet wired — see below) | mullion ribs + glazing bead |
| `ap_chamfer_nohq` | (authored, not yet wired — see below) | 2 m panel joints + slit reveals |
| `ap_concrete_nohq` | `concrete_panels_co` | board lines + form-tie dimples |
| `ap_plaster_nohq` | `gallery_wall_plaster_a_co` | orange-peel |
| `ap_roofdeck_nohq` | `marble_tiles_01_co` | 0.5 m tile joints |

`metal_dark_proc` was pulled back OUT of the palette fold and given a real tiling `ap_facade_co`
+ `_nohq` — a pinned palette cell cannot carry a normal map, and the facade is the one surface
that most needs one. Net section count is unchanged.

**Curtain wall and chamfer maps are authored but unwired.** `*_glass` UVs are pinned into the
base-game window atlas region (0.46–0.62 / 0.443–0.768), so a tiling normal map would stretch one
tile across a whole pane. Wiring them needs either a second UV set or per-bay pane geometry —
which is exactly what the facade-bay module is for. Do it there, not here.

**Still over budget for a single p3d.** The p3d limit is on VERTEX NORMALS, and p3d v70 (Arma 3,
Q1 2016+) raised it above 2^16 — but hard-edged boxy architecture splits normals at every edge,
so 74,722 points becomes far more vertex normals than that. Where the remaining tris sit:

| group | tris | objects |
|---|---|---|
| slabs / floors / ceilings | 31,320 | 120 |
| door leaves + hardware | 19,008 | 176 |
| facade skin | 11,568 | 30 |
| neon | 10,708 | 38 |
| mullions | 10,032 | 30 |
| stairs | 9,540 | 121 |
| glass (2 panes) | 8,016 | 60 |
| suite signs | 7,344 | 60 |
| interior walls | 7,104 | 30 |

Slabs and doors are 41 % of Resolution between them, and both are per-floor repeats — they are
what the module split is for. **Do not add exterior detail before that decision is made.**

### v20 — lobby + elevator finish
- **The lobby reception desk is deleted.** `F01_reception`, `F01_reception_top` and
  `F01_reception_neon` are gone (36 tris, 3 objects, 1 Geometry component).
- **Elevator doors are a real weathered metal**, not a flat proc colour. `ap_elevator_co` is
  brushed stainless — vertical brush grain, drip streaks, scuffs at hand height, and a grime
  gradient toward the floor. `ap_elevator_smdi` carries **varying** roughness in G at constant
  high metalness in B, which is what reads as weathered metal rather than merely dirty metal;
  `ap_elevator_nohq` carries the brush relief. All three are procedural — regenerate from the
  script in the project if you retune.
- **The door UVs are PINNED, not world-projected** (`panelUV`): v spans the leaf height exactly
  (0.31 → 2.61 m = v 0 → 1) and u repeats twice, one tile per leaf. This matters because the
  texture has a top-to-bottom grime gradient: `alignUV`'s world projection put v = 1.0 at 2.00 m
  up the door, so every leaf on all 30 floors got a hard band there where clean steel met the
  darkest grime, and the grime landed at an arbitrary height instead of the floor line.
  **Any texture with a vertical gradient needs `panelUV`, not `alignUV`.**
- **`F##_call_box` / `F##_call_plate`** — a call station on every floor, between the two door
  pairs on the corridor face of the z = 3.0 wall (housing 3.10–3.144, plate face 3.150).
  The housing is brass (palette cell 4). **The buttons are texture only** — no button geometry:
  one pinned plate quad carries `ap_callplate_co` with `ap_callplate_emi` as its emissive mask,
  so only the ring and arrow pixels light. 24 tris and 2 objects per floor.
  In engine give `ap_callplate.rvmat` an `emissive` stage pointing at `ap_callplate_emi.paa`
  and the plate will glow without a light source; add it to the lit-window/emissive hidden
  selection if you want it to switch off with the building's night state.
  Sections 17 → 18.
- This pulled `metal_elevator_proc` back out of the palette fold, for the same reason
  `metal_dark_proc` came out: **a pinned palette cell cannot carry a texture or a normal map.**
  Sections 16 → 17. The palette now folds 3 materials (grey, white marking, brass) plus the
  30 suite-sign decals.

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
| glass_blackout_proc | `#(argb,8,8,3)color(0.04,0.07,0.09,0.50,ca)` | `a3\structures_f_exp\data\glass\glass.rvmat` (super-glossy; alpha 0.45 — see budget section) |
| ~~glass_interior_proc~~ | DELETED in v19 — single glazing, see the budget section | — |
| concrete_floor_02_co | `a3\structures_f_enoch\data\floor\concrete\concrete_floor_02_co.paa` | — |
| gallery_floor_parquet_b_co | `a3\structures_f_aow\civilian\gallery_01\data\gallery_floor_parquet_b_co.paa` | — |
| marble_tiles_01_co | `a3\structures_f_exp\data\tiles\marble_tiles_01_co.paa` | — |
| marble_tiles_02_co | `a3\structures_f_exp\data\tiles\marble_tiles_02_co.paa` | `a3\structures_f\data\metal\metalclean1.rvmat` |
| house_big02_multi2 | `a3\structures_f_enoch\data\wood\woodfine_01_co.paa` | `a3\structures_f\data\metal\metalclean1.rvmat` (satin lacquer) |
| ~~door_brass_proc~~ | folded into `ap_palette_co`, cell 4 | — |
| rollup_combo_co | `a3\structures_f\data\metal\rollup_combo_co.paa` | — |
| office_addons_co | `a3\structures_f\civ\offices\data\office_addons_co.paa` | `a3\structures_f\data\metal\metalclean1.rvmat` |
| ~~metal_grey_proc~~ | folded into `ap_palette_co`, cell 1 | — |
| metal_elevator_proc | `ap_structures\data\ap_elevator_co.paa` (+ `_nohq`, `_smdi`) | `ap_structures\data\ap_elevator.rvmat` |
| **ap_palette_co** | `ap_structures\data\ap_palette_co.paa` (+ `ap_palette_smdi.paa`) | `ap_structures\data\ap_palette.rvmat` |
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
- **Glazing is ONE pane** since v19. `*_glass` is a single double-sided untextured proc colour at
  alpha 0.50 — no UV work needed. The old `*_glass_inner` 8 cm lining is gone. If you ever want
  the two-pane read back, the lining is 4,008 tris and one extra section; the reason it existed
  was that a near-opaque outer pane blacks out the interior.
- **`door_N` leaves** (v20): dark walnut two-panel leaf — slab + full-height stiles and three
  rails on both faces, every member a tapered prism (bevelled moulding edge). 11 pieces, 132 tris.
  Material `house_big02_multi2` (woodfine_01 tinted, satin rvmat).
- **`door_N_hw`** (v20): brass latch-edge strip, three hinge knuckle barrels on the hinge stile,
  and a lever set (rose + shank + grip) on each face. 10 pieces, 208 tris. Material is palette
  cell 4 (`ap_palette_co`). It is a SEPARATE object so it can
  carry the brass material, but it belongs to the SAME selection as the leaf: assign both
  `door_N` and `door_N_hw` to selection `door_N` so the hardware swings with the door.
- **`ROOF_ac_01..04`**: authentic office_addons atlas UVs — do not re-UV; if they render as
  a wrong texture, your mapping fell back.
- AC Geometry: plain 1.45×1.07×2.94 boxes, not the detailed meshes.

## Mesh naming
`F{01..30}_*` + `ROOF_*` + `NEON_corners` + `FOUNDATION_c*` (3 m deep concrete plinth under
the whole footprint, inset 0.06 from the facade line — for placement on sloped terrain;
base y = −3): `_slab`, `_walls_interior`, `_floor_wood`/`_floor_bath`/
`F01_floor_stone`, `_stairA/B/Land`, `_stair_rails`, `_elevator_doors`,
`_sign_plates` (number is a palette decal — no `_sign_digits` any more), `_facade_dark`,
`_glass` (single pane — no `_glass_inner`), `_window_frames`, `_neon_ring`,
`_door_frames`, `F01_reception*`, `F01_columns`, `ROOF_bar*`, `ROOF_lounge*`, `ROOF_helipad_*`, `ROOF_hut`,
`ROOF_ac_01..04`, `door_1..door_88`.

**Since v19 every group is ONE merged Resolution object.** The old `name_cNN` split (one visible
object per convex box) is gone. Convex collision now ships the same way the slabs always did:
hidden `GEO_<group>_cNN` boxes sitting beside the merged mesh. So:
**import `GEO_*` into Geometry/Fire, and DELETE every `GEO_*` object from Resolution 1.0.**
Nothing else in Resolution needs splitting or merging.
`F##_slab` / `F##_floor_*` remain single plan-shaped concave extrusions (real shaft holes) —
Resolution only, collision via `GEO_F##_slab_c*`. There is no `F##_ceiling`: the slab's underside
is the ceiling.

## Curved geometry — conversion notes
- Rounded corners are built collision-safe: slabs/coverings use **solid quarter-cylinder
  wedges (8 segments, convex — one Geometry component each)**. Since v19 the spandrel band's
  Geometry is ALSO a solid quarter-cylinder per corner instead of 8 chord boxes — the pie fully
  contains the chords, because the chords' outer corners sit on the r=9 circle. Resolution still
  uses the chord boxes (the pie would bulge past the facade line visually). Spandrel/parapet arcs are
  **faceted chord boxes placed so their OUTER CORNERS sit exactly on the plan circle**
  (r_center = R·cos(δ/2) − t/2) — nothing bulges past the facade plane or the footprint.
  The NE chamfer is rotated boxes, wall inset so its outer face lies ON the chamfer line.
  All convex, all 1:1 components.
- **Neon is a PROUD strip, not a recessed groove** (changed in v19). The spandrel band is now
  ONE prism per side instead of a lower/upper pair straddling a 0.12 m slot — that halved the
  facade box count. The glow strip stands 30 mm off the band face and is embedded 20 mm into it,
  so nothing is coplanar and nothing flickers. **The groove reads from `_nohq`, not geometry** —
  author the recess shadow into the spandrel normal map. Neon stays excluded from Geometry.
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
  frames, signs, neon, bar/table tops, deck/floor coverings.
- **Roadway**: `F*_slab` tops (one piece), floor coverings, `*_stairA/B/Land_c*`, `ROOF_slab` top (one piece; convex Geometry = hidden `GEO_ROOF_slab_c*`),
  `ROOF_deck_tile`, `ROOF_dancefloor` top — top faces only. FOUNDATION is Geometry/Fire
  only, never Roadway.
- **Fire**: Geometry set + `*_glass` as a separate penetrable component.
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
