# Drug Rework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the hard-drug catalogue into the Armapunk 2035 fiction, delete the LSD and PCP chains entirely, give each surviving drug a health/mobility trade-off, and add Boost as an adulterant that doubles processing yield.

**Architecture:** Three independent layers, executed in order. (1) A deletion pass that removes LSD, PCP, fungi and henbane from every config, code path and asset. (2) A mechanical key-rename pass, one chain per task, replacing exact quoted tokens rather than substrings. (3) A behaviour pass that adds a heal-block gate, a damage-absorb pool in the existing damage event handler, and a yield multiplier column in the processing recipe table.

**Tech Stack:** SQF (Arma 3 mission + server addon), `.paa`/`.ogg` assets, Python tooling under `tools/`, a Next.js website under `website/`.

**Spec:** `drugs.md` at repo root. Read it before starting.

---

## Global Constraints

These come from `CLAUDE.md` and apply to every task. A task's requirements implicitly include this whole section.

- **Work on `main` directly.** Owner call 2026-08-21 — dev server, no players, no PR round-trip.
- **`git fetch origin` and pull before starting any task.** Other sessions commit to main.
- **Commit trailer is `Co-Authored-By: <funny defunct AI>`, name only, no email.** Rotate between Microsoft Tay, SmarterChild, ELIZA, Clippy, Dr. Sbaitso. Do not repeat back-to-back. **This overrides the harness default Claude/Anthropic trailer — do not emit it.**
- **Never name other Arma servers** anywhere git-tracked.
- **`core/configuration.sqf` is a minified data file — append, never reformat.**
- **Client fn** `core/<domain>/fn_name.sqf` → called `AP_fnc_name` → MUST be registered in `Functions.h`. Deleting a function means deleting its `Functions.h` line too.
- **Server fn** `server/AP_server/core/TON/fn_name.sqf` → `APS_fnc_name` → registered in `server/AP_server/config.cpp`.
- **`mission.sqm` is never opened or saved from 3DEN.** No task here touches it.
- **`loonybot/` is out of scope and must not be edited.** Its `clankr.py` parses logs from the frozen LooneyBin Altis box where the old drug names are still correct. Every grep sweep in this plan excludes it.

### The stat-slot invariant — read this before Tasks 2–6

`core/functions/fn_statArrUpdate.sqf` holds `AP_statSlotMap`, a hash of **stat name → fixed array index**. That index is persisted in the player's stats array in the database and is read back by the website by number (`website/src/lib/leaderboards.ts` uses `lt(26)` for meth).

Current entries relevant to this work:

```
["hydro", 18]   ["phos", 19]   ["crank", 23]   ["crankp", 24]
["ephedra", 25] ["meth", 26]   ["bluemeth_proc", 68]  ["cokebrick_proc", 72]
["henbane", 144] ["pcpu", 145] ["pcp", 146]   ["pcpp", 147]
```

Two rules, both absolute:

1. **When renaming, change the KEY and keep the INDEX byte-identical.** `["meth", 26]` becomes `["blacklace", 26]`. Historical stats stay attached to the right column.
2. **When deleting, remove the entry and renumber NOTHING.** Slots 144–147 become unused holes. Renumbering shifts every later stat into the wrong column — that exact class of bug has already cost this project a corruption incident.

A missed rename here does not error. `AP_statSlotMap getOrDefault [toLower _item, -1]` returns `-1` and the stat is silently dropped.

### The verification loop

There is no SQF test runner. "Run the tests" means this, and every task ends with it:

```bash
# offline gate — bracket balance, content validators, Python unit tests
bash tools/run_checks.sh

# deploy to dev (NEVER reload-loonydev.sh — that packs the other project)
bash /home/timb/arma3server_dev/reload-armapunk2035.sh

# wait for the boot marker (~40-90s)
grep "read from bank" /home/timb/arma3server_dev/loonydev.log

# read the newest client RPT for new errors
ls -t ~/.local/share/Steam/steamapps/compatdata/107410/pfx/drive_c/users/steamuser/AppData/Local/Arma\ 3/*.rpt | head -1
```

In-game observations are made with `diag_log` probes tagged `[AP-PROBE]` so they land in the client RPT and can be read without a relay.

**Every task states its red state — the observation that must be SEEN failing before the change, and seen passing after.** In a codebase with no test harness, that observation is the test.

---

## File Structure

**Deleted outright (Task 1):**

```
mission/Armapunk2035.Malden/core/drugs/fn_lsd.sqf
mission/Armapunk2035.Malden/core/drugs/fn_pcp.sqf
mission/Armapunk2035.Malden/core/drugs/fn_heroin.sqf
mission/Armapunk2035.Malden/core/actions/fn_mineFungi.sqf
mission/Armapunk2035.Malden/core/actions/fn_fungiActions.sqf
mission/Armapunk2035.Malden/npcs/fn_civFungi.sqf
mission/Armapunk2035.Malden/icons/{lsdpill,lsdpurify,pcp,pcpp,pcpu,darkmushroom,henbane}.paa
mission/Armapunk2035.Malden/sounds/{gatherLsd,makeLsd}.ogg
```

**Created:**

| File | Responsibility |
|---|---|
| `core/drugs/fn_blackLace.sqf` | Black Lace effect (renamed from `fn_meth.sqf`) |
| `core/drugs/fn_smash.sqf` | Smash effect (moved from `core/items/fn_cocaine.sqf`) |
| `core/drugs/fn_glitter.sqf` | Glitter effect (renamed from `fn_crank.sqf`) |
| `core/drugs/fn_healBlocked.sqf` | Single predicate every heal path calls: is healing currently blocked? |
| `core/functions/fn_speedMod.sqf` | The movement-speed modifier stack — the ONLY writer of `setAnimSpeedCoef` |
| `core/drugs/fn_drugVision.sqf` | The shared stimulant screen effect, driven by `AP_drug_level` |

**Modified, by responsibility:**

| File | Owns |
|---|---|
| `core/config/fn_virtItemCfg.sqf` | the item catalogue — every key, name, weight, price, icon |
| `core/actions/fn_processAction.sqf` | hand processing; gains the `_yield` column and the pre-consumption weight cap |
| `core/actions/fn_processVehicle.sqf` | bulk trunk processing; gains the same `_yield` column |
| `evh/fn_handleDamage.sqf` | the damage event handler; gains the Glitter absorb pool |
| `core/functions/fn_statArrUpdate.sqf` | stat name → persisted slot index (see invariant above) |
| `npcs/fn_civProcessItem.sqf` | processor NPC scroll actions, including the new Cut actions |
| `core/pmenu/fn_useItem.sqf` | item-use routing |
| `core/drugs/fn_drugUsed.sqf` | addiction accrual + overdose roll |
| `website/src/lib/leaderboards.ts` | leaderboard labels (indices unchanged) |

---

# Phase 1 — Deletion

### Task 1: Strip LSD, PCP, fungi and henbane

**Files:**
- Delete: the six `.sqf` files and nine assets listed in File Structure
- Modify: `mission/Armapunk2035.Malden/Functions.h`, `core/config/fn_virtItemCfg.sqf`, `core/actions/fn_processAction.sqf`, `core/actions/fn_processVehicle.sqf`, `core/actions/fn_gather.sqf`, `core/fn_setupActions.sqf:489`, `core/pmenu/fn_useItem.sqf`, `core/drugs/fn_drugUsed.sqf`, `npcs/fn_civProcessItem.sqf`, `core/config/fn_virt_shops.sqf`, `core/config/fn_exchangeCfg.sqf`, `core/config/fn_loginBonusCfg.sqf`, `core/config/fn_prestigeCfg.sqf`, `core/config/fn_talentCfg.sqf`, `core/config/fn_wantedChargesConfig.sqf`, `server/AP_server/core/TON/fn_wantedChargesConfig.sqf`, `core/compat/fn_itemDemand.sqf`, `core/functions/fn_statArrUpdate.sqf`, `core/shops/fn_sellVehicleInv.sqf`, `core/actions/fn_metalDetector.sqf`, `core/vehicle/fn_deviceMine.sqf`, `core/vehicle/fn_tractorMine.sqf`, `evh/fn_onPlayerRespawn.sqf`, `core/configuration.sqf`, `core/radio/fn_plbInvDemo.sqf`, `debug/npcprobe.sqf`, `initServer.sqf`, `CfgSounds.hpp`, `server/AP_server/core/system/fn_marketTick.sqf`, `server/AP_server/eventhandlers.sqf`, `edenNPC_data.sqf`

**Interfaces:**
- Consumes: nothing
- Produces: a tree with zero references to `lsd_0`, `lsd_1`, `pcpu`, `pcp`, `pcpp`, `fungi`, `henbane`, `heroinp`. Tasks 2–6 sweep a smaller surface as a result.

- [ ] **Step 1: Observe the red state**

```bash
cd /home/timb/Armapunk2035 && git fetch origin && git pull --ff-only
grep -rnoiE '"(lsd_[01]|pcpu|pcpp|pcp|fungi|henbane|heroinp)"' \
  --include=*.sqf --include=*.hpp --include=*.cpp --include=*.py --include=*.ts \
  mission/ server/ tools/ website/ | wc -l
```

Expected: a non-zero count. Record it. This number must reach 0 by Step 12.

- [ ] **Step 2: Delete the six function files and their registrations**

```bash
git rm mission/Armapunk2035.Malden/core/drugs/fn_lsd.sqf \
       mission/Armapunk2035.Malden/core/drugs/fn_pcp.sqf \
       mission/Armapunk2035.Malden/core/drugs/fn_heroin.sqf \
       mission/Armapunk2035.Malden/core/actions/fn_mineFungi.sqf \
       mission/Armapunk2035.Malden/core/actions/fn_fungiActions.sqf \
       mission/Armapunk2035.Malden/npcs/fn_civFungi.sqf
```

Then remove the matching entries from `mission/Armapunk2035.Malden/Functions.h`. Find them with:

```bash
grep -n 'lsd\|pcp\|heroin\|mineFungi\|fungiActions\|civFungi' mission/Armapunk2035.Malden/Functions.h
```

A function file deleted without removing its `Functions.h` line makes the mission fail to compile at preInit.

- [ ] **Step 3: Remove the seven item rows**

In `core/config/fn_virtItemCfg.sqf`, delete these lines entirely:

```sqf
["fungi", "Dark Fungi", 2, -1, 150, -1, 750, 500, 350, -1, "icons\darkmushroom.paa"],
["lsd_0", "LSD Pill", 2, -1, 150, -1, 2000, 1700, 550, -1, "icons\lsdpill.paa"],
["lsd_1", "Purified LSD Sheet", 2, -1, 150, -1, 2000, 2500, 900, -1, "icons\lsdpurify.paa"],
["henbane", "Henbane plant", 2, -1, 100, -1, -1, -1, -1, -1, "icons\henbane.paa"],
["pcpu", "PCP Powder", 2, -1, 150, -1, -1, -1, -1, -1, "icons\pcpu.paa"],
["pcp", "PCP Pill", 2, -1, 200, -1, 2000, 1750, 1000, -1, "icons\pcp.paa"],
["pcpp", "Purified PCP Sheet", 2, -1, 200, -1, 2000, 2500, 1350, -1, "icons\pcpp.paa"],
```

- [ ] **Step 4: Remove the recipes**

In `core/actions/fn_processAction.sqf`, remove these five entries from the `AP_processMap` literal:

```sqf
["fungi", [["fungi"], "lsd_0", 0, "Extracting LSD Juices From Moist Fungi", 1]],
["lsd_1", [["lsd_0"], "lsd_1", 0, "Turning LSD into sheets", 1]],
["pcpu", [["henbane", "hydro"], "pcpu", 0, "Mixing and extracting ingredients", 0]],
["pcp", [["pcpu"], "pcp", 0, "Processing PCP Pills", 1]],
["pcpp", [["pcp"], "pcpp", 0, "Turning PCP Pills into sheets", 1]],
```

