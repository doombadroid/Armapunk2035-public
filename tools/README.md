# Armapunk 2035 — Map Tooling, The Full Manual

Everything custom on this map — shops, NPCs, props, compounds, decoration — is **data, not
mission.sqm placement**. It lives in one array (`allLocalMapEntities`) inside
`mission/Armapunk2035.Malden/core/config/fn_mapData.sqf` (~15,700 entries) and is spawned **locally on
every machine** at load (`AP_fnc_createVehicleLocal`): zero network traffic, zero JIP cost, zero
server simulation. The trade-off is that none of it appears in the 3DEN editor — you can't drag
what isn't placed.

This folder is the bridge: a **full-map round-trip** that turns the array into editable Eden
entities and converts your edits back to script, with the fidelity and safety problems solved
(tilt, NPC group caps, outfits, deletions, stale caches, accidental map wipes).

```
fn_mapData.sqf ──extract──▶ editor mission ──import──▶ 3DEN entities
                                                        │  (edit anything)
fn_mapData.sqf ◀──apply──── clipboard export ◀──export──┘
```

---

## 1. The entry format (what one map object IS)

```sqf
["ClassName", [x, y, zATL], [[dirX,dirY,dirZ], [upX,upY,upZ]], "init code", isServer, LOADOUT]
```

| # | Field | Meaning |
|---|---|---|
| 0 | class | `CfgVehicles` classname |
| 1 | position | **ATL** (height above terrain; the engine computes it, never hand-math it) |
| 2 | orientation | `vectorDir` + `vectorUp` — full 3D orientation, tilt/bank included |
| 3 | init | SQF run on the spawned object with `_this` = the object. **This is live shop/NPC wiring** (`[_this,'STAND_U1','gun'] call NPC_fnc_shops;`). Use `_this`, never `this`. |
| 4 | isServer | `true` = spawned by the server (initServer), `false` = spawned per client |
| 5 | loadout *(optional)* | `getUnitLoadout` array for NPCs — a custom outfit/gear set applied at spawn. Absent = class-default look. |

Spawn behavior (`core/functions/fn_createVehicleLocal.sqf`): objects with no init and no loadout
become `createSimpleObject` (cheapest); anything with init or a loadout becomes a real local
object; NPCs get weapons stripped, then their stored loadout applied (randomization frozen), then
their init runs. All cargo is cleared — ammo-box classes are safe pure decoration.

---

## 2. The tools

| File | Runs where | Job |
|---|---|---|
| **`mapdata_all.py`** | shell (Python 3, stdlib only) | `baseline [--from <sqm>]`: stage the Eden ids a mission already has, so the export can spot NEW objects on its own. `delivery <old.sqm> <new.sqm>`: what changed between two designer deliveries. `extract`: stage the whole array + copy the SQF tools into the editor mission. `apply <file>`: rewrite `fn_mapData.sqf` from an export (or **append** an add-only one), then **auto-re-stage** so the editor snapshot never lags. |
| **`mapdata_watch.py`** | shell, left running | Tails the client RPT for the export block and applies it the moment it appears — no clipboard, no second command. `--dry-run` / `--once` / `--backfill`. |
| **`mapImportAll.sqf`** | 3DEN Debug Console | Spawn every entry as an editable entity: props always; **NPCs as real units wherever their side has group headroom** (loadout-editable), otherwise kept as pass-through data. Layer `MapDataAll`, names `md_<index>`. Records which indexes became units (in `profileNamespace`, survives editor restarts). |
| **`mapExportAll.sqf`** | 3DEN Debug Console | Rebuild the array: every `md_*` entity **gathered by name** (selection-proof) + **anything you placed, found automatically** by Eden id against the baseline (selection optional) + non-imported NPCs passed through from the staged data. With nothing imported it switches to **add-only** and emits just your new objects. Captures `getUnitLoadout` for any unit whose gear differs from class default. → clipboard + RPT. |

Support cast: `sqm_read.py` (shared rapified-`mission.sqm` reader: `parse` / `walk` / `entity_ids`),
`mapdata_to_eden.py` (the quote/bracket-aware array parser both Python tools use),
`eden_region.py` + `edenImport.sqf`/`edenExport.sqf` (the older **region** pipeline — see §9),
`compExport.sqf`/`compImport.sqf` (**composition zones** — see §9), `MAP_EDITING.md` (long-form
guide for those two).

