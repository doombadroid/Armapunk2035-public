# LooneyBin Altis Life — Project Memory

> **REBRANDED 2026-06-03: in-code "Asylum" → "Project Loonybin".** Identifiers `ASY_`→`AP_`, `asyv_`→`APV_`,
> `ASYUI_`→`PLBUI_`, `Asylum`→`Loonybin`; CfgFunctions tag `ASY`→`PLB` (so `ASY_fnc_*` is now **`AP_fnc_*`**).
> The "Mental Asylum" heist → **"Loony Bin"** (`mentalAsylum*`→`loonyBin*`). If older notes here say `ASY_`/`asyv_`,
> read them as `AP_`/`APV_`. Pre-rebrand backup: `~/looneybin-backup-pre-rebrand-20260603-154115.tar.gz`.
> Deferred rebrand items (asset filenames, mission.sqm marker, Asydidas) are tracked in **`REBRAND-TODO.md`**.

Self-hosted **Arma 3 Altis Life** server (orig. Asylum). Frankenstein of a **2017 leaked serverside** (`server/AP_server`) + a **2020 deobfuscated client** (`mission/LooneyBin.Altis`). A `APS_fnc_*` adapter layer bridges 2020 client calls → 2017 server fns; **many adapters shipped as broken stubs (log-only) or passthroughs to the wrong 2017 fn** — the bulk of the work is rewriting them self-contained.

DB: **extDB3 → MariaDB**, docker container `looneybin-db`, all creds `looneybin`, db `looneybin`, port 3306.

---

## Operations

**Reboot** (repacks BOTH PBOs from source via `deploy/pack_pbo.py`):
```bash
cd "/home/timb/Documents/LooneyBin Altis Life"; pkill -x arma3server_x64; sleep 1; bash deploy/run-boot2.sh > /tmp/lb_boot.log 2>&1 &
```
- READY marker in console.log: `::LooneyBin Server:: READY`
- console.log: `$HOME/arma3server/profiles/console.log`
- Mission PBO out: `$HOME/.local/share/Steam/steamapps/common/Arma 3 Server/mpmissions/LooneyBin.Altis.pbo`
- Client RPT (Proton): `~/.steam/steam/steamapps/compatdata/107410/pfx/drive_c/users/steamuser/AppData/Local/Arma 3/*.rpt`
- DB query: `docker exec looneybin-db mariadb -ulooneybin -plooneybin looneybin -e "..."`

**Testing constraints:**
- User CANNOT paste into Arma 3 (Linux/Proton). Debug = instrument code (`diag_log`) + read RPT/console.log, OR make DB changes directly.
- Remote friends (player101, player105, Prime) on other machines — can't read their client RPTs.
- Communication: **CAVEMAN MODE** (terse). Code/commits written normal.

---

## extDB3 / DB gotchas

- **Multi-thread reorder**: `extdb3-conf.ini` has `Threads=0` (multi) + `maxSessions=-1`. Two async **mode-1** (fire-forget) queries on the **same row** can execute OUT OF ORDER → `DELETE`+`INSERT` of one row vanishes. **RULE: atomic `REPLACE INTO` / `INSERT … ON DUPLICATE KEY UPDATE` / `UPDATE`; never DELETE+INSERT the same logical row as two mode-1 queries.**
- **`DB_fnc_asyncQuery`** (`server/AP_server/core/DB/fn_asyncQuery.sqf`): `[q]`=mode1 (write, returns true); `[q,2]`=mode2 (blocks, returns first row); `[q,2,true]`=all rows `[[col,col],…]`. Logs `SQL Query: %1`. Internally `call compile`s the whole extDB3 result; result `[status,[rows]]`, status 0 = error (logs `extDB3: Protocol Error … MariaDBQueryException`).
- **mres codec** (`core/DB/fn_mresArray` + `fn_mresToArray`): encoder = `str(str(x))` then char `34("`)→`96(backtick)`, **keeps the outer quotes**. Decoder = `96→34`, then **re-wraps in quotes + compiles → returns the `str(x)` STRING**; the caller must compile AGAIN to get the value.
  - mresToArray param filter is `[""]` → a **plain number returns `[]`**. Store numbers as quoted strings, e.g. prestige `"1000000000"`.
  - asyncQuery call-compiles the result, so a text column's **own outer quotes act as string delimiters** → SELECT mres columns (gear/vinv/loadout) **UNQUOTED**; wrap plain varchars that would compile as a bareword/float (uid, name, worldspace, gang) in **`QUOTE(col)`**.
