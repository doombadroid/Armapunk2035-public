# LooneyBin Dev Lessons — Distilled from a Reference Mission

These are debranded, actionable lessons extracted from a decompiled reference Altis Life mission and mapped onto LooneyBin's actual files/functions. Each lesson states the reference **technique**, **why** it beats LooneyBin's current approach, and **how to apply** it. Source server names have been stripped throughout; it is only ever "the reference mission."

---

## Top priorities (dupe / exploit / data-loss prevention)

Do these first — they close money-minting, cartel-theft, and dupe/loss holes.

1. **Wire-transfer is an unauthenticated money printer.** `APS_fnc_handleWireTransfer` credits the receiver with zero proof the sender was ever debited, and it's remoteExec-whitelisted. Port the atomic deduct-before-credit + nonce handshake. *(Client→server security #1)*
2. **Cartel ownership is client-authoritative.** `fn_captureCartel.sqf` lets a client `setVariable ['AP_capData', …, true]` and name the owning gang; the server monitor is inert. Repair the server monitor and make the client read-only. *(Cartel #1, #2)*
3. **The server capture loop is dead.** `fn_monitorCaptures.sqf` reads `list capture_N` on trigger objects that don't exist on the live map → detects nobody → authority fell back to the exploitable client path. Switch presence to `nearEntities` off the existing `*_flag` objects. *(Cartel #1)*
4. **Sell price has no upper bound and no tamper detection.** `fn_virtualShopManage` sell path can be driven with a spoofed price for arbitrary payout, silently. Add per-unit + absolute ceilings that log + kick. *(Economy #2)*
5. **The money integrity cache is dead code.** `AP_cashCacheB` / `AP_atmcashCacheB` are written but never read back anywhere. Turn them into a live tripwire behind a single `AP_fnc_addMoney` choke-point. *(Economy #1)*
6. **Trunk/storage save races a restart.** No near-restart open-block and no last-instant re-check before the destructive cargo write — the documented trunk-dupe/persistence-loss TOCTOU class. Add a restart-window lockout + re-sample the save flag right before the write. *(Inventory #4, Houses #1)*
7. **Desynced containers become loot fountains.** No factory-default cargo comparison on trunk open; a hydrate failure leaves a truck full of config-default `TransportItems` that a player can loot every time it recurs. Add a default-cargo wipe-on-match. *(Inventory #1)*

---

## Virtual inventory + house / vehicle / container storage (dupe / loss prevention)

### Wipe factory-default cargo before it can be duped out of a desynced container
- **Technique:** On every trunk open, cache each vehicle type's config-default physical loadout in a hashmap (built from `TransportItems/Magazines/Weapons/Backpacks`), read the container's live `getItemCargo/getMagazineCargo/getWeaponCargo/getBackpackCargo`, sort both, and if live cargo is byte-equal to a **non-empty** default, `clearWeapon/Magazine/ItemCargoGlobal` and refuse the open with a logged event.
- **Why:** When a stored trunk fails to hydrate (extDB desync/timeout), Arma repopulates the vehicle's physical cargo with config defaults. `fn_openInventory` has no default-cargo comparison, so a hydrate failure leaves factory gear silently lootable every time the bug recurs.
- **Apply:** Add a helper (cache CfgVehicles defaults per type; compare sorted live cargo) and call it in `fn_openInventory` before showing the trunk for Car/Air/Ship; on exact non-empty match, clear physical cargo, log `-BUGGEDINV-` via `APS_fnc_logIt`, abort the open. *(high)*

### Self-healing trunk mutex via an explicit holder-online test
- **Technique:** Store the mutex as the holder's UID string; before blocking a new opener, test `(allPlayers findIf {getPlayerUID _x == held}) != -1`. If the holder is offline, ignore the stale UID and let the new player in.
- **Why:** LooneyBin's mutex is the holder's player **object** (`AP_activeTrunk` at `fn_openInventory:153`, blocked at `:181`). That only clears on engine unit deletion — not guaranteed on a hard crash, and never clears for a still-connected holder whose close-watcher died (script error, teleport), permanently locking the house/shed to every other keyholder until restart.
- **Apply:** Store `AP_activeTrunk` as `getPlayerUID` (string); in the block branch (`:181`) and its watcher, refuse only when held UID is non-empty **and** the holder is still in `allPlayers`. *(medium)*

### Expiring time-lease with heartbeat for the per-session container lock
- **Technique:** Store the lock as `[holderUID, serverTime+180]`. Block a new opener only if `holder notin [me,''] && expiry > serverTime`. The open-watcher refreshes the lease when within 10s of expiry and clears it on close; the scrap/save path reads it the same way.
- **Why:** A pure boolean/object lock (`AP_activeTrunk` / `AP_trunkLock`, and the `_fnRelease` in `fn_vehicleToHouseStore.sqf`) is only released if the releasing path actually runs; a killed spawn or wedged client wedges the container indefinitely. A `serverTime` lease auto-expires so no failure mode wedges forever, while the heartbeat protects a genuinely-active session.
- **Apply:** Replace the boolean/object reservation with `[uid, serverTime+N]`; check `expiry > serverTime` to block, refresh from the open-watcher loop (`fn_openInventory:166`, `fn_vehicleToHouseStore`), treat expired as free. *(medium)*

### Re-check the save/restart lock at the last instant before the destructive write
- **Technique:** The scrap/save path raises `trunkLocked` up front, runs its confirm dialog + progress bar, then **re-checks** `restartLock` immediately after the bar completes and right before `clearCargoGlobal` + the Trunk write — aborting if a restart-drain began meanwhile. `trunkLocked` is cleared in every exit branch.
- **Why:** A mutation gated only by a start-of-op check is a TOCTOU hole: a restart save-sweep or another writer can begin during those seconds and clobber freshly-persisted state. LooneyBin raises `AP_trunkLock` + a fixed `uiSleep 1.25` settle before persisting (`fn_openInventory:375-388`) but never re-samples a save-in-progress flag right before the write.
- **Apply:** At `fn_openInventory` close-save (`:383`) and the `fn_vehicleToHouseStore`/`fn_houseToVehicleStore` deposit loops, re-read a server-broadcast "restart/save in progress" flag immediately before the final `APS_fnc_updateHouseTrunk`/cargo write and abort if it changed; release the lock on every early-exit. *(medium)*

---

## Client → server call security (remoteExec gating, non-spoofable caller validation, money/item transfer)

### Atomic deduct-before-credit transfer with a random-nonce challenge
- **Technique:** The receiver never credits on trust. It builds a random per-transfer key, remoteExecs an **atomic debit** onto the sender's machine (debit only if `balance >= value`), and the sender calls back `[key, ret]` only on a real debit. The receiver `waitUntil` (max 5s) for that keyed reply and credits only if `ret` is true; timeout increments a strike counter. The random key stops the receiver pre-setting a fake success.
- **Why:** `APS_fnc_handleWireTransfer` is a pure passthrough — it credits up to $9,999,999 with **zero** check that the sender was debited or even had the funds, and it's remoteExec-whitelisted (`allowedTargets=2`), so a hacked client calls it directly with any sender/receiver to mint money.
- **Apply:** In `server/AP_server/core/TON/fn_handleWireTransfer.sqf` + `core/functions/fn_receiveMoney.sqf`, either have the server hold+debit+credit both balances itself, or port the nonce-keyed "verify the sender actually lost the money" handshake before crediting. *(high)*

### Assert `remoteExecutedOwner` == the caller's *claimed* network id
- **Technique:** Take a client-supplied `_fromID` and `if !(remoteExecutedOwner isEqualTo _fromID) exitWith { …flag… }`. `remoteExecutedOwner` is engine-set and unforgeable, so comparing it to the claimed id proves the caller is that machine before any money moves.
- **Why:** `fn_receiveMoney` only checks `remoteExecutedOwner isEqualTo clientOwner` (self-credit block); `handleWireTransfer`/`fn_receiveItem` never verify the caller matches the claimed `_from`, so a client can pass an arbitrary sender and be believed.
- **Apply:** In `fn_receiveMoney` / `fn_receiveItem` / `fn_handleWireTransfer`, pass the sender's `owner`/`clientOwner` explicitly and reject unless it equals `remoteExecutedOwner`; route mismatches to the existing `APS_fnc_dongClient` funnel. *(high)*

### Reject broadcast/JIP-context calls (`remoteExecutedOwner == 0`) in money receivers
- **Technique:** Guard `if (remoteExecutedOwner isEqualTo 0) exitWith {}`. Owner 0 means the call didn't arrive from a specific directed client (JIP queue / broadcast), which would sidestep per-caller identity checks.
- **Why:** LooneyBin's money receivers validate `!= 2` / `== clientOwner` but never exclude the ambiguous owner-0 context, leaving a path where owner-based validation is meaningless.
- **Apply:** Add the guard at the top of `fn_receiveMoney`, `fn_receiveItem`, `fn_clientWireTransfer` and other value-crediting receivers. *(medium)*

### Detect "funds reported but balance did not change" as a tamper signal
- **Technique:** Capture balance before and after the debit; if it reported success yet the balance is unchanged on a meaningful amount, fire a dedicated flag. Log every funds check (before/after/requested/key/sender) regardless of outcome.
- **Why:** Catches a client that hooked its own deposit fn to "succeed" without losing money — invisible to a simple `balance >= amount` check. LooneyBin's transfer paths do no before/after delta assertion.
- **Apply:** When a client-side debit is part of a transfer (`fn_bankTransfer`/`fn_giveMoney`), snapshot the balance and emit a `APS_fnc_dongClient` flag if the succeeded-but-no-delta case occurs. *(medium)*

### Route hardcoded value-cap violations into the anti-cheat funnel with per-session escalation
- **Technique:** Cap each transfer mode server-side; on breach, report through the centralized flag fn (`Hacked Money Transfer | %1`) and escalate via a per-session strike counter — not a silent UI exit.
- **Why:** LooneyBin caps client-side in `fn_giveMoney`/`fn_bankTransfer`/`fn_clientWireTransfer` with a plain `exitWith` + chat message and no server-side flag; a scripted client that skips the dialog and hits the server fn directly trips nothing.
- **Apply:** In `fn_clientWireTransfer`/`handleWireTransfer`, when `_val` exceeds the cap, emit a `APS_fnc_dongClient` flag (funnel already exists) instead of silently exiting; add a per-session strike counter. *(medium)*

---

## MaxSec / cop — arrest, jail, bail, restraint, contraband

### Gate bail behind a minimum time served
- **Technique:** On jail entry set `canpay_bail = false` + `bailUnlockTime = time + 600`; the jail loop flips it true only once `time > bailUnlockTime`. The post-bail fn short-circuits while the flag is set.
- **Why:** `fn_postBail.sqf` lets a prisoner pay full bail the instant they hit the cell (only guard is `AP_bail_paid` + a cash check), so any cash-rich player skips prison on every arrest and jail time is meaningless.
- **Apply:** In `core/civilian/fn_jailMe.sqf`, set `AP_canPayBail = false` + `AP_bailUnlockTime = time + 600` on entry and flip it in the jail loop; gate `core/actions/fn_postBail.sqf` with `if !(AP_canPayBail) exitWith { … };`. *(high)*

### Clamp bail to a hard floor and ceiling
- **Technique:** `bail = bounty min 2000000 max 62500` — raw bounty clamped into `[62.5k, 2M]`.
- **Why:** `fn_jailMe.sqf:27` sets `AP_bail_amount = _bounty` with no bounds: a trivially-wanted prisoner bails for pocket change (jail is free) while a mega-bounty faces an unpayable bail.
- **Apply:** In `core/civilian/fn_jailMe.sqf`, `AP_bail_amount = _bounty min 2000000 max 62500;` (tune to LooneyBin's economy). *(high)*

### On excessive-restraint auto-release: notify + reset restrainer + log
- **Technique:** When restraint exceeds the limit (15 min), clear the vars, titleText the detainee, remoteExec a warning to the restrainer, fire an analytics event with both UIDs/positions, and re-run the cop's gear-reattach.
- **Why:** `fn_restrainAction.sqf:49-76` has the 10-min limit but the loop just silently ends — no feedback to the cop, no audit trail of who over-held a detainee.
- **Apply:** In `core/actions/fn_restrainAction.sqf`, on the timeout branch remoteExec a message to `_enforcer` and spawn a `APS_fnc_logIt` `-RESTRAINTIMEOUT-` row with both UIDs/positions, mirroring the `-RESTRAIN-` log in `fn_restrain.sqf`. *(medium)*

### Keep prisoners at walking pace with `forceWalk`
- **Technique:** Every jail tick `if !(isForcedWalk player) then { player forceWalk true };`, dropped with `forceWalk false` on release.
- **Why:** LooneyBin's jail loop only reacts after the fact (teleport back via `inPolygon AP_jailPoly` once they've already left). Forcing walk makes boundary-hugging and escape-timing far slower, complementing the poly teleport.
- **Apply:** Add the `forceWalk true` line to the `fn_jailMe.sqf` jail `while` loop and `player forceWalk false;` right after loop exit. *(low)*

### Re-derive the sentence from a server-authoritative bounty at jail entry
- **Technique:** Nil the server bounty, remoteExec a request to the server, `waitUntil {!isNil …}`, and derive `_jailTime`/bail from that value — falling back to the saved pair only on JIP resume or empty fetch.
- **Why:** `fn_jailMe.sqf:11-19` computes `_jailTime` purely from the **client** `A_stats_crimes` array (`AP_fnc_wantedPerson` is a stub), so a tampered client shortens its own sentence.
- **Apply:** Have the server (`AP_fnc_wantedPerson` or a new `APS_fnc` getBounty) return the authoritative bounty+sentence before the loop; derive `_jailTime`/`AP_is_arrested[2]` from it, keeping the client array only as JIP/relog fallback. *(low)*

---

## Cartel capture / gang / turf / gang wars / gang funds

### Detect cartel presence with `nearEntities` + per-player flag, not a named trigger's `list()`
- **Technique:** A player-attached EmptyDetector sets only a self boolean (`cappingCart`) on entry; the authoritative side computes cappers via `_flag nearEntities ['CAManBase',100] select {isPlayer _x && _x getVariable ['cappingCart',false]}`. No dependency on pre-placed named zone objects.
- **Why:** `server/AP_server/core/system/fn_monitorCaptures.sqf` reads presence via `list (missionNamespace getVariable ['capture_N', objNull])`. Those `capture_N` objects don't exist on the live map, so `list objNull` is always `[]` → the server loop is **inert**, which is why ownership fell back to the client-authoritative path.
- **Apply:** Replace the `capture_N`/`list` presence source with `nearEntities` off `arms_flag`/`drug_flag`/`oil_flag`/`wongs_flag` (which already carry `AP_capData`) so the server loop reclaims authority. *(high)*

### Keep the capturing client READ-ONLY on progress/ownership
- **Technique:** The capture UI loop only **reads** `_flag getVariable 'capture_data'` to drive the bar and status; it never writes progress or owner.
- **Why:** `core/gangs/fn_captureCartel.sqf` computes progress on the client and writes `_flagObject setVariable ['AP_capData', […], true]` as a public variable, picking owner client-side. `APS_fnc_cartelSRV` mode 3 arrives with `_value=-1` and hits the `if (_value<=0) exitWith` guard, so the server never records ownership — a modified client owns any cartel for any gang id (the SNEED/client-trust class).
- **Apply:** In `fn_captureCartel.sqf`, stop the client writing `AP_capData`/owner; send only "I am capping" intent and make the repaired `nearEntities`-based `monitorCaptures` the sole writer. *(high)*

### Graduated contest rate as one pure function (N-gang aware, 3:1 push-through)
- **Technique:** Bucket cappers into a `gang → units` hashmap, find top-two by headcount, return `[rate, controllingGang]`: rate `1.0` (one gang) / `0.5` (dominant ≥3× the second) / `0` (contested). All UI status strings derive from that rate.
- **Why:** LooneyBin has contest logic **duplicated and binary** in two places (server `count _totals == 1` → decay 0.1; client "any enemy nearby fully stalls"). Neither supports a dominant force pushing through, and the copies can disagree.
- **Apply:** Port the headcount/top-two/superiority model into `fn_monitorCaptures` as the rate source; let `fn_captureCartel`'s UI read the resulting rate/status. *(medium)*

### War-invite send-path rejects already-at-war and uses a persistent decline list
- **Technique:** The send fn guards: target already at war, target gang id `0`, same gang, target rank ≥3, and target in a persistent `declinedWars` set. The receiver pre-adds the target to its decline set so a refused gang can't be re-spammed.
- **Why:** `core/gangs/fn_challengeWar.sqf` checks in-gang, self rank, a 5-min cooldown, and a valid selection, but does **not** reject challenging a gang you're already at war with and has no "already declined" suppression — so war spam resumes once the 5-min timer lapses.
- **Apply:** In `fn_challengeWar.sqf`, add an already-at-war check against the client war list and a persistent declined-set check before sending; have `fn_warChallenged`/decline record the refusing gang. *(medium)*

### War invites expire (auto-decline) instead of lingering forever
- **Technique:** The invite shows then `waitUntil {uiSleep 1; !isNil 'AP_warResponse' || _timer <= time}` with `_timer = time + 60`; on timeout it auto-declines.
- **Why:** `fn_warChallenged` pushes into `AP_gang_challenges` with **no expiry**, so a stale challenge from a since-disbanded/renamed gang can be accepted much later, creating a war against data that no longer matches.
- **Apply:** In `fn_warChallenged.sqf`/`fn_acceptWar.sqf`, timestamp each queued challenge and expire it after a fixed window (~60s) so acceptance can't act on stale data. *(medium)*

### Client-side TTL cache for gang panel data
- **Technique:** Store gang exp/level/perks as `cachedGangExpData = data + [time + 30]`; re-query only when `cache#3 <= time`.
- **Why:** `core/gangs/fn_gangMenu.sqf` fires `APS_fnc_getGangInfo` (a DB read) on **every** menu open with no TTL, so repeatedly opening/closing the panel spams the DB.
- **Apply:** Cache the `getGangInfo` result with a short expiry and skip the round-trip while fresh. *(low)*

---

## Economy — buy/sell validation, dynamic pricing, cartel cuts, money integrity

### One hardened cash choke-point with a checksummed shadow + auto-kick on divergence
- **Technique:** Funnel every cash/atm/inventory change through one handler that keeps a per-value shadow under obfuscated keys with a random offset; on every call it recomputes `expected = real - (shadow - offset)`, and if the real var was tampered outside the handler (divergence > 5000), or the write didn't land, or the call didn't arrive via a legit fn on `diag_stackTrace`, it remoteExecs the stack trace to the server and `endMission "HackedMoney"`. Single cash change hard-capped at 5000/call.
- **Why:** LooneyBin already has the shadow ingredient (`AP_cashCacheB = AP_cash/4 + 9`, `AP_atmcashCacheB = …/4 + 11`) written in several files but **never read back or compared anywhere** — it's dead. Meanwhile `AP_cash = AP_cash + X` is scattered raw across dozens of files with zero integrity check.
- **Apply:** Introduce a single `AP_fnc_addMoney` choke-point that updates cash **and** cache together as the only writer, and flag any divergence as tamper (verify in `core/session/fn_ClupdatePartial.sqf` before sync). *(high)*

### Cap the client-submitted sell price against market-high; auto-kick + log on overshoot
- **Technique:** After computing the sale total, apply two ceilings: absolute (`total > 2,500,000` → log "Hacked Sold Price" + kick) and relative (`price/unit > marketHigh(item) * mod` → same log + kick).
- **Why:** `fn_virtualShopManage` sell path derives `_price` from config but has **no** upper sanity bound and no tamper detection anywhere in buy/sell (grep for `Hacked`/`endMission` in `core/shops`/`core/actions` is empty). A client that spoofs the listbox value, market factor, or config price sells for arbitrary amounts silently.
- **Apply:** In `core/shops/fn_virtualShopManage.sqf` sellItem, after `_price = round((_price + _addBuff) * _amount)`, add a per-unit ceiling `(virtItemCfg max price) * AP_marketMaxPrem * slack` and an absolute total cap; on breach `APS_fnc_logIt` an exploit event + kick (or at minimum clamp + log for CLANKR). *(high)*

### Re-verify a real dealer/NPC is in range at the moment of sale
- **Technique:** Before payout, `player nearEntities [["Man",…], 10]` and exit if no non-player entity within 10 m, then resolve it to a known dealer.
- **Why:** `fn_virtualShopManage` trusts that the shop dialog being open means the player is at a shop; nothing re-confirms an NPC is nearby when Sell is clicked, so a player can open a shop, teleport away, and keep selling — or script the dialog open anywhere.
- **Apply:** In both buyItem and sellItem, add a ~10 m proximity re-check against the shop's NPC/object class at click time and exit if absent. *(medium)*

### Aggregate cartel/turf tax in a per-session hashmap; settle once on shop close
- **Technique:** Accumulate cartel tax per item in a `uiNamespace` hashmap + a session-sold total; one watcher (`waitUntil isNull findDisplay 2400`) sends a single aggregated cartel-tax remoteExec on close and only emits an analytics event when the session total exceeds a threshold.
- **Why:** `fn_virtualShopManage` mutates `AP_wongsCartel`/`AP_turfTax`/`AP_armsCartel` and calls `ClupdatePartial` + `saveGear` inline on **every** sale — one save/sync per click during a bulk dump.
- **Apply:** Accumulate cartel cuts + a session-sold total in a `uiNamespace` hashmap and flush the cartel credit + heavy save once when display 39500 closes. *(medium)*

### Per-dealer sell cooldown to throttle farming a single dealer
- **Technique:** Stamp `hasSoldAt[index] = time` and refuse another sale at that dealer if `time - hasSoldAt < 1800` (30 min), registering each sale server-side.
- **Why:** LooneyBin's virtual-sell path has only a global `scriptAvailable(0.275)` micro-throttle and an inventory ceiling — no per-dealer cooldown, so a high-value dealer can be hammered continuously.
- **Apply:** For special/roaming/high-payout dealers, track a per-dealer last-sold timestamp and gate re-sales; skip ordinary always-on shops where a cooldown would be user-hostile. *(low)*

---

## Vehicle keys / ownership, world persistence, garage, impound, chop shop

### Eject crew and `waitUntil` empty before `deleteVehicle`
- **Technique:** Before deleting, `{ _x moveOut _vehicle } forEach _crew; waitUntil { uiSleep 0.02; crew _vehicle isEqualTo [] }; deleteVehicle _vehicle;`. Never deletes an occupied object.
- **Why:** `deleteVehicle` on a seated vehicle can leave the occupant broken/stuck or fail to remove the object. `core/cop/fn_impoundAction.sqf`'s ownerless quick-delete path (`if (_vehicleData isEqualTo[]) exitWith { deleteVehicle _vehicle };`) deletes with **no** crew check — a player seated in a glitched/ownerless vehicle gets deleted underneath them.
- **Apply:** Add a moveOut-all-crew + `waitUntil {crew _vehicle isEqualTo[]}` guard before that `deleteVehicle` (the main path aborts on crew; this path skips the check entirely). *(medium)*

### Refund the claim charge via a server-confirmed success handshake
- **Technique:** Deduct money, remoteExec the swap to the server, `waitUntil { AP_claim_done }`, and if `!AP_claim_success` re-credit + clear the rekey flag. The server signals both flags back, so a failed rekey costs nothing.
- **Why:** `core/shops/fn_chopShopClaim.sqf` deducts `AP_atmcash - _claimPrice` (`:103`) then fire-and-forgets `APS_fnc_vehOwnerSwap` (`:107`) with no confirmation and no refund — a failed server swap loses the money.
- **Apply:** Have `APS_fnc_vehOwnerSwap` `publicVariable` a done/success result and refund on failure, mirroring `AP_claim_done`/`AP_claim_success`. *(medium)*

### Block chopping while an enemy (non-gang, non-group) player is nearby
- **Technique:** `allPlayers select { player distance _x <= 10 && (_x gang) isNotEqualTo _playerGangID && group _x isNotEqualTo group player }`; if any, exit with a message.
- **Why:** `core/shops/fn_chopShopSell.sqf` has no nearby-player gate — only distance-to-vehicle and lock flags — so a player can delete stolen/evidence/contested vehicles in the open or mid-fight.
- **Apply:** Add the same within-10 m, not-same-gang, not-same-group check before starting the chop progress bar. *(medium)*

### Guard `isSimpleObject` before manipulating a target vehicle
- **Technique:** `if (isSimpleObject _vehicle) exitWith {};` in impound, flip, and chop flows before any `setVariable`/`deleteVehicle`/progress logic.
- **Why:** Simple objects silently no-op `setVariable` (no network sync) and don't respond to normal manipulation. LooneyBin has **zero** `isSimpleObject` guards in vehicle/impound/chop/store code; any path resolving a target via `nearestObjects`/`cursorTarget`/`objectFromNetId` could receive one.
- **Apply:** Add an early `if (isSimpleObject _vehicle) exitWith {}` alongside existing `isNull`/`alive` checks in `fn_impoundAction`, `fn_chopShopSell`, `fn_chopShopClaim`, `fn_storeVehicle`. *(low)*

### One-at-a-time persistence mark to protect a parked vehicle from idle-reap
- **Technique:** Set `despawn=true` on the vehicle, track `currMarked` on the player, and clear the previously-marked vehicle's flag so only one is protected; gated on a 60s cooldown + key ownership, cleared on disconnect. The reaper honors the `despawn` var.
- **Why:** `server/AP_server/core/system/fn_cleanup.sqf` reaps every idle empty vehicle at a firm 2400s cap with no player opt-out (a recurring "car despawned early" complaint).
- **Apply:** Optionally add a client mark action setting a networked `AP_noReap` var (one at a time, auto-unmark previous); have the alive-vehicle branch `continue` when set. **Note:** the owner deliberately chose the firm 40-min cap — confirm intent before adding. *(low)*

---

## Houses — buy / storage capacity & upgrades / keys / gang sheds / persistence

### Block storage-open in the final minutes before restart; force-close mid-session
- **Technique:** Exit with "Inventory is being saved" when minutes-to-restart `< 5` or the object carries `restartLock`; the open-watcher re-checks the same condition every 0.25s and force-closes the dialog + clears the lock the instant the window/flag trips.
- **Why:** `fn_openInventory` gates only on `AP_trunkLock` + `AP_activeTrunk` — **no near-restart gate**. A trunk opened seconds before a soft/hard restart races the `AP_vinv`/`AP_pinv` save (the repeatedly-hit save-race class).
- **Apply:** In `core/inventory/fn_openInventory.sqf`, add a House_F/vehicle open-block when `serverTime` is within N minutes of the scheduled restart (reuse the soft/hard restart-time state) and add the same check to the watcher loop (~L200) to force-close an open trunk. *(medium)*

### Bind owned-house positions to buildings with a bounded retry, not fire-once
- **Technique:** `waitUntil` that every owned/keyed position resolves to a non-null building (or `diag_tickTime > start+30`), retrying at `uiSleep 0.02`, and only then push into the owned-house array + create markers.
- **Why:** `fn_CLinitHouses` does a single-pass `nearestObjects[pos,["House"],10,true]`; if the building isn't resolvable at that instant the house is silently dropped — no marker **and** not `pushBack`'d into `AP_vehicles`, so T-key storage is dead for that session. This is a real race for industrial sheds `createVehicle`-spawned server-side after `uiSleep 6`: a JIP client running `CLinitHouses` before the shed replicates loses access to its own warehouse.
- **Apply:** Wrap per-position resolution in a bounded `waitUntil` retry (~20-30s), or re-invoke `CLinitHouses` when any position fails, so late-spawning sheds still bind their marker + `AP_vehicles` access. *(medium)*

### Gate storage-open on active-heist zones (and building state)
- **Technique:** Refuse the trunk when the building `inArea` an active robbery zone (e.g. Fed Reserve with `chargeplaced`, plus other heist zones) or when the building is `on_fire`/`locked_down`.
- **Why:** `fn_openInventory` has event guards for airdrop/ufoCrash/winterEvent/tomb but **none** for an active Fed Reserve robbery — a stash house inside the fed zone can shuffle loot in/out during a live heist. LooneyBin already tracks `fed_bank chargeplaced`, so the guard is cheap.
- **Apply:** In `fn_openInventory`, if a House_F is `inArea` an active heist zone with a charge placed, block the open with a message, mirroring the existing airdrop-lock guards. *(low)*

### Strip nil holes from the inventory array before serializing a trunk
- **Technique:** Serialize as `[(_trunk select 0) select {!isNil "_x"}, _trunk select 1]` — drops any nil slot so a sparse/corrupt array can't poison the blob; also logs any malformed write received.
- **Why:** A nil hole reads back as a corrupt entry and can throw on next open or silently drop the whole trunk. LooneyBin's house-trunk save passes `AP_vinv`/`AP_pinv` straight through (`_newVirt`/`_newPhys` → `APS_fnc_updateHouseTrunk`) with no nil-hole strip.
- **Apply:** In the house-trunk save path (`fn_openInventory` close handler / `APS_fnc_updateHouseTrunk`), filter `_inv select {!isNil "_x"}` before persisting. *(low)*

### Require gang activity before a gang building's storage unlocks
- **Technique:** A `bldg_locked` flag on gang sheds stays locked until the gang meets activity thresholds (member count / hours / recent logins), refusing storage otherwise (admins exempt).
- **Why:** LooneyBin's gang sheds ($200k warehouse) have no activity gate — a dead or one-man gang keeps a fully usable shared 3000-capacity stash (anti-abandoned-stash / anti-boosting).
- **Apply:** Consider a gang-activity gate (member count / recent-login threshold) before unlocking shed storage; requires the server to expose gang activity stats to the check. *(low)*

---

## Login / query, save-on-change vs periodic, relog/disconnect, stat buffering

### Relocate players OUT of hot zones at LOGIN, including DYNAMIC red-zone markers
- **Technique:** Build a comprehensive combat-log zone list (rebel outposts, cartels, black markets, bounty, jail, fed reserves, etc.) **plus** a dynamic scan `allMapMarkers select { pos inArea _x && markerColor == 'ColorEAST' && markerBrush == 'FDiagonal' }`, then for each zone move the loaded logout position via `BIS_fnc_findSafePos` to a ring outside the zone **before** the player is ever positioned.
- **Why:** It defends at re-entry, so it works regardless of how the disconnect happened (crash / pkill / watchdog restart with no graceful save), and the dynamic scan auto-covers event/gang-base zones with no hardcoded list. LooneyBin only obfuscates position on the **save** path (`fn_ClupdateRequest _randomSyncZone`, covering only the 4 cartels + mental hospital); `fn_initCiv` then `setPosATL AP_ses_last_pos` at the exact saved spot for rebel outposts, black markets, fed, jail and any dynamic zone (only broadcasting a warning) — so a combat-logger re-enters right in the fight.
- **Apply:** In `mission/LooneyBin.Altis/core/fn_initCiv.sqf` (returning-player branch ~L45-72, before `setPosATL AP_ses_last_pos`), relocate `AP_ses_last_pos` via `BIS_fnc_findSafePos` when inside a fixed zone list **plus** a runtime `allMapMarkers` red/east + `FDiagonal` scan. *(high)*

### Derive stat name → DB-slot mapping from config once, not a hand-synced 148-branch switch
- **Technique:** Build a bidirectional `name ↔ index` hashmap from `configClasses(missionConfigFile >> 'CfgStats')` order via `createHashMapFromArray`; guard drift with `if count(cfgList) != count(loadedStats) then { diag_log …; resize }`. Config order **is** DB slot order, so the flush payload and every consumer agree from one source. Supports read-time derived/combined stats via a config `type` field.
- **Why:** LooneyBin hand-maintains the same mapping in **three** places that must stay in sync: the 148-branch `switch(toLower _item)` in `fn_statArrUpdate.sqf` (already has gaps/dups — indices 128, 140-142 skipped; 30/40/53 reused), the fixed `APV_defaultStats resize 148` in `configuration.sqf`, and the server pad-to-148 in `APS_fnc_getStatsArr`. Adding a stat means picking a free index by hand across all three — collision-prone.
- **Apply:** Longer-term, move the `fn_statArrUpdate.sqf` index table into a `CfgStats` config and build a `name→index` hashMap at init, so the switch, `APV_defaultStats` length, and server padding all derive from config order. *(medium)*

### Route all persistence RPCs through ONE indirection point (offloadable to a headless client)
- **Technique:** Wrap every persistence call in one fn that reads `[hcActive, hcID]` and, when an HC is active, reroutes the save/DB fns from server id 2 to `HC_fnc_*` on the HC, with a clean fallback to id 2. The client save dispatcher is mode-typed (cash/bank/gear/position/license/revive/arrested/wanted/death) and always hands off through this single wrapper.
- **Why:** LooneyBin scatters `spawn AP_fnc_MP` / `remoteExec[…,2]` across every save site (`fn_ClupdatePartial`, `fn_ClupdateRequest`, `fn_flushStats`, `statTableUpdate`), hardcoding the server target everywhere. A single choke-point lets heavy save/DB work move off the FPS-bound server (a documented pain point) without touching call sites, and centralizes throttling/dedup. (extDB3 lives on the server, so full HC DB offload needs the extension there too; the wrapper itself is the low-risk win.)
- **Apply:** Add a thin `AP_fnc_persist` wrapper that all save paths call instead of hardcoding target 2, choosing server-vs-HC from a flag — so the indirection exists even before an HC does. *(low)*

---

## Player-facing UX / QoL — notifications, vehicle audio, movement, interaction

### Notification dedupe + update-in-place by ID
- **Technique:** (1) Early-exit if new text equals the most-recent queued message's text (`if (_text isEqualTo ((oev_message_list select 0) select 2)) exitWith {}`), suppressing consecutive dup spam; (2) accept an `_id` param and, if a live message with that id exists, rewrite that control's structured text in place instead of stacking a new box — letting a progress/countdown message update on one line.
- **Why:** `fn_handleMessage`/`fn_createMessage` are the **same** priority-insert + active-lock design (same `_insertIndex`/`AP_message_active` lineage) but have no `_id` and no dedupe — so repeated identical alerts stack and any updating status (timers, rob progress, gather counts) spams a new box each tick (the "zero-menu-overlap"/"search menu stays 60s" clutter class).
- **Apply:** In `mission/LooneyBin.Altis/dialog/function/fn_handleMessage.sqf` + `fn_createMessage.sqf`, add an `_id` param (default -1), an early dedupe against `(AP_message_list select 0) select 2`, and an id-match loop that `ctrlSetStructuredText`-updates the existing control. Signatures/queue shape already match. *(high)*

### Auto-earplugs on vehicle entry, per ground/air type, Off/Partial/Full, auto-restore on exit
- **Technique:** In the GetInMan EVH read a per-type setting (`AP_groundVehEarplugs`/`AP_airVehEarplugs`); if not Off, snapshot prior earplug state, apply Partial/Full fade, then the GetOutMan EVH restores exact prior state and clears the flag.
- **Why:** LooneyBin only has a manual key-bound earplug toggle (`evh/fn_keyDownHandler.sqf:421`) — the player must remember to toggle every entry/exit of a loud heli/offroad. LooneyBin already has the exact settings-persistence scaffold (`tawvd_foot/car/air` in `PLBClientSettings`), so two combo settings is a small, well-precedented change.
- **Apply:** Add `AP_groundVehEarplugs`/`AP_airVehEarplugs` (Off/Partial/Full) to `core/pmenu/fn_settingsMenu.sqf` + the `PLBClientSettings` array in `fn_settingsInit.sqf`; apply/restore in the GetInMan/GetOutMan EVHs (`evh/`), snapshotting prior state. *(high)*

### Autorun auto-consumes stamina items when fatigued; cancels on healing/jail/limp
- **Technique:** When `getFatigue player isEqualTo 1`, on a 10s cooldown walk the energy items (redgull/coffee/lollypop) and consume one if held/usable. Exit the loop with a player-facing reason on healing, jail, limp (`getHit 'legs' >= 0.5`), restrained, or not-on-ground.
- **Why:** `core/functions/fn_autoRun.sqf` has richer weapon/slope/water animation selection but never consumes stamina items (a fatigued player just crawls) and only aborts on downed/restrained/dead/inVehicle — it happily autoruns a mid-heal or limping player.
- **Apply:** In the `fn_autoRun.sqf` while loop, add a fatigue-triggered, cooldown-gated auto-consume over LooneyBin's energy items, plus exit guards for active healing and heavy leg damage (both tracked elsewhere). *(medium)*

### Radial (pie) interaction wheel with per-slice predicate re-checked at select time + submenu back-stack
- **Technique:** Each action is `[label, selectFnc, icon, enabledFnc]`; `enabledFnc` is evaluated when drawing (greys out disabled slices) **and again at selection** in the confirm handler, plus a fresh distance re-check (`isKindOf 'Man' && player distance _target > 5`). A `wheelActionsPrevious` stack lets a slice open a submenu with right-click to pop back.
- **Why:** LooneyBin drives interactions through engine `addAction` scroll entries (`core/actions/*`) — can't grey out unavailable options, no nested submenus, and (for dialog phone/interaction menus) don't re-validate condition/distance at click time. Re-evaluating the predicate + distance at selection closes the "target ran away / state changed while menu was open" gap and scales to many contextual actions without scroll clutter.
- **Apply:** Larger port — introduce a radial display + a `[label,fnc,icon,enabledFnc]` registry to augment the `addAction` surface; even without the wheel, adopt re-running the action's guard + distance check at execution time in dialog-driven interactions. *(medium)*