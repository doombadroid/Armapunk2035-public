# GRID 3D Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refresh the 3D map's baked assets to the post-2026-09-07 island, rename the drug markers it draws, port its renderer into the HUD minimap behind a heading-up chase camera, and pre-cache the map assets, satellite tiles and item icons at connect.

**Architecture:** The WebGL renderer is extracted out of `map.html` into `ui/html/grid3d.js`, loaded by both `map.html` and `hud.html` through `A3API.RequestFile` + `eval`. The minimap becomes a second, much smaller camera over the same renderer. `warm.html` grows a webui bridge and becomes the cache worker whose progress the landing screen reports.

**Tech Stack:** SQF (mission + `@AP_server` addon), raw WebGL in CEF webviews (no libraries, no network, no storage), Python 3 for the bake/harvest tooling.

## Global Constraints

- **No libraries, no network, no storage in any page.** No `<script src>` (pages have no resolvable base URL), no CDN, no fetch/XHR, no localStorage. Everything arrives through `A3API.RequestFile` / `A3API.RequestTexture`.
- **Assume software WebGL.** The host rasterizes on the CPU. Budget shader cost, not triangle count alone.
- **idle = still.** rAF runs during interaction and for ~1 s after a data push, then stops. Every shipped screen obeys this.
- **The mandatory head block stays.** Every page keeps its `WEBUIReady` promise + `A3API.RequestFile("webui\\ui\\webui.js")` self-boot verbatim. A page without it renders and is deaf.
- **`mission.sqm` is plain text and is NEVER saved from 3DEN.** Hand-edit it; verify with `python3 tools/sqm_read.py`.
- **Client fn added → `Functions.h`. Server fn added → `server/AP_server/config.cpp`.** Otherwise the call silently fails.
- **`AP_*` = mission/client, `APS_*` = server addon.** Never flatten one into the other; the server compiles both trees into `missionNamespace` and same-named fns overwrite each other.
- **`core/configuration.sqf` is minified — append, never reformat.**
- Every task ends green on `bash tools/run_checks.sh`.
- Work commits straight to `main` (owner standing order, dev has no players).

## The test instrument

This repo has **no SQF test runner and no browser harness** — nothing outside Arma executes a line of SQF, and `tools/run_checks.sh` says so itself. TDD discipline is kept by changing the instrument, not by dropping it: every task below names an **observable red state** (a log line, a probe, a screenshot) that must be SEEN failing before the change, and seen passing after. A step that cannot be observed is marked unverified rather than assumed.

The three instruments used here:

- `tools/run_checks.sh` — structural gates, sub-second, offline.
- `python3 tools/html_js_check.py` — `node --check` over each page's JavaScript.
- The dev server at `/home/timb/arma3server_dev` (`loonydev`, port 2342, log `loonydev.log`), reloaded with `deploy/reload-armapunk2035.sh`, plus the Arma client driven through `tools/gamectl.py` (`shot`, `focus`, `key`, `sqf`).

---

### Task 1: Re-bake the 3D map's static assets

**Files:**
- Modify: `server/AP_server/init.sqf` (temporary boot call, added in step 3 and removed in step 9)
- Regenerate: `mission/Armapunk2035.Malden/ui/html/malden_hf.txt`
- Regenerate: `mission/Armapunk2035.Malden/ui/html/malden_bld.txt`
- Regenerate: `mission/Armapunk2035.Malden/ui/html/malden_msh.txt`
- Regenerate: `tools/map_model_paths.txt`
- Test: `tools/test_bake_map_meshes.py` (existing, unmodified)

**Interfaces:**
- Consumes: nothing.
- Produces: the three text assets every later task reads. Their formats are unchanged — `hf` is `"# size cellMeters minH maxH"` then `size` rows north-first; `bld` is `"# count gen=<hash>"` then `x,y,dir,sx,sy,sz,kind,alt,mid` per row; `msh` is the mesh library keyed by `mid`.

- [ ] **Step 1: Record the red state — the shipped bake predates the designer merge**

```bash
cd /home/timb/Armapunk2035
git log -1 --format='%h %ad %s' --date=short -- mission/Armapunk2035.Malden/ui/html/malden_bld.txt
git log -1 --format='%h %ad %s' --date=short -- mission/Armapunk2035.Malden/mission.sqm
head -1 mission/Armapunk2035.Malden/ui/html/malden_bld.txt
```

Expected: the `malden_bld.txt` commit is **older** than `8fd1aec4` (2026-09-07, the MaldenFinal merge), and the header reads `# 17346 gen=b2f1a7bd28c9bb5b`. That gap is the defect. Write the count and hash down — step 8 compares against them.

- [ ] **Step 2: Confirm the dev server is running the post-merge island**

The bake reads the world, so the world has to be the right one. `map_objects` is the only source of map data and `APS_fnc_mapLoad` spawns it at boot.

```bash
grep -a "\[AP-MAP\] boot" /home/timb/arma3server_dev/loonydev.log | tail -2
```

Expected: a `rows in N pages, rev R` line **timestamped after 2026-09-07 14:28** (the merge). If the newest line predates the merge, stop — reload the dev server first (`deploy/reload-armapunk2035.sh`) and re-check. Baking a stale island produces a file that looks perfectly valid and is wrong, which is the single worst outcome available in this task.

Second, independent confirmation that the moved tower is where the merge put it (7130, 7909 — it was at 7216.602, 7777.412):

```bash
python3 tools/map_query.py near 7130 7909 40 | grep -i skyscraper
```

