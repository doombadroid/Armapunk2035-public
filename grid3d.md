# GRID 3D — map refresh, 3D minimap, connect-time cache

2026-09-08. Three pieces of work that share one renderer and one asset set:

1. **Refresh** the full-screen 3D map (`ui/html/map.html`, "MALDEN GRID") so it
   draws the island as it stands after the 2026-09-07 designer merge, and so no
   label still names a drug by its pre-rename name.
2. **Make the HUD minimap 3D** — a full port of the GRID renderer into the
   always-on HUD webview, heading-up chase camera.
3. **Cache at connect** — the landing screen's loader becomes a real progress
   readout for a background cache worker that pre-pulls the 3D map's assets, the
   satellite layer and every shop icon.

Owner decisions on record (2026-09-08): re-bake now, restart included; full GRID
port for the minimap, not a cheaper approximation; shared renderer module; capped
render budget plus a HUD toggle back to 2D; heading-up chase camera; `warm.html`
does the fetching and the landing page only displays; PLAY is never gated on the
cache; cache set = map text assets + all 251 item icons + satellite tiles.

---

## §1 What is stale, and why

`ui/html/malden_bld.txt` (17 346 rows), `malden_hf.txt` and `malden_msh.txt` were
last written by commit `e8a30e8f`, before `8fd1aec4` merged the designer's
MaldenFinal delivery — La Trinite HQ rebuilt, the skyscraper moved, decor
re-laid. Every building the 3D map draws is therefore at a pre-merge position,
and the moved tower is drawn where it no longer stands.

Markers are NOT stale in position: `fn_mapOpen.sqf`'s static payload reads
`allMapMarkers` live, so a marker the designer moved already arrives at its new
place. What is stale is marker **text** — the drug rename (`drugs.md` §1) landed
in the item catalogue and the processors, but the map layer in `mission.sqm`
still says Cocaine and Fentanyl.

---

## §2 The re-bake

`APS_fnc_mapBake` is a one-shot: it walks the terrain and the mission's objects
and emits `[MAPBAKE]` chunks to the RPT, which `tools/harvest_map_bake.py` turns
back into `malden_hf.txt` + `malden_bld.txt`. It has no boot call in the tree by
design — ~5k log lines is fine once and unacceptable forever.

**Ordering is the one thing that can silently ruin this run.** The skyline is not
in the PBO: `map_objects` is the only source of map data, and `APS_fnc_mapLoad`
spawns it into the world from `server/AP_server/init.sqf:236`. A bake that fires
before that finishes records terrain and nothing else, and the failure looks
exactly like a successful bake with a suspiciously small building count. The
temporary boot call therefore waits on a mapLoad-complete signal, not on a
`uiSleep` guess, and the harvest asserts a building count in the same order of
magnitude as the shipped file (17 346) before it overwrites anything.

Sequence:

1. Add the temporary boot call, gated on mapLoad completion.
2. Restart dev (.96).
3. Harvest `[MAPBAKE]` → `malden_hf.txt`, `malden_bld.txt`.
4. Re-run `tools/bake_map_meshes.py` for model paths new since the last bake
   (the rebuilt HQ, the moved `custom_p3ds\skyscraper30_r17.p3d`).
5. `tools/test_bake_map_meshes.py` must pass — it validates the shipped
   artifacts against each other, and it is the gate on this step.
6. Remove the boot call. It does not ship.

Heightfield format, cell size and row order are unchanged; the page's parser is
untouched by this work.

---

## §3 Marker text — the drug rename

Hand-edited in the shipped `mission/Armapunk2035.Malden/mission.sqm`. Two rules
constrain the edit and both are pre-existing:

- The shipped sqm is NEVER saved from 3DEN. Editing the `text=` attributes in
  place is the only route.
- `tools/map_codegen.py` syncs marker positions and new markers, but **marker
  renames do not sync** — so this cannot be done in the editor and applied.

| current text | new text |
|---|---|
| `Cocaine Field` | `Smash Field` |
| `Fentanyl` | `Boost` |
| `Fentanyl Pickup` | `Boost Pickup` |
| `[  Ashfall ] ---- Produces Marijuana, Processed Cocaine` | `[  Ashfall ] ---- Produces Marijuana, Processed Smash` |
| `Ephedra` | `Sparkdust` |
| `Phosphorus` | `Redshift` |
| `Hydrogen` | `Toxic Slurry` |

Names come from `drugs.md` §1's rename table (`cocainep`→`smash`,
`fentanylu`→`boost`, `ephedrau`→`sparkdust`, `phos`→`redshift`,
`hydro`→`toxicslurry`). Prices, weights and keys are already renamed; this is
display text only and changes no behaviour.

Alongside it, a sweep for stale drug words in anything the map draws or the map
code comments: `initServer.sqf`'s ring definitions carry `"Cocaine Field"` and
`"Fentanyl"` in comments beside the marker ids, and any label constant in
`map.html` that names a drug is corrected in the same pass. `edenNPC_data.sqf`'s
`"heroin"` tokens are NPC role tags, not display text, and are out of scope.

One straggler rides along because it is the same defect and one line:
`briefing.sqf:60` still lists `heroin` among the illegal materials, beside `smash`
and `black lace` which the rename already corrected. There is no heroin key in the
catalogue — `drugs.md` §1 never created one — so the word names nothing. It becomes
`boost`.

