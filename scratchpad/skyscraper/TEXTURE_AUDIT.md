# Task for Claude Code — audit + re-extract every texture this project references

**Problem:** the F770 printer (`ap_printer_f770.p3d`) shows rusty metal in-game on surfaces that are
clean white/grey in the viewer (`f770.html`). The viewer previews `textures/a3/**.png`, whose
provenance is unknown — some may be stand-ins saved under a real Arma filename. The game reads the
real `.paa` (and the `.rvmat`, which the viewer ignores entirely). One of those disagrees.

## 1. Find out what the built P3D actually uses (do this first)

For the F770, and any other of our P3Ds you have handy:

```
# mikero / armake2 / hemtt — whichever is installed
armake2 inspect ap_printer_f770.p3d          # or: dump the MLOD with a P3D reader
```

List every texture and rvmat path per face-selection. Compare against the intended map in
`ARMA3_HANDOFF_F770.md` §"Material → texture map". Report any face whose texture is NOT one of:

```
a3\structures_f_exp\data\metal\metal_panels_white_co.paa       (shell, pillars, head cover)
a3\structures_f_enoch\data\metal\metal_servicehangar_black_co.paa
a3\structures_f\data\metal\metalcoloureddark_co.paa
a3\structures_f_exp\data\metal\metal_seams_01_co.paa
a3\structures_f\data\metal\metal_gray_clean_co.paa
a3\structures_f\data\metal\metalclean1_co.paa
```

Also check the rvmat on those faces. `metal_plate.rvmat` / `metalclean1.rvmat` are what the handoff
asked for. If the faces got a rusty rvmat (`metal_rust.rvmat`, anything `*_rust*`, `*_old*`,
`*_dirty*`) or an rvmat whose `_co`/`_smdi` stages point at a rusty sheet, that is the bug —
fix the rvmat assignment in Object Builder and stop here.

## 2. Re-extract every referenced texture from the game install

Path contract (unchanged from `TEXTURE_EXTRACTION.md`):
`a3\x\y\z_co.paa` → `textures/a3/x/y/z_co.png`, lowercase, forward slashes. Overwrite what's
there — assume nothing present is trustworthy. Keep alpha on `_ca`. First (largest) mip only.

### Textures (`.paa` → `.png`) — all 44 referenced across the project

