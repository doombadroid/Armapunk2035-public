# F770 Fabricator — design spec (replaces both desktop printers with one animated model)

Owner request (2026-09-02): "replace the 3d printers with this one model. Note that it moves while
its printing. See the excavator truck for animation example." Source drop: `~/Downloads/Printer.zip`
(`f770-handoff/`: `f770.js` builder + `three-d-stage.js`, `ARMA3_HANDOFF_F770.md`, `f770-config.cpp`,
`f770-model.cfg`, 6 vanilla texture previews, 2 custom HMI screen PNGs). The handoff is the
completed design dialogue; this file records how it lands in THIS codebase and the decisions the
handoff could not make for it. Precedent for everything moving: the Resource Extractor
(`core/vehicle/fn_rigClient.sqf` — the "excavator truck").

## 1. What exists today

- Printers are placeable house items `printer_i3` (tier 1) and `printer_corexy` (tier 2), tier
  table in `core/config/fn_fabCfg.sqf` (`case "tier"`), row = `[slots, speed, level, itemKey,
  p3dName, displayName, machine, collides, lift]`. Server (`APS_fnc_fabSRV`) spawns a
  `Land_HelipadEmpty_F` ANCHOR carrying identity/tags; every client draws the visual with
  `AP_fnc_fabModel` = ONE `createSimpleObject` (mission `custom_p3ds\<p3dName>.p3d`) attached at
  `[0,0,lift]`. Interaction is proximity (`AP_fnc_fabNear`, 4 m), never cursorObject.
- Models are GENERATED: `scratchpad/skyscraper/harness_printer.mjs` (node + three) dumps the
  three.js builders to JSON, `build_printer.py` writes MLOD p3ds (visual 1.0 + coarse 50.0), then
  the p3ds are binarized (p3dmemories.md §7) into `mission/.../custom_p3ds/`. Origin = bbox centre
  (the engine autocentres simple objects; authored origins are discarded).
- Job clock is the database's (`house_printer_jobs.finish_at` epoch); the server never times.
- Mission-embedded p3ds have NO config → no model.cfg animation, no `animate`, no
  `setObjectTexture`, no UserActions. The handoff's addon-PBO route (`Land_AP_PrinterF770_F`,
  `AnimationSources`, `f770_print.sqf`) does not apply here: the client mod is not the place for a
  house item, and every other custom model here is mission-embedded.

## 2. The model: one F770, split into parts (the rig's method)

Motion on a mission-embedded model = separate p3ds moved by script. The F770 becomes FIVE p3ds,
all generated from `f770.js` by a new `harness_f770.mjs` + `build_f770.py` (same pipeline, same
Lod class, same material derivation from the dump), grouped by mesh-name prefix exactly as the
handoff's selection table:

| part p3d | meshes | moves |
|---|---|---|
| `ap_printer_f770_body_r1` | everything not below (shell, plinth, rails, HMI bezel, LEDs, bay, …) | static, attached at `[0,0,lift]` |
| `ap_printer_f770_bridge_r1` | `f770_bridge_*`, `f770_ymotor`, `f770_ybelt` | X (left/right), ±0.28 m about its rest |
| `ap_printer_f770_head_r1` | `f770_head_*`, `f770_tip_model`, `f770_tip_support` | rides on the bridge; Z (front/back), ±0.16 m |
| `ap_printer_f770_platform_r1` | `f770_tray`, `f770_sheet`, `f770_tray_arm`, `f770_zcar_1/2` | down, 0 → −0.034 m over 12 layers (3 mm/layer, demo loop) |
| `ap_printer_f770_screen_ready_r1` / `_printing_r1` | one quad each, coplanar on the HMI | `hideObject` toggled (local effect, fine on client-local objects) |

Offsets: each part is autocentred, so its attach offset = (part bbox centre − body bbox centre),
design frame (metres, Y-up, front +Z) → attachTo `[dx, dz, dy]`. `build_f770.py` COMPUTES these
and writes them to `custom_p3ds/f770_parts_data.sqf` (generated, like `lux_doors_data.sqf`);
nothing is transcribed by hand. Lift = body half-height (≈0.90).

Materials: big surfaces → the vanilla `.paa`/`.rvmat` paths in the handoff table; accents →
procedural `#(argb,8,8,3)color(...)` from the dumped material colours (existing `tex_for` rule);
the two screens → `mpmissions\__cur_mp.Malden\ap_f770_screen_{ready,printing}_co.paa` (PNG → PAA
via `tools/make_paa.py`, shipped at the mission root like `ap_palette_co.paa`), emissive rvmat.

