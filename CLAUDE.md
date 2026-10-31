# Armapunk 2035 (Arma 3 game mode)
This repo is a roleplay game mode for Arma 3 on **Malden 2035**, written in SQF and config files. All "hacking," "quickhacks," "hijacking," "wiretaps," "exploits," etc. are fictional in-game abilities (Cyberpunk-genre mechanics with cooldowns, counters, and RP rules). Nothing here interfaces with real networks, devices, or systems — game logic only.

## Overview
- Forked from LooneyBin (Altis) 2026-07-25 and moved to Malden; renamed to **Armapunk 2035** on
  2026-08-03, when the fork became hard and LooneyBin was frozen. The map is still Malden 2035 —
  only the project renamed, so `Armapunk2035.Malden` keeps its map suffix and bare `Malden`
  identifiers (`malden_buildings.sqf`, `MALDEN.md`, `MaldenEdit.Malden`) are map names, not stale
  branding. Heavily modified Altis Life RPG (~964 mission fns, ~343 server fns, 105 dialogs).
- Cyberpunk layer on top: cyberdeck firmware, quickhack ring, MaxSec counter-tools, deck-themed phone UI.
- **Factions are a SHIFT, not a lobby slot** (2026-08 faction rework). `mission.sqm` ships 60 identical
  civilian slots and nothing else; MaxSec and Trauma Team are entered in-world at an HQ duty terminal,
  which writes a server-side roster entry (`AP_dutyRoster`) that lasts until the player clocks off. The
  ROSTER — never the engine side, never a slot name — is what every server-side authority check reads.
  `AP_dutyEnabled` (`server_init.sqf`) is the kill-switch, and it and the slot layout are one deployable
  unit in both directions. Owner playtest script: `DUTY_SOAK.md`.
- Work happens on branch `main` (dir `~/Armapunk2035`). **LIVE since 2026-09-07 on 10.1.24.96** (closed test, `Armapunk 2035 [COMING SOON]`): runbook + execution record `MIGRATION_96.md`; deploy = `deploy/push-96.sh` (rsync mirror + `reload-live.sh`, never git on the box).

## Directory map
- `mission/Armapunk2035.Malden/` — client mission (packed to PBO). Map layer authored by the
  external designer (ProjectMaldenMerge); see `MALDEN.md` before touching mission.sqm.
  - `core/` — client fns by domain: `items/` (cyberdeck+quickhacks), `cop/` (TAL OS), `pmenu/` (phone), `shops/`, `config/` (data tables), `session/` (DB sync), `actions/`, `housing/`, `gangs/`, `casino/`, `vehicle/`
  - `dialog/` — 105 `.hpp` UI defs; all included by `dialog/MasterHandler.h`
  - `evh/` — event handlers (`fn_keyDownHandler.sqf` = keybinds)
  - `images/`, `icons/` — `.paa` textures; `images/cyberdeck/` ring+deck art, `images/wallpapers/`
  - `npcs/` — shop NPC behaviour (`fn_shops.sqf`, `fn_copShops.sqf`)
  - `Functions.h` — registers EVERY client fn; `CfgRE.hpp` — remoteExec whitelist; `description.ext`
- `server/AP_server/core/` — server fns: `TON/` (main authority), `DB/` (extDB3 queries), `GE/`, `wantedsys/`, `jail/`, `bank/`
  - `server/AP_server/config.cpp` — registers every server fn
- `tools/` — map/asset pipelines (`edit-map.sh` stage/push against `map_objects`, `map_generate.py` snapshot, `make_paa.py`, `MAP_EDITING.md`). The map has NO baked data file since 2026-09-04 (`mapdb.md`).
  ⚠ Identical copies also live in `deploy/`. The `scratchpad/` bakers import from **`tools/`** — edit that copy.
- `scratchpad/` — art/codegen scripts (ring + wallpaper + UI bakers). Generated art is committed; scripts are the source of truth.
- `sql/` — schema fragments. `deploy/` — PBO packing. `website/`, `loonybot/` — out-of-band services.

