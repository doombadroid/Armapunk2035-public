# Luxury Shower — Claude Code handoff (OBJ/MTL → P3D)

Source: `shower.html` viewer → **Download OBJ + MTL**. Meters, Y-up, origin at plan center,
base y=0, entry side faces **+Z** (back/left walls go against bathroom walls). Import RAW —
no axis negation. One model: 1.7 × 1.3 m corner unit, 2.5 m tall. No anims → no model.cfg.

## Material → texture map (Face Properties)
| usemtl | texture | rvmat |
|---|---|---|
| marble_tiles_02_co | `a3\structures_f_exp\data\tiles\marble_tiles_02_co.paa` | `a3\structures_f\data\metal\metalclean1.rvmat` |
| marble_tiles_01_co | `a3\structures_f_exp\data\tiles\marble_tiles_01_co.paa` | `a3\structures_f\data\metal\metalclean1.rvmat` |
| steel_proc | `#(argb,8,8,3)color(0.77,0.79,0.80,1.0,co)` | `a3\structures_f\data\metal\metalclean1.rvmat` |
| metal_dark_proc | `#(argb,8,8,3)color(0.14,0.15,0.18,1.0,co)` | `a3\structures_f\data\metal\metalclean1.rvmat` |
| glass_clear_proc | `#(argb,8,8,3)color(0.90,0.95,1.00,0.18,ca)` | `a3\structures_f_exp\data\glass\glass.rvmat` |
| led_warm_proc | `#(argb,8,8,3)color(1.0,0.95,0.85,1.0,co)` | mission neon rvmat (optional) or — |
| matte_black_proc | `#(argb,8,8,3)color(0.08,0.09,0.10,1.0,co)` | `a3\structures_f\data\metal\metal_plate.rvmat` (matte) |

## Mesh naming
`SHW_*` structure (tray + lip, back/left walls, ceiling, niche back/shelves/trim/led, glass
clamps + rails, bench + top/led, drain + slots) and the matte-black system on the LEFT wall:
`SHW_head_escut`, `SHW_head_arm`, `SHW_head`, `SHW_head_face` (square wall rain head);
`SHW_slide_bar`, `SHW_slide_bracket_t/_b`, `SHW_wand_holder`, `SHW_wand`, `SHW_wand_head`,
`SHW_wand_outlet`, `SHW_wand_hose_01..07` (slide-bar handheld; the hose is a 7-segment chain); `SHW_valve_plate`,
`SHW_valve_btn_1..3`, `SHW_valve_knob`, `SHW_valve_knob_grip` (thermostatic valve).
Glass panes: `GLASS_right` / `GLASS_front`.

## LOD build
- **Geometry** (collision): `SHW_tray`, `SHW_tray_lip`, `SHW_wall_back`, `SHW_wall_left`,
  `SHW_ceiling`, `SHW_bench`, `SHW_bench_top` — each one convex box, import per-object.
  EXCLUDE glass, niche parts, LED strips, all plumbing (`SHW_head*`, `SHW_slide*`, `SHW_wand*`, `SHW_valve*`, rails, drain).
- **Fire Geometry**: Geometry set + `GLASS_right`, `GLASS_front` as separate penetrable
  components (shatter decals).
- **View Geometry**: walls + ceiling + tray.
- **Roadway**: `SHW_tray` top (players walk in through the front gap).
- No Paths/Memory. Mass ~350. `class=house`, `map=hide`.

## config.cpp
`shower-config.cpp` — `Land_AP_LuxShower_F`, House_F child, destrType=DestructNo.
Sits flat on floor, back/left against walls. Pairs with the lux tower suites (bath is
3.4×4.9 m — this unit fits the NE corner) or any Malden interior.