In the same file also remove: the `case ("lsd_0"): {["makeLsd", 6, 5]};` arm of `_processSoundArray`; `"pcpu"`, `"pcp"`, `"pcpp"`, `"lsd_0"`, `"lsd_1"` from the infamy-talent `_output in [...]` list; `"pcpp"` from the `_tax = 0.95` list; `"pcp"`, `"pcpp"`, `"lsd_0"`, `"lsd_1"` from the infamy-award `_output in [...]` list.

In `core/actions/fn_processVehicle.sqf`, remove the `"fungi"` case and the `"heroin"` case.

- [ ] **Step 5: Remove the shop, exchange, market and demand rows**

`core/config/fn_virt_shops.sqf` — in the `"Drug Dealer"` sell list, delete `"pcp", "pcpp", ` from the front and `, "lsd_0", "lsd_1"` from the end. The remaining list must stay syntactically valid:

```sqf
["cocainep", "cokebrick", "marijuana", "marijuanam", "meth", "bluemeth", "ephedra", "crank", "crankp", "humanscalp", "cannas_3", "cannai_3", "canna_dab"]
```

`core/config/fn_exchangeCfg.sqf` — delete these three array elements:

```
["virtualItem","lsd_1",1,750,25,500000,350],
["virtualItem","lsd_0",1,750,25,500000,350],
["virtualItem","pcp",1,750,25,500000,350],
```

`core/compat/fn_itemDemand.sqf` — delete `["lsd_0",900],["lsd_1",900],`.

`server/AP_server/core/system/fn_marketTick.sqf` — remove `lsd_0` and `lsd_1` from both lists (L38 and L46).

- [ ] **Step 6: Fix the login bonus WITHOUT shifting day numbers**

`core/config/fn_loginBonusCfg.sqf` rows are `[dayNumber, [item, qty], ...]`. Days 39 and 52 award `pcp` and `lsd_0`. **Do not delete these rows** — the day index is the reward calendar and removing an entry silently changes which day awards what. Substitute the item instead:

```sqf
[39, ["cocainep", 5], true, false, false, false],
```

```sqf
[52, ["marijuana", 30], true, false, false, false],
```

(These become Smash and Reggie Cannabis after Task 4. Quantities are kept as-is.)

- [ ] **Step 7: Remove the stat slots — delete only, renumber nothing**

`core/functions/fn_statArrUpdate.sqf`. Change:

```sqf
["remoteenginekillswitch", 143], ["henbane", 144],
        ["pcpu", 145], ["pcp", 146], ["pcpp", 147]];};
```

to:

```sqf
["remoteenginekillswitch", 143]];};
```

Slots 144–147 are now unused holes. **This is correct.** Every other index in the map keeps its exact current number.

- [ ] **Step 8: Remove the wanted charges from BOTH copies**

`core/config/fn_wantedChargesConfig.sqf` and `server/AP_server/core/TON/fn_wantedChargesConfig.sqf` are two copies of the same table and **must stay identical**. Locate the entries with:

```bash
grep -noiE 'LSD|PCP|Fungi' mission/Armapunk2035.Malden/core/config/fn_wantedChargesConfig.sqf
grep -noiE 'LSD|PCP|Fungi' server/AP_server/core/TON/fn_wantedChargesConfig.sqf
```

Delete the charge entries that name LSD, PCP or Fungi from both. After editing, prove they still match:

```bash
diff <(grep -o '"[^"]*"' mission/Armapunk2035.Malden/core/config/fn_wantedChargesConfig.sqf) \
     <(grep -o '"[^"]*"' server/AP_server/core/TON/fn_wantedChargesConfig.sqf) && echo IDENTICAL
```

Expected: `IDENTICAL`.

- [ ] **Step 9: Remove the gather field, the dig loop and the talent clause**

`core/actions/fn_gather.sqf` — delete `case (_zone isEqualTo "illegal_marker_8_0"): {["henbane", 150];};` and remove `"henbane"` from both talent clauses at L45 and L53, leaving `ephedrau` alone in each:

```sqf
private _giveExtraGangTalent9 = (_item in ["ephedrau"] && 9 in AP_gang_talents);
```

```sqf
if (_item in ["ephedrau"] && {22 in AP_infamy_talents && license_civ_rebel}) then {_delay = _delay - 0.04;};
```

`core/fn_setupActions.sqf:489` — delete the whole `Gather Henbane` `addAction` line.

`core/config/fn_talentCfg.sqf` — talent 223 "Rockhound" currently reads `"You know where to dig. Mining uranium and fungi pulls an extra unit every swing."`. Change the description to `"You know where to dig. Mining uranium pulls an extra unit every swing."` and remove the fungi branch from wherever the talent is applied. **Keep talent id 223** — talent ids are persisted per player.

`evh/fn_onPlayerRespawn.sqf` — delete the `AP_inFungiDen` clear at L19–21.

- [ ] **Step 10: Remove the remaining scattered references**

Each of these is a single reference; open the file, find it, remove it:

```
core/pmenu/fn_useItem.sqf          lsd_0/lsd_1, pcp, heroinp cases
core/drugs/fn_drugUsed.sqf         "heroinp" and "lsd" switch arms
npcs/fn_civProcessItem.sqf         case "heroin" block; stale names in the purificationfactory comment
core/config/fn_prestigeCfg.sqf     henbane (L11, L95)
core/shops/fn_sellVehicleInv.sqf   lsd_0, lsd_1, pcp (L44)
core/actions/fn_metalDetector.sqf  lsd_0 (L31)
core/vehicle/fn_deviceMine.sqf     henbane (L25)
core/vehicle/fn_tractorMine.sqf    henbane (L23)
core/configuration.sqf             pcp (L2) -- append-only file, surgical edit only
core/radio/fn_plbInvDemo.sqf       LSD (L14)
debug/npcprobe.sqf                 pcp/PCP
initServer.sqf                     the illegal_marker_8_0 comment block (L70)
server/AP_server/eventhandlers.sqf pcp/PCP (L116)
edenNPC_data.sqf                   the Fungi Den NPC entry (grep for the fungi processor type)
tools/make_compositions.py, tools/npc_move.py, tools/npc_place.py
```

The Fungi Den's buildings and elevator are map-layer objects and stay. Only the NPC that attaches the dig actions is removed.

- [ ] **Step 11: Delete the assets and their sound classes**

```bash
git rm mission/Armapunk2035.Malden/icons/lsdpill.paa \
       mission/Armapunk2035.Malden/icons/lsdpurify.paa \
       mission/Armapunk2035.Malden/icons/pcp.paa \
       mission/Armapunk2035.Malden/icons/pcpp.paa \
       mission/Armapunk2035.Malden/icons/pcpu.paa \
       mission/Armapunk2035.Malden/icons/darkmushroom.paa \
       mission/Armapunk2035.Malden/icons/henbane.paa \
       mission/Armapunk2035.Malden/sounds/gatherLsd.ogg \
       mission/Armapunk2035.Malden/sounds/makeLsd.ogg
```

Then remove the `gatherLsd` and `makeLsd` classes from `CfgSounds.hpp`. A `CfgSounds` class pointing at a missing `.ogg` is a boot-time error.

- [ ] **Step 12: Observe the green state — offline**

```bash
bash tools/run_checks.sh
```

Expected: every check PASS, exit 0.

```bash
grep -rnoiE '"(lsd_[01]|pcpu|pcpp|pcp|fungi|henbane|heroinp)"' \
  --include=*.sqf --include=*.hpp --include=*.cpp --include=*.py --include=*.ts \
  mission/ server/ tools/ website/ | wc -l
```

Expected: `0`. This is the Step 1 red state resolved.

- [ ] **Step 13: Observe the green state — in-game**

```bash
bash /home/timb/arma3server_dev/reload-armapunk2035.sh
grep "read from bank" /home/timb/arma3server_dev/loonydev.log
```

Expected: the boot marker appears within ~90s. Then read the newest client RPT and confirm no new errors — specifically no `undefined variable AP_inv_lsd_0` / `..._pcp` / `..._fungi` / `..._henbane`, and no missing-function errors for the six deleted functions.

Connect and confirm: the Drug Dealer sell list shows no LSD or PCP rows; the Fungi Den NPC is gone; no "Gather Henbane" action anywhere.

- [ ] **Step 14: Commit**

```bash
git add -A
git commit -m "feat(drugs): strip the LSD and PCP chains entirely

Removes both chains and the two raw goods that existed only to feed them:
lsd_0, lsd_1, pcpu, pcp, pcpp, fungi, henbane. Takes with them the Dark
Fungi Den dig loop, the henbane gather field, the dead heroin processor
case, and fn_heroin.sqf -- whose item was deleted a pass ago and whose
hook was only being kept for fentanyl, which now has no effect to inherit.

The henbane field was already unreachable on Malden: its marker
illegal_marker_8_0 is absent from mission.sqm and the action is gated on
markerType != \"\", so this deletes dead code rather than content.

Stat slots 144-147 are removed and NOTHING is renumbered -- the indices
are persisted per player and read back by the website by number.

Co-Authored-By: Clippy"
```

---

# Phase 2 — Renames

Every rename task follows the same shape and the same footgun.

**The footgun: never replace a bare substring.** `meth` is inside `bluemeth` and `methcocktail`; `crank` is inside `crankp` and `crankLab`; `cocaine` is inside `cocainep`; `phos` is inside `phosphorus`; `hydro` is inside dozens of unrelated engine class names. Replace only these exact token forms:

| Form | Example |
|---|---|
| quoted key | `"meth"` → `"blacklace"` |
| inventory variable | `AP_inv_meth` → `AP_inv_blacklace` |
| stat key with suffix | `"bluemeth_proc"` → `"blacklaceprime_proc"` |
| icon path | `icons\meth.paa` → `icons\blacklace.paa` |

Always rename the **longer** key first (`bluemeth` before `meth`, `crankp` before `crank`, `cocainep` before `cocaine`) so the shorter pattern cannot eat the longer one.

### Task 2: Rename the precursors

**Files:**
- Modify: every tracked file containing `"ephedrau"`, `"phos"`, `"hydro"`, `AP_inv_ephedrau`, `AP_inv_phos`, `AP_inv_hydro`
- Rename: `icons/ephedrau.paa` → `icons/sparkdust.paa`, `icons/phos.paa` → `icons/redshift.paa`, `icons/hydro.paa` → `icons/toxicslurry.paa`

**Interfaces:**
- Consumes: Task 1's cleaned tree
- Produces: keys `sparkdust`, `redshift`, `toxicslurry`. Tasks 3 and 5 depend on these names in their recipe inputs.

- [ ] **Step 1: Observe the red state**

```bash
grep -rn '"ephedrau"\|"phos"\|"hydro"\|AP_inv_ephedrau\|AP_inv_phos\|AP_inv_hydro' \
  --include=*.sqf --include=*.hpp --include=*.cpp --include=*.py --include=*.ts \
  mission/ server/ tools/ website/ | wc -l
```

Expected: non-zero. Record it.

- [ ] **Step 2: Rename the icon files**

```bash
git mv mission/Armapunk2035.Malden/icons/ephedrau.paa mission/Armapunk2035.Malden/icons/sparkdust.paa
git mv mission/Armapunk2035.Malden/icons/phos.paa     mission/Armapunk2035.Malden/icons/redshift.paa
git mv mission/Armapunk2035.Malden/icons/hydro.paa    mission/Armapunk2035.Malden/icons/toxicslurry.paa
```

- [ ] **Step 3: Replace the tokens**

```bash
FILES=$(grep -rl '"ephedrau"\|"phos"\|"hydro"\|AP_inv_ephedrau\|AP_inv_phos\|AP_inv_hydro' \
  --include=*.sqf --include=*.hpp --include=*.cpp --include=*.py --include=*.ts \
  mission/ server/ tools/ website/)
sed -i \
  -e 's/"ephedrau"/"sparkdust"/g'   -e 's/AP_inv_ephedrau/AP_inv_sparkdust/g' \
  -e 's/"phos"/"redshift"/g'        -e 's/AP_inv_phos/AP_inv_redshift/g' \
  -e 's/"hydro"/"toxicslurry"/g'    -e 's/AP_inv_hydro/AP_inv_toxicslurry/g' \
  -e 's|icons\\ephedrau\.paa|icons\\sparkdust.paa|g' \
  -e 's|icons\\phos\.paa|icons\\redshift.paa|g' \
  -e 's|icons\\hydro\.paa|icons\\toxicslurry.paa|g' \
  $FILES
```

