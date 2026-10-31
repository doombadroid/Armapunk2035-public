# Arma 3 Skyscraper — Claude Code handoff (OBJ/GLB → P3D)

Source: `skyscraper.html` viewer → **Download OBJ + MTL** (or GLB). Geometry is in
meters, Y-up, origin at plan center, base at y=0. Main entrance faces **+Z**.
UVs are world-scaled: 1 texture tile per 2 m.

## Building facts
- 24 × 24 m footprint, 20 stories, 71.2 m to parapet (76 m incl. mast).
- Floor levels (top of slab): L1 = 0.3, L2 = 5.3, then +3.4 per story; roof deck = 69.9.
- Floor 1: open lobby (glass storefront, N double-door 3.6 m, S exit 1.2 m, parked elevator cab).
- Floors 2–20: 4 L-shaped rooms around a ring corridor; 1 working door per room (1.1 × 2.2) in the N/S ring walls at x = ±3.3.
- Central core every floor: switchback stair (west half, door at x = −2.2 on core N wall)
  + elevator shaft (east half, 1.4 m openings each floor at x = +2.2, **sealed by fake door panels `F##_elevator_door`** — swap for a scripted elevator later; the shaft behind is open top to bottom).
- Stair arrives on the north landing strip each floor; continues to a roof hut (door on hut E side).
- Roof: parapet, bitumen deck, helipad ring + H (west-facing clear zone), 3 AC units, 4 vents, mast.

## Mesh naming
`F{01..20}_*` per floor + `ROOF_*` + `FOUNDATION_c*` (3 m deep concrete plinth under the
footprint, inset 0.06, base y = −3 — for placement on sloped terrain): `_slab`, `_walls_interior`, `_floor_wood`,
`_floor_corridor`/`_floor_tile`, `_stairA`/`_stairB`/`_stairLand`, `_stair_rails`, `_facade_concrete`,
`_glass`, `_window_frames`, `_door_frames`, `_elevator_door`, `_elevator_cab`, `ROOF_hut`, `ROOF_ac_01..03`, etc.
Collision-relevant groups (`_slab`, `_walls_interior`, `_stairA/B/Land`, `_facade_concrete`,
`ROOF_parapet`, `ROOF_hut`, `ROOF_equipment`) are pre-split into one object per convex box:
`F07_slab_c00 .. _c05`. GLB keeps a group per floor. OBJ: one `o` per mesh, `usemtl` = material names below.

## Material → Arma 3 base texture map (apply in Object Builder Face Properties)
| usemtl name | texture | rvmat |
|---|---|---|
| concrete_panels_co | `a3\structures_f_enoch\data\concrete\concrete_panels_co.paa` | — |
| plaster03_4x4_office_co | `a3\structures_f\data\plaster\plaster03_4x4_office_co.paa` | — |
| window_set_dark_2_ca | `a3\structures_f_exp\data\glass\window_set_dark_2_ca.paa` | `a3\structures_f_exp\data\glass\glass.rvmat` |
| concrete_floor_02_co | `a3\structures_f_enoch\data\floor\concrete\concrete_floor_02_co.paa` | — |
| hotel_02_floor_co | `a3\structures_f_exp\data\wood\hotel_02_floor_co.paa` | — |
| tile_04a_co | `a3\structures_f\data\tile\tile_04a_co.paa` | — |
| asphalt_roof_a_co | `a3\structures_f_enoch\data\roof\asphalt_roof_a_co.paa` | — |
| wooden_bridge_co | `a3\structures_f_exp\data\wood\wooden_bridge_co.paa` | — |
| rollup_combo_co | `a3\structures_f\data\metal\rollup_combo_co.paa` | — |
| office_addons_co | `a3\structures_f\civ\offices\data\office_addons_co.paa` | `a3\structures_f\data\metal\metalclean1.rvmat` |
| house_big02_multi2 | *(no texture — leave empty)* | `a3\structures_f_argo\civilian\house_big02\data\i_house_big_02_b_pink_multi2.rvmat` |

**office_addons_co is ONLY on `ROOF_ac_01..03`** — AC units lifted verbatim from JewelryBuildingModel.p3d with their authentic atlas UVs. Do NOT re-UV or world-scale those meshes; apply the texture and leave UVs untouched.