---

## 3. One-time setup

**Linux (this box — already done):** both editor entries are symlinks into the repo:

```
~/.local/share/Steam/steamapps/compatdata/107410/pfx/drive_c/users/steamuser/Documents/Arma 3/missions/Armapunk2035.Malden
~/.local/share/Steam/steamapps/compatdata/107410/pfx/drive_c/users/steamuser/Documents/Arma 3/mpmissions/Armapunk2035.Malden
      → /home/timb/Armapunk2035/mission/Armapunk2035.Malden
```

Eden edits, the round-trip tools, and the dev-server pack all share one tree. The staged tool
files inside the mission folder are gitignored and never sync to live.

**Windows:** `mklink /D "%USERPROFILE%\Documents\Arma 3\missions\Armapunk2035.Malden" "C:\repo\mission\Armapunk2035.Malden"`
(admin prompt or Developer Mode). Or skip the symlink and point the stager with
`AP_PROTON_MISSION` / edit `EDITOR_DIRS` in `mapdata_all.py`.

---

## 4. The standard session, start to finish

### 4.1 Stage

```bash
# Linux, repo root
python3 tools/mapdata_all.py extract
```
```powershell
# Windows
$env:AP_PROTON_MISSION = "$env:USERPROFILE\Documents\Arma 3\missions\Armapunk2035.Malden"
py tools\mapdata_all.py extract
```

Writes `mapImportAll_data.sqf` (the full array as `AP_dataAll`) into the editor mission and
copies the two SQF tools next to it. `apply` re-runs this automatically, so manual `extract` is
only needed the very first time or after a hand-edit of `fn_mapData.sqf`.

### 4.2 Import

Open the mission in the 3DEN editor → Tools → **Debug Console** → paste, **LOCAL EXEC**:

```sqf
call compile preprocessFileLineNumbers "mapImportAll.sqf"
```

- ~7,000 entities appear in layer **`MapDataAll`**, named `md_0`… Expect the editor to chew for a
  minute; progress prints every 500.
- Finish line: `N entities (U NPCs as REAL units -- Edit Loadout works) | D NPCs kept as data
  (side at group cap) | K unknown-class skips`. **N + D must equal the staged count.**
- The import refuses to run twice (`md_0` already exists) — delete the old layer first.

**Want to edit civilian NPCs too?** The mission.sqm carries 288 civilian playable slots — exactly
Eden's 288-groups-per-side cap, so civ NPCs normally stay data. Free the side **for this session
only** (you never save the mission anyway — §6) by running this BEFORE the import:

```sqf
{ if (side _x isEqualTo civilian) then { delete3DENEntities [_x]; }; } forEach (all3DENEntities select 1);
```

All 219 civilian NPCs then import as editable units. WEST/EAST/GUER always have headroom.

### 4.3 Edit

- **Move / rotate** anything — full tilt is preserved both ways.
- **Add** objects/units anywhere. Give new NPCs an init in their attributes if they should run a
  shop (copy an existing one's init; `_this` not `this`).
- **Outfits / gear**: right-click a unit → **Edit Loadout** — the full arsenal editor. Anything
  differing from class default exports automatically. (Cop NPCs: the old June-16 uniform-strip in
  `npcs/fn_*.sqf` skips NPCs that carry a custom loadout, so your outfit sticks.)
- **Delete**: delete the `md_*` entity. See §5 for exactly what sticks.
- **Init fields are live shop logic** — don't clear one unless you mean to kill that shop.
- **Description fields carry `AP_SERVERSIDE`** (the isServer flag) — don't clear them.

### 4.4 Export

**Select nothing.** Imported entities are gathered by their `md_` name, and anything you placed is
recognised by Eden id against `mapBaseline_ids.sqf` (stage it once with `mapdata_all.py baseline`;
`extract` does it too). A selection is still honoured, as a fallback.

```sqf
call compile preprocessFileLineNumbers "mapExportAll.sqf"
```

Chat line: `N props + M NPCs (preserved) -> clipboard (...)`. Sanity: N + M = previous total ±
your adds/deletes.

### 4.5 Apply

```bash
# Linux (X11: xclip -selection clipboard -o > /tmp/mapdata_all_export.sqf)
wl-paste > /tmp/mapdata_all_export.sqf
python3 tools/mapdata_all.py apply /tmp/mapdata_all_export.sqf
```
```powershell
Get-Clipboard -Raw | Out-File -Encoding utf8 $env:TEMP\mapdata_all_export.sqf
py tools\mapdata_all.py apply $env:TEMP\mapdata_all_export.sqf
```

Or skip the clipboard entirely — leave `python3 tools/mapdata_watch.py` running and the export
lands in `fn_mapData.sqf` on its own, straight off the RPT.

`apply` reports `applied X entries (was Y)` (or `appended N new entries` for an add-only export),
writes `fn_mapData.sqf.bak`, and **re-stages the editor snapshot**. Repack/reload the dev server to see it in game; commit `fn_mapData.sqf` through
the normal PR flow.

### 4.6 Clean up the editor

Delete the `MapDataAll` layer (with entities). **Only save the mission after the layer is gone —
or don't save at all** (§6). If you freed the civ slots, do NOT save (exiting without saving
restores them — they were only deleted in the session).