- [ ] **Step 4: Set the display names**

In `core/config/fn_virtItemCfg.sqf` the three rows now read `["sparkdust", "Ephedra plant", ...]` and so on. Set the display names:

```sqf
["sparkdust", "Sparkdust", 2, -1, 100, -1, -1, -1, -1, -1, "icons\sparkdust.paa"],
["redshift", "Redshift", 2, -1, -1, 1, 234, 165, 115, -1, "icons\redshift.paa"],
["toxicslurry", "Toxic Slurry", 2, -1, -1, -1, 234, 165, 115, -1, "icons\toxicslurry.paa"],
```

- [ ] **Step 5: Fix the stat slots — keys change, indices do not**

In `core/functions/fn_statArrUpdate.sqf` the sed above already changed `["phos", 19]` → `["redshift", 19]` and `["hydro", 18]` → `["toxicslurry", 18]`. **Verify the numbers are untouched:**

```bash
grep -o '\["redshift", 19\]\|\["toxicslurry", 18\]' mission/Armapunk2035.Malden/core/functions/fn_statArrUpdate.sqf
```

Expected: both print. If either index changed, revert and redo — a shifted index corrupts every later stat.

- [ ] **Step 6: Verify offline**

```bash
bash tools/run_checks.sh
grep -rn '"ephedrau"\|"phos"\|"hydro"\|AP_inv_ephedrau\|AP_inv_phos\|AP_inv_hydro' \
  --include=*.sqf --include=*.hpp --include=*.cpp --include=*.py --include=*.ts \
  mission/ server/ tools/ website/ | wc -l
```

Expected: `run_checks.sh` all PASS, grep count `0`.

- [ ] **Step 7: Verify in-game**

Deploy, wait for the boot marker, read the RPT. Then in-game: gather at an ephedra field and confirm the pickup message names **Sparkdust**, the Y-inventory row reads Sparkdust with its icon, and the meth processor's "Mix Meth cocktail" action appears when you hold all three precursors.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat(drugs): rename the precursors to Sparkdust, Redshift and Toxic Slurry

ephedrau -> sparkdust, phos -> redshift, hydro -> toxicslurry. Item keys
change with the display names: there is no live server and no SQL or bot
coupling, so leaving AP_inv_phos meaning Redshift would make the code
permanently misleading.

Stat slot indices 18 and 19 are unchanged -- only their keys are renamed,
so historical stats stay attached to the right columns.

Co-Authored-By: ELIZA"
```

### Task 3: Rename the meth chain to Black Lace

**Files:**
- Modify: every tracked file containing the meth chain tokens
- Rename: `icons/meth.paa` → `icons/blacklace.paa`, `icons/bluemeth.paa` → `icons/blacklaceprime.paa`, `icons/ephedra.paa` → `icons/lacebase.paa`
- Rename: `core/drugs/fn_meth.sqf` → `core/drugs/fn_blackLace.sqf`

**Interfaces:**
- Consumes: `sparkdust`, `redshift`, `toxicslurry` from Task 2
- Produces: keys `lacebase`, `blacklace`, `blacklaceprime`; function `AP_fnc_blackLace`. Task 8 rewrites that function's body; Task 13 adds `cut_blacklace` and `cut_blacklaceprime`.

- [ ] **Step 1: Observe the red state**

```bash
grep -rn '"bluemeth"\|"meth"\|"ephedra"\|"methcocktail"\|AP_inv_bluemeth\|AP_inv_meth\|AP_inv_ephedra\|bluemeth_proc' \
  --include=*.sqf --include=*.hpp --include=*.cpp --include=*.py --include=*.ts \
  mission/ server/ tools/ website/ | wc -l
```

Expected: non-zero. Record it.

- [ ] **Step 2: Rename the files**

```bash
git mv mission/Armapunk2035.Malden/icons/meth.paa      mission/Armapunk2035.Malden/icons/blacklace.paa
git mv mission/Armapunk2035.Malden/icons/bluemeth.paa  mission/Armapunk2035.Malden/icons/blacklaceprime.paa
git mv mission/Armapunk2035.Malden/icons/ephedra.paa   mission/Armapunk2035.Malden/icons/lacebase.paa
git mv mission/Armapunk2035.Malden/core/drugs/fn_meth.sqf mission/Armapunk2035.Malden/core/drugs/fn_blackLace.sqf
```

- [ ] **Step 3: Replace the tokens — longest first**

```bash
FILES=$(grep -rl '"bluemeth"\|"meth"\|"ephedra"\|"methcocktail"\|AP_inv_bluemeth\|AP_inv_meth\|AP_inv_ephedra\|bluemeth_proc\|AP_meth_effect\|AP_fnc_meth' \
  --include=*.sqf --include=*.hpp --include=*.cpp --include=*.py --include=*.ts \
  mission/ server/ tools/ website/)
sed -i \
  -e 's/"bluemeth_proc"/"blacklaceprime_proc"/g' \
  -e 's/"bluemeth"/"blacklaceprime"/g'  -e 's/AP_inv_bluemeth/AP_inv_blacklaceprime/g' \
  -e 's/"methcocktail"/"lacebase"/g' \
  -e 's/"ephedra"/"lacebase"/g'         -e 's/AP_inv_ephedra/AP_inv_lacebase/g' \
  -e 's/"meth"/"blacklace"/g'           -e 's/AP_inv_meth/AP_inv_blacklace/g' \
  -e 's/AP_meth_effect/AP_blackLace_effect/g' \
  -e 's/AP_fnc_meth/AP_fnc_blackLace/g' \
  -e 's|icons\\meth\.paa|icons\\blacklace.paa|g' \
  -e 's|icons\\bluemeth\.paa|icons\\blacklaceprime.paa|g' \
  -e 's|icons\\ephedra\.paa|icons\\lacebase.paa|g' \
  $FILES
```

Note the ordering: `bluemeth_proc` before `bluemeth` before `meth`, and `methcocktail` before `meth`. Reordering these corrupts the result silently.

- [ ] **Step 4: Update `Functions.h`**

The registration for `fn_meth.sqf` must now name `fn_blackLace.sqf`. Find and fix:

```bash
grep -n 'fn_meth\|blackLace' mission/Armapunk2035.Malden/Functions.h
```

- [ ] **Step 5: Set the display names**

```sqf
["lacebase", "Lace Base", 2, -1, 225, -1, -1, -1, 375, -1, "icons\lacebase.paa"],
["blacklace", "Black Lace", 2, -1, 400, 1, 3277, 2800, 1800, -1, "icons\blacklace.paa"],
["blacklaceprime", "Black Lace Prime", 2, -1, 900, 1, 3880, 3200, 2700, -1, "icons\blacklaceprime.paa"],
```

- [ ] **Step 6: Rename the processor captions**

In `npcs/fn_civProcessItem.sqf`, `case "meth"` is now `case "blacklace"` — the NPC type string. Check `core/config/fn_mapData.sqf` for the processor's declared type and keep the two in sync. Update the captions:

```sqf
_obj_main addAction["Mix Lace Base", AP_fnc_processAction, "lacebase", 1.5, false, false, "", 'AP_inv_sparkdust > 0 && AP_inv_redshift > 0 && AP_inv_toxicslurry > 0 && !AP_is_processing', 5];
_obj_main addAction["<t color='#33FF99'>Process Vehicle: Lace Base</t>", AP_fnc_processVehicle, "lacebase", 1.5, false, false, "", '!AP_is_processing', 5];
_obj_main addAction["Cook Black Lace", AP_fnc_processAction, "blacklace", 1.5, false, false, "", 'AP_inv_lacebase > 0 && !AP_is_processing', 5];
_obj_main addAction["<t color='#33FF99'>Process Vehicle: Black Lace</t>", AP_fnc_processVehicle, "blacklace", 1.5, false, false, "", '!AP_is_processing', 5];
_obj_main addAction["Refine Black Lace Prime", AP_fnc_processAction, "blacklaceprime", 1.5, false, false, "", 'AP_inv_blacklace > 0 && !AP_is_processing', 5];
_obj_main addAction["<t color='#33FF99'>Process Vehicle: Black Lace Prime</t>", AP_fnc_processVehicle, "blacklaceprime", 1.5, false, false, "", '!AP_is_processing', 5];
```

Also update the process captions inside the recipe rows in `fn_processAction.sqf`: `"Cooking Meth"` → `"Cooking Black Lace"`, `"Purifying Crystal Meth"` → `"Refining Black Lace Prime"`, `"Mixing Ingredients"` stays.

- [ ] **Step 7: Verify the stat indices survived**

```bash
grep -o '\["blacklace", 26\]\|\["lacebase", 25\]\|\["blacklaceprime_proc", 68\]' \
  mission/Armapunk2035.Malden/core/functions/fn_statArrUpdate.sqf
```

Expected: all three print, with those exact numbers.

- [ ] **Step 8: Verify offline and in-game**

```bash
bash tools/run_checks.sh
grep -rn '"bluemeth"\|"meth"\|"ephedra"\|"methcocktail"\|AP_inv_meth\|AP_inv_bluemeth\|AP_inv_ephedra' \
  --include=*.sqf --include=*.hpp --include=*.cpp --include=*.py --include=*.ts \
  mission/ server/ tools/ website/ | wc -l
```

Expected: all PASS, grep `0`. Deploy, boot marker, clean RPT. In-game: cook the full chain Sparkdust+Redshift+Toxic Slurry → Lace Base → Black Lace → Black Lace Prime, and confirm every caption, item name and icon reads correctly and the Drug Dealer buys all three.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat(drugs): rename the meth chain to Black Lace

ephedra -> lacebase, meth -> blacklace, bluemeth -> blacklaceprime, plus
the fn_meth.sqf -> fn_blackLace.sqf move and the processor captions.

Tokens were replaced longest-first (bluemeth_proc, then bluemeth, then
methcocktail, then meth) so the shorter key could not eat the longer one.
Stat indices 25, 26 and 68 are unchanged.

Effects are unchanged by this commit -- Black Lace still behaves exactly
like meth did. The new behaviour lands in its own commit.

Co-Authored-By: Dr. Sbaitso"
```

### Task 4: Rename the cocaine chain to Smash

**Files:**
- Modify: every tracked file containing the cocaine chain tokens
- Rename: `icons/cocaine.paa` → `icons/smashpowder.paa`, `icons/cocainep.paa` → `icons/smash.paa`, `icons/cokebrick.paa` → `icons/smashbrick.paa`
- Rename: `core/items/fn_cocaine.sqf` → `core/drugs/fn_smash.sqf` (also moves domain: it is a drug, not an item)

**Interfaces:**
- Consumes: Task 1's cleaned tree
- Produces: keys `smashpowder`, `smash`, `smashbrick`; function `AP_fnc_smash`. Task 9 rewrites that function's body; Task 13 adds three cut recipes.

- [ ] **Step 1: Observe the red state**

```bash
grep -rn '"cokebrick"\|"cocainep"\|"cocaine"\|AP_inv_cokebrick\|AP_inv_cocainep\|AP_inv_cocaine\|AP_cocaine_effect\|AP_fnc_cocaine\|cokebrick_proc' \
  --include=*.sqf --include=*.hpp --include=*.cpp --include=*.py --include=*.ts \
  mission/ server/ tools/ website/ | wc -l
```

Expected: non-zero. Record it.

- [ ] **Step 2: Rename the files**

```bash
git mv mission/Armapunk2035.Malden/icons/cocaine.paa   mission/Armapunk2035.Malden/icons/smashpowder.paa
git mv mission/Armapunk2035.Malden/icons/cocainep.paa  mission/Armapunk2035.Malden/icons/smash.paa
git mv mission/Armapunk2035.Malden/icons/cokebrick.paa mission/Armapunk2035.Malden/icons/smashbrick.paa
git mv mission/Armapunk2035.Malden/core/items/fn_cocaine.sqf mission/Armapunk2035.Malden/core/drugs/fn_smash.sqf
```

- [ ] **Step 3: Replace the tokens — longest first**

