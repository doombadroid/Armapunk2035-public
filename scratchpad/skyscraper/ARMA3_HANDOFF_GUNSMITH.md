# Gunsmith Workbench — Claude Code handoff (OBJ/MTL → P3D)

Source: `gunsmith.html` viewer → **Download OBJ + MTL**. Meters, Y-up, origin at plan center,
base y=0, front faces **+Z** (pegboard riser at the back, z<0). Import RAW — no axis negation.
Worktop at 0.92 m; pegboard to 1.85 m; footprint 2.0 × 0.8 m. Set dressing: bench vice with a
barrel clamped in the jaws, disassembled fictional rifle + pistol on a rubber mat, pegboard
tools, punch block, cleaning rod, solvent jar, ammo can, loose brass.

All primitives (boxes/cylinders/tubes) — convex-friendly except the 3 helical springs and the
torus pieces (trigger guard, muff band, plier pivot). ~8.3k tris, 170 meshes. No anims → no
model.cfg.

## Material → texture map (Face Properties)
Big surfaces use REAL a3 textures (the viewer previews them from `textures/a3/...png`; in
Object Builder point the face at the `.paa`). Small accents stay procedural colors.

| usemtl | texture | rvmat |
|---|---|---|
| woodfine_01_co | `a3\structures_f_enoch\data\wood\woodfine_01_co.paa` (worktop) | `a3\structures_f\data\wood\wood_plank.rvmat` |
| woodfine_01_dark | same `.paa`, darker rvmat/tint (edge trim, hammer handle, punch block) | wood rvmat |
| planksold_02_co | `a3\structures_f_enoch\data\wood\planksold_02_co.paa` (floor crate) | wood rvmat |
| wood_plank_old_co | `a3\structures_f_enoch\data\wood\wood_plank_old_co.paa` (pegboard) | wood rvmat |
| metalcoloureddark_co | `a3\structures_f\data\metal\metalcoloureddark_co.paa` (legs, aprons, pedestal, drawers, struts, shelf) | `a3\structures_f\data\metal\metal_plate.rvmat` |
| metal_gray_clean_co | `a3\structures_f\data\metal\metal_gray_clean_co.paa` (bright tool steel: wrenches, rods, screws, BCG) | `a3\structures_f\data\metal\metalclean1.rvmat` |
| metalclean1_co | `a3\structures_f\data\metal\metalclean1_co.paa` (vice castings, hacksaw, pliers, torque head) | metalclean1 rvmat |
| metal_servicehangar_black_co | `a3\structures_f_enoch\data\metal\metal_servicehangar_black_co.paa` (gun metal: barrel, upper, scope, suppressor, slide) | metalclean1 rvmat (satin) |
| metal_servicehangar_black_matte | same `.paa`, matte rvmat (polymer: lower, grips, mags, stock, muff cups) | metal_plate rvmat |
| metal_universal_dirty_co | `a3\structures_f_enoch\data\metal\metal_universal_dirty_co.paa` (bench mat) | matte |
| metal_green_paint_co | `a3\structures_f_enoch\data\metal\metal_green_paint_co.paa` (ammo can) | metal_plate rvmat |
| brass_proc | `#(argb,8,8,3)color(0.70,0.58,0.35,1.0,co)` | metalclean1 |
| copper_tip_proc | `#(argb,8,8,3)color(0.61,0.39,0.25,1.0,co)` | metalclean1 |
| handle_red_proc | `#(argb,8,8,3)color(0.55,0.18,0.14,1.0,co)` | matte |
| plastic_blk_proc | `#(argb,8,8,3)color(0.07,0.07,0.09,1.0,co)` | matte |
| glass_jar_proc | `#(argb,8,8,3)color(0.87,0.93,0.94,0.28,ca)` | `a3\structures_f_exp\data\glass\glass.rvmat` |
| liq_solvent_proc | `#(argb,8,8,3)color(0.79,0.54,0.17,0.85,ca)` | glass rvmat |
| label_proc | `#(argb,8,8,3)color(0.85,0.82,0.75,1.0,co)` | — |
| stain_proc | `#(argb,8,8,3)color(0.08,0.06,0.04,0.50,ca)` | — (decal circles; delete if unwanted) |