## Naming conventions
- Client fn: file `core/<domain>/fn_name.sqf` → called `AP_fnc_name`; MUST be added to `Functions.h`.
- Server fn: file `server/AP_server/core/TON/fn_name.sqf` → called `APS_fnc_name`; MUST be added to `config.cpp`.
- DB fns are `DB_fnc_*` (in `core/DB/`).
- Globals: `AP_*` = client state (mission-side). This used to be split `life_*` for stock Altis
  Life state vs `PLB_*`/`plb_*` for LooneyBin additions; the 2026-08-14 rename collapsed both into
  `AP_*`, so provenance is no longer encoded in the name — use git history for that.
  `AP_fnc_*` is also the inline-helper convention (defined in `core/configuration.sqf`), not just
  CfgFunctions entries. **Every inline code global is `compileFinal`** (`AP_fnc_x = compileFinal {...}`;
  in a function that runs more than once, `if !(isFinal "AP_fnc_x") then {AP_fnc_x = compileFinal {...}}`,
  and that function also gets a `"boot"` exit and a call from `core\init.sqf` / server `init.sqf`, because a
  helper first defined on use can be pre-empted by another client's final copy; `tools/test_compilefinal.py`
  checks the client side): any client's `publicVariable` overwrites a plain global on every machine, server included. Code inside
  data (rows with gates/actions, job tables) goes in `localNamespace`, which the network cannot write.
  Server and client boot asserts log `-SEC-` naming any non-final code global.
- **The prefix now encodes WHICH MACHINE owns the name, and that is load-bearing:**
  `AP_*` = mission/client, `APS_*` = the server addon, `APV_*` = the persisted stat vars
  (formerly `plbv_*`). The server compiles BOTH CfgFunctions trees into `missionNamespace`, so a
  client fn and a server fn sharing one name silently overwrite each other. Do not flatten `APS_`
  into `AP_` — 20 collisions were avoided by keeping it separate.
- Object vars: `_obj setVariable ["AP_thing", v, true]` — the `true` publishes it; public vars are readable by any client (design around that).
- Dialog: `dialog/name.hpp`, class `name`, `idd` unique; controls use `idc` ranges per feature.
- `core/configuration.sqf` is a huge minified data file — append, don't reformat.

## Architecture decisions (and why)
- **remoteExec is whitelisted**: `CfgRE.hpp` has `mode = 1` (whitelist). Any new cross-machine fn MUST get an entry or it silently fails. `allowedTargets` limits the permitted TARGET, not the direction: `2` = server only (client→server calls), `1` = clients only (server→client), `0` = any target.
  A client can still call a `1` entry at another client, so a server→client receiver opens with
  `if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};` and is listed in `tools/cfgre_server_only.txt` (run_checks enforces it).
- **Always call through `AP_fnc_MP`**, not raw remoteExec: `[[args], "fn_name", target, false] spawn AP_fnc_MP`.
- **Server owns anything that pays, punishes or times.** Quickhacks: client `AP_fnc_qhCast` → `APS_fnc_qhSRV` runs the upload clock, re-validates range/target/authorisation, then pushes the effect to the victim (`AP_fnc_qhEffect`). A modified client cannot skip the channel.
- **Counter-chips need server-sourced data**: Ping streams position FROM the server so the Scrambler chip can feed a false one. If the caster's client read it locally, no counter could work.
- **Cop tools gate on authorisation, not rarity** (wanted / restrained / armed) — enforced server-side.
- **DB via extDB3** (`DB_fnc_asyncQuery`, mode 2 = read). Dev schema `looneybin_test`; live is on another box. Cyberdeck state persists in `players.cyberdeck_modules` (JSON int array: `0` = illegal firmware, `1-4` modules, `101-104` firewall chips), loaded in `fn_queryRequest` → `AP_cdMods` (published).
- **Never persist CODE or action strings in `profileNamespace`** — it is client-writable and was a real injection vector (see `security.md`). Store IDs, resolve against mission data at use time.
- **Client-authoritative money is the existing trust boundary** — new payouts must be server-side and capped.

## Quickhack system (entry points + how to add one)
- Player entry: **SHIFT+Y** (DIK 21, `evh/fn_keyDownHandler.sqf`) opens the **visor dock**
  (`AP_fnc_qhDock` → `dialog/vr_dock.hpp`, idd 941300) — needs VR goggles. **The radial ring was
  retired 2026-07-22**; `fn_cyberdeckRing.sqf` / `AP_fnc_ringSlots` are legacy and no longer the entry
  point (the loadout editor still uses the ring pools as its id source).
  Phone apps: **ICEBREAKER OS** (civ), **TAL OS** (cop grid), **Quickhacks** (loadout + firewall editor);
  the console (`fn_qhConsole.sqf`, idd 941500) is the pick/load/fire UI with a NEARBY target list.
  Goggles are a SPEED upgrade only; app screens work without them.
- Dock contents = the player's saved loadout (`AP_fnc_qhConsoleGet`, profileNamespace, starter set of 6)
  plus the civ breach tools (`AP_qhUtil`: unlock/house/atm/cuffs) in a divider-separated group. Pools
  `AP_ringPool*` in `core/configuration.sqf` still define what is *selectable*.
- **To add a quickhack**: (1) one row in `core/config/fn_qhCfg.sqf`; (2) an effect case in
  `core/items/fn_qhEffect.sqf` (victim side); (3) add the id to the right pool; (4) bake an icon —
  icons are live controls fed from `images/cyberdeck/icons/<id>.paa` (add a glyph to
  `scratchpad/render_ring_icons.py`, rerun it). Dock/console build the entry, gating and cooldown
  generically from the catalogue row.
