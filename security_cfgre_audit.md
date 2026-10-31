# CfgRE `allowedTargets=2` Gap Audit — client→server remote-exec surface

**Scope:** all 144 `allowedTargets=2` entries in `mission/LooneyBin.Altis/CfgRE.hpp` (every fn a client can
remoteExec **at the server** with forged args). Cross-referenced against the ~55 hardened in the 2026-06-23
security batch (`security.md` §4b). Companion to `security.md`. **READ-ONLY recon — nothing staged.**

**Method:** (1) marker-scan every fn's source for hardening tells — `remoteExecutedOwner` (REO, caller
identity), `_san`/`splitString "'"` (SAN, SQL escape), `-SEC-` (SEC, block-log), `2026-06-23`/`SECURITY`
(BAT, batch-touched); (2) **code-verified** the high-risk / low-marker fns by reading them. A fn is "hardened"
only when its protections match its risk class. **Unread low-risk fns are NEEDS-REVIEW, not "safe."**
Precision rule: a false "hardened" is worse than a false "gap."

## Counts
| | n |
|---|---|
| Total `allowedTargets=2` | 144 (139 `APS_fnc_`, 4 `DB_fnc_`, 1 `AP_fnc_botKick`) |
| Confirmed hardened (markers + verify) | ~78 |
| **GAPS** (verified exploitable) | **14** — 3 CRIT, 4 HIGH, 7 MED |
| NEEDS-REVIEW (unread, risk unclear / passthrough to `AP_fnc_*`) | ~40 |

The batch did real work — gang-authority, cop/wanted/jail, admin, most money fns are genuinely closed. The
gaps below are the **survivors**: mostly the generic DB save-layer (untouched for identity) + old-style
`system/` fns + thin alias passthroughs the batch skipped.

---

## GAP TABLE — ranked

