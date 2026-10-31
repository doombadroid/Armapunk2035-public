# F770-class industrial FDM printer — Claude Code handoff (OBJ/MTL → P3D)

Source: `f770.html` → **Download OBJ + MTL**. Builder `f770.js` (`buildF770`, `poseF770`).
Meters, Y-up, origin at floor center, front faces **+Z**. Import RAW — no axis negation.

## ⚠ Mirroring — the build is currently mirrored in-game (v5 report)
Symptom: the whole printer is flipped left↔right and the READY/PRINTING text reads backwards. That is
an axis-negating import (X or Z negated on the way into Object Builder), not a model problem: the OBJ
is authored directly in Arma's handedness (X east, Y up, Z north — same as O2's X/Y/Z) and must be
imported **without** any "flip X"/"mirror"/"Z-up→Y-up" option. Check:
1. Re-import the OBJ RAW. Text on `f770_screen_*` must read correctly when looking at the front (+Z side, the open chamber). The HMI is on the **right** (x=+0.87) when facing the front.
2. If the importer forces a flip, undo it in Object Builder: select all, Points → Mirror **X** (or Z — whichever the importer negated), then Faces → Reverse (mirroring inverts winding; unreversed faces will render inside-out / dark).
3. All Memory-LOD points and axis pairs in this document are in the RAW (un-negated) frame — after a mirror the head would run the wrong way and `hmi_trigger` sits on the wrong side. Re-check those after fixing.
Never fix the mirror by negating the text UVs only — the geometry (HMI side, bay doors, grille) would stay flipped.
Envelope 2.24 W × 1.80 H (player height) × 1.09 D. ~145 meshes, ~2.4k tris. Empty bed — no printed part.

Export with the pose at t=0 (the page starts there): bridge at its −X end, head at the front, platform at
first-layer height (tips 1 cm above the sheet). Chamber is open at the front — no door.
Both screen quads export overlapping at the same spot (`f770_screen_ready`, `f770_screen_printing`) — keep both; they are hide-toggled.

## Animated selections (this is why the model needs a model.cfg)
Three motion groups + one hide pair. The OBJ flattens groups, but every mesh keeps its group prefix — select by name prefix in
Object Builder and make one named selection per group:

| selection | meshes | motion | Memory LOD points |
|---|---|---|---|
| `f770_bridge` | `f770_bridge_*`, `f770_ymotor`, `f770_ybelt` **+ everything in `f770_head`** (child) | translation along **X**, ±0.28 m about x=−0.18 | `bridge_axis` = (−0.18, 1.39, 0) → (0.82, 1.39, 0) |
| `f770_head` | `f770_head_*`, `f770_tip_model`, `f770_tip_support` | translation along **Z**, ±0.16 m about z=0 | `head_axis` = (0, 1.24, 0) → (0, 1.24, 1) |
| `f770_platform` | `f770_tray`, `f770_sheet`, `f770_tray_arm`, `f770_zcar_1/2` | translation along **−Y**, 0 → −0.34 m (sheet at y 1.05 = first layer, tips end 1.06; bottom of travel y 0.71) | `platform_axis` = (0, 0.70, 0) → (0, 1.70, 0) |
| `f770_screen_ready` / `f770_screen_printing` | one quad each, coplanar on the HMI | `hide` anims on source `printing`: READY shown at phase 0, PRINTING at phase 1 | — |

Nesting: the head rides on the bridge. In Object Builder the `f770_head` faces must also belong to
`f770_bridge` (bone parent `f770_head` → `f770_bridge` in the skeleton). `f770-model.cfg` has this.

Direction convention: translations use `axis` memory pairs with `offset0/offset1` in **meters along the
axis line** (axis line length = 1 m so offsets are literal meters).

## Print-cycle driver (SQF)
Houses have no `time` controller for translations, so all three translations are `source="user"` and a per-frame loop
sets phases (mirrors `poseF770()` in `f770.js`). **The head only moves while a job is running**:
`_p setVariable ["ap_printing", true, true]` starts it (Start/Stop UserActions in the config toggle this);
when false the loop idles and the pose is left where it stopped. Drop this in the class init EH:

```sqf
// _p = printer object. PASS 1.3 s, 20 passes/layer, 12 layers per demo loop. _t = accumulated print time.
[_p] spawn {
  params ["_p"]; private _t = 0;
  while { alive _p } do {
    if !(_p getVariable ["ap_printing", false]) then { _p animate ["printing", 0, true]; sleep 0.25; continue };  // screen → READY
    _t = _t + 0.03;
    private _pass = floor (_t / 1.3); private _k = (_t mod 1.3) / 1.3; private _e = _k*_k*(3-2*_k);
    private _x = if (_pass mod 2 == 0) then { _e } else { 1 - _e };     // 0..1 across ±0.28 m
    private _layer = floor (_pass / 20); private _i = _pass mod 20;
    private _z = if (_layer mod 2 == 0) then { _i / 19 } else { 1 - _i / 19 };
    _p animate ["head_x", _x, true];
    _p animate ["head_y", _z, true];
    _p animate ["platform_z", ((_layer mod 12) * 0.003) / 0.34, true];
    _p animate ["printing", 1, true];   // screen → PRINTING
    sleep 0.03;
  };
};
```
Start/Stop print UserActions in `f770-config.cpp` (`position = "hmi_trigger"`).
Config anims live in an ADDON PBO — mission-folder simple objects have no simulation (see LESSONS.md).

## Material → texture map (Face Properties)
Big surfaces = real a3 textures (viewer previews `textures/a3/…png`; point faces at the `.paa`). Accents procedural.

| usemtl | texture | rvmat |
|---|---|---|
| metal_panels_white_co | `a3\structures_f_exp\data\metal\metal_panels_white_co.paa` — shell, pillars, head cover | `a3\structures_f\data\metal\metalclean1.rvmat` |
| metal_servicehangar_black_co | `a3\structures_f_enoch\data\metal\metal_servicehangar_black_co.paa` — cap ring, top, opening trim, bay doors, head body | metalclean1 |
| metalcoloureddark_co | `a3\structures_f\data\metal\metalcoloureddark_co.paa` — plinth | metalclean1 |
| metal_seams_01_co | `a3\structures_f_exp\data\metal\metal_seams_01_co.paa` — chamber liner (5 faces) | metalclean1 |
| metal_gray_clean_co | `a3\structures_f\data\metal\metal_gray_clean_co.paa` — X rails, bridge beam, leadscrews, Z rails | `a3\structures_f\data\metal\metalclean1.rvmat` |
| metalclean1_co | `a3\structures_f\data\metal\metalclean1_co.paa` — platform tray | metalclean1 |
| trim_charcoal_proc | `#(argb,8,8,3)color(0.13,0.14,0.16,1.0,co)` — carriages, motors, mounts, handles, HMI bezel, seams | metalclean1 |
| rubber_proc | `#(argb,8,8,3)color(0.05,0.06,0.07,1.0,co)` — feet, slats, fan blade | matte |
| ap_f770_screen_ready_co / ap_f770_screen_printing_co | `textures/ap/ap_f770_screen_ready_co.png` / `_printing_co.png` (512×358, convert to `.paa`, ship in the addon) — HMI READY / PRINTING screens | emissive rvmat (self-lit) |
| led_proc / led_amber_proc | tiny emissive `_ca` or emissive rvmat (white status + chamber strips, amber bay/power) | emissive |
| brass_proc | `#(argb,8,8,3)color(0.79,0.64,0.29,1.0,co)` — tips | metalclean1 |
| heater_proc | `#(argb,8,8,3)color(0.48,0.16,0.10,1.0,co)` — heater block | metalclean1 |
| belt_proc / cable_proc | near-black procs | matte |

## LODs
- **1.0**: everything (~2.4k tris).
- **2.0**: drop belts, cables, fan, tips, grille slats, vent slots, LEDs, leadscrews/Z rails, bay labels (~1.4k).
- **3.0**: shell boxes + plinth + tray + screens (~270). Animations still apply (selections carry).
- **Geometry** (mass 900): 3 convex boxes — plinth `2.18×0.10×1.03` @ (0,0.15,0); lower body `2.24×0.52×1.09` @ (0,0.36,0);
  chamber+cap `2.24×1.18×1.09` @ (0,1.21,0). HMI, handles: none. The open chamber is too shallow to enter, so it stays one solid box.
- **Fire/View** = Geometry.
- No Roadway, no Paths. Memory LOD: the 3 axis pairs above + `hmi_trigger` = (0.87, 1.40, 0.60).

## Files
`f770.js`, `f770.html`, `f770-config.cpp`, `f770-model.cfg`, `three-d-stage.js`, `textures/a3/…` (6 pngs), `textures/ap/ap_f770_screen_*_co.png` (2 custom, → .paa).

## rvmat rule
Only rvmats that actually ship in Arma 3 may be referenced. `a3\structures_f\data\metal\metal_plate.rvmat`, `metal_rust.rvmat` and `a3\structures_f\data\wood\wood_plank.rvmat` do NOT exist — a missing rvmat makes the engine fall back to a default material that renders rusty. Verified real: `a3\structures_f\data\metal\metalclean1.rvmat`, `a3\structures_f_exp\data\glass\glass.rvmat`. Check any new path against the shipped-rvmat index (`tools/texture_audit.py`) before use.