- **`_dec` helper** (queryRequest / receiveHouses / fetchLoadouts):
  ```sqf
  _dec = { params[["_v","",[""]]];
    if(isNil"_v"||{_v isEqualTo ""}||{_v isEqualTo "NULL"})exitWith{[]};
    private _a=[_v] call DB_fnc_mresToArray;
    if(typeName _a=="STRING")then{_a=call compile format["%1",_a]};
    if(isNil"_a")then{_a=[]}; _a };
  ```
- **Encode-for-SQL**: `(([x] call DB_fnc_mresArray) splitString "'") joinString "''"` (mres + escape single quotes).

---

## Networking / remoteExec

- **`AP_fnc_MP`** (`core/functions/network/fn_MP.sqf`): `[params, fnName, target, isPersistent, isCall] spawn/call AP_fnc_MP`. Target: `false`→server, `true`→all clients, object→that client, `2`→server, `-2`→all-but-server, side, group. **`spawn` does NOT guarantee remoteExec order — use `call` for ordered sequential sends to one target** (this bit the loadout fetch: holder vs requested-flag race).
- **`CfgRE.hpp`**: `Functions mode=1` (whitelist), `Commands mode=0` (blocked). `allowedTargets`: 0=any, 1=server-only target, 2=clients-only target. **Server is EXEMPT from filtering** (can remoteExec anything) → server→client callbacks should be `allowedTargets=2`, not 0.
- **`fn_netSetVar.sqf`**: generic client-var setter with `_approvedVars` whitelist; requires `remoteExecutedOwner==2` (server) to set. Used to push `AP_loadoutHolder`/`AP_loadoutRequested` server→client.

## Recurring bug classes (adapter migration)

- **ownerID→owner**: 2017 `_unit getVariable["ownerID",-1] publicVariableClient` → -1 (dropped) on 2020 units. Use `owner _unit`.
- **KRON_Replace** is mission-only (undefined on server) → sanitize names natively `(_s splitString "\'""") joinString ""`.
- **arg-order drift**: 2020 client args ≠ 2017 fn params (e.g. `handleJail [cop,offender,flags]` fed into 2017 `jailSys [offender,spawn,release]` → jailed the cop).
- **stub adapters**: log-only `APS_fnc_*` (createItem, fetchLoadouts, handleLoadouts, wantedAdd-passthrough…). Rewrite self-contained.

---

## Key UIDs & DB grants

- **Owner/dev: `76561190000000001`** (admin5, cop7, medic6) — the only retained hardcoded UID after the purge; sole debug-console UID.
- **player101: `76561190000000008`** (DB-granted admin4/cop7/medic6; no hardcoded UID).
- **Prime: `76561190000000009`**, **player105** — testers.
- All 27 foreign Asylum-staff UIDs were stripped (debug console, super-taze, dev icons, titles, loot skins, winners).

**DB grant procedure (IMPORTANT):** stats load on connect (`requestReceived`); a live client **flushes its values periodically + on disconnect**, overwriting DB grants. To grant reliably: **player OFFLINE** (or in lobby pre-spawn) → set DB → player connects → loads → their client then flushes the new values so it sticks. A naive relog can clobber (disconnect-flush writes old values first).
- `players_global`: `adminlevel, donorlevel, coplevel, copretired, mediclevel, honor_exp, honor_talents`.
- `players` (per-instance): `cop_gear, cop/civ/med_licenses, civ/cop/med_talents` (mres text), `civ_exp/cop_exp/med_exp` (bigint), `prestige` (mres text → store `"N"`), `infamy_exp` (bigint), `infamy_talents`.
- **Talent formula** (`fn_calTalents`): points from `AP_side_exp` tiers, **max 28 at exp ≥ 14200**, capped per side (civ 20 / cop 20 / medic 16). So `cop_exp ≥ 14200` maxes cop talent points. Prestige/infamy/honor use stored points directly.

---

## Subsystems

