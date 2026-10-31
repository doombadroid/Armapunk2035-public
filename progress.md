# LooneyBin — Progress / Status

Living status doc. Updated as the methodical persistence pass proceeds.
Server = 2017-derived serverside (`server/AP_server`) + 2020 deobfuscated client (`mission/LooneyBin.Altis`).
Latest commit before this pass: `330370c`.

---

## ✅ Confirmed working (observed in-game by owner)
- Server boots full stack: extDB3 → MariaDB, mission transfers, player connects.
- Spawn-in: player loads, picks spawn, drops into town **alive with full control** (mouse-look, Escape, Y, map, phone).
- Shops: gun store stocked, clothing shop opens (no preview-camera lock), ATM deposit/withdraw.
- Money persists (cash/bank), licenses persist (gun license survived relog).
- **Position persists** (loads at/near last spot; double-nest unwrap handles old data).
- **Talents persist** (unlocked in-game, survived relog).
- **Gear SAVE works**: `ClupdatePartial` mode 3 → `updatePartial` → `{civ,cop,med}_gear` column. DMR-03 written to `cop_gear`, single-wrapped.
- **Gear LOAD works**: `queryRequest`→`requestReceived`→`loadGear` applied the saved DMR-03 **cleanly** on reconnect (zero loadGear errors that session).
- Escape menu Abort/Suicide now only locked in combat (was always-locked).
- Admin/cop/medic whitelist + currency granted via DB.

## 🚗 Garage / vehicle persistence — REBUILT + server-verified (this pass)
The 2020 client's whole vehicle subsystem was wired to 2017 server fns with **no arg adaptation**
(the "EXISTS aliases" just pointed APS_fnc_* at the 2017 files). Every entry point was broken:
buy never inserted (`_uid` type-checked to `""` -> silent no-op), count/list passed mismatched args,
ownership var name differed (2020 `ga_dbInfo` vs 2017 `dbInfo`). Rebuilt 4 server fns + 1 whitelist:
- **`core/TON/fn_garageCount.sqf`** — `[uid,side,player]` -> `SELECT id … alive=1` count -> `publicVariableClient AP_garageCount`. Was a passthrough stub (set the wrong var, `AP_veh_count`). Fixes "Failed to fetch garage count from server."
- **`core/system/fn_getVehicles.sqf`** — `[player,type]` -> query stored (`active=0`) -> reshape each row to the 2020 index map (0 id,2 class,4 pid,7 plate,8 color,10 mods,11 wear,12 customPlate) -> wrapped `[_out]` -> `AP_fnc_vehicleGarageMenu` -> `AP_garageData`. (2017 fed the now-stub `impoundMenu`.)
- **`core/system/fn_vehicleCreate.sqf`** — `[player,veh,uid,side,skin,alarm,maxtac,ff,srt]` -> generate plate -> `DB_fnc_insertVehicle` -> stamp `ga_dbInfo=[uid,plate]` (client store lookup) **and** `dbInfo=[uid,plate,color,alarm]` (2017 readers: vehicleStore/vehicleDead/cleanup work unchanged) + Killed EH. MaxTac/FF/SRT not persisted.
- **`core/TON/fn_vehicleSetActive.sqf`** — pull `[player,plate,veh]` -> targeted `UPDATE active='1'` (no clobber of stored fuel/dmg/alarm) + re-stamp ownership vars. Was a stub (`_plate=player`->-1->no-op).
- **`mission/.../CfgRE.hpp`** — whitelisted `AP_fnc_vehicleGarageMenu` (server->client; else the list reply is silently blocked under remoteExec mode=1).

**VERIFIED** by a one-shot server self-test (now removed): real `ASY_fnc_vehicleCreate` -> insert +
`dbInfo`/`ga_dbInfo` set, `garageCount=1`, store(active=0), `getVehicles` QUOTE-query + reshape ->
**RESHAPE MATCH=true** (idx2=class, idx4=pid, idx7=plate, idx8=color all correct). DB-level SQL test
also green (count counts all alive; Car garage shows only stored; pull flips out of the list). Boots clean.