---

## 4B. Just adding a few objects (the short path)

You do not need to import 15,700 entries to place a bollard.

```bash
python3 tools/mapdata_all.py baseline      # once; re-run after mission.sqm changes
python3 tools/mapdata_watch.py             # leave running (or use the clipboard as in 4.5)
```

Open the mission in 3DEN, **place your objects, select nothing**, and run the export line. With
nothing imported the export runs in **add-only mode**: it emits only what you placed, marks the text
`AP_MAPALL_MODE_APPEND`, and `apply` appends those rows instead of replacing the array. The >2%
wipe-guard does not apply (nothing was replaced); instead an add-only export carrying more than 2000
entries is refused, which is what a stale or missing baseline looks like.

How it knows: every entity a mission ships with carries an Eden id, and `get3DENEntityID` returns the
same number in the editor (it survives save/load). `mapBaseline_ids.sqf` is that id set. An entity
that is neither an `md_` import nor a baseline id can only be something you just placed.

---

## 4C. Map work coming from the designer (Windows, no Python, no console)

They run nothing. Their job: **place objects, save, send the `mission.sqm`.** Everything else is here.

```bash
python3 tools/mapdata_all.py delivery <their PREVIOUS .sqm> <their NEW .sqm>
```

ADDED / REMOVED / moved / retyped, by Eden id. **Read it before applying** — removals are the ones
that matter, because an add-only apply cannot see them; deciding to drop those rows is a separate,
deliberate act.

```bash
python3 tools/mapdata_all.py baseline --from <their PREVIOUS .sqm>
# open THEIR NEW file in 3DEN, run the export line (watcher running, or paste as in 4.5)
```

Eden ids are stable inside their mission too, so the ids their new file has and the old one doesn't
are exactly their additions — no position matching, no class+XY join. Opening their file in 3DEN is
only so the **engine** works out ATL heights: converting those offline from the sqm's `atlOffset` was
measured at 56% accurate over 7,555 objects (median 2 mm, p90 **14 m**, max 134 m), so don't.

If `delivery` reports **no shared Eden ids**, the files are not the same lineage (rebuilt mission, or
a different source). The id baseline cannot help — import the new file and export the whole array.

---

## 5. Deletion semantics (exactly what sticks)

| You delete… | Result |
|---|---|
| a prop (`md_*` object) | Gone. Its name is absent from the gather → the row drops out. |
| an NPC that imported as a **unit** | Gone — the import recorded its index (`profileNamespace`), so the export refuses to resurrect its data row. **Requires the session to have been imported with the current tools**; a legacy session prints `legacy session … deletions will NOT stick` at export. |
| an NPC still on the **data side** (capped civs) | Can't — it isn't in the editor. Free the civ slots (§4.2), re-import, then delete it as a unit. |
| something you added this session (not yet exported) | Just delete it / don't select it. |
| **many things** (more than 2% of the array, ~140 entries) | `apply` **aborts** as a wipe-guard. Re-run with `--allow-deletes` when the deletion is deliberate. |

---

## 6. The two rules that protect the repo