**`door_*` leaves (house_big02_multi2)** are the green front-door leaf ripped verbatim from `i_House_Big_02_b_pink_F.p3d` (House_Big02). It is a MULTIMATERIAL surface: face texture stays EMPTY and the whole look comes from the rvmat above (base game ships it — Argo/Malden platform content). UVs are authentic — do not re-UV, do not world-scale. **If doors show up with a roof/tile/bitumen texture in-game, your material mapping fell back on this name** — map `house_big02_multi2` explicitly: texture `""` (empty string), material = the rvmat path above, on every `door_*` face.

**`*_glass` UVs are pinned to the clean pane region of window_set_dark_2_ca** (u 0.46–0.62, v 0.44–0.77 in OBJ space), matching how the jewelry storefront maps it — the rest of that texture is painted window frames. Do not re-UV or tile the glass.
| metal_grey_proc | `#(argb,8,8,3)color(0.55,0.57,0.59,1.0,co)` | `a3\structures_f\data\metal\metalclean1.rvmat` |
| metal_dark_proc | `#(argb,8,8,3)color(0.18,0.20,0.23,1.0,co)` | `a3\structures_f\data\metal\metalclean1.rvmat` |
| white_marking_proc | `#(argb,8,8,3)color(0.90,0.90,0.88,1.0,co)` | — |

All paths verified present in the two reference P3Ds (base game / no mods).

## LOD mesh mapping (copy these named meshes per LOD)
- **Geometry** (collision): all `*_slab_c*`, `*_walls_interior_c*`, `*_facade_concrete_c*`, `*_stairA_c*`, `*_stairB_c*`, `*_stairLand_c*`, `*_elevator_door`, `ROOF_parapet_c*`, `ROOF_hut_c*`, `ROOF_equipment_c*` objects. **Each object is already one convex box — make it exactly one component (1:1). NEVER convex-hull a merged group or a whole floor: hulling fills the stair holes and door openings and creates invisible walls.** Stairs are now one mesh per flight, so even a per-mesh hull degrades to a walkable ramp wedge instead of a ceiling over the landing (the "head hits invisible ceiling after one flight" bug). For `ROOF_ac_01..03` use a plain 1.45×1.07×2.94 box, not the detailed mesh.
- Optional stair smoothing: in Geometry (not Roadway) you may replace each `_stairA_c*`/`_stairB_c*` tread set with one sloped ramp box (1.3 wide × 0.25 thick, length hypot(2.6, rise/2), rotated ±atan2(rise/2, 2.6) about X) — smoother player movement.
- **Roadway** (walkable): `*_slab_c*`, `*_floor_wood`, `*_floor_corridor`, `F01_floor_tile`, `*_stairA_c*`, `*_stairB_c*`, `*_stairLand_c*`, `ROOF_slab_c*`, `ROOF_deck_bitumen` — top faces only. FOUNDATION is Geometry/Fire only, never Roadway.
- **Fire Geometry**: Geometry set + keep `*_glass` as separate components (penetrable).
- **View Geometry**: `*_facade_concrete_c*`, `*_walls_interior_c*`, `*_slab_c*`.

All wall/slab UVs are world-aligned (continuous texture bands across wall segments — fixes banding misalignment around doorways). `F##_elevator_door` panels use rollup_combo_co (roller-shutter slats read as elevator doors); keep them as separate named meshes for future scripted-elevator animation.

## Doors — fully wired (96 swinging doors)
`door_1..door_96` leaf meshes are in the export, closed, names = Arma selections.
The ground floor deliberately has NO functional doors: the lobby entrance has fixed
always-open glass panes (`F01_entrance_leaves`, decorative only — exclude from door wiring),
and the lobby stair doorway and S exit are open passages.
Generated files (all in this package, single source of truth = `doors-manifest.json`):
- `doors-manifest.json` — per door: leaf box, hinge axis line, open angle (right-hand rule about axis bottom→top), `door_N_axis` memory-point coordinates, floor, glass/wood.
- `model.cfg` — CfgSkeletons bone per door + rotation animation per door (ready to use; rename the CfgModels class to the final p3d name).
- `config.cpp` — CfgVehicles class with per-door `AnimationSources` (`source = "user"`, door sound at the trigger point) + 192 Open/Close `UserActions` — vanilla scroll-menu door interaction, zero scripting, no mods.

