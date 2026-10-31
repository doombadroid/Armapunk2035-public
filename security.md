# LooneyBin — Security Audit & Hardening

Living document. Tracks confirmed vulnerabilities, the client-trust exploit surface, and a hardening
checklist. Companion to `AUDIT.md` (general code audit) and `launch.md` (pre-public revert list).
Sibling: [[loonybin-cfgre-rce-deferred]], [[loonybin-clankr-anticheat]].

**Threat model.** An Arma 3 client is fully attacker-controlled: a scripter can read/write any
`missionNamespace` / `profileNamespace` var, redefine any `AP_fnc_*`, and `remoteExec` any
**whitelisted** function (CfgRE `mode=1`). Therefore: **nothing client-side is trustworthy** —
not logging, not permission checks, not cooldowns, not identity, not money/inventory values.
Every security-relevant decision MUST be re-validated **server-side** against server-owned state
(DB, `getPlayerUID` of the real remote unit, BattlEye). Client code is UX + best-effort telemetry.

Status legend: 🔴 OPEN (confirmed, unfixed) · 🟡 PARTIAL (hardened, still bypassable) · 🟢 FIXED · ⚪ INFO.

---

## 1. Confirmed vulnerabilities

### 1.1 🔴 profileNamespace anti-cheat bypass (owner-reported 2026-06-23)
All three of the server's profileNamespace-based anti-cheat signals live **client-side**, so the
client neutralizes them before joining. profileNamespace is the player's local Arma profile file —
fully attacker-controlled, and **shared across every Arma server** (Asylum-derived).

| Signal | Location | Purpose | Bypass |
|---|---|---|---|
| `yxzmen` | `initPlayerLocal.sqf:93-107` | alt-account / ban-evasion list → `-MULTIPLESTEAMS-`/`-NEWACCOUNT-` | `profileNamespace setVariable ["yxzmen",[]]; saveProfileNamespace;` → history erased → new Steam account joins unlogged |
| `A_flgd` | `initPlayerLocal.sqf:281-289` | "already-flagged" suppress flag | pre-set `["A_flgd",true]` → the `isNil A_flgd` gate skips the `MAIN_RE` report entirely |
| `MAIN_RE` | `initPlayerLocal.sqf:281-287` | known cheat-menu signature → `APS_fnc_wacClient` code 50 | clear it → nothing to detect |

Server side: `APS_fnc_wacClient` (`server/.../fn_wacClient.sqf`) only **advisory-logs** `-WAC-` (no
auto-action). `fn_getIpAddress.sqf:17` is **stubbed `0.0.0.0`** (`// player IP not available without an
extension` — extDB3 migration broke it) → currently **no** server-owned anchor that survives a wipe.

**Why it can't be sealed client-side:** the client owns profileNamespace. Any detection living there
is bypassable. The only durable fix is a server-owned signal.

**Fix plan (owner 2026-06-23: do both):**
- **A — client hardening (partial, cheap):** report `MAIN_RE` EVERY session (drop the `A_flgd`
  self-suppression at `initPlayerLocal.sqf:281`); log `-WACTAMPER-` when `A_flgd` arrives set, or when
  the client's `yxzmen` is SMALLER than the server's historical `-MULTIPLESTEAMS-` record for that UID
  (server `log` table is authoritative history — a shrunken client list = a wipe). Raises the bar; a
  determined wipe still evades.
- **B — server-side alt detection (durable):** restore real IPs via **BE RCON `players`** (BattlEye
  knows every connected IP; we already have RCON + `bm.py`) → correlate UID↔IP in a DB table on each
  join. Cannot be client-wiped. This is the real ban-evasion fix. STATUS: to build.