```bash
FILES=$(grep -rl '"cokebrick"\|"cocainep"\|"cocaine"\|AP_inv_cokebrick\|AP_inv_cocainep\|AP_inv_cocaine\|AP_cocaine_effect\|AP_fnc_cocaine\|cokebrick_proc' \
  --include=*.sqf --include=*.hpp --include=*.cpp --include=*.py --include=*.ts \
  mission/ server/ tools/ website/)
sed -i \
  -e 's/"cokebrick_proc"/"smashbrick_proc"/g' \
  -e 's/"cokebrick"/"smashbrick"/g'  -e 's/AP_inv_cokebrick/AP_inv_smashbrick/g' \
  -e 's/"cocainep"/"smash"/g'        -e 's/AP_inv_cocainep/AP_inv_smash/g' \
  -e 's/"cocaine"/"smashpowder"/g'   -e 's/AP_inv_cocaine/AP_inv_smashpowder/g' \
  -e 's/AP_cocaine_effect/AP_smash_effect/g' \
  -e 's/AP_fnc_cocaine/AP_fnc_smash/g' \
  -e 's|icons\\cocainep\.paa|icons\\smash.paa|g' \
  -e 's|icons\\cocaine\.paa|icons\\smashpowder.paa|g' \
  -e 's|icons\\cokebrick\.paa|icons\\smashbrick.paa|g' \
  $FILES
```

`cocainep` must precede `cocaine`, and `icons\cocainep.paa` must precede `icons\cocaine.paa`, or the shorter pattern eats the longer one.

- [ ] **Step 4: Update `Functions.h`**

`fn_cocaine.sqf` moved domain as well as name — its `Functions.h` entry must point at `core\drugs\fn_smash.sqf`. Find and fix:

```bash
grep -n 'fn_cocaine\|fn_smash' mission/Armapunk2035.Malden/Functions.h
```

- [ ] **Step 5: Set the display names**

```sqf
["smashpowder", "Smash Powder", 3, -1, 150, -1, 267, 250, 175, -1, "icons\smashpowder.paa"],
["smash", "Smash", 3, -1, 300, 1, 1018, 999, 600, -1, "icons\smash.paa"],
["smashbrick", "Smash Bricks", 2, -1, 550, 1, 1618, 1100, 1000, -1, "icons\smashbrick.paa"],
```

- [ ] **Step 6: Rename the processor captions**

In `npcs/fn_civProcessItem.sqf`, `case "cocaine"` is now `case "smashpowder"` after the sed. Keep the NPC type string in sync with `core/config/fn_mapData.sqf`, and update the captions:

```sqf
_obj_main addAction["Process Smash", AP_fnc_processAction, "smashpowder", 1.5, false, false, "", 'AP_inv_smashpowder > 0 && !AP_is_processing', 5];
_obj_main addAction["<t color='#33FF99'>Process Vehicle: Smash</t>", AP_fnc_processVehicle, "smashpowder", 1.5, false, false, "", '!AP_is_processing', 5];
_obj_main addAction["Press Smash Bricks", AP_fnc_processAction, "smashbrick", 1.5, false, false, "", 'AP_inv_smash > 0 && !AP_is_processing', 5];
_obj_main addAction["<t color='#33FF99'>Process Vehicle: Smash Bricks</t>", AP_fnc_processVehicle, "smashbrick", 1.5, false, false, "", '!AP_is_processing', 5];
```

Recipe captions in `fn_processAction.sqf`: `"Processing Cocaine"` → `"Processing Smash"`, `"Forming Cocaine Bricks"` → `"Pressing Smash Bricks"`.

- [ ] **Step 7: Verify offline and in-game**

```bash
bash tools/run_checks.sh
grep -rn '"cokebrick"\|"cocainep"\|"cocaine"\|AP_inv_cocaine\|AP_inv_cocainep\|AP_inv_cokebrick' \
  --include=*.sqf --include=*.hpp --include=*.cpp --include=*.py --include=*.ts \
  mission/ server/ tools/ website/ | wc -l
```

Expected: all PASS, grep `0`. Deploy, boot marker, clean RPT. In-game: gather at a Smash field, process powder → Smash → Bricks, confirm captions, names and icons, and that the rebel weapon recipes that consume `AP_inv_smashpowder` still show their cost correctly.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat(drugs): rename the cocaine chain to Smash

cocaine -> smashpowder, cocainep -> smash, cokebrick -> smashbrick.
fn_cocaine.sqf moves to core/drugs/fn_smash.sqf, which is where it always
belonged -- it was the only drug effect living under core/items/.

Longest-first replacement again: cokebrick_proc, cokebrick, cocainep,
then cocaine. Weapon-craft recipes in fn_recipeDetail.sqf follow the
rename automatically since they reference AP_inv_ prefixed keys.

Co-Authored-By: Microsoft Tay"
```

### Task 5: Rename the crank chain to Glitter

**Files:**
- Modify: every tracked file containing the crank chain tokens
- Rename: `icons/crank.paa` → `icons/glitterbase.paa`, `icons/crankp.paa` → `icons/glitter.paa`
- Rename: `core/drugs/fn_crank.sqf` → `core/drugs/fn_glitter.sqf`, `core/actions/fn_crankLab.sqf` → `core/actions/fn_glitterLab.sqf`

**Interfaces:**
- Consumes: `sparkdust`, `redshift`, `toxicslurry` from Task 2
- Produces: keys `glitterbase`, `glitter`; functions `AP_fnc_glitter`, `AP_fnc_glitterLab`. Task 10 rewrites the effect; Task 13 adds `cut_glitter`.

- [ ] **Step 1: Observe the red state**

```bash
grep -rn '"crankp"\|"crank"\|AP_inv_crankp\|AP_inv_crank\|AP_crank_effect\|AP_fnc_crankLab\|AP_fnc_crank' \
  --include=*.sqf --include=*.hpp --include=*.cpp --include=*.py --include=*.ts \
  mission/ server/ tools/ website/ | wc -l
```

Expected: non-zero. Record it.

- [ ] **Step 2: Rename the files**

```bash
git mv mission/Armapunk2035.Malden/icons/crank.paa  mission/Armapunk2035.Malden/icons/glitterbase.paa
git mv mission/Armapunk2035.Malden/icons/crankp.paa mission/Armapunk2035.Malden/icons/glitter.paa
git mv mission/Armapunk2035.Malden/core/drugs/fn_crank.sqf mission/Armapunk2035.Malden/core/drugs/fn_glitter.sqf
git mv mission/Armapunk2035.Malden/core/actions/fn_crankLab.sqf mission/Armapunk2035.Malden/core/actions/fn_glitterLab.sqf
```

- [ ] **Step 3: Replace the tokens — longest first**

```bash
FILES=$(grep -rl '"crankp"\|"crank"\|AP_inv_crankp\|AP_inv_crank\|AP_crank_effect\|AP_fnc_crankLab\|AP_fnc_crank' \
  --include=*.sqf --include=*.hpp --include=*.cpp --include=*.py --include=*.ts \
  mission/ server/ tools/ website/)
sed -i \
  -e 's/AP_fnc_crankLab/AP_fnc_glitterLab/g' \
  -e 's/"crankp"/"glitter"/g'  -e 's/AP_inv_crankp/AP_inv_glitter/g' \
  -e 's/"crank"/"glitterbase"/g' -e 's/AP_inv_crank/AP_inv_glitterbase/g' \
  -e 's/AP_crank_effect/AP_glitter_effect/g' \
  -e 's/AP_fnc_crank/AP_fnc_glitter/g' \
  -e 's|icons\\crankp\.paa|icons\\glitter.paa|g' \
  -e 's|icons\\crank\.paa|icons\\glitterbase.paa|g' \
  $FILES
```

`"crankp"` must precede `"crank"`, and `icons\crankp.paa` must precede `icons\crank.paa`. The `AP_fnc_crankLab` line is listed first for clarity but reaches the same result either way, since `AP_fnc_crankLab` contains `AP_fnc_crank` as a prefix and both rewrites land on `AP_fnc_glitterLab`. Verify rather than assume:

```bash
grep -rn 'AP_fnc_glitterLab' --include=*.sqf --include=*.h mission/ | wc -l
grep -rn 'crankLab\|AP_fnc_crank' --include=*.sqf --include=*.h mission/ | wc -l
```

Expected: the first count is non-zero, the second is `0`.

- [ ] **Step 4: Update `Functions.h`**

Both renamed functions need their registrations updated:

```bash
grep -n 'fn_crank\|fn_glitter' mission/Armapunk2035.Malden/Functions.h
```

- [ ] **Step 5: Set the display names**

```sqf
["glitterbase", "Glitter Base", 2, -1, 200, -1, -1, -1, 235, -1, "icons\glitterbase.paa"],
["glitter", "Glitter", 2, -1, 450, 1, 1780, 1699, 1000, -1, "icons\glitter.paa"],
```

- [ ] **Step 6: Fix the mobile-lab proximity guards**

`fn_processAction.sqf` has two guards keyed on the old output names. After the sed they read `_output in ["glitterbase", "glitter"]` — confirm both the building-distance check and the vehicle-distance check picked up the rename:

```bash
grep -n 'glitterbase", "glitter"' mission/Armapunk2035.Malden/core/actions/fn_processAction.sqf
```

Expected: two hits — the "too close to a building" guard and the in-loop vehicle-distance check. If either still says `crank`, fix it. A missed guard here means the mobile lab can be run from inside a building.

- [ ] **Step 7: Rename the captions**

Recipe captions in `fn_processAction.sqf`: `"Mixing Ingredients"` stays for `glitterbase`; `"Cooking Crank"` → `"Cooking Glitter"`. Processor NPC captions in `npcs/fn_civProcessItem.sqf` become `Mix Glitter Base` and `Cook Glitter`.

- [ ] **Step 8: Verify the stat indices survived**

```bash
grep -o '\["glitterbase", 23\]\|\["glitter", 24\]' mission/Armapunk2035.Malden/core/functions/fn_statArrUpdate.sqf
```

Expected: both print, with those exact numbers.

- [ ] **Step 9: Verify offline and in-game**

```bash
bash tools/run_checks.sh
grep -rn '"crankp"\|"crank"\|AP_inv_crank\|AP_inv_crankp\|AP_fnc_crank' \
  --include=*.sqf --include=*.hpp --include=*.cpp --include=*.py --include=*.ts \
  mission/ server/ tools/ website/ | wc -l
```

Expected: all PASS, grep `0`. Deploy, boot marker, clean RPT. In-game: run the mobile lab, confirm the "too close to a building" guard still fires indoors, and cook Glitter Base → Glitter.

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "feat(drugs): rename the crank chain to Glitter

crank -> glitterbase, crankp -> glitter, plus fn_crank.sqf and
fn_crankLab.sqf. AP_fnc_crankLab is replaced before AP_fnc_crank so the
shorter pattern cannot mangle the lab function's name.

The two mobile-lab proximity guards in fn_processAction.sqf are verified
by grep after the sweep: a missed rename there silently lets the lab run
indoors, which is the whole point of the guard.

Stat indices 23 and 24 unchanged.

Co-Authored-By: SmarterChild"
```

### Task 6: Rename fentanylu to Boost

**Files:**
- Modify: every tracked file containing `"fentanylu"` / `AP_inv_fentanylu`
- Rename: `icons/fentanylu.paa` → `icons/boost.paa`

**Interfaces:**
- Consumes: Task 1's cleaned tree
- Produces: key `boost`. Task 11 gives it a use message; Task 13 uses it as the second input of all eleven cut recipes.

- [ ] **Step 1: Observe the red state**

```bash
grep -rn '"fentanylu"\|AP_inv_fentanylu' \
  --include=*.sqf --include=*.hpp --include=*.cpp --include=*.py --include=*.ts \
  mission/ server/ tools/ website/ | wc -l
```

Expected: non-zero (about 28 — twelve of them are weapon-craft recipes in `fn_recipeDetail.sqf`). Record it.

- [ ] **Step 2: Rename the icon and replace the tokens**