1. **NEVER save the mission while `MapDataAll` (or a `comp_*`) layer exists.** The editor folder is
   a symlink into the repo — saving bakes ~7,000 objects into `mission.sqm`. Export → delete layer
   → then save (or just never save; the round-trip needs no sqm save). Recovery if it happens:
   `git checkout mission/Armapunk2035.Malden/mission.sqm`. **This is not hypothetical:** an Eden
   autosave on 2026-07-26 took `mission.sqm` from 1.71 MB to 5.36 MB — 4,260 objects to 19,902 — and
   everything in the array then existed twice at runtime. `mapdata_all.py delivery <old> <new>` is
   the quickest way to see what a suspect .sqm gained.
2. **The Arma preprocessor caches script files per editor session.** If a tool `.sqf` is updated
   while the editor is open, `preprocessFileLineNumbers` can serve the stale version. **Restart the
   editor after tool updates** (or run the tool under a temporary new filename). Rule of thumb: if
   a tool behaves like its old self, it IS its old self.

---

## 7. Safety systems (what saves you when something goes wrong)

- **Wipe-guard**: `apply` aborts on a >2% net shrink without `--allow-deletes`.
- **Add-only cap**: an append-marked export over 2000 entries is refused (stale/missing baseline).
- **Watcher refusals are loud and harmless**: `mapdata_watch.py` prints `REFUSED: ...` and keeps
  running rather than writing; it also ignores a block it has already applied (hash), so re-reading
  the log cannot double-apply.
- **Backup**: every `apply` writes `fn_mapData.sqf.bak` first. The file is also in git.
- **Auto-restage**: `apply` immediately refreshes the editor snapshot — the "my new box didn't
  import" stale-data class of bug is structurally gone.
- **Resurrection-guard**: deleted unit-NPCs stay deleted (imported-index record).
- **Duplicate-guard**: moved/redressed NPCs can't emit twice (index-based passthrough dedup).
- **Ledger audit** (run after any apply that surprises you):
  counts must satisfy `old ± your_changes = new`, and a class-level diff of `.bak` vs current
  shows exactly what changed. Ask the assistant for the audit — it's a 10-line Python diff.
- **Exclusion list** (top of `mapExportAll.sqf`) drops Logic/Module/etc. classes even if selected.
  **Never put a real map class in it** — `Sign_Arrow*` are live DP/time-trial markers and were once
  silently eaten here (16 objects, restored from `.bak`).
- Unknown-class import skips are logged to RPT with positions and **drop from the round-trip** —
  resolve them before applying (they usually mean missing DLC/mods on the editing machine).

---

## 8. Troubleshooting

| Symptom | Cause → fix |
|---|---|
| `only 288 groups per side are supported!` | A side ran out of group headroom mid-import. Current import pre-counts and keeps overflow NPCs as data instead — if you see this, you're on a stale cached tool (§6 rule 2). |
| Import shows an old map state (missing recent additions) | Editor served the cached `mapImportAll_data.sqf`. Restart the editor. (`apply` auto-restages, so the file on disk is current.) |
| Export chat shows a tiny count / apply aborts at ~290 entries | The export ran without the `md_*` gather — stale cached tool. Restart the editor. |
| `legacy session … deletions will NOT stick` at export | Session was imported before the deletion-guard existed. Finish additive edits, apply, restart editor, re-import. |
| Edited NPC spawns naked/undressed in game | The cop-NPC uniform strip predates loadouts and is now conditional — if it recurs, the NPC init raced the loadout; report it. |
| `apply` says "no entries parsed" | Clipboard didn't hold the export (copied something since?). Re-run the export, re-save the file. |
| Deleted something in Eden but it's back next import | It was a data-side NPC (§5) or the export ran in a legacy session. |
| Wrong editor folder staged | Set `AP_PROTON_MISSION` explicitly. |
| Editor hangs a while on import | Normal at 7k entities — watch the every-500 progress lines. |

---

## 9. Sibling pipelines

- **Region pipeline** (`eden_region.py`, `edenImport.sqf`, `edenExport.sqf`) — pull a small radius
  of the array into Eden and merge it back. Predates the full-map pair; its importer is yaw-only
  (flattens tilt) and it is selection-sensitive. Still handy for tiny surgical edits; full docs in
  `MAP_EDITING.md`.