Expected: a `custom_p3ds\skyscraper30_r17.p3d` row at approximately x=7130 y=7909. **If `map_query.py` reports rows from a different database than the dev server is reading** (it resolves its DSN through `tools/apdb_dsn.py`, which is not guaranteed to be the server's own connection), treat only the `[AP-MAP] boot` line above as authoritative and note in the commit message that the spatial check was skipped.

- [ ] **Step 3: Add the temporary boot call, gated on map load**

`APS_fnc_mapBake` has no boot call in the tree on purpose (~5k log lines). Add one **temporarily**, and gate it on `AP_mapFarDone`, which `fn_mapLoad.sqf:64` sets true once the far rows are spawned. A `uiSleep` guess instead of the gate is how this bake records an empty skyline.

In `server/AP_server/init.sqf`, immediately after the existing map-load spawn (the line containing `APS_fnc_mapLoad`), add:

```sqf
// TEMPORARY -- 3D map re-bake, grid3d_plan.md Task 1. REMOVE after harvesting.
// Gated on AP_mapFarDone (fn_mapLoad.sqf:64) because the skyline is spawned from map_objects at
// runtime: a bake that fires first records terrain and no buildings, and looks like it worked.
[] spawn {
    waitUntil { uiSleep 1; !isNil "AP_mapFarDone" };
    uiSleep 5;
    diag_log "[MAPBAKE] boot call: map load complete, baking";
    [] call APS_fnc_mapBake;
};
```

- [ ] **Step 4: Reload the dev server and watch the bake run**

```bash
bash deploy/reload-armapunk2035.sh
```

Then watch for the bake, which starts after the map load and takes tens of seconds:

```bash
timeout 300 tail -F /home/timb/arma3server_dev/loonydev.log | grep -a --line-buffered "MAPBAKE\|AP-MAP boot"
```

Expected, in order: `[AP-MAP] boot: N rows ...`, then `[MAPBAKE] boot call: map load complete, baking`, then `[MAPBAKE] start`, then a `[MAPBAKE] done` line. If `[MAPBAKE] start` never appears, the gate never opened — do not proceed, and do not harvest a partial dump.

- [ ] **Step 5: Harvest the heightfield and buildings**

```bash
python3 tools/harvest_map_bake.py /home/timb/arma3server_dev/loonydev.log
```

Expected: it prints the two output sizes. It reads the LAST complete bake in the log and exits non-zero on an incomplete heightfield (`heightfield incomplete: N/200 rows`), which is the guard against harvesting a truncated dump.

- [ ] **Step 6: Re-bake the mesh library for any model paths new since the last bake**

```bash
python3 tools/bake_map_meshes.py
```

Expected: it rewrites `mission/Armapunk2035.Malden/ui/html/malden_msh.txt` from `tools/map_model_paths.txt` (which step 5 regenerated). New meshes are expected for the rebuilt La Trinite HQ; the moved `skyscraper30_r17.p3d` is the same model at a new position and needs no new mesh, only a new row.

- [ ] **Step 7: Run the artifact test**

Run: `python3 -m unittest tools/test_bake_map_meshes.py -v`
Expected: PASS. It validates the shipped `malden_msh.txt` against `malden_bld.txt` — every `mid` a building row references must exist in the library.

- [ ] **Step 8: Sanity-check the diff before trusting it**

```bash
head -1 mission/Armapunk2035.Malden/ui/html/malden_bld.txt
git diff --stat mission/Armapunk2035.Malden/ui/html/
```

Expected: the header count is within a few percent of the 17 346 recorded in step 1 (the merge soft-deleted 383 rows and inserted 468, so a swing of thousands means something went wrong, most likely a partial world), and all three assets show as changed. A building count near zero, or a `malden_bld.txt` that shrank by an order of magnitude, means the bake ran before the skyline existed — go back to step 3.

- [ ] **Step 9: Remove the boot call**

Delete the whole temporary block added in step 3 from `server/AP_server/init.sqf`. It does not ship.

```bash
grep -n "MAPBAKE" server/AP_server/init.sqf
```

Expected: no output.

- [ ] **Step 10: Run the full gate and commit**

```bash
bash tools/run_checks.sh
git add mission/Armapunk2035.Malden/ui/html/malden_hf.txt \
        mission/Armapunk2035.Malden/ui/html/malden_bld.txt \
        mission/Armapunk2035.Malden/ui/html/malden_msh.txt \
        tools/map_model_paths.txt
git commit -m "map3d: re-bake the static assets onto the post-MaldenFinal island

The heightfield, the building dump and the mesh library were baked before
8fd1aec4 merged the designer's 2026-09-07 delivery, so the 3D map drew the
skyline as it stood before the La Trinite HQ rebuild and before the skyscraper
moved to 7130,7909. Re-baked off the dev server with the boot call gated on
AP_mapFarDone -- ungated, the bake races map_objects and records terrain only."
```

- [ ] **Step 11: Confirm the map draws the new island**

Reload dev, join with the client, open MALDEN GRID, and look at La Trinite.

```bash
bash deploy/reload-armapunk2035.sh
python3 tools/gamectl.py focus arma3
python3 tools/gamectl.py shot /tmp/grid_after.png --half
```

Expected: the tower stands at the new position and the rebuilt HQ is present. This is the acceptance criterion for the task — the artifact tests prove the files are well-formed, only the screenshot proves they are right.

---

### Task 2: Rename the drug markers the map draws

**Files:**
- Modify: `mission/Armapunk2035.Malden/mission.sqm` (marker `text=` attributes only)
- Modify: `mission/Armapunk2035.Malden/initServer.sqf` (comments naming the old markers)
- Modify: `mission/Armapunk2035.Malden/briefing.sqf:60`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: nothing later tasks read. `fn_mapOpen.sqf` reads `allMapMarkers` live, so no code change is needed for the map to show the new text.

- [ ] **Step 1: Record the red state — the map layer still names dead drugs**

```bash
grep -o 'text="[^"]*"' mission/Armapunk2035.Malden/mission.sqm | sort -u | grep -iE 'cocaine|fentanyl|ephedra|phosphorus|hydrogen'
grep -n heroin mission/Armapunk2035.Malden/briefing.sqf
```

Expected output — these six marker texts plus the briefing line:

```
text="Cocaine Field"
text="Ephedra"
text="Fentanyl"
text="Fentanyl Pickup"
text="Hydrogen"
text="Phosphorus"
text="[  Ashfall ] ---- Produces Marijuana, Processed Cocaine"
```

None of those names exist in the item catalogue any more — `drugs.md` §1 renamed `cocainep`→`smash`, `fentanylu`→`boost`, `ephedrau`→`sparkdust`, `phos`→`redshift`, `hydro`→`toxicslurry`, and `fn_gather.sqf` / `fn_processAction.sqf` already emit the new keys.

- [ ] **Step 2: Snapshot the sqm's structure so the edit can be proved non-destructive**

```bash
python3 tools/sqm_read.py mission/Armapunk2035.Malden/mission.sqm > /tmp/sqm_before.txt 2>&1 || \
  python3 -c "
import re,sys
s=open('mission/Armapunk2035.Malden/mission.sqm',encoding='utf-8',errors='replace').read()
print('markers', len(re.findall(r'dataType=\"Marker\"', s)))
print('entities', len(re.findall(r'dataType=\"Object\"', s)))
print('texts', len(re.findall(r'text=\"', s)))
" > /tmp/sqm_before.txt
cat /tmp/sqm_before.txt
```

Expected: counts printed. Keep the file — step 5 diffs against it.

- [ ] **Step 3: Rename the marker texts**

This is a hand edit of the shipped sqm. It cannot be done in 3DEN: the shipped sqm is never saved from the editor, and `tools/map_codegen.py` syncs marker positions and new markers but **not renames**.

```bash
python3 - <<'EOF'
import pathlib
p = pathlib.Path("mission/Armapunk2035.Malden/mission.sqm")
s = p.read_text(encoding="utf-8")
RENAMES = [
    ('text="Cocaine Field"',    'text="Smash Field"'),
    ('text="Fentanyl Pickup"',  'text="Boost Pickup"'),   # before the bare "Fentanyl"
    ('text="Fentanyl"',         'text="Boost"'),
    ('text="Ephedra"',          'text="Sparkdust"'),
    ('text="Phosphorus"',       'text="Redshift"'),
    ('text="Hydrogen"',         'text="Toxic Slurry"'),
    ('text="[  Ashfall ] ---- Produces Marijuana, Processed Cocaine"',
     'text="[  Ashfall ] ---- Produces Marijuana, Processed Smash"'),
]
for old, new in RENAMES:
    n = s.count(old)
    if n == 0:
        raise SystemExit("NOT FOUND, refusing to write: " + old)
    print("%2d x %s -> %s" % (n, old, new))
    s = s.replace(old, new)
p.write_text(s, encoding="utf-8")
print("written")
EOF
```

Expected: seven lines each showing a non-zero count, then `written`. Order matters — `Fentanyl Pickup` is replaced before the bare `Fentanyl`, or the longer string would be left as `Boost Pickup`'s broken half.

- [ ] **Step 4: Fix the two prose stragglers**

`briefing.sqf:60` still lists `heroin` among the illegal materials, beside `smash` and `black lace` which the rename already corrected. There is no heroin key in the catalogue, so the word names nothing:

```bash
sed -i 's/such as weed, smash, heroin, black lace/such as weed, smash, boost, black lace/' \
  mission/Armapunk2035.Malden/briefing.sqf
grep -n "such as weed" mission/Armapunk2035.Malden/briefing.sqf
```

Expected: the line now reads `... such as weed, smash, boost, black lace, etc. is illegal.`

Then the marker-id comments in `initServer.sqf`, which still label the rings by their old drug names:

```bash
sed -i 's/"Cocaine Field"/"Smash Field"/; s/"Fentanyl"          + 100 m ring/"Boost"             + 100 m ring/' \
  mission/Armapunk2035.Malden/initServer.sqf
grep -n "Smash Field\|Boost\"" mission/Armapunk2035.Malden/initServer.sqf | head
```

Expected: the comments name the new markers. These are comments only — the marker **ids** (`illegal_marker_2_0`, `fentanyl_1`) are data keys read by `fn_gather.sqf` and are NOT renamed here. Renaming an id is a migration, not a label fix, and would silently break every gather zone.

- [ ] **Step 5: Prove the sqm is structurally untouched**

```bash
python3 -c "
import re
s=open('mission/Armapunk2035.Malden/mission.sqm',encoding='utf-8',errors='replace').read()
print('markers', len(re.findall(r'dataType=\"Marker\"', s)))
print('entities', len(re.findall(r'dataType=\"Object\"', s)))
print('texts', len(re.findall(r'text=\"', s)))
" > /tmp/sqm_after.txt
diff /tmp/sqm_before.txt /tmp/sqm_after.txt && echo "STRUCTURE IDENTICAL"
git diff --stat mission/Armapunk2035.Malden/mission.sqm
```

Expected: `STRUCTURE IDENTICAL`, and a diff touching only the seven text lines. Any change in the counts means the edit did more than rename text — revert and start again.

- [ ] **Step 6: Gate and commit**

```bash
bash tools/run_checks.sh
git add mission/Armapunk2035.Malden/mission.sqm mission/Armapunk2035.Malden/initServer.sqf \
        mission/Armapunk2035.Malden/briefing.sqf
git commit -m "map: the map layer still named cocaine, fentanyl and their precursors

drugs.md's rename landed in the catalogue and the processors but not in the
markers, so both maps labelled fields after items that no longer exist. Text
only -- marker ids stay, because fn_gather reads them as keys. The law text in
the briefing loses its last heroin, a drug this fork never had a key for."
```

- [ ] **Step 7: Confirm in game**

Reload dev, join, open the 2D map and MALDEN GRID.

```bash
bash deploy/reload-armapunk2035.sh
python3 tools/gamectl.py focus arma3
python3 tools/gamectl.py key m
python3 tools/gamectl.py shot /tmp/markers_after.png --half
```

Expected: the illegal fields read SMASH FIELD / BOOST / SPARKDUST / REDSHIFT / TOXIC SLURRY. `fn_mapOpen` builds its static payload from `allMapMarkers`, so the 3D map picks the new text up with no code change.

---

### Task 3: Extract the renderer into `ui/html/grid3d.js`

**Files:**
- Create: `mission/Armapunk2035.Malden/ui/html/grid3d.js`
- Modify: `mission/Armapunk2035.Malden/ui/html/map.html`
- Modify: `tools/html_js_check.py` (so the new `.js` file is parse-checked too)

**Interfaces:**
- Consumes: `malden_hf.txt`, `malden_bld.txt`, `malden_msh.txt` from Task 1.
- Produces — the module contract every later task codes against. `grid3d.js` defines exactly one global:

```
window.GRID3D.create(gl) -> R

R.loadHF(txt)                    parse a heightfield; sets R.hf {n, cell, minH, maxH, d}
R.hAt(x, y) -> metres            bilinear height at world metres; 0 outside the field
R.buildTerrain()                 terrain VBO/IBO from R.hf
R.buildWater()                   sea plane
R.loadMeshLib(txt)               parse malden_msh.txt into R.meshes {mid: {V,T,L}}
R.loadBuildings(txt)             parse malden_bld.txt; buckets rows into 640 m sectors
R.tiles.want(c, r, res, prio)    queue one satellite tile
R.tiles.pump()                   run the fetch queue (max 3 in flight)
R.tiles.atlasTex(res) -> texture the atlas for that resolution
R.drawTerrain(VP)                one draw call
R.drawWater(VP)
R.drawBuildings(VP, cx, cy, radius)   sectors whose centre is within radius of (cx,cy)
R.dispose()                      delete every GL object this instance owns
```

`create` takes the page's GL context — it never calls `getContext` itself, because the two pages own different canvases with different attributes.

- [ ] **Step 1: Record the red state — one renderer, one consumer, 1900 lines**

```bash
wc -l mission/Armapunk2035.Malden/ui/html/map.html
ls mission/Armapunk2035.Malden/ui/html/grid3d.js 2>&1
grep -c "GRID3D" mission/Armapunk2035.Malden/ui/html/*.html
```

Expected: 1910 lines, `No such file or directory`, and zero `GRID3D` references. The minimap cannot reuse any of this today.

- [ ] **Step 2: Create the module with the shared code moved verbatim**

Create `mission/Armapunk2035.Malden/ui/html/grid3d.js` with this wrapper, then move the listed functions into it **unchanged** from `map.html`, rebinding their `gl` references to the instance's context:

```js
/* GRID3D -- the shared terrain/building/satellite renderer behind MALDEN GRID
   (ui/html/map.html) and the HUD minimap (ui/html/hud.html).

   Loaded by A3API.RequestFile + eval, never <script src>: these pages have no
   resolvable base URL and a src quietly resolves to nothing. Idempotent -- a
   second eval replaces the global with an identical one and breaks nothing.

   It owns EVERYTHING that is the same on both screens: the heightfield, the
   terrain mesh, the sea, the satellite atlas and its fetch pump, the mesh
   library and the building batcher. It owns NOTHING about how a screen looks:
   no camera, no input, no blips, no chrome. create() takes the page's own GL
   context because the two canvases are created with different attributes. */
(function () {
  "use strict";
  function create(gl) {
    var R = { gl: gl, hf: null, meshes: {}, sectors: {}, _gl: [] };
    /* ... moved functions become methods on R, in this order ... */
    return R;
  }
  window.GRID3D = { create: create, VERSION: 1 };
})();
```

Move these, by name, from `map.html` (line numbers are pre-edit, for locating them):

| function | map.html line |
|---|---|
| `mPersp`, `mLook`, `mMul` | 266-279 |
| `sh`, `prog` | 286-352 |
| `parseHF`, `hAt` | 353-376 |
| `buildTerrain`, `buildWater` | 377-413 |
| `glBuf`, `glIbuf` | 414-415 |
| `initAtlas`, `initHero`, `heroSeed`, `heroUpload`, `updateHero` | 730-813 |
| `pad3`, `tilePath`, `wantTile`, `pumpTiles`, `blitTile` | 814-899 |
| `parseMeshLib`, `bucketize`, `parseBuildings` | 900-968 |
| `boxCounterpart`, `buildBoxSectors`, `buildMeshSectors`, `buildMeshChunks`, `evictMeshSectors` | 969-1130 |

Do NOT move — these are MALDEN GRID's own screen and stay in `map.html`: `buildHeli`, `buildShip`, `meshBox`, `meshDome`, `bakeMesh`, `cartelCol`, `buildCartelRing`, `buildLandmarks`, `drawShipHolo`, `altFor`, `heliUnits`, `drawHolos`, `homeOnSelf`, `camClamp`, `camMat`, `mPerPx`, `rayAt`, `groundHit`, `dirty`, `frame`, `stepAnims`, `animTo`, `sunFromHour`, and every `AP.on` handler.

Every moved function keeps its body byte-for-byte apart from one mechanical change: a bare `gl` becomes `R.gl`. Do not "improve" anything while moving it — a behaviour change hidden inside a 900-line move is undiagnosable.

- [ ] **Step 3: Load the module from `map.html`**

In `map.html`, before the renderer's first use, replace the moved block with the loader. It sits after the mandatory head block and before the page's own `buildLandmarks()` line:

```js
/* The renderer lives in ui/html/grid3d.js so the HUD minimap can use the same
   one. RequestFile + eval, the same path webui.js takes -- a <script src> has
   no base URL to resolve against here. A page that reaches its first draw with
   no GRID3D says so on its own surface, because the console is unreachable in
   game (Esc closes the dialog). */
var R = null;
function loadRenderer() {
  if (typeof A3API === "undefined" || !A3API.RequestFile) {
    window.__apBootErr = "no A3API -- grid3d.js cannot load"; return Promise.reject();
  }
  return A3API.RequestFile("ui\\html\\grid3d.js").then(function (src) {
    try { (0, eval)(src); } catch (e) { window.__apBootErr = "grid3d eval: " + e; throw e; }
    if (!window.GRID3D) { window.__apBootErr = "grid3d.js loaded but defined no GRID3D"; throw new Error("no GRID3D"); }
    R = window.GRID3D.create(gl);
    return R;
  });
}
```

Every former call site changes from `buildTerrain()` to `R.buildTerrain()`, `hAt(x,y)` to `R.hAt(x,y)`, and so on, and the boot sequence at the bottom of the page now waits on `loadRenderer()` before its first build.

- [ ] **Step 4: Extend the JS parse gate to `.js` files**

`tools/html_js_check.py` walks the html directory but only reads `.html`, so a syntax error in the new module would ship silently. In its file loop, replace:

```python
            if not fn.endswith(".html"):
                continue
            p = os.path.join(root, fn)
            js = "\n".join(re.findall(r"<script>(.*?)</script>",
                                      open(p, encoding="utf-8", errors="replace").read(), re.S))
```

with:

```python
            if not fn.endswith((".html", ".js")):
                continue
            p = os.path.join(root, fn)
            raw = open(p, encoding="utf-8", errors="replace").read()
            # A .js asset IS the script; an .html page carries its script in tags.
            js = raw if fn.endswith(".js") else "\n".join(
                re.findall(r"<script>(.*?)</script>", raw, re.S))
```

Second, in the same file, make a zero-file run fail. `main()` currently prints
`all ui/html scripts parse` and returns 0 even when it checked nothing — which is
what an empty walk looks like, and it is indistinguishable from a real pass. Before
the final `print`, add:

```python
    if checked == 0:
        print("FAIL: html_js_check found no files to check -- wrong path?")
        return 1
```

incrementing a `checked` counter beside each `node --check` call. This was not a
theoretical concern while writing this plan: a patched copy of this script run from
a scratch directory reported `all ui/html scripts parse` on a file containing
`function bad( {`, because its `__file__`-derived `HTML` path did not exist.

- [ ] **Step 5: Run the parse gate**

Run: `python3 tools/html_js_check.py`
Expected: PASS, and the output now lists `grid3d.js` among the files checked. If node is absent it prints `node not present -- skipped`, which is NOT a pass — install node or run this on the box before continuing.

- [ ] **Step 6: Prove the map is unchanged on screen**

This is the whole acceptance test for the task: an extraction that changes the picture is a bug, not a refactor.

```bash
bash deploy/reload-armapunk2035.sh
python3 tools/gamectl.py focus arma3
# open MALDEN GRID from the phone, then:
python3 tools/gamectl.py shot /tmp/grid_extracted.png --half
```

Expected: `/tmp/grid_extracted.png` matches `/tmp/grid_after.png` from Task 1 step 11 — same terrain, same buildings, same tiles, same holograms. Compare them side by side; a blank canvas means the eval failed, and `window.__apBootErr` carries the reason.

- [ ] **Step 7: Commit**

```bash
bash tools/run_checks.sh
git add mission/Armapunk2035.Malden/ui/html/grid3d.js \
        mission/Armapunk2035.Malden/ui/html/map.html tools/html_js_check.py
git commit -m "map3d: lift the renderer into ui/html/grid3d.js

The HUD minimap is about to draw the same island, and a second copy of a
WebGL renderer means every future fix lands twice or not at all. Terrain,
sea, satellite atlas, mesh library and the building batcher move out
verbatim; camera, holograms, blips and chrome stay with the screen that
owns them. html_js_check now parses .js assets too, or a syntax error in
the module would only surface as a dead map."
```

---

### Task 4: The minimap draws in 3D

**Files:**
- Modify: `mission/Armapunk2035.Malden/ui/html/hud.html`

**Interfaces:**
- Consumes: `window.GRID3D.create(gl)` and the `R.*` contract from Task 3; the existing `hud` / `hudmap` push channels from `fn_hudWebPush.sqf` (`{dir, pos, zoom, marks}` plus `tiles` carrying `base`, `ext`, `grid`, `tileMeters`, `worldSize`, `res`, `hf`).
- Produces: nothing later tasks read.

- [ ] **Step 1: Record the red state — the minimap is flat**

```bash
grep -n "getContext('webgl')\|getContext(\"webgl\")" mission/Armapunk2035.Malden/ui/html/hud.html
grep -n "GRID3D" mission/Armapunk2035.Malden/ui/html/hud.html
```

Expected: no output from either. The panel is rotated `<img>` tiles and DOM blips.

- [ ] **Step 2: Add the GL canvas under the existing blip layer**

In `hud.html`'s `#map .in`, add the canvas as the FIRST child, before `#mrot`, so every existing blip keeps drawing over it:

```html
<div id="map"><div class="in"><canvas id="mgl" width="208" height="208"></canvas><div id="mrot"><div id="mtiles"></div><canvas id="mwater" width="320" height="320"></canvas><div id="mmarks"></div></div><span id="mme">▲</span><div id="mscan"></div></div></div>
```

and the style, beside the existing `#mtiles` rule:

```css
/* The 3D panel. 208px = 13rem at the 16px root the panel is designed around;
   devicePixelRatio is 1 on this host so there is no backing-store scale to
   apply. Hidden until the renderer is up, so a failed load leaves the 2D
   panel visible rather than a black square. */
#mgl{position:absolute;inset:0;width:100%;height:100%;display:none}
#mgl.on{display:block}
#map.is3d #mrot,#map.is3d #mscan{display:none}
```

- [ ] **Step 2b: Two consumers, one tile cache — decide this BEFORE writing the camera**

The Task 3 review surfaced a cost the original plan missed, and it lands squarely
on this task. `GRID3D.create(gl)` gives every instance its OWN satellite atlases —
A128 at 1664², A256 at 3328², and the hero window at 3072², plus their backing 2D
canvases. That is roughly 70 MB of GL texture and 90 MB of canvas **per instance**,
and each instance keeps its own `tilesHave` / `tilesPend`, so a minimap open beside
the full-screen map re-fetches and re-decodes every tile the map already has.

`R.initAtlases()` (`grid3d.js:611`) is all-or-nothing: it builds A128, A256 and the
hero window together. The minimap can never use the hero window — `HERO_MPP = 6`
(`grid3d.js:225`) means it only engages once a pixel is a few metres, and the minimap
sits far below that — so as written it pays ~30 MB for a texture it will never sample.

Resolve it one of two ways, and say which in the commit:

1. **Give `create` an options object** — `create(gl, {hero: false, atlas: [128]})` —
   so the minimap builds only what it samples. Smallest change, no shared state, and
   the map keeps today's behaviour by passing nothing.
2. **Share the tile cache across instances** — one module-level atlas keyed by
   resolution, reference-counted. Cheaper still when both screens are open, but it
   introduces the first piece of cross-instance state in a module that currently has
   none, and the Task 3 review specifically confirmed that absence.

Option 1 is recommended: it solves the minimap's own waste, it cannot regress the map,
and it leaves the door open to 2 later. Whichever is chosen, the HUD must not build the
hero window.

- [ ] **Step 2c: The lighting model must not be copied**

`sunFromHour` and the `nightAmb` / `amb` / `fogK` derivation stayed in `map.html` per
Task 3's do-not-move list, but every draw pass in the module now takes `(sun, amb, fogK)`
as arguments. So the HUD cannot draw without that derivation, and the obvious move —
pasting it into `hud.html` — creates a second copy of a rule, which is the exact thing
this refactor exists to prevent.

Move `sunFromHour` and the ambient/fog derivation into `grid3d.js` as
`R.lighting(hour, overcast) -> {sun, amb, fogK}`, and have `map.html` call it instead
of its local copy. That is a Task 3-shaped change landing in Task 4 because Task 3's
move list did not anticipate it; do it as its own commit, and re-run the harness — the
map's rendered output must stay byte-identical, since the same arithmetic is producing
the same three values from the same inputs.

- [ ] **Step 3: Boot the renderer and hold the chase camera**

Add to `hud.html`'s script, after the `S` state object:

```js
/* THE 3D MINIMAP. Same renderer as MALDEN GRID (ui/html/grid3d.js), a much
   smaller camera. Chase: behind and above the player, yawing with them.
   The budget below is the whole reason this is safe to leave running: the HUD
   webview NEVER closes, so an uncapped rAF here is a cost paid for the entire
   session on a software rasterizer. */
var M3 = { R:null, gl:null, ready:false, on:true, raf:0, last:0, dirty:false,
           FPS:12, RADIUS:500, TILERES:128, PITCH:52*Math.PI/180, BACK:1.55 };
function m3Boot(){
  if (M3.R || typeof A3API==='undefined' || !A3API.RequestFile) return;
  var cv=$('mgl');
  M3.gl=cv.getContext('webgl',{antialias:false,alpha:false,depth:true,preserveDrawingBuffer:false});
  if(!M3.gl){window.__apBootErr='minimap: no webgl';return;}
  A3API.RequestFile('ui\\html\\grid3d.js').then(function(src){
    try{(0,eval)(src);}catch(e){window.__apBootErr='minimap grid3d eval: '+e;return;}
    if(!window.GRID3D){window.__apBootErr='minimap: no GRID3D after eval';return;}
    M3.R=window.GRID3D.create(M3.gl);
    return Promise.all([A3API.RequestFile('ui\\html\\malden_hf.txt'),
                        A3API.RequestFile('ui\\html\\malden_bld.txt'),
                        A3API.RequestFile('ui\\html\\malden_msh.txt')]);
  }).then(function(a){
    if(!a)return;
    M3.R.loadHF(a[0]); M3.R.buildTerrain(); M3.R.buildWater();
    M3.R.loadMeshLib(a[2]); M3.R.loadBuildings(a[1]);
    M3.ready=true; $('mgl').className='on'; $('map').className='is3d';
    m3Dirty();
  }).catch(function(e){window.__apBootErr='minimap assets: '+e;});
}
/* A push landed. Draw, and keep drawing while pushes keep landing -- then stop.
   idle = still is the house rule; a stationary player costs zero frames. */
function m3Dirty(){ M3.dirty=true; if(!M3.raf) M3.raf=requestAnimationFrame(m3Frame); }
function m3Frame(now){
  M3.raf=0;
  if(!M3.ready||!M3.on) return;
  if(now-M3.last < 1000/M3.FPS){ M3.raf=requestAnimationFrame(m3Frame); return; }
  M3.last=now; m3Draw();
  if(M3.dirty){ M3.dirty=false; M3.raf=requestAnimationFrame(m3Frame); }
}
function m3Draw(){
  var Mp=S.map, gl=M3.gl, R=M3.R;
  var px=Mp.pos[0], py=Mp.pos[1], yaw=(Mp.dir||0)*Math.PI/180;
  var d=(Mp.zoom||M3.RADIUS)*M3.BACK;
  var ex=px-Math.sin(yaw)*d*Math.cos(M3.PITCH), ey=py-Math.cos(yaw)*d*Math.cos(M3.PITCH);
  var ez=R.hAt(px,py)+d*Math.sin(M3.PITCH);
  gl.viewport(0,0,gl.drawingBufferWidth,gl.drawingBufferHeight);
  gl.clearColor(0.027,0.051,0.066,1); gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);
  var VP=R.chaseVP(ex,ez,ey, px,R.hAt(px,py),py, 1.0);
  R.drawTerrain(VP); R.drawWater(VP);
  R.drawBuildings(VP, px, py, M3.RADIUS);
}
```

`R.chaseVP(ex, ey, ez, cx, cy, cz, asp)` is the one addition `grid3d.js` needs beyond Task 3's contract: `mMul` of `mPersp` and `mLook`, which both already live in the module. Add it there, not here.

- [ ] **Step 4: Feed it from the existing push handlers**

The panel already has two channels. Extend both — `hud` for the full payload, `hudmap` for the 12 Hz fast lane — so the 3D camera moves on exactly the data the 2D one does:

```js
  AP.on('hud',function(d){if(!d)return;
    ['hp','h2o','food','wanted'].forEach(function(k){if(typeof d[k]==='number')S[k]=d[k]});
    S.paused=!!d.paused;S.regen=!!d.regen;
    if(d.map)S.map=d.map;render();m3Dirty();});
  AP.on('hudmap',function(d){if(!d)return;
    if(d.pos)S.map.pos=d.pos;
    if(typeof d.dir==='number')S.map.dir=d.dir;
    renderMap();m3Dirty();});
```

and call `m3Boot()` once, beside the page's existing boot line.

No easing, anywhere. PR15 removed the transitions from this panel for a measured reason: a 0.2 s ease against an 83 ms push interval leaves the layer permanently ~2.4 pushes behind the player, which IS the "not 1 to 1" complaint. The chase camera inherits that rule.

- [ ] **Step 5: Parse-check**

Run: `python3 tools/html_js_check.py`
Expected: PASS.

- [ ] **Step 6: Watch it, walking and driving**

```bash
bash deploy/reload-armapunk2035.sh
python3 tools/gamectl.py focus arma3
python3 tools/gamectl.py shot /tmp/mini_walk.png --half
```

Expected: the top-left panel shows tilted terrain with real buildings, oriented so the player's heading is up, blips still drawn over it. Then drive: the world should track the vehicle 1:1 with no visible lag. If the panel is black but the page is alive, read `window.__apBootErr` — every failure path above writes it, because the in-game console is unreachable.

- [ ] **Step 7: Measure the cost**

With the 3D panel up, note the in-game FPS; then set `M3.on=false` through the deck console and note it again. Expected: a difference small enough to leave on. If it is not, that is what Task 5's toggle exists for — record the number in the commit message either way, so the decision rests on a measurement instead of an impression.

- [ ] **Step 8: Commit**

```bash
bash tools/run_checks.sh
git add mission/Armapunk2035.Malden/ui/html/hud.html
git commit -m "hud: the minimap draws the real island in 3D

Same renderer as MALDEN GRID, chase camera behind the player, fed by the
channels the 2D panel already used. Budgeted deliberately because this
webview never closes: 12 fps to match the push rate, buildings culled to
the zoom radius, the 128 mip, and rAF stops entirely when the player does.
No easing -- PR15 removed it here for a measured reason and a camera is
not an exception."
```

---

### Task 5: A settings toggle back to the 2D minimap

**Files:**
- Modify: `mission/Armapunk2035.Malden/core/configuration.sqf` (append one default)
- Modify: `mission/Armapunk2035.Malden/core/pmenu/fn_settingsInit.sqf`
- Modify: `mission/Armapunk2035.Malden/core/web/fn_deckSettings.sqf`
- Modify: `mission/Armapunk2035.Malden/core/web/fn_hudWebPush.sqf`
- Modify: `mission/Armapunk2035.Malden/ui/html/hud.html`

**Interfaces:**
- Consumes: `M3.on` from Task 4.
- Produces: `AP_minimap3D` (Boolean, client global), settings slot **25**, and a `mode3d` field on the `hud` payload.

- [ ] **Step 1: Record the red state — slot 25 does not exist**

```bash
grep -o "AP_clientDefaultSettings=\[[^]]*\]" mission/Armapunk2035.Malden/core/configuration.sqf
grep -n "select 24" mission/Armapunk2035.Malden/core/pmenu/fn_settingsInit.sqf
```

Expected: an array of 25 values (indices 0-24, ending `,false]`), and `AP_streamerMode` reading slot 24 as the last one. There is no 3D-minimap preference.

- [ ] **Step 2: Append the default**

`configuration.sqf` is a huge minified data file — append, never reformat. Change the tail of `AP_clientDefaultSettings` from `,false,false,false,false]` to `,false,false,false,false,true]`. Default `true`: 3D is the shipped experience and the toggle is the escape hatch.

```bash
python3 - <<'EOF'
import pathlib, re
p = pathlib.Path("mission/Armapunk2035.Malden/core/configuration.sqf")
s = p.read_text(encoding="utf-8")
m = re.search(r"AP_clientDefaultSettings=\[([^\]]*)\]", s)
if not m: raise SystemExit("AP_clientDefaultSettings not found")
vals = m.group(1).split(",")
if len(vals) != 25: raise SystemExit("expected 25 defaults, found %d -- someone else added one" % len(vals))
s = s[:m.end()-1] + ",true" + s[m.end()-1:]
p.write_text(s, encoding="utf-8")
print("appended slot 25, now", len(vals)+1, "defaults")
EOF
```

Expected: `appended slot 25, now 26 defaults`. The length assertion is the guard — `fn_settingsInit` back-fills missing slots by index, so an off-by-one here silently reassigns somebody else's preference.

- [ ] **Step 3: Read it back at init**

In `fn_settingsInit.sqf`, after the `AP_streamerMode` line (slot 24), add:

```sqf
AP_minimap3D = (profileNamespace getVariable["PLBClientSettings", AP_clientDefaultSettings]) select 25;
```

The existing back-fill above it already appends defaults for slots an old profile is missing, so a returning player gets `true` without a migration.

- [ ] **Step 4: Draw the row in the deck's settings panel**

In `fn_deckSettings.sqf`, add to the `_hud` list, first row so it sits at the top of the HUD group:

```sqf
    ["minimap3D", 25, "3D minimap",            "toggle"],
```

- [ ] **Step 5: Push it to the page**

In `fn_hudWebPush.sqf`, add the flag to the `hud` payload beside the map hash:

```sqf
    ["mode3d", missionNamespace getVariable ["AP_minimap3D", true]],
```

- [ ] **Step 6: Honour it in the page**

In `hud.html`'s `hud` handler, before `render()`:

```js
    if (typeof d.mode3d === 'boolean' && d.mode3d !== M3.on) {
      M3.on = d.mode3d;
      /* Switching back to 2D restores PR15's panel exactly: the tile layer was
         never removed, only hidden, so there is nothing to rebuild. */
      $('mgl').className = (M3.on && M3.ready) ? 'on' : '';
      $('map').className = (M3.on && M3.ready) ? 'is3d' : '';
      if (M3.on) m3Dirty();
    }
```

- [ ] **Step 7: Gate and commit**

```bash
bash tools/run_checks.sh
python3 tools/html_js_check.py
git add mission/Armapunk2035.Malden/core/configuration.sqf \
        mission/Armapunk2035.Malden/core/pmenu/fn_settingsInit.sqf \
        mission/Armapunk2035.Malden/core/web/fn_deckSettings.sqf \
        mission/Armapunk2035.Malden/core/web/fn_hudWebPush.sqf \
        mission/Armapunk2035.Malden/ui/html/hud.html
git commit -m "hud: MINIMAP 3D is a setting, and 2D is one switch away

Slot 25, default on. The in-game web surface has cost this project frames
before, so the escape hatch ships with the feature rather than after the
first complaint. 2D restores the existing tile panel, which was hidden
rather than removed precisely so this could be free."
```

- [ ] **Step 8: Confirm both directions in game**

Reload, join, open the deck's settings, toggle `3D minimap` off and on.

Expected: off restores the rotated tile panel with blips exactly as before; on returns the 3D panel without a reload. Then relog and confirm the choice survived — it is stored in `profileNamespace`, which is what makes it per-account rather than per-session.

---

### Task 6: `warm.html` becomes the cache worker, and the landing bar tells the truth

**Files:**
- Modify: `mission/Armapunk2035.Malden/ui/html/warm.html`
- Modify: `mission/Armapunk2035.Malden/core/web/fn_hudWebInit.sqf` (bridge the warm layer, beside the existing HUD bridge)
- Modify: `mission/Armapunk2035.Malden/core/web/fn_landingData.sqf`
- Create: `mission/Armapunk2035.Malden/core/web/fn_warmProgress.sqf`
- Modify: `mission/Armapunk2035.Malden/Functions.h`

**Interfaces:**
- Consumes: the three map assets (Task 1), `GRID3D` (Task 3) only insofar as the same files are warmed.
- Produces: `AP_warmPct` (Number 0-100, client global) and `AP_fnc_warmProgress` (the channel handler the page calls). `fn_landingData.sqf` reads `AP_warmPct` for its `loadPct` field.

- [ ] **Step 1: Record the red state — the bar is a decoration**

```bash
grep -n "loadPct" mission/Armapunk2035.Malden/core/web/fn_landingData.sqf
grep -c "RequestFile" mission/Armapunk2035.Malden/ui/html/warm.html
```

Expected: `["loadPct",  100],` — hardcoded, with the file's own comment explaining it was always 100 — and `0` RequestFile calls in the warmer, which pulls satellite tiles only. The landing screen shows a full bar while nothing has been cached, and the map's own assets are fetched for the first time on the first M press.

- [ ] **Step 2: Turn the warmer into a reporting worker**

Rewrite `warm.html`'s script, keeping its comment header and its "draws nothing, idles forever" shape. The queue is priority-ordered and the bridge is optional — a warmer that cannot reach SQF must still warm:

```js
(function () {
  if (typeof A3API === "undefined" || !A3API.RequestTexture) return;
  var GRID = 13, inflight = 0, q = [], done = 0, total = 0, sent = -1;
  function pad3(n) { return ("00" + n).slice(-3); }

  /* 1. THE MAP'S OWN ASSETS. First because they are small, and because the HUD
        minimap now reads them at boot as well as the full-screen map. */
  ["ui\\html\\malden_hf.txt", "ui\\html\\malden_bld.txt", "ui\\html\\malden_msh.txt"]
    .forEach(function (p) { q.push(["file", p, 0]); });

  /* 2. THE SATELLITE LAYER, at the two mips both screens sample. */
  for (var r = 0; r < GRID; r++) for (var c = 0; c < GRID; c++) {
    q.push(["tex", "a3\\map_malden\\data\\layers\\s_" + pad3(c) + "_" + pad3(r) + "_lco.paa", 128]);
    q.push(["tex", "a3\\map_malden\\data\\layers\\s_" + pad3(c) + "_" + pad3(r) + "_lco.paa", 256]);
  }

  /* 3. THE ITEM ICONS. Every shop, inventory, loot, storage and fitting grid
        draws from this one directory, so one pass here removes the pop-in from
        five screens. Mission-relative: WEBUI.texture's root ladder is not
        available on this page, so the path is asked for as-is and a miss simply
        resolves with a stub -- which is why a miss must not stall the pump. */
  ICONS.forEach(function (n) { q.push(["tex", "icons\\" + n + ".paa", 128]); });
  total = q.length;

  function report() {
    var pct = total ? Math.round(done * 100 / total) : 100;
    if (pct === sent) return;                 // only on change: this is a message per push
    sent = pct;
    try { if (window.WEBUI && WEBUI.call) WEBUI.call("warmProgress", [pct, done, total]); } catch (e) {}
  }
  function fin() { done++; inflight--; report(); pump(); }
  function pump() {
    while (inflight < 3 && q.length) {
      var j = q.shift(); inflight++;
      var pr = (j[0] === "file") ? A3API.RequestFile(j[1]) : A3API.RequestTexture(j[1], j[2]);
      pr.then(fin, fin);                       // a miss counts as done: it must not stall the queue
    }
  }
  report(); pump();
})();
```

`ICONS` is a literal array of the 251 basenames in `mission/Armapunk2035.Malden/icons/`, generated once into the page:

```bash
python3 - <<'EOF'
import pathlib
d = pathlib.Path("mission/Armapunk2035.Malden/icons")
names = sorted(p.stem for p in d.glob("*.paa"))
print("var ICONS = %s;" % repr(names).replace("'", '"'))
print("// %d icons" % len(names))
EOF
```

Paste the emitted `var ICONS = [...]` line above the queue build. Regenerating it is a one-liner when icons are added; a stale list warms fewer icons and breaks nothing.

- [ ] **Step 3: Bridge the warm layer**

`AP_map_warm` is cut from `core/init.sqf:71` as an RscTitles webview, and `fn_hudWebInit.sqf` already proves a type=106 control carries a bridge in a title layer. Add the same two lines for the warm control, and register the channel:

```sqf
// The tile warmer reports its progress so the landing screen can show a real bar.
// Same pattern as the HUD layer above: init the bridge, register one handler.
if ([_warmCtrl] call webui_fnc_init) then {
    [_warmCtrl, "warmProgress", { _this call AP_fnc_warmProgress }] call webui_fnc_handle;
};
```

Create `core/web/fn_warmProgress.sqf`:

```sqf
/*
    AP_fnc_warmProgress -- the connect-time cache worker's progress, from ui/html/warm.html.

        [pct, done, total] call AP_fnc_warmProgress;

    Stores the figure and re-pushes the landing payload if that screen is still up. Nothing
    else reads it and nothing waits on it: PLAY is deliberately NOT gated on the cache, because
    every consumer already handles a cold asset and a login that waits on 2.9 MB of icons to
    save a first-open stutter is a bad trade.
*/
params [["_pct", 0, [0]], ["_done", 0, [0]], ["_total", 0, [0]]];
AP_warmPct = 0 max (round _pct) min 100;
if (!isNull (findDisplay 938100)) then {
    [] spawn { uiSleep 0; [] call AP_fnc_landingPush; };
};
[]
```

Register it in `Functions.h` beside the other `core\web` entries:

```cpp
class warmProgress {};
```

- [ ] **Step 4: Make `loadPct` real**

In `fn_landingData.sqf`, replace the hardcoded row:

```sqf
    ["loadPct",  100],
```

with:

```sqf
    // The connect-time cache's real figure (ui/html/warm.html -> AP_fnc_warmProgress). It starts
    // at 0 and climbs; it does NOT gate PLAY, which the page keys off its own >= 100 test only for
    // the greyed style. Defaulting to 100 when the warmer never reported keeps a client whose warm
    // layer failed from staring at an empty bar forever.
    ["loadPct",  missionNamespace getVariable ["AP_warmPct", 100]],
```

The page renders whatever arrives and needs no change.

- [ ] **Step 5: Parse-check and gate**

```bash
python3 tools/html_js_check.py
bash tools/run_checks.sh
```

Expected: both PASS. `warm.html`'s script is now large enough that a splice error is plausible, which is exactly the failure `html_js_check.py` exists to catch.

- [ ] **Step 6: Watch a real connect**

```bash
bash deploy/reload-armapunk2035.sh
timeout 300 tail -F /home/timb/arma3server_dev/loonydev.log | grep -a --line-buffered "LANDING\|HUDWEB"
```

Join with the client and watch the landing screen.

Expected: the bar climbs from a low number instead of sitting at 100, and PLAY is usable throughout — click it at 10% and confirm the world loads normally. Then open a shop and the map: both should appear without the first-open texture pop-in.

- [ ] **Step 7: Confirm the cache survives the landing closing**

Deploy immediately (bar well under 100), then wait ~30 s in the world and open MALDEN GRID.

Expected: the map opens warm. This is the reason the worker lives in `warm.html` rather than on the landing page — the landing dialog closes on DEPLOY and would take its in-flight fetches with it.

- [ ] **Step 8: Commit**

```bash
git add mission/Armapunk2035.Malden/ui/html/warm.html \
        mission/Armapunk2035.Malden/core/web/fn_hudWebInit.sqf \
        mission/Armapunk2035.Malden/core/web/fn_warmProgress.sqf \
        mission/Armapunk2035.Malden/core/web/fn_landingData.sqf \
        mission/Armapunk2035.Malden/Functions.h
git commit -m "connect: the tile warmer becomes a real cache, and the bar stops lying

warm.html already ran at every connect and idled forever; it now warms the
3D map's own assets and all 251 item icons as well as the satellite layer,
and reports progress, so the landing screen's loadPct is the truth instead
of a hardcoded 100. PLAY is still never gated -- every consumer handles a
cold asset, and the fetching lives in the title layer precisely so DEPLOY
closing the dialog does not abandon it."
```

---

## Verification of the whole feature

After Task 6, one pass that exercises everything together:

1. Reload dev, connect, and watch the landing bar climb from 0.
2. Deploy. Confirm the HUD minimap comes up in 3D, tilted, heading-up.
3. Walk, then drive. Confirm the minimap tracks 1:1 and stops drawing when you stand still.
4. Open MALDEN GRID. Confirm La Trinite shows the rebuilt HQ and the moved tower.
5. Read the illegal-field markers on both maps: SMASH FIELD, BOOST, SPARKDUST, REDSHIFT, TOXIC SLURRY.
6. Toggle `3D minimap` off in the deck settings; confirm the 2D panel returns intact. Toggle back on.
7. Relog; confirm the setting persisted and the second connect is visibly warmer than the first.

## Self-review notes

- **Spec coverage.** `grid3d.md` §2 → Task 1. §3 → Task 2. §4 → Task 3. §5 → Tasks 4 and 5. §6 → Task 6. §7's ship order is the task order. §8's out-of-scope items appear in no task.
- **Executed during review** (per the plan-code rule — plan code is a claim until something runs): the `AP_clientDefaultSettings` length assertion in Task 5 step 2, the marker-rename script's find-before-write in Task 2 step 3, and the `ICONS` generator in Task 6 step 2 were all run against the real tree before this plan was committed; each behaved as written. The `html_js_check.py` patch in Task 3 step 4 was applied and exercised in place (a scratch copy silently checks nothing, because the script derives its search path from `__file__`): a valid `.js` passes, and a file containing `function bad( {` fails with exit 1. That false pass is why step 4 now also adds the zero-files-checked guard.
- **Unverified, and marked as such.** The JavaScript in Tasks 3, 4 and 6 has been `node --check`ed for syntax only — no browser, and no CEF, has executed it. The `R.*` contract in Task 3 is a design, so the first implementation of Task 3 may need to adjust names; if it does, Task 4's calls move with it. `R.chaseVP` does not exist yet and is created in Task 4 step 3. The `_warmCtrl` handle in Task 6 step 3 is named for the control `fn_hudWebInit` will resolve; the exact lookup follows that file's existing pattern for the HUD control.
- **Lifecycle owners.** The 2D minimap is hidden, never removed — `renderMap()` keeps running and keeps owning `#mrot`, `#mtiles`, `#mwater` and `#mmarks`, so the 2D and 3D paths never both claim the same element. `warm.html` gains a bridge but keeps its existing lifetime (cut once at connect, never closed), so nothing else has to change ownership.
- **Paths.** Every file written lands under `mission/`, `server/`, or `tools/`; none are gitignored, and this plan and its spec sit at the repo root beside `mapdb.md`, `hudeditor.md` and the other design/plan pairs, which is this repo's convention rather than the skill's default `docs/superpowers/`.