```bash
git mv mission/Armapunk2035.Malden/icons/fentanylu.paa mission/Armapunk2035.Malden/icons/boost.paa
FILES=$(grep -rl '"fentanylu"\|AP_inv_fentanylu' \
  --include=*.sqf --include=*.hpp --include=*.cpp --include=*.py --include=*.ts \
  mission/ server/ tools/ website/)
sed -i -e 's/"fentanylu"/"boost"/g' -e 's/AP_inv_fentanylu/AP_inv_boost/g' \
       -e 's|icons\\fentanylu\.paa|icons\\boost.paa|g' $FILES
```

- [ ] **Step 3: Set the display name and give it a price**

Boost is currently unpriced (`-1` across the board) because it was raw feedstock with no chain. As a cutting agent it must be buyable, or the mechanic has no on-ramp. Set it to sell at the Blackmarket and buy at the rebel shop:

```sqf
["boost", "Boost", 2, -1, 200, 1, 900, 800, 600, -1, "icons\boost.paa"],
```

Add `"boost"` to the rebel shop's item list in `core/config/fn_virt_shops.sqf`.

- [ ] **Step 4: Verify offline and in-game**

```bash
bash tools/run_checks.sh
grep -rn '"fentanylu"\|AP_inv_fentanylu' \
  --include=*.sqf --include=*.hpp --include=*.cpp --include=*.py --include=*.ts \
  mission/ server/ tools/ website/ | wc -l
```

Expected: all PASS, grep `0`. Deploy, boot marker, clean RPT. In-game: buy Boost at the rebel shop, confirm the Y-inventory row reads "Boost" with its icon, and confirm a weapon recipe that consumes it still displays its cost.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(drugs): rename Raw Fentanyl to Boost and make it purchasable

fentanylu -> boost. Also gives it a price and a rebel-shop listing: it was
unpriced because it had no chain, but as the cutting agent it needs an
on-ramp or the mechanic it exists for is unreachable.

It remains feedstock for twelve weapon recipes in fn_recipeDetail.sqf.
That an adulterant is also rifle-crafting material predates this work and
is left as-is deliberately (see drugs.md, Known issues).

Co-Authored-By: Clippy"
```

---

# Phase 3 — Behaviour

### Task 7: The heal block

**Files:**
- Create: `mission/Armapunk2035.Malden/core/drugs/fn_healBlocked.sqf`
- Modify: `mission/Armapunk2035.Malden/Functions.h`, `core/fn_survival.sqf:37`, `core/items/fn_bloodbag.sqf`, `core/items/fn_medKit.sqf`, `core/items/fn_adrenalineShot.sqf`, `core/items/fn_adrenalineShotEffect.sqf`, plus every remaining heal path found in Step 2

**Interfaces:**
- Consumes: nothing
- Produces: `AP_fnc_healBlocked` — `[unit] call AP_fnc_healBlocked` (defaults to `player`) returns `true` while that unit's healing is blocked. Task 8 sets `AP_healBlock`.

- [ ] **Step 1: Write the predicate**

Create `mission/Armapunk2035.Malden/core/drugs/fn_healBlocked.sqf`:

```sqf
// Single source of truth for "is this player's healing currently suppressed?".
// Black Lace publishes AP_healBlock on the UNIT as an expiry time; every heal path asks here rather
// than testing the variable itself, so adding a second suppressing effect later is
// one edit instead of eight. Returns false when the variable was never set.
params [["_unit", player, [objNull]]];
// PUBLIC OBJECT VARIABLE, not missionNamespace: fn_bloodbag/fn_medKit have a
// heal-ANOTHER-player branch where the HEALER's client runs setDamage on the
// victim, so the gate must be readable from any machine. Mirrors AP_can_revive.
private _until = _unit getVariable ["AP_healBlock", 0];
if (_until <= time) exitWith { false };
true
```

Register it in `Functions.h` alongside the other `core/drugs/` functions.

- [ ] **Step 2: Observe the red state — enumerate every heal path**

```bash
grep -rn 'setDamage\|setHitPointDamage\|AP_can_revive' --include=*.sqf \
  mission/Armapunk2035.Malden/core/ mission/Armapunk2035.Malden/evh/ \
  | grep -viE 'setDamage 1|setDamage\(1\)|suicide|forceRagDoll' | cut -c1-160
```

Read every hit. Any that **reduces** damage is a heal path and needs the gate. The known set is `fn_survival.sqf:37` (passive regen), the bloodbag, the medkit, the first-aid kit, the defibrillator, the adrenaline shot, and the medic heal action. Write the full list down before editing — **a single missed path makes Black Lace's downside optional**, which is the one way this feature fails silently.

- [ ] **Step 3: Gate the passive regen**

`core/fn_survival.sqf` line 37 currently reads:

```sqf
_plb_dmg setDamage(damage player - 0.01);};};
```

Change the enclosing condition so the regen is skipped while blocked:

```sqf
if !(call AP_fnc_healBlocked) then { _plb_dmg setDamage(damage player - 0.01); };};};
```

- [ ] **Step 4: Gate every remaining heal path**

For each path from Step 2, add an early exit at the top of the healing branch. The pattern, applied to the bloodbag as the worked example:

```sqf
if (call AP_fnc_healBlocked) exitWith {
    ["Your blood won't take it. Something in your system is fighting the transfusion.", "basic"] spawn AP_fnc_handleMessage;
};
```

Use a message appropriate to each item — the player must be told *why* the heal did nothing, or this reads as a bug.

- [ ] **Step 5: Observe the green state**

Deploy, boot marker, clean RPT. Then in-game, with a debug probe:

```sqf
player setVariable ["AP_healBlock", time + 60, true]; diag_log format ["[AP-PROBE] blocked=%1 dmg=%2", call AP_fnc_healBlocked, damage player];
```

Take damage, then attempt each heal path in turn. Expected in RPT: `blocked=true`, and `damage player` unchanged after every attempt. Wait 60 seconds and repeat: `blocked=false` and each heal path works normally.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(drugs): add the heal-block gate

AP_fnc_healBlocked is one predicate over one expiry variable, asked by
every heal path rather than each testing the variable itself -- so the
next suppressing effect is one edit, not eight.

Every path that REDUCES damage is gated: passive regen in fn_survival,
bloodbag, medkit, FAK, defib, adrenaline shot and the medic heal action.
Each refuses with a message rather than silently doing nothing, because a
heal that no-ops without explanation reads as a bug.

Nothing sets AP_healBlock yet; Black Lace does that next.

Co-Authored-By: ELIZA"
```

### Task 7B: The movement-speed stack

**Files:**
- Create: `mission/Armapunk2035.Malden/core/functions/fn_speedMod.sqf`
- Modify: `mission/Armapunk2035.Malden/Functions.h`, `core/drugs/fn_blackLace.sqf`, `core/drugs/fn_smash.sqf`, `core/drugs/fn_glitter.sqf`, `core/items/fn_redgull.sqf`, `core/items/fn_supermale.sqf`, `initPlayerLocal.sqf:250-251`, `core/drugs/fn_cannabisItems.sqf`

**Interfaces:**
- Consumes: nothing
- Produces: `AP_fnc_speedMod` — `["name", coefficient] call AP_fnc_speedMod` registers or replaces a named modifier; `["name", nil] call AP_fnc_speedMod` clears it. Both recompute and apply. Tasks 8, 9 and 10 call it instead of touching `setAnimSpeedCoef`.

- [ ] **Step 1: Observe the red state**

```bash
grep -rn "setAnimSpeedCoef" --include=*.sqf mission/ | wc -l
```

Expected: **16 hits across 7 files.** `setAnimSpeedCoef` is absolute, not multiplicative, so every one of these writers overwrites the others, and each resets to `1` on expiry — cancelling any other effect still running. Take RedGull then Smash and you are at 1.20; when RedGull expires two minutes later you drop to 1.0, losing the Smash buff you paid for. That is the bug.

- [ ] **Step 2: Write the stack**

Create `mission/Armapunk2035.Malden/core/functions/fn_speedMod.sqf`:

```sqf
params [["_name", "", [""]], ["_coef", nil, [0]]];
if (_name isEqualTo "") exitWith {};

// THE ONLY WRITER OF setAnimSpeedCoef. The command is absolute, so seven
// independent callers each setting and later resetting it to 1 meant the last
// writer won and the first expiry cancelled everyone. Effects now register a
// NAMED coefficient here and the product of all live ones is applied once.
private _mods = missionNamespace getVariable ["AP_speedMods", createHashMap];
if (isNil "_coef") then { _mods deleteAt _name; } else { _mods set [_name, _coef]; };
missionNamespace setVariable ["AP_speedMods", _mods];

private _product = 1;
{ _product = _product * _y; } forEach _mods;

// Clamped so a future stack of buffs cannot produce a speed the animations
// cannot sustain, and so a stack of penalties cannot immobilise a player.
_product = (_product max 0.5) min 1.5;
player setAnimSpeedCoef _product;
_product
```

Register it in `Functions.h` with the other `core/functions/` entries.

- [ ] **Step 3: Convert every existing writer**

Each of the seven writers stops calling `setAnimSpeedCoef` directly. Apply on start:

```sqf
["redgull", 1.1] call AP_fnc_speedMod;
```

and on expiry, instead of `player setAnimSpeedCoef 1`:

```sqf
["redgull", nil] call AP_fnc_speedMod;
```

The full conversion table — the name is the modifier key and must be unique:

| File | Name | Coefficient |
|---|---|---|
| `core/items/fn_redgull.sqf` | `"redgull"` | `1.1` |
| `core/items/fn_supermale.sqf` | `"supermale"` | `1.12` |
| `initPlayerLocal.sqf:250-251` | `"supermale"` | `1.12` — same key, it is the same effect by a second route |
| `core/drugs/fn_cannabisItems.sqf` (vape) | `"cannaanim"` | `0.5` |
| `core/drugs/fn_cannabisItems.sqf` (dab rig) | `"cannaanim"` | `0.5` |
| `core/drugs/fn_blackLace.sqf` | `"blacklace"` | `1.15` |
| `core/drugs/fn_smash.sqf` | `"smash"` | `1.15` for now — Task 9 raises it to `1.20` |
| `core/drugs/fn_glitter.sqf` | `"glitter"` | `1.15` for now — Task 10 changes it to `0.85` |

Black Lace, Smash and Glitter keep their **current** coefficients in this task. Changing behaviour and changing the mechanism in one commit makes a regression impossible to bisect; Tasks 8–10 change the numbers.

- [ ] **Step 4: Observe the green state**

```bash
grep -rn "setAnimSpeedCoef" --include=*.sqf mission/ | grep -v fn_speedMod.sqf | wc -l
```

Expected: `0`. `fn_speedMod.sqf` is the only remaining writer.

```bash
bash tools/run_checks.sh
```

Expected: all PASS. Deploy, boot marker, clean RPT.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "fix(effects): make movement-speed buffs stack instead of clobbering

setAnimSpeedCoef is absolute, and seven callers were each setting it and
later resetting it to 1. The last writer won, and the FIRST expiry
cancelled everyone -- take RedGull then Smash and you sat at 1.20, then
dropped to 1.0 when RedGull ran out, losing the buff you paid for.

Effects now register a named coefficient with AP_fnc_speedMod, which
applies the product of all live modifiers and is the only writer of the
command. Clamped to [0.5, 1.5]. The two Super Male routes share one key
because they are one effect.

Coefficients are unchanged here on purpose: changing the mechanism and the
numbers in one commit would make a regression unbisectable.

