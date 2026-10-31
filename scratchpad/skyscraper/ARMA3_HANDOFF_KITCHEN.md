# Integrated Kitchen — Claude Code handoff (OBJ/MTL → P3D)

Source: `kitchen.html` viewer → **Download OBJ + MTL**. Meters, Y-up, origin at plan center,
base y=0, front faces **+Z** (back goes against a wall). Import RAW — no axis negation.
One model: 3.0 × 0.6 m run, worktop at 0.9 m, splash to 1.35 m. No anims → no model.cfg.

## Material → texture map (Face Properties)
| usemtl | texture | rvmat |
|---|---|---|
| native_house_stone_floor_co | `a3\structures_f_exp\data\stone\native_house_stone_floor_co.paa` | `a3\structures_f\data\metal\metalclean1.rvmat` |
| woodfine_01_co | `a3\structures_f_enoch\data\wood\woodfine_01_co.paa` | — |
| steel_proc | `#(argb,8,8,3)color(0.77,0.79,0.80,1.0,co)` | `a3\structures_f\data\metal\metalclean1.rvmat` (stainless: basin, faucet, pulls) |
| metal_dark_proc | `#(argb,8,8,3)color(0.14,0.15,0.18,1.0,co)` | `a3\structures_f\data\metal\metalclean1.rvmat` |
| glass_black_proc | `#(argb,8,8,3)color(0.05,0.06,0.08,1.0,co)` | `a3\structures_f\data\metal\metalclean1.rvmat` |
| white_marking_proc | `#(argb,8,8,3)color(0.90,0.90,0.88,1.0,co)` | — |
| burner_proc | `#(argb,8,8,3)color(0.07,0.07,0.07,1.0,co)` | — |

## Mesh naming
`KIT_*` carcass/top/doors/pulls (worktop = 4 convex pieces `KIT_top_l/r/f/b` around the sink
void), `SINK_basin` (ONE welded mesh: 4 walls + floor, 0.28 m deep, steel_proc + metalclean rvmat = stainless) + drain/faucet, `OVEN_*` frame/door/handle/panel/knobs/window,
`STOVE_*` hob/burners/grates.

## LOD build
- **Resolution 1.0**: everything.
- **Geometry** (collision): `KIT_plinth`, `KIT_carcass_l1..l5` (splits around the sink void), `KIT_carcass_r`, `KIT_oven_bay`, `KIT_top_l/r/f/b`,
  `KIT_splash` — each one convex box, import per-object. EXCLUDE doors/drawers/pulls, all
  `SINK_*`, `OVEN_*`, `STOVE_*` (thin detail — bullets yes, bodies no).
- **Fire Geometry**: Geometry set + `OVEN_door`, `STOVE_hob`.
- **View Geometry**: carcasses + tops + splash.
- No Roadway/Paths/Memory. Mass ~220. `class=house`, `map=hide`.

## config.cpp
`kitchen-config.cpp` — `Land_AP_KitchenRun_F`, House_F child, destrType=DestructNo.
Sits flat on floor, back against wall. Pair with lux/20F interiors or Malden houses.
