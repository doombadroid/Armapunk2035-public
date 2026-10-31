# Jewelry Display Case — Claude Code handoff (OBJ/GLB → P3D)

Source: `jewelry-case.html` viewer → **Download OBJ + MTL**. Open variant: `jewelry-case-open.html` → p3d `ap_jewelry_case_open` — identical to pristine
except GLASS_top is swung 100° about the back-rail hinge line (y 1.302, z −0.27) with two
`CASE_hinge_*` brass blocks and ALL `JWL_*` displays removed (cleaned out; plaques remain);
the pane stays out of Geometry (Fire only). Smashed/robbed variant:
`jewelry-case-smashed.html` → separate p3d `ap_jewelry_case_smashed` (same rules below;
extra `SHARD_*`/`CUT_*`/`DEBRIS_*`/`SLAG_*` meshes; extra procs: `led_dead_proc`
`#(argb,8,8,3)color(0.72,0.70,0.65,1.0,co)`, `torch_char_proc` `#(argb,8,8,3)color(0.08,0.07,0.06,1.0,co)`,
`torch_glow_proc` `#(argb,8,8,3)color(1.0,0.54,0.20,1.0,co)` + mission neon rvmat for the molten lips).
Smashed TOP FRAME: the copper lid is torch-cut into rails `CASE_topframe_b/l/r/f1/f2`
(right + front rails have chunks burned out; one rail lies on the floor; charred ends +
molten lips). Smashed counter: 4 convex tiles `CASE_top_marble_a..d` with two torch-cut bites
(front-right chunk gone along with post_03 — stub + fallen post remain — plus a front-left
notch); charred kerf faces + glowing lips line every cut. Meters, Y-up, origin at plan
center, base y=0, front faces **+Z**. Import RAW — no axis negation. Storefront prop:
1.84 × 0.64 m footprint, 1.32 m tall. No doors/anims → no model.cfg, no Memory points.

## Material → texture map (Face Properties)
| usemtl | texture | rvmat |
|---|---|---|
| marble_tiles_02_co | `a3\structures_f_exp\data\tiles\marble_tiles_02_co.paa` | `a3\structures_f\data\metal\metalclean1.rvmat` |
| metal_dark_proc | `#(argb,8,8,3)color(0.14,0.15,0.18,1.0,co)` | `a3\structures_f\data\metal\metalclean1.rvmat` |
| brass_proc | `#(argb,8,8,3)color(0.79,0.64,0.30,1.0,co)` | `a3\structures_f\data\metal\metalclean1.rvmat` |
| silver_proc | `#(argb,8,8,3)color(0.85,0.87,0.89,1.0,co)` | `a3\structures_f\data\metal\metalclean1.rvmat` |
| velvet_proc | `#(argb,8,8,3)color(0.17,0.12,0.29,1.0,co)` | — |
| glass_clear_proc | `#(argb,8,8,3)color(0.90,0.95,1.00,0.20,ca)` | `a3\structures_f_exp\data\glass\glass.rvmat` |
| led_white_proc | `#(argb,8,8,3)color(1.0,0.96,0.86,1.0,co)` | mission neon rvmat (optional) or — |
| white_marking_proc | `#(argb,8,8,3)color(0.90,0.90,0.88,1.0,co)` | — |
| gem_ruby_proc | `#(argb,8,8,3)color(0.88,0.14,0.29,1.0,co)` | `a3\structures_f\data\metal\metalclean1.rvmat` |
| gem_emerald_proc | `#(argb,8,8,3)color(0.12,0.77,0.48,1.0,co)` | `a3\structures_f\data\metal\metalclean1.rvmat` |

## Mesh naming
`CASE_*` structure (plinth, cabinet, kickline, top_marble, post_01..04, top_frame, led_f/b,
bracket_l/r, plaque_*), `GLASS_*` panes (front/back/left/right/top/shelf), `DECK_velvet`,
`JWL_*` jewelry displays (ring cones/rings, watch, T-bar + bangles, busts + chains + pendants,
earring card, shelf rings, coil).

## LOD build
- **Resolution 1.0**: everything.
- **Geometry** (collision): `CASE_plinth`, `CASE_cabinet`, `CASE_top_marble*`, `CASE_post_*`,
  `CASE_topframe_*` rails — each is one convex box, import per-object. EXCLUDE glass, deck, LED,
  brackets, plaques, all `JWL_*`, `SHARD_*`, `CUT_*`, `DEBRIS_*`, `SLAG_*`, the post stub and fallen post
  (tiny visual clutter — never collision).
  Smashed variant: the missing front/top panes mean players can reach through — that is
  intended; keep Fire = surviving panes only.
- **Fire Geometry**: Geometry set + the five `GLASS_*` panes as separate penetrable
  components (shots must pass and shatter-decal correctly).
- **View Geometry**: `CASE_cabinet` + `CASE_top_marble`.
- No Roadway, no Paths, no Memory LOD. Mass ~150. `class=house`, `map=hide`.

## config.cpp
`case-config.cpp` — `Land_AP_JewelryCase_F`, plain House_F child, destrType=DestructNo
(or DestructBuilding + glass hitpoints later if you want smashable displays).
Place indoors against a storefront window; base sits flat on the floor.