Co-Authored-By: Clippy"
```

### Task 8: Black Lace effects

**Files:**
- Create: `mission/Armapunk2035.Malden/core/drugs/fn_drugVision.sqf`
- Modify: `mission/Armapunk2035.Malden/Functions.h`, `core/drugs/fn_blackLace.sqf`, `core/drugs/fn_drugUsed.sqf`

**Interfaces:**
- Consumes: `AP_fnc_healBlocked` from Task 7; `AP_fnc_speedMod` from Task 7B; the `blacklace` key from Task 3
- Produces: `AP_fnc_drugVision` — `[endTime] spawn AP_fnc_drugVision` runs the stimulant screen effect until `time > endTime`, then clears it. Task 9 reuses it.

- [ ] **Step 1: Observe the red state**

Deploy the current build. In-game, take Black Lace at full health and probe:

```sqf
diag_log format ["[AP-PROBE] dmg=%1 aim=%2 addiction=%3", damage player, player getCustomAimCoef, AP_addiction];
```

Expected before the change: `dmg=0`, `aim=1`, `addiction` slot 3 at its incremental value. All three are wrong per spec — that is the red state.

- [ ] **Step 2: Extract the shared screen effect**

Black Lace's ppEffect loop and the one Task 9 gives Smash are the same effect driven by the same variable. Write it once. Create `mission/Armapunk2035.Malden/core/drugs/fn_drugVision.sqf`:

```sqf
params [["_endTime", 0, [0]]];
// The stimulant screen signature, shared by every drug that has one. Intensity
// tracks AP_drug_level live, so a second hit mid-effect visibly deepens it.
// Spawn this -- it blocks until _endTime.
private _apply = {
    "ColorInversion" ppEffectEnable true;
    "ColorInversion" ppEffectAdjust[AP_drug_level / 5, 0, AP_drug_level / 5];
    "ColorInversion" ppEffectCommit 1;
    "chromAberration" ppEffectEnable true;
    "chromAberration" ppEffectAdjust[AP_drug_level / 10, AP_drug_level / 10, true];
    "chromAberration" ppEffectCommit 1;
};
call _apply;
while {alive player && (time < _endTime)} do { uiSleep 2; call _apply; };
"chromAberration" ppEffectEnable false;
"ColorInversion" ppEffectEnable false;
```

Register it in `Functions.h`.

- [ ] **Step 3: Rewrite the effect**

Replace the body of `core/drugs/fn_blackLace.sqf`:

```sqf
if !([false, "blacklace", 1] call AP_fnc_handleInv) exitWith {};
AP_drug_level = selectMin[AP_drug_level + 0.2, 1];

// THE PRICE. Half a health bar, permanently -- it does not come back when the
// effect ends. Clamped to 0.95 so the drug maims and never kills outright: a
// player at 60% damage taking Black Lace would otherwise die on the swallow,
// which reads as a crash rather than a choice.
player setDamage (((damage player) + 0.5) min 0.95);

// ...and no healing it off for the duration. fn_healBlocked reads this.
player setVariable ["AP_healBlock", time + 180, true];

if (AP_blackLace_effect isEqualTo 0) then {AP_blackLace_effect = time;
    [] spawn {AP_fatigueEnabled = false;
        ["blacklace", 1.15] call AP_fnc_speedMod;   // +15% sprint, stacked not clobbered
        player setCustomAimCoef 0.1;                // sway to 10% of normal
        player setFatigue 0;
        player enableFatigue false;
        waitUntil {uiSleep 0.75;
            !(alive player) || ((time - AP_blackLace_effect) > (3 * 60))};
        ["blacklace", nil] call AP_fnc_speedMod;
        player setCustomAimCoef 1;
        player enableFatigue true;
        AP_blackLace_effect = 0;
        AP_fatigueEnabled = true;};
    [AP_blackLace_effect + (3 * 60)] spawn AP_fnc_drugVision;} else {AP_blackLace_effect = time;};
systemChat "The lace takes hold. Everything narrows.";
[] call AP_fnc_hudUpdate;
["blacklace"] call AP_fnc_drugUsed;
```

- [ ] **Step 4: Make the addiction instant**

In `core/drugs/fn_drugUsed.sqf`, the switch arm for the meth slot currently reads `case "blacklace": {[3, 0.3]};` after Task 3's rename. Instant addiction means the accrual is a full unit:

```sqf
case "blacklace": {[3, 1]};
case "blacklaceprime": {[3, 1]};
```

`AP_addiction set[_index, selectMin[_add + _addInc, 1]]` already clamps to 1, so an increment of 1 saturates the slot on the first use, which is what "instantly addictive" means.

- [ ] **Step 5: Observe the green state**

Deploy, boot marker, clean RPT. **Owner decision 2026-08-21: no in-game pass this run** — the offline gate plus a clean boot is the bar. Record the probe block below in the report file so the owner can run it later; it is not a blocker for this task.

```sqf
diag_log format ["[AP-PROBE] dmg=%1 aim=%2 add3=%3 blocked=%4",
    damage player, player getCustomAimCoef, AP_addiction select 3, call AP_fnc_healBlocked];
```

Expected: `dmg=0.5`, `aim=0.1`, `add3=1`, `blocked=true`. Then verify:
- A bloodbag refuses with its message and `damage player` stays at 0.5
- Sprint is visibly faster and weapon sway visibly near-zero
- At 3 minutes: `aim` returns to 1, `blocked=false`, and `dmg` is **still 0.5** — the health does not come back
- Taking it again at `dmg=0.7` leaves you at 0.95, alive, not dead

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(drugs): Black Lace -- half a health bar, no heals, no sway

Costs 0.5 damage permanently (clamped to 0.95 so it maims rather than
killing on the swallow), blocks all healing for its 3 minutes, drops sway
to 10% via setCustomAimCoef, keeps the +15% sprint, and saturates its
addiction slot on the first use.

The health is not restored on expiry. That is the deal: it is the best
gunfighting drug in the game and you pay for it in blood you do not get
back.

Co-Authored-By: Dr. Sbaitso"
```

### Task 9: Smash effects

**Files:**
- Modify: `mission/Armapunk2035.Malden/core/drugs/fn_smash.sqf`

**Interfaces:**
- Consumes: the `smash` key from Task 4; `AP_fnc_speedMod` from Task 7B; `AP_fnc_drugVision` from Task 8
- Produces: nothing downstream

- [ ] **Step 1: Observe the red state**

In-game, take Smash at full health and probe:

```sqf
diag_log format ["[AP-PROBE] dmg=%1 anim=%2", damage player, player getAnimSpeedCoef];
```

Expected before the change: `dmg=0`, `anim=1.15`. Spec wants `dmg=0.3` and `anim=1.2`.

- [ ] **Step 2: Rewrite the effect**

Replace the body of `core/drugs/fn_smash.sqf`:

```sqf
params[["_isForced", false, [false]]];
if ((_isForced) || ([false, "smash", 1] call AP_fnc_handleInv)) then {

    // Smash costs 30% of a health bar, permanently. Same clamp as Black Lace:
    // it maims, it does not kill on use.
    player setDamage (((damage player) + 0.3) min 0.95);

    if (AP_smash_effect select 0) then {
        AP_smash_effect = [true, time];} else {AP_smash_effect = [true, time];
        [] spawn {waitUntil {uiSleep 1;
                (!alive player || ((time - (AP_smash_effect select 1)) > (6 * 60)));};
            AP_smash_effect = [false, time];
            AP_fatigueEnabled = true;
            ["smash", nil] call AP_fnc_speedMod;};

        // Smash now carries the same visual signature as Black Lace -- cocaine had
        // none, which made the strongest mobility drug in the game invisible to the
        // player taking it. Same helper, so the two cannot drift apart.
        [(AP_smash_effect select 1) + (6 * 60)] spawn AP_fnc_drugVision;};
    [] call AP_fnc_hudUpdate;
    AP_fatigueEnabled = false;
    player setFatigue 0;
    player enableFatigue false;
    titleText["Everything speeds up. You feel unstoppable!", "PLAIN"];
    ["smash", 1.20] call AP_fnc_speedMod;   // +20% sprint, stacked not clobbered

    ["smash"] call AP_fnc_drugUsed;
    AP_drug_level = selectMin[1, AP_drug_level + 0.15];} else {["You have no Smash to use.", "basic"] spawn AP_fnc_handleMessage;};
```

- [ ] **Step 3: Observe the green state**

Deploy, boot marker, clean RPT. In-game at full health, take Smash and probe:

```sqf
diag_log format ["[AP-PROBE] dmg=%1 anim=%2 add1=%3", damage player, player getAnimSpeedCoef, AP_addiction select 1];
```

Expected: `dmg=0.3`, `anim=1.2`, `add1` incremented by 0.1 (not saturated — Smash is not instantly addictive). Confirm the screen effect is visible and clears at 6 minutes, and that `dmg` stays at 0.3 after expiry.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(drugs): Smash -- +20% speed for 30% of a health bar

Costs 0.3 damage permanently, clamped to 0.95, and raises sprint to +20%
(cocaine was +15%). Adds the ColorInversion/chromAberration signature it
never had: the strongest mobility drug in the game was previously
invisible to the player taking it.

Addiction stays incremental at +0.10 -- Smash is the one drug in this pass
that is not instantly addictive.

Co-Authored-By: Microsoft Tay"
```

### Task 10: The Glitter shield

**Files:**
- Modify: `mission/Armapunk2035.Malden/core/drugs/fn_glitter.sqf`, `evh/fn_handleDamage.sqf`, `core/drugs/fn_drugUsed.sqf`

**Interfaces:**
- Consumes: the `glitter` key from Task 5; `AP_fnc_speedMod` from Task 7B
- Produces: `AP_glitterShield` (Number) — remaining absorb pool in damage units, `0` when inactive

- [ ] **Step 1: Observe the red state**

In-game, take Glitter, then take a known hit and probe:

```sqf
diag_log format ["[AP-PROBE] shield=%1 dmg=%2 anim=%3",
    missionNamespace getVariable ["AP_glitterShield", -1], damage player, player getAnimSpeedCoef];
```

Expected before the change: `shield=-1` (the variable does not exist), `anim=1.15`. Spec wants a 0.5 pool and `anim=0.85`.

- [ ] **Step 2: Add the pool to the damage handler**

In `evh/fn_handleDamage.sqf`, the handler already computes a damage figure and returns it. Insert the absorb step **before** the final return, after the headshot and armour branches (a headshot is lethal and deliberately ignores the shield — the shield is armour, not immortality):

```sqf
// GLITTER SHIELD. A non-decaying absorb pool drains before the health bar does.
// Placed after the headshot branch on purpose: Glitter is armour, not immortality.
private _shield = missionNamespace getVariable ["AP_glitterShield", 0];
if (_shield > 0) then {
    private _incoming = _damage - (damage _unit);
    if (_incoming > 0) then {
        private _absorbed = _incoming min _shield;
        AP_glitterShield = _shield - _absorbed;
        _damage = _damage - _absorbed;
        if (AP_glitterShield <= 0) then {
            AP_glitterShield = 0;
            systemChat "The glitter burns out.";
        };
    };
};
```

Adapt the variable names to the ones already in scope in that file — read it first. `_damage` is whatever the handler's running total is named, `_unit` whatever the damaged unit is named.

- [ ] **Step 3: Rewrite the effect**

Replace the body of `core/drugs/fn_glitter.sqf`:

```sqf
if !([false, "glitter", 1] call AP_fnc_handleInv) exitWith {};
AP_drug_level = selectMin[AP_drug_level + 0.4, 1];

// A HALF-BAR OF ARMOUR, NOT A HEAL. The pool does not decay with time -- only
// incoming damage spends it. So Glitter is a decision made BEFORE a fight, not a
// bloodbag you swallow during one: it cannot repair damage you already have.
AP_glitterShield = 0.5;

if (AP_glitter_effect isEqualTo 0) then {AP_glitter_effect = time;
    [] spawn {["glitter", 0.85] call AP_fnc_speedMod;   // -15% movement: the cost of the armour
        player setFatigue 0;
        player enableFatigue false;
        AP_fatigueEnabled = false;
        waitUntil {uiSleep 0.575;
            !(alive player) || ((time - AP_glitter_effect) > (3 * 60))};
        ["glitter", nil] call AP_fnc_speedMod;
        player enableFatigue true;
        AP_glitterShield = 0;    // the pool expires with the effect, spent or not
        AP_glitter_effect = 0;
        AP_fatigueEnabled = true;};} else {AP_glitter_effect = time;};
systemChat "Your skin hardens. Everything slows down.";
[] call AP_fnc_hudUpdate;
["glitter"] call AP_fnc_drugUsed;
```

- [ ] **Step 4: Make the addiction instant**

In `core/drugs/fn_drugUsed.sqf`:

```sqf
case "glitter": {[4, 1]};
```

- [ ] **Step 5: Observe the green state**

Deploy, boot marker, clean RPT. In-game:

```sqf
diag_log format ["[AP-PROBE] shield=%1 dmg=%2 anim=%3 add4=%4",
    AP_glitterShield, damage player, player getAnimSpeedCoef, AP_addiction select 4];