```
a3\data_f_argo\images\assetmaldenstructures_co.paa
a3\map_malden\data\ui_malden_ca.paa
a3\props_f_aow\civilian\gallery\data\galleryframe_01_large_portrait_picture_f_co.paa
a3\props_f_aow\civilian\gallery\data\galleryframe_02_square_picture_co.paa
a3\props_f_aow\civilian\gallery\data\galleryframe_03_large_f_co.paa
a3\roads_f\runway\data\asphalt_runway_ca.paa
a3\roads_f\runway\data\asphalt_tile_co.paa
a3\roads_f\sidewalks\data\sidewalk_01_co.paa
a3\structures_f\civ\offices\data\office_addons_co.paa
a3\structures_f\data\brick\ind_brick_2_co.paa
a3\structures_f\data\concrete\concrete_floor_03_co.paa
a3\structures_f\data\concrete\concrete_wall2_co.paa
a3\structures_f\data\concrete\radar_body_concrete_co.paa
a3\structures_f\data\metal\metal_gray_clean_co.paa
a3\structures_f\data\metal\metalclean1_co.paa
a3\structures_f\data\metal\metalcoloureddark_co.paa
a3\structures_f\data\metal\rollup_combo_co.paa
a3\structures_f\data\plaster\plaster01_4x4_co.paa
a3\structures_f\data\plaster\plaster03_4x4_office_co.paa
a3\structures_f\data\tile\tile_04a_co.paa
a3\structures_f\data\tile\tile_05_co.paa
a3\structures_f_aow\civilian\gallery_01\data\gallery_floor_parquet_b_co.paa
a3\structures_f_aow\civilian\gallery_01\data\gallery_wall_plaster_a_co.paa
a3\structures_f_argo\civilian\house_big02\data\i_house_big_02_b_pink_mlod_co.paa
a3\structures_f_argo\data\roof\church_01_v2_roof01_4x4_co.paa
a3\structures_f_enoch\data\concrete\concrete_panels_co.paa
a3\structures_f_enoch\data\floor\concrete\concrete_floor_02_co.paa
a3\structures_f_enoch\data\floor\wood_floor\parquets1dark_co.paa
a3\structures_f_enoch\data\metal\metal_green_paint_co.paa
a3\structures_f_enoch\data\metal\metal_servicehangar_black_co.paa
a3\structures_f_enoch\data\metal\metal_universal_dirty_co.paa
a3\structures_f_enoch\data\roof\asphalt_roof_a_co.paa
a3\structures_f_enoch\data\wood\planksold_02_co.paa
a3\structures_f_enoch\data\wood\wood_plank_old_co.paa
a3\structures_f_enoch\data\wood\woodfine_01_co.paa
a3\structures_f_enoch\infrastructure\pavements\data\concrete_pavements_co.paa
a3\structures_f_exp\data\concrete\concrete_clean_co.paa
a3\structures_f_exp\data\glass\window_set_dark_2_ca.paa
a3\structures_f_exp\data\metal\metal_panels_white_co.paa
a3\structures_f_exp\data\metal\metal_seams_01_co.paa
a3\structures_f_exp\data\roof\airport_02_terminal_bitumen_co.paa
a3\structures_f_exp\data\stone\native_house_stone_floor_co.paa
a3\structures_f_exp\data\tiles\marble_tiles_01_co.paa
a3\structures_f_exp\data\tiles\marble_tiles_02_co.paa
a3\structures_f_exp\data\wood\hotel_02_floor_co.paa
a3\structures_f_exp\data\wood\wooden_bridge_co.paa
```

### Rvmats — copy as plain text to `textures/<same path>.rvmat`, and ALSO extract every `.paa` they reference (`_nohq`, `_smdi`, `_as`, `_dt`, `_mc`) to the mirrored path

```
a3\data_f\penetration\concrete.rvmat
a3\structures_f\data\metal\metal_plate.rvmat
a3\structures_f\data\metal\metal_rust.rvmat
a3\structures_f\data\metal\metalclean1.rvmat
a3\structures_f\data\wood\wood_plank.rvmat
a3\structures_f_argo\civilian\house_big02\data\i_house_big_02_b_pink_multi2.rvmat
a3\structures_f_exp\data\glass\glass.rvmat
```

Rvmats are usually binarized (`raP`) inside PBOs — derapify (`armake2 derapify`, `hemtt`, or
mikero DeRap) before saving. If `metal_plate.rvmat` turns out to have a rusty `_smdi`/`_dt` stage,
say so; that would explain the F770 and we'll switch rvmat.

### Where the PBOs live
`structures_f.pbo`, `roads_f.pbo`, `data_f.pbo` → `addons/`; `structures_f_exp.pbo` → `expansion/addons/`;
`structures_f_enoch.pbo` → `enoch/addons/`; `structures_f_argo.pbo`, `data_f_argo.pbo`,
`map_malden.pbo` → `argo/addons/`; `props_f_aow.pbo`, `structures_f_aow.pbo` → `aow/addons/`.
Search rather than assume; extract only the listed files.

## 3. Deliver

- `textures/MANIFEST.md`: one row per file — Arma path, source PBO, SHA-1 of the `.paa`,
  PNG size, `replaced` / `unchanged` (compare to the previous PNG's pixels), plus the rvmat stage
  summary (which `_co`/`_nohq`/`_smdi` each rvmat points at).
- The step-1 face/texture/rvmat dump for `ap_printer_f770.p3d` as `f770-handoff/P3D_AUDIT.md`.
- Don't touch `textures/ap/` (our own screens) or any `.js`/`.html`.

Open `f770.html` afterwards — if the shell still looks white/grey in the viewer but rusty in game,
the bug is in step 1 (the P3D), not the textures.