- **Composition zones** (`compExport.sqf`, `compImport.sqf`, `compositions/zones.sqf`,
  `AP_fnc_compZones`) — export any Eden build as a named zone streamed to players at the
  reference distances (small zones IN r+400 / OUT r+550; big zones IN r+1000 / OUT r+1250; 2s
  poll; per-object creation throttle; parked-vehicle unload guard). Zero network cost — every
  client spawns its own simple objects. Also the capture path for shed-relative builds (the
  helipad upgrade came from one of these exports). Docs in `MAP_EDITING.md`.

## 10. History footnotes (why the odd bits exist)

- **288**: Eden's hard cap on groups per side. Every placed unit = one group, and this mission's
  sqm ships 288 civilian playable slots — the civ side is born full. Hence the session-only
  slot-free snippet and per-side headroom accounting (285 with a 3-group margin).
- **`md_` names are load-bearing**: the index in `md_<index>` ties an editor entity back to its
  data row for the passthrough/dedup/deletion logic. Don't rename imported entities.
- **Sign_Arrow incident**: the reason §7 shouts about the exclusion list.
- **Deleted one-offs** (`edenProbe.sqf`, `gen_malden_loader.py`, `sqm_extract.py`,
  `eden_to_mapdata.py`, `eden_sqf_to_mapdata.py`): Malden-merge-era scaffolding and superseded
  converters, removed 2026-07-10. The git history keeps them if archaeology ever calls.
- **Sea-fortress/prison drift incident (2026-07-11)**: Eden re-grounds WATER-OVER and STACKED objects
  at import placement (setPosATL over sea measures from the SEABED; stacked walls physics-settle), and
  the old export re-read live transforms for every entity — so untouched props drifted a little more
  every round-trip until the sea fortress sat 40m off and the prison HBarriers floated. Fix (both tools):
  `mapImportAll` records each entity's actual post-placement transform (`AP_mapPlacedXf`,
  profileNamespace); `mapExportAll` emits the ORIGINAL staged transform verbatim unless the entity moved
  relative to that record (a real user move). Init/serverside/loadout are still read live, so attribute
  edits without moves keep working. The export's summary line shows the passthrough count — if it says
  0 on a big export, the session predates the record: delete the MapDataAll layer and re-import once to
  arm it. Deliberately MOVING an object that sits over water remains a re-derive (drift risk on that one
  object only) — nudge such pieces by editing the array row's numbers directly if millimetres matter.

---

### sqf_balance.py

Arma-aware bracket balance check. `python3 tools/sqf_balance.py <file>...`

SQF escapes a quote by DOUBLING it (`""` inside `".."`), a backslash means nothing, and comments only
count outside strings. A per-line net delta is useless -- `} else {` is net zero, and a mis-PAIRED
bracket (a `]` closing a `{`) balances perfectly by count. This walks a stack and reports the first
bracket that closes the wrong opener, with line and column. Run it on every .sqf you touch: a brace
fault in a client function throws no visible error, it silently deletes the player's whole scroll menu.

**It also looks INSIDE code-bearing strings.** Scroll-menu conditions are quoted strings compiled by
the engine at menu-build time, so a paren deleted inside one is the same silent scroll-menu-deletion
fault — and a tokenizer that treats a literal as opaque cannot see it. It happened: an agent deleted
one paren inside a `fn_setupActions.sqf` condition and this tool said `ok`. It now joins `+`-chained
literals, decides whether the result is *code* or *text*, and balances the code ones.

Text is never checked, because a checker that cries wolf gets removed: SQL fragments, `%1` format
templates, `<t size=...>` markup, `"["` values and prose with apostrophes are all legitimately
unbalanced in this tree and all stay quiet. A string is checked only if it holds one unambiguous SQF
token (`&&`, `getVariable`, `objNull`, a `AP_`/`AP_` global…) or two English-ambiguous ones, and
only if every operand of its `+` chain is a literal. Measured on the whole tree: 1337 files, 1770 code
strings parsed, **0 flagged**. Recall measured the other way round, by injecting the fault: 11 730
single-bracket mutants, **10 not caught** — all ten a bracket inside a *nested display literal*
(`"Oil Processing ($1,000)"`), where deleting it changes what a player reads, not whether the code
compiles. Against faults in compiled code the measured miss rate is zero. Limits are listed at the
bottom of the script.

`--no-strings` restores the old outer-syntax-only behaviour (byte-identical output). Tests:
`python3 tools/test_sqf_balance.py` — every NOFLAG case in it is a real unbalanced string from this
repo, so a new failure there means the checker has started crying wolf.