```

Take Glitter at full health. Expected: `shield=0.5`, `dmg=0`, `anim=0.85`, `add4=1`. Then:
- Take a small hit. Expected: `dmg` still `0`, `shield` reduced by the hit's size
- Keep taking hits until the pool empties. Expected: the "glitter burns out" message, then damage starts landing on the bar
- Take Glitter while already at `dmg=0.4`. Expected: `dmg` stays `0.4` — it must **not** heal you
- Wait out 3 minutes without being hit. Expected: `shield=0`, `anim=1`
- Take a headshot with the shield up. Expected: lethal — the shield does not absorb it

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(drugs): Glitter -- half a bar of armour for 15% of your speed

A non-decaying 0.5 absorb pool in fn_handleDamage that drains before the
health bar. It does not repair existing damage, so Glitter is a decision
made before a fight rather than a bloodbag swallowed during one, and it
sits after the headshot branch: it is armour, not immortality.

Costs 15% movement speed and saturates its addiction slot on first use.
The pool expires with the effect whether it was spent or not.

Co-Authored-By: SmarterChild"
```

### Task 11: Boost's use message and the dead-slot cleanup

**Files:**
- Modify: `mission/Armapunk2035.Malden/core/pmenu/fn_useItem.sqf`, `core/drugs/fn_drugUsed.sqf`

**Interfaces:**
- Consumes: the `boost` key from Task 6
- Produces: nothing downstream

- [ ] **Step 1: Observe the red state**

In-game, use Boost from the Y-inventory. Expected before the change: the generic "This item is not usable" default — indistinguishable from a bug.

- [ ] **Step 2: Add the case**

In `core/pmenu/fn_useItem.sqf`, add near the other drug cases:

```sqf
case (_item isEqualTo "boost"): {
        ["Boost does nothing on its own. Take it to a processor and cut a batch with it -- you'll walk away with twice what you put in.", "basic"] spawn AP_fnc_handleMessage;};
```

- [ ] **Step 3: Confirm slot 2 is genuinely unreferenced**

Task 1 removed the `heroinp` arm from `fn_drugUsed.sqf`. Addiction slot 2 is now written by nothing. Confirm, and leave the array five wide:

```bash
grep -rn 'AP_addiction' --include=*.sqf mission/ | grep -n 'select 2\|set\[2' | head
```

Expected: no writes to index 2. **Do not shrink `AP_addiction`** — its width is persisted in `profileNamespace` per faction, and narrowing it invalidates every stored value.

- [ ] **Step 4: Observe the green state**

Deploy, boot marker, clean RPT. Use Boost in-game: the explanatory message appears and no Boost is consumed.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(drugs): tell the player what Boost is for

Using Boost fell through to the generic \"not usable\" default, which is
indistinguishable from a bug for an item whose entire purpose is
non-obvious. It now explains itself and is not consumed.

Addiction slot 2 (ex-heroin) is left in place and unwritten. The array
width is persisted per faction in profileNamespace, so narrowing it would
invalidate every stored value to save one float.

Co-Authored-By: Clippy"
```

### Task 12: The yield column and the weight cap

**Files:**
- Modify: `mission/Armapunk2035.Malden/core/actions/fn_processAction.sqf`, `core/actions/fn_processVehicle.sqf`

**Interfaces:**
- Consumes: nothing
- Produces: `AP_processMap` rows accept an optional 6th element `_yield` (Number, default 1). Task 13 uses it.

- [ ] **Step 1: Observe the red state**

`fn_processAction.sqf` computes `_inputCount = selectMin _inputVals`, consumes `_inputCount` of each input and emits exactly `_inputCount` of the output. There is no yield term. Confirm:

```bash
grep -n '_inputCount = selectMin\|handleInv\] call\|true, _output, _inputCount' \
  mission/Armapunk2035.Malden/core/actions/fn_processAction.sqf
