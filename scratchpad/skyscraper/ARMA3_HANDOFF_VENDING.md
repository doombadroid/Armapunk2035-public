# Vending machine — OBJ/GLB → P3D handoff

Source: `vending.html` viewer → **Download OBJ + MTL**. Meters, Y-up, origin at floor centre.
Classic closed-front soda machine at 1:1: **0.81 w × 1.83 h × 0.84 d**.

**Locked sign sets — one retexture per shop, Synth-Meat + Cyberthreads Chrome '85, Lo-Point Surplus Stencil (option C):**

| shop | front 512×1536 | side 512×1024 |
|---|---|---|
| SYNTH-MEAT MARKET | `textures/signs/synthmeat_front.png` | `textures/signs/synthmeat_side.png` |
| CYBERTHREADS | `textures/signs/cyberthreads_front.png` | `textures/signs/cyberthreads_side.png` |
| LO-POINT FIREARMS | `textures/signs/lopoint_front.png` | `textures/signs/lopoint_side.png` |
| GROUNDED MOTORS (car shop) | `textures/signs/carshop_front.png` | `textures/signs/carshop_side.png` |
| GROUNDED AVIATION (air shop) | `textures/signs/airshop_front.png` | `textures/signs/airshop_side.png` |
| PACK RAT SURPLUS (gear shop) | `textures/signs/gearshop_front.png` | `textures/signs/gearshop_side.png` |
| ILL-EAGLE FIREARMS & GEAR (rebel guns + gear) | `textures/signs/illeagle_front.png` | `textures/signs/illeagle_side.png` |
| ILL-EAGLE VEHICLES (rebel air + ground) | `textures/signs/illeaglevehicles_front.png` | `textures/signs/illeaglevehicles_side.png` |
| HARD RESET PHARMA (medical) | `textures/signs/pharma_front.png` | `textures/signs/pharma_side.png` |
| REALLY ILL-EAGLE VEHICLES (black market, New Drachma only) | `textures/signs/reallyilleagle_front.png` | `textures/signs/reallyilleagle_side.png` |
| REALLY ILL-EAGLE FIREARMS & GEAR (black market, New Drachma only) | `textures/signs/reallyilleagleweapons_front.png` | `textures/signs/reallyilleagleweapons_side.png` |
| KABUKI ELECTRONICS (hack chips + firmware) | `textures/signs/kabuki_front.png` | `textures/signs/kabuki_side.png` |

Convert each PNG to .paa (`deploy/make_paa.py`), ship as e.g.
`mpmissions\__cur_mp.Malden\textures\synthmeat_front.paa`, and point the three LOGO materials
at them — one .p3d duplicate per shop. The machines replace shop NPCs. Option files
`{shop}_{a-d}_*.png` remain for reference; `vending-signs.html` previews the current shop's four.

## Logo slots — the point of this prop
Three faces, each with its **own material**, nothing else mapped to them:

| mesh | usemtl | size / shape |
|---|---|---|
| `LOGO_front_*` | `LOGO_front_ca` | 0.55 × 1.62 m **flat** sign panel, 0.012 m proud of the body; UV u across, v up |
| `LOGO_side_L_*` | `LOGO_side_l_ca` | 0.66 × 1.38 m flat quad, left flank |
| `LOGO_side_R_*` | `LOGO_side_r_ca` | 0.66 × 1.38 m flat quad, right flank |

Point each at your own texture, e.g. `mpmissions\__cur_mp.Malden\textures\vend_front.paa`.
UVs are clean 0–1 — author front art ~512×1536, sides ~512×1024. The front panel is the lit
one: give `LOGO_front_ca` a self-illuminated rvmat so it glows at night (the machine's only
light apart from the label strip). Duplicate the .p3d with different logo paths per brand.
In the viewer the slots render as plain blue lit panels.

## Build
- **Cabinet**: near-black gloss shell (`metal_panels_white_co` tinted dark), black top cap,
  base with 6-slot vent grille, 4 feet, door seam + 3 hinges on the left edge.
- **Flat front panel**: 0.55 × 1.62 m quad, framed by flat sills top/bottom and rails at the sides.
- **Pickup flap** set into the panel: frame, push door with steel push bar, dark recess.
- **Selection column** (right of panel): instruction card, coin plate with slot bezel + price
  window + round coin-return button + return cup, bill acceptor with slit, **9 selection
  buttons** each with a lit label window, lock cylinder.
- ~90 meshes / ~3.5k tris — closed body, no interior (nothing visible through a closed front).

## LODs
- LOD0 as exported. LOD1: drop buttons/hinges/vents, keep panel + column plates (~800 tris).
  LOD2: body + front panel (~150).
- **Geometry**: ONE box 0.81 × 1.83 × 0.84, mass ~320 kg. Fire/View: same box.
- No Roadway, no Memory, no model.cfg (nothing animated).

## config.cpp
`House_F` child (or `Thing` for a tippable prop), `destrType=DestructNo`. Rename the .p3d
every rebuild (`_r2`, `_r3`…) — Arma caches by path.

## Test checklist
1. Height vs a character: 1.83 m, eye-level near the coin slot (1.49 m).
2. Front logo art lands on the panel un-stretched, right way up; sides not mirrored.
3. Night: front panel and button labels glow, nothing else.
4. Geometry box blocks movement; flap and buttons don't snag.