| # | Fn | File:line | Risk | Missing | Exploit sketch | Sev |
|---|---|---|---|---|---|---|
| 1 | `DB_fnc_updatePartial` | `DB/fn_updatePartial.sqf:7,58,59` | MONEY / cross-acct | **caller-identity** (uses client `_uid`, only `_san`'d — never reconciled to `getPlayerUID _player`) | remoteExec `[player,civilian,VICTIM_UID,6,0,0]` → `UPDATE players SET cash=0,bankacc=0 WHERE playerid=VICTIM` → **zero any player's money**; or own UID + huge `_d` → self-enrich | **CRIT** |
| 2 | `DB_fnc_updateRequest` | `DB/fn_updateRequest.sqf:6,29,36` | MONEY (root) | **value authority** (`_cash`/`_bank` taken from client, only `numberSafe`'d) | remoteExec `[player,name,side,9.9e8,9.9e8,[],0]` → own bank=999M. Identity *is* server-derived (self-only) so CLANKR cash-delta is the only backstop. Architectural — full close = server-authoritative cash | **CRIT** |
| 3 | `APS_fnc_vehicleDelete` | `system/fn_vehicleDelete.sqf:9-19` | THEFT + SQLi + money | caller-identity, ownership, `_san` | client `_vid`/`_pid` go RAW into `DELETE FROM vehicles WHERE id='_vid' AND pid='_pid'` → delete **any** player's vehicle row (+ SQLi via either) then credits the passed `_unit` for the "sale" | **CRIT** |
| 4 | `APS_fnc_handleWireTransfer` | `TON/fn_handleWireTransfer.sqf:10-14` | MONEY | **no sender debit** + identity by passed `_sender` | `[9999999,anyObj,accompliceObj]` → relays a wire credit; capped 10M/call but **never debits a sender** → mint ≤10M per call. (cap is the only batch touch; not REO-gated) | **HIGH** |
| 5 | `APS_fnc_updateHousePrice` | `TON/fn_updateHousePrice.sqf:8,15` | GRIEF + SQLi | ownership check + `_san` on `_id` | `[objNull,VICTIM_HOUSE_OID,player,1]` → `UPDATE houses SET sale='1' WHERE oid='_id'` (raw `_id`) → relist/mis-price **any** house; SQLi via `_id`. **Contradicts `security.md` §2.2 "SAFE" claim** | **HIGH** |
| 6 | `DB_fnc_insertRequest` | `DB/fn_insertRequest.sqf:8,18,20` | SQLi | `_san` on `_uid` (only `_name` escaped) | client `_uid` raw into `INSERT players_global VALUES('%1')` + the ban-check SELECT → SQLi; UID fully client-trusted (new-player path, INSERT IGNORE limits blast) | **HIGH** |
| 7 | `APS_fnc_exchangeSystemSRV` (BUY) | `TON/fn_exchangeSystemSRV.sqf:84-92,102` | MONEY | buy-side debit/recompute **unconfirmed** | LIST path now server-derives `_uid` + `_san`s (SQLi/identity **closed**, verified :104). BUY path `_paySeller` credits `bankacc+_amount` — could not confirm `_amount` is the DB `Price` (re-fetched) vs client. **Re-verify the buy debit** before clearing | **HIGH (PARTIAL)** |
| 8 | `DB_fnc_queryRequest` | `DB/fn_queryRequest.sqf:10-14` | INFO | identity by passed `_player` | loads passed object's full DB row, but reply routes to `owner _player` (the victim), so attacker gets nothing back → low exfil. Force-reload nuisance only | **MED** |
| 9 | `DB_fnc_insertGang` | `DB/fn_insertGang.sqf:10,12,32` | GRIEF/money | caller-identity (passed `_player`) | `[VICTIM_OBJ,"x"]` → `getPlayerUID VICTIM` → deduct **victim's** 25k + force them into a new gang. Name *is* `_san`'d | **MED** |
| 10 | `APS_fnc_discordEmbed` | `TON/fn_discordEmbed.sqf:6` (`params[]`) | ABUSE | identity, content validation | client-callable with `_this` → post arbitrary embeds through the **server's Discord webhook** (spam / staff impersonation / phishing in your Discord). Confirm the `AP_fnc_*` target | **MED** |
| 11 | `APS_fnc_handlePhoneMsg` | `TON/fn_handlePhoneMsg.sqf:15` | SPOOF | identity by passed `_caller` | `[3,anyObj,objNull,"msg"]` → spoofed phone message to all cops/medics/**admins**, "from" a chosen player | **MED** |
| 12 | `APS_fnc_registerMaxTac` | `TON/fn_registerMaxTac.sqf:7` → `APS_fnc_maxtacRegistered` | PRIV | identity (passthrough) | passthrough of client `_this`; per `security.md` §2.2 trigger MaxTac register/deploy as non-cop. Verify `APS_fnc_maxtacRegistered` | **MED** |
| 13 | `APS_fnc_fedRobbery` / `APS_fnc_bankRobbery` / `APS_fnc_add2Lotto` | `TON/fn_fedRobbery.sqf:7` / `fn_bankRobbery.sqf:7` / `fn_add2Lotto.sqf:7` | GRIEF/money | identity (thin alias → `APS_fnc_fedAlarm`/`bankDrillVault`/`addToLottery`) | pass `[player]` from client → start fed alarm / bank drill / lotto-entry as/against a chosen player. `bankRobbery` is known **guarded** (`AP_bank_drilling` single-fire, CLANKR-watched); fed-alarm griefable; lotto entry unverified. Audit the 3 `AP_fnc_*` bodies | **MED** |
| 14 | `APS_fnc_medSupplySpawn` | `TON/fn_medSupplySpawn.sqf:8,16` | OBJECT SPAM | rate-limit | `[anyObj]` → spawn a med crate (30-min despawn) anywhere; loop = object/grief spam. Owner set from passed obj (harmless) | **MED** |

### Root-cause grouping (mirrors `security.md` §2.4)
- **#1–#3, #5, #8–#13 = identity-by-argument** — the save-layer + old-style + alias fns trust a passed
  `_player`/`_uid`/`_caller` for *who acts*. Fix = derive from `remoteExecutedOwner` / `getPlayerUID _player`,
  drop the client UID. `updatePartial` is the worst (cross-account money write) and the cheapest fix (one line:
  `_uid = getPlayerUID _player;` like `updateRequest` already does).
- **#2, #4, #7 = value authority** — money taken from a client number. `updateRequest`/`updatePartial` cash is
  the architectural root (same family as `createItem`); CLANKR cash-delta is the live backstop.
- **#3, #5, #6 = residual SQLi** — `_vid`/`_pid`/`_id`/`_uid` raw into `format[]` queries (batch missed these
  files). Fix = `_san` + numeric coercion.

---

## CONFIRMED HARDENED (markers + verified — do not re-flag)
Gang authority: `gangBank` `gangBHistory` `removeGang` `updateGangMem` `transferGangOwnerSRV` `addGangHouse`
`changeGangHouseSRV` `removeGangHouseSRV` `setGangTagSRV` `update1GangTalents` `gangGarageAddSRV`
`gangGarageStore` `gangGarageSetActive` `getGangInfo`.
Cop/wanted/jail: `jailSys` `handleJail` `setJail` `wantedPardon` `wantedRemove` `wantedRemoveCharge`
`wantedAdd`(clamped 1–5) `wantedBounty`(partial) `bulkAdd` `evidenceTruck` `evidenceAppend` `handleDispatch`
`handlePrisonBreak` `copSplit`.
Admin: `adminKickBan` `adminMsg` `adminDelVeh` `createAdminVeh` `adminPlayerQuerySRV` `changeServCycle`
`changeWeather` `toggleNewbieRoles` `economySRV`.
Money/value (server-recompute or clamp): `cartelSRV`(clamp :56-64) `srvChopShopSell`(REO+BAT; real impl
`system/fn_chopShopSell` chop-zone gated) `srvSellVehicle` `vehicleRepairSRV` `medicSplit`(bounded)
`medSupplyPay`(bounded) `createItem`(bounded) `updateProperty` `houseTaxSRV` `processMailbox` `loginBonusSRV`
`xmasTreeAndPresentsSRV` `transferHouse` `varPersist` `statTableUpdate` `droneCharges` `updateVehicleMods`
`garageCount` `vehOwnerSwap` `keyManagement`(revoke-only) `updateHouseTrunk` `loveBombSRV` `barrelSRV`
`fetchLoadouts`(server UID) `handleLoadouts` `seizeLock` `govSystemSRV` `greenhouseSRV` `jewelryEmporiumSRV`
`duelArenaSystemSRV` `trialSystemSRV` `gangFortressSRV` `endConvoyRobbery` `airDrop` `srvRobStore`.
DB partial: `updateRequest`/`updatePartial` SQLi+nil-guard closed (but see GAP #1/#2 for residual
identity/value).

## NEEDS-REVIEW (unread or `AP_fnc_*` passthrough — classify before clearing)
`AP_fnc_botKick` (defined in MISSION `core/functions/network/fn_botKick.sqf` but whitelisted server-target —
confirm a client can't kick others), `doBuySkin` (client UID trusted; **skins were stripped** → likely dead,
confirm), `srvSpikeStrip` `enableCoPilot` `checkPlayer` `getID` `lagCheck` `getVehicles` `vehicleStore`
`vehicleCreate` `vehicleDead` `gangGarageGetVehicles` `gangGarageCount` `garageCount` `wantedFetch`
`wantedSyncList` `getStatsArr` `srvPersistentBounties` `srvObjectMonitor` `handleTimer` `huntingGrounds`
`igiInit` `laserQueue` `laserEliminated` `eventBRSRV` `eventPurgeSRV` `eventParticipants` `eventGraveyardSRV`
`eventGunGameSRV`(REO+SEC present) `createTimeTrialVehSRV` `timeTrialSRV` `easterSeasonalEvent`
`handlePhoneCallSRV` `medicFireSRV` `initHouseInventory` `houseFurnitureSRV` `setCleanTime`
`spawnPhysicalItem` `visible` `flipVehicle` `enableCoPilot` `srvSellHouse` `srvMobileHQ` `ignitionBombSRV`
`loonyBinSRV` `convoyRobbery` `bankLighthouseToggle` `medSupplySpawn`(rated MED above) `addHouse`(BAT) `logIt`
(SAN; server-side log sink) `insertGang`(rated MED) `updateWar` `bldgUpdateKeys`(SAN) `repairBuildingSRV`
`sendKeyHouses`(new, REO).

## Recommended fix order
1. **GAP #1 `updatePartial` identity** — one-line, closes cross-account money-zeroing. Highest value/cost.
2. **GAP #3 `vehicleDelete`** + **#6 `insertRequest`** + **#5 `updateHousePrice`** — add `_san` + ownership /
   server-UID. Closes the residual SQLi + arbitrary-delete/relist.
3. **GAP #4 `handleWireTransfer`** — add server-side sender debit (or REO-gate to the owner-checked path).
4. **GAP #7 `exchange` BUY** — re-verify the buy debit uses DB `Price`; clear or fix.
5. **#2/#updateRequest value authority** — the architectural cash refactor (with `createItem`); CLANKR holds the line meanwhile.
6. MEDs (#9–#14) — identity-gate the alias/spoof/spam fns; audit the `AP_fnc_*` passthrough bodies.