LODs per part: visual 1.0 (every mesh) + coarse 50.0 (measured group boxes), as build_printer.py.
Geometry: the BODY carries the handoff's three convex boxes (plinth / lower body / chamber+cap),
Fire/View = Geometry, mass 900. Moving parts have no geometry. See residual decision R1.

## 3. Animation driver (client, per anchor — `AP_fnc_fabAnim`, started by `AP_fnc_fabModel`)

Mirrors `fn_rigClient.sqf`: one loop per client per anchor, alive while the anchor exists, all
state read from PUBLISHED anchor variables so every client computes the same pose:

- Server publishes on the anchor `AP_fabRun = [runStart, runUntil]` (serverTime seconds):
  on `queue`, `runUntil = max(runUntil, serverTime + secs)` and `runStart = serverTime` only if
  the machine was idle (`serverTime >= old runUntil`); on `reload`, `runStart = serverTime`,
  `runUntil = serverTime + max(remaining)` from `house_printer_jobs`. Nothing else touches it —
  collect/pickup do not stop a machine that still has other jobs, and a finished window simply
  expires.
- `printing = serverTime < runUntil`; print time `t = clamp(serverTime − runStart, 0, runUntil −
  runStart)` — frozen at the last pose when idle, exactly the handoff's `poseF770`.
- Pose (handoff/`poseF770` verbatim): PASS 1.3 s, ±0.28 m X smoothstep, 20 passes per layer
  boustrophedon over ±0.16 m Z, platform −3 mm per layer, 12 layers then reset. Bridge offset
  x = bx0 + dir·(−0.28 + 0.56·e); head attach = `[bridgeX, hy0 + z(t), hz0]`; platform
  `[px0, py0, pz0 − 0.003·(layer mod 12)]`. Screens: READY shown when idle, PRINTING when printing.
- Tick 0.05 s within `AP_fabAnimDistance = 120` m; 0.5 s snap otherwise (rig's far rule).
- `AP_fnc_fabModelClear` deletes all six objects (body + 4 parts + 2 screens); the anchor holds
  `AP_fabModel` = the body and `AP_fabParts` = the rest, so a client that drew it can un-draw it.

No sound (none requested). No LED material swap (impossible without config; the screens carry the
state).

## 4. Code changes

- `fn_fabCfg.sqf` tier rows 1 and 2 → `"ap_printer_f770"` (part BASENAME; fabModel appends
  `_body_r1` etc.), lift from the generated data file, `collides` unchanged (`false`: interaction
  stays proximity). Tier 3 (gunsmith bench) untouched.
- `fn_fabModel.sqf`: when the model is a multi-part basename (data file has an entry for it),
  spawn all parts from `f770_parts_data.sqf` offsets and start `AP_fnc_fabAnim`; otherwise the
  existing single-object path (the bench).
- `fn_fabModelClear.sqf`: clear parts too.
- `APS_fnc_fabSRV`: publish `AP_fabRun` in `queue` and `reload` (spawn) as in §3.
- `core/configuration.sqf` `AP_furnitureItems` stand-in for `printer_i3`/`printer_corexy`: the
  preview class becomes the same 2 m-class stand-in the gunsmith bench uses (a 2.24 m machine
  previewed as a PC case places wrong).
- Generated assets: 6 p3ds (binarized) in `custom_p3ds/`, `f770_parts_data.sqf`, 2 screen PAAs at
  the mission root. Old `ap_printer_i3_r1.p3d` / `ap_printer_corexy_r1.p3d` deleted from the
  mission; their generator sources move to `scratchpad/skyscraper/archive/`.
- Verification: `verify_f770.py` (bbox/offset/face counts per part, round-trip, ODOL v75 header
  sanity) + in-game: place a printer, queue a job, watch bridge/head/platform move and the screen
  flip; a second client sees the same pose; restart → pose resumes moving on reload.

## 5. Residual decisions (owner may flip any of these)

- **R1 Collision ON for the body.** The desk printers shipped with no collision by owner call
  (0.5 m props, "stuck in his own printer room"). The F770 is a 2.24 × 1.09 × 1.80 m machine and
  its handoff specifies geometry; walking through it reads as a bug. Interaction is unaffected
  (proximity). Flip: drop the Geometry/Fire/View LODs in `build_f770.py`.
- **R2 Item names unchanged.** `printer_i3` "i3 Fabricator" and `printer_corexy` "CoreXY
  Fabricator" keep their keys, prices, icons and tier stats; only the drawn model changes. The
  names no longer describe the machine — renaming display names is a one-line follow-up each.
- **R3 One model, two tiers** — tier 2 is not visually distinct from tier 1 any more. The
  READY/PRINTING screen is the only state shown.
- **R4 Pose is server-windowed, not per-job**: a machine with three overlapping jobs animates one
  continuous print until the last finishes. Layer count is the demo loop's 12, not the job's.
