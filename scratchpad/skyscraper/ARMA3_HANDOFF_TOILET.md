# Luxury Toilet + Bidet — Claude Code handoff (OBJ/MTL → P3D)

Source: `toilet.html` viewer → **Download OBJ + MTL**. Meters, Y-up, origin at plan center,
base y=0, front faces **+Z** (cistern panel against the wall at z=−0.29). Import RAW — no axis
negation. Wall-hung pan, rim at 0.40 m, panel to 1.08 m; footprint 0.62 × 0.69 m (the pan hangs 5 cm proud of the panel face; the wall-anchored control pod does not move).

**Higher-polycount prop, unlike the other props in this project.** The bowl, seat and lid are
swept shells built from a 64-point squircle outline (16–22 rings each), not boxes — they are
CONCAVE and smooth-shaded. Do NOT try to make them convex Geometry components; use the
collision recipe below. No anims → no model.cfg (add one only if you want a lid rotation).

## Material → texture map (Face Properties)
| usemtl | texture | rvmat |
|---|---|---|
| porcelain_white_proc | `#(argb,8,8,3)color(0.95,0.94,0.92,1.0,co)` | `a3\structures_f\data\metal\metalclean1.rvmat` (glossy) |
| seat_white_proc | `#(argb,8,8,3)color(0.91,0.91,0.89,1.0,co)` | `a3\structures_f\data\metal\metalclean1.rvmat` |
| matte_black_proc | `#(argb,8,8,3)color(0.08,0.09,0.10,1.0,co)` | `a3\structures_f\data\metal\metal_plate.rvmat` (matte) |
| steel_proc | `#(argb,8,8,3)color(0.77,0.79,0.80,1.0,co)` | `a3\structures_f\data\metal\metalclean1.rvmat` |
| marble_tiles_02_co | `a3\structures_f_exp\data\tiles\marble_tiles_02_co.paa` | `a3\structures_f\data\metal\metalclean1.rvmat` |
| water_proc | `#(argb,8,8,3)color(0.62,0.85,0.90,0.55,ca)` | `a3\structures_f_exp\data\glass\glass.rvmat` |
| glass_panel_proc | `#(argb,8,8,3)color(0.11,0.12,0.14,1.0,co)` | `a3\structures_f\data\metal\metalclean1.rvmat` |
| led_warm_proc | `#(argb,8,8,3)color(1.0,0.95,0.85,1.0,co)` | mission neon rvmat (optional) or — |

## Mesh naming
- Wall side: `TLT_panel`, `TLT_panel_shelf`, `TLT_panel_led`, `TLT_flush_plate`,
  `TLT_flush_pad_1/2`.
- Bowl: `TLT_bowl_outer`, `TLT_bowl_under`, `TLT_bowl_rim`, `TLT_bowl_inner`, `TLT_bowl_sump`,
  `TLT_water`.
- Seat/lid: `TLT_seat`, `TLT_seat_top`, `TLT_seat_inner`, `TLT_lid` (raised ~78°),
  `TLT_hinge_l/r`.
- Bidet: `TLT_bidet_housing`, `TLT_bidet_arm`, `TLT_bidet_nozzle`, `TLT_bidet_tip`,
  `TLT_ctrl_body`, `TLT_ctrl_face`, `TLT_ctrl_btn_1..4`, `TLT_ctrl_led`.
- Fixings: `TLT_supply_valve`, `TLT_supply_pipe`, `TLT_bolt_cap_l/r`.

## LOD build
- **Resolution 1.0**: everything — ≈15.6k tris (bowl_outer 2816, bowl_inner 2560, seat 2048,
  lid 1856, under 1600, sump 1344, rest small). Fine for an interior prop. LOD 2.0: delete
  `TLT_bowl_inner`, `TLT_bowl_sump`, `TLT_water`, `TLT_bidet_*`, `TLT_ctrl_btn_*`, `TLT_panel_led`
  → ≈10.7k; for a real LOD 3.0 replace the shells with the four collision boxes below.
- **Geometry** (collision): do NOT import the shells. Draw 4 convex boxes by hand in Object
  Builder — panel `0.56 × 1.05 × 0.10` at z −0.29; pan block `0.37 × 0.33 × 0.61` centred
  (0, 0.2375, 0.05) — spans y 0.075–0.40, z ±0.305, so it encloses the underside dome and the full
  rim depth; seat slab `0.37 × 0.04 × 0.61` at y 0.42, z 0.05; control arm `0.145 × 0.05 × 0.30`
  centred (0.2025, 0.385, −0.09) — runs from the panel face into the bowl flank. That is the whole collision volume; players cannot enter the bowl.
- **Fire Geometry**: same 4 boxes.
- **View Geometry**: pan block + panel.
- No Roadway, no Paths, no Memory. Mass ~120. `class=house`, `map=hide`.

## config.cpp
`toilet-config.cpp` — `Land_AP_LuxToiletBidet_F`, House_F child, destrType=DestructNo.
Back against a wall; pairs with the lux tower suite baths and `shower.html`.