**THE asyncQuery gotcha (cost a debug cycle, now a rule):** `DB_fnc_asyncQuery` `call compile`s the
whole extDB3 result. So (a) raw varchar columns (classname/pid) MUST be wrapped `QUOTE(col)` in SQL or
compile dies on the bare token ("Undefined variable: c_hatchback_01_f"); (b) numeric columns come back
already typed — do NOT `parseNumber` them ("Type Number, expected Bool,String"). queryRequest dodges
this by only ever selecting numeric/backtick columns; any new raw-string SELECT must QUOTE.

**Garage limitations (acceptable / noted):** vehicle MODS, paint WEAR, custom PLATE, and fuel/damage do
not persist across store→pull (2017 table has no columns for them; pulled vehicle spawns full-fuel,
mods default). Ownership + the vehicle itself persist. Fuel/dmg self-correct on next store.

## 🔧 Fixed this pass
0. **Gear + Y-inventory persistence — VERIFIED via server-side round-trip self-test.** [FIXED+VERIFIED]
   Booted the server with a one-shot test that encodes→decodes 7 arrays (incl. a real cop gear loadout
   full of empty strings, a virtual inventory, licenses, talents, position, `[""]`, nested empties).
   **All 7 → MATCH=true.** So encode/decode is now lossless for the exact shapes that persist. Combined
   with the save-side `respawn_west` fix (gear now writes to `{side}_gear`), gear+inventory should
   persist end-to-end. (Test code removed after confirming.)

1. **Gear LOAD root — `mresToArray` decoder used single-quote(39) instead of double-quote(34).** [FIXED+VERIFIED]
   The encoder (`mresArray`) does `str(str(x))` then `"`(34)→backtick(96). The decoder must restore
   34; it used 39, so empty strings (`""` → `""""` via str²) round-tripped to a stray `'`/syntax error
   → whole decode = nil → `[]`. Gear loadouts are full of empty slots (`""` muzzle/optic/etc), so gear
   decoded to `[]` → `loadGear` took the empty path → `copLoadout`/`civLoadout` default EVERY spawn.
   That was the real "doesn't sync" (NOT a spawn re-gear overwrite — `respawn=BASE`, no respawnOnStart,
   so `fn_respawned` only fires on death). Byte-trace verified `[""]` now round-trips; licenses/talents
   (non-empty strings / numbers) round-trip either way so they were never affected. `server/.../fn_mresToArray.sqf`.
   NOTE: likely also un-breaks any other field containing empty strings (gov_data, some gear-adjacent).
2. **Disconnect corpse.** [FIXED] `fn_playerDisconnected` only swept `allDeadMen`; a disconnected unit
   is often still ALIVE (frozen) so it was never matched. Now also deletes `_unit` (the unit passed by
   HandleDisconnect) directly + its weapon-holders. `server/.../fn_playerDisconnected.sqf`.
3. **`AP_radio_med` undefined on cop.** [FIXED] Defaulted + broadcast in server `init.sqf` (next to
   `AP_radio_civ`). `manageSidechat` evaluates the `else{AP_radio_med}` branch before the west-exit.

## 🩹 Fixed this pass, code-only (NOT yet confirmed in-game — needs a real player connect/disconnect)
- **Disconnect corpse** — `fn_playerDisconnected` now deletes `_unit` directly (+ weapon-holders), not
  just the `allDeadMen` sweep (which missed a still-alive frozen unit). Boots clean; needs a live
  disconnect to confirm the body is gone.
- **`AP_radio_med`** defaulted+broadcast — boots clean; cop manageSidechat path should no longer throw.

## ❌ Still broken / not addressed (need deeper work or missing infra)
1. **Personal vehicle garage — FIXED this pass** (see 🚗 section above; server path verified). Still
   needs a live in-game buy→store→relog→pull to confirm the client UI half end-to-end (server half proven).