### Wanted / jail (rewritten this session)
- Wanted level lives in OFFENDER's client var **`A_stats_crimes`** (index 0 = total bounty), mirrored public as **`ga_wantedAmt`**. `A_stats_crimes` loads from `requestReceived` param 16 (persists in the player blob). **`AP_fnc_wantedListAdd`** is the ONLY writer (crimeID 1..80 = config index into A_stats_crimes + getChargeValue; crimeID **999 = clear all**).
- `APS_fnc_wantedAdd` (server) **relays** `[crimeID,uid,amount]`→`AP_fnc_wantedListAdd` on the offender's client + maintains `AP_wanted_list` `[name,uid,[crimeIDs],bounty,jail]` for the cop Wanted menu. `handleJail`=jail the offender (not the cop). `wantedRemove`=clear list+`AP_restrained_players`. `setJail`=add uid to `AP_restrained_players` (combat-log re-jail, read at `fn_query:217`). `wantedPardon`=clear offender via `wantedListAdd 999`.
- `AP_fnc_index` = `_array findIf {_find in _x}` (matches uid anywhere in entry). `wantedBounty` reads `AP_wanted_list[id] select 3` = bounty (arrest reward).

### Charges
- Config in BOTH `core/config/fn_wantedChargesConfig.sqf` (client) AND `core/TON/fn_wantedChargesConfig.sqf` (server) — **must stay in sync**. Row `[id,name,bounty,jailTime,isCapital,isManual]`; `isManual=true` (index 5) → shows in cop crimeCharge menu. `AP_totalCrimes = 1 + getAmountOfCharges`. Charges applied **manually** by cop. Added **#81 "Possessing Illegal Firearm Accessories"** (2000/60/manual).

### Loadouts
- DB `loadouts(id, pid, side, slot, name, gear, currency)`; `slot` holds client uniqueID; `gear` = mres `[type,name,loadout,virtualInv,skins]`.
- `APS_fnc_fetchLoadouts` (server): SELECT → 6-slot `AP_loadoutHolder` → push via `netSetVar` (holder THEN requested, **`call` not spawn**). `APS_fnc_handleLoadouts`: mode 1=delete / 2=insert / 3=atomic update. Both were stubs (menu hung). Asylum+ slot lock removed (`loadoutMenu` `_subscriber=true`). Holder entry `[uniqueID,type,name,loadout,virtualInv,skins]`, 6 slots, empty `[]`.