Landmark holograms in `map.html` (`FEDX/FEDY` 9762/3895, the penitentiary on the
same anchor, the evidence lockup at 9457/4226) are on the fed island and were not
touched by the designer merge. Verified, left as they are.

---

## §4 The shared renderer — `ui/html/grid3d.js`

The minimap is a full port, so there are two consumers of one renderer. It is
extracted rather than copied: a duplicated WebGL renderer means every future map
fix has to land twice, and the copies drift.

**Loading.** `A3API.RequestFile("ui\\html\\grid3d.js")` then `eval`, exactly the
path `webui.js` already takes. A `<script src>` cannot work on these pages — they
have no resolvable base URL and the src quietly resolves to nothing.

**What moves into the module:** GL context + program setup, the terrain mesh
built from the heightfield, the satellite drape, the building batcher and the
`malden_msh` mesh library, water, and the asset loaders for the three text files.

**What stays with each page:** camera, input, blips, labels, chrome. `map.html`
keeps its own camera, search, marker overlay and landmark holograms; `hud.html`
gets a much smaller camera and reuses its existing blip layer.

**Blips stay DOM** on both pages, drawn over the GL canvas. Text in GL on a
software rasterizer is a wasted frame, and the HUD's blip layer already works.

`map.html` must look and behave identically after the extraction. That is the
acceptance test for this step, before the minimap exists at all.

---

## §5 The 3D minimap

Lives where the current one does — `#map` in `ui/html/hud.html`, 13 rem square,
top-left, in the always-on HUD webview.

**Camera: heading-up chase.** Positioned behind and above the player, yaw follows
player heading, fixed pitch. It is fed by the existing `pos`/`dir` push at 12 Hz,
so it inherits the 1:1 responsiveness PR15 tuned for — and the same reasoning
applies: no easing, no transitions. A transition against an 83 ms push interval
is a lag, which is the complaint it would appear to fix.

**Render budget.** The HUD webview never closes, so this is a cost the whole
session pays and it is bounded deliberately:

- frame cap ~12 fps, matching the push rate — more frames than pushes draw the
  same state twice
- buildings culled to the zoom radius (500 m default)
- satellite drape at the 128 mip
- rAF **stops** when the player is stationary and no push has landed for ~1 s,
  which is the house rule every shipped screen obeys

**Toggle.** Deck settings gains `MINIMAP: 3D / 2D`, persisted with the other HUD
preferences. 2D restores today's tile panel, which stays in the page unchanged.
Default is 3D. This exists because the in-game web surface has a documented
history of costing frames, and the escape hatch has to be one switch away for a
player whose box it does not suit — not a patch.

---

## §6 Connect-time cache

**`warm.html` is the worker.** It already exists as a tile warmer: an RscTitles
webview cut 8 s into connect from `core/init.sqf:71`, a 0.02 × 0.02 speck that
draws nothing and idles forever. That lifetime is why it, and not the landing
page, does the fetching — the landing dialog closes on DEPLOY, and anything it
had in flight dies with it.

It gains the webui bridge (proven to work in a title layer by `AP_map_warm`
itself, per `fn_hudWebInit.sqf`) and reports `done` / `total` to SQF as it works.

**Queue, in priority order:**

1. `malden_hf.txt`, `malden_bld.txt`, `malden_msh.txt` via `RequestFile`. Small,
   and now needed at HUD boot as well as on the first M press, because the
   minimap is 3D.
2. Satellite tiles — the existing 169 × {128, 256}, plus whichever mip the 3D map
   and the new minimap actually sample, so nothing converts on first open.
3. All 251 `icons/*.paa` (2.9 MB) through the mission-root candidate ladder
   `WEBUI.texture` uses — `RequestTexture` alone only resolves absolute
   game-content paths. Kills first-open pop-in on shop, inventory, loot, storage
   and fitting.

Concurrency stays at the existing 3 in flight, and every fetch keeps its
`.catch` — a miss resolves with a stub rather than rejecting, so failures must
not stall the pump.

**Landing side.** `fn_landingData.sqf:72` hardcodes `loadPct` to 100 today. It
becomes the real figure and is re-pushed as the worker reports. The landing page
already renders `loadPct` verbatim and needs no change.

**PLAY is never gated.** The bar is informational. A player who deploys at 3 %
gets the world immediately and the cache keeps filling behind it. Nothing in the
queue is required for correctness — every consumer already handles a cold asset,
which is what makes a non-blocking cache safe.

---

## §7 Shipping

`hud.html`, `landing.html` and `warm.html` are not in the server-served set
(`server/AP_server/web/ui/html/`), so unlike `map.html` they cannot be hot-served
and ship by repack. The restart the re-bake needs covers them.

Order of work, each step verifiable before the next:

1. Re-bake (the restart) — `test_bake_map_meshes.py` green, building count sane.
2. Marker text + stale-name sweep — visible in-game on the 2D map and the GRID.
3. `grid3d.js` extraction — `map.html` unchanged on screen.
4. Minimap camera + budget + toggle — walk and drive, watch frame cost.
5. Cache worker + real `loadPct` — connect twice, second one cold-free.

## §8 Out of scope

- Any change to the marker data model, or migrating runtime markers into the map
  layer. Position sync already works.
- Re-skinning the drug `.paa` art. `drugs.md` §1 keeps the pixels and renames the
  files; a visual pass is separate work.
- Widening the map's ESP guard. The payload stays the player's own position,
  their own group and their own markers.
- The web map on the website. This is the in-game GRID only.