## Mesh naming (170 meshes)
- Bench: `GS_top`, `GS_edge_f`, `GS_leg_1..4`, `GS_apron_f/b`, `GS_shelf_low`, `GS_ped_r`,
  `GS_drawer_1..3`, `GS_dhandle_1..3`.
- Pegboard: `GS_peg_strut_l/r`, `GS_pegboard`, `GS_peg_shelf`, `GS_hook_*`;
  hung tools `GS_wrench_1/2_*`, `GS_pliers_*`, `GS_file_1/2(+_grip)`, `GS_hdriver_1/2_*`,
  `GS_muff_band/cup_l/cup_r`, `GS_hacksaw_*`.
- Vice: `GS_vice_base/swivel/lock_l/body/jaw_fix/slide/jaw_mov/plate_1/plate_2/screw/hub/
  handle/hend_1/hend_2` + clamped `GS_barrel(+_chamber,_thread,_gasblock)`.
- Rifle on mat: `GS_mat`, `GS_rifle_lower/grip/tguard/buffer/stock/pad`,
  `GS_rifle_upper/rail/chandle`, `GS_bcg_body/head/key`, `GS_spring_rifle`,
  `GS_mag_1..3(+_plate)`, `GS_scope_tube/obj/ocular/turret/ring_1/ring_2`, `GS_suppressor`.
- Pistol: `GS_pistol_frame/grip/slide/sight/barrel`, `GS_spring_pistol`.
- Ammo: `GS_ammocan(+_lid,_handle,_latch)` (closed can), `GS_rd_1..8(+_tip)` (3 standing,
  5 lying).
- Hand tools: `GS_hammer_head/peen/handle`, `GS_punch_block`, `GS_punch_1..5`,
  `GS_driver_grip/shaft`, `GS_torque_shaft/head/grip/band`, `GS_caliper_beam/jaw_f/jaw_s/dial`,
  `GS_rod(+_handle,_brush)`, `GS_patches`, `GS_jar(+_liq,_lid)`, `GS_oil_body/top/spout/label`,
  `GS_rag_1/2`, `GS_tray(+_well)`, `GS_pin_1..4`, `GS_spring_sm`.
- Lamp: none (removed). Storage: `GS_crate(+_lid)`,
  `GS_kitbox(+_latch)`. Decals: `GS_stain_1/2/floor`.

## LOD build
- **Resolution 1.0**: everything — ~8.3k tris (springs 672 ea, muff band 320, tguard 256).
- **LOD 2.0**: delete `GS_spring_*`, `GS_rd_*`, `GS_pin_*`, `GS_hook_*`, `GS_patches`,
  `GS_caliper_*`, `GS_oil_spout`, `GS_barrel_thread`, `GS_vice_hend_*`, `GS_vice_lock_l`,
  `GS_pistol_sight`, `GS_stain_*`, all pegboard hung tools → ≈3.5k. Keep vice + barrel +
  rifle parts (signature read).
- **LOD 3.0**: bench boxes + pegboard + vice base/body + mat + ammo can → ≈400.
- **Geometry** (collision): 5 convex boxes drawn by hand in Object Builder —
  worktop `2.00 × 0.06 × 0.80` @ (0, 0.89, 0); right pedestal `0.56 × 0.84 × 0.70` @
  (0.70, 0.445, 0); left leg bay `1.38 × 0.86 × 0.76` @ (−0.31, 0.43, 0) — encloses the open
  frame + low shelf; pegboard riser `1.94 × 0.96 × 0.09` @ (0, 1.37, −0.365); vice block
  `0.34 × 0.22 × 0.18` @ (−0.58, 1.02, 0.16). Small clutter gets NO collision.
- **Fire Geometry / View Geometry**: same 5 boxes.
- No Roadway, no Paths, no Memory. Mass ~140. `class=house`, `map=hide`.

## config.cpp
`gunsmith-config.cpp` — `Land_AP_GunsmithBench_F`, House_F child, destrType=DestructNo.
Back against a wall (pegboard side). Workshop / hideout armory set dressing for Armapunk2035.