### Shops
- Weapons: `core/config/fn_weaponShopCfg.sqf` — `[class,displayName,price,[shopIDs],condition]`. Shop IDs: `rebelwep, police_weapons, srt_weapons, bounty, skiptracer, turf, gun, huntingwep, med_basic, genstore, gas, delivery`.
- Addons (mags/optics/**suppressors**): `core/config/fn_weaponAddons.sqf` — per-shop `[class,displayName,price]`. Filtered per selected weapon's `compatibleItems` (`weaponShopSelection:59`); entries with no displayName are skipped (so a bad classname can't crash the shop). Added suppressors @ $10k: rebel = coloured cans + 3 black exceptions; cop = black cans.
- Vehicles: `core/config/fn_vehicleConfig.sqf` — row `[class,"",[sides],[shops],copGate(4),medicGate(5),donorGate(6),prices…,[talents](11),[colors]]`. `getVirtCap`=index 10, `getPhysCap`=index 12. `prepareVehicle` sets `ga_vcap=getVirtCap` on buy/garage-pull (spawned async).

### Illegal items / search
- `Config_physWeights.hpp` (`CfgWeights`): base classes `Optic/Gun/Mag_OneWeight_NI` (legal) vs `_IL` (`illegal=true`). Flag a class illegal via `class X:Optic_OneWeight_IL{}`. Virtual illegal items via `AP_fnc_virtItemCfg "getIllegalItems"`.
- Cop search `fn_copSearch` (displays), seize `fn_seizePlayerIllegal`. **Charges are manual.** 19 suppressors flagged `_IL` this session.

### Gather devices
- Tempest device = `O_Truck_03_device_F`; `fn_deviceMine.sqf`. Tractor = `fn_tractorMine.sqf`. Gather caps at `ga_vcap` (mres weight in `ga_vinv=[items,weight]`). Storage system (`openInventory/storeInventory/refreshInventory`) defaults `ga_vcap` to **100**; deviceMine had a stray **900** default → over-gather when ga_vcap unset; aligned to 100.

---

## Fixes applied (this session, all live unless noted)
1. **Xi'an disarm** (`fn_clearVehicleAmmo`): empty pylons + `setVehicleAmmo 0` for `O_T_VTOL_02_*`.
2. **Wanted/jail** (5 server fns) — see above.
3. **Item drops**: `APS_fnc_createItem` implemented (was stub) — spawns `Land_Suitcase_F` with `ga_droppedItems=[[shortName,amount],…]`, self-cleans (empty/30min). Fixes manual + death drop + login bonus/chop tree/xmas.
4. **Vehicle repair** (`fn_repairTruck`): measure distance from player START pos, not the (rolling) vehicle.
5. **Loadouts**: fetch/handle implemented + Asylum+ unlock + `spawn→call` ordering fix. **Decode round-trip CONFIRMED** (`rows=1 filledSlots=1`). **Cop-save fix** (`fn_getLoadoutPrice`): it returns -1 on ANY item with no shop price → `saveLoadout` silently bails; MaxSec standard-issue gear (`H_Watchcap_blk`, `G_Bandanna_aviator`, `U_Rangemaster`, `V_Rangemaster_belt`, `V_tacvest_blk_police`, `H_Cap_police`) is issued/sold-nowhere → now exempted (treated free).
6. **Hardcoded UID purge**: 27 foreign UIDs stripped; debug console owner-only; super-taze dead.
7. **Tempest gather cap** (`fn_deviceMine` 900→100).
8. **Suppressors feature** + charge #81 (illegal firearm accessories).
9. **DB grant**: Prime prestige `"1000000000"` + `cop_exp=50000`.
10. **Heli armor** (`evh/fn_handleVehicleDamage.sqf`): small-arms damage ×0.15 (~6.7× rounds, rotor was <1 mag) for Huron `B_Heli_Transport_03_unarmed_F` / Ghosthawk `B_Heli_Transport_01_F` / Mohawk `I_Heli_Transport_02_F`; RPG/PG7 left at full. NOTE: the EVH's `_heavyVehicles` list is **dead code** (defined, never used) — bullet damage was unscaled. Tune the `0.15`.

## Pending / known issues
- **CfgRE RCE close-out — DEFERRED to before PUBLIC LAUNCH** (fine for private testing): remove `BIS_fnc_debugConsoleExec` (`CfgRE.hpp:22`, full client RCE, nothing uses it); flip the LooneyBin callback block `allowedTargets 0→2` (`requestReceived, uC, GEMenu, KBW_fnc_GEMenu, gangGarageMenu, vehicleGarageMenu, handleHouse, KBW_fnc_addWeapon`) + add `if(remoteExecutedOwner!=2)exitWith{}` to `uC`(client money-setter)/`KBW_fnc_addWeapon`(free-weapon)/`requestReceived`. Also `unsafeCVL=1` in `description.ext`.
- **`LB_LOADOUT_FETCH` diag_log** still in `server/.../TON/fn_fetchLoadouts.sqf` — decode now confirmed working, safe to strip out.
- **Vehicle damage**: `evh/fn_handleVehicleDamage.sqf` is the per-vehicle HandleDamage EVH. Scales collision (wheel ×0.15 / body ×0.35), fuel `palivo` /3, mini_Grenade →0, domSafezone →0, APC+PG7 →5000. Heli armor scaling added here. `_heavyVehicles` list = dead code.
- **Pre-existing DB `MariaDBQueryException`s at boot** (NOT ours, fixable later): `votes`, `gangs` (SELECT … FROM gangs), `vehicle_mem`, `exchange`. Plus **topWealth** name error (`SELECT p.name … ORDER BY wealth` returns unquoted names → bareword compile fail; needs `QUOTE()`).
- Admin model verified sound (DB-driven, `__SETCONST__` immutable `AP_adminLevel`, SpyG anti-tamper). `receiveMoney` guarded. Houses persist (earlier fix).
- Watch: money flush can save `atm=0` mid side-switch. `vehicleShopMenu` fragility: one bad class → "Zero divisor" breaks the whole shop.

---

## Session 2026-06-03 — rebrand, loonybot, drone, more

### In-game rank schemes (VERIFIED from code + live DB — don't guess)
- **`AP_adminLevel`** (`__SETCONST__`, from `players_global.adminlevel`): **3 = admin, 4 = developer, 5 = owner**, 2 = mod (admin-menu/ESP tier), 1 = trial, 0 = none. Proof: `fn_requestReceived` `_isAdmin = >=3`; `fn_onPlayerKilled` `4→"developer", 3→"admin"`; live DB has staff (staffA/staffB/staffC) at **4** and owner (steamuser) at **5**. NB developer (4) is **above** admin (3).
- **`AP_medicLevel`** (from `players_global.mediclevel`): emr1, emt2, **aemt3**, para4, asstchief5, chief6. **AEMT+ = `>= 3`**.
- `AP_copLevel`: cadet1..chief7.

### Asylum → Project Loonybin rebrand (BIG)
- Scripted, anchored replace (not blind substring — `easy`/`Speakeasy` protected). 331 files, ~3000 edits. Rules: heist `mentalAsylum`→`loonyBin` + `Mental Asylum`→`Loony Bin` FIRST, then marquee display phrases→"Project Loonybin", then prefixes `ASYUI_`/`ASY_`/`asyv_`/`_asy_`, `tag="ASY"`→`"PLB"`, then word `ASYLUM`/`Asylum`/`asylum`→`LOONYBIN`/`Loonybin`/`loonybin`. Asset paths (`*.paa/.jpg/.ogg/...`) + the sqm marker `"jail_marker_asylum"` were **protected** (left intact).
- **3 code files renamed** to match their now-renamed references (CfgFunctions maps class→`fn_<name>.sqf`; #include paths): `fn_mentalAsylum.sqf`→`fn_loonyBin.sqf`, `fn_mentalAsylumSRV.sqf`→`fn_loonyBinSRV.sqf`, `dialog/myasylumstats.hpp`→`myloonybinstats.hpp`. (A blind rename without these = description.ext preprocessor fail + undefined `AP_fnc_*` cascade.)
- `mission.sqm` Intel display names sed'd → "Project Loonybin" (`gName`/`briefingName`/`overviewText`). Server `hostName` in `deploy/server.cfg` already "LooneyBin Altis Life [TEST]".
- **deploy + loonybot do NOT parse the word** "Asylum"/"ASY" → rebrand can't break boot/bot/DB. No content mods (only `@extDB` + `@AP_server`).
- Deferred (see `REBRAND-TODO.md`): asset files still named `asylum*`/`asydidas*` (textures/sounds — renaming needs file+ref together), `mission.sqm` `asylum_logo` flag textures + `jail_marker_asylum` marker, Asydidas clothing pun, cosmetic `class ASY` label (tag already PLB).

### Branding visuals
- **Grumpycat** on all billboards + splash + connect screen: `fn_applyRandomBillboardTexture.sqf` (random list → just grumpycat), `fn_mapData.sqf` (former `billboardloonybin.jpg` + `billboard_rules.jpg` setObjectTexture), `description.ext` `loadScreen`, `dialog/loadingBackground.hpp` `mainLoadingScreen.jpg` → all `images\grumpycat.jpg`. **Arma world textures need power-of-2 + baseline JPEG** or they render white — made it 1024x512 via `magick ... -interlace none`.
- **Logo placeholder**: overwrote `images/asylum_logo.jpg` content with a "PROJECT LOONYBIN / logo placeholder" card (orig at `asylum_logo.jpg.orig-bak`); welcome-UI `.paa` logo ref redirected to it. Both temporary — replace with real art in the asset pass.

### loonybot (Discord bot) — `loonybot/`
- discord.py 2.7.1 + PyMySQL in `loonybot/venv`. **OpenRC service** (CachyOS-OpenRC, supervise-daemon): `sudo rc-service loonybot restart`. Launcher `/usr/local/bin/loonybot` (space-free path; the project dir has spaces). Logs `/var/log/loonybot/`. `config.json` (gitignored): token (EXPOSED in chat — rotate), owner_ids `[100000000000000485]`, intake `100000000000000973` (a **Discord FORUM** — posts = threads), status+admin `100000000000000047`, db `127.0.0.1:3306/looneybin`.
- **Bug intake** → `BUGS.md` (project root). Forum posts captured via `on_thread_create` + startup `_backfill_intake` (walks forum threads; dedup on stored `**ref:** channel_id/msg_id`). Comments: **"received — bug #N"** on log, **"fixed please test again"** (pings reporter) on `### #N · FIXED`, status `NEEDINFO` → posts a `> ask:` question. Watcher (3s) diffs BUGS.md → status channel.
- **Admin console** (`admin.py`, owner+admin-channel gated): `!info <pid>` (incl alias `last_names` from `player_names` table + `last_ban` from `bans`), `!pid <name>`, `!whitelist <pid> <cop|med|srv> <rank>`, `!comp <pid> <amt> [cash]`, `!srv hardr|softr|msg|kick|ban`. **`SRV_RANKS` corrected** to the in-game ladder (was dev=1; now `none0/trial1/mod2/admin3/dev4/owner5`).
- **Server bridge**: tables `bot_commands`(id,command,target,arg1,arg2,status) + `bans`(playerid,reason,banned_by,until). Bot writes rows → **poller in `server/.../init.sqf`** (every 5s, `SELECT ... QUOTE(...) WHERE status='pending'`) executes `msg`→`AP_fnc_broadcast`, `kick`/`ban`→`AP_fnc_botKick`. **Ban gate** in `fn_insertRequest.sqf` (rejects banned UID on connect). `hardr`/`softr` = bot subprocess reboots the **arma server** (`_server_reboot()`: pkill + `run-boot2.sh`).
- **`player_names`** table (alias tracking): UNIQUE(playerid,name), seen-bumped; written from **`fn_queryRequest.sqf`** on every connect (`INSERT ... ON DUPLICATE KEY UPDATE seen=NOW()`). Backfilled from `players.name`.

### Bug fixes (BUGS.md, this session)
- **#8 drops tweak** (`APS_fnc_createItem`): now MERGES the dropped items into a same-class suitcase within 6 m (stacking like items) instead of one case per drop, and spawns the case with `enableSimulationGlobal false` + `allowDamage false` (no PhysX → can't punt vehicles/players). Pickup uses cursorTarget (works on sim-disabled).
- #1 loadout, #4 jail, #5/#6 heli, #7 tempest, #9 repair, #10 unflip, #11 VDM — confirmed FIXED by user. #2 revive + #3 aging barrel → NEEDINFO (bot asked jimjim for repro).

### Features added
- **House Rebel Loadouts**: scroll action in `fn_setupActions.sqf` (after "Check Registration", inside the `adminLevel>=2` block) → `AP_fnc_loadoutMenu "rebel"`, gated `(call AP_adminLevel) >= 3` + owned house (`ga_homeOwner != ""`) within 15m. Anti-cheat (`initPlayerLocal` `_badText`/`_badCode` scan of PLAYER addActions): keep title/code clear of `==,!!,--,*,##,~,teleport,kill,esp,spawn,explosive,ammo` (title) and `bis_fnc_arsenal,bis_fnc_mp,_decrypt,createunit,ctrlcreate,createagent` (code).
- **Admin-menu Virtual Arsenal** (`dialog/admin_menu.hpp` idc 12915) gated to `AP_adminLevel >= 3` (was open to the whole admin menu ≥2). Dialog button, not a player addAction → AC doesn't touch it.
- **Medic Revive Drone (AEMT+)** — **AL-6 Pelican (Medical), Laws of War DLC**: drone `I_UAV_06_medical_F`, backpack `I_UAV_06_medical_backpack_F` (native disassemble), terminal `I_UavTerminal` (independent = medic side, so the terminal can control it). Sold as **normal gear**: backpack in medic clothing shop `fn_clothing_med.sqf` case 4 (backpacks), $20k, AEMT+ block; terminal in `fn_weaponShopCfg.sqf` `med_basic` shop (with NVG/GPS), AEMT+. Assemble + fly NATIVELY. **`fn_reviveDrone.sqf`** (treat-only): "Treat via Drone" scroll action (`fn_setupActions`) uses **`getConnectedUAV player`** to find the drone the medic is piloting → revive nearest downed (`AP_fnc_revived` MP) / bloodbag nearest injured (`setDamage 0`, **global effect**) within 7 m of the **drone**. 10 shared charges (`AP_droneCharges`) → 1 h recharge (`AP_droneRechargeAt`); session-only (relog resets — persistence TODO. Registered `class reviveDrone {}` in `Functions.h` Medical_System.
  - UAV gotchas learned: **`connectTerminal` is NOT a script command** (use the terminal item + native "Connect Terminal to UAV"); a UAV spawned mid-air with no engine **falls + explodes** (spawn on ground, `allowDamage false` before physics); only the Darter + the UAV_06 family have backpack-assemble variants.

### Still standing
- Bot token exposed in chat → **rotate** (Discord dev portal).
- `#2 revive` + `#3 aging barrel` await jimjim's repro answers.
- CfgRE RCE close-out still DEFERRED to before public launch (see Pending above).
- Drone charge persistence (session-only), drone-treat scroll requires body view (drone holds position).