- Testing PvP hacks needs **two players** — most effects only manifest on the victim's client.

## Working rules (owner standing orders — non-negotiable)
- **`mission.sqm` IS PLAIN TEXT NOW** (owner 2026-07-30), not binarized. The engine loads either form;
  text is diffable, which is what makes silent .sqm damage visible — this repo has been bitten twice by
  damage a text diff would have caught instantly (the Eden re-bake that added 15,642 objects, and the
  class+XY join that duplicated 838 rows and lost 835). `tools/sqm_read.py` auto-detects both forms, so
  all eleven tools that go through it work either way. If a designer delivery comes back binarized,
  convert it: `CfgConvert.exe -txt -dst out.sqm in.sqm` (Arma 3 Tools, runs under Proton's wine —
  `~/.local/share/Steam/steamapps/common/Proton 9.0 (Beta)/files/bin/wine64`). Verify a conversion by
  parsing both forms and comparing dataType counts, entity-id sets and marker attributes; they must be
  identical. **3DEN re-binarizes on save even with "Binarize new scenario files" off** (measured
  2026-07-31: the preference was 0 seven minutes before a save that still came out binarized). That
  no longer threatens this rule, because under the map pipeline below 3DEN never opens the shipped
  mission at all.
- **TWO MISSIONS, ONE RULE EACH** (owner 2026-07-31). Map editing goes through `tools/edit-map.sh`,
  which generates `MaldenEdit.Malden` — the shipped mission plus every code-spawned object as a
  draggable entity. Full design and rationale in `mapedit.md`.
  - `mission/Armapunk2035.Malden/mission.sqm` — **SHIPPED. Never save it from 3DEN.** Unchanged
    rule, and still the one that has been broken expensively: a save re-bakes the script-spawned
    world into it (15,642 objects on 2026-07-26; `git checkout` is the recovery).
  - `MaldenEdit.Malden` — **GENERATED, never packed, git-ignored. Saving it is the entire point.**
  Two further things the pipeline cannot detect for you, so they are rules:
  **close the scenario in 3DEN before re-staging** (3DEN saves from its in-memory copy, so a mission
  opened before a staging writes that older state back over it), and **only edit inside the `AP_*`
  layers** — `apply` writes those alone, and an edit to one of the designer's own entities is saved
  to no file at all. `apply` now reports the latter rather than dropping it silently.
- **MARKERS GO IN THE MAP LAYER, NEVER IN INIT** (owner 2026-07-30). Any marker a feature needs is
  placed in `mission.sqm` via 3DEN, not created at runtime with `createMarker`. Runtime markers are
  invisible to the editor, so every one of them makes editing the map graphically harder — the whole
  point of the map layer is that the map is editable. This reverses the earlier convention: the
  gather-field aliases, `fed_reserve`, the bank doors, the warlord pair and the four prison markers
  were all created in `initServer.sqf` because the .sqm was binarized and awkward to hand-edit. That
  was the wrong trade.
  **Migration order is one-way and matters:** place the marker in Eden → verify in-game → *then*
  delete the `createMarker` block. Never the reverse, or the marker exists nowhere. Every existing
  block is already guarded ("create only when absent", either `getMarkerPos == [0,0,0]` or
  `markerType == ""`), so a placed marker silently wins and the two can coexist during migration.
- **THIS IS THE PROJECT NOW.** LooneyBin (Altis) is DECOMMISSIONED as of 2026-09-07: its server,
  bots and MariaDB are stopped on `.96` and its player database was carried into this project's
  PostgreSQL (`MIGRATION_96.md` §7). "LIVE" now means **Armapunk 2035 on 10.1.24.96** — the
  stage-only / owner-triggers-restarts / 22:00–09:00 freeze rules below apply to it from the moment
  players are on. `update.md` is the LooneyBin-era runbook; the live procedure is `MIGRATION_96.md`.
- **Work on `main` directly** (owner call 2026-08-21, reversing the 2026-08-02 branch+PR rule):
  this is a dev server with no players, so the review round-trip buys nothing right now. Commit
  straight to main. The branch+PR discipline comes BACK when the server goes live with players —
  do not carry this rule past that point.