Claude Code steps: (1) keep leaf meshes as named selections `door_N` in the resolution LOD; (2) add the two `door_N_axis` points AND the `door_N_trigger` point per door to the Memory LOD from the manifest; (3) also name the matching Geometry/Fire components `door_N` so collision swings with the leaf; (4) use the provided model.cfg + config.cpp (config now includes `source = "user"` AnimationSources with door sounds and 192 Open/Close UserActions wired to the trigger points). Doors: 19 stairwell (floors 2–20), 76 room, 1 roof hut. Doors: 3 lobby glass (double entrance + S exit), 20 stairwell, 76 room, 1 roof hut. The lobby stair door is glass; elevator openings stay sealed by the static `F##_elevator_door` panels.

## Stairwell collision — eliminating the invisible blockers
Everything in the stair shaft is now per-convex-box objects: `_stairA_c*`, `_stairB_c*`, `_stairLand_c*`, `_stair_rails_c*`, slab strips. Rules:
- **Geometry LOD must contain NO merged hulls.** Every component 1:1 with one exported box.
- **Exclude `*_stair_rails_c*` and `*_window_frames` from Geometry entirely** (rails would clip the mid-landing turn).
- If an invisible blocker persists, open the Geometry LOD and inspect every component intersecting the stair shaft (x −4.5..0, z −2.6..2.6): each must match a visible stair/slab box from the OBJ; delete any component larger than its source box — it is a stray hull. Prime suspects: a hull of a whole `F##_stairA` group, or slab strips fused across the stair hole.

## Signage
`F##_sign_plates` (dark plates) + `F##_sign_digits` (7-segment digit boxes, white): floor number on the core wall facing the corridor and on the stairwell landing wall of every floor; room number plate (e.g. 704) beside each apartment door, latch side. Textures: the two procedural colors from the table. Visual only — **exclude signage from Geometry/Fire/Roadway LODs**.

## Coordinate convention — READ BEFORE IMPORTING
The OBJ is authored in Arma's convention already: **X east, Y up, Z north, meters** — import it RAW, with NO axis negation/mirroring. Symptom table:
- **Signage text mirrored in-game** (room plates, stairwell floor numbers) ⇒ your import mirrored an axis. Re-import without the flip. Text is correct in the source; do not "fix" it by mirroring the sign meshes.
- **Doors hinge on the wrong side / don't sit in their frames** ⇒ same mirror: the mesh got negated but the `door_N_axis` memory points from doors-manifest.json (authored in the SAME coords as the OBJ) did not — they must match. If you absolutely cannot avoid a negation, apply the identical negation to every manifest coordinate (box, axis, trigger, memoryPoints).
- Sanity check in Buldozer: plate "201" must read normally, and every leaf's hinge must sit on the same side as its `door_N_axis` line.

## P3D conversion checklist
1. Import OBJ into Object Builder (faces arrive grouped by `o` name and `usemtl`).
   Check scale: building is 71 m tall (base extends to y −3, foundation); 1 OBJ unit = 1 m.
   Axis: Y-up, entrance +Z. Sink the model so terrain cuts the plinth, never the lobby floor.
2. Resolution LOD 0.000: the imported visual mesh, textures per table above.
   Consider a 2nd resolution LOD (drop `_window_frames`, `_stair_rails`, `_door_frames`, merge interiors) for distance.
3. **Geometry LOD**: import the pre-split convex `_c*` boxes 1:1 as components
   (`Structure > Topology > Find Components` on the whole set works since every object is convex),
   set total mass (~500000). Property `class=house`, `map=building`. Do not hull merged meshes — see LOD mapping above.
4. **Roadway LOD**: slab tops, floor coverings, stair treads/landings, roof deck —
   this is what makes upper floors walkable.
5. **Fire Geometry**: copy of Geometry incl. interior partitions (glass excluded so shots pass windows).
6. **View Geometry**: exterior shell + interior walls (occlusion).
7. Shadow Volume 0: simplified closed shell, sharp edges, no textures.
8. Memory LOD: add door/ladder points as needed. Paths LOD if AI should navigate floors.
9. Windows: `_glass` faces are separate meshes per floor — keep them own components
   in Fire Geom if you want penetrable/destructible glass ("hitpoint" selections per pane optional).
10. Doors: see the Doors section above — selections, memory points, model.cfg, config.cpp are all pre-generated.

## Minimal config.cpp
Use the generated `config.cpp` in this package (includes all 100 door AnimationSources). Pack with Addon Builder / Mikero pboProject; binarize on.