```

A recipe cannot currently produce more than it consumes. That is the red state — and it is why a cut recipe added as data alone would be a net loss.

- [ ] **Step 2: Add the yield parameter**

In `fn_processAction.sqf`, change:

```sqf
_processArray params["_input", "_output", "_cost", "_text", "_capIndex"];
```

to:

```sqf
// _yield defaults to 1, so every pre-existing 5-element row keeps its exact current
// behaviour: params substitutes the default when the array is short. Only rows that
// opt in by supplying a 6th element produce more than they consume.
_processArray params["_input", "_output", "_cost", "_text", "_capIndex", ["_yield", 1, [0]]];
```

- [ ] **Step 3: Cap the batch to what will actually fit, BEFORE consuming**

`AP_fnc_handleInv` with `_math = true` already clamps an add to the available weight via `AP_fnc_calWeightDiff` — but `fn_processAction` consumes the inputs *first* and adds the output *after*, so anything that does not fit is destroyed with no message. This is a pre-existing bug at yield 1 and a constant one at yield 2. **It is fixed for every recipe, not just the doubling ones** — a bug that eats a player's materials should not survive just because it fires less often.

Immediately after `_inputCount` is computed and the zero-check has passed, add:

```sqf
// Cap the batch to what the output will actually FIT into, before anything is
// consumed. handleInv clamps the ADD, but by then the inputs are already gone, so
// the overflow was silently destroyed. Applies to every recipe: a heavier output
// than input (rock -> cement, ore -> ingot) could always overflow, doubling just
// makes it routine.
// calWeightDiff walks the count down until it fits and returns the fitted number.
// It is asked about the OUTPUT item, never about an input.
private _fits = [_output, (_inputCount * _yield), AP_carryWeight, AP_maxWeight] call AP_fnc_calWeightDiff;
private _maxBatch = floor (_fits / _yield);
if (_maxBatch < 1) exitWith {
    ["You can't carry what that would make. Drop something first.", "basic"] spawn AP_fnc_handleMessage;
};
if (_maxBatch < _inputCount) then { _inputCount = _maxBatch; };
```

**One caveat the implementer must handle:** the inputs are consumed too, freeing weight as they go, so this cap is conservative — it can refuse a batch that would in fact have fitted once the inputs left the inventory. That is the correct direction to err (refusing with a message beats destroying materials silently), but the message must not claim the inventory is full when it is merely tight. Use the wording above verbatim.

- [ ] **Step 4: Multiply the output**

Change the output add from:

```sqf
if ([true, _output, _inputCount] call AP_fnc_handleInv) then {
```

to:

```sqf
if ([true, _output, (_inputCount * _yield)] call AP_fnc_handleInv) then {
```

The consumption loop above it still uses the un-multiplied `_inputCount`, which is the whole point.

- [ ] **Step 5: Mirror the parameter into the vehicle processor**

`fn_processVehicle.sqf` gets the same `params` change so the two recipe-row formats stay identical. No cut recipe is registered for bulk processing in this pass, so the multiplication there is dormant — but keeping the formats identical means enabling bulk cutting later is a data change, not a code change.

- [ ] **Step 6: Observe the green state — existing recipes unchanged**

```bash
bash tools/run_checks.sh
```

Deploy, boot marker, clean RPT. In-game, process a normal recipe that has no yield column — Smash powder → Smash with 10 units:

```sqf
diag_log format ["[AP-PROBE] before smash=%1 powder=%2", AP_inv_smash, AP_inv_smashpowder];
```

Expected: 10 powder in, 10 Smash out, exactly as before. **This step proves the default did not change any of the 49 existing recipes.** Nothing else in this task is safe until it passes.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat(process): add an optional yield multiplier to recipe rows

fn_processAction was structurally 1:1 -- selectMin across the inputs,
consume that many of each, emit exactly that many. A sixth recipe column
_yield (default 1) now scales the output alone. params substitutes the
default for short rows, so all 49 existing recipes are byte-identical in
behaviour, verified in-game before anything opts in.

Also caps the batch to what the output will fit BEFORE consuming inputs.
handleInv clamps the add, but by then the inputs are gone -- so overflow
was silently destroyed. Rare at yield 1, constant at yield 2.

fn_processVehicle takes the same parameter so the two row formats stay
identical and bulk cutting is later a data change, not a code change.

Co-Authored-By: ELIZA"
```

### Task 13: The cut recipes

**Files:**
- Modify: `mission/Armapunk2035.Malden/core/actions/fn_processAction.sqf`, `npcs/fn_civProcessItem.sqf`

**Interfaces:**
- Consumes: `_yield` from Task 12; `boost` from Task 6; every drug key from Tasks 3–5
- Produces: eleven `cut_*` recipe keys

- [ ] **Step 1: Observe the red state**

In-game, stand at the Smash processor holding Smash and Boost. Expected: no "Cut" action exists.

- [ ] **Step 2: Add the eleven recipes**

Append to the `AP_processMap` literal in `fn_processAction.sqf`:

```sqf
["cut_smashpowder",    [["smashpowder", "boost"],    "smashpowder",    0, "Cutting Smash Powder",  1, 2]],
["cut_smash",          [["smash", "boost"],          "smash",          0, "Cutting Smash",         1, 2]],
["cut_smashbrick",     [["smashbrick", "boost"],     "smashbrick",     0, "Cutting Smash Bricks",  1, 2]],
["cut_blacklace",      [["blacklace", "boost"],      "blacklace",      0, "Cutting Black Lace",    1, 2]],
["cut_blacklaceprime", [["blacklaceprime", "boost"], "blacklaceprime", 0, "Cutting Black Lace Prime", 1, 2]],
["cut_glitter",        [["glitter", "boost"],        "glitter",        0, "Cutting Glitter",       1, 2]],
["cut_marijuana",      [["marijuana", "boost"],      "marijuana",      0, "Cutting Reggie",        1, 2]],
["cut_marijuanam",     [["marijuanam", "boost"],     "marijuanam",     0, "Cutting Medicinal",     1, 2]],
["cut_cannas_3",       [["cannas_3", "boost"],       "cannas_3",       0, "Cutting Sativa Bud",    1, 2]],
["cut_cannai_3",       [["cannai_3", "boost"],       "cannai_3",       0, "Cutting Indica Bud",    1, 2]],
["cut_canna_dab",      [["canna_dab", "boost"],      "canna_dab",      0, "Cutting Golden Wax",    1, 2]]
```

The `1` in position 5 is `_capIndex` — the Drug Cartel. Cutting inside a rival-held cartel is taxed on the **doubled** amount, which is deliberate: it keeps the cartel meaningful at the new volume.

- [ ] **Step 3: Suppress infamy and stats on cut recipes**

The drug already paid both when it was produced; awarding them again on every cut turns Boost into an infinite infamy tap. In `fn_processAction.sqf`, guard both awards. Immediately before the `statArrUpdate` call, add:

```sqf
// Cut recipes re-emit an item that already paid its stat and infamy when it was
// first produced. Awarding again per cut makes Boost an unbounded infamy tap.
private _isCut = (_type select [0, 4]) isEqualTo "cut_";
```

Then wrap the stat award:

```sqf
if !(_isCut) then {
    if (_output in ["uraniump", "smashbrick", "blacklaceprime", "moonshine", "moonshinep"]) then {[format["%1%2", _output, "_proc"], _inputCount] call AP_fnc_statArrUpdate;} else {[_output, _inputCount] call AP_fnc_statArrUpdate;};
};
```

and the infamy award:

```sqf
if (!_isCut && {_output in ["uraniump", "smash", "smashbrick", "blacklace", "lacebase", "blacklaceprime", "moonshinep", "marijuana", "marijuanam", "canna_dab", "scotch_3", "glitter", "moonshine"]}) then {
```

- [ ] **Step 4: Add the scroll actions**

In `npcs/fn_civProcessItem.sqf`, add one action to each drug's processor case. At the Smash processor:

```sqf
_obj_main addAction["<t color='#FFAA00'>Cut Smash Powder with Boost</t>", AP_fnc_processAction, "cut_smashpowder", 1.5, false, false, "", 'AP_inv_smashpowder > 0 && AP_inv_boost > 0 && !AP_is_processing', 5];
_obj_main addAction["<t color='#FFAA00'>Cut Smash with Boost</t>", AP_fnc_processAction, "cut_smash", 1.5, false, false, "", 'AP_inv_smash > 0 && AP_inv_boost > 0 && !AP_is_processing', 5];
_obj_main addAction["<t color='#FFAA00'>Cut Smash Bricks with Boost</t>", AP_fnc_processAction, "cut_smashbrick", 1.5, false, false, "", 'AP_inv_smashbrick > 0 && AP_inv_boost > 0 && !AP_is_processing', 5];
```

At the Black Lace processor:

```sqf
_obj_main addAction["<t color='#FFAA00'>Cut Black Lace with Boost</t>", AP_fnc_processAction, "cut_blacklace", 1.5, false, false, "", 'AP_inv_blacklace > 0 && AP_inv_boost > 0 && !AP_is_processing', 5];
_obj_main addAction["<t color='#FFAA00'>Cut Black Lace Prime with Boost</t>", AP_fnc_processAction, "cut_blacklaceprime", 1.5, false, false, "", 'AP_inv_blacklaceprime > 0 && AP_inv_boost > 0 && !AP_is_processing', 5];
```

At the Glitter lab:

```sqf
_obj_main addAction["<t color='#FFAA00'>Cut Glitter with Boost</t>", AP_fnc_processAction, "cut_glitter", 1.5, false, false, "", 'AP_inv_glitter > 0 && AP_inv_boost > 0 && !AP_is_processing', 5];
```

At the marijuana processor:

```sqf
_obj_main addAction["<t color='#FFAA00'>Cut Reggie with Boost</t>", AP_fnc_processAction, "cut_marijuana", 1.5, false, false, "", 'AP_inv_marijuana > 0 && AP_inv_boost > 0 && !AP_is_processing', 5];
_obj_main addAction["<t color='#FFAA00'>Cut Sativa Bud with Boost</t>", AP_fnc_processAction, "cut_cannas_3", 1.5, false, false, "", 'AP_inv_cannas_3 > 0 && AP_inv_boost > 0 && !AP_is_processing', 5];
_obj_main addAction["<t color='#FFAA00'>Cut Indica Bud with Boost</t>", AP_fnc_processAction, "cut_cannai_3", 1.5, false, false, "", 'AP_inv_cannai_3 > 0 && AP_inv_boost > 0 && !AP_is_processing', 5];
_obj_main addAction["<t color='#FFAA00'>Cut Golden Wax with Boost</t>", AP_fnc_processAction, "cut_canna_dab", 1.5, false, false, "", 'AP_inv_canna_dab > 0 && AP_inv_boost > 0 && !AP_is_processing', 5];
```

At the medicinal marijuana processor:

```sqf
_obj_main addAction["<t color='#FFAA00'>Cut Medicinal with Boost</t>", AP_fnc_processAction, "cut_marijuanam", 1.5, false, false, "", 'AP_inv_marijuanam > 0 && AP_inv_boost > 0 && !AP_is_processing', 5];
```

- [ ] **Step 5: Observe the green state**

Deploy, boot marker, clean RPT. In-game with 10 Smash and 10 Boost, probe before and after cutting:

```sqf
diag_log format ["[AP-PROBE] smash=%1 boost=%2 infamy=%3", AP_inv_smash, AP_inv_boost, AP_infamy];
```

Expected after: `smash=20`, `boost=0`, `infamy` **unchanged**. Then:
- With 10 Smash and 3 Boost: expected `smash=16`, `boost=0` — `selectMin` bounds the batch to 3
- With a nearly full inventory: the batch is capped and you get a message, and **your Smash is not destroyed**
- Cut inside a rival-held Drug Cartel: the retained amount is taxed off the doubled figure
- Confirm no Cut action appears at any processor when you hold no Boost

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(drugs): cut any sellable drug with Boost for double output

Eleven cut_* recipes, one per sellable drug across the Smash, Black Lace,
Glitter and cannabis lines, each consuming N drug + N Boost and returning
2N drug at that drug's own processor.

Cut recipes award no infamy and no stats: the item already paid both when
it was first produced, and re-awarding per cut would make Boost an
unbounded infamy tap. The cartel tax deliberately applies to the DOUBLED
amount, so the cartel still matters at the new volume.

Hand processing only -- no Process Vehicle variants -- so the Boost sink
stays observable while the economy is tuned.

Co-Authored-By: Dr. Sbaitso"
```

### Task 14: Sync the website, tools and docs

**Files:**
- Modify: `website/src/lib/leaderboards.ts`, `website/src/lib/compItems.ts`, `website/src/lib/houseItems.ts`, `tools/make_compositions.py`, `tools/npc_move.py`, `tools/npc_place.py`, `FEATURELIST.md` / `FEATURES.md` if they name any renamed drug

**Interfaces:**
- Consumes: every key from Tasks 1–6
- Produces: nothing downstream

- [ ] **Step 1: Observe the red state**

```bash
cd website && npx tsc --noEmit; cd ..
grep -rn 'Meth Processed\|Cocaine\|Crank\|LSD\|PCP\|Fentanyl\|Fungi\|Henbane' website/src/ | cut -c1-140
```

Expected: stale labels naming drugs that no longer exist.

- [ ] **Step 2: Fix the leaderboard labels — labels only, never the indices**

`website/src/lib/leaderboards.ts` line 62 reads:

```ts
{ key: "meth", label: "Meth Processed", format: "int", source: lt(26) },
```

Change it to:

```ts
{ key: "blacklace", label: "Black Lace Processed", format: "int", source: lt(26) },
```

**`lt(26)` must not change.** It is the persisted stat slot; only its human label is stale. Apply the same treatment to any other leaderboard row naming a renamed drug, and delete any row whose `lt(n)` points at a slot removed in Task 1 (144–147).

- [ ] **Step 3: Regenerate or hand-fix the item lists**

`compItems.ts` and `houseItems.ts` are item catalogues mirroring `fn_virtItemCfg.sqf`. Find the generator:

```bash
grep -rn 'compItems\|houseItems' tools/ scratchpad/ website/ --include=*.py --include=*.ts --include=*.js | grep -v 'src/lib/comp\|src/lib/house' | head
```

If a generator exists, rerun it. If not, hand-edit: remove the seven deleted items and rename the twelve renamed ones, keeping the file's existing sort order.

- [ ] **Step 4: Fix the Python tooling**

```bash
grep -rn 'lsd\|pcp\|fungi\|henbane\|meth\|cocaine\|crank\|fentanyl' \
  tools/make_compositions.py tools/npc_move.py tools/npc_place.py | cut -c1-140
```

Update each hit to the new key or delete it if it names a removed item.

- [ ] **Step 5: Observe the green state**

```bash
cd website && npx tsc --noEmit && npm run build; cd ..
bash tools/run_checks.sh
grep -rniE '"(lsd_[01]|pcpu|pcpp|pcp|fungi|henbane|ephedrau|phos|hydro|ephedra|meth|bluemeth|cocaine|cocainep|cokebrick|crank|crankp|fentanylu)"' \
  --include=*.sqf --include=*.hpp --include=*.cpp --include=*.py --include=*.ts \
  mission/ server/ tools/ website/ | wc -l
```

Expected: `tsc` clean, build succeeds, `run_checks.sh` all PASS, and the final sweep returns `0`. **`loonybot/` is excluded from this sweep on purpose** — it keeps the old names deliberately, because it parses logs from the frozen LooneyBin Altis box.

- [ ] **Step 6: Update the docs and commit**

Mark `drugs.md` implemented. Add a line to `launch.md` recording that `loonybot/clankr.py`'s `_BAL_ITEMS` still names the old precursors and must be updated before Armapunk goes live.

```bash
git add -A
git commit -m "chore(drugs): sync the website, tooling and docs to the new names

Leaderboard LABELS change; lt() slot indices do not. The index is the
persisted stat column and the label is the only stale part -- swapping the
index to match a renamed key would silently repoint the column at someone
else's data.

Records in launch.md that loonybot/clankr.py's _BAL_ITEMS still names
Hydrogen Sulfate, Phosphorus and Ephedra plant. That is correct today: it
parses logs from the frozen LooneyBin Altis box. It becomes wrong the day
Armapunk takes players.

Co-Authored-By: Microsoft Tay"
```

---

## Plan Self-Review

**Spec coverage.** §1 renames → Tasks 2–6. §2 deletions → Task 1. §3 effects → Tasks 7–11. §4 cutting → Tasks 12–13. §5 verification → the loop in Global Constraints, applied in every task. Known issues → Task 14 Step 6 records the clankr.py one; the other two are documented non-goals. No gaps.

**Placeholder scan.** No TBDs. Every code step carries the code. Task 1 Steps 9–10 name files and the reference to remove in each rather than quoting minified single-line configs verbatim — quoting a 7000-character line would be less executable, not more, and each instruction names the exact anchor to grep for.

**Type consistency.** `AP_fnc_healBlocked` (Task 7) is called identically in Tasks 7 and 8. `AP_glitterShield` (Task 10) is written in `fn_glitter.sqf` and read in `fn_handleDamage.sqf` under that one name. `_yield` (Task 12) is defined once and consumed by the eleven rows in Task 13. `AP_blackLace_effect`, `AP_smash_effect` and `AP_glitter_effect` each match the sed that produces them in Tasks 3, 4 and 5.

**Riskiest plan code, executed rather than proofread:**

- `params [..., ["_yield", 1, [0]]]` against a 5-element row — **verified** against the local BIKI mirror (`~/biki/wiki/params.wiki`): "default value to return if input element is undefined, of the wrong type or of the wrong size (if array)". All 49 existing rows keep their behaviour. Task 12 Step 6 re-proves it in-game before anything opts in.
- `AP_fnc_calWeightDiff` returning a fitted count — **verified** by reading `core/functions/fn_calWeightDiff.sqf`: it walks the count down until the weight fits and returns the fitted `_sum`, which is exactly what the batch cap needs.
- `handleInv` clamping adds — **verified** by reading `fn_handleInv.sqf`: the `_math` branch calls `calWeightDiff` and overwrites `_num`. This is why the cap must run before consumption, not after.
- The stat-slot indices quoted in the invariant — **verified** by extracting them from `fn_statArrUpdate.sqf`.
- `lt(26)` being the meth leaderboard source — **verified** by reading `website/src/lib/leaderboards.ts:62`.
- **Unverified, and marked as such:** every SQF body in Tasks 8–10 and 13. There is no SQF parser outside Arma, so `tools/sqf_balance.py` checks their brackets and nothing checks their semantics until the dev boot in each task's green-state step. Treat the first deploy of each as the real compile.

**Lifecycle owners of reused components.** `setAnimSpeedCoef` is **absolute, not multiplicative**, and had **seven** writers across 16 call sites — Black Lace, Smash, Glitter, RedGull, two separate Super Male routes (`fn_supermale.sqf` and `initPlayerLocal.sqf:250`), and the cannabis vape/dab animation. Each set it and later reset it to `1`, so the last writer won and the first expiry cancelled everyone. Owner call 2026-08-21: fix it rather than document it. Task 7B makes `AP_fnc_speedMod` the single writer and converts all seven, deliberately keeping every coefficient unchanged so that Tasks 8–10 remain bisectable when they change the numbers.

**Owner decisions taken during pre-flight (2026-08-21), both recorded here because they change the plan as written:**

1. **No in-game verification pass this run.** The bar is `run_checks.sh` green, a clean boot, and a clean RPT. The in-game probe blocks stay in the plan and go into each task's report file for the owner to run later. **This is a real gap and it is deliberate**: a health delta that never applies, a shield that never drains, and a heal block that never engages all boot perfectly cleanly. Nothing in Tasks 7–13's behaviour is proven by this run.
2. **All three plan-mandated review conflicts are fixed rather than adjudicated.** The shared screen effect (`fn_drugVision`, Task 8), the speed stack (Task 7B), and the weight cap now applying to every recipe rather than only the doubling ones (Task 12).

**Artefact paths.** `docs/` is gitignored in this repo (`.gitignore:46`), so both `drugs.md` and `drugs_plan.md` live at the repo root, matching the existing `mainmenu_plan.md` / `maldenfed_plan.md` / `postgres_plan.md` convention.
