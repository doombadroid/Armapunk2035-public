# ARMA 3 HANDOFF — Desktop 3D printers (2 variants)

Source: `printer.js` (builders) / `printer.html` (viewer + OBJ/MTL export, two stages).
Export names: `printer_i3`, `printer_corexy`. Meters, Y-up, front = +Z, origin at floor center.

## Variants
- **A — i3 bedslinger** (`buildPrinterI3`): open frame, 0.50×0.50 m footprint, 0.60 m tall incl. spool. Orange printed parts, teal LCD, spool on top.
- **B — enclosed CoreXY** (`buildPrinterCoreXY`): 0.50×0.50 m cube, 0.585 m tall; rear spool pushes depth to ~0.65 m. Smoke acrylic panels + door, teal printed parts, blue touchscreen, white LED strips.

Both posed mid-print (nozzle just above bed).

## Tri counts (Resolution 1.0)
- i3: 68 meshes / ~3.8k tris. CoreXY: 100 meshes / ~3.9k tris (measured).
- Small-prop class — Resolution 1.0 = everything is acceptable (kitchen/toilet precedent).

## LODs
- LOD1 (~0.3): drop fans' blades/hubs, heatsink fins, wire looms, filament path/feed tube, knobs, hinges, idlers, pulleys, couplers, rod holders, belt strips, LED strips.
- LOD2 (~0.08): primary masses only — i3: base slab + frame plate + bed + spool disc + gantry bar (~180 tris). CoreXY: cube shell + skirt + bed + spool disc (~120 tris).

## Geometry LOD — convex components only, 1:1 with source boxes, never merged hulls
- **i3** (mass 14): base slab 0.50×0.09×0.50; frame plate box 0.38×0.35×0.03; bed slab 0.30×0.03×0.30 @ y 0.16; spool box 0.20×0.20×0.08 @ y 0.50. 4 components.
- **CoreXY** (mass 32): one cube 0.50×0.56×0.50 (it is a closed box — a single convex cube IS the source shape, not a merged hull); skirt band included; rear spool box 0.20×0.20×0.10. 2 components.
- Fire/View = Geometry.
- Exclude everywhere: glass panels/door, rods, leadscrews, belts, wires, nozzle, fans, LCD/screen, LED strips, filament runs, feet.

## Roadway
None — prop, nothing walkable.

## Config
- `class=house`, `map=hide`, destrType=DestructBuilding or Tree? → use `DestructDefault`; penetration material: `plastic.bisurf` body, `glass.bisurf` panels if split.
- No Memory LOD / model.cfg (nothing animates). No Paths.

## Materials (MTL names)
alu, alu_dark, steel, plastic_black, plastic_dark, plastic_orange (i3 accents), plastic_teal (CoreXY accents), brass (nozzle), pei (bed sheet), belt, rubber (feet), motor_black, fan_dark, glass_smoke (panels/door — transparent), lcd (emissive teal), screen (emissive blue), led (emissive white), wire, filament_orange, filament_teal.
Emissives (lcd/screen/led) → tiny `_ca.paa` or plain emissive rvmat; glass_smoke → standard glass rvmat, exclude from Geometry/Fire.

## UVs
World-scaled per doctrine (1 tile / 2 m) — at prop scale a single 0.5 m tile wrap is fine; exporter UVs are per-primitive, re-box-map in Object Builder if the flat colors are kept as one atlas.

## Checklist
- [ ] Export OBJ+MTL ×2 from `printer.html` (toolbar, top + bottom stage)
- [ ] LOD1/LOD2 decimation per ladder above
- [ ] Geometry/Fire/View convex boxes per list, mass 14 / 32
- [ ] glass_smoke faces → glass rvmat, excluded from Geometry/Fire