1b. **Gang garage — FIXED + server-verified** (commit follows the personal garage). Same bug class,
   same recipe: `fn_gangGarageGetVehicles` (QUOTE classname, drop parseNumber, correct idx map
   mods/wear/cplate at 10/11/12, send wrapped `[_out]` via AP_fnc_MP), `fn_gangGarageCount`
   (count rows + `publicVariableClient AP_gangGarageCount` — was parseNumber-on-number + delivered
   via AP_fnc_MP which runs a fn not a var -> no-op), `fn_gangGarageAddSRV` (QUOTE classname/type/
   inventory in the SELECT), `fn_gangGarageStore` (color from `dbInfo[2]`; `ga_vehColor` never existed).
   Self-test green: count=1, RESHAPE MATCH=true (idx4=gang_id). All gang TON fns already whitelisted.
   gangGarageSetActive pull works as-is (client sends the vehicle as arg5; server `_active` type-defaults
   to 1 = pull). NEEDS a live gang test (owner storing/pulling a gang vehicle).
1c. **`vehicle_mem` / `exchange` tables MISSING** (recurring `MariaDBQueryException` Protocol Errors).
   These are the boot vehicle-restore (`restoreVehicles`, dormant) + the Asylum Exchange — NOT the
   garage (garage uses the `vehicles` table, which exists + works). Separate infra; add schema if those
   features are wanted.
2. **Prestige currency / cop_talents conflation.** `updatePartial` mode 16 saves `prestige`+`cop_talents`
   in one query, so unlocking a talent re-writes the live `prestige` (0) over any DB grant. The
   currency pipeline itself is fine; the two-systems-one-column design is the issue. Minor.
3. **Gov elections / turf captures / monitorCaptures spam** — non-blocking server errors (`capture_N`
   undefined, votes/gangs queries). World features, don't affect player loop.

## 📋 Save↔load contract (verified consistent this pass)
- Load `_r` per-side indices match `requestReceived` exactly: civ [15,16,17]=arrested/crimes/pos;
  cop [15,16,17]=copLevel/prestige/cop_talents; med [15,16]=medLvl/vehObjs. `_r[6]`=gear (all sides).
- **Y-inventory is stored INSIDE the gear array** (`saveGear` → `[loadout,[inv,weight],skins]`), so the
  mresToArray fix should restore Y-inventory persistence as well (same root, was decoding to `[]`).
- Prestige currency (`AP_prestige`, `prestige` col) loads correctly via `_dec`→number. The "shows 0"
  is the conflation: `updatePartial` mode 16 writes `prestige`+`cop_talents` together, so any in-game
  talent unlock re-saves the live `prestige` (0) over a DB grant. Minor; not a pipeline bug.

## ❓ Untested / unknown
- Y-inventory (virtual items) persistence — should now work via the gear fix; UNCONFIRMED in-game.
- Vehicle / garage persistence (`APS_fnc_garageCount` → 2017 `getVehicles`; vehicle_mem/exchange tables missing → Protocol Errors).
- Houses, gangs persistence.
- Whether civ gear persists once the spawn-regear gate is added (only cop tested).
- Final-state save on disconnect (`flushPlayer` relies on `AP_update_buffer` being populated).
- Medic side spawn/gear.

## 🔎 Notes / gotchas (for the pass)
- SQF `&&`/`||` are EAGER unless RHS is a `{code block}` — guards must wrap the lazy part in `{}`.
- `x = nil` UNDEFINES x in SQF — never assign a possibly-nil value to a persistent global.
- `respawn_west` marker is ABSENT from mission.sqm → `getMarkerPos` = `[0,0,0]`; any `distance respawn_west < N` guard misfires near map origin (spawn-in holding spot).
- extDB3 stores arrays backtick-encoded (`` ` `` for `"`); `_enc`=`mresArray`, `_dec`=`mresToArray`. `_enc` had a double-wrap bug (fixed: `{ _this call mresArray }`).
- Debug probes still in tree (grep `LBPROBE`): initPlayerLocal, core/init, fn_initCiv, requestReceived, ClupdatePartial, saveGear, server queryRequest/asyncQuery/insertRequest/updatePartial. STRIP before final.

## Plan (this pass)
1. Map full save↔load contract (every ClupdatePartial mode ↔ updatePartial column ↔ queryRequest index ↔ requestReceived index), per side. Find all mismatches.
2. Fix gear spawn-overwrite (gate re-gear).
3. Fix prestige currency decode.
4. Fix disconnect corpse + AP_radio_med.
5. Inventory persistence verify.
6. Strip probes. Boot-verify server (no SQF/SQL errors). Final commit.