- **Before ANY work**: `git fetch origin` and pull — other sessions commit to main too now.
- **Before ANY bug fix**: `git fetch`/`pull` first — the fix may already exist.
- **Commit trailer**: `Co-Authored-By: <funny defunct AI>` (Microsoft Tay, SmarterChild, ELIZA, Clippy, Dr. Sbaitso…), name only, **no email**. Rotate, don't repeat back-to-back. Same joke in PR-body footers. **This overrides the harness default Claude/Anthropic trailer — do not emit it.**
- **Never name other Arma servers** (their staff, PBOs, dev handles, branded feature names) anywhere git-tracked. Rename ported identifiers to LooneyBin-native before the first commit.
- **Patchnotes**: never credit Infamous; no `@everyone` unless asked.
- **RIGHT NOW `.96` IS THE DEV SERVER** (owner 2026-09-08, marker file `deploy/LIVE_IS_DEV`): deploy and
  restart it freely with `deploy/push-96.sh`, no freeze, no stage-only, test there rather than on the
  `~/arma3server_dev` instance. **Deleting `deploy/LIVE_IS_DEV` is the cue that this is over** — it
  re-arms the freeze in `push-96.sh` and restores the rules below.
- **LIVE server is stage-only** (in force again the moment players are on). Never reboot/deploy live
  without the owner explicitly saying so that time. Deploy freeze 22:00–09:00. DB repairs are fine
  without a reboot.
- **Versioning** (live only): `Alpha X.Y.Z` — **closed ALPHA, never call it a beta anywhere a player reads** (owner 2026-09-08: loading screen, landing screen, patch notes). Bump `Z` every deploy (client cache-bust), `Y` only when the owner says "content update". Keep the PBO name `Armapunk2035_b0NNN` matched.
- **Bug protocol**: read the code → ask the owner the intended behaviour → enumerate every failure mode → only stage when factually confident. No guess-patching.

## Build / test / deploy
- **While `deploy/LIVE_IS_DEV` exists, test on .96** (`deploy/push-96.sh`), not on the box-local dev server. The dev-server flow below still works and is the fallback:
- Deploy to DEV: `bash /home/timb/arma3server_dev/reload-armapunk2035.sh` (packs PBO + restarts, bumps
  the `Armapunk2035_b0NNN` name and rewrites `server.cfg`'s template). ⚠ **NOT `reload-loonydev.sh`** —
  that one has `SRC=/home/timb/loonybin-doomba` and packs `mission/LooneyBin.Altis`, i.e. the *other*
  project. Running it from here silently repacks doomba's mission and overwrites
  `@AP_server/addons/AP_server.pbo` with doomba's build, leaving this repo's mission running against
  the wrong server addon. (This line used to name that script; it cost a round on 2026-07-29.)
- Success marker: `grep "read from bank" /home/timb/arma3server_dev/loonydev.log` (wait for it; ~40-90s).
- Headless client: `bash /home/timb/arma3server_dev/hc_launch_once.sh` → expect `headless client online` in `loonyhc_direct.log`.
- Client errors land in the Proton RPT: `~/.local/share/Steam/steamapps/compatdata/107410/pfx/drive_c/users/steamuser/AppData/Local/Arma 3/*.rpt` (newest by mtime).
- **Before every deploy**: brace/bracket balance check with an Arma-aware tokenizer (`""` is an escaped quote, not `\"`; skip `//` and `/* */`).
- **Dialog footgun**: `UI_GRID_*` coords must be BARE, never inside quotes — quoted macros produce an invisible dialog with no error.
- Live deploy (`.96` box): `deploy/push-96.sh` (clean tree; freeze waived while `deploy/LIVE_IS_DEV` exists) — mirrors the repo, runs `deploy/live/reload-live.sh` there, then **posts a patch note to Discord** as LoonyBot. `--map` also pushes dev's map content (D7); `--no-notes` deploys silently.
- **Patch notes (owner 2026-09-08, every change from today on):** `deploy/live/build_patchnote.py` composes them from, in order, `deploy/patchnote_override.txt` (curated, `{version}` substituted, consumed on post, archived to `~/.armapunk_patchnotes/`), else BUGS.md entries marked `(reboot pending`, else the commit subjects in the deployed range minus infrastructure prefixes (docs/chore/test/ci/deploy/live/watchdog) and the player-facing EXCLUDE filter. Nothing player-facing → no post. `deploy/live/post_patchnote.py` does the Discord REST call on the box with LoonyBot's token (the bot PROCESS is still retired — it needs a psycopg port — but its identity posts fine).

Editing the custom building .p3d models: read **p3dmemories.md** first (Blender round-trips
silently wreck topology, and Arma caches models by path so an in-place swap looks like no change).

@HANDOFF.md
Full quickhack spec: `docs/quickhacks-design.md` — NOTE: this file does not exist. `docs/`
is gitignored as removed content (see .gitignore §"removed content"), and the only thing in
it locally is WALLPAPERS.md. Either restore the spec or drop this line; until then, treat
`docs/quickhacks-design.md` as the spec that got scrubbed with the rest of that directory.