### 1.2 🟡 `-FNCALL-` audit is client-disableable
`fn_MP.sqf:15` gates the `-FNCALL-` audit (CLANKR's primary data) on
`missionNamespace getVariable ["AP_logCalls", true]` — a client var. A scripter runs
`AP_logCalls = false;` (or redefines `AP_fnc_MP`) and ALL their remote calls go unlogged → invisible
to CLANKR. Inherent to client-side logging. **Mitigation:** server-side logging of the *actual*
exploitable actions (money/item/seize writes via `APS_fnc_logIt` **server-side**) is the real audit
trail — `-FNCALL-` is best-effort. A client whose `-FNCALL-` stream goes silent while they're clearly
active is itself a tell (a CLANKR heuristic worth adding). Good: `APS_fnc_logIt` derives `_uid` via
`getPlayerUID _who` from the real remote unit (`fn_logIt.sqf:21`) — identity isn't spoofable when an
object is passed (only the string-UID branch trusts the caller).

### 1.3 🟡 BattlEye is enforcement-blind (log-only stubs)
Every `deploy/battleye/*.txt` filter is exactly `1 ""` — BE action level **1 = LOG ONLY** with no
patterns. `server.cfg` has `BattlEye = 1`, but BE never kicks/bans; it just writes be.log. So
**CfgRE `mode=1` is the ONLY real remoteExec restriction** — the BattlEye second layer (scripts /
remoteexec / setvariable / createvehicle / setpos / setdamage filters) enforces nothing. This is a
deliberate staged state (collect be.log → write filters → raise action to 7=log+kick+ban), but it's a
public-launch gap: an attacker who finds a CfgRE-whitelisted hole has no BE backstop. **Fix (pre-public):**
mine be.log for legit patterns, author the filters, raise actions to kick/ban. Tracks with
[[loonybin-cfgre-rce-deferred]] (CLOSED BETA → trusted admins → deferred; REMIND at actual-public).

### 1.4 🔴 Admin/RCON secrets committed in plaintext
`deploy/server.cfg` stores `passwordAdmin` and `serverCommandPassword` in cleartext in the repo, and
they are **identical**. Anyone with repo access (it's a shared/derivative codebase — see `legal.md`,
`v2.md`) gets admin login + RCON. **Fix:** move both into a gitignored secret (pattern already used for
`loonybot/secrets.json` BM token — chmod 600, never committed) and have run-boot2 inject them at deploy;
use DISTINCT values for login vs command. Rotate the current ones.

---

## 2. Client-trust exploit surface (audit in progress)

The 266 CfgRE-whitelisted functions (`mode=1` whitelist — correct) are the remoteExec surface. Each that
fails to re-validate its args server-side is a vector. **None** of the vulnerable fns below has an
in-function `remoteExecutedOwner==2` / identity check — the whitelist is the only gate, so any scripter
can remoteExec them with arbitrary args.

### 2.1 Money / value / quantity trust (sweep agent + 3 CRITs re-verified by me)
**Root cause across all of these:** the pervasive *"the client already debited itself, the server just
credits the other side"* pattern. Invalid under the threat model — a scripter never runs the client
debit. Every payout must **debit server-side** (authoritative cash/bank/inv) or **recompute the value
from server state**, and money fns should add a caller-identity check.

| Fn (CfgRE line) | File:line | Trusted client value | Exploit | Sev |
|---|---|---|---|---|
| `APS_fnc_createItem` (487) | `TON/fn_createItem.sqf:19,50` | `_items` array incl. `["money",N]` | remoteExec a pile `[[["money",9.9e8]],pos,"Land_Suitcase_F"]` → walk over → `AP_cash += 9.9e8` (`fn_pickupItem.sqf:88`) + any item/qty. **🔴 re-verified** | **CRIT** |
| `APS_fnc_srvChopShopSell` (385) | `system/fn_chopShopSell.sqf:11,37` | `_price` (arg2) | remoteExec `[player,<any pulled veh w/ dbInfo>,9.9e8]` → veh deleted, `cash+=9.9e8`. **🔴 re-verified** | **CRIT** |
| `APS_fnc_exchangeSystemSRV` (673) | `TON/fn_exchangeSystemSRV.sqf:115,137` | BUY `_price` (DB `Price` SELECT'd then discarded) | BUY w/ inflated `_price`; `_paySeller _price*_take` mints to a colluding/self seller, buyer debit is client-side. **🔴 re-verified** | **CRIT** |
| `APS_fnc_handleWireTransfer` (754) | `TON/fn_handleWireTransfer.sqf:10` | `_val`,`_receiver` (no sender debit) | remoteExec `[9.99e6,any,accomplice]` → server relays `clientWireTransfer` to receiver (passes its owner==2), +9.99M bank, no debit. Distinct from the owner-gated `fn_clientWireTransfer`. | **HIGH** |
| `APS_fnc_medSupplyPay` (649) | `TON/fn_medSupplyPay.sqf:7` | `_price`,`_owner` | remoteExec `[anyBuyer,accomplice,9.9e8]` → accomplice bank +9.9e8 free. | **HIGH** |
| `APS_fnc_medicSplit` (595) | `TON/fn_medicSplit.sqf:11` | `_partners`,`_share` | remoteExec `[[accomplice],9.9e8]` → accomplice bank +9.9e8. | **HIGH** |
| `APS_fnc_cartelSRV` (751) | `TON/fn_cartelSRV.sqf:18,61` | `_value` unbounded; computed `_cap` never applied | if your gang holds a cartel, remoteExec `[0,0,9.9e8]` → +~1B gang bank/call. | **HIGH** |
| `APS_fnc_eventGunGameSRV` (622) | `TON/fn_eventGunGameSRV.sqf:34` | case 2 `_x1`=winner → hardcoded $250k | during any active Gun Game, remoteExec `[2,any]` → that acct +$250k, no proof. | **HIGH** |
| `APS_fnc_copSplit` | `TON/fn_copSplit.sqf:14` | `_amount` pool unbounded (cop-gated) | cop remoteExec `[player,9.9e8]` → split among cops incl self. | **MED** |
| `APS_fnc_updateProperty` | `TON/fn_updateProperty.sqf:14,21` | `_value` → `AP_vcap/phys_cap/keycap`+DB, no owner/pay check | remoteExec `[house,player,"vstorage",2e9,oid]` → unlimited house storage (value amplifier). | **MED** |
| `APS_fnc_govSystemSRV` | `TON/fn_govSystemSRV.sqf:164` | `_amount`→treasury (capped 5M/call, pays treasury not caller) | inflation/grief only. | **LOW** |
| `APS_fnc_statTableUpdate` | `TON/fn_statTableUpdate.sqf:12` | `_uid`+stat deltas (idx<500, ≥0) | remoteExec `[anyUID,[[idx,N]]]` → pump any acct's lifetime stats (title/BH fuel). | **LOW** |

**Also:** `APS_fnc_loveBombSRV` (whitelisted) takes client `_pos` → permanently levels every building
within 1km = server-wide grief/availability (gate to admin). **Dead code:** `core/GE/` legacy Exchange
- **The 2017 Grand Exchange backend is GONE (2026-08-22).** `fn_listing`, `fn_offlineComp` and
  `fn_updateMailbox` no longer exist: the first two were already absent, and the last (an
  unescaped, unauthenticated `UPDATE players_global SET mailbox=...`) was deleted along with its
  `config.cpp` registration. The two orphan whitelist entries that still advertised the dead
  client half -- `KBW_fnc_GEMenu` and `KBW_fnc_addWeapon`, functions defined on no machine --
  are out of `CfgRE.hpp` too. The live marketplace is `APS_fnc_exchangeSystemSRV`, which is a
  different implementation and is hardened; its remaining gap is buyer-side money, see below.
called) — but `fn_listing`/`fn_offlineComp` would be CRIT money printers **if ever re-wired** — flag any
re-enable.

**SAFE (read + properly hardened — don't re-flag):** `fn_srvSellVehicle` (server-recomputes price),
`fn_clientWireTransfer` (owner==2), `fn_houseTaxSRV`, `fn_greenhouseSRV`/`fn_barrelSRV` (clamp to
mature/cap), `fn_endConvoyRobbery`, `fn_fedGoldSpawn`, `fn_stimmySRV`/`fn_economySRV` (owner/admin5
re-checked from DB), `fn_gangBank` (balance-gated, race-proof), `fn_loginBonusSRV`,
`fn_gangGarageStore`/`fn_transferHouse`/`fn_gangFortressSRV`/`fn_trialSystemSRV`/
`fn_jewelryEmporiumSRV`/`fn_duelArenaSystemSRV`/`fn_robStore`/`fn_airDrop`.
⚠ **CORRECTION (2026-06-23, §4c):** `fn_updateHousePrice` was previously listed SAFE here — **wrong.**
Code-verified as a **HIGH gap**: no ownership check (relist/steal any house) + string `_id` SQLi. Removed
from SAFE; see §4c.

### 2.2 Permission / privilege / identity trust
**Core pattern:** almost every privileged server fn is gated ONLY by a client-side UX check; the server
handler re-validates nothing. Two flavors: (a) **no check at all** — acts on a UID/object from args; or
(b) **identity-by-argument** — derives the actor via `getPlayerUID _clientArg` instead of the
non-spoofable `remoteExecutedOwner`, so the attacker picks the actor/victim object. **Cross-cutting fix:**
two helpers at the top of every privileged handler — `_uid = getPlayerUID (objectFromNetId str
remoteExecutedOwner)` for identity (never trust a passed object/UID for *who is acting*) + a DB-backed
`isCop`/`gangRank`/`isHouseOwner`/`isVehicleOwner(uid)` for authz. In-repo models to copy: `fn_seizeLock`
(`:22` uses `remoteExecutedOwner`), `fn_govSystemSRV`.

**🔴 SERVER TAKEOVER**
- `APS_fnc_toggleNewbieRoles` (CfgRE 616) — `fn_toggleNewbieRoles.sqf:10-13` only checks `_player != null`,
  no owner gate → flips `SRV_grantNewbieRoles`; `fn_queryRequest.sqf:164` then grants new joiners **Sr
  Admin 4 + Cop 7 + Medic 6**. Any client flips it on → alt joins → full admin. **CRIT, re-verified.**
  (Live state 2026-06-23: toggle OFF, never toggled this boot = armed, not yet abused.) Fix: owner-UID
  guard (the `fn_stimmySRV` pattern). NOTE: the newbie-grant feature itself is a beta thing on
  `launch.md` to revert pre-public — but the **ungated toggle** is the security bug regardless.

**🔴 Cop / wanted / jail pipeline — all cop-only, all client-gated only (no server `side==west`/cop check)**

| Fn (CfgRE) | File:line | Exploit (any civ remoteExecs) | Sev |
|---|---|---|---|
| `APS_fnc_handleJail` (763) / `APS_fnc_jailSys` | `fn_handleJail.sqf:11,25` / `jail/fn_jailSys.sqf:9` | `[objNull,victim]` → jail anyone | CRIT |
| `APS_fnc_wantedAdd` (358) | `fn_wantedAdd.sqf:10,14` | `[57,victim,999999]` → frame anyone, 999k bounty | CRIT |
| `APS_fnc_wantedPardon`/`wantedRemove` | `wantedsys/fn_wantedPardon.sqf:10` / `fn_wantedRemove.sqf:9` | self-pardon / wipe any wanted level (+DELETE DB row) | CRIT |
| `APS_fnc_setJail` | `fn_setJail.sqf:9` | `[victimUID]` → trap a player in jail across relogs | HIGH |
| `APS_fnc_wantedRemoveCharge` | `fn_wantedRemoveCharge.sqf:10` | drop anyone's charges | HIGH |
| `…fn_wantedBounty` | `wantedsys/fn_wantedBounty.sqf:9` | pass own object as `_cop` → collect bounty as non-cop | HIGH |
| `APS_fnc_evidenceTruck`/`evidenceAppend` | `fn_evidenceTruck.sqf:7` / `fn_evidenceAppend.sqf:10` | spawn truck w/ the whole seized evidence pool to self; or load+collect contraband as non-cop | HIGH |
| dispatch/MaxTac (`fn_handleDispatch.sqf:8`, `fn_maxtacRegistered.sqf:10`) | — | spam fake cop dispatches / trigger MaxTac deploy anywhere | MED |

**🔴 Gang authority + cross-player asset theft (no DB rank/membership/ownership check)**

| Fn (CfgRE) | File:line | Exploit | Sev |
|---|---|---|---|
| `APS_fnc_removeGang` (508) | `fn_removeGang.sqf:6,9` | `[player,"",rivalGangID]` → **disband any gang** | CRIT |
| `APS_fnc_transferGangOwnerSRV` (667) | `fn_transferGangOwnerSRV.sqf:11,14` | `[victimLeaderUID,myUID]` → **steal leadership** (sets attacker gangrank0=1) | CRIT |
| `APS_fnc_updateGangMem` | `fn_updateGangMem.sqf:12` | demote a leader / kick / self-promote | CRIT |
| `APS_fnc_gangBank` (517) | `fn_gangBank.sqf:75` | `[1,rivalGangID,player,-funds]` → **drain any gang bank** (only a balance gate, NO rank check) | CRIT |
| `APS_fnc_gangGarageAddSRV` | `fn_gangGarageAddSRV.sqf:6` | `[myGangID,player,VICTIM_UID,VICTIM_PLATE]` → steal a garaged car | CRIT |
| `APS_fnc_gangGarageStore` | `fn_gangGarageStore.sqf:7,21` | store a rival's **live** vehicle into your gang garage | HIGH |
| `APS_fnc_vehOwnerSwap` | `fn_vehOwnerSwap.sqf:9` | `[player,ANY_veh,0]` → transfer any vehicle's DB ownership+key to self | HIGH |
| `APS_fnc_srvChopShopSell`→`fn_chopShopSell` | `system/fn_chopShopSell.sqf:36` | `[player,ANY_veh,price]` → destroy any owner's vehicle (no possession/at-chop check) | HIGH |
| `APS_fnc_keyManagement` (mode 1) | `fn_keyManagement.sqf:14` | `[player,ANY_veh,1]` → give self a working key to any vehicle | HIGH |
| `APS_fnc_gangGarageSetActive` | `fn_gangGarageSetActive.sqf:12` | pull a rival gang's stored vehicle | HIGH |
| gang house/tag/talents/info (`fn_setGangTagSRV.sqf:13`, `fn_getGangInfo`, `fn_update1GangTalents`, `fn_addGangHouse`/`changeGangHouseSRV`/`removeGangHouseSRV`) | — | spoof/strip any gang's tag/house/talents; dump rival roster UIDs (recon) | MED |

**🟡 Admin-impersonation / info / restart (MED)**
- `APS_fnc_adminPlayerQuerySRV` (`:7`) — no admin check → dump any player's cash/bank/levels.
- `APS_fnc_adminMsg` (`:9`) — no admin check → impersonate a staff broadcast.
- `APS_fnc_economySRV` (`:14`) — owner check is on a **passed object** → spoofable if owner online.
- `APS_fnc_changeServCycle` (`:40`) — gates the repack+deploy on a client-passed UID string.
- `APS_fnc_handlePrisonBreak` — any civ starts/stops prison breaks.

**SAFE (verified by the sweep — don't re-flag):** `fn_seizeLock` (`remoteExecutedOwner`), `fn_govSystemSRV`
(appoint/law/vote re-validated), `fn_transferHouse`/`fn_addHouse` (DB-verify unowned + refund),
`fn_vehicleStore.sqf:77` (`_uid==getPlayerUID _unit`), `fn_vehicleSetActive` (own-pid only), `fn_copSplit`
(payees server-filtered to west+alive), `fn_banPlayer` (inert stub), `fn_changeWeather`/`fn_cartelSRV`/
`fn_doRestart`/`fn_hardRestart` (server-state). ⚠ `fn_adminKickBan` checks `getPlayerUID _caller` of a
**passed object** → an attacker passing a real admin's object could kick/ban "as" them (harden).
⚠ Legacy `core/politics/fn_vote.sqf` has NO duplicate-vote guard (vote-stuffing) — appears superseded by
`govSystemSRV`; **confirm it's not still CfgRE-reachable**.

### 2.3 SQL injection / unvalidated client data / more namespace
**Systemic:** `DB_fnc_asyncQuery` is **unparameterized** — every query is a `format[]` string. The legacy
sanitizer **`KRON_Replace` is mission-only → UNDEFINED on the dedicated server** (confirmed: comment at
`DB/fn_insertRequest.sqf:16`; still called by `fn_insertWanted.sqf:14`/`fn_update.sqf:28`) → those paths
get ZERO escaping (or nil-corrupt the value). The safe pattern (`splitString "'" joinString "''"` / a
`_san`) is used by SOME fns; the ones below interpolate a **client `_uid`/`_gangID`** raw. `remoteExecutedOwner`
is used in only **2 of ~150** client-callable fns → almost nothing verifies the actor.

**🔴 SQL injection — client UID/ID raw into queries (re-verified: gangBank + KRON_Replace).** Payloads:
`' OR '1'='1` and `UNION SELECT`.

| Fn | File:line | Impact |
|---|---|---|
| `APS_fnc_gangBank` | `fn_gangBank.sqf:43,116` | `_targetUID`/`_gangID` → `bankacc+=N WHERE '1'='1'` = **credit EVERY player's bank**; exfil via gang queries |
| `APS_fnc_gangBHistory` | `fn_gangBHistory.sqf:15` | `_gangID` → `UNION SELECT playerid,bankacc…` **exfiltrates any column** (reply returns to caller) |
| `APS_fnc_exchangeSystemSRV` | `fn_exchangeSystemSRV.sqf:66,110…` | client `_uid` (≠`_unit`) raw → exfil/inject; use `getPlayerUID _unit` |
| `APS_fnc_wantedPardon` | `wantedsys/fn_wantedPardon.sqf` | `_uid` → `DELETE FROM wanted WHERE '1'='1'` = **wipe the wanted table** |
| `APS_fnc_transferHouse`/`addHouse` | `fn_transferHouse.sqf:35`/`fn_addHouse.sqf:55` | `_uid` → **mass-rewrite `houses.owners`** |
| `APS_fnc_processMailbox` | `fn_processMailbox.sqf:13,40,47` | `_uid` → read/wipe any mailbox; mass cash/bank writes |
| `APS_fnc_statTableUpdate`/`droneCharges`/`vehicleRepairSRV`/`handleLoadouts`/`updateVehicleMods`/`loginBonusSRV`/`vehicleCreate`/`updateProperty`/`gangGarageStore`/`gangGarageAddSRV`/`transferGangOwnerSRV`/`updateGangMem`/`changeGangHouseSRV` | (each `_uid`/`_gangID` raw) | per-row → cross-account writes + injection |
| `DB/fn_updatePartial` | `fn_updatePartial.sqf:7,44,52` | `_uid` raw into **every** partial-save `WHERE playerid`; case 20/24 values unescaped (`_d`/`_e` raw) |
| `DB/fn_insertWanted`/`fn_deleteWanted` | (via `bulkAdd`/`wantedRemoveCharge`) | dead `KRON_Replace` → `_uid`/`_name` reach SQL |

**🟡 More namespace / privilege (not in §2.2):**
- `APS_fnc_changeServCycle` (`:39`) — **any client can force a server RESTART (DoS)**; HARD has no server gate, UPDATE checks a client-passed UID. Agent-1 rated MED; the DoS makes it **CRIT**.
- `APS_fnc_createAdminVeh` (`:10`) — no admin check → spawn any `CfgVehicles` class incl. **armed gunship/tank**, unlocked.
- `APS_fnc_adminDelVeh` (`:10`) — no admin check → despawn any vehicle (grief).
- `APS_fnc_varPersist` (`:7`) — client clears own `AP_banktrace` → evade dirty-cash search.

**🔴 Unvalidated client arrays → item/cash dupe:**
- `APS_fnc_createItem` — `_items` incl. `["money",N]` (also §2.1 CRIT, triple-confirmed).
- `APS_fnc_updateHouseTrunk` (`:9,23`) — client `_vinv`/`_pinv` arrays written to house storage + re-applied → store arbitrary items/qty → re-pull = **dupe**.
- `DB/fn_updatePartial` cases 3/11/12/13 — client gear array persisted + re-applied via `setUnitLoadout` with no item whitelist → respawn with **illegal/restricted gear**.

### 2.4 Consolidated — ~40 findings collapse to 4 root-cause fixes
The catalogue is large but it's **four bugs wearing many masks**. Fix the roots, not the 40 symptoms:

1. **Server-side caller identity + authz (closes the whole privilege/takeover/DoS/cop/jail/wanted/gang-authority/admin class — ~25 findings).** Add one helper used at the top of every privileged `APS_fnc_*`:
   `_uid = getPlayerUID (objectFromNetId str remoteExecutedOwner)` (NEVER trust a passed object/UID for *who acts*), + DB-backed `isCop`/`gangRank(uid,gid)`/`isHouseOwner`/`isVehicleOwner(uid,plate)`/`isOwnerUID`. Models already in-repo: `fn_seizeLock`, `fn_govSystemSRV`, `fn_stimmySRV`.
2. **SQL escaping / numeric coercion at every client→query interpolation (closes the SQLi class — ~25 findings).** A `_sql = { _this splitString "'" joinString "''" }` wrapper on every client string; force every `_gangID`/numeric param to `[0]`; KILL the dead `KRON_Replace` calls. Better: route all writes through a small set of escaped DB helpers.
3. **Server-authoritative money — debit/recompute, never credit on a client number (closes §2.1 money dupes).**
4. **Item/loadout validation — classname whitelist + qty caps before store/spawn/setUnitLoadout (closes createItem / updateHouseTrunk / gear dupes).**

**Reality check:** the server is **public** (`password=""`) with random players (incl. the known scripter on the CLANKR observe list). These are live-exploitable now. Suggested order: #1 + #2 first (takeover/DoS/SQLi-wipe are the worst), then #3, then #4. None modified yet — awaiting owner's go on what to act on.

---

## 3. Hardening best-practices checklist

Arma 3 / Altis-Life server hardening. ✓ = in place, ✗ = gap, ? = verify.

**Network / config**
- [✓] `verifySignatures = 2` + signed PBOs (run-boot2 signs mission + @AP_server with looneybin key).
- [✗] BattlEye filters are empty log-only stubs (`1 ""`) → BE enforces nothing. §1.3. Author filters + raise action to kick/ban pre-public.
- [✓] `CfgRemoteExec mode=1` (whitelist) + `jip=0` default. ← the only real remoteExec restriction right now.
- [✓] `steam_appid` = 107410 (verified; must stay — see [[loonybin-steam-appid-coexist]]).
- [✗] Admin/RCON passwords committed plaintext + identical in `server.cfg`. §1.4. Move to gitignored secret, split, rotate.
- [⚪] `kickDuplicate = 0` (a 2nd client with the same ID isn't kicked) — consider `1` for public.
- [✓] `enableDebugConsole` restricted to owner UID only (see [[loonybin-owner-uid]]).

**Server-authoritative validation (the core principle)**
- [ ] Every whitelisted server fn validates: caller identity (`remoteExecutedOwner`/`getPlayerUID`), amount bounds, item legality, distance/possession, cooldown — SERVER-side. Audit §2.
- [ ] Money/inventory/bank writes never trust a client-sent number; recompute or bound-check server-side.
- [ ] Permission checks (admin/cop level, gang rank, house/vehicle ownership) re-checked server-side, not just in the client UI gate.
- [ ] All client strings sanitized before SQL/log (single-quote/backtick escaping) — `fn_logIt` does; verify every `DB_fnc_asyncQuery` caller does.

**Anti-cheat / detection**
- [ ] Detection anchored on server-owned signals (DB, real UID, BE/IP), never solely profileNamespace/missionNamespace. (§1.1)
- [✓] Single-fire action server guards (e.g. `if (AP_bank_drilling) exitWith{}`) — pattern to replicate on other one-shot fns.
- [✓] CLANKR: remoteExec-spam + dupe/exploit detection → ban mirror (see [[loonybin-clankr-anticheat]]).
- [ ] Rate-limit / sanity-bound high-value server fns (wire, comp, grants, seize).

---

## 4. Hardening reference — best practices by layer

Defence in depth: an attacker must beat EVERY layer. Today only Layer 2 (CfgRE whitelist) + Layer 4
(server validation, uneven) are real; Layers 1 (BE) and 5 (detection) are stubbed/bypassable.

**Layer 1 — BattlEye (broad net).** ON + maintained filters with KICK/BAN actions (not `1 ""` log-only).
Author `scripts.txt` / `remoteexec.txt` / `setvariable.txt` / `publicvariable.txt` / `createvehicle.txt`
/ `setpos.txt` / `setdamage.txt` / `attachto.txt` / `mpeventhandler.txt` from a community Altis-Life
baseline, then mine be.log for false positives, then raise action to `7` (log+kick+ban). BE catches
script injection CfgRE can't see (it inspects raw command strings). → §1.3.

**Layer 2 — CfgRemoteExec (the RPC whitelist).** `mode=1` ✓. Per-function: set `allowedTargets=0`
(server-only) wherever the fn isn't meant to be client→client; keep `jip=0`. Remove any whitelisted fn
that doesn't actually need remote invocation (smaller surface = fewer holes). Every entry is a door —
audit each (§2).

**Layer 3 — config / signatures.** `verifySignatures=2` ✓ + sign every PBO & mod. Set
`allowedLoadFileExtensions[]` / `allowedPreprocessFileExtensions[]` / `allowedHTMLLoadExtensions[]` to
strict whitelists (block arbitrary file/HTML load → data exfil + UI injection). Strong DISTINCT secret
admin vs command passwords, OUT of the repo (§1.4). `regularCheck`, sane `maxPing`/`kickTimeout`,
`kickDuplicate=1`. `enableDebugConsole` owner-only ✓. DB uses least-priv `looneybin` user (not root) ✓.

**Layer 4 — server-authoritative validation (the core).** THE principle: re-derive/re-check everything
server-side.
- **Identity:** derive the actor from `remoteExecutedOwner` / the real remote unit + `getPlayerUID`.
  NEVER trust a player/UID passed as an argument for *who is acting*. (`APS_fnc_logIt` does this right.)
- **Authorization:** re-check admin/cop/gov/gang-rank/ownership SERVER-side; client UI gates are cosmetic.
- **Money/inventory/stats:** server is source of truth; bound + recompute, never apply a client-sent
  number. Client `AP_cash`/`AP_inv_*` are display caches.
- **Cooldowns / single-fire:** enforce server-side (`if (AP_bank_drilling) exitWith{}` pattern), not
  via client profileNamespace timers.
- **Inputs:** bound numbers (`isNumber`, min/max), validate class/item legality, distance/possession.

**Layer 5 — SQL safety.** Sanitize EVERY client string before `format[]` into a query (escape `'` and
backtick — the `_san` pattern in `fn_logIt`). Encode arrays with mres/str2, read bare (see
[[loonybin-mres-quote-footgun]]). Validate numerics are numeric before interpolation.

**Layer 6 — detection / audit (server-owned only).** Anchor on DB + real UID + BE/IP, never solely
client namespace (§1.1/§1.2). Keep server-side action logging (`APS_fnc_logIt` server-side = the real
audit trail). CLANKR analyzes it; BE-GUID/IP correlation for alts; rate-limit high-value fns; tripwire
vars only a cheat sets. Treat a silent `-FNCALL-` stream from an active player as a tell.

**Layer 7 — operational.** Secrets in gitignored `secrets.json` (chmod 600) — tokens AND passwords.
Signed deploys + PBO backups + version-bump cache-bust (✓). Ban-list mirror to BattleMetrics (✓). Keep
Arma server + BE updated. Periodic re-audit (this doc).

## 4b. Fix status (owner "fix and stage all", 2026-06-23) — STAGE-ONLY, no deploy
- ✅ **toggleNewbieRoles** (takeover) — owner-gated via `remoteExecutedOwner`; non-owner client calls blocked + logged `-SEC-`.
- ✅ **changeServCycle** (DoS) — caller re-derived server-side; UPDATE=owner-only, HARD=server-verified admin ≥3 (DB), spoofable `_uid` arg no longer trusted.
- 🟡 **createItem** (cash/item dupe) — BOUNDED mitigation: structure-validate entries, hard-cap money 10M / items 100k, log oversized. FULL close needs server-authoritative cash (drop-system refactor) — legit death-drops pass `[money, AP_cash]` so money can't be rejected. Flagged for a follow-up. **Superseded 2026-09-26 (mints audit):** client calls get a forced holder class, a virtItemCfg name whitelist, cash only from a dead caller, and per-uid 30-min cash/weight/value budgets -- see the `fn_createItem.sqf` header.
- 🔵 Dead-code confirmed unreachable: `vote`/`submitCandidate`/`GE_`/`offlineComp`/`listHouse`/`politics` are NOT CfgRE-whitelisted → no fix (delete/harden before any re-enable).
- ✅ **All 4 implementation batches STAGED + VALIDATED** (~55 server fns): gang-authority (11) / cop-wanted-jail (16) / vehicle-money (16) / admin-DB (26). Pattern: non-spoofable `remoteExecutedOwner` caller + DB-backed authz (`isCop`/`gangRank`/owner) + `_san` SQL strip + server-recompute/clamp of money + item/loadout validation. Overlap files (`insertWanted`/`deleteWanted`/`updateProperty`) reconciled clean (single edit each). **Validation:** 151 session-modified `.sqf` balance-checked (the 2 paren-flags were string-only false-positives), both PBOs pack-test OK. STAGE-ONLY — not deployed.
- ✅ Also this session: **WAC→DONG rename** (`APS_fnc_dongClient`, `-DONG-` tag) + **SpyGlass REMOVED entirely** (dir, Functions.h tag, 3 `AP_sgA` blocks, `initSpy`, 64 inert `checkIntegrity` guards, `-SpyG-` tripwire, CfgRE `observe`).

**Residuals flagged by the agents (always-safe fixes applied — SQLi/identity closed, amounts bounded; deeper authz left to avoid blocking legit play. Owner decides if worth closing):**
- `createItem` — bounded cap+log; full close = server-authoritative cash refactor. (2026-09-26: now per-uid 30-min budgets, see §4b.)
- `wantedAdd` — civ-vs-civ charge still open (kill-attribution path), now clamped 1–5. `wantedPardon` — self-pardon kept for the gov flow. `wantedBounty` — pays the real caller but can't prove a real arrest (no server restrained/distance check).
- `updateGangMem` — same-gang rank-hierarchy left to the client gate; self-join has no invite verification (low impact: gang chat/house spawn).
- `chopShopSell`/`vehOwnerSwap` — chop legitimately destroys/claims OTHERS' vehicles, so gated to chop-zone+claimable (no possession req). (2026-09-26 mints audit: a chop pays only when its parameterised DELETE removed the vehicle's real row -- owner + plate + class; `vehicleCreate` registers an ND-only vehicle only against a server-seen ND debit; ND sell-back/chop of ND classes also sold for cash is capped at 20 ND/h per uid. mints2 follow-up: the other two row-registration doors are closed too -- `recoverWreck` re-inserts a row only if the stamped owner's row of THIS class still exists or `vehicleDead` really deleted it (a localNamespace wreck ledger, spent once; a cop seize files none), and a client `gangGarageStore` needs the gang's or caller's row of THIS class already on file. Server-only fab progression/schematics and the rig kind moved off the unit into localNamespace: a client's public setVariable overwrites a same-named UNpublished object var on the server too.) `medSupplyPay`/`medicSplit` — payee not server-derivable → amount bounded instead. `eventGunGame` — can't verify the 15th kill → restricted to self-award during a live event. `keyManagement` mode 3 — revoke-only.
- `vehAddAlarm` — escape-only (alarm flag still flippable, cosmetic). `vehicleRepairSRV`/`loginBonusSRV` — SQL/cross-account closed; gang-repair-authz remains (§2.2 class); the loginBonus reward is server-derived from the tier row since 2026-09-26 (mints audit).
- All blocked exploit attempts now log `-SEC-` → wire CLANKR to auto-ban repeat offenders.

## 4c. Post-batch CfgRE `allowedTargets=2` gap audit (2026-06-23, code-verified)
Coverage check of all **144** `allowedTargets=2` fns (the client→server remoteExec surface) against the §4b
batch. Full table + confirmed-hardened/needs-review lists: companion **`security_cfgre_audit.md`**.

**Coverage:** 144 total → **~78 confirmed hardened** (gang/cop/jail/admin/most-money genuinely closed) ·
**14 verified GAPS** (3 CRIT / 4 HIGH / 7 MED) · ~40 NEEDS-REVIEW (unread / `AP_fnc_*` passthroughs).
Survivors = the generic DB **save-layer** (batch touched it for SQLi, not identity), old-style `system/`
fns, and thin alias passthroughs.

**Verified CRIT/HIGH (read in code, not agent-asserted):**

| # | Fn | File | Gap | Sev |
|---|---|---|---|---|
| 1 | `DB_fnc_updatePartial` | `DB/fn_updatePartial.sqf:7,14,58-59` | client `_uid` → `WHERE playerid`; case 6 = cash/bankacc. `[player,civ,VICTIM,6,0,0]` **zeroes any player**. SQLi was closed (`_san` :14), **identity was not**. | CRIT |
| 2 | `DB_fnc_updateRequest` | `DB/fn_updateRequest.sqf:6,8,36` | client `_cash`/`_bank` → self-enrich 999M; **AND cross-account** — `_uid=getPlayerUID _player` trusts a passed object → pass a victim → overwrite their money/name/talents. | CRIT |
| 3 | `APS_fnc_vehicleDelete` | `system/fn_vehicleDelete.sqf:11,18` | `_pid` (string) raw into `DELETE … WHERE pid='%2'` → `' OR '1'='1` **wipes the entire `vehicles` table**; `_vid` numeric-safe. Then credits passed `_unit`. | CRIT |
| 4 | `APS_fnc_handleWireTransfer` | `TON/fn_handleWireTransfer.sqf:10-13` | credits `_receiver`, **no server debit** → `[9.99e6,any,accomplice]` **mints ≤10M/call**, unlimited. | HIGH |
| 5 | `APS_fnc_updateHousePrice` | `TON/fn_updateHousePrice.sqf:8,15` | **no ownership check** → relist/reprice/**steal** any house ($0 listing → cheap buy); string `_id` → SQLi. **§2.1 "SAFE" tag was WRONG** (corrected). | HIGH |
| 6 | `DB_fnc_insertRequest` | `DB/fn_insertRequest.sqf:7,11,24` | `_uid` raw into INSERT + ban-check SELECT (only `_name` escaped :20) → SQLi on the new-player path. | HIGH |

**Corrections to the agent's pass (each re-verified in code):**
- `updatePartial` fix is **NOT** `getPlayerUID _player` — `_player` is itself a spoofable passed object. Must
  use `remoteExecutedOwner` (server-internal `_src==0` → keep `_player`).
- `updateRequest` is **cross-account**, not "self-only" (same spoofable-`_player` hole) — same fix.
- `vehicleDelete` is **full-table-wipe** capable (string `_pid` SQLi), worse than "delete any row".
- `updateHousePrice` is a **HIGH gap**, contradicting §2.1's SAFE list — tag corrected.

**Root cause (extends §2.4):** survivors are (1) **identity-by-argument** (save-layer + aliases trust passed
`_player`/`_uid`/`_caller`), (2) **value-authority** (client money number), (3) **residual SQLi** in 3 files
the batch skipped (`vehicleDelete`/`updateHousePrice`/`insertRequest`).

**Fix plan, by confidence:**
- **Surgical + 100%-confident** (proven `remoteExecutedOwner`/`_san`, won't break legit flows): `updatePartial`
  identity · `updateRequest` identity · `insertRequest` `_san _uid`.
- **Needs ownership-lookup verify before staging:** `vehicleDelete` (`_san _pid` + caller-owns-`_vid`, or gut
  if dead legacy) · `updateHousePrice` (numeric `_id` + caller==owner via `AP_house_owners`).
- **Defer to the cash refactor (CLANKR cash-delta holds):** `updateRequest` value-authority +
  `handleWireTransfer` mint — both client-trusted money numbers, same root as `createItem` (§4b).

**MED (7) — identity-gate aliases/spoof/spam:** `queryRequest` (force-reload nuisance), `insertGang` (deduct
victim 25k), `discordEmbed` (server-webhook spam/impersonation), `handlePhoneMsg` (spoof cop/admin msg),
`registerMaxTac` (non-cop MaxTac), `fedRobbery`/`bankRobbery`/`add2Lotto` (alias griefs — `bankRobbery`
known-guarded), `medSupplySpawn` (object spam). Detail in `security_cfgre_audit.md`.

**Status:** all gaps **pre-existing** (live in b0091; batch is staged, not deployed). Recon only — **nothing
staged from this audit.** Awaiting owner's go on fix-timing.

## 5. Sweep log
- **2026-06-23** — §1.1 profileNamespace AC bypass confirmed + logged (owner-reported). §1.2 (`-FNCALL-`
  client-disable), §1.3 (BE log-only stubs), §1.4 (committed admin secrets) added. §4 hardening reference
  written. 3 parallel agents sweeping the §2 client-trust surface (money/value, permission/identity,
  namespace/SQL) — results pending.
- **2026-06-23 (cont.)** — §2.1 money/value sweep DONE: 3 CRIT money-printers (`createItem` arbitrary
  cash/item pile, `chopShopSell` client price, `exchange` BUY client price) all independently re-verified
  by reading the code; 5 HIGH, 2 MED, 2 LOW + loveBomb grief + dead-GE flag. Root cause = "client debits
  itself, server credits".
- **2026-06-23 (full picture)** — §2.2 (permission/identity) + §2.3 (SQLi/namespace/data) sweeps DONE
  (agents re-run after the session-limit cutoff). Verified personally: `toggleNewbieRoles` = server
  takeover (armed, OFF/unused live), `gangBank` SQLi (`_targetUID` raw → credit-everyone), `KRON_Replace`
  = server-side no-op. ~40 findings total → collapse to 4 root-cause fixes (§2.4): (1) server-side caller
  identity+authz, (2) SQL escaping/numeric coercion, (3) server-authoritative money, (4) item/loadout
  validation. Awaiting owner's go on what to act on (#1+#2 worst — takeover/DoS/SQLi-wipe).
- **2026-06-23 (post-batch gap audit)** — §4c added. Background fork audited all **144** `allowedTargets=2`
  fns vs the §4b batch → ~78 hardened, **14 verified GAPS** (3 CRIT/4 HIGH/7 MED), ~40 needs-review. CRIT/HIGH
  re-read in code by me; **4 agent corrections** (updatePartial fix needs `remoteExecutedOwner` not
  `getPlayerUID _player`; updateRequest is cross-account; vehicleDelete `_pid` SQLi = full-table-wipe;
  updateHousePrice SAFE tag wrong → §2.1 corrected). Survivors = DB save-layer identity + value-authority +
  3 missed-SQLi files. Companion `security_cfgre_audit.md`. Nothing staged — owner decides fix-timing.
- **2026-06-23 ("free house keys" exploit, owner-reported brag)** — house storage (`AP_vinv`/`AP_pinv`)
  was broadcast GLOBAL at all times → any client read/self-copied any house's stash (the bragged
  `asyv_tempHouseKeys`-class read; live var = `AP_vinv`). **LIVE mitigation (shipped):** CLANKR -HOUSEINV-
  unauthorized-access **auto-ban** (was alert-only) — unowned shed / confirmed tent / ≥2 distinct houses,
  admins exempt, FP-safe. **Code fix (STAGED, option B "hydrate-on-gated-open"):** house storage now
  SERVER-LOCAL at rest (`fn_receiveHouses`) so clients hold nil; `APS_fnc_initHouseInventory` = gated hydrate
  chokepoint (owner/keyholder/gang/cop via `remoteExecutedOwner`, else `-SEC-`); `fn_updateHouseTrunk`
  dehydrates on close + now allows cop-persist; cop search/seize hydrate-on-demand. Linchpin: house storage
  persists ONLY via `updateHouseTrunk` (2 callers, no periodic all-house save) → dehydrate-on-close is
  lossless. Residual: readable only during an active authorized open (bounded by single-open + CLANKR-logged).
  Option A (full per-client targeted) deferred — high dupe-regression risk on the ~15 shared mutation sites.
  Detail: [[loonybin-house-storage-broadcast-fix]].


## profileNamespace code-execution vector — FIXED 2026-07-20

**The finding.** `core/pmenu/fn_setFavApp.sqf` persisted *entire* phone-app entries into
`profileNamespace` (`AP_favApps`) and `saveProfileNamespace`. An entry is
`[_text, _image, _function, _condition, _tooltip]` where **`_condition` is CODE** and **`_function` is an
action STRING**. On every phone open `fn_p_openMenu` did `if (call _condition)` and
`_button ctrlAddEventHandler ["ButtonClick", _function]`.

`profileNamespace` is **client-writable** (script executor, or just editing the local
`*.Arma3Profile`). So a tampered profile could plant arbitrary SQF that the mission itself executed on
every phone open — and it **persisted across mission updates, restarts and redeploys**, because the
stored copy shadowed whatever the new PBO shipped.

Direct impact is client-local execution, but it is a real foothold: the injected code runs inside the
mission's own context with the player's identity, so it can drive any CfgRE-whitelisted remoteExec
target. It also silently defeated gate changes (a re-gated app kept its OLD condition — this is how
ICEBREAKER OS stayed on a MaxSec phone after the side-gate shipped).

**The fix.** Favourites now store **names only**, under a new key `AP_favApps_v2`, and
`fn_p_openMenu` re-resolves each name against the LIVE `AP_phone_buttons` + global list at open time.
Unknown names are dropped. The legacy `AP_favApps` key is never read again, so previously-planted
payloads are inert.

**Audit result for the rest of the mission (same date):**
- No other site stores CODE in `profileNamespace` (the only `setVariable` containing `{` is an `apply`).
- No profile-derived value reaches `compile` / `execVM` / `callExtension`.
- The one dynamic `compile format[...]` (`fn_inventory.sqf`) interpolates a local param via `str()` plus a
  `missionConfigFile` boolean — not profile data, and client-local.
- Non-code, self-only: wallpaper path (`PLBClientSettings`) feeds a texture path; `AP_msgThreads` feeds
  `parseText` markup. Neither executes.

**Rule going forward: never persist CODE or action strings in `profileNamespace`. Store an identifier and
resolve it against mission-side data at use time.**
