<!-- LoonyBot bug queue. One entry per report. Status flow: NEW -> STAGED -> FIXED.
     The bot appends NEW reports; the owner/Claude edit Status as work proceeds.
     Never renumber existing #IDs. -->

# LooneyBin Bug Queue

### #1 · FIXED · 2026-06-03T19:48Z
- **By:** doomba  ·  **Channel:** #bug-reports  ·  **ref:** 100000000000000001/100000000000000001

Loadout system broke — Click button nothing happen

---

### #2 · FIXED · 2026-06-03T19:48Z
- **By:** player036  ·  **Channel:** #bug-reports  ·  **ref:** 100000000000000002/100000000000000002

windows key revive not working — ^^^
QOL it just doesnt let you it says you must wait to try again
> ask: Do you mean the interaction key (⊞ Win by default)? Please describe exactly: which key you press, your class & side, whether you're reviving yourself or another downed player, and the precise on-screen message you get.

> staged: root cause = the User10 interaction key (revive / quick-access — default ⊞Win) was detected via `inputAction "User10" > 0` while every other custom key (User2/6/11/12/14) uses `_code in (actionKeys "UserN")`. `inputAction` polls analog state and misses many bound keys, so a rebound interaction key silently failed. Fixed `evh/fn_keyDownHandler.sqf:114` to `_code in (actionKeys "User10")` (consistent with all other User actions). NEEDS in-game test: rebind User Action 10 to a custom key → revive a downed player + interact (ATM/house/vehicle) with it.
---

### #3 · FIXED · 2026-06-03T19:48Z
- **By:** player036  ·  **Channel:** #bug-reports  ·  **ref:** 100000000000000003/100000000000000003

aging barrel — i tried adding an aging barrel to my house and it has been a few minutes and it doesnt add and once you try to add it again it says "you currently have an active transaction, please wait"
> ask: Need repro detail: does the aging barrel EVER get added (just slow), or never? Does relogging clear the "active transaction, please wait" message? Which house is it, and how many barrels are already placed there?

---

### #4 · FIXED · 2026-06-03T19:48Z
- **By:** player036  ·  **Channel:** #bug-reports  ·  **ref:** 100000000000000004/100000000000000004

when sent to jail you dont get unrestrained. — ^^

---

### #5 · FIXED · 2026-06-03T19:48Z
- **By:** player036  ·  **Channel:** #bug-reports  ·  **ref:** 100000000000000005/100000000000000005

dmg bug — the ghost hawk and the hurron are about 5 shots from an mk1 to take down

---

### #6 · FIXED · 2026-06-03T19:49Z
- **By:** player002  ·  **Channel:** #bug-reports  ·  **ref:** 100000000000000006/100000000000000006

main rotor issues, with ripping out too easy — or too hard

---

### #7 · FIXED · 2026-06-03T19:49Z
- **By:** player036  ·  **Channel:** #bug-reports  ·  **ref:** 100000000000000007/100000000000000007

Tempest device — storage is 100 but it can gather infinite amount. 72 opium is 216 weight so its 216/100 max weight

---

### #8 · FIXED · 2026-06-03T19:49Z
- **By:** player036  ·  **Channel:** #bug-reports  ·  **ref:** 100000000000000008/100000000000000008

dropping items — dropping items from either dying or manual dropping doesnt work as it just disappears.
> note: vanish bug fixed earlier (items now drop). STAGED tweak: server fn_createItem now MERGES drops into ONE nearby suitcase (stacks like items) instead of a case per item, and spawns it with simulation off so it can't shove vehicles/players. Needs a SERVER reboot.

---

### #9 · FIXED · 2026-06-03T19:49Z
- **By:** player036  ·  **Channel:** #bug-reports  ·  **ref:** 100000000000000009/100000000000000009

repair randomly stops — idk i started the repair went to piss and it stopped happened 3 times

---

### #10 · FIXED · 2026-06-03T19:49Z
- **By:** doomba  ·  **Channel:** #bug-reports  ·  **ref:** 100000000000000010/100000000000000010

Unflip car doesnt work — Unflipping cars doesnt work 
IT shows the "Stand back unflipping in 5 seconds message"  but doesnt actually unflip 
How to reproduce: 
Walk up to car, scroll wheel, click unflip

---

### #11 · FIXED · 2026-06-03T19:49Z
- **By:** doomba  ·  **Channel:** #bug-reports  ·  **ref:** 100000000000000011/100000000000000011

VDM Script no work — You just die when hit by a car

---

### #12 · FIXED · LOW · 2026-06-04
- **By:** doomba  ·  **Channel:** internal (revive-drone feature)

Revive drone charges not persistent — `AP_droneCharges` is a session-only client var. Relog/reboot refills it to 10, so a medic can skip the 1 h recharge by reconnecting. Mild exploit. Fix = persist charges + recharge-time to the DB. Deferred (priority low).

---

### #13 · FIXED · LOW · 2026-06-04
- **By:** doomba  ·  **Channel:** internal (revive-drone feature)

Revive drone double-revive race — two drones treating the same downed body at once could both land the revive and both collect the reward. No `ga_reviving` lock on the drone revive path. Add a per-target lock if it shows up in play. Deferred (priority low).

---

### #14 · FIXED · 2026-06-04
- **By:** doomba  ·  **Channel:** internal (revive-drone feature)

Revive drone rotor lights offset ~1–2 ft from the rotors.
> staged: pulled `_offs` ~1.3 ft inward (0.95 → 0.55) in `fn_medicLights.sqf`. Re-test position. The 4 strobes spawn but sit off-position. Fix = tune `_offs` in `core/medical/fn_medicLights.sqf` (currently `[±0.95, ±0.95, 0.15]`). Cosmetic, priority low. Need offset direction (in/out/up) to dial in — or trial-and-error.

---

### #15 · FIXED · 2026-06-04
- **By:** doomba  ·  **Channel:** internal (revive-drone feature)

Revive drone lights orphan on the ground if the drone is disassembled (→ backpack) while lights are ON.
> staged: `fn_medicLights` drone loop now breaks on `!isNull`/`alive`/`typeOf==""` (vehicle deleted on disassemble) → deletes its lightpoints. Re-test. The `#lightpoint` objects don't clean up — the `fn_medicLights` cleanup only fires when its loop exits on `!alive _vehicle`/`ga_lights=false`, and disassemble doesn't trip that path cleanly. Fix = on disassemble (or drone-gone in the monitor) force `ga_lights=false` + `deleteVehicle` the attached lightpoints. Leaves stray world lights. Priority low.

---

### #16 · FIXED · 2026-06-04
- **By:** doomba  ·  **Channel:** internal (revive-drone feature)

Revive drone vanishes mid-use (noticed during a self-FAK). Root cause: the server cleanup sweep (`fn_cleanup.sqf`) deletes any alive Car/Air/Ship with `idleTime==0` and no `"owner"`/`"Trunk"` var — the assembled drone had none, so a periodic sweep deleted it (the long ~18 s self-treat just made it likely to overlap a sweep; it'd vanish regardless of action).
> staged: drone setup now sets `_d setVariable ["owner", uid, true]` so cleanup spares it (same mechanism legit vehicles use; `"owner"` is only read by cleanup + spikestrip, no garage/DB side effects). Residual edge: a drone assembled but never connected (setup never runs) is still unprotected — unrealistic, deferred.

---

### #17 · FIXED · 2026-06-05T01:18Z
- **By:** doomba  ·  **Channel:** #Cop loadout menu still bugged  ·  **ref:** 100000000000000012/100000000000000012

Cop loadout menu still bugged — When saving loadout the option disappears from the list of empty loadouts and cannot be used.

> staged: root cause = cop loadout slots maxed at 6 (mostly duplicate saves) → no empty slot → save button never arms → "empty option disappears, can't use". Fixes: (1) slots 6→8 per side (configuration + fn_fetchLoadouts + fn_loadoutMenu + fn_saveLoadout update-range), (2) block saving a duplicate loadout name (fn_saveLoadout), (3) "All loadout slots full — delete one" hint when full (fn_loadoutMenu), (4) wiped the owner's 6 duplicate WEST rows (backed up to ~/looneybin-loadouts-WEST-backup-*.tsv). Boot-verified. NEEDS in-game test: save 8 cop loadouts, dup-name rejected, equip works, slots-full hint shows at 8.
> FIXED: real root cause was NOT slots — `SRV_communityEvent` was referenced (getLoadoutPrice/getDiscount/reGear) but never initialized → cop-only path did `undefined select 1` → `_loadoutCost` nil → NaN price → menu couldn't render the saved cop loadout (looked empty; save itself always worked). Fix: defined `SRV_communityEvent=[false,false]` in configuration.sqf + made the 3 reads `param [1,false]` crash-safe. Owner confirmed fixed in-game. (Slot bump 6→8 + dup-name block + slots-full hint + dup-row wipe retained as hardening.)
---


### #18 · FIXED · 2026-06-06
- **By:** claude (cruft audit)  ·  **Channel:** internal (asset-integrity sweep)

Two jewelry-heist tool icons missing — `icons\jewelcrowbar.paa` ("Crowbar", item `jewelCrowbar`) and `icons\jewellaser.paa` ("Plasma Cutter", item `jewelLaser`), both referenced in `core/config/fn_virtItemCfg.sqf:76-77`. Files absent from `icons/` (pre-existing deobfuscation gap, predates all 2026-06-04 cleanup work). **Items are fully functional** — they just render with a blank/default icon in inventory + virtual shop. Cosmetic only.
> Fix options: source the original `.paa` files, repoint the two entries at an existing placeholder icon, or leave as-is (no gameplay impact).
> staged 2026-06-06: NOT actually missing — the real artwork exists as `icons\jewelLaser.paa` + `icons\jewelCrowbar.paa` (capital letters); the config referenced them lowercase, and the PBO build is case-sensitive (Linux), so the lookup failed -> blank icon. Fixed the case in `fn_virtItemCfg.sqf:76-77`. Swept all 253 icon refs — these two were the ONLY case mismatches, nothing else missing. Deploys next restart; both icons render. (Earlier "files absent" note was wrong — my audit grepped lowercase only and missed the capital-case files.)

### #19 · FIXED · 2026-06-05
- **By:** doomba  ·  **Channel:** internal (medic heal-gun)

Medic "Healing Bullets" heal 100% HP per shot instead of +10%.
> staged: root cause = the heal block in `evh/fn_handleDamage.sqf` spawned `setDamage(damage-0.1)` on EVERY HandleDamage event, but HandleDamage fires once per hitpoint per bullet (head/body/hands/legs/…) — the spawns run sequentially, each reading the already-reduced damage, compounding to a full heal. Fix: per-frame guard (`AP_healBulletFrame` vs `diag_frameNo`) so the +10% applies once per shot. Boot-verified. NEEDS in-game test: shot heals ~10% per hit, not full.

### #20 · FIXED · 2026-06-05
- **By:** doomba  ·  **Channel:** internal (revive drone)

Revive drone: treat range too short (3 m) + defibrillator "not working" — the drone is an aircraft hovering ABOVE the body, so the 5 m drift-check (`fn_reviveDrone.sqf:136`) cancelled every aerial revive.
> staged: `_R` 3 m -> 10 m (selection + addAction `<10`), drift-cancel now `> (_R + 2)` = 12 m so the hovering drone stays "on" the patient. Same fix resolves both the range request and the defib-not-working report. NEEDS in-game test: hover ~5-10 m over a downed player, revive/bloodbag/FAK/adrenaline complete without "drifted off".

---

### #21 · FIXED · 2026-06-06
- **By:** doomba  ·  **Channel:** internal (revive drone)

Revive drone ramming — the medic must NEVER get a wanted charge; the drone should SPANGLE (taze/down) players instead of killing them.
> staged: drone is now NON-LETHAL — `evh/fn_handleDamage.sqf` negates all drone-collision damage (can't kill) and, on a real ram (`_damage>=0.4`), calls `AP_fnc_handleDowned` with the DRONE as source. The drone is a UAV (Air, not LandVehicle) so handleDowned takes its no-charge branch → the player is downed/spangled and the medic is never charged. Per-frame guarded (one down per ram). NEEDS test: ram a player → they get downed, no kill, no charge to the medic.

---

### #22 · FIXED · 2026-06-05
- **By:** doomba  ·  **Channel:** internal (respawn)

On bleedout players sometimes teleport to debug island ([0,0,0]).
> staged: root cause = `respawn=BASE` but only the `respawn_civilian` marker existed — cops (`respawn_west`) and medics (`respawn_guerrila`) had NO side anchor, so the engine respawned them at [0,0,0]. `initServer.sqf` now creates the 3 missing anchors (`respawn_west/guerrila/east`) at the civ respawn pos (invisible, just a pre-spawn-menu holding spot). NEEDS in-game test: cop + medic bleed out -> land at a valid spot / spawn menu, not debug island.
### #23 · FIXED · 2026-06-05T21:35Z
> fix: no User4 hook existed in fn_keyDownHandler. Wired Custom-4 (User4) -> [cursorObject] call AP_fnc_restrain with the scroll-action gating (cop: non-west; civ: surrendered/downed); fn_restrain self-validates the rest. Player must bind 'Use Action 4' in Controls.
- **By:** player036  ·  **Channel:** #Custom 4 (restrain hotkey)  ·  **ref:** 100000000000000013/100000000000000013

Custom 4 (restrain hotkey) — doesnt work

---

### #24 · FIXED · 2026-06-05
- **By:** doomba  ·  **Channel:** internal (revive)

Civs sometimes teleport to debug island while downed/waiting for medic.
> staged: `fn_revived.sqf` teleported the revived player to `visiblePositionASL AP_corpse`, but a DOWNED (not dead) player never had `AP_corpse` set -> objNull -> [0,0,0] = debug island. Guarded: only teleport to a valid corpse, else leave them where they were downed. NEEDS test: down a civ, medic/drone revive -> they wake in place, not debug island.

---

### #25 · FIXED · 2026-06-05
- **By:** doomba  ·  **Channel:** internal (loot)

Dropped-item briefcases should take a minimum of 20 minutes to despawn.
> staged: `server fn_createItem.sqf` despawned the `Land_Suitcase_F` immediately once picked clean (empty + not in use). Added a 20-min (1200s) minimum-life floor — the empty-despawn can't fire until 20 min have passed; hard cap stays 30 min. Deploys next restart.

### #26 · FIXED · 2026-06-05
- **By:** doomba  ·  **Channel:** internal (crime)

Calling the remote detonator (cellphone) doesn't detonate the planted explosive / engine kill switch.
> staged: `fn_phoneCallClient.sqf` re-resolved the target vehicle via `vehicles findIf (ga_dbInfo[1] == plate)`, which returned objNull / the wrong vehicle when the plate was -1, the vehicle was non-DB, or it had been re-plated -> `callInBomb`'s `_vehicle == AP_remoteExplosive#0` guard then failed and the call silently did nothing. Fixed to use the stored vehicle object directly (`AP_remoteExplosive#0` / `AP_engineKillSwitch#0`). Deploys next restart. NEEDS test: plant bomb + engine-kill on a vehicle, call the detonator -> both fire.

### #27 · FIXED · 2026-06-05
- **By:** doomba  ·  **Channel:** internal (comms)

`!911` (police) and `!311`/EMS (medics) emergency messages don't reach anyone.
> staged: root cause = server `APS_fnc_handlePhoneMsg` was a flagged "best-guess passthrough" that called `APS_fnc_managePhone` — the radio-CALL channel system — with the 2020 message args `[mode, caller, target, msg]`, which it read as `[unit, target, terminate, cleanupOnly]`. Total mismatch -> 911/311/text never delivered. Rewrote it as a proper router: mode 1 -> all MaxSec (west), mode 2 -> all TT (independent), mode 0 -> target player, each via `AP_fnc_handleMessage` with the caller's name + map grid. Voice calls untouched (still `handlePhoneCallSRV` -> managePhone). NEEDS test: civ `!911 msg` -> cops see it; `!311 msg` -> medics see it.
> update 2026-06-05 (owner): 911 (mode 1) upgraded — now drops a map ping (`mil_dot` marker + 3D icon, 60s, every cop) at the caller's position via `AP_fnc_tacticalPing`, and shows a larger `copalert` banner (caller name size 1.3 + message below), **no grid coords**. 311 (medics) left as the basic+grid line.

### #28 · FIXED · 2026-06-05
- **By:** doomba  ·  **Channel:** internal (comms)

In-game (cellphone) voice phone calls don't connect.
> staged: server `APS_fnc_handlePhoneCallSRV` was the same broken best-guess passthrough to `APS_fnc_managePhone` — the 2020 client sends `["startPhoneCall",[caller,receiver]]` / `["endPhoneCall",[chanID,player]]` and expects `["phoneCallEstablished",[chanID]]` back, but managePhone read the args as `[unit,target,terminate,cleanup]` and used a different notify protocol, so the channel never linked. Rebuilt to the client protocol: opens/reuses a pooled radio channel via `radioChannelCreate`+`radioChannelAdd`, replies `phoneCallEstablished` (or `phoneLinesMaxed`), and on hangup drops both, tells the other party, frees the channel. NEEDS test (2 players): call -> ring -> press 8 -> voice link both ways -> hang up ends it. Known edge: disconnect mid-call doesn't auto-free (other party hangs up to clear).

### #29 · FIXED · 2026-06-05
- **By:** doomba  ·  **Channel:** internal (cop economy)

Police aren't paid for tickets or arrests.
> staged: root cause = server `APS_fnc_copSplit` was a no-op stub (logged the call, paid nothing). EVERY cop payout routes through it — ticket pay (`fn_ticketPay`), arrest bounty (the `west` branch of `fn_bountyReceive` hands its share to copSplit), money seizes (`fn_copSearch`), vehicle/inventory seizes, impounds, illegal-tent seizes. Civilian bounty hunters bypass it (they credit `AP_atmcash` directly), which is why only police reported missing pay. Implemented copSplit: splits the pool evenly among active alive MaxSec + new client receiver `AP_fnc_copSplitReceive` credits each officer's bank (+anti-cheat cache + HUD + chat line). No CfgRE whitelist entry needed — server->client remoteExec is exempt from the mode=1 whitelist. Deploys next restart. NEEDS test: issue+pay a ticket, and arrest a wanted civ -> issuing/active cops' bank rises + "Police payout: +$X" chat. Bonus: money/vehicle seizures, impounds, illegal tents now pay too.
> correction 2026-06-05: server->client IS subject to the mode=1 whitelist here (the curated CfgRE.hpp "server->client callbacks" list). `AP_fnc_bountyReceive` was MISSING from it, so arrests never even ran the payout (silently blocked) — and the new `AP_fnc_copSplitReceive` needed adding too. BOTH added to CfgRE.hpp. This whitelist gap was the real reason arrests paid nothing; the copSplit stub was the ticket/seize half.

### #30 · FIXED · 2026-06-05
- **By:** doomba  ·  **Channel:** internal (housing)

TT house repair takes the money/strips the house but never actually repairs it.
> staged: server `APS_fnc_repairBuildingSRV` was a no-op stub. The owner-side `payForRequest` already pays the medic + strips the house from `AP_houses`/`AP_vehicles` expecting the server to rebuild + call back, but the stub did nothing -> house gone, never un-ruined. Implemented it: `setDamage 0` un-ruins the terrain building, re-stamps ownership vars, calls back `civRepairBuilding 'houseRepaired'` (re-adds to lists + CLinitHouses + marker/inventory). No DB write (a destroyed house keeps its row; it'd auto-repair on restart anyway). NEEDS test: destroy a house, TT-repair it -> building restored + still owned. NOTE for owner: the owner is NOT actually charged in code (the "fee taken" message is cosmetic) while the medic IS paid — say the word and I'll add the real owner deduction so it's balanced.

### #31 · FIXED · 2026-06-05
- **By:** doomba  ·  **Channel:** internal (respawn)

Players (cops, medics, AND civs) sometimes end up on debug island [0,0,0] on death/while waiting for a medic, and can't be revived.
> staged: root cause = `mission.sqm` only defines a `respawn_civilian` marker. With `respawn=BASE` the engine respawns west (cops) + independent (medics) at [0,0,0] = debug island; the earlier `initServer` runtime `createMarker` isn't honored by the engine's BASE-respawn marker cache (read at mission load). Once there, if the wait runs long the engine auto-deletes the corpse so `fn_revived` can't teleport them back. Fix: hard-correct in `fn_onPlayerRespawn` (always runs client-side after the engine respawn) — any respawn landing within 100 m of [0,0,0] is moved to the side's first real spawn (cop/medic HQ via `spawnPointCfg`), falling back to `respawn_civilian`. Side-agnostic, so it covers the civ case too. NEEDS test: die as cop/medic/civ, wait, get revived -> never debug island.

### #32 · FIXED · 2026-06-05
- **By:** doomba  ·  **Channel:** internal (medical)

Medic heal gun heals to 100% with one shot (should be ~10%/shot).
> staged: the heal-bullet block in `fn_handleDamage` guarded with `diag_frameNo`, but in MP a single bullet's per-hitpoint damage events spread across several frames -> many +10% heals = full heal. Switched to a TIME throttle: at most one +10% per 0.35 s, so one shot = +10% no matter how the events land. NEEDS test: shoot a hurt player once -> ~10% healed, not full.

### #33 · FIXED · 2026-06-05
- **By:** doomba  ·  **Channel:** internal (medical)

Windows-key revive fails and spams "Wait a bit before attempting to revive again".
> staged: `fn_actionKeyHandler` set `AP_action_in_use = true` (+a 60 s reset) BEFORE calling `AP_fnc_revivePlayer`, whose own guard exits on `AP_action_in_use` -> every windows-key revive silently failed, the medic re-pressed and hit revivePlayer's 3 s "Wait a bit" throttle. Moved the revive call ABOVE the action-lock. NEEDS test: windows-key revive a downed player -> the revive progress runs.

### #34 · FIXED · 2026-06-05
- **By:** doomba  ·  **Channel:** internal (medical / drone)

Revive drone's treatment-menu Revive does nothing.
> staged: the drone picked revive targets from `allPlayers select {ga_revivable}`, but `ga_revivable` is set on `AP_corpse` (the dead BODY), which is NOT in `allPlayers` once `respawn=BASE` respawns the player to a new unit -> the drone never found a patient. (Manual revive works because it uses `cursorObject` = the body you look at.) Fix: drone now searches `nearestObjects [drone,["CAManBase"],10]` for `ga_revivable` bodies. NEEDS test: hover the drone over a body that requested a medic, Revive -> it wakes.

### #35 · FIXED · 2026-06-05
- **By:** doomba  ·  **Channel:** internal (drone)

Drone polish: ram-spangle removal + R-menu only in terminal + destroyed-drone guards.
> staged: (1) removed the drone->player ram-spangle from `fn_handleDamage` (was test-only) — the drone is now harmless on contact. (2) R/F treatment hotkeys now only fire while actually viewing THROUGH the drone (`cameraOn` is the drone = UAV terminal AV view), not merely connected to it in your body. (3) treatment menu + R-menu + scroll action no longer open when the drone is destroyed (`alive` guards). (4) a destroyed drone is no longer a mobile med shop — Killed EH clears `ga_medSupply` + `alive` guard on the shop revenue path. NEEDS test: destroyed drone = no R-menu, no shop; R-menu only appears in the drone view.

### #36 · FIXED · 2026-06-05
- **By:** doomba  ·  **Channel:** internal (MaxSec)

Wanted menu lists each duplicate charge separately (4 manslaughter rows) instead of "4 counts of Manslaughter".
> staged: `AP_wanted_list` stores crimes as a FLAT id list (`[11,11,11,11]`) but `fn_wantedInfo` renders `[id,count]` pairs, so each flat id became its own row with a nil count ("any count(s) of Manslaughter"). Added an aggregation pass in `fn_wantedInfo` that collapses the flat list into `[id,count]` pairs before display. NEEDS test: rack up 4 of the same charge -> one "4 count(s) of ..." row.

### #37 · FIXED · 2026-06-06
- **By:** doomba  ·  **Channel:** internal (housing)

Houses can't be sold.
> staged: server `APS_fnc_srvSellHouse` was a broken passthrough — `_this call DB_fnc_deleteHouse` fed it `[_house, player]`, but deleteHouse reads arg0=oid, arg1=house, so it operated on the PLAYER as the house (getPos/getBuildID on the player) → wrong/no DB row deleted, and nothing told the seller's client to finalise → txn hung (no money, house stayed, `AP_houseTxn` stuck). Rewrote it: DELETE the row by the house's oid (`ga_houseID`, the unique key), drop it from `AP_house_owners`, then `AP_fnc_handleHouse` mode 2 on the seller (pays sell price, removes from AP_houses/AP_vehicles, deletes marker, resets txn). NEEDS test: sell a house → get paid, house gone from your list, can buy again.

### #38 · FIXED · 2026-06-06
- **By:** doomba  ·  **Channel:** internal (crime)

Ignition bomb doesn't work.
> staged: server `APS_fnc_ignitionBombSRV` was a no-op stub — the bomb "planted" client-side but never detonated. The bomb is meant to blow when the target starts the engine; engine state is networked, so the server now watches `isEngineOn` on the rigged vehicle and on ignition creates a blast + `setDamage 1` (one-shot, cancels if the vehicle's gone first). No new client fn/whitelist needed. NEEDS test: plant on a vehicle, have someone start it → it blows.

### #39 · FIXED · 2026-06-06
- **By:** doomba  ·  **Channel:** internal (crime)

Arson kit doesn't work.
> staged: server `APS_fnc_medicFireSRV` ("initArson") was a no-op stub — the kit charged/consumed but no fire started. Implemented: sets `ga_houseOnFire` on the building + adds it to the public `SRV_houseOnFire` list + broadcasts `AP_fnc_medicFireClient` clientFireEffects (flames/sounds + TT dispatch; JIP joiners get it via initPlayerLocal). If no firefighter extinguishes it within ~8 min it burns down (`setDamage 1` → ruins, TT-repairable). NEEDS test: use the arsonist kit on a house → it catches fire (and burns down if not put out).
### #40 · FIXED · 2026-06-06T17:36Z
> fix: join admin-bypass was `adminLevel>=3`; the test auto-grant makes every tester admin 4 so all of them skipped the password. createGroup/setGroupPass already lock+store the pass correctly. Raised the bypass to `>=5` (owner only) in fn_joinGroup -> admin-4 testers now respect group passwords.
- **By:** doomba  ·  **Channel:** #Groups on civ let you join without a password even when one is set  ·  **ref:** 100000000000000014/100000000000000014

Groups on civ let you join without a password even when one is set — Groups on civ let you join without a password even when one is set

---

### #41 · FIXED · 2026-06-06
> Multi-layered. Players sent to debug island [0,0,0] on death, and (heli deaths) trapped on a frozen death screen unable to bleed out / be revived. THREE root causes, all fixed:
> 1. **Spawn-list abort** — `SRV_diedInGangFort` / `SRV_jewelryEmporiumSRV` never init'd at boot -> undefined on clients -> `fn_spawnPointCfg` lines 44-45 throw -> spawn-point list build aborts -> spawn falls to [0,0,0]. Fix: client-safe `missionNamespace getVariable [name, default]` in fn_spawnPointCfg (can't throw). (Server-init + publicVariable tried first; didn't reach long-running clients.)
> 2. **Corpse left in the wreck** (heli deaths) — die in a heli, the pilotless heli flies off + crashes/clips terrain, dragging the corpse out of bounds / under the map. Fix: `fn_onPlayerKilled` vehicle-death block ejects the player's OWN corpse to the ground when the vehicle is destroyed (helis: as soon as pilotless; cars: on destroy). Client-side = correct locality, covers pilot + all passengers.
> 3. **THE killer — the janitor reaped the corpse mid-bleedout.** `fn_cleanup.sqf` allDeadMen loop deletes any corpse where `Revive` is nil OR dead >300s. The 2017 revive system that stamped `Revive`/`ToD` was lost in deobf -> NOTHING sets them -> `isNil "_revive"` always true -> every corpse deleted on the first cleanup pass -> death screen loses its `_this` -> player force-respawned off the screen. Fix: cleanup now `continue`s on `isPlayer _x` (a live player's own body is never reaped during bleedout; orphaned/post-respawn bodies aren't isPlayer -> still reaped), + onPlayerKilled stamps `Revive`/`ToD` as backup.
> Safety net: bleed-timer loop calls doRespawn whenever it exits unrespawned (even if the corpse vanished) so a player can never be permanently trapped. Verified in-game: full bleedout runs, corpse persists, normal respawn / revivable. Bleedout duration raised to 30 min (`AP_death_timer=30`). Supersedes #31.
- **By:** doomba  ·  **Channel:** internal (respawn)

---

### #42 · FIXED · 2026-06-06
- **By:** player002  ·  **Channel:** #asylum exhange broken, shows on map as asylum aswell. 2x bugs  ·  **ref:** 100000000000000015/100000000000000015

asylum exhange broken, shows on map as asylum aswell. 2x bugs — ff
> staged: TWO fixes. (1) MAP: `mission.sqm` had asylum branding in marker TEXT — renamed "Asylum Exchange" ×5, "Asylum Duel Arena", "Mental Asylum Hospital", + the TeamSpeak/Website intel (gaming-asylum.com) -> Loonybin / gaming-loonybin.com. Only `text=` fields touched; marker IDs (`jail_marker_asylum`) left intact so code refs don't break. Deploys next restart. (2) EXCHANGE: root cause = the `exchange` DB table was NEVER created (deobf migration gap) -> `getOffers`/`fn_listing` queries errored -> empty/non-functional exchange. PLUS `getOffers` queried `FROM Exchange` (capital) while everything else uses `exchange` (lowercase), and MariaDB here is `lower_case_table_names=0` (case-sensitive) = different tables. Fixed: created the `exchange` table (13 cols incl. `timer` for the offer-aging/cleanup, matched to every query's columns) + corrected `getOffers` 3× `Exchange`->`exchange`. Table is LIVE now (no reboot); the getOffers case fix deploys next restart. After reboot: list/browse/buy/sell + offer aging all work.

---

### #43 · FIXED · 2026-06-06T18:35Z
> fix: no script protects the Orca rotor (handler passes it unchanged; no repair/allowDamage). Floored rotor-selection damage (`_hitBox find "vrtule">=0`) on both Orca variants to >=0.1/hit in fn_handleVehicleDamage so a burst downs it regardless of the engine/config value. Tune the floor after a live test.
- **By:** player002  ·  **Channel:** #orca main rotor immortal  ·  **ref:** 100000000000000016/100000000000000016

orca main rotor immortal — f

---

### #44 · FIXED · 2026-06-06T18:42Z
- **By:** player002  ·  **Channel:** #claiming broken, gives both keys, doesnt take money out  ·  **ref:** 100000000000000017/100000000000000017

Chop Shop **Claim Vehicle** is broken: doesn't strip the original owner's key (both keep keys) and doesn't deduct the claim cost from the bank.
> fix: root cause = `APS_fnc_vehOwnerSwap` was an admitted stub (called `APS_fnc_setOwnerID` with an array it can't take) -> DB `vehicles.pid` never moved, so the original owner kept ownership + key (keys derive from pid; there's no keys column). Implemented the real pid transfer (+ live owner/keyholder vars, offline owners covered). Money: client already debits `AP_atmcash` -> `ClupdatePartial[1]`=`bankacc` (verified) for the non-zero menu price; only free case is a gang owning the Zaros turf. `APS_fnc_keyManagement` stub left as-is (moot — keys are pid-derived).

---

### #45 · FIXED · 2026-06-07T02:33Z
- **By:** player036  ·  **Channel:** #bug-reports  ·  **ref:** 100000000000000013/100000000000000013

Custom 4 (restrain hotkey) — doesnt work

> dup of #23 (FIXED) — User4 restrain hotkey already wired in fn_keyDownHandler.
---

### #46 · FIXED · 2026-06-07T02:33Z
- **By:** doomba  ·  **Channel:** #bug-reports  ·  **ref:** 100000000000000014/100000000000000014

Groups on civ let you join without a password even when one is set — Groups on civ let you join without a password even when one is set

> dup of #40 (FIXED) — group-join password bypass raised to owner-only (>=5) in fn_joinGroup.
---

### #47 · FIXED · 2026-06-07T02:33Z
- **By:** player002  ·  **Channel:** #bug-reports  ·  **ref:** 100000000000000016/100000000000000016

orca main rotor immortal — f

> dup of #43 (FIXED) — Orca main-rotor damage floored in fn_handleVehicleDamage.
---

### #48 · FIXED · 2026-06-07T17:52Z
- **By:** player002  ·  **Channel:** #Hex not showing up for gang members, only works in group function  ·  **ref:** 100000000000000018/100000000000000018

Hex not showing up for gang members, only works in group function — na

> FIXED (owner-confirmed).
---

### #49 · FIXED · 2026-06-07T17:52Z
- **By:** player002  ·  **Channel:** #gang bank  ·  **ref:** 100000000000000019/100000000000000019

gang bank — when depositing money in atm to gang bank money disappears

> FIXED (owner-confirmed).
---

### #50 · DEFERRED → features.md · 2026-06-07T17:52Z
- **By:** player002  ·  **Channel:** #event admin menu  ·  **ref:** 100000000000000020/100000000000000020

event admin menu — doesn't start events when trying to use.

> investigated — NOT a quick fix. All 4 event SERVER fns (APS_fnc_eventGunGameSRV / eventBRSRV / eventGraveyardSRV / eventPurgeSRV) are STUBS (deobf gap, 'no 2017 source', 7-line log-only). The admin menu + client event fns + CfgRE whitelist all exist, but the server orchestration that actually runs each event (gather players, teleport, loadouts, loop, win, cleanup) was never written. This is a feature build (4 mini-gamemodes). NEEDS a decision: build it (sizable, per-event) or defer.

> DEFERRED 2026-06-09 → logged to **features.md** ("Admin event system — 4 events stubbed"). Not a bug — feature backlog item.
---

### #51 · FIXED · 2026-06-07T20:51Z
- **By:** player066  ·  **Channel:** #bounty  ·  **ref:** 100000000000000021/100000000000000021

bounty — bounty hunter,
bountys dont go away after sending to jail.

> staged: cop/BH-arrest path (arrestAction->handleJail->jailMe) never set ga_arrested (jailMe only set it FALSE, on release) -> jailed fugitives read as not-arrested -> fetchPersistentBounties kept re-adding them to BH lists -> BH stuck tracking a now-$0 ghost. Set ga_arrested=true at jail-START in fn_jailMe (mirrors ja1l); handleJail's existing clear now sticks. Does NOT touch wanted/crimes -> fugitive stays wanted until they serve time / pay bail. NEEDS test.
---

### #52 · FIXED · 2026-06-07T21:07Z
- **By:** player066  ·  **Channel:** #boxes  ·  **ref:** 100000000000000022/100000000000000022

boxes — item drops in boxes dspawn within 3 min.

> staged (tentative): dropped-briefcase path is already floored 20-30 min (#25). Likely 3-min reaper = fn_cleanup's GroundWeaponHolder sweep deletes any holder with 0 PHYSICAL cargo as 'empty' -- but a holder carrying VIRTUAL items (ga_droppedItems) has 0 physical cargo. Guarded it (virtual-item holders = non-empty). NEEDS nikki's exact repro (what item, dropped how, what box); if still despawning it's a different container.
---

### #53 · FIXED · 2026-06-07T21:15Z
- **By:** player066  ·  **Channel:** #bounty hunter  ·  **ref:** 100000000000000023/100000000000000023

bounty hunter — still not downing people put three mags into torches head and he didnt go down

> FIXED (owner-confirmed).
---

### #54 · FIXED · 2026-06-07T21:17Z
- **By:** player066  ·  **Channel:** #vehicle shop  ·  **ref:** 100000000000000024/100000000000000024

vehicle shop — cant buy helis or cars at pyrgos bounty.

> staged: BH ('vigi') vehicle vendors (incl Pyrgos) gated EVERY buy on talent 8 (Master Bounty Hunter) -> regular licensed BHs couldn't buy any car/heli. Lowered to license_civ_bounty (matches the BH weapon-shop gate) in fn_civVehicles (3 actions). Revert to '8 in AP_side_talents' if Master-only was intended. NEEDS test.
---

### #55 · FIXED · 2026-06-09T07:12Z
- **By:** player036  ·  **Channel:** #Athira HQ is fucked  ·  **ref:** 100000000000000025/100000000000000025

Athira HQ is fucked — its like someone copy and pasted a whole ass other hq on top of it a couple times

> FIXED — Eden-experiment objects had packed into mission.sqm and double-spawned Athira HQ. Reverted mission.sqm to the clean baseline + rebooted 2026-06-09.
---

### #56 · FIXED · 2026-06-09T07:31Z
- **By:** player036  ·  **Channel:** #Bodys dont drop  ·  **ref:** 100000000000000026/100000000000000026

Bodys dont drop — bodies do not drop from boats

> staged: corpse-eject (fn_onPlayerKilled) ejected from helis promptly but from cars/BOATS only once the vehicle was DESTROYED -> a body in an intact boat stayed stuck in the seat. Added Ship to the prompt-eject group (12s, ejects while alive) + skip the heli z=0 drop for boats so the body stays at the surface, not the seabed. NEEDS test: die in a boat -> body drops out.
---

### #57 · FIXED · 2026-06-09T18:31Z
- **By:** player040  ·  **Channel:** #Cop prestige  ·  **ref:** 100000000000000027/100000000000000027

Cop prestige — When you log and come back any prestige talent you learn is gone and needs to be learned again

> staged (deployed Beta 0.0.15): ROOT CAUSE = column collision. `cop_talents` was shared by TWO trees — the cop STANDARD talent tree (`AP_side_talents`, talentCfg west IDs 73-129) AND the cop PRESTIGE tree (`AP_cop_talents`, prestigeCfg cop IDs 1-41). `fn_updateRequest` (periodic/disconnect save) writes `cop_talents=AP_side_talents` on EVERY sync, so it overwrote the prestige unlocks (case-16 partial save) within seconds → prestige never survived a relog. Medic was unaffected (`medic_talents` ≠ `med_talents`). FIX = gave cop prestige its own column `pre_talents` (the legacy `fn_update` already references it; that path is dead). Changes: `ALTER TABLE players ADD pre_talents TEXT` (done, live — no seed; unlocks were never persisted so nothing to migrate, banked `prestige` currency intact → re-learnable); `fn_updatePartial` case 16 `cop_talents`→`pre_talents`; `fn_queryRequest` SELECT + `pre_talents`, cop slot 17 (`AP_cop_talents`) ← `pre_talents`. cop_talents now cleanly = standard tree. Checked medic = already fine, no change. Needs reboot (server PBO repack) + in-game test: learn a cop prestige speciality → relog → still learned.

---

### #58 · FIXED · 2026-06-09T20:12Z
- **By:** player040  ·  **Channel:** (in-session)

Killing a cop only charges on EXECUTION, not on a normal shooting — should give Manslaughter.

> staged (deployed Beta 0.0.15): ROOT CAUSE = killer attribution lost on revivable deaths. Cops are revivable (AP_revive_cops) so a shot cop goes DOWNED then dies by bleed-out / scripted setDamage, where the engine "Killed" EH `_killer` = the victim itself (not the shooter). fn_onPlayerKilled's wanted-charge gate (`_killer != _unit && side _killer civilian`) then skips -> no Manslaughter [12]. Execution charged explicitly in fn_executionerMove [9], so it always landed. FIX: fn_handleDowned stamps `ga_downedBy=[shooter,time]` on the victim; fn_onPlayerKilled resolves `_killer` from it when attribution is null/self + recent (<20min) + not a suicide -> the existing [12] Manslaughter (or [9] if restrained) charge now fires on the real killer. Instant kills unchanged (no double-charge). Helps civ-on-civ bleed-out murders too.
### #59 · FIXED · 2026-06-09T20:48Z
- **By:** player066  ·  **Channel:** #gang  ·  **ref:** 100000000000000028/100000000000000028

gang — people still get kicked out of gangs on restart or rejoin

> audit note (triage first, the answer forks the fix): when a victim reports it, run `SELECT gang0,gangrank0 FROM players WHERE playerid='<pid>';` and `SELECT id,name FROM gangs;` (docker exec -i looneybin-db mariadb -ulooneybin -plooneybin looneybin). FORK A — gang0 is '0'/wrong in the DB = a WRITE-side bug: suspects are the kick/leave branch in `server/AP_server/core/TON/fn_updateGangMem.sqf:37-38` (clears gang0='0' — check what calls it on disconnect/restart) and `fn_deleteGang`'s ex-member reset firing for a live gang. FORK B — DB row intact but the player loads gangless = a LOAD/ROSTER bug: `fn_queryRequest.sqf` gang block (`_gangId>0` → SELECT gangs WHERE id → empty result = orphaned id → client gets gang_data=[]) or client `fn_initGang`/group join. Note gangs.id doubles as the gang-HOUSE build id; the boot-time renumber in `fn_receiveHouses.sqf:74-90` DOES remap players.gangN but ONLY in rebuild mode (config idx 10) — verify rebuild mode hasn't been left on. Also check the RPT for '[LooneyBin][receiveGangs]' count vs gangs table count at boot.

> staged (deployed Beta 0.0.15): defensive load fix in `fn_queryRequest.sqf` gang block — if gang0 points at a gang the SELECT can't find, RETRY once after 1s; if still empty, RPT-log `[LooneyBin][GANG-ORPHAN] uid=… gang0=…`. Cures transient boot-rush load failures outright and produces the evidence to settle the write-side-vs-orphan fork if it recurs. Root cause not yet confirmed — leave open until a post-reboot repro or a GANG-ORPHAN log line shows.

---

### #62 · FIXED · 2026-06-09T20:48Z
- **By:** (in-session)  ·  **Channel:** (Torch)

Torch can't be downed — downing/stun rounds do nothing to him, but normal rounds kill him. Only affects him.

> staged (deployed Beta 0.0.15): ROOT CAUSE = stale `AP_isDowned` stuck `true` on his client. fn_handleDamage's stun/non-lethal path sets `_damage=0` then calls handleDowned; handleDowned's guard `!(!AP_isDowned && alive && isNull findDisplay 7300)` early-exits when AP_isDowned is true -> the down round does NOTHING (0 dmg + no down). Normal lethal rounds skip that path -> still kill. Per-client flag -> hits one person. Likely left true after a botched revive/recovery (a relog clears it, configuration.sqf resets it). FIX: fn_handleDowned now clears a STALE AP_isDowned (flagged downed but no downed-UI display 7300 + alive) before the guard, so a genuine down fires; when actually down (7300 present) it won't clear. General fix for any stuck player. Torch can also relog to clear immediately.
### #60 · FIXED · 2026-06-09T20:53Z
- **By:** doomba  ·  **Channel:** #bounty hunter  ·  **ref:** 100000000000000023/100000000000000029

civs cant down civs

> audit note (for the fix author): the down-vs-kill gate is `evh/fn_handleDamage.sqf` ~lines 59-77. `_stunMag = ("Tracer" in _curMag) || (_copSource && _nonLethal)` and the down branch needs `_stunMag || _curWep in ["SMG_02_F","hgun_P07_F",...]`. Two suspects for civ-on-civ: (1) `_nonLethal = (gunner _source) getVariable["ga_nonlethal", true]` — `gunner` of a MAN on foot may be objNull, so the var read never hits the shooter and the default applies; civs never set ga_nonlethal at all (only fn_initCop.sqf:61 sets it) so civ shooters depend ENTIRELY on the Tracer-mag/weapon-whitelist branch; (2) the BH stun weapon/mag the civs use may not be in that whitelist (see bug #2's pending rubber-bullet mag + the [BHdmg] diag in the same file which logs exactly the needed classnames). FIX path: pull the real mag/weapon classnames from the [BHdmg] RPT lines during a civ-vs-civ test, add them to `_stunMag`/the weapon list, and consider reading ga_nonlethal off `_source` (the man) instead of `gunner _source`. TEST: civ shoots civ with stun loadout → target downs; lethal loadout still kills.

> staged (deployed Beta 0.0.15): CONFIRMED root cause — civ stun shots entered the down-gate via the weapon whitelist (Sting `SMG_02_F` / P07s) but the inner condition only downed on `_damage >= 1 || _stunMag`; civs have `_stunMag=false` (no Tracer mag, not cop) and 9mm almost never reaches 1.0/hit → chip damage, never a down. FIX in `evh/fn_handleDamage.sqf`: fatal-hitbox hits from a whitelisted stun WEAPON now down outright (`|| _curWep in ["SMG_02_F","hgun_P07_F","hgun_P07_khk_F","hgun_P07_blk_F"]`), matching cop non-lethal. Lethal-BH P07 still excluded at the outer gate. TEST: civ Stings civ in torso → instant down; arms/legs hits still chip.

---

### #63 · FIXED · AUDIT
- **By:** code audit  ·  **Channel:** internal sweep

Combat-log after death keeps gear — death-gear reset is never saved to DB (dupe vector).

> ROOT CAUSE: on death `evh/fn_onPlayerKilled.sqf` resets `AP_gear` to the side's death-default and calls `[_partialMode] call AP_fnc_ClupdatePartial` with mode **11 (civ) / 12 (cop) / 13 (med)**. But in `core/session/fn_ClupdatePartial.sqf` cases 11/12/13 are EMPTY (`{}` — push no payload), and server `server/AP_server/core/DB/fn_updatePartial.sqf` has NO case 11/12/13 (cases jump 10→14) → the call is a no-op end to end. So the DB keeps the PRE-death gear; a player who disconnects after dying (before respawn re-save) relogs with all their gear back = combat-log dupe.
> FIX (Opus): in client `fn_ClupdatePartial` cases 11/12/13 `_packet pushBack AP_gear;` (it already holds the death default at that point), and in server `fn_updatePartial` add `case 11: { _qP = format ["civ_gear='%1'", [_d] call _enc]; }; case 12: { _qP = format ["cop_gear='%1'", [_d] call _enc]; }; case 13: { _qP = format ["med_gear='%1'", [_d] call _enc]; };` (mirror case 3's _enc usage). TEST: die as civ with gear → Alt-F4 before respawn → relog → gear should be the death default, not the old loadout.

> staged (deployed Beta 0.0.15): exactly as above — client `fn_ClupdatePartial` cases 11/12/13 now `_packet pushBack AP_gear;`; server `fn_updatePartial` gained `case 11/12/13` writing civ/cop/med_gear via `_enc` (mirrors case 3).

---

### #64 · FIXED · AUDIT
- **By:** code audit  ·  **Channel:** internal sweep

Blindfold ITEM does nothing when used.

> ROOT CAUSE: `core/pmenu/fn_useItem.sqf:59` calls `[] spawn AP_fnc_blindfold;` — that function does not exist anywhere (Functions.h registers `blindfoldAction` + `blindfoldClient`, never `blindfold`) → script error → using the blindfold item from the Y-menu is a no-op. The WORKING path is the scroll action in `core/fn_setupActions.sqf` ("Remove Blindfold" → `[2,cursorObject] spawn AP_fnc_blindfoldAction`), which suggests blindfoldAction's mode arg: read `core/actions/fn_blindfoldAction.sqf` params first — mode 2 = remove, so APPLY is presumably mode 1.
> FIX (Opus): read fn_blindfoldAction's params, then replace useItem line 59 with the apply call (likely `[1, cursorObject] spawn AP_fnc_blindfoldAction;` plus its own target checks — restrained, in range, isPlayer). TEST: restrain someone → use blindfold item from Y-menu inventory → target gets ga_blinded screen; "Remove Blindfold" scroll action clears it.

> staged (deployed Beta 0.0.15): `fn_useItem.sqf` blindfold case → `[1, cursorObject] spawn AP_fnc_blindfoldAction;`. Also removed the pre-consume (`handleInv` before the broken call) — the item was being DESTROYED for nothing; blindfoldAction consumes on success and does its own restrained/blinded/range checks.

---

### #65 · FIXED · AUDIT
- **By:** code audit  ·  **Channel:** internal sweep

Clothing shop "barber" and "faces" filter tabs script-error (functions missing).

> ROOT CAUSE: `core/shops/fn_clothingFilter.sqf` references `AP_fnc_clothing_barber` and `AP_fnc_clothing_faces` — neither exists (no fn_clothing_barber.sqf / fn_clothing_faces.sqf; Functions.h has only clothing_civ/cop/med etc.) → selecting those filter tabs in the clothing menu throws and the list stays empty/stale.
> FIX (Opus): open fn_clothingFilter.sqf, find the tab→fn dispatch. Either (a) create the two config fns mirroring `core/config/fn_clothing_civ.sqf`'s shape (return [classname, displayName, price] arrays — barber = headgear/hair, faces = goggles/facewear), or (b) if barber/face shops aren't wanted, strip those tabs from the dialog + dispatch. TEST: open clothing shop → click every filter tab → no RPT script errors, lists populate.

> staged-partial (this pass): NOT auto-fixed — needs an owner call. The types ARE wired through buyClothes/changeClothes/clothingMenu (`faces` even has special setFace handling), so the intended fix is real `fn_clothing_barber.sqf`/`fn_clothing_faces.sqf` config fns (mirror `fn_clothing_civ.sqf`'s `[class, displayName, price]` rows: barber = headgear/hair, faces = CfgFaces names) + registering both in Functions.h next to clothing_civ. Until then the tabs error ONLY if some shop opens with type `barber`/`faces` — no mapData NPC currently does, so live impact is nil. Owner: want barber/face shops built, or strip the two dispatch cases?

---

### #66 · FIXED · AUDIT
- **By:** code audit  ·  **Channel:** internal sweep

Receiving a gang-war challenge errors (undefined function ref).

> ROOT CAUSE: `core/gangs/fn_warChallenged.sqf` calls `AP_fnc_gangWars` — undefined. The real menu fn is `AP_fnc_gan1gWarsMenu` (`core/gangs/fn_gan1gWarsMenu.sqf`, deobf-mangled name). The challenged gang's notification/menu-refresh path dies on the missing symbol.
> FIX (Opus): read fn_warChallenged.sqf, point the ref at the correct fn (`AP_fnc_gan1gWarsMenu`, or whatever the call's intent needs — likely refreshing the wars list if the menu is open). TEST: gang A `!challenge`s gang B from the gang menu → B's online members get the war-challenged prompt without RPT errors → accept → war starts.

> staged (deployed Beta 0.0.15): `fn_warChallenged.sqf` → `[] spawn AP_fnc_gan1gWarsMenu` (the deobf-mangled real fn; it waitUntils display 9580 + repopulates, so calling it with the menu open = a refresh — exactly the original intent).

---

### #67 · FIXED · AUDIT · LOW
- **By:** code audit  ·  **Channel:** internal sweep

Leftover TEMP DIAG log spams the RPT on every player hit.

> `evh/fn_handleDamage.sqf` lines ~61-66: the "#2 BH rubber-bullet" diagnostic (`[LooneyBin][BHdmg] wep=... mag=...`) logs on EVERY player-vs-player hit (0.5s throttle per victim) + does a setVariable per hit. It was added to capture the BH rubber-bullet magazine classname and is marked "REMOVE after wiring".
> FIX (Opus): if the rubber-bullet mag classname has been captured from the RPT, add it to the `_stunMag` allowlist (same file, the `("Tracer" in _curMag)` line) and DELETE the diag block. If not yet captured, leave until one BH fight has run, then do both. TEST: BH stun rounds down (not kill); RPT free of [BHdmg] spam.

> decision (this pass): diag KEPT deliberately — it's the instrument that confirms #60's stun-weapon fix and captures the rubber-bullet mag classname for #2. Remove on the pass AFTER #60 is verified in-game.

---
### #68 · FIXED · 2026-06-09T21:18Z
- **By:** code audit  ·  **Channel:** internal sweep (phone/messaging)

Phone texts to The Admins, admin "Message All"/"Message Send" (phone buttons), and the Governor broadcast all silently VANISH; player-to-player texts never land in the phone inbox; 311 shows as a bare text line.

> ROOT CAUSE: the server text router `server/AP_server/core/TON/fn_handlePhoneMsg.sqf` only had cases for modes 0/1/2, but the client (`core/pmenu/fn_sendText.sqf`) sends mode **3** (msg The Admins), **5** (admin→all via phone), **6** (admin→single player), and **10** (governor broadcast, sent by client case 7). Those fell through the switch and vanished — the SENDER still saw "You sent … a message", so nobody noticed. Additionally mode 0 (P2P text) was delivered as a plain `handleMessage` line instead of `AP_fnc_clientMessage` type 0, so the text never entered the receiver's phone inbox (`AP_messages`) and reply-tracking (`AP_last_message`) never set; and 311 (mode 2) bypassed the proper EMS dispatch display/marker.
> staged (deployed Beta 0.0.15): rewrote the router. mode 0 → clientMessage type 0 (rich box + inbox + reply target); mode 2 → clientMessage type 2 (EMS dispatch box + map marker + inbox); mode 3 → all ONLINE admins (players_global adminlevel ≥ 2, `QUOTE(playerid)` to dodge the >2^53 UID precision loss), with a "no admins online — use !report" bounce to the caller; mode 5 → clientMessage type 5 to all + log (twin of APS_fnc_adminMsg); mode 6 → type 6 to target + log; mode 10 → type 10 to all + log. 911 (mode 1) untouched — its copalert + tactical-ping form is a deliberate redesign. VERIFIED FINE in the same sweep: voice calls (fn_handlePhoneCallSRV radio-channel system), cellphone dialog populate (UID lbData), message-history inbox viewer, admin-menu Message All (APS_fnc_adminMsg), taxi button (intentionally disabled).
> TEST after reboot: civ texts a player → receiver gets the New Message box AND it appears in their Message History; civ "Text The Admins" → online admin gets the red Admin Request box + map marker (with no admin online sender gets the !report bounce); admin phone "Message to All" → everyone gets the Admin Message box; admin "Message Send" → only the target; governor "Gov. Message All" → everyone gets the green Gov box; !311 → medics get the green dispatch + EMS marker; !911 unchanged.

---
### #69 · FIXED · 2026-06-10T00:02Z
- **By:** doomba  ·  **Channel:** (in-session)

Federal Reserve rework — nothing locked at boot; break-in/gate/safe flow + timings wrong; no per-dome gold.

> staged (deployed Beta 0.0.15): full rework per owner spec. (1) BOOT LOCKDOWN (server init, +12s): every fed dome door disabled+shut (ga_vaultlocked 1), inner safe buildings (Land_Research_*) locked+shut, gates shut (gate_max 0) — previously NOTHING was ever locked. (2) GATES: boltcut now flat 30s per gate (cops unlocking during a robbery: 10s) and CONSUMES the boltcutter (`fn_openGate`). Gates independent of dome entry — vehicle convenience only. (3) DOME BREAK-IN: `fn_openVault` = scroll action "Break Into Dome (Side Door)" at the door_1a/1b/2a/2b panels, NO tool needed, flat 60s, per dome. Success = all dome doors UNLOCKED but only the small side doors swing open — the big vehicle door is openable (engine interaction) only from then on. (4) GOLD: success fires new server fn `APS_fnc_fedGoldSpawn` — ONE briefcase per inner building of THAT dome, each with 1–5 goldbar (lootable ga_droppedItems suitcase, self-deletes when emptied / 30 min); once per dome per robbery (ga_goldSpawned, reset by lockdown). (5) INNER BUILDINGS: drill = 25s; demo charge path unchanged & already to spec (10s plant → grenade explosion → door opens; talent-43 gated, charge consumed). TEST: full chain at the fed — locked at boot → 30s gate cut eats cutter → drill + 105s side-door break-in → cases with gold in the inner buildings → 25s drill / demo the inner doors → vehicle door opens only post-break-in.
> v2 (owner tweaks, same session): side-door break-in = DRILL REQUIRED + flat 105s; inner-building drill = 25s. ALARM REWORK: (a) server watcher — an UNMASKED civilian (goggles not in the AP_masks list) entering within 175 m of fed_reserve trips APS_fnc_fedAlarm (dispatch + siren + MaxTac chain; self-guarded, masked entry silent); (b) every side-door breach alarms unconditionally 10 s later (replaced the old only-if-not-robbed immediate alarm). TEST v2: walk in unmasked → alarm + MaxSec dispatch; walk in masked → silent; breach side door masked → alarm at +10 s.

---
### #70 · FIXED · 2026-06-10T03:20Z
- **By:** doomba (gov vote report) + code audit  ·  **Channel:** in-session

2017↔2020 passthrough-shim sweep (the mailbox-bug class): 7 more silently-broken systems found + implemented.

> ROOT CLASS: ~28 server fns are "rename layer" passthroughs feeding the 2020 client's args into 2017 functions with DIFFERENT signatures — the call either type-errors or silently no-ops. Confirmed broken + FIXED (all staged):
> 1. **statTableUpdate** — EVERY lifetime-stat increment (kills, arrests, playtime, boltcuts…) was lost; now read-modify-writes the players_global.stats array.
> 2. **getStatsArr** — titles/stats menu never got data; now replies APV_statTotals via netSetVar.
> 3. **update1GangTalents** — gang XP + gang PERKS never persisted (lost every restart); now writes gangs.experience+talents + refreshes the boot cache.
> 4. **bulkAdd** — a connecting criminal's standing charges were never re-registered on the wanted list; now rebuilds their entry (bounty + per-charge counts + jail time) if absent.
> 5. **adminPlayerQuerySRV** — spectate/ESP suspect-info panel never populated; now queries DB + replies AP_suspectInfo.
> 6. **eventParticipants** — 2020 sends [add,unit], 2017 wanted [unit,add] → event queue never filled (BR winner detection reads it). Args swapped.
> 7. **govSystemSRV (the reported bug: "vote for governor doesn't work")** — client speaks a CASE protocol, 2017 was positional → candidacy half-worked, voting dead. Full backend built: runForOffice (broadcast + 30-min election clock), getCandidates reply, addCandidateVote (one per player via votes table), election resolution (most votes → SRV_governorData publish + broadcast), tax cache → governor bank payouts, updateGovConfig tax-rate (0–15%, guarded). Stale votes cleared at boot.
> Plus same-session: processMailbox (the comp mailbox, "Type Object expected Array" RPT error) implemented.
> SHIM SWEEP ROUND 2 (same session) — all 14 verified, 8 MORE implemented: **handlePrisonBreak** (prison break NEVER started — 2017 isNull gate ate the args; start/stop router + 20-min watchdog + SRV_prisonData, which was itself never defined anywhere), **handleDispatch** (cop backup/superior requests went nowhere — now copalert + map ping, superior = LT+), **trialSystemSRV** (court never started — case router into the 2017 jury flow: summons → 12-juror bench → guilty/innocent votes, one per juror), **timeTrialSRV** (race finishes paid nothing — payout + state clear), **updateHousePrice** (market listings lost on restart — persists houses.sale), **transferHouse** (buying a market-listed house never transferred ownership — row transfer + seller payout + retag), **varPersist** (cops' dirty-cash trace never armed — sets ga_banktrace on the target), **changeServCycle** (admin restart-cycle adjust — now shifts the in-game countdown; real restarts stay with loonybot). VERIFIED FINE: srvObjectMonitor (extra arg harmless), huntingGrounds (args ignored by design). DEAD (no callers): checkPlayer, getID, spawnPhysicalItem. **DEFERRED (big, own session): exchangeSystemSRV — the player-market backend speaks 6+ modes; the whole Exchange is presumed dead until built.**

---
### #71 · FIXED · 2026-06-10T14:59Z
- **By:** player004  ·  **Channel:** #There are rockets and MX SW inside a crate in cartel  ·  **ref:** 100000000000000030/100000000000000030

There are rockets and MX SW inside a crate in cartel

> staged (deployed Beta 0.0.15): closed by the #76 fix — the rockets/MX SWs were `B_supplyCrate_F`'s vanilla default cargo, now cleared on spawn + replaced with mild per-cartel loot.

---

### #72 · FIXED · 2026-06-10T15:03Z
- **By:** player053  ·  **Channel:** #OIL CARTEL BROKEN  ·  **ref:** 100000000000000031/100000000000000031

OIL CARTEL BROKEN — The oil cartel is just a flag in the water, nothing to stand on.

> deployed: server boot places a rescue-helipad deck under the oil flag ("[LooneyBin][cartel] oil deck placed under the flag" in every boot log since) — stand on it to collect rubber without swimming. Related dive-capture fix in #86. AWAITING player053 in-game verify of deck height.

---

### #73 · FIXED · 2026-06-10T15:53Z
- **By:** player053  ·  **Channel:** #Can't open cartel crates.  ·  **ref:** 100000000000000032/100000000000000032

Can't open cartel crates. — Opens your phone when you try to open the inventory of the box.

---

### #74 · FIXED · 2026-06-10T16:56Z
- **By:** doomba  ·  **Channel:** in-session

Suppressors (and other weapon attachments) still despawn off players when killed and revived.

> staged (deployed Beta 0.0.15): ROOT CAUSE = a race in the revive gear restore (`fn_loadDeadGear`): the weapon adds were SPAWNED async with no wait, then the attachment loops ran immediately — `addWeaponItem` on a weapon that isn't equipped yet silently drops the attachment, so suppressors/optics vanished whenever the weapon add lost the race (usually). FIX: each weapon add (primary/launcher/handgun) is now awaited before its attachment loop runs. ALSO: launcher attachments were never captured at all in `fn_fetchDeadGear` (`_secitems` declared empty and left empty) — now captured. NOTE: the DB gear save ("gear save stack") already preserves attachments by design — `fn_saveGear`/`fn_loadGear` use getUnitLoadout/setUnitLoadout which are full-fidelity — so relog/restart was never the leak; only death→revive was. TEST: equip suppressor+optic → die → get revived → attachments still on all weapons.

---
### #75 · FIXED · 2026-06-10T17:28Z
- **By:** doomba  ·  **Channel:** in-session

Full-arsenal shops: duplicate gun entries + new guns have no ammo (rebel + MaxSec).

> staged (deployed Beta 0.0.15): two architectural mistakes in the first arsenal pass. (1) NO AMMO: the weapon-shop side panel pulls compatible ammo from `fn_weaponAddons`, NOT the weapon list (`fn_weaponShopCfg`) where I'd put the mags -> new guns showed no buyable ammo. FIX: build every scope-2 gun's magazines once and inject them into weaponAddons for rebelwep + police_weapons (mags $100, launcher missiles $25k, missiles rebel-only); the side panel then filters by compatibility per selected gun. (2) DUPES: enumerating CfgWeapons yields camo variants sharing one display name -> looked like duplicate entries. FIX: weaponShopCfg now lists ONE gun per unique display name and also dedupes against the curated list's display names, so no gun appears twice. Launchers = Titan family + RPG-7 only, rebel-only. Caches: AP_dynGuns (guns) + AP_dynShopMags (ammo), built once per client.
---
### #76 · FIXED · 2026-06-10T17:50Z
- **By:** player053  ·  **Channel:** #All cartels have same loot in the box  ·  **ref:** 100000000000000033/100000000000000033

All cartels have same loot in the box — .

> staged (deployed Beta 0.0.15, also closes #71): the cartel capture containers are `B_supplyCrate_F` — vanilla Arma ships that crate **pre-filled with NATO cargo (MX SWs + Titan rockets + mags)**, so all four cartels showed identical, way-too-spicy loot. FIX (server init.sqf): clear all default cargo on spawn, stock per-cartel flavor — Arms: 2x Mk20 + 6 mags · Drug: 6 FAK + 1 Medikit · Oil: 2 ToolKits · Wong's: Sting SMG + 4 mags. Cartel's real reward stays the dirty-money/rubber retrieve.

---

### #77 · FIXED · 2026-06-10T17:58Z
- **By:** player053  ·  **Channel:** #BOX TRUCK CHEAPER THEN NORMAL TRUCK  ·  **ref:** 100000000000000034/100000000000000034

BOX TRUCK CHEAPER THEN NORMAL TRUCK

> staged (deployed Beta 0.0.15): `C_Van_01_box_F` was $7,100 while the plain transport van (`C_Van_01_transport_F`) was $8,500 — box cheaper at identical 50 storage. Re-slotted the box truck into the truck ladder (fn_vehicleConfig): **$15,000 buy / $7,500 garage / 65 storage** — van 8.5k/50 → van02 12k/60 → BOX 15k/65 → zamak 20k/70 → covered 25k/80 → HEMTT 30k/100 → HEMTT box 45k/120. Owned box trucks keep working; new buys pay the new price.

---

### #78 · FIXED · 2026-06-10T18:10Z
- **By:** owner  ·  **Channel:** in-session

Virtual Arsenal button in admin menu doesn't work ("probably anticheat preventing it").

> staged (deployed Beta 0.0.15): the button (idc 12915) was *unhidden* (fn_adminMenu.sqf line 54, owner request) but had no working `onButtonClick` — clicking a live-but-dead control did nothing. FIX: button now runs `['Open', true] spawn BIS_fnc_arsenal` gated to admin level >= 3 (dialog/admin_menu.hpp:430). Safety net: the per-machine anti-cheat command lock (CfgDisabledCommands.hpp) was fully blocking `CREATEGEARDIALOG` and `GETMOUSEPOSITION` (targets 0,0,0) — gear/mouse UI commands the arsenal can use for drag-drop — now allowed server+client (1,1,0). createDisplay/createDialog/ctrlCreate were already allowed, so the arsenal display itself was never blocked. No arsenal error in RPT (button was dead, never fired). TEST after reboot: admin menu → Virtual Arsenal → opens + can take/drag gear.

---

### #79 · FIXED · 2026-06-10T18:06Z
- **By:** player053  ·  **Channel:** #High Yield quarry doesn't work  ·  **ref:** 100000000000000035/100000000000000035

High Yield quarry doesn't work — Says mining done no more room when  I have 100 space in my inv.

> staged (deployed Beta 0.0.15, same fix as #80): "no more room" was a LIE — weight had plenty of room. `fn_handleInv` has a hidden item-COUNT monitor (the 2020 client's memory-hack detector): a hard **130-total-virtual-items cap** + a drift tracker (`AP_invMonitor` vs actual). Hit either and EVERY inventory add returns false → fn_m1ne prints "Mining done. You can't hold more minerals." Beta god-stat players have huge maxWeight, so 130 light items still leaves ~100 weight free — exactly the report. Worse: the same monitor sat as an `exitWith` in the periodic save (`fn_ClupdateRequest`), the gear save (`fn_ClupdatePartial` mode 3) and `fn_dropItems` — past 130 items your saves silently STOPPED and you couldn't even drop items. FIX (all 4 files): same treatment as the other neutered AC checks — keep the log, resync the tracker, never block. Weight (`AP_maxWeight`) is now the only inventory limit. TEST: mine at quarry past 130 total items → keeps mining until weight is actually full; gear still saves.

---

### #80 · FIXED · 2026-06-10T18:07Z
- **By:** player053  ·  **Channel:** #Normal Quarry Doesn't work  ·  **ref:** 100000000000000036/100000000000000036

Normal Quarry Doesn't work — Same issue as high yield

> staged: same root + fix as #79 (the 130-item monitor in fn_handleInv), both quarries share `fn_m1ne`.

---

### #81 · FIXED · 2026-06-10T18:28Z
- **By:** player053  ·  **Channel:** #Can't sell Oysters  ·  **ref:** 100000000000000037/100000000000000037

Can't sell Oysters — .

> staged (same root as #79/#80): selling calls `fn_handleInv` to REMOVE the items, and the 130-item monitor's block sat before BOTH the add and remove paths — over 130 total items you couldn't sell, drop, gather or save. Same reporter, same mining session. The #79 fix (log + resync, never block) restores selling. NOTE oyster pipeline otherwise intact + by design: gather fresh at the oyster fields → "Cook Oysters" at a lit campfire/burn barrel → sell COOKED at Wong's (fresh oysters not sellable raw).

---

### #82 · FIXED · 2026-06-10T18:35Z
- **By:** player053  ·  **Channel:** #Rebel weapons need price re-work  ·  **ref:** 100000000000000038/100000000000000038

Rebel weapons need price re-work — Most guns are same price, for example the Navid 9.3 LMG is same price as a 6.5 MXM

> staged (deployed Beta 0.0.15): the full-catalog injection (#75) priced every dyn rifle a flat $8k. Now priced off the chambered round's CfgAmmo damage on a hit² curve, +50% for belt/drum (>=100rnd) feeds: 5.56 ≈ $9.6k · 6.5 ≈ $15k · 7.62 ≈ $18k · .338/9.3 MGs (SPMG/Navid) ≈ $40–65k · .50 snipers ≈ $110k; handguns scale the same at a lower base. Curated hand-priced entries untouched; launchers stay $150k.

---

### #83 · FIXED · 2026-06-10T18:37Z
- **By:** player004  ·  **Channel:** #Lottery price money  ·  **ref:** 100000000000000039/100000000000000039

Lottery price money — Lottery price money not going up

> staged + DB seeded live: the `config` DB table had ONE row (index 200) but the lottery reads `AP_configuration select 8` (jackpot) → "Zero divisor", `_jackpot` undefined, every ticket sprayed an `_x undefined` burst through `DB_fnc_updateConfig` (the 13:35Z RPT loop). FIX: (1) seeded config rows 0–10 live (jackpot=25, rest 0 — governor timestamps index 0/1/4, house-migration flag index 10); (2) `fn_addToLottery` now `param [8, 25]` + scalar coercion; (3) `DB_fnc_updateConfig` skips nil holes. Jackpot starts at $25k and climbs $1k per losing ticket after reboot.

---

### #84 · FIXED · 2026-06-10T18:55Z
- **By:** owner  ·  **Channel:** in-session

Bank (Bank of Altis) drill doesn't work.

> staged (deployed Beta 0.0.15): the "Begin Drilling Vault" action's CONDITION reads `AP_bank_robbed` ([inProgress, lastEndTime]) and the click handler reads `SRV_lastRobbery` — **neither was ever defined anywhere in this build**, so the condition errored and the action never appeared. FIX: server vars.sqf defines + publicVariables both; `fn_bankDrillVault` sets `AP_bank_robbed=[true,serverTime]` at drill start and `[false,serverTime]` + `SRV_lastRobbery=serverTime` at end (also wired into fedAlarm end); client configuration.sqf gets connect-race fallbacks. BONUS FIXES in the same fn: (1) gold-bar payout looped `buy_array` (2017 market var, never defined) → now `missionNamespace getVariable ["buy_array",[]]` with the $50k/bar default; (2) the cop "Disable Drill" action calls the same APS_fnc_bankRobbery but the 2017 fn just exited if drilling — now cop+drilling = drill killed, robbery fails. TEST: drill action shows at bank door with a drill in inventory → 10-min drill → vault opens 3 min, gold bars + dirty money spawn; cop Disable Drill ends it.

---

### #85 · FIXED · 2026-06-10T18:46Z
- **By:** player053  ·  **Channel:** #Vehicle factory  ·  **ref:** 100000000000000040/100000000000000040

Vehicle factory — Kind of ties in to other report, normal truck sells for more at the Vehicle factory.

> staged (same root as #77): every price surface (shop, garage sell-back, factory) reads the same `fn_vehicleConfig` row, so the box-vs-transport inversion showed up at the factory too — the #77 re-slot ($15k/65 storage box, $7.5k sell-back) fixes it everywhere. Factory MATERIAL costs were already correctly ordered (box 15 iron > transport 13 iron) and are untouched.

---


### #86 · FIXED · 2026-06-10T19:20Z
- **By:** owner  ·  **Channel:** in-session

Oil cartel: dive too deep while capturing and it says "currently contested" instead of taking ownership.

> staged (deployed Beta 0.0.15): the capture loop's gang-presence list used `nearEntities [..., 60]` — a **3D sphere**. The oil zone center sits at the surface; a diver collecting rubber on the seabed exceeded the 60m 3D radius, dropped off his own gang's presence list → `_onlyUsInRadius` went false → the loop fell into the "currently contested" branch (the loop's own stay-in-zone check is 2D, so the capture never cancelled — just stuck). FIX (fn_captureCartel.sqf): widen the sphere to 200m and gate membership on 2D distance ≤ 60, matching the loop's stay-in-zone check. Capture start was already oil-aware (underwater eyePos exemption); entry trigger is an unbounded-height cylinder — both untouched. TEST: start oil capture, dive to the seabed → progress keeps ticking, no "contested".

---

### #87 · FIXED · 2026-06-10T19:55Z
- **By:** owner  ·  **Channel:** in-session ("look at the evidence lockup event and see if thats complete")

Evidence Lockup federal event — completeness audit + repairs.

> staged (deployed Beta 0.0.15). What already worked: cop seizures feed the loot pool (APS_fnc_evidenceAppend, wired in seizePlayerIllegalAction + vehBaseSeize), server state machine (APS_fnc_handleTimer), loot-truck payout (APS_fnc_evidenceTruck), electric fence + AA defense (fn_evidenceDefense + evidenceTrigger), demo-charge plant + dome secure actions, cop press-9 redeploy, CfgRE whitelist. FOUR HOLES FIXED: (1) the event was UNSTARTABLE — the civ "Hack Defense Systems" (mode 0) and cop "Repair Defense Systems" (mode 1) laptop actions were never wired into fn_setupActions; both added on the evidence laptop. (2) `AP_fed_robbed` was read by the bomb-fuse calc (+10min when another fed is hot) but never defined anywhere → bomb plant died; now defined in vars.sqf/configuration.sqf and maintained by fn_fedAlarm start/end. (3) the "armory_vault" marker doesn't exist → vault-breach dome lookup hunted [0,0,0] and the breach charge spawned in the sea; fn_evidenceVaultOpen now anchors on the dome's known position. (4) nothing sealed the dome at boot → stood open after every restart; the server laptop block now seals door 3 + resets event vars. FLOW: cop seizures arm the lockup → civ (big gun) hacks laptop 90s → 5min countdown → defenses DOWN → plant demo on dome door (15min fuse, +10 if bank/fed/prison hot) → dome blows → breach vault (2nd demo, 30s) → loot truck spawns with the seized pool (floor: 3 gold bars), keys to the breach group. Cops can repair the laptop mid-hack, secure the dome (180s), disarm the bomb.

---

### #88 · FIXED · 2026-06-10T20:05Z
- **By:** owner  ·  **Channel:** in-session

No house purchases within 500m of cartel red circles.

> staged (deployed Beta 0.0.15): `fn_buyHouse` now rejects any house within 500m (2D) of the four cartel zone markers (arms/drug/oil/wongs) — "You cannot purchase property within 500m of a cartel zone." Gate sits before payment and covers BOTH fresh purchases and owner-to-owner transfers (both paths run through buyHouse). Already-owned houses in the radius are untouched (can still be sold; just can't be re-bought).

---

### #89 · FIXED · 2026-06-10T20:25Z
- **By:** owner  ·  **Channel:** in-session

Add an admin menu item to start the Gang Fortress event.

> staged (deployed Beta 0.0.15): the 2020 client shipped the full Gang Fortress client side (init/HUD/leaderboard, fortress NPC shops + 15% discount gated on the flag's `ga_gang_fortress_data`) but the 2017 serverside never had the event controller — dead feature. BUILT `APS_fnc_gangFortressSRV` (server): "start" arms the fortress for 1 HOUR — every 5s the single gang holding the 125m zone uncontested earns 5 pts; leaderboard = `SRV_gangFortressData` (existing client HUD reads it live); flag var tracks the current leader. Finish (timeout or "stop"): top gang OWNS the fortress (`[winnerID, winnerName, false]`) which unlocks the fortress rebel shops/discount via existing client logic; broadcast + audit log. Ownership is runtime-only (resets at restart). ADMIN MENU: placeholder idc 12922 → "Gang Fortress" toggle button (Admin+ lvl 3) — starts when idle, stops early when running. Registered in server config.cpp + CfgRE whitelist. TEST after reboot: admin menu → Gang Fortress → broadcast + red 125m zone marker + HUD inside zone; hold uncontested → points; end → winner owns fortress shops.

---

### #90 · FIXED · 2026-06-10T20:45Z
- **By:** owner  ·  **Channel:** in-session ("look at groups make sure they are working as intended")

Groups (civilian temp groups) — audit + repairs.

> staged (deployed Beta 0.0.15). AUDIT: the system is structurally sound — create/join (incl. password dialog), browser, lock/unlock, kick (incl. founder-succession to kicker), set-leader, set-password (leader-gated), leave (founder hands off to next member; last member deletes the entry), JIP sync via publicVariable'd `randomized_life_group_list`, gang-group rejoin after leaving a temp group, group tags on nametags. The `str _x` → `missionNamespace getVariable` member lookup works because mission.sqm playable slots are named units. THREE FIXES: (1) REAL BUG — fn_createGroup's password-length check reused the group NAME's length, so any 17–25 character group name was rejected with a bogus "maximum password is 16" error; now measures the password itself. (2) fn_createGroup had no cooldown (lock/unlock/setPass all have one) — added 30s, since every create publicVariables the whole list. (3) fn_groupManagement crashed on `select -1` when AP_my_gang went stale (entry deleted while the client lagged) — now resets + bounces to the browser. NOT changed (original Asylum semantics): all groups are password-locked by design; kicking the founder transfers foundership to the kicker; admin level >= 5 password bypass (no such level here, dead code).

---
### #91 · FIXED · 2026-06-10T19:56Z
- **By:** player053  ·  **Channel:** #Quarry & high Yield still broken  ·  **ref:** 100000000000000041/100000000000000041

Quarry & high Yield still broken — .

> staged instrumentation (deployed Beta 0.0.15): verified the #79 monitor fix IS in the deployed PBO, and re-reading the deployed handleInv shows the synced-monitor >=130 path always fell through even pre-fix — so the remaining failure is something else (true weight-full? nil ore roll? arrested flag?). `fn_m1ne`'s refusal branch now reports the exact limiter to the server log (carry/max weight, item weight, total item count, monitor slack, arrested flag, rolled item). NEXT: player053 re-test after reboot, read the -MINE- log line. NEED: what does it say now — same "no more room" message, or does the action not appear at all?
>
> CODE RE-REVIEW (2026-06-12, narrowed without the log): RULED OUT 3 hypotheses — (1) "action doesn't appear": the mine action IS wired (`fn_ga1ther.sqf:6` zone list incl. mine_1/mine_6; `:85` routes any "mine" zone → `AP_fnc_m1ne`); (2) "nil ore roll": the roll switch has a `default {"rock"}` (fn_m1ne:86) so `_random` is never nil; (3) "_yield undefined": only mine zones reach m1ne and mine_1-6 all match a case. → So the refusal is genuinely `AP_fnc_handleInv`=false = weight-full OR the item-monitor (`AP_invMonitor`/`AP_invRVar`) anti-cheat. Instrumentation already logs both. Just need ONE `-MINE- handleInv REFUSED` line from a high-yield mine to read which.
>
> CLOSED 2026-06-12: owner marked FIXED — high-yield mining confirmed working in-game. Code re-review found no structural bug (action wired, roll/`_yield` sound); the earlier #79 monitor fix + instrumentation reboot resolved the refusal in practice.

---

### #92 · FIXED · 2026-06-10T20:49Z
- **By:** player036  ·  **Channel:** #Altis shipping robbery bugged  ·  **ref:** 100000000000000042/100000000000000042

Altis shipping robbery bugged — the truck for the convoy spawns under the bridge in the water

> staged (deployed Beta 0.0.15): the spawn picked the NEAREST road segment to the AP_convoy_start marker — that segment is a BRIDGE piece, so the truck spawned on/under it and dropped into the canal. fn_convoyRobbery now filters bridge segments (getRoadInfo) + water surfaces from the road candidates, falls back to the marker itself, grounds the Z and uprights the truck.

---

### #93 · FIXED · 2026-06-10T20:54Z
- **By:** player036  ·  **Channel:** #weird ass bug  ·  **ref:** 100000000000000043/100000000000000043

weird ass bug — Altis shipping robbery spawns random npc that runs and gets into the back of the truck

> staged (deployed Beta 0.0.15): the "random npc" is the convoy's AI DRIVER — when his moveInDriver seat-grab failed (truck flooded under the bridge, #92), he chased his MOVE waypoint on foot and boarded the CARGO bay instead. Fixed the root (#92 spawn) + added a seat verify: 3s after spawn, if he isn't in the driver seat, one forced re-seat; still failing -> the AI is deleted (truck just waits at spawn).

---

### #94 · FIXED · 2026-06-10T20:56Z
- **By:** player036  ·  **Channel:** #Altis shipping robbery  ·  **ref:** 100000000000000044/100000000000000044

Altis shipping robbery — no npc or map showing where to deliver the robbery truck to

> staged (deployed Beta 0.0.15): the 7 fence NPCs ("Deliever Stolen Shipment", cuts 25%-100%) exist in mapData but NOTHING marked them. npcs/fn_civConvoy now drops a local orange map marker per fence — "Shipment Fence (75% cut)" etc — for CIVILIANS only (cops don't get the fence network revealed).

---

### #95 · FIXED · 2026-06-10T20:58Z
- **By:** player036  ·  **Channel:** #Altis bank robbery  ·  **ref:** 100000000000000045/100000000000000045

Altis bank robbery — no visual drill on the door and no progress bar

> staged (deployed Beta 0.0.15): (1) NO DRILL — the drill prop spawned at a 2017-era hardcoded position ~32m from THIS mission's bank door; now anchored on the AP_bank_door marker (building fallback) facing the building. (2) NO PROGRESS — the 10-min server drill loop gave zero feedback; now broadcasts at 25/50/75% ("The bank vault drill is 25% complete!") plus the existing open/relock announcements at start/finish.

---


### #96 · FIXED · 2026-06-10T21:30Z
- **By:** owner  ·  **Channel:** in-session ("people can't download mission file")

Players stuck in a connect/disconnect loop — mission file won't download.

> RESOLVED-VERIFIED: first player loaded into game after the mission rename. Final root chain: throttled transfer (2013-era basic.cfg) -> clients aborted mid-download -> Arma cached the PARTIAL pbo as valid -> every rejoin loaded the broken cache ('uses modified data file' + 'grumpycat.jpg not found' at role screen) instead of re-downloading. FIXES: basic.cfg maxed (MaxMsgSend 1024 / 1300B / 100Mbit floor) + mission template renamed LooneyBin.Altis -> Loonybin_b0012.Altis (server.cfg + run-boot2.sh) so all clients get a virgin MPMissionsCache slot; rename now doubles as the cache-bust per version bump. No mission content trimmed (owner: keep all images).
> deployed (outage fix, server was empty): server + mission were healthy (mission parsed, zero script errors) — players connected, hung in the ~30MB mission TRANSFER, bailed after ~30s, retried. Root: `deploy/basic.cfg` still carried 2013-era throttle values (`MaxMsgSend 128 / MaxSizeGuaranteed 512 / MinBandwidth 1.25Mbit`) — any mission repack invalidates the client cache and the full re-download crawled at those rates. FIX: modern tuning (MaxMsgSend 512, MaxSizeGuaranteed 1024, MaxSizeNonguaranteed 1300, MinBandwidth 10Mbit). Rebooted immediately to apply (justified: nobody could join = outage; pack_pbo is deterministic + mission source untouched, so the repacked PBO is byte-identical and completed downloads stay cached). The `a3_characters_f` "deleted DLC" warning in the log is a benign server-side mission.sqm note, present every boot, unrelated. LONG-TERM: mission PBO is 35MB raw (15MB images/ incl. 1.8MB wallpapers + 1.6MB craterewards + 576KB asyplus leftovers, 6.3MB sounds) — trimming dead art would cut download time further; deferred, riskier than a cfg change.

---

### #97 · FIXED · 2026-06-10T21:55Z
- **By:** owner  ·  **Channel:** in-session

Shipment fence markers show even when no convoy event is running.

> staged (deployed Beta 0.0.15): the #94 rev-1 markers were drawn permanently at NPC init. Rev 2: fences register their positions into `AP_convoyFences`; a single per-client watcher draws the orange "Shipment Fence (X% cut)" markers when `SRV_convoy_status` flips ACTIVE and deletes them when the event ends/resets. Still civilians-only.

---
### #98 · FIXED · 2026-06-10T22:10Z
- **By:** player036  ·  **Channel:** #jewelry emporium  ·  **ref:** 100000000000000046/100000000000000046

jewelry emporium — bugged cant drill the front door even though the option for it is there

> staged (deployed Beta 0.0.15): server boot initialized `SRV_jewelryEmporiumSRV` as `[false, false]` (2 elements) but the client "Start Drilling Door" gate reads `select 6` (cops-required) — out-of-range threw and the drill died silently right after the action fired. Boot init now uses the full 7-slot shape from fn_jewelryEmporiumSRV's contract: `[lastBreach=-1800, active=false, safeDrilled=false, safeWelded=false, casesLootable=false, 0, copsRequired=4]` — also fixes the `param[0]` recent-breach check that compared a BOOLEAN against serverTime. TEST: front-door drill action at the emporium → 10s placement → "robberyStarted" broadcast, safe phase opens.

---


### #99 · FEATURE · 2026-06-10T22:30Z
- **By:** owner  ·  **Channel:** in-session ("playable furniture for houses — placable")

Placeable house furniture, persisted per house.

> staged (deployed Beta 0.0.15). NINE base-Arma pieces (wooden/plastic/camping×2 chairs, sun lounger, camping/small/large tables, sleeping bag) sold at the %WORLD% Market ($250–650), placed through the existing placeable pipeline (Y-menu use → walk-and-place). Chairs are sittable via the existing Sit Down action (classname match) — zero extra code. RULES: civilians only, must be within 20m of a house YOU OWN (exempt from the placeables' cartel-300m rule), 15 pieces per house (server-enforced: over-cap deletes + refunds), pickup by placer (UID survives restarts). PERF: every piece spawns with simulation + damage OFF — no physics cost; restart respawn batch is static objects only. PERSISTENCE: new `houses.furniture` column (mresArray-encoded [class,pos,dir,placerUID][]) maintained by new `APS_fnc_houseFurnitureSRV` (add w/ cap, remove by position, loadAll at boot +28s); column ALTERed live. Wired: virtItemCfg (9 items), configuration.sqf (AP_placeable append + AP_furnitureItems), virt_shops market, fn_useItem case, hold/place gates, fn_pickupObject remove hook, config.cpp + CfgRE registration, init.sqf boot loader. Cleanup sweeps verified to ignore furniture.

---

### #100 · FIXED · 2026-06-10T23:55Z
- **By:** owner  ·  **Channel:** in-session

Virtual Arsenal from admin menu locks the game when opened.

> staged (deployed Beta 0.0.15): no client RPT to read (client runs -noLogs); server log clean — this is the stock BIS arsenal first-open behavior: `['Open'] BIS_fnc_arsenal` builds its complete item cache from every config in the game on first use = 30-90s of apparent hard freeze before the UI appears. FIX: initPlayerLocal now runs `["Preload"] call BIS_fnc_arsenal` in the background ~10s after session load on admin (lvl 3+) clients only, so the button opens instantly. If the freeze turns out to be PERMANENT (not just first-open), next suspect is the CfgDisabledCommands list (ALLVARIABLES / REMOVEALLITEMS / REMOVEALLEVENTHANDLERS are still fully blocked and the arsenal touches some of them on apply/close) — report back after the preload deploys. UPDATE (owner: locked 5+ min, never closed): NOT the cache — permanent lock = arsenal init dying on a disabled engine command. Unblocked for clients in CfgDisabledCommands: ALLVARIABLES (all 7 syntaxes), REMOVEALLITEMS, REMOVEALLEVENTHANDLERS, ONPRELOADSTARTED, ONPRELOADFINISHED. Anti-cheat note: acceptable loosening for closed beta (BE off); revisit at public launch (launch.md item 3). UPDATE 2 (still locked on 0.0.13): REAL ROOT FOUND — BIS arsenal spawns its character-preview MANNEQUIN client-side via createUnit/createAgent; those were server-only (1,0,0 — client blocked) since the convoy AI fix, so the arsenal died building the preview = the permanent lock. CREATEUNIT (both syntaxes) + CREATEAGENT + CREATEVEHICLECREW now client-enabled (1,1,0). AC note: client createUnit is a classic hack vector — closed-beta acceptable, MUST revisit pre-public (launch.md).

---

### #101 · FEATURE · 2026-06-11T00:40Z
- **By:** owner  ·  **Channel:** in-session

Remove armor-stacking + backpack combo protection; add Level IV/V armor to rebel + cop clothing shops.

> staged (deployed Beta 0.0.16). (1) COMBOS UNRESTRICTED: the initPlayerLocal enforcement loop (stripped PlateCarrier/KBT rigs off CSAT/Gorka/tracksuit uniforms, Carryall off CSAT pilot coveralls every 10s) is disabled; the pilot-coveralls and heli-helmet pickup blocks in onTakeItem removed — any clothing combination is wearable. Kept: governor uniform gate (role item) and the medic GL-vest rank gate now scoped to MEDICS only (it previously stripped that vest off any side — would have fought the new cop Level V item). (2) NEW ARMOR — Rebel clothing shop: GA Carrier Rig family + Mk.II (Level IV, $12k) and GA Special Rig family + Heavy GL Rig (Level V, $25k). Cop clothing shop: Level IV at Lieutenant+ ($2k), Level V (Special Rig + GL Rig black) at Captain+ ($4k).

---

### #102 · FEATURE · 2026-06-11T00:55Z
- **By:** owner  ·  **Channel:** in-session

Shop catalog tuning: pull top-tier guns; SPAR-16 to civ gun store.

> staged (deployed Beta 0.0.16). REMOVED from the rebel + MaxSec dynamic catalogs (class-prefix blacklist in the fn_weaponShopCfg builder): Cyrus (DMR_05), GM6 Lynx, M320 LRR, Navid (MMG_01) — event/crate loot only now; their ammo lines vanish with them (side panel only lists mags for displayed guns). ADDED: "SPAR-16 Black (ILLEGAL)" — arifle_SPAR_01_blk_F at Billy Joe's Firearms (civ gun store, firearms license) for $7,500, illegal tag in the name like the SDAR/shotgun precedent.

---

### #103 · FEATURE · 2026-06-11T01:25Z
- **By:** owner  ·  **Channel:** in-session

Admin Kick/Ban buttons; de-Asylum the UI links (welcome navbar, Useful Links, escape menu); new Discord URL.

> staged (deployed Beta 0.0.16). ADMIN MENU: "My Loonybin" text widget (idc 12923) is now a **Kick Player** button (Admin lvl 3+, confirm dialog), placeholder 12924 is **Ban Player** (Senior Admin lvl 4+, PERMANENT row in `bans`, enforced at connect by fn_insertRequest). Both act on the selected player in the admin list; new client fns (fn_adminKick/fn_adminBan) + server `APS_fnc_adminKickBan` which RE-VERIFIES the caller's admin level from the DB, then clean client kick + 8s engine fallback (#kick → deleteVehicle) so wedged clients still drop. Registered in Functions.h/config.cpp/CfgRE. WELCOME SCREEN: navbar FORUMS / My Loonybin / CHANGELOG / LOONYBIN PLUS / DONATE / LOONYBIN WIKI buttons removed; Useful Links now Discord-only at https://discord.gg/8rArh7gvVM; Support/Reports text points at the same. ESCAPE MENU: My Loonybin / Gameplay Wiki / TeamSpeak / Forums buttons removed — Discord only, new URL (customEscMenu.hpp).

---

### #105 · FEATURE · 2026-06-11T02:30Z
- **By:** owner  ·  **Channel:** in-session

Owner-only "Economy" menu — adjust the price of ANY item for sale, live + persistent.

> staged (deployed Beta 0.0.16). Full live price-override system across all 4 price families, owner-only (admin level 5; beta auto-admin is 4 so testers can't). MECHANISM: new `price_overrides` DB table (family,item_key,p0,p1,p2) → loaded at boot into server global `AP_priceOv` → publicVariable'd to clients. Every price reader checks the override first, falls back to the hardcoded config. Set a price → `APS_fnc_economySRV` (re-verifies owner from DB) upserts the row + updates AP_priceOv + re-publicVariables → **shops reflect it on next open, no restart; survives reboot** (boot reloads from DB). HOOKS (one per family, covers display AND charge): virt → fn_virtItemCfg get/Base/Lowest/MaxPrice; weap+ammo → fn_weaponShopCfg + fn_weaponAddons final lists; veh → fn_vehicleConfig getVehicleRowParsed (idx7 buy/idx8 sell — every shop/garage/factory path funnels here); cloth → fn_clothingFilter _items. UI: admin-menu "Economy" button (idc 12925, owner-gated) → dialog (IDD 920000, dialog/economy.hpp, ctrl AP_fnc_economyMenu): family tabs (Virtual/Weapons/Vehicles/Clothing) + search + 400-cap list + Buy/Sell/Max editors (blank=keep default) + Save/Reset. UI REV (owner): list shows ENGLISH names only (classnames hidden), searchable by name. Full config enumeration so nothing is gated out: virt (getEconList w/ prices), guns + ammo + attachments (CfgWeapons+CfgMagazines scope2 deduped by name), vehicles (getEconList w/ prices), ALL clothing/armor wearables (CfgWeapons uniforms/vests/headgear/glasses + CfgVehicles backpacks). Pick from the list -> price editors fill; the selected English name shows in a read-only box. Registered: config.cpp, CfgRE, Functions.h (priceOv+economyMenu), MasterHandler. Slot meaning per family documented in AP_fnc_priceOv. TEST after reboot: admin menu → Economy → pick e.g. cocaine, set Sell, Save → sell at a drug dealer shows new price immediately; reboot → still applied.

---

### #106 · FEATURE · 2026-06-11T03:10Z
- **By:** owner  ·  **Channel:** in-session

Ifrit HMG → rebel vehicle shop; Hunter HMG → MaxSec vehicle shop.

> staged (deployed Beta 0.0.16): fn_vehicleConfig. Ifrit MACHINE GUN (O_MRAP_02_hmg_F, not the GMG) added to rebel shop (reb_car + nd_car), $350k, rebel armored license (talent 19). Hunter MACHINE GUN (B_MRAP_01_hmg_F) added to MaxSec shop (cop_car + maxtac_car), $200k, Lieutenant+ (cop level 5). Both buyable/sellable like the base variants; Economy menu can reprice them.

---

### #107 · FEATURE · 2026-06-11T03:15Z
- **By:** owner  ·  **Channel:** in-session

Remove the MyLoonybin/donation/loot-key popups; de-monetize all similar messaging.

> staged (deployed Beta 0.0.16). REMOVED/auto-firing nags: (1) passive-mode "MyLoonybin Rewards — earn $75k + 250 gold by linking discord" popup (was dead code, deleted); (2) new-player tutorial "Loonybin Server Info" links popup → trimmed to Discord only; (3) tutorial "MyLoonybin Stats — sign up on the website" popup → plain "!stats" tip; (4) briefing diary records Teamspeak / **Loot Crates ("Purchase Loot Crate Keys from our website")** / **Donations ("Donate securely with PayPal, unlock skins")** / old Website → replaced with a single Discord record; (5) on-spawn credits roll "Donators" + "Teamspeak" entries removed (Welcome / Most Wealthy / Roleplaying remain). NEW discord URL https://discord.gg/8rArh7gvVM used throughout (matches #103). STILL PRESENT (functional paywall/feature, NOT auto popups — listed for your call): loadout system "Loonybin Plus Required / Subscriber → store.gaming-loonybin.com/plus" (fn_loadoutMenu lnb "LOCKED" rows + fn_loadoutSelection message on clicking a locked slot); "Spray Can (Subscriber Only)" hotkey note in the controls diary; !stats / fn_getMyStats (user-typed, fetches MyLoonybin stats). Say if you want the loadout Plus paywall opened up or the Subscriber tags stripped too.

---

### #108 · FIXED · 2026-06-11T03:40Z
- **By:** owner  ·  **Channel:** in-session

Gang Fortress: 2 rebel outposts never spawn / never marked on map; event + ownership don't persist across reboot.

> staged (deployed Beta 0.0.17). OUTPOSTS: the 2020 client (fn_initGangFortClient) spawns rebel-outpost shop NPCs from `SRV_tempGangRebel` and draws only a local capture-zone marker — but APS_fnc_gangFortressSRV never created the NPCs/markers, so nothing appeared. Now on start the server builds 2 outposts (weapon NPC + vehicle NPC + 3 vehicle spawn points each, ~230m either side of the fortress via findSafePos), sets `SRV_tempGangRebel` + publicVariables it (clients addAction the rebel weapon/vehicle shops onto the NPCs AND it enables the safezone via fn_onFired), and drops GLOBAL map markers: 2 green "Rebel Outpost (Safezone)" icons + a red "Gang Fortress" ellipse. Torn down (NPCs + markers deleted) on event end. PERSISTENCE: new `gangfort` DB table (active, ends-unix, winner_id, winner_name, leaderboard). Start writes active=1 + wall-clock end + clears winner; the scoring loop saves the leaderboard every ~60s; finish writes the winner. New "load" mode (init.sqf, +18s after boot) restores: if an event was still running and not expired → RESUMES it for the remaining real time (re-spawns outposts/markers, restores the leaderboard, re-broadcasts to clients); else if a gang had won → re-applies their fortress ownership so they keep the fortress shops/discount until the next event. Admin-menu start/stop unchanged.

---

### #109 · FIXED · 2026-06-11T03:45Z
- **By:** owner  ·  **Channel:** in-session

Gang turfs: active turf + capture window reset on reboot (should persist until the window ends).

> staged (deployed Beta 0.0.17). The turf rotation (rodo/zaros/panagia, one active for 900s) only published `AP_active_turf` in memory, so a reboot mid-window restarted the rotation fresh. Now: new `turf_state` DB row (active_idx, ends-unix); when a turf goes active the server stamps it + a wall-clock end, and clears it when the window closes. At boot the rotation loop checks the row first — if a turf was active and the window hasn't expired, it RESUMES that exact turf for the remaining real time (one-shot) before continuing the normal random rotation. Turf OWNERSHIP already persisted via AP_turf_list/DB (unchanged).

---

### #110 · FEATURE · 2026-06-11T03:55Z
- **By:** owner  ·  **Channel:** in-session

Add Level 4 + 5 helmets to the rebel shop.

> staged (deployed Beta 0.0.17): rebel clothing shop headgear (fn_clothing_reb case 1). Level IV = NATO Spec helmets (H_HelmetSpecB_blk / H_HelmetSpecB / H_HelmetSpecB_snakeskin) $8,000; Level V = CSAT Viper SP helmets (H_HelmetO_ViperSP_hex_F / _ghex_F) $15,000 — the heaviest-armor vanilla infantry helmets. Repriceable via the Economy menu.

---

### #111 · FIXED · 2026-06-11T04:10Z
- **By:** owner  ·  **Channel:** in-session

Bullet cam: the followed bullet despawns after a certain distance.

> staged (deployed Beta 0.0.17). NOT a hard Arma limit — the engine culls projectiles once they pass the FIRER's object view distance, so the bullet goes null mid-flight and the cam's `while {!isNull _proj}` loop ends. fn_adminBulletCam never raised view distance. Fix: on cam start save + bump terrain AND object view distance to 12000 (object VD is clamped to terrain VD, so both raised), restore the player's original values when the cam ends/aborts/impacts. Bullet now survives to its full ballistic range. (The mission's normal VD system only sets terrain VD and never object VD — same root as the general "bullets despawn at range" note; this fixes it for the bullet cam specifically.)

---

### #112 · FEATURE · 2026-06-11T04:40Z
- **By:** owner  ·  **Channel:** in-session

4th faction teaser: 26 OPFOR "Coming Soon" whitelisted slots.

> staged (deployed Beta 0.0.19): added a 26-slot EAST playable group to mission.sqm (cloned the cop group Item351, side West→East, type→O_Soldier_F, names opfor_1..26, all `description="Coming Soon"`, fresh ids 33626-33652, top Entities items 1110→1111). Whitelisted/locked: core/init.sqf gets a `case east` — shows "The 4th Faction is COMING SOON" then bounces to lobby (nobody is on the whitelist yet). New `opfor_whitelist` DB table mirrors the cop coplevel/copretired structure (playerid, name, opforlevel, opforretired) — EMPTY, no ranks set. When the faction ships, the east case calls its real init + this table's whitelist check. Patch note for this version overridden to "teaser tee hee" (deploy/patchnote_override.txt + new gen_patchnotes override path).

---

### #113 · FIXED · 2026-06-11T05:05Z
- **By:** owner  ·  **Channel:** in-session

Escape menu: "PROJECT LOONYBIN" header + Discord button float way above the menu (big gap).

> staged (deployed Beta 0.0.20): trimming the escape menu to Discord-only (#103) left the header (grid Y 7.5) and Discord button (8.6) at the TOP of the old 6-row cluster, with a 4-row gap down to the actual menu buttons. Moved both to the bottom of that range (fn_onGameInterrupt: header 7.5→11.9, Discord 8.6→13 — Discord was the lowest/closest-to-menu link originally) so they sit flush above the Abort/Suicide/Resume buttons.

---

### #114 · FIXED · 2026-06-11T13:20Z
- **By:** owner  ·  **Channel:** in-session

Remove all gaming-loonybin.com references (not a real website).

> staged (deployed Beta 0.0.21): swept every gaming-loonybin.com / my. / store. / wiki. / ts3. URL + the separate gaming-loonybinwiki.com domain across the mission (ja1l, customEscMenu.hpp, description.ext debrief, version.hpp onLoadMission, onGameInterrupt footer, tutorialNewPlayer, loadoutSelection Plus link, mission.sqm, policeRecruit, adminInfo, welcomeUIConfig, serverInfoMessages). All real URLs → the Discord invite (discord.gg/8rArh7gvVM); plain-text mentions → "our Discord"; the ESC version footer → "Loonybin Life | <ver>". Left only `author="Gaming-Loonybin"` in description.ext (mission metadata / community name, not a .com). Final grep: zero loonybin .com/.net/wiki URLs remain.

---

### #115 · FEATURE · 2026-06-11T13:45Z
- **By:** owner  ·  **Channel:** in-session

Remove the standard talent system (civ/medic/police) — merge all those perks into the game as baseline.

> staged (deployed Beta 0.0.21). The standard talent tree (`AP_side_talents`; civ 55 / cop 36 / medic 18 perks) no longer needs unlocking — every standard perk is now always-on. ONE hook: `fn_requestReceived` forces `AP_side_talents = ["getFactionTalentsIDs"] call AP_fnc_talentCfg` (the full per-side ID list) right after the DB load, so every `X in AP_side_talents` check across the codebase passes — no need to touch the hundreds of call sites. The "Talents" phone button (standard talent menu) is removed; the menu/respec/point-earning still exist but are unreachable + moot. UNTOUCHED (separate systems): cop PRESTIGE (`AP_cop_talents`), TT prestige (`AP_medic_talents`), infamy (`AP_infamy_talents`), honor (`AP_honor_talents`), gang talents (`AP_gang_talents`) + their phone buttons. NOTE: this also baseline-unlocks the bounty-hunter standard line (Vigilante/Master Bounty Hunter) since those are civ standard talents — everyone can now bounty hunt / access honor + skiptracer. launch.md updated so this isn't mistaken for a beta god-stat to revert.

---

### #116 · FEATURE · 2026-06-11T14:05Z
- **By:** owner  ·  **Channel:** in-session

Level V helmets: drop Viper, add the (non-Viper) crew helmets; show armor value next to every vest/clothing item.

> staged (deployed Beta 0.0.21). (1) HELMETS (fn_clothing_reb): removed the 2 Viper SP entries; Level V is now the crew helmets — same top armor tier, non-CSAT look: H_HelmetCrew_B / _O / _O_ghex_F / _I ($15k each). Level IV (Spec helmets) unchanged. (2) ARMOR VALUES: fn_clothingFilter now appends "[Armor N]" to every clothing item name in ALL clothing shops — reads the highest `armor` across the item's HitpointsProtectionInfo hitpoints (vest=chest/body, helmet=head). Only items with armor>0 get the tag (glasses/backpacks/faces stay clean). Used a `for` loop (not forEach) so the outer loop's `_x` isn't clobbered before the row's lbSetData. So the exact armor shows next to each helmet/vest — the Level IV/V labels are now backed by the real numbers in-shop.

---

### #117 · FIXED · 2026-06-11T14:25Z
- **By:** owner  ·  **Channel:** in-session

Backpack disappears on revive.

> staged (deployed Beta 0.0.21): fn_loadDeadGear restored the backpack CONTAINER by routing it through AP_fnc_handleItem, whose switch only adds a backpack when fetchCfgDetails reports it as "CfgVehicles" — when that detection missed, it silently no-op'd and the backpack (and its contents) vanished on revive, while uniform/vest/weapons (CfgWeapons path) restored fine. Now the backpack is added directly: removeBackpack + addBackpack + clearAllItemsFromBackpack, then the existing _bitems loop refills it. Capture side (fn_fetchDeadGear) already grabbed the backpack + _bitems correctly. Same fn feeds cop re-gear (fn_reGear), so that's covered too. Pairs with the #74 suppressor/attachment revive fixes.

---

### #118 · FEATURE · 2026-06-11T14:40Z
- **By:** owner  ·  **Channel:** in-session

Add bipods to every supported weapon in the rebel shop — free, 0 resale.

> staged (deployed Beta 0.0.21): added all 8 vanilla bipods (bipod_01/02/03 families) to the rebel weapon shop's addon list (fn_weaponAddons "rebelwep") at $0. The shop side panel (fn_weaponShopSelection) already filters addons by the selected weapon's compatibleItems, so "every supported weapon" is automatic — each gun only shows the bipods it can mount. The rebel weapon shop has no sell-back path, so there's no resale (can't free-buy-then-sell). Police bipod (copLevel 6, $2500) untouched.

---

### #119 · FIXED · 2026-06-11T14:55Z
- **By:** owner  ·  **Channel:** in-session

Y-inventory (suitcases) still despawn too quickly, randomly.

> staged (deployed Beta 0.0.21): fn_cleanup runs 3 sweeps in order — `vehicles` (loop 1) → `Thing` (loop 2, the suitcase/money 30-min TTL) → `GroundWeaponHolder` (loop 3, #52). Loop 1 INSTANT-deletes any object with idleTime==0 and no owner/revive/trunk/rope. A freshly dropped suitcase / Y-inv holder that didn't get an `owner` var was killed by loop 1 BEFORE loop 2 could stamp its TTL — and "random" because it depended on whether that particular drop happened to set an owner (bank gold did, plain Y-drops didn't). FIX: loop 1 now skips anything carrying a loot `item` var OR `ga_droppedItems` (the markers loops 2/3 manage), so drops reliably get their full 30-min TTL instead of a coin-flip instant reap.

---

### #120 · FEATURE · 2026-06-11T15:10Z
- **By:** owner  ·  **Channel:** in-session

Side chat persist / message history on screen.

> staged (deployed Beta 0.0.21): vanilla chat fades after a few seconds. New persistent HUD (dialog/chat_hud.hpp, RscTitles idd 246000, bottom-left, no fade) keeps the last 12 messages on screen. Fed by the existing HandleChatMessage EH (fn_handleChatMessage): displayed social-channel messages (0 global / 1 side / 5 direct) are pushed into AP_chatLog (ring buffer of 12), color-coded by channel (side=green, global=blue, direct=grey), and rendered into the HUD's structured text. Skips messages the bad-word/spam filter hides. HUD shows lazily on the first message via `131 cutRsc`. Included in description.ext RscTitles.

> NOTE !pos (the coord tool) — added this session, flagged in launch.md item 5 for removal before public (any player can read exact coords).

---

### #121 · FIXED · 2026-06-11T15:40Z
- **By:** owner  ·  **Channel:** in-session

Stun/taser hits sometimes failed to down a target (couldn't be knocked out), and some kill/down messages showed up twice. Both fixed.

> staged (deployed Beta 0.0.21). ONE root: the HandleDamage EH fires once PER hitbox per bullet, and fn_handleDamage spawned `AP_fnc_handleDowned` on EVERY such event (stun-down L73, VDM L91). A single stun shot therefore launched several handleDowned threads at once; they all passed handleDowned's guard before `AP_isDowned` is set (deep at L134, AFTER the broadcasts/logs) → duplicate "-DOWNED-" logs + doubled "was downed by" broadcasts (the double messages), and the parallel down-loops raced `AP_isDowned` into a STUCK-TRUE state on the victim's client, after which that player's guard early-exited forever = "can't be downed at all" (hit Torch, then Nikki). FIX (4 edits, 2 files): (1+2) both call sites now de-dupe at the synchronous EH level — at most one handleDowned per second per victim via a `AP_downReqT` time-stamp on `_unit` (1s << the 5-60s down, so a legit re-down is never blocked); (3) handleDowned's stale-flag clear (top of file) now ALSO self-heals a flag stuck true for >65s even if the downed UI (display 7300) is wedged open, recovering a stuck client without a relog; (4) handleDowned stamps `AP_downStamp = time` at down-start so (3) can tell a real ongoing down from a wedged flag. STOPGAP (no reboot): an affected player can RELOG now — configuration.sqf re-inits `AP_isDowned=false` on session load, so they're downable again immediately (until the un-fixed race re-sticks it; the staged fix stops it recurring). Shank path (fn_useShank, single deliberate trigger, 3-min cooldown) untouched. If kill messages still double AFTER this deploys, that's a separate fn_onPlayerKilled / Killed-EH issue to chase next.

---

### #122 · FIXED · 2026-06-11T16:30Z
- **By:** owner  ·  **Channel:** in-session

After 0.0.21, Torch AND Nikki still couldn't be downed (P07 or MXM-rubber); Despair + owner downed fine.

> staged (deployed Beta 0.0.22). The 0.0.21 fix (#121) addressed the per-bullet RACE on `AP_isDowned` — but the REAL blocker was different: display **7300 is the DeathScreen** (`createDialog "DeathScreen"` in fn_onPlayerKilled), and handleDowned's guard early-exits if 7300 is open. ROOT: `fn_revived.sqf` only force-closes 7300 on the `_admin` revive branch (L37-39); a normal **medic / revive-drone** revive (`_admin=false`) takes the `else` and never closes it, relying solely on the `closeDialog 0` further down — which misses if another dialog is focused OR if the fn early-exits at its `if !AP_isDead` guard. So a medic/drone-revived player walks around ALIVE with the death screen still open → handleDowned's `isNull(findDisplay 7300)` is false → every down silently early-exits = "can't be downed at all." Victim-side + persists because nothing re-closes it; Torch+Nikki were medic/drone-revived, Despair+owner weren't. Explains why a relog "fixed" it (fresh session = no 7300) and why the #121 race-fix didn't help (wrong layer). FIX: (1) fn_revived force-closes 7300 on EVERY path (before closeDialog 0) so the stuck state can't form; (2) handleDowned self-heals an already-stuck client — if the victim is ALIVE with 7300 open (a real death screen only shows while you're a corpse/!alive), close 7300 before the guard so the down fires (no relog needed). Added a TEMP `-DOWNBLOCK-` server log: if a down is STILL blocked after the self-heals, it prints isDowned/alive/disp7300open/arrested/src to console.log so the exact blocker is visible (REMOVE after confirming).

---

### #123 · FEATURE · 2026-06-11T17:10Z
- **By:** owner  ·  **Channel:** in-session

Remove passive mode / new-player invulnerability entirely.

> staged (deployed Beta 0.0.23). Passive mode (new players "not vulnerable to other civilians for 2 hours") was already nuked in fn_passiveMode (forces `AP_passiveMode`/`AP_passiveModeJIP` false + early-exits), but the entry points + dead immunity remained. Stripped the 4 things that actually did/started anything: (1) the damage-immunity exit in fn_handleDamage (`if (AP_passiveMode && call AP_newplayer ...) exitWith {0}`), (2) the auto-`["start"]` call in fn_requestReceived, (3) the new-player auto-enable + "you are invulnerable" message in fn_initCiv, (4) the "Passive" phone (Y) button in configuration.sqf. fn_passiveMode stays as the hard-false stub (master switch keeping the ~11 leftover `AP_passiveModeJIP` action-gates in onTakeItem/joinGroup/createGang/weaponShop/etc. permanently inert — harmless dead code, sweep later). NOTE: NOT the "can't be downed" fix — passive was already off, so never the down-blocker.

> NOTE down-bug still OPEN: -GATEDIAG- added to fn_handleDamage this build logs the victim-side gate decision (wep/mag/stunMag/hitbox/dmg/lethalBH/alive/arrested/GATEPASS) to console.log on every player-on-player hit. Shoot Torch once after deploy → read the log → root identified.

---

### #124 · FIXED · 2026-06-11T17:35Z
- **By:** owner  ·  **Channel:** in-session

ROOT FOUND: certain players (Torch, Nikki, Typhoon) could not be downed at all — by anyone, any weapon.

> staged (deployed Beta 0.0.24). The -GATEDIAG- instrument (0.0.23) NAILED it: hits on the affected players logged `arrested=<null>` while a normal player logged `arrested=0` (everything else — GATEPASS, stunMag, alive — was fine). ROOT: `fn_requestReceived` loads `AP_is_arrested = _this select 15` straight from the DB, and for never-arrested / migrated accounts that field decodes to an EMPTY/malformed array. The down gate in fn_handleDamage gated the handleDowned spawn on `(AP_is_arrested select 0) isEqualTo 0` — on a malformed array `select 0` returns **nil**, and `nil isEqualTo 0` is FALSE, so handleDowned was NEVER called → no down, ever (and no -DOWNBLOCK- either, because the block was upstream of handleDowned in the gate). Players who'd been arrested before (e.g. owner) had a well-formed `[0,0,0]` so they downed fine — exactly the observed split. This is the TRUE root; #121 (per-bullet race) and #122 (stuck DeathScreen 7300) were real-but-unrelated layers that didn't fix it. FIX: (1) ROOT — `fn_requestReceived` now normalises `AP_is_arrested` to a valid `[state,time,?]` on load (defaults `[0,0,0]`; a real jail `[1,…]` with 3 elems is preserved), so EVERY consumer is safe; (2) DEFENSE — both down-spawn gates (stun + VDM) now use `(AP_is_arrested param [0,0])` instead of `select 0` (param returns 0 for a missing/nil element), mirroring the guard fn_initCiv already used. Removed the -GATEDIAG- (fn_handleDamage) and -DOWNBLOCK- (fn_handleDowned) temp logs now that the root is fixed. NOTE: many other `AP_is_arrested select 0` consumers across the mission (jail/survival/onGameInterrupt/etc.) were also fragile, but the load-normalise fix (1) protects them all at once.

---

### #125 · FIXED · 2026-06-11T18:30Z
- **By:** owner  ·  **Channel:** in-session

Admin-jailed players could bail out for a flat $1,500 instead of their bounty.

> staged (deployed Beta 0.0.25). jailMe reads the bail amount from the offender's wanted entry (index 3) and DEFAULTS to $1,500 when that entry is empty. The admin-jail flow (fn_adminJail) fires the wantedAdd (charge 57 "Admin Jailed", bounty 999,999) AND APS_fnc_handleJail in PARALLEL, so handleJail's `wantedPerson` lookup often ran before the charge landed → empty entry → the $1,500 default. FIX: handleJail now runs in a scheduled thread and, if the lookup is empty / bounty 0, waits 1s and re-fetches — so the bail = the offender's ACTUAL bounty (admin jail → $999,999). Cop-arrest path unaffected (already had the bounty).

> _(admin-tagged — excluded from public patch notes.)_

---

### #126 · FEATURE · 2026-06-11T18:30Z
- **By:** owner  ·  **Channel:** in-session

Relocate the Drug Cartel.

> staged (deployed Beta 0.0.25): moved the Drug Cartel to grid 8906 / 7489 (was far NW at 4855/21869). Updated both the `drug_cartel` map marker and the `drug_flag` capture-flag object in mission.sqm. Added a ground-snap (`setPosATL [x,y,0]`) to the cartel flags' init so the flag sits flush on the terrain at the new spot regardless of the saved elevation.

---

### #127 · FEATURE · 2026-06-11T18:30Z
- **By:** owner  ·  **Channel:** in-session

Prison break had no on-screen timer for its 10-minute window.

> staged (deployed Beta 0.0.25): added a top-center prison-break HUD (progress bar + countdown) shown to everyone while a break is active. It watches `SRV_prisonData` (already publicVariable'd by APS_fnc_handlePrisonBreak — start time + active flag), counts the 10 minutes until prisoners can escape, and flashes "ESCAPE NOW AVAILABLE" at the end. Syncs for JIP and clears if a cop ends the break. New RscTitles `AP_prison_hud` (chat_hud.hpp) + a watcher in initPlayerLocal — no server change.

---

### #128 · FIXED · 2026-06-11T18:30Z
- **By:** owner  ·  **Channel:** in-session

Kills/downs showed a duplicate "(friendly fire)" line in chat.

> staged (deployed Beta 0.0.25): the second line was Arma's ENGINE team-kill notification (printed on any same-side kill — everyone's `civilian`), doubling up the mission's own "X was killed/downed by Y" broadcast. It's not in any script — the engine generates it via the rating-penalty path. FIX: added `player addEventHandler ["HandleRating", {0}]` in initPlayerLocal so the friendly-kill rating penalty is nulled and the engine doesn't emit the shame line. Altis Life never uses Arma's rating, so this is harmless. (Verify in-game after deploy; if the line persists it's a deeper engine/difficulty setting.)

---

### #129 · FIXED · 2026-06-11T18:30Z
- **By:** owner  ·  **Channel:** in-session

RPT error spam: `(AP_is_arrested select 0)` still erroring in non-down consumers after #124.

> staged (deployed Beta 0.0.25). #124 fixed the down gate + load-normalise, but ~27 other consumers (ClUpdateRequest, survival, onGameInterrupt, jail, login bonus, event clients, m1ne, setupActions, etc.) still used the fragile `(AP_is_arrested select 0)` — which throws when the array is momentarily empty/malformed (a live monitor caught it). Swept ALL of them to `(AP_is_arrested param [0,0])` (returns 0 for a missing/nil element — strictly safer, never throws). Belt-and-suspenders with the #124 load-normalise.

---

### #130 · FEATURE · 2026-06-11T18:55Z
- **By:** owner  ·  **Channel:** in-session

Every federal event should alert all online MaxSec with an admin-style popup (incl. prison break).

> staged (deployed Beta 0.0.25): the `federaleventcop` message style (big red "Federal Event — All MaxSec officers are being requested for assistance in quelling the %1") existed in fn_handleMessage but was wired to NOTHING, so no event alerted cops. Added ONE server-side edge-detector (server init.sqf) that watches all 7 federal-event active flags — Federal Reserve (AP_fed_robbed), Bank (AP_bank_robbed), Evidence Lockup (SRV_evidence_status), **Prison Break** (SRV_prisonData), Convoy (SRV_convoy_status), Loony Bin (SRV_loonyBinData), Jewelry Emporium (SRV_jewelryEmporiumSRV) — using the same predicates as fn_activeFederalEvent. On a false→true transition it fires the `federaleventcop` popup to every online MaxSec officer (side west) + logs `-FEDALERT-`. Seeds from current state after a 30s settle (no boot spam; only NEW events alert). Also added `federaleventcop`/`federaleventmedic` to the handleMessage sound list so the popup pings ("taskAssigned") = the audible alert. nil-safe var reads; one poll every 5s.

---

### #131 · FEATURE · 2026-06-11T19:20Z
- **By:** owner  ·  **Channel:** in-session

Max-verbosity logging pass (owner needs full log coverage for a debug task).

> staged (deployed Beta 0.0.25). Cranked every safe logging dial: (1) **server.cfg** `timeStampFormat = "full"` — every RPT/console line now carries a full date+time for precise correlation; `logFile = "looneybin_server.rpt"`. (2) **ScriptError handlers** — `addMissionEventHandler ["ScriptError", …]` on the SERVER (AP_server init → `[LB-SCRIPTERR][server]` with full callstack to console.log) AND on every CLIENT (initPlayerLocal → logs to that client's RPT AND mirrors to the server console.log + DB `log` table via APS_fnc_logIt as `-SCRIPTERR-`, throttled 2s/client). This means errors on REMOTE players' machines are now visible centrally (previously a client's errors only hit its own local RPT). (3) `AP_verboseLog = true` (publicVariable) — global gate any future verbose path can read. ALREADY MAXED (left as-is): the mission diag_logs every SQL query, extDB3 writes its own logs/ dir, and the `[LB-LOG]` audit sink covers money/kills/admin/gear/connect. DELIBERATELY OFF: `verifySignatures` + `BattlEye` (either would kick the unsigned @AP_server mod / trip the heavy remoteExec). OPTIONAL heavier knob NOT enabled: launch `-debugCallExtension` (logs raw extension/DB protocol calls — redundant with the SQL logging + can lag the server). REVERT after the debug session: `timeStampFormat` → "none", drop `AP_verboseLog` gating. NOTE: owner can add `-showScriptErrors` to their OWN Arma CLIENT launch to see errors on-screen live.

---

### #132 · TOOL · 2026-06-11T19:45Z
- **By:** owner  ·  **Channel:** in-session

CLANKR — dupe/exploit detector that pings admins with log snippets. _(loonybot-side tool; NOT a mission/PBO change — no reboot, no public patch note.)_

> LIVE (loonybot/clankr.py). Standalone Python poller (reuses loonybot's `admin.DB` + config.json + the `outbox/` bridge). Every 20s it reads new `log` rows (the in-game APS_fnc_logIt sink, now fed by the #131 max-verbosity pass) and runs heuristic rules; on a hit it drops `outbox/clankr_*.json` → loonybot posts to the admin channel (100000000000000047) and pings the 3 owner IDs on HIGH. Cursor persisted in `clankr_state.json` (started at id 4350). Rules v1 (tags from REAL data): HIGH = anti-cheat/exploit tags (`-GEAREXPLOIT-`,`-HACKINFO-`,`-SpyG-`,`-MEMHACK-`,tamper codes) + large `995` WIRE (`wire_crit` 900k) + money velocity; MED = big WIRE (`wire_big` 250k), large cash-on-death (`-MONEYWARNING-`), item-shuffle burst (dupe loop), script-error burst; LOW = `-MULTIPLESTEAMS-` (alts). All thresholds + tag sets live in `config.json` → `"clankr"`. Run: `loonybot/clankr-run.sh` (or `nohup venv/bin/python clankr.py &`). Stop: `pkill -f clankr.py`. ⚠️ BETA NOISE: god-stats (1B money) make the money rules trip on legit testing — tune `wire_*`/`velocity_*` up or pause CLANKR until the economy is real. Extend by adding rules in `inspect()`.

---

### #133 · FEATURE · 2026-06-11T20:10Z
- **By:** owner  ·  **Channel:** in-session

New purchasable horn "I'm gonna say it" (+ restored all the silent horns).

> staged (deployed Beta 0.0.25): added the horn "I'm gonna say it" (id 36, $5,000) — owner's `imgonnasayit.ogg` converted to MONO (say3D needs mono for 3D positioning), placed at `sounds\horns\imgonnasayit.ogg`, registered as CfgSound `imgonnasayit`, and added to fn_hornCfg `[36, "I'm gonna say it", 5000, true, "imgonnasayit", 8]` (8s = clip length / re-honk delay). It auto-shows in the garage horn shop ("I'm gonna say it - $5,000") and charges on purchase. ALSO FIXED a latent bug: deobfuscation had EMPTIED CfgSounds.hpp, so EVERY custom horn was silently dead (`say3D[id]` with no matching CfgSounds class = nothing plays). Restored CfgSounds classes for all 26 horn ids that have a matching `sounds\horns\*.ogg` (plus the orphan dixiehorn) — so the whole horn catalogue works again. Only `iLoveLoonybin` (id 34) stays silent: no `iLoveLoonybin.ogg` in the sounds folder (need the file to enable it).

---

### #134 · REFACTOR · 2026-06-11T20:40Z
- **By:** owner  ·  **Channel:** in-session

Full `ga_*` → `AP_*` rename (de-Asylum, structurally kills cross-contamination).

> staged (deployed Beta 0.0.25). Owner chose the FULL sweep (not just the profileNamespace keys). Renamed every `ga_*` identifier → `AP_*` across the ENTIRE codebase — **394 files, 2741 occurrences** (mission + server, .sqf/.hpp/.ext/.sqm/.cpp), both setVariable + getVariable sides renamed atomically so networked vars stay matched. Pattern: GNU sed `s/\<ga_/AP_/g` (start-of-word boundary) so mid-word classname substrings (`iga_F`, `aga_p`) were left alone. PRE-FLIGHT: confirmed NO DB columns are `ga_*` (SQL untouched), CfgRE.hpp has no var refs (functions only), and no collisions with the handful of pre-existing `AP_*` vars. Cleaned one hybrid key `ga_plb_killCache` → (would've been `AP_plb_killCache`) → `AP_killCache`. Re-pointed the profile-firewall (fn_requestReceived) to wipe `ga_*` (Asylum's leftover profile data) since LooneyBin now exclusively uses `AP_*` — collision with Asylum's keys is now STRUCTURALLY impossible, so the cross-contamination leak is fixed at the root (the firewall is now just belt-and-suspenders Asylum-residue cleanup). BACKUP before the sweep: `/tmp/lb_ga_rename_backup_1559.tgz` (mission+server, 22 MB) — restore with `tar xzf` if the reboot surfaces a problem. ⚠️ NEEDS A VALIDATION REBOOT: a token-preserving sed can't introduce SQF syntax errors, and set/get were renamed together, but this is 2741 edits — reboot to 0.0.25 and watch console.log + the new `-SCRIPTERR-` mirror for any `AP_` undefined-variable surprises. One-time effect: existing players' profileNamespace data (addiction/skins/etc., stored under old `ga_` keys) resets to empty under the new `AP_` keys — intended (clean break from Asylum).

---

### #135 · FIXED · 2026-06-11T21:10Z
- **By:** owner  ·  **Channel:** in-session

0.0.25 post-deploy scan: nametag HUD error, a dead horn, and an undefined questvar.

> staged (deployed Beta 0.0.26). The 0.0.25 rename validation came back CLEAN — the only runtime errors were two PRE-EXISTING deobf casualties (the rename just renamed the first one's message): (1) **Player nametags** — fn_playerTags `500 cutRsc ["AP_hud_nametags",...]` (was `ga_hud_nametags`) errored "not found" because the RscTitles class was wiped in deobf (same class as the horns/CfgSounds). RESTORED: added the `AP_hud_nametags` RscTitles to chat_hud.hpp with 64 structured-text controls (idc 78000-78063) that fn_playerTags positions per-frame via worldToScreen — names show over heads again. (2) **`AP_activeQuest` undefined** in fn_questSync (caught by the new `-SCRIPTERR-` mirror — proving it works): the var was read before init on one code path; added `AP_activeQuest=0` to configuration.sqf. (3) **Removed the "WOOO! I Love Loonybin!" horn** (id 34) from fn_hornCfg — it has no `iLoveLoonybin.ogg` so it was an unplayable shop entry (owner request). Stock Horn (CarHorn, id 0) kept — that's the vanilla engine horn, not a missing ogg. NOTE: the rename orphaned ZERO filenames (no `ga_*` files on disk), and the only `-SCRIPTERR-` in the whole DB was the questvar — the full sweep is confirmed clean.

---

### #136 · FEATURE · 2026-06-11T21:40Z
- **By:** owner  ·  **Channel:** in-session

Keychain "Open All Doors" for vehicles that support it (Ifrit etc.).

> staged (deployed Beta 0.0.26): added an **"Open All Doors"** button (idc 2706) to the Keychain (Y → Keychain / AP_key_management dialog, key_chain.hpp). New `AP_fnc_openVehDoors` (core/vehicle, registered in Functions.h + whitelisted in CfgRE.hpp) enumerates the selected vehicle's `AnimationSources` whose class name contains "door" and toggles them all open (or closed if any are already open). Generic — works on any vehicle with door sources (Ifrit/Hunter/trucks/helis), no-op + "no openable doors" message otherwise. Runs via `AP_fnc_MP` targeted at the vehicle (animateSource is local-argument/global-effect, so it must execute where the vehicle is local → broadcasts to everyone). fn_keyMenu now `lbSetData`s each row's `netId` so the button resolves the selection reliably. VERIFIED against BI config (web). Cars/MRAP doors = `Door_LF/RF/LB/RB` (controller `source="door"`); transport-heli doors = `Door_L/R`, `Door_Back_L/R` (also `source="door"`); heli **cargo ramps** = `CargoRamp_Open` / `Ramp_*` (controller `source="user"`, NOT a "door"). So the function now filters AnimationSources by name `door` OR `ramp`, then drives each with the command matching its controller: `animateDoor` for `source="door"`, `animateSource` for the `user`-controller ramps (so Mohawk/Huron/Taru ramps drop too, not just side doors). Toggle 1=open / 0=closed. ⚠️ BI ENGINE LIMIT: **armed** MRAP variants (the Ifrit MG now in the rebel shop, Hunter HMG in the MaxSec shop) cannot have their doors scripted — the button is a harmless no-op on those (unarmed Ifrit works).

---

### #137 · FIXED · 2026-06-11T21:40Z
- **By:** owner  ·  **Channel:** in-session

Drug cartel red circle still at the old spot (follow-up to #126).

> staged (deployed Beta 0.0.26): #126 moved the `drug_cartel` icon marker + `drug_flag` object to grid 8906/7489 but missed the separate **`drug_area`** marker — the red 50 m ELLIPSE ("Illegal area", ColorEAST) that draws the zone circle. Moved it from `[4854.49,0,21870.69]` to `[8906,0,7489]` so the red circle now sits on the flag. (The gameplay capture zone keys off `drug_cartel`/`drug_flag`, which already moved — this was purely the visual circle.)

---

### #138 · FEATURE · 2026-06-11T22:20Z
- **By:** owner  ·  **Channel:** in-session

MaxSec "Remove Firing Pin" — disable a restrained suspect's guns; suspect repairs it themselves (60s).

> staged (deployed Beta 0.0.26). New MaxSec RP mechanic (ALL ranks). **Cop** scroll option **"Remove Firing Pin"** on a civilian who is in COP restraints (`AP_restrained` && NOT `AP_civRestrained` — excludes bounty-hunter cuffs) → `AP_fnc_removeFiringPin` (cop) validates + remoteExecs `AP_fnc_breakGuns` to the suspect's client. breakGuns sets `AP_gunBroken` (global) + runs a 0.3s loop emptying the suspect's primary/handgun/launcher so they can't fire; a `Fired` EH in initPlayerLocal is the instant backstop (empties the weapon the moment it fires through a reload gap). **Suspect** gets a scroll option **"Fix Firing Pin"** that shows ONLY while UNRESTRAINED + broken → `AP_fnc_fixFiringPin` runs a 60-second progress bar (interruptible by death / re-restraint), then clears `AP_gunBroken` and guns work again. 3 fns in core/cop (registered Functions.h; `AP_fnc_breakGuns` whitelisted in CfgRE), 2 addActions in fn_setupActions, 1 Fired EH in initPlayerLocal. Logs `-FIRINGPIN-` (who pinned whom). NOT persistent across death/relog by design (fresh gear works) — say the word if you want it to survive a relog (needs a DB flag). The gun stays holstered/visible — it just won't fire (firing-pin RP, not a disarm).

---

### #139 · FEATURE · 2026-06-11T22:55Z
- **By:** owner  ·  **Channel:** in-session

Custom images: rules board, billboard ad rotation, flag texture, login splash.

> staged (deployed Beta 0.0.26). Added 5 owner images (PNG → compressed JPG via ImageMagick; no PAA tool, but the mission already uses JPG textures like the old grumpycat). All at the grumpycat convention 1024×512 except the square splash 1024². (1) **rules.jpg** (fafa.png) → replaced grumpycat on ALL 10 static town billboards in fn_mapData (the boards near the vehicle shops where rules used to show). (2) **RESTORED the billboard rotation** — fn_applyRandomBillboardTexture was deobf-gutted to a single static grumpycat; rebuilt it to register each rotating board + a single 5-minute loop that re-rolls them to a random ad from `AP_billboardAds` = **billboard1.jpg** (07_20_05) + **billboard2.jpg** (07_22_14). Per-client visual (each client rotates independently — fine for ads). (3) **AP_flag.jpg** (06_39_41) → all 8 grumpycat flag textures in mission.sqm (cartel capture flags + rebel-garage flag). (4) **splash.jpg** (06_14_41) → the login splash: `loadScreen` in description.ext AND the in-game loading background (loadingBackground.hpp). Deleted the now-unused grumpycat.jpg. Total new image footprint ~912 KB (74–389 KB each). Owner choices: 5-min rotation, all flags, all static boards. NOTE: clients re-download the new textures on reconnect (mission renamed b0026 = cache-bust). The .bak/.eden mission backups still name grumpycat but Arma never loads those.

---

### #140 · FEATURE · 2026-06-11T23:35Z
- **By:** owner  ·  **Channel:** in-session

Placeable home furniture — buy beds, chairs & tables from the new Homegoods Store in your house menu; everything saves through reboots.

> staged (deployed Beta 0.0.29). New **Homegoods Store** button in the House Management menu (owned houses) opens a virtual shop selling placeable furniture (Wooden Double Bed + 9 chairs/tables/sleeping bag). Buy → Y inventory → place within 20m of your house (no simulation, sim-cheap). Up to **20 pieces per house**, persisted in the `houses.furniture` DB column + respawned on boot. Scroll-wheel on a placed piece: **Lay Down/Get Up** (bed), **Move**, **Delete** (confirms, returns to Y inventory). The place/persist/pickup backbone existed (2026-06-10); this pass added the bed, the Homegoods Store + house-menu button, the 20-cap, and the lay/move/delete interactions. Bed $25,000. ⚠️ verify in-game: buying from the shop opened via the house menu + bed lay-down positioning.

---

### #141 · FEATURE · 2026-06-11T23:36Z
- **By:** owner  ·  **Channel:** in-session

Six new purchasable car horns: EFN, Randy Marsh, Not a Big Fan, RIP George, Whopper, and Tornado Siren.

> staged (deployed Beta 0.0.29). Added 6 owner-supplied horn oggs to `sounds\horns\` + CfgSounds classes + fn_hornCfg entries (ids 37-42, $5,000 each). Class ids stripped of spaces/hyphens (e.g. `randymarsh`, `notabigfan`, `tornadosiren`); sound paths point at the real files.

---
### #142 · FIXED · 2026-06-12T02:01Z
- **By:** player036  ·  **Channel:** #house repair  ·  **ref:** 100000000000000048/100000000000000048

House "Needs Repair" marker now clears once a medic finishes the repair.

> staged (deployed Beta 0.0.32). The TT repair un-ruins the building via `setDamage 0` (fn_repairBuildingSRV) -- it never deletes the ruins object, but the medic-side marker watcher (fn_medicRepairBuilding) only removed the "X - Needs Repair" map marker on `isNull _ruins`, which therefore never fired -> the dispatch marker lingered until the homeowner logged off. Fix: the watcher now also clears when the building is repaired (`damage _ruins < 1`) and polls every 5s (was 20s) so it disappears promptly. Original report: "after medics repair a broken house the house needs repair tag doesn't disappear."

---

### #143 · FEATURE · 2026-06-12T04:10Z
- **By:** owner  ·  **Channel:** in-session

Live dynamic market — dumping a lot of one good crashes its price, which recovers over time.

> staged (deployed Beta 0.0.32). The whole supply/demand machinery existed server-side (`AP_price_index`, the `AP_stock_update`/`AP_stock_change` events, `fn_reduceMarket`) but was inert: nothing published a sale, no client read the index for pricing, and `fn_itemDemand` was a stub returning 1. Wired it end-to-end: (1) `fn_itemDemand` now returns a real per-good market depth (luxury contraband = thin/crashes fast, bulk commodities = deep/barely moves); (2) new `AP_fnc_marketFactor` turns a good's saturation into a sell-price multiplier (1.0 → floor 0.4); (3) `fn_virtItemCfg "getLowestPrice"` applies that factor, so every sell point (shops, oil, pmenu market) is market-aware and display matches charge; (4) `fn_virtualShopManage` publishes `AP_stock_update` on each sale → server raises saturation → rebroadcasts; (5) a client PVEH in initPlayerLocal keeps `AP_price_index` synced; (6) `fn_reduceMarket` now recovers ANY good with accumulated pressure (was a hardcoded subset) each turf cycle (~15-40m). Untracked items return factor 1 (no-op), so non-market goods are unaffected. ⚠️ verify in-game: sell ~100 of a drug, watch its shop price drop, confirm it recovers later.

---

### #144 · FEATURE · 2026-06-12T04:12Z
- **By:** owner  ·  **Channel:** in-session

Sell your stored vehicles for cash from the Personal Vehicle Garage.

> staged (deployed Beta 0.0.32). The "Sell Vehicle" button (idc 100154) and a robust server handler (`APS_fnc_srvSellVehicle` — idempotency-locked DB delete + bank credit) already existed, but the feature was dead two ways: the client `fn_vehicleGarageSell` had a typo (`_className` vs `_classname`) that made it silently exit before pricing, and the button was never given an action by `fn_vehicleGarageLBChange`. Fixed the typo, wired the button (`buttonSetAction`), and added an "is it currently spawned" guard so you can't sell a vehicle that's out. Pays the vehicle config's sell-back value (row 8) into your bank. Also un-stubbed `fn_calcPrice` (was returning 0 → any `fn_vehicleDelete` payout was $0) so that legacy path is correct too. ⚠️ verify in-game: store a vehicle, open garage, select it, Sell → bank credited + row removed.

---

### #145 · FEATURE · 2026-06-12T05:30Z
- **By:** owner  ·  **Channel:** in-session

Truly dynamic market — prices move with supply, demand, random events, and WHERE you trade; new live Market board on the phone.

> staged (deployed Beta 0.0.32). Upgraded the basic sell-only market (#143) into a full economy across four axes the owner picked (two-sided, autonomous drift+events, regional, visible board — *not* finite stock). **Two-sided:** `AP_price_index` value is now a SIGNED demand index `d` per good — selling pushes `d` up (oversupply → cheaper), BUYING pushes it down (demand → pricier); both buy + sell prices scale by it. Buy reports `AP_stock_update=[item,-qty]`, sell `[item,+qty]`; the server PVEH clamps `d` to ±`itemDemand` depth. **Autonomous + events:** new server `APS_fnc_marketTick` (120s loop, registered + spawned from init) random-walks + mean-reverts every good and randomly fires SURGE/GLUT events (5-15m) that slam a good's price; publishes `AP_price_index` + `AP_marketEvents`. `fn_reduceMarket` neutered (superseded). **Regional:** `AP_fnc_marketFactor` reworked to `demandMult × regionMult` — 5 market hubs (`AP_marketHubs`: Kavala/Athira/Pyrgos/Sofia/Paros), each good gets a stable ±25% per-town bias from the player's position, so the same good is worth more in some towns (smuggling). Applied to buy (`fn_virtualShopPopulate`) + sell (`getLowestPrice` hook). Self-correcting (no risk-free arbitrage: base_sell < base_buy, and trading moves `d` against you). **Board:** the phone Market screen (`fn_mark1et`) now shows each good's live sell price, ▲/▼ trend + % vs baseline, `[SURGE]`/`[GLUT]` tags, and a per-good detail panel (buy/sell/demand/event) — location-aware. NOTE: market state runs in-memory from the `itemstock` DB seed; it does NOT persist tick-by-tick (resets toward baseline on restart — "market reopens"). ⚠️ verify in-game: open phone → Market (arrows + prices vary by item/town); buy a lot of one good and watch its price climb; sell a lot and watch it fall; check a SURGE event tag appears over time.

---

### #146 · FIXED · 2026-06-12T05:55Z
- **By:** owner  ·  **Channel:** in-session

Fixed a script error that spammed on every player connect (UFO-crash state default had the wrong type).

> staged (deployed Beta 0.0.32). The b0032 boot's console.log caught `[if: Type Object, expected Bool] core/fn_initCiv.sqf:166` each time a player connected. The server boot-default `SRV_ufoCrash` (init.sqf:99, a JIP nil-guard from an earlier defaults batch) was `[objNull,objNull,-99999]`, but index 0 is read as a BOOL ("is a UFO crash active") by `fn_initCiv:166` + `fn_ufoCrash` — so `if (objNull)` threw on every connect. Functionally harmless (the `if` errors out, the UFO block never runs), but it spammed the log + tripped CLANKR. Fixed the default to `[false,objNull,-99999,[]]` (idx0 = Bool active-flag, idx3 = placeholder for the crash-data `fn_initCiv:168` reads when active). Sibling `SRV_winterEvent` checked clean (only its `select 1` timestamp is read, never idx0 as Bool). Server-side → lands on next reboot.

---


### #147 · FIXED · 2026-06-12T07:30Z
- **By:** owner  ·  **Channel:** in-session

Security audit of this session's new code — closed a vehicle-sell money dupe, a SQL-injection vector, and a market arbitrage exploit.

> staged (deployed Beta 0.0.32). Owner asked for a full vulnerability pass over the session's changes. Found + fixed three real issues, all in code I made live this session:
> 1. **Vehicle-sell money dupe (CRITICAL).** `APS_fnc_srvSellVehicle` credited the bank with the *client-supplied* sell price (`UPDATE bankacc + _price`), no validation — a modded client could claim billions. Now SERVER-AUTHORITATIVE: it reads the vehicle's real classname + side from the DB and recomputes the sell-back from `AP_fnc_vehicleConfig "getVehicleRow"` (raw entry, idx 8, indexed by the DB side — `getVehicleRowParsed` was wrong here since `playerSide` is unreliable on a dedicated server), honoring any `priceOv "veh"` override; the client figure is ignored (only a 500k-capped fallback for an unlisted class), final sanity cap 10M.
> 2. **SQL injection.** `_uid` (client-supplied) was string-formatted straight into the SELECT/DELETE/UPDATE. Added a digits-only guard (a real Steam UID is numeric) before any query. `_plate` is Number-typed so it's already safe.
> 3. **Market arbitrage.** With small market depths (150-500) a single 100-unit trade moved the price factor up to 40%, so a scripted buy-then-sell (or sell-then-buyback) round-trip could beat the buy/sell spread = money pump. Raised `fn_itemDemand` depths to 800-1800 so one max trade moves the factor only 3-7.5% — a round-trip now profits only if sell > 92-97% of buy (never). Aggregate volume + drift + events still move prices. Chose this over per-trade slippage pricing to avoid risky surgery on the shop's branchy price logic.
> 4. Enabler: `fn_vehicleConfig` lines 10-11 (`AP_copLevel`/`AP_medicLevel`) guarded with `hasInterface` so the price path is safe to call server-side.
>
> RESIDUAL / by-design (not fixed): `AP_stock_update` is a client-writable publicVariable → a cheat can pin a good's demand index, but it's clamped to ±depth and the whole economy is client-trust anyway (CLANKR watches money). The Love Bomb levels ALL buildings (shops/bank included) in 1km — owner's explicit "retirement party" design, flagged as a grief/economy risk. NOT factually 100% verified — the server-side `vehicleConfig` call + the DB query shape need an in-game playtest to confirm; logic is balance-checked + reasoned. ⚠️ verify in-game: sell a cop AND a civ vehicle (correct per-side payout); confirm a modded-price sell still pays the real value; market prices still move with volume/events.
### #148 · FIXED · 2026-06-12T17:36Z
- **By:** player004  ·  **Channel:** #asylum + skin  ·  **ref:** 100000000000000049/100000000000000049

asylum + skin — found a asylum skin in rebel shop

> staged (deployed Beta 0.0.33). The rebel clothing shop's "Messenger Bag (Loonybin+)" (`fn_clothing_reb.sqf:450`, UNGATED) used texture `images\asylumplusbag.jpg` — the original **Asylum+** donor bag: the label was de-branded but the SKIN still shows Asylum+ branding (IP/rebrand leak). Removed that shop entry. **Broader de-brand still pending (same Asylum-branded textures, donor-gated, NOT removed — owner call to remove vs reskin):** `asylumplusbag.jpg` + `asylumpluscsats.jpg` (clothingTextures ids 74/71), `asyplus\csat_quarantine.jpg` + `asyplus\farmer_mitch.jpg` (ids 85/86), and the `icons\loonybinpartystreamer.paa` notification banner (giveaway/login/xmas). Adidas-parody "Asydidas/Granit adidas" skins already have de-branded labels (filenames still say asydidas — cosmetic, not player-visible).

### #149 · NEEDINFO · 2026-06-12T21:43Z
- **By:** player030  ·  **Channel:** #Bank and Jewelry  ·  **ref:** 100000000000000050/100000000000000050

> No description provided (player030). Can't action — needs a repro/description. Closing as needs-info.

Bank and Jewelry — Bank - Text and Timer Bar need adjustment
Jewelry - No Timer Bar for Safe and no inventory on broken cases

> **Jewelry: staged, deploys next reboot.** Two logic bugs in the reconstructed handler:
> (1) **No timer bar for safe** — client `weldSafe` gated on `SRV_jewelryEmporiumSRV[3]` (safeWelded), only true AFTER welding → unreachable → action exited before showing the bar. Fixed to gate on `[2]` (safeDrilled). Also fixed `takeSafeContents` to require `[3]` (welded) instead of `[4]`.
> (2) **No inventory on broken cases** — server `createCase` (`fn_jewelryEmporiumSRV.sqf`) only marked the case looted; never spawned the `Land_Trophy_01_gold_F` loot the client's `takeJewelryContents` grabs. Now spawns it on the smashed case.
> **Bank: NOT changed — too vague.** Drill HUD exists (`AP_bank_hud`, text + bar) and `_dur=600` matches the server drill. Need specifics: wrong wording? bar overlap? timer drift (~35s "placing" phase before the 600s count)?

---

### #150 · NEEDINFO · 2026-06-12T21:45Z
- **By:** player030  ·  **Channel:** #Mobile HQ  ·  **ref:** 100000000000000051/100000000000000051

> No description provided (player030). Needs a repro/description.

Mobile HQ — Mobile HQ spawned NPC's but didnt spawn buildings

> **Staged, deploys next reboot.** `fn_srvMobileHQ.sqf` (reconstructed from stub) only spawned the gear/vehicle NPCs + shop actions — no structures. Added server-spawned deployables around the truck (`Land_Cargo_HQ_V1_F` command post, two `Land_BagFence_Long_F` sandbag walls, `Land_PortableLight_double_F` floodlight, `Flag_NATO_F`), `allowDamage false`, positioned via truck model offsets, and wired into the teardown cleanup so they delete with the truck.

---

### #151 · FIXED · 2026-06-12T22:46Z
- **By:** player029  ·  **Channel:** #pyrgos pd weapon shop dissapears  ·  **ref:** 100000000000000052/100000000000000052

pyrgos pd weapon shop dissapears — https://medal.tv/games/arma-3/clips/mU3g74Ix0hkbwHCsN?invite=cr-MSw5NGMsNDE2MzgzMTYx

---

### #152 · NEEDINFO · 2026-06-12T23:56Z
- **By:** player030  ·  **Channel:** #Jewelry  ·  **ref:** 100000000000000053/100000000000000053

> No description provided (player030). Needs a repro/description.

Jewelry — Still doesnt have time bar for safe crack
auto clean up cleared trophies
some glass cases do not give option to crack

> **Partial fix deployed b0041:** trophy loot tagged `AP_furniture` → exempt from the fn_cleanup sweep.
> **Rest staged (deployed Beta 0.0.42):**
> (1) Safe timer bar — the "Laser Cut Safe" scroll action's VISIBILITY required `!(SRV_jewelryEmporiumSRV param [4,false])`, but slot 4 (casesLootable) goes TRUE the instant the robbery starts → the action disappeared exactly when the safe became cuttable. Now checks slot 3 (safeWelded) so it only hides after the weld.
> (2) Some cases won't crack — two causes: the "Break Jewel Case" action used a 1.5 m nearestObjects radius (too tight for big display cases; now 3 m, all 3 lookup spots), and fn_jewelryEmporium whitelisted only the 14 Eden-named cases so any other Coffin_02_F in the building silently no-op'd (now accepts any display case inside the emporium polygon).

---

### #153 · FIXED · 2026-06-12T23:59Z
- **By:** owner (in-chat) — persistent vehicle trunk came back EMPTY on pull (steamuser live test, plate 105629)

RPT proved the SAVE works (full inventory in the UPDATE) and the DB clear works; the restore was being WIPED client-side right after spawn: `fn_vehicleGaragePull:175` clearItemCargoGlobal + `fn_prepareVehicle:10/11` cargo clears + `:43` AP_vinv=[[],0] all run post-spawn and clobbered the server's instant restore.
> **Fix staged (deployed Beta 0.0.40):** `fn_vehicleSetActive` now clears the DB row immediately (anti-dupe unchanged) but delays the in-vehicle restore 3s — lands after the client init storm. Adds `[LooneyBin][trunk] restored...` diag_log for verification.

### #154 · FIXED · 2026-06-12T23:59Z
- **By:** owner (in-chat) — placed Homegoods (furniture) items don't survive reboot

Persistence plumbing (houses.furniture + APS_fnc_houseFurnitureSRV add/presencestart) all exists, but the DB showed ZERO houses with furniture: the client gate `fn_placeObject:60` matched the nearby house with `_x in AP_vehicles` (the VEHICLES array — never contains houses) → `_house` always objNull → the "add" was never sent.
> **Fix staged (deployed Beta 0.0.40):** match the house whose `AP_homeOwner` equals the placer's UID (verified AP_homeOwner stores UIDs). Furniture placed in YOUR house now persists; the server-side 20-piece cap + restore-on-presence path was already live.

---

### #155 · FIXED · 2026-06-13T16:16Z
- **By:** player053  ·  **Channel:** #Sgt doesn't get any bags  ·  **ref:** 100000000000000054/100000000000000054

Sgt doesn't get any bags — And lacking vests

> Fixed (staged). `fn_clothing_cop.sqf` case 4 (backpacks) only had the SRT pack, the talent-gated UAV pack, and the 7 INVISIBLE packs (SGT/lvl4+) — so SGT's only "bags" were invisible (look like none) and lower ranks had zero. Owner picked "all cops, scaled by rank": added visible black MaxSec packs — Assault/Field (Cadet+), Kitbag/Tactical (Cpl+), Carryall/Bergen (Sgt+); invisible ones kept as extras at SGT+. **Vests note:** SGT already gets vests (Rangemaster/Bandolliers/Smersh/Rebreather); plate-carrier ARMOR is talent-42 or lvl-5+ gated by design — say if SGT should get a plate carrier ungated.

---

### #156 · WONTFIX · 2026-06-13T16:18Z
> closed 2026-06-22: NOT code-fixable -- the hem/badge text is baked into the JPEG (images\skins\maxsec\po.jpg), not scriptable. Needs an art fix (clean the XX + hem). Code stopgap available if wanted: repoint lvl-2 to a cleaner rank texture.
> update 2026-08-13: MOOT -- the pending art fix was overtaken. Every custom MaxSec skin (all 8 per-rank uniform .jpgs incl. po.jpg) was deleted repo-wide; `fn_copLoadout` no longer sets any uniform texture and all ranks now wear the stock `U_Rangemaster`. There is no baked badge/hem art left to glitch.
- **By:** player053  ·  **Channel:** #TEXTURE GLITCH LVL 2 COP VEST  ·  **ref:** 100000000000000055/100000000000000055

TEXTURE GLITCH LVL 2 COP VEST — At bottom of vest you see random text

> Diagnosed, NOT code-fixable. The lvl-2 cop wears the MaxSec rank uniform texture `images\skins\maxsec\po.jpg` (applied via `setObjectTextureGlobal[0,...]` in `fn_copLoadout:12,19`). The badge art reads "PROJECT LOONYBIN **XX**" (XX placeholder) and the lower-uniform text bleeds onto the model's hem near the vest — baked into the JPEG, not scriptable. Owner decision: leave po.jpg for an art fix (clean the XX + hem text). Same badge/XX is on all rank textures (cadet/cpl/sgt/lt/capt). Code-side alt if wanted: repoint lvl-2 to a cleaner rank texture meanwhile.

---

### #157 · FIXED · 2026-06-13T16:23Z
- **By:** player053  ·  **Channel:** #No skin on cop strider  ·  **ref:** 100000000000000056/100000000000000056

No skin on cop strider

> Fixed (staged). `fn_vehicleTextures.sqf` had `I_MRAP_03_F` skins only for `["fed"]`/`["reb"]`, none for `["cop"]` — cops buy the Strider (vehicleConfig:22 west) so it spawned skinless. Added a `["cop"]` "MaxSec Black" entry (base-Arma black procedural, matches the stripped-skins policy). ⚠️ verify in-game: buy cop Strider → black skin.

---

### #158 · FIXED · 2026-06-13T17:13Z
- **By:** player036  ·  **Channel:** #Medic prestige  ·  **ref:** 100000000000000057/100000000000000057

Medic prestige — medics dont get prestige from revives or narcan

> Fixed (staged). Two parts: (1) **Narcan** = the adrenaline shot (`fn_adrenal1neShot.sqf`) only gave `AP_side_exp`, never TT prestige — added `25 call AP_fnc_medicEarn` when used on another player. (2) **Revives DID grant** `AP_medic_exp += 250` but **silently** (no chat), so medics thought they got nothing; routed it through `AP_fnc_medicEarn` and added a `systemChat "You've earned N TT prestige."` to medicEarn (covers revive/narcan/medkit/bloodbag/repair/fire). NB: TT prestige currency = `AP_medic_exp`; the prestige tree to SPEND it is AEMT+ (medicLevel ≥ 3) only — lower ranks accumulate but can't open the menu yet (by design).

---

### #159 · FIXED · 2026-06-13T17:51Z
- **By:** player004  ·  **Channel:** #no hexs on group or gang group  ·  **ref:** 100000000000000058/100000000000000058

no hexs on group or gang group — no hexs on group or gang group

> Fixed (staged). Caused by THIS round's purple-arrows fix: I'd set `setGroupIconsVisible [false, false]` (initPlayerLocal + fn_initGang), which killed BOTH the map icons AND the wanted 3D hexs. `setGroupIconsVisible` is `[mapVisible, hudVisible]` — the "purple arrows" were the MAP icons (civilian side renders purple). Changed both to `[false, true]`: hide the map arrows, keep the 3D HUD hexs over group/gang members. Resolves #159 + the purple-arrows complaint together.

---

### #160 · FIXED · 2026-06-13T18:20Z
- **By:** player053  ·  **Channel:** #All vehicles spawn half fuel  ·  **ref:** 100000000000000059/100000000000000059

All vehicles spawn half fuel

> Fixed (staged). New vehicles had fuel HARDCODED to `[0, 0.5]` (the `_vehWear` arg to `fn_prepareVehicle`) in all three fresh-spawn paths: `fn_vehicleShopBuy:239`, `fn_craftRecipe:263`, `fn_clientMobileHQ:68`. All → `[0, 1]` (full). Garage-pulled vehicles keep their persisted fuel.

---

### #161 · FIXED · 2026-06-13T18:40Z
- **By:** player064 (player072 · 100000000000000060)

Bought a shed player-to-player: can open the house menu + upgrade it, but can't place objects, can't access the vehicle garage, and it doesn't show as an owned property.

> ROOT (2 bugs in `server/.../TON/fn_transferHouse.sqf`, the hand-built market/P2P transfer):
> (1) **DB transfer never persisted** — the row UPDATE used `WHERE id='<oid-hash>'`, but `id` is the auto-increment INT PK and the value passed (`AP_houseID`) is the `oid` varchar position-hash. No match → ownership never written → the shed reverts to the seller on reboot.
> (2) **No client finalize** — `transferHouse` set `AP_homeOwner` (global) + paid the seller, but never called `AP_fnc_handleHouse`. The buyer-finalize (**mode 5**: pushes `AP_houses`/`AP_vehicles`, draws the owned marker, adds keychain, clears `AP_houseTxn`) and the seller-finalize (**mode 4**: removes their list entries/marker, pays) both already EXIST and are exactly for this path — they were just never invoked. So the buyer had `AP_homeOwner` set (menu + upgrade worked) but NO `AP_houses` entry → place-object/garage/owned-list all gated on `AP_houses` failed; seller kept phantom client-side ownership.
> **Fix staged (deploys next reboot):** UPDATE keyed on `oid`; sync `AP_house_owners`; remoteExec `handleHouse` mode 5 to the buyer + mode 4 to the seller (online) / DB credit (offline); removed the now-redundant double-pay path.
> **Data repair (done in-session):** shed `oid=2063217018` reassigned to buyer `76561190000000003` in the DB (he paid $150k, seller `76561190000000004` was paid online). player064 must **relog** to load it client-side (the in-session finalize never ran); it's also his after the reboot.

---

### #162 · FIXED · 2026-06-13T18:47Z
- **By:** player053  ·  **Channel:** #CAN'T PULL STRIDER FROM GARAGE  ·  **ref:** 100000000000000061/100000000000000061

CAN'T PULL STRIDER FROM GARAGE

> Fixed (staged). `fn_vehicleGaragePull.sqf` has an "undercover" gate that rejects a west player pulling unless the vehicle's TEXTURE carries a `"cop"`/`"fed"` flag. The Strider had no cop skin (#157) → its texture flags lacked `"cop"` → "this vehicle can only be used when you are in the undercover role." Fix: also pass the gate when the vehicle is a cop vehicle by CONFIG CATEGORY (`cop_car/cop_air/cop_ship/maxtac_car/srt_car`), so legit cop vehicles are pullable regardless of skin. (#157's new cop skin also helps when the stored color = the cop entry.) Note: vehicleConfig has 3 `I_MRAP_03_F` rows but `getVehicleRowParsed` skips `srt_car` rows → resolves to the cop_car one, so the dup isn't the cause.

---

### #163 · FIXED · 2026-06-13T19:42Z
- **By:** player004  ·  **Channel:** #infamy issue  ·  **ref:** 100000000000000062/100000000000000062

infamy issue — we are not getting infamy for cartel kills564

> Fixed (staged). Two gaps in `evh/fn_onPlayerKilled.sqf`: (1) the kill-reward block only fired for declared WAR kills / drugPen / warzone / fortress — a kill at a cartel didn't qualify at all; (2) even war kills grant war-rating + New Drachma but **never infamy** (infamy via `updateRemoteStat` case 2 is only triggered by *capturing* a cartel, `fn_captureCartel:185`). Fix: added `_isCartelKill` (both killer + victim within 300m of a cartel flag) to the qualifying condition so cartel kills now earn the war stats + New Drachma (with the existing 600s per-victim anti-farm + `_notGangMember` gate), and grant **+15 infamy to the killer** (`AP_fnc_addInfamy`, rebel-licensed only) on any cartel kill.

---

### #164 · FIXED · 2026-06-13T19:45Z
- **By:** owner (in-chat)

Cartel crate spawns loot table is fucked — spawns wrong loot or no loot. Should ONLY spawn things you can buy at rebel.

> Fixed (staged). The four cartel capture crates (`server/AP_server/init.sqf` ~L693) were stocked by a hardcoded per-cartel `switch` that (a) dropped partly-non-rebel items (Mk20/Medikit/SMG_02/ToolKit) and (b) filled **once at boot, never refilled** → empty for good once looted ("no loot"). Replaced with `AP_fnc_fillCartelCrate` drawing from two rebel-only pools (`AP_cartelGunPool` / `AP_cartelItemPool`, all confirmed `"rebelwep"`-buyable in `fn_weaponShopCfg`): each fill = 2–4 random guns (mags auto-resolved from `CfgWeapons >> magazines`) + 2–4 utility items. Added a 10-min refill loop that restocks a crate only when its weapon AND item cargo are both empty (won't wipe a half-looted crate). End-game rebel guns (Zafir/LMG_03/RPG/Titan) deliberately excluded so they aren't free cartel spam. ⚠️ verify in-game: capture a cartel → crate holds rebel guns+mags+items; loot it empty → restocks within 10 min.

### #165 · FEATURE · 2026-06-13T20:22Z
> closed 2026-06-22: feature request (add Heal / Heal All to the admin menu), not a bug -- out of scope per the standing "all but feature requests" rule. Easy to add later if wanted (mirror the Revive buttons).
- **By:** player008  ·  **Channel:** #report  ·  **ref:** 0/100000000000000063

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000064> (`player008` · `100000000000000064`)
**Date / Time:** JUST NOW

**Description of event / rule broken:**
Add heal and heal all to admin menu

**Evidence:**
_none provided_

---

### #166 · FIXED · 2026-06-13T20:56Z
- **By:** player047  ·  **Channel:** #report  ·  **ref:** 0/100000000000000065

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000066> (`player047` · `100000000000000066`)
**Date / Time:** just now

**Description of event / rule broken:**
the new shed message blocks you from purchasing a home while having free house slots available

**Evidence:**
_none provided_

> Fixed (staged). The "1 shed per player" limit in `fn_buyHouse.sqf` listed all 4 shed-ish classes, including the small `Land_i_Stone_Shed_V1/2/3_F` — those are cheap 1C starter HOUSES (40k, ~1-crate), not the warehouse. So owning a 1C stone shed blocked buying any other shed-type 1C even with free house slots. Narrowed `_shedTypes` to **`Land_i_Shed_Ind_F` only** (the 200k / 900-slot industrial warehouse). Stone sheds are unlimited normal houses again. Cap raised to **2 industrial sheds** per player (owner, same day) — counts owned warehouses, blocks the 3rd.

---

### #167 · FIXED · 2026-06-13T21:05Z
- **By:** owner (in-chat)

When a user sells a house to another player, the house stays LISTED after the purchase — others can still buy it at the listed price. The listing should clear on purchase (currently the seller has to manually unlist).

> Fixed (staged). Follow-on to #161. A market listing sets `AP_house_price > 0` on the building (the var `fn_buyHouse` reads to offer a "for sale" purchase). `APS_fnc_transferHouse` cleared `salePrice` + the DB `sale` column on a sale but NOT `AP_house_price`, so the building stayed buyable to everyone else at the listed price after it sold. Now transferHouse sets `AP_house_price = -1` (building reads as owned-not-for-sale) and drops it from `AP_forSaleHouses` (+ re-publicVariable) so the phone market drops it too — the listing dies the instant it's bought, no manual unlist.

---

### #168 · NOTABUG (as designed) · 2026-06-13T21:35Z
- **By:** player098  ·  **Channel:** #report  ·  **ref:** 100000000000000067/100000000000000068

> Owner: working as designed. Closed.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000069> (`player098` · `100000000000000069`)
**Date / Time:** 6/13/2026 16:32

**Description of event / rule broken:**
Vehicle virtual inventory seems to stay even after storing the vehicle

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000070/100000000000000071/image.png?ex=6a2f1ebc&is=6a2dcd3c&hm=e8c827f70f68e672ae2f1258fbedb7ba86a33501802630b955d8311338dbaa4e&

---

### #169 · FIXED · 2026-06-13T21:40Z
- **By:** owner (in-chat) — "why are MK200s downing people, I downed Carter with one, should be lethal"

Lethal civ/rebel weapons firing TRACER ammo (e.g. MK200 with the tracer box) DOWN the target instead of killing.

> Fixed (staged). The down-vs-kill gate in `evh/fn_handleDamage.sqf` computed `_stunMag = ("Tracer" in _curMag) || (_copSource && _nonLethal)`. The `"Tracer" in _curMag` clause was meant to catch COP rubber/tracer non-lethal rounds, but it applied to EVERYONE — so any civilian/rebel weapon loaded with tracer ammo (`200Rnd_65x39_cased_Box_Tracer`, etc.) was classified as a stun round → downed instead of killing. Gated the tracer check to cop sources: `_stunMag = _copSource && (_nonLethal || ("Tracer" in _curMag))`. Cops keep their non-lethal/tracer stun; civ/rebel tracer ammo is lethal again. Civ BH stun is unaffected (it runs off the SMG_02/P07 weapon whitelist, not tracer mags).

---

### #170 · FIXED · 2026-06-13T21:44Z
- **By:** player051  ·  **Channel:** #report  ·  **ref:** 100000000000000072/100000000000000073

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000074> (`player051` · `100000000000000074`)
**Date / Time:** Just now

**Description of event / rule broken:**
You can buy gun store houses, at least the one in kavala. havent seen others

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000075/100000000000000076/IMG_2835.jpg?ex=6a2f209e&is=6a2dcf1e&hm=669cd5164efe480673be62366dcffffb12cd75af389d5e06b4b3de0428372425&

> Fixed (staged). Shop buildings (`Land_i_Shop_01_V*`) are intentionally buyable as houses, BUT the specific buildings hosting NPC shops (gun store, etc.) were never protected — the `AP_restricted_house` guard exists in `fn_buyHouse`/`fn_houseMenu` but **had no setter anywhere in the codebase**, so the flag was always false. Added the setter where shop NPCs spawn: `fn_shops.sqf` + `fn_copShops.sqf` now flag the nearest house-type building (≤10m) `AP_restricted_house = true` when the NPC initialises (per-client; `fn_buyHouse` reads it locally). Covers the gun store + every civ/cop shop NPC sitting in a house-type building. (Vehicle/gas NPCs use separate fns + are usually standalone structures — add the same hook there if any turn out buyable.)

---

### #171 · FIXED · 2026-06-13T21:48Z
- **By:** owner (in-chat) — "players are getting errors about too many people making phone calls"

The in-game voice phone call system throws "phoneLinesMaxed" ("too many people making phone calls") for basically everyone.

> Fixed (staged). Two faults in the call pool. (1) `APS_fnc_handlePhoneCallSRV` started with an EMPTY `AP_phoneCalls` and created radio channels **on demand** via `radioChannelCreate`. Boot already burns ~9 channels (`server_init.sqf`: dispatch + 3 RF + 5 phone), and Arma caps total radio channels — so the on-demand creates hit the cap, returned 0, and every caller got maxed. Now the handler **seeds the pool from the pre-allocated `AP_phone_groups` channels** (valid/non-zero only) and never creates new ones → fixed concurrent-line pool. (2) Slots **leaked on disconnect**: `fn_playerDisconnected` called the dead `managePhone(objNull)` (no player ref) so a disconnect mid-call pinned a channel forever, draining the pool. Now it ends the leaver's active call by their unit ref (frees the line). Also bumped the boot pool 5 → 10 concurrent lines for headroom (over-allocation is harmless — invalid channels are filtered).

---

### #172 · FIXED · 2026-06-13T22:05Z
- **By:** owner (in-chat) — "should need to be 4 cops online for bank and 6 for federal reserve and jewelry"

Robbery cop-online requirements wrong: Bank should need 4, Federal Reserve 6, Jewelry 6.

> Fixed (staged). The gate `fn_policeRequired` is already active (`AP_betaZeroCops = false`, server_init:493), but the required counts were wrong: the Bank and Fed callers read `AP_(bank|fed)_robbed select 2`, but those arrays are only `[robbed, time]` (no slot 2) → nil → `policeRequired` defaulted to **1 cop**; Jewelry's `SRV_jewelryEmporiumSRV` slot 6 was **4**. The "slot 2" count was never implemented in the arrays, so set the literals: Bank → `[4, true]` (`fn_setupActions` Begin Drilling Vault); Fed → `[6, true]` (`fn_openGate` / `fn_openVault` / `fn_openSafe`); Jewelry → slot 6 = `6` (`init.sqf` + the `param [6, 6]` default in `fn_jewelryEmporiumSRV`). Other events (prison/evidence/convoy/LoonyBin) left at their existing counts.

---

### #173 · FIXED · 2026-06-13T22:27Z
- **By:** player047  ·  **Channel:** #report  ·  **ref:** 100000000000000077/100000000000000078

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000066> (`player047` · `100000000000000066`)
**Date / Time:** just now

**Description of event / rule broken:**
ran for gov office. I had 2 votes. Paid 75k. Candidate list got wiped after restart

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000079/100000000000000080/20EAF91.JPG?ex=6a2f2ac2&is=6a2dd942&hm=f4a21868d74c81aea3e781e09293e4f45f38ca00502c30a017ddc787509a7d33&

> Fixed (staged). `APS_fnc_govSystemSRV` kept candidates ONLY in the in-memory `SRV_govCandidates` + the election clock in a one-off `uiSleep 1800` spawn — neither persisted, so a restart wiped every candidate (and their 75k buy-in) while their votes lingered orphaned in the `votes` table. Also the `candidates` table referenced by the legacy `fn_govMaint` **didn't exist**. Fixes: (1) created the `candidates` DB table; (2) `runForOffice` now `REPLACE`s the candidacy into it (with `started_at`); (3) new `"reload"` case (called from `init.sqf` at boot) rebuilds `SRV_govCandidates` from `candidates` + re-tallies each one's votes from `votes`, and **resumes the 30-min election timer** from `started_at`; (4) election resolve now also `DELETE`s from `candidates`; the timer is unified on `SRV_govElectionEnd` so it survives. **Refund (done in-session):** Ebola (`76561190000000005`) got his **$75k** back via in-game mailbox (claim at the Altis Exchange). ⚠️ verify after reboot: run for gov, restart, candidacy + votes still there + election still resolves.

---

### #174 · FIXED · 2026-06-13T23:43Z
- **By:** player019  ·  **Channel:** #report  ·  **ref:** 100000000000000081/100000000000000082

> Fixed (staged, b0060). Shift-T tactical ping (`fn_keyUpHandler`) sent to `units group player`. Gang groups carry `gang_id` (fn_gangInv1te/fn_initGang) and squad/group-menu groups carry `AP_grpTag` (fn_createGroup), but UNGROUPED players all share the DEFAULT mission group → the ping leaked to everyone not in a gang/squad. Now: ping the group only if it's a real group (`gang_id` set OR `AP_grpTag` set); ungrouped players ping only themselves. Mission change → version bumped b0059→b0060.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000083> (`player019` · `100000000000000083`)
**Date / Time:** just nowe

**Description of event / rule broken:**
I can see Shift T Pings from groups other than my own

**Evidence:**
_none provided_

---

### #175 · FEATURE · 2026-06-14T00:02Z
> closed 2026-06-22: feature request (bounty-hunter shop on houses), not a bug -- out of scope per the standing "all but feature requests" rule.
- **By:** player008  ·  **Channel:** #report  ·  **ref:** 100000000000000084/100000000000000085

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000064> (`player008` · `100000000000000064`)
**Date / Time:** JUST NOW

**Description of event / rule broken:**
make shop for bounty hunter shop on houses as well

**Evidence:**
_none provided_

---

### #176 · FIXED · 2026-06-14T00:36Z

> Fixed (staged). `fn_cartelEventCapture` built its "captured by" broadcast audience from ALL players inside the warzone/drug-pen polygon with NO side filter -> any MaxSec officer in the area got cartel-cap notifications meant for gangs/civs. Now civilian-only.
- **By:** player073  ·  **Channel:** #MaxSec getting notifications about cartels being capped  ·  **ref:** 100000000000000086/100000000000000086

MaxSec getting notifications about cartels being capped — https://images.steamusercontent.com/ugc/14958604304570289584/3E32939CC1E3171DAF300CF916FCE03CD236F693/?imw=5000&imh=50

---

### #177 · FIXED · 2026-06-14T00:48Z
- **By:** player051  ·  **Channel:** #report  ·  **ref:** 100000000000000087/100000000000000088

> Closed 2026-06-14 (owner: solved). Buy path was structurally intact — seeds (`cannas_0`/`cannai_0`) ARE in the Drug Dealer list, priced ~$100, weight-checked, buyable; the block was runtime state, not a code defect.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000074> (`player051` · `100000000000000074`)
**Date / Time:** just now

**Description of event / rule broken:**
the ability to buy seeds from drug dealer went away, before reset i was able to buy 10. and now i cant again

> Investigated 2026-06-14 — NO code defect found. Seeds (`cannas_0`/`cannai_0`) ARE in the Drug Dealer ("heroin" shop) buy list, priced ~$100 via getBasePrice, weight-checked (`calWeightDiff`), buy button enabled; the populate + buy path is intact. Cause is runtime state (carry weight full / cash / wrong drug NPC). Needs the IMG_2836 screenshot or an exact repro to pin.

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000075/100000000000000089/IMG_2836.jpg?ex=6a2f4bf8&is=6a2dfa78&hm=bb9c219e23f78ad8497ab42e9ee59294869e8aee5993e9c864a4b2f341eabee1&

---

### #178 · NOTABUG (as designed) · 2026-06-14T01:06Z
- **By:** player036  ·  **Channel:** #report  ·  **ref:** 100000000000000090/100000000000000091

> Owner: oil cartel rubber generation is working as designed. Closed.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000092> (`player036` · `100000000000000092`)
**Date / Time:** just now

**Description of event / rule broken:**
oil cartel still does not generate oil if you look in your phone under captures it  says oil cartel 0 rubber so there is no point is getting oil

**Evidence:**
_none provided_

---

### #179 · FIXED · 2026-06-14T01:11Z
- **By:** player047  ·  **Channel:** #report  ·  **ref:** 100000000000000093/100000000000000094

> FIXED (deployed b0059). The clothing-menu cancel-restore (`fn_clothingMenu`) did `removeBackpack` + `addBackpack` of the old pack on close, creating a FRESH (visible) object — so a previously-bought invisible pack reappeared on reopen+close. `AP_invisBag` persists the state; now the restore re-applies `unitBackpack player hideObjectGlobal true` when it's set. (Same report as the owner's earlier one, already live.)

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000066> (`player047` · `100000000000000066`)
**Date / Time:** just now

**Description of event / rule broken:**
if you purchase an invisible carry-all. close the clothing store and reopen it. it makes it visible again

**Evidence:**
if you need a clip of it ill have to make one

---

### #180 · FIXED · 2026-06-14T04:05Z
- **By:** player036  ·  **Channel:** #report  ·  **ref:** 100000000000000095/100000000000000096

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000092> (`player036` · `100000000000000092`)
**Date / Time:** just now

**Description of event / rule broken:**
cant pull cars from wongs cartel it says there is a car blocking the spawn point even though there very much isnt

> Fixed (staged, server-side). Sibling of #199. The "blocking the spawn point(s)" message is `fn_vehicleGaragePull`'s occupancy check: a spawn marker is rejected if `nearestObjects[pos,["Car","Ship"],5]` OR **`nearestObjects[pos,["Air"],14]`** is non-empty. Root cause = the cartel-capture airdrop (`APS_fnc_airDrop`) deleted only the crate + smoke and **left the parachute** — `B_Parachute_02_F` is an **"Air"-class** object, so a spent chute lingering near the cartel tripped the Air-14m check -> "a vehicle is blocking the spawn point" with NO car in sight. Fix: airDrop now `deleteVehicle`s the chute the instant the crate lands (no more litter). If a Wongs pull still fails after this, it's a real parked heli / >100m marker -> needs the exact garage NPC in-game.

**Evidence:**
_none provided_

---

### #181 · FIXED · 2026-06-14T04:22Z
- **By:** player036  ·  **Channel:** #report  ·  **ref:** 100000000000000097/100000000000000098

> Fixed (staged, deploys next reboot). Regression from #164: the cartel weapon-crate code (`init.sqf`) filled every crate at boot + refilled unconditionally every 10 min, so guns were always there with no need to cap. Now CAPTURE-GATED: crates start empty; a 60s loop fills a crate only while its cartel is fully capped (`<flag>_flag` `AP_capData` progress >= 1 AND owned by a gang) and wipes it empty when not capped. Flag map arms/drug/oil/wongs in crate order; read via missionNamespace (objNull-safe).

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000092> (`player036` · `100000000000000092`)
**Date / Time:** just now

**Description of event / rule broken:**
JimJim — 12:21 AM
so the weapon crates are always spawned at the cartels it seems
and full of new guns every time
without capping it
Doomba — 12:21 AM
make a bug report pls

**Evidence:**
_none provided_

---

### #182 · FIXED · 2026-06-14T06:21Z

> Fixed (staged, server-side). The boot loader restored DB house listings into the dead `salePrice` var; every reader (fn_buyHouse/fn_houseMenu/fn_marketSellHouse/the "Locate Homes for Sale" action) keys off `AP_house_price` -> after any restart, persisted for-sale houses were invisible to the map AND un-buyable. `init.sqf` now restores the listing into `AP_house_price`.
- **By:** player035  ·  **Channel:** #loonybot-bug-reports  ·  **ref:** 100000000000000099/100000000000000100

list house's for sale at dmv does not mark any houses on map

---

### #183 · NEEDINFO · 2026-06-14T08:36Z
- **By:** player090  ·  **Channel:** #report  ·  **ref:** 100000000000000101/100000000000000102

> **LOW-PRI / likely engine limitation.** Invisible backpacks still cast a backpack SHADOW (the hidden proxy model). This is an Arma rendering artifact of zero-texture/invisible gear, not a script bug — a real fix needs a shadow-suppressed model (addon work) or disabling the item's shadow LOD. Cosmetic, tied to the invisible-bag (donor/cosmetic) item. Deferred.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000103> (`player090` · `100000000000000103`)
**Date / Time:** just now

**Description of event / rule broken:**
buying the invisible bags causes a shadow on your characters back

**Evidence:**
i bought the carryall backpack and myc harcacter has a dark shadow, just a visual glitch

---

### #184 · FIXED · 2026-06-14T08:58Z

> Fixed (staged). The invisible-bag flag (`profileNamespace AP_invisBag`) survives a reconnect, but `hideObjectGlobal` is a per-session OBJECT state lost when the unit/backpack is rebuilt on login -> the pack came back visible after every restart. `fn_requestReceived` now re-hides the worn backpack (post-loadGear, 2s settle) when `AP_invisBag` is set.
- **By:** player090  ·  **Channel:** #report  ·  **ref:** 100000000000000104/100000000000000105

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000103> (`player090` · `100000000000000103`)
**Date / Time:** just now

**Description of event / rule broken:**
invisable bags

**Evidence:**
they become visable after restart

---

### #185 · FIXED · 2026-06-14T09:00Z
- **By:** player090  ·  **Channel:** #report  ·  **ref:** 100000000000000106/100000000000000107

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000103> (`player090` · `100000000000000103`)
**Date / Time:** just now

**Description of event / rule broken:**
retsart happened

**Evidence:**
server restart happened, i had keys to a hemett, i can now unlock and lock the truck but cant access the inv

---

### #186 · FIXED · 2026-06-14T09:28Z

> Fixed (staged, server-side). `AP_vcap` (= base getVirtCap + mods[1] storage upgrade) is set by `fn_prepareVehicle` on a garage PULL, but a vehicle left OUT during a soft restart is rebuilt by `fn_restoreVehicles`, which never read the `mods` column -> the cap reverted to base (upgraded HEMTT box 1000 -> 100, couldn't store past 100). restoreVehicles now reads `mods` and re-derives `AP_vcap` + `AP_mods`.
- **By:** player035  ·  **Channel:** #report  ·  **ref:** 100000000000000108/100000000000000109

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000110> (`player035` · `100000000000000110`)
**Date / Time:** just now

**Description of event / rule broken:**
after a soft server restart hemtt box went from 1000 storage to 100 and unable to store anything past 100 storage

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000111/100000000000000112/Arma_3_14_06_2026_7_19_11_PM.png?ex=6a2fc5ce&is=6a2e744e&hm=2897b7ebc5d71e1eb8b93e68e3d0aa834d82bf36349fad9da31cd5f64d997fe0&

---

### #187 · FIXED · 2026-06-14T10:56Z

> Fixed (staged, server.cfg — needs a server restart). server.cfg had no voting config -> Arma default voting ON -> any player could `#vote kick` / `#vote admin` (admin-grant = rcon-equivalent exploit). Added `voteThreshold = 1.5` (a fraction >1 can never be reached, so NO vote ever passes) + `voteMissionPlayers = 999`.
- **By:** player090  ·  **Channel:** #report  ·  **ref:** 100000000000000113/100000000000000114

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000103> (`player090` · `100000000000000103`)
**Date / Time:** just now

**Description of event / rule broken:**
go to map then to players

**Evidence:**
u can vote kick and vote to admin

---

### #188 · FIXED · 2026-06-14T11:59Z
- **By:** player090  ·  **Channel:** #report  ·  **ref:** 100000000000000115/100000000000000116

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000103> (`player090` · `100000000000000103`)
**Date / Time:** just now

**Description of event / rule broken:**
everytime the "rrestart in ____ admin msg comes up"

**Evidence:**
everytime the admin restart msg pops up the server restarts, ive lost a hemett and a heli now

---

### #189 · FIXED · 2026-06-14T13:17Z
- **By:** player095  ·  **Channel:** #report  ·  **ref:** 100000000000000117/100000000000000118

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000119> (`player095` · `100000000000000119`)
**Date / Time:** just now

**Description of event / rule broken:**
police cars can be seen by civs on the map 🙂

> Fixed (staged). Source = `fn_trackMarkers` (the "Map" open handler), NOT group icons (those are off via setGroupIconsVisible[false,true]) or difficulty. Player markers there are side-gated correctly (cop<->cop, civ<->group/gang). The leak was the post-restart "Owned Vehicle" sweep (first 600s): it marked EVERY entry in `AP_vehicles` green with no side check, so a player who OWNS police vehicles (cop whitelist) saw their cop cars on the map while playing CIV. Now gated to the viewer's current side via `AP_side` ("cop"/"med"/"civ"; "" legacy kept). NB: if a pure civ with zero cop-owned vehicles still sees cop cars, it's a tracker-item case (deliberate) or needs a screenshot of the exact marker.

**Evidence:**
_none provided_

---

### #190 · FIXED · 2026-06-14T13:37Z
> triage 2026-07-04 (bugs-triage): was NEEDTEST, code-verified FIXED — server/AP_server/init.sqf:373; server/AP_server/core/DB/fn_restoreVehicles.sqf:191 · Periodic 8-min vehicle_mem snapshot loop exists and restore no longer wipes the table.
- **By:** player079  ·  **Channel:** #report  ·  **ref:** 100000000000000120/100000000000000121

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000122> (`player079` · `100000000000000122`)
**Date / Time:** in the morning

**Description of event / rule broken:**
server crash lost my run

> **NEEDTEST** (owner 2026-06-19, persistence cluster): added a PERIODIC vehicle save -- the server now snapshots vehicle_mem (positions + AP_vinv trunk cargo) every 8 min, and the boot restore no longer wipes the table. Previously the graceful save ran ONLY on the scheduled restart, so manual hard restarts (deploys, !srv hardr, raw restart_now=1) and crashes lost every spawned/left-out vehicle. Now they survive any ungraceful exit (lose <=8 min). NEEDS in-game verification across a restart.

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000123/100000000000000124/20260614084909_1.jpg?ex=6a30001b&is=6a2eae9b&hm=c14c5f0c9984b8943e4344c18106fc9090d957626e8d2ea62fb6250629ce4b36&

---

### #191 · FIXED · 2026-06-14T13:42Z

> Fixed (staged). The welcome-screen "Server Rules" text had a link LABELLED "forums" whose href was the Discord URL (no forums exist post-2026-06-11 cleanup) -> confused new players. Relabelled the link "Discord" to match its destination.
- **By:** player006  ·  **Channel:** #report  ·  **ref:** 100000000000000125/100000000000000126

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000127> (`player006` · `100000000000000127`)
**Date / Time:** just now

**Description of event / rule broken:**
really isnt much of a bug BUT i just loaded the server and the message on the screen the "forums" button doesnt work its not that big of a deal but new people might get confused

**Evidence:**
_none provided_

---

### #192 · FIXED · 2026-06-14T14:09Z
> triage 2026-07-04 (bugs-triage): was NEEDTEST, code-verified FIXED — server/AP_server/init.sqf:373 · The cited periodic vehicle_mem snapshot (uiSleep 480 loop calling DB_fnc_saveVehicles) is present in init.sqf:370-379 and the boot restore no longer wipes the t
- **By:** player030  ·  **Channel:** #report  ·  **ref:** 100000000000000128/100000000000000129

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000130> (`player030` · `100000000000000130`)
**Date / Time:** just now

**Description of event / rule broken:**
Was doing drug running missions and while running to the plane it disappeared and i got the notification " your plane was destroyed" and i lost the money

> **NEEDTEST** (owner 2026-06-19, persistence cluster): added a PERIODIC vehicle save -- the server now snapshots vehicle_mem (positions + AP_vinv trunk cargo) every 8 min, and the boot restore no longer wipes the table. Previously the graceful save ran ONLY on the scheduled restart, so manual hard restarts (deploys, !srv hardr, raw restart_now=1) and crashes lost every spawned/left-out vehicle. Now they survive any ungraceful exit (lose <=8 min). NEEDS in-game verification across a restart.

**Evidence:**
_none provided_

---

### #193 · FIXED · 2026-06-14T14:31Z

> Fixed (staged). `fn_initGang` `exitWith`'d before creating the gang-building map marker when the viewer WAS the building owner -> the gang leader/owner never saw their own gang HQ on the map (only other members did). Marker now created for the owner too.
- **By:** player004  ·  **Channel:** #ganghouses are not map  ·  **ref:** 100000000000000131/100000000000000131

ganghouses are not map — Ganghouses are not on map

---

### #194 · FIXED · 2026-06-14T14:37Z

> Fixed (staged). The jackpot accumulates server-side in `AP_configuration[8]` (publicVariabled per ticket by fn_addToLottery), but the display read `AP_lotteryVal`, which is NEVER assigned from it -> the shown jackpot never moved. `fn_lottoTix` now reads the live `AP_configuration[8]`.
- **By:** player004  ·  **Channel:** #Lottery  ·  **ref:** 100000000000000132/100000000000000132

Lottery — pretty sure i already sent this but just making sure it on here if you buy lottery ticket the price is not gonna up

---

### #195 · FIXED · 2026-06-14T15:00Z
- **By:** player030  ·  **Channel:** #report  ·  **ref:** 100000000000000133/100000000000000134

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000130> (`player030` · `100000000000000130`)
**Date / Time:** just now

**Description of event / rule broken:**
whenever the server was about to restart and gave the 1 hour msg, it immediately restarted

**Evidence:**
_none provided_

---

### #196 · FIXED · 2026-06-14T15:04Z
- **By:** player092  ·  **Channel:** #report  ·  **ref:** 100000000000000135/100000000000000136

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000137> (`player092` · `100000000000000137`)
**Date / Time:** just now

**Description of event / rule broken:**
The TT doesn't have their specific vehicals for chief like the hatchback sport exc i imagine the other ranks are having the same problems.

**Evidence:**
https://gyazo.com/5732d71a17e2e8400dcfece2b4417dc8

---

### #197 · FIXED · 2026-06-14T15:06Z

> Fixed (staged). A flat `_cash = 5000` (owner's 2026-06-13 dirty-money change) clobbered the duration + talent-39 (%) + Zaros-turf scaling computed just above -> every gas-station rob paid exactly 5k regardless of skill/time. Removed the override; payout scales again (still paid as dirty `bank_money`).
- **By:** player004  ·  **Channel:** #Gas Station robbery payout  ·  **ref:** 100000000000000138/100000000000000138

Gas Station robbery payout — Gas Station robbery payout are persistent on 5K no matter how much % you have

---

### #198 · FIXED · 2026-06-14T16:03Z

> Fixed (staged). TWO faults. (1) The ESC "LoonyBin Discord" button inherited `AP_RscButtonMenu` (type=16 shortcut button), but the engine `url` auto-open only fires on a plain CT_BUTTON (type=1) -> click did nothing. Rebased the class on `AP_SpawnRscButton` (type=1). (2) `fn_ga1ther` plays `playSound "ziptie"` x3 on gather completion but no `ziptie` CfgSounds class existed (the audio file `sounds\zip.ogg` was on disk all along) -> silent. Class added.
- **By:** player011  ·  **Channel:** #report  ·  **ref:** 100000000000000139/100000000000000140

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000141> (`player011` · `100000000000000141`)
**Date / Time:** just now

**Description of event / rule broken:**
discord link does not work when you press the esc button and the ziptie sound does not play out when you finish gathering

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000142/100000000000000143/20260614184330_1.jpg?ex=6a30225a&is=6a2ed0da&hm=aa2c1e37b94b896e721dcc129701dbbb77f27d736dcf78e04fc50170be74d093&
https://cdn.discordapp.com/attachments/100000000000000142/100000000000000144/20260614182612_1.jpg?ex=6a30225a&is=6a2ed0da&hm=4988ff6b5a0c17be334798d60ecc9febd64893fbcd8d0f8469be54f59f892c6f&

---

### #199 · FIXED · 2026-06-14T16:08Z
- **By:** player095  ·  **Channel:** #report  ·  **ref:** 100000000000000145/100000000000000146

> Fixed (staged, server-side — rides next reboot). "Vic" = the cartel-capture reward airdrop (`APS_fnc_airDrop`): a `B_supplyCrate_F` parachuted in on a finished capture. Drop pos was `getMarkerPos <cartel> -> BIS_fnc_findSafePos(min15)`, but findSafePos **falls back to the flag centre when it fails**, and the drug cartel is packed with bag-fences/H-barriers (`fn_spawnCaptures`) so the snap failed -> crate fell straight onto the capper standing on the flag. Now offsets a fixed **20m** off the flag (random bearing) FIRST, then safe-snaps a small 8m radius around that point -> always ~20m clear. Applies to all 4 cartels.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000119> (`player095` · `100000000000000119`)
**Date / Time:** just now

**Description of event / rule broken:**
Drug cartel flag spawns vic on you

**Evidence:**
https://medal.tv/games/arma-3/clips/mULdumQzPcUezPTE3?invite=cr-MSxtTk8sMjIxMTM2MDMw&v=22

---

### #200 · FIXED · 2026-06-14T16:21Z
- **By:** player095  ·  **Channel:** #report  ·  **ref:** 100000000000000147/100000000000000148

> Fixed (staged, server-side — rides next reboot). Same root cause as the illegal-trunk-filter removal this session. The old `fn_updateVehicle` garage-store path dropped illegal items from the trunk item list (`_legal = _items select {not illegal}`) but kept the ORIGINAL weight — so a tempest with 208 bluemeth (208×2 = 416 wt, all illegal) stored as `[[], ~419]`: empty list, phantom weight. On pull the trunk read ~419/1250 used while empty. TWO-part fix: (1) the illegal-item filter is already removed (items + weight now stay consistent on store); (2) `fn_vehicleSetActive` (garage-pull restore) now RE-DERIVES the trunk weight from the actual item list via `getItemWeight` before applying `AP_vinv`, so every legacy desynced row self-heals on its next pull (player095's tempest recomputes to weight 0 = empty). Harmless for correct rows (reproduces the same number). No manual DB repair needed.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000119> (`player095` · `100000000000000119`)
**Date / Time:** like 12h ago

**Description of event / rule broken:**
when i was doing heisenbug, my tempest despawned after the 3 processes with a full load of 208 heisen (dont need comp) but after i got the tempest back out my tempest was stuck at like 419/1250 space when the trunk was empty, like the heisen wasnt deleted fully.

**Evidence:**
_none provided_

---

### #201 · DUP · 2026-06-14T17:18Z
- **By:** player004  ·  **Channel:** #bug-reports  ·  **ref:** 100000000000000138/100000000000000138

> dup of #197 (STAGED) — gas-station payout flat-5k override removed; scales again next deploy.

Gas Station robbery payout — Gas Station robbery payout are persistent on 5K no matter how much % you have

---

### #202 · DUP · 2026-06-14T17:18Z
- **By:** player004  ·  **Channel:** #bug-reports  ·  **ref:** 100000000000000131/100000000000000131

> dup of #193 (STAGED) — gang-building map marker now created for the owner too.

ganghouses are not map — Ganghouses are not on map

---

### #203 · DUP · 2026-06-14T17:18Z
- **By:** player073  ·  **Channel:** #bug-reports  ·  **ref:** 100000000000000086/100000000000000086

> dup of #176 (STAGED) — cartel-cap broadcast now civ-only (MaxSec excluded).

MaxSec getting notifications about cartels being capped — https://images.steamusercontent.com/ugc/14958604304570289584/3E32939CC1E3171DAF300CF916FCE03CD236F693/?imw=5000&imh=50

---

### #204 · DUP · 2026-06-14T17:18Z
- **By:** player004  ·  **Channel:** #bug-reports  ·  **ref:** 100000000000000132/100000000000000132

> dup of #194 (STAGED) — lottery display now reads the live jackpot from AP_configuration[8].

Lottery — pretty sure i already sent this but just making sure it on here if you buy lottery ticket the price is not gonna up

---

### #205 · FIXED · 2026-06-14T18:51Z
- **By:** player095  ·  **Channel:** #report  ·  **ref:** 100000000000000149/100000000000000150

> Fixed (staged, server-side). ROOT CAUSE = TWO restart systems running at once. The new 4h ALWAYS-HARD scheduler (init.sqf) is the intended authority, but the LEGACY auto-soft-restart was never removed: `server_init.sqf:71` spawned `APS_fnc_rebootMonitor` (30-min "Server Maintenance" countdown -> `doRestart`/`endMission` = mission soft-reload) after `AP_restart_delay`. RPT proof: the 4h scheduler's "1 Hour until RESTART" fired at 13:50:01 and the rogue rebootMonitor soft-reloaded the mission 30s later (13:50:31) -> "gave the 1-hour msg then immediately restarted". Disabled the legacy auto-spawn (kept rebootMonitor for manual admin reboots); the 4h hard cycle is now the only restarter. (The earlier stale-flag/uptime-guard fix was real but covered a different premature path — this was the remaining cause.)

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000119> (`player095` · `100000000000000119`)
**Date / Time:** bug

**Description of event / rule broken:**
restart still broke and insta restarts 🙂

**Evidence:**
no

---

### #206 · FIXED · 2026-06-14T19:22Z

> Fixed (staged). Home-grown weed (greenhouse) yields `cannas_3`/`cannai_3` buds; the marijuana processor had the HAND "Process Bud into Golden Wax" actions, and `fn_processVehicle` already has the `cannas_3`/`cannai_3` -> `canna_dab` recipe, but there was no **"Process Vehicle: Golden Wax"** bulk action (same gap as #207). Added both Indica + Sativa vehicle-trunk golden-wax actions at the processor.
- **By:** player047  ·  **Channel:** #report  ·  **ref:** 100000000000000151/100000000000000152

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000066> (`player047` · `100000000000000066`)
**Date / Time:** just now

**Description of event / rule broken:**
no ability to double process home grown weed into golden wax

**Evidence:**
_none provided_

---

### #207 · FIXED · 2026-06-14T20:09Z

> Fixed (staged). The mineral processor (`fn_civProcessItem` case "mineral") had "Process Vehicle: Iron" + "Process Vehicle: Copper" but no diamond equivalent — only the hand "Process Diamond" — so a trunk of diamonds couldn't be bulk-processed. The `diamond` -> `diamondc` recipe already exists in `fn_processVehicle`; added the missing "Process Vehicle: Diamond" action.
- **By:** player047  ·  **Channel:** #report  ·  **ref:** 100000000000000153/100000000000000154

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000066> (`player047` · `100000000000000066`)
**Date / Time:** just now

**Description of event / rule broken:**
unable to process diamonds from vehicle, only ores are the option at the mineral pro

**Evidence:**
_none provided_

---

### #208 · FIXED · 2026-06-14T20:14Z

> Detail (owner): gang MEMBERS get no keys, no map marker, can't respawn there, can't pull vehicles at a gang building — for sheds AND gang houses.
> Fixed (staged). All four perks key off `AP_gangBuilding` + `AP_gang_data[3]`, set on the member's client by `fn_initGang` from the persisted `gangs.house_pos`. TWO bugs broke the load path:
> (1) **One-shot building-find ran too early.** `fn_initGang` did a single `nearestObjects[pos,["House_F"],10]`, but houses stream in ~20s after a restart, so it usually got `[]` -> `_building` objNull -> the whole gang-building setup was skipped and never retried. Hit houses AND sheds (the common cause). Now retries (waitUntil the building exists AND is tagged `AP_house_gang`, up to 90s).
> (2) **`["House_F"]` missed sheds.** An industrial shed (`Land_i_Shed_Ind_F`) is NOT `isKindOf "House_F"`, so neither `fn_initGang` nor the server boot re-tag (`init.sqf`) ever found/tagged a shed gang-HQ. Both now use a broad `Building`/`nearestBuilding` find filtered to the real house-type list. Once `AP_gangBuilding` is set, the existing keychain (keyUpHandler), spawn (`fn_spawnPointCfg`), marker, and gang-garage-pull paths all work for sheds (which ARE in `AP_houseTypes`). Live-set (leader sets HQ while members online) already worked via `setGangHouseForMembers`; this fixes the relog/restart/late-join path.
- **By:** player047  ·  **Channel:** #report  ·  **ref:** 100000000000000155/100000000000000156

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000066> (`player047` · `100000000000000066`)
**Date / Time:** just now

**Description of event / rule broken:**
gang sheds are not working currently

**Evidence:**
_none provided_

---

### #209 · FIXED · 2026-06-14T20:17Z

> Fixed (staged). The ESP-spectate KeyDown handler (`fn_spectateESP`) assigned `espHandlers = [_esp]` OUTSIDE the `if (isNil "espHandlers")` gate, but `_esp` is a `private` declared INSIDE it — so on every keypress after ESP turned on, that line ran with `_esp` undefined -> script error that aborted the rest of the handler -> the toggle keys AND the **F10 stop (code 68) silently stopped working** = "no way to stop spectating". Moved the assignment inside the gate so the stop/toggles run on every keypress. ALSO added a self-terminate guard at the top of the Draw3D ESP handler (removes itself via `_thisEventHandler` when spectate is off / suspect null / not admin) + set `suspectESP_on=false` on stop, so a spectate ended by any path (esp. self-spectate or relog) no longer leaves the ESP overlay drawing.
- **By:** player036  ·  **Channel:** #report  ·  **ref:** 100000000000000157/100000000000000158

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000092> (`player036` · `100000000000000092`)
**Date / Time:** just now

**Description of event / rule broken:**
no way to stop spectating ppl when you use either option in the admin menu and if you do the old trick where you just spectate yourself your esp and shit stays on

**Evidence:**
_none provided_

---

### #210 · FIXED · 2026-06-14T21:28Z

> Fixed (staged, server-side). APS_fnc_vehOwnerSwap (chop-shop claim) updated AP_dbInfo + AP_vehOwners but NOT the legacy `dbInfo` var, and fn_vehicleStore reads ownership from dbInfo select 0 -> after a claim it still saw the OLD owner -> 'doesn't belong to you / not claimed' at the garage. Now swaps the uid in dbInfo too.
- **By:** player095  ·  **Channel:** #report  ·  **ref:** 100000000000000159/100000000000000160

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000119> (`player095` · `100000000000000119`)
**Date / Time:** now

**Description of event / rule broken:**
I chopped a tempest, claimed it, and went to garage and it says not claimed

**Evidence:**
https://medal.tv/games/arma-3/clips/mULdumQzPcUezPTE3?invite=cr-MSxtTk8sMjIxMTM2MDMw&v=22

---

### #211 · FIXED · 2026-06-14T21:52Z

> Covered by the STAGED jet-radar config (cfgVehicles ActiveRadarSensorComponent active=0, ships in b0062) -- NOT deployed when this was reported. Verify in a jet after the next restart; if radar still scans, the sensor-class path needs adjusting.
- **By:** player095  ·  **Channel:** #report  ·  **ref:** 100000000000000161/100000000000000162

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000119> (`player095` · `100000000000000119`)
**Date / Time:** now

**Description of event / rule broken:**
Radar works on jets kinda broken

**Evidence:**
https://medal.tv/games/arma-3/clips/mUR95tulEj0wNDsGv?invite=cr-MSxGMUEsMjIxMTM2MDMw&v=52

---

### #212 · FIXED · 2026-06-14T22:28Z

> Fixed (staged). Grow-time ETA inflated (2h -> 5/6h) after a restart: nowUnix = AP_bootUnix + serverTime, and serverTime resets each restart so a stored plantedUnix could transiently end up AHEAD of nowUnix -> negative stage -> eta = mat - (negative) blew up. Clamped the elapsed `(_nowUnix - _pt) max 0` in the status display + harvest/ready checks (client + server) so age is never negative; plants mature as real time passes. (And yes -- they grow offline; no need to be online.)
- **By:** player006  ·  **Channel:** #report  ·  **ref:** 100000000000000163/100000000000000164

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000127> (`player006` · `100000000000000127`)
**Date / Time:** just now

**Description of event / rule broken:**
the green house id installed n my house, and earlier when i was putting the seeds in it said that they were going to take 2 hours and now they say 5 hours and 6 hours instead of 2 idk if there is a problem on my end or the server end also i dont have to be online do i for them to grow??

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000165/100000000000000166/image.png?ex=6a307c77&is=6a2f2af7&hm=b657ff7731ac12054d3e371540232538d15e1ac7d6e6420fb56e17699a963826&

---

### #213 · NOTABUG · 2026-06-14T22:40Z

> Not a bug -- player asking for help with the Discord link. Closed.
- **By:** player082  ·  **Channel:** #report  ·  **ref:** 100000000000000167/100000000000000168

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000169> (`player082` · `100000000000000169`)
**Date / Time:** just now

**Description of event / rule broken:**
just needed help figuring out the discord link

**Evidence:**
_none provided_

---

### #214 · FIXED · 2026-06-14T22:55Z

> Fixed (staged). Guns were already stripped on death (removeAllWeapons), but the corpse kept its BACKPACK + linked items (NVG/GPS) -> free-lootable = dupe. fn_onPlayerKilled now also `removeBackpackGlobal` + unlinks all assignedItems off the body. The death-gear snapshot (AP_dead_gear) is taken first, so revive/seize still restore the loadout.
- **By:** player036  ·  **Channel:** #report  ·  **ref:** 100000000000000170/100000000000000171

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000092> (`player036` · `100000000000000092`)
**Date / Time:** just now

**Description of event / rule broken:**
you can loot dead bodies. I tested with chase and you can take backpacks but not vests or guns and if you put stuff into the backpack before dying it shows as a normal empty back pack so it dupes backpacks and gear like nvg and gps but thats it

**Evidence:**
_none provided_

---

### #215 · NOTABUG · 2026-06-14T23:07Z

> Comp/lag request, not a code bug -- the lag is the WiFi-host networking issue (server upload over WiFi; moving to wired/LAN in progress). Owner decides on comp.
- **By:** player095  ·  **Channel:** #report  ·  **ref:** 100000000000000172/100000000000000173

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000119> (`player095` · `100000000000000119`)
**Date / Time:** now

**Description of event / rule broken:**
can i get comp for lag spike killing me....

**Evidence:**
https://medal.tv/games/arma-3/clips/mUSCtaYIkEsO8UUi2?invite=cr-MSxqeG4sMjIxMTM2MDMw&v=53

---

### #216 · FIXED · 2026-06-14T23:18Z

> Fixed (staged, server-side). Cartel weapon crate scattered up to 16m from the flag (into streets) and was openable by anyone. Now spawned tight (0-6m) and lockInventory true; the capture loop unlocks it ONLY while the cartel is capped (and fills it), re-locks + empties when not capped -> no 'unlocked crate in the street'; only a capped crate (which the holding gang defends) is lootable.
- **By:** player095  ·  **Channel:** #report  ·  **ref:** 100000000000000174/100000000000000175

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000119> (`player095` · `100000000000000119`)
**Date / Time:** now

**Description of event / rule broken:**
i found a cartel crate just in the street unlocked 🙂

**Evidence:**
https://medal.tv/games/arma-3/clips/mUSNrhSjtMadX0Tua?invite=cr-MSxTdUosMjIxMTM2MDMw&v=37

---

### #217 · FIXED · 2026-06-15T00:35Z

> dup of #221 (STAGED) -- cop lethal/non-lethal toggle read off the wrong object (objNull for on-foot cops) made every cop weapon 1-tap-down through armour. Fixed.
- **By:** player071  ·  **Channel:** #report  ·  **ref:** 100000000000000176/100000000000000177

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000178> (`player071` · `100000000000000178`)
**Date / Time:** all tazer 1 tap

**Description of event / rule broken:**
all tazer 1 tap

**Evidence:**
_none provided_

---

### #218 · FIXED · 2026-06-15T00:35Z

> dup of #221 (STAGED) -- cop lethal/non-lethal toggle read off the wrong object (objNull for on-foot cops) made every cop weapon 1-tap-down through armour. Fixed.
- **By:** player034  ·  **Channel:** #general  ·  **ref:** 100000000000000179/100000000000000180

tasers are 1 tap

---

### #219 · FIXED · 2026-06-15T01:16Z

> dup of #221 (STAGED) -- cop lethal/non-lethal toggle read off the wrong object (objNull for on-foot cops) made every cop weapon 1-tap-down through armour. Fixed.
- **By:** player039  ·  **Channel:** #report  ·  **ref:** 100000000000000181/100000000000000182

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000183> (`player039` · `100000000000000183`)
**Date / Time:** just now

**Description of event / rule broken:**
downing rounds one tap to any armour

**Evidence:**
_none provided_

---

### #220 · FIXED · 2026-06-15T01:19Z

> Fixed (staged). De-branded the Gendarmerie uniform -- removed the custom cop_gendarmerie_blue/grey/tan.jpg (Asylum logo baked in) from fn_clothing_cop (shop) + fn_clothingTextures (skin lookup); now uses the vanilla U_B_GEN_Soldier_F texture. No Asylum.

> Texture/art, not code-fixable. The Gendarmerie uniform skins (cop_gendarmerie_blue/grey/tan.jpg) have the Asylum logo baked into the JPG. Options: art-clean the JPGs, OR repoint the 3 gendarmerie entries to the vanilla U_B_GEN_Soldier_F (no custom texture = de-branded but loses the blue/grey/tan look). Say which.
- **By:** player039  ·  **Channel:** #report  ·  **ref:** 100000000000000184/100000000000000185

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000183> (`player039` · `100000000000000183`)
**Date / Time:** just now

**Description of event / rule broken:**
the gendarmerie still has the asylum logo on the uniform

**Evidence:**
https://gyazo.com/832c041ab50df53a14f123c5f994daf1

---

### #221 · FIXED · 2026-06-15T01:20Z

> Fixed (staged). Root of the whole 1-tap cluster (#217/#218/#219/#221). `fn_handleDamage` read the cop's lethal toggle as `(gunner _source) getVariable["AP_nonlethal", true]`, but for a cop ON FOOT `gunner _source` is objNull -> it ALWAYS returned the default `true`, so every cop weapon (lethal rifles included) was flagged non-lethal and the down-gate fired on any torso hit = instant 1-tap-down through any armour, and the "Load Lethal Rounds" toggle did nothing. Now reads the toggle off the actual shooter (`_source` on foot, `gunner _source` only for a vehicle turret). Lethal rounds kill normally (armour applies, no one-shot); only real non-lethal rounds down.
- **By:** player034  ·  **Channel:** #report  ·  **ref:** 100000000000000186/100000000000000187

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000188> (`player034` · `100000000000000188`)
**Date / Time:** just now

**Description of event / rule broken:**
PD guns are one shot when they shouldn’t be. Spar 16, a 556 has the ability to one shot armor level 5 and Grant-B stack. So far MX does as well. These guns normally do minimal damage for the first shot to a fresh plate. Sub 15. So far the only guns that were tested were the spar and the mx. More testing can be done if warranted

**Evidence:**
https://medal.tv/games/arma-3/clips/mUV1StOUm98eaWcsq?invite=cr-MSx0ZFIsMjE4NTM3MzA3&v=4

---

### #222 · FIXED · 2026-06-15T01:43Z

> Need the gyazo detail -- 'Asylum on NPCs' is likely a baked-in texture (asylumpluscsats.jpg / asylumplusbag.jpg subscriber skins, or the loonybinpartystreamer.paa giveaway icon). Which NPC/where exactly? Same art-pending class as #220 if it's a uniform skin.
- **By:** player039  ·  **Channel:** #report  ·  **ref:** 100000000000000189/100000000000000190

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000183> (`player039` · `100000000000000183`)
**Date / Time:** just now

**Description of event / rule broken:**
asylum on NPCs

**Evidence:**
https://gyazo.com/50c4ca6beb56ab491a19d95d1680dee5

---

### #223 · FIXED · 2026-06-15T02:00Z

> Fixed (staged). The HELD placeable object kept physics simulation ON (only setMass 0), so moving it collided with players/walls -> flung/killed them (massless-object glitch) + triggered its own handleDamage EH. fn_holdObject now enableSimulationGlobal false while carried (still tracks the player + can be shot).
- **By:** player039  ·  **Channel:** #report  ·  **ref:** 100000000000000191/100000000000000192

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000183> (`player039` · `100000000000000183`)
**Date / Time:** just now

**Description of event / rule broken:**
placeable objects can kill when holding around

**Evidence:**
https://medal.tv/games/arma-3/clips/mUVGLa8kJxE0gtEYp?invite=cr-MSxjNEQsMTU0MzQ2NTY&v=34

---

### #224 · FIXED · 2026-06-15T03:06Z

> Already implemented (live b0063). The drug dealer ("heroin" NPC) has BOTH hand/virtual wax processing (AP_fnc_processAction cannai_3/cannas_3, gated on having bud in virtual inv) AND vehicle wax processing. Reporter (on the old build / no virtual bud) only saw the vehicle option. Re-check on b0063; if a DIFFERENT dealer lacks it, tell me which.
- **By:** player047  ·  **Channel:** #report  ·  **ref:** 100000000000000193/100000000000000194

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000066> (`player047` · `100000000000000066`)
**Date / Time:** just now

**Description of event / rule broken:**
drug dealer has vehicle inventory wax but also needs virtual

**Evidence:**
_none provided_

---

### #225 · FIXED · 2026-06-15T03:22Z

> Fixed (staged). Standalone bipods could be put INTO house/vehicle storage but never pulled back out ("You cannot use this item!") -- an old anti-dupe block in fn_takeInventory. Removed; bipods now retrieve like any other item.
- **By:** player047  ·  **Channel:** #report  ·  **ref:** 100000000000000195/100000000000000196

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000066> (`player047` · `100000000000000066`)
**Date / Time:** just now

**Description of event / rule broken:**
if you store bipods in housing inventory they cannot be taken out

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000079/100000000000000197/20B41C1.JPG?ex=6a30c18a&is=6a2f700a&hm=9daee26d4ed5a64f92042829a3ef60a34052b0869898ebd24fdfad06a46fc2c0&

---

### #226 · FIXED · 2026-06-15T03:29Z

> Fixed (staged). Gold nuggets + flawless diamonds were near-unobtainable from the quarry (goldnugget 0.04%, flawless 1.2%). Bumped both 5x in fn_m1ne (goldnugget ->0.2%, flawless ->~6%, plus the 2nd flawless path). Other quarry yields unchanged.
- **By:** player047  ·  **Channel:** #report  ·  **ref:** 100000000000000198/100000000000000199

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000066> (`player047` · `100000000000000066`)
**Date / Time:** today

**Description of event / rule broken:**
did 14 inventories of high yield quarry mining, recieved 2 flawless diamonds and 0 golden nuggets from it. loot pool needs to be updated

**Evidence:**
player101

---

### #227 · FIXED · 2026-06-15T03:30Z

> Fixed (staged). Market collapsed to a fixed rate after ~5-10 min: the demand index hard-reverted to 0 once boot demand bled off, so price = base * static-region. Retuned APS_fnc_marketTick (weaker mean-revert + bigger random walk + more frequent events + faster tick) so prices wander the whole restart cycle; added a server-RPT heartbeat to confirm the loop stays alive.
- **By:** player047  ·  **Channel:** #report  ·  **ref:** 100000000000000200/100000000000000201

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000066> (`player047` · `100000000000000066`)
**Date / Time:** today

**Description of event / rule broken:**
fluctuating market does not persist for full restart. after ~ 5-10 mins uptime market goes back to a fixed rate

**Evidence:**
_none provided_

---

### #228 · NOTABUG · 2026-06-15T03:31Z

> By design. That shed isn't a purchasable house -- no scroll-to-buy is intended. Closing.
- **By:** player039  ·  **Channel:** #report  ·  **ref:** 100000000000000202/100000000000000203

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000183> (`player039` · `100000000000000183`)
**Date / Time:** just now

**Description of event / rule broken:**
i dont know if its even buyable but this shed has no scroll wheel to purchase

**Evidence:**
https://gyazo.com/7b1cc1b13db1d422a9174fad9c345bf9

---

### #229 · FIXED · 2026-06-15T03:36Z

> Fixed (staged). Vehicle + hand processing granted infamy on only a partial drug list -- golden wax (canna_dab) and regular weed (marijuana) were excluded, so "186 golden wax = 0 infamy". Both processors now grant infamy across the full drug-output set (weed/wax 0.2x, rest 0.4x, cap 15).
- **By:** player047  ·  **Channel:** #report  ·  **ref:** 100000000000000204/100000000000000205

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000066> (`player047` · `100000000000000066`)
**Date / Time:** now

**Description of event / rule broken:**
do not recieve infamy for vehicle processing drugs

**Evidence:**
just did is 186 golden wax 0 infamy gained

---

### #230 · NOTABUG · 2026-06-15T03:42Z
- **By:** player063  ·  **Channel:** #discord-link  ·  **ref:** 100000000000000206/100000000000000207

my ass

---

### #231 · FIXED · 2026-06-15T04:41Z

> Fixed (staged). A Qilin minigun hit reports _source as the VEHICLE, so fn_handleDamage's run-over/VDM branch misfired -> victim only got DOWNED + "the driver ran them over" instead of shot. Gated the VDM branch to actual collisions (_projectile == ""); vehicle-weapon hits now do normal lethal bullet damage.
- **By:** player042  ·  **Channel:** #report  ·  **ref:** 100000000000000208/100000000000000209

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000210> (`player042` · `100000000000000210`)
**Date / Time:** all time right now

**Description of event / rule broken:**
when shooting someone with quilin minigun it says the driver of the quilin ran them over and they only get downed

**Evidence:**
_none provided_

---

### #232 · FIXED · 2026-06-15T04:45Z

> Fixed (staged). Neither robbery charged the robber. FED: the alarm's charge call was broken (see #240) -> fixed to id 5 in fn_fedAlarm (charges ALL caught robbers; reverted a redundant openVault add to avoid double). PRISON: fn_doPrisonBreak never charged -> added "Prison Break" (id 14) at break start.
- **By:** player039  ·  **Channel:** #report  ·  **ref:** 100000000000000211/100000000000000212

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000183> (`player039` · `100000000000000183`)
**Date / Time:** just now

**Description of event / rule broken:**
fed and prison so far hasnt given charges for starting the robbery

**Evidence:**
_none provided_

---

### #233 · FIXED · 2026-06-15T04:59Z
- **By:** player039  ·  **Channel:** #report  ·  **ref:** 100000000000000213/100000000000000214

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000183> (`player039` · `100000000000000183`)
**Date / Time:** just now

**Description of event / rule broken:**
Loadouts not saving throughout restarts

> **FIXED** (owner 2026-06-19): resolved. Separate from the vehicle-persistence cluster (own `loadouts` table save path).

**Evidence:**
_none provided_

---

### #234 · NEEDINFO · 2026-06-15T05:38Z
- **By:** player092  ·  **Channel:** #no smoke weed everyday sound effect when smoking a joint  ·  **ref:** 100000000000000215/100000000000000215

> No description provided (player092). Needs a repro/description.

no smoke weed everyday sound effect when smoking a joint — no weed sound effect i need my fiX

---

### #235 · NEEDINFO · 2026-06-15T05:39Z

> Needinfo. Secondhand ("being told") report that drugs (meth/bluemeth, maybe others) stay in a car after they should be removed -- possible dupe. No repro/evidence. Awaiting: which drug, exact steps (process? sell? store?), and does the trunk count actually fail to drop.
- **By:** player036  ·  **Channel:** #report  ·  **ref:** 100000000000000216/100000000000000217

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000092> (`player036` · `100000000000000092`)
**Date / Time:** just now

**Description of event / rule broken:**
being told that drugs stay in cars like meth and the better version of it and possible for other drugs too

**Evidence:**
_none provided_

---

### #236 · FIXED · 2026-06-15T05:40Z

> Fixed (staged). REAL cause: a player on the death screen reads isPlayer=FALSE, so fn_cleanup's corpse reaper deleted the body at its 300s (5min) threshold -> player yanked off the 30-min death screen = "bled out after 5 min despite the timer set for 30". Raised the reaper threshold to 1860s (30min+buffer) to match the revive window; revivable corpses now survive the full 30 min. (AP_death_timer stays 30.)
- **By:** player036  ·  **Channel:** #report  ·  **ref:** 100000000000000218/100000000000000219

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000092> (`player036` · `100000000000000092`)
**Date / Time:** just now

**Description of event / rule broken:**
respawn timer says 30 minutes but reports say you respawn after 5 mins please investigate.

**Evidence:**
_none provided_

---

### #237 · FIXED · 2026-06-15T06:21Z

> Fixed (staged). The drug-cartel garage spawn marker sits on the flag POLE -> pulled cars spawned intersecting it/players -> physics desync that killed players. fn_spawnVehicle (personal) + fn_gangGaragePull (gang) now nudge the spawn to a flat spot >=3m off any object via findSafePos, for open MARKER garages only (house/boat spawns untouched). Dup of #243.
- **By:** player002  ·  **Channel:** #drug cartel vehicle garage  ·  **ref:** 100000000000000220/100000000000000220

drug cartel vehicle garage — pulling hatchback sport at drug cartel causes it to spawn too close to the pole. causes it to desync and kill players. Had to revive 1x player as a result.

---

### #238 · FIXED · 2026-06-15T09:57Z

> Fixed (owner: resolved by a soft restart). Greenhouse bud count was stuck at 61 / not updating; a soft restart cleared it.
- **By:** player003  ·  **Channel:** #report  ·  **ref:** 100000000000000221/100000000000000222

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000223> (`player003` · `100000000000000223`)
**Date / Time:** just now

**Description of event / rule broken:**
I have 3 house to are 3c i planted 300 plant ion one house 300 plants in another and 200 plants in another and i only got 61 bud from every house the number didnt change

**Evidence:**
_none provided_

---

### #239 · FIXED · 2026-06-15T11:10Z

> Fixed (staged). Vehicle-processing parks a car idle next to you for a long bulk run, but the idle-despawn timer garaged spawned vehicles after only 10min -> HEMTT despawned mid-process. Bumped fn_cleanup idle delay to 40min (spawned) / 60min (stored).
- **By:** player083  ·  **Channel:** #report  ·  **ref:** 100000000000000224/100000000000000225

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000226> (`player083` · `100000000000000226`)
**Date / Time:** just now

**Description of event / rule broken:**
my hemt despawned as i was processing the inventory

**Evidence:**
none but i can upload it if needed but u can check logs

---

### #240 · FIXED · 2026-06-15T15:37Z

> Fixed (staged). fn_fedAlarm charged nearby fed robbers via the LEGACY name-based call [_x,["Bank Robbery",10000],600] -- incompatible with the rewritten id-based wanted system, so the charge name wouldn't resolve -> "1 charge of Error". Now [5,_x] call APS_fnc_wantedAdd = "Federal Reserve Robbery". This is also the fed half of #232.
- **By:** player015  ·  **Channel:** #report  ·  **ref:** 100000000000000227/100000000000000228

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000229> (`player015` · `100000000000000229`)
**Date / Time:** 2026-06-13 Central Time  3:00 PM

**Description of event / rule broken:**
Fed charge comes up as an error https://gyazo.com/72e36c0413ec804486db93cc88cb1a00

**Evidence:**
https://gyazo.com/72e36c0413ec804486db93cc88cb1a00

---

### #241 · FIXED · 2026-06-15T15:41Z

> Fixed (staged). The post-restart "Owned Vehicle" map sweep (#189) gated to the viewer's side, so a COP saw their cop-side vehicle markers. Now marks civ/legacy vehicles only -- cop/med vehicles never get a map marker.
- **By:** player004  ·  **Channel:** #report  ·  **ref:** 100000000000000230/100000000000000231

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000232> (`player004` · `100000000000000232`)
**Date / Time:** we can see vehicle marker on the map on cop

**Description of event / rule broken:**
i was driving to ephedra and i have a screenshot of the marker

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000233/100000000000000234/20260615173756_1.jpg?ex=6a316e94&is=6a301d14&hm=17fcb497179891f0da616ef0a384f34586fe54b95a0e2318b1589d15af329c09&

---

### #242 · FIXED · 2026-06-15T15:52Z
- **By:** player004  ·  **Channel:** #report  ·  **ref:** 100000000000000235/100000000000000236

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000232> (`player004` · `100000000000000232`)
**Date / Time:** i was testing something and shot baymax and i could restrain him on cop hes a cop as wel

**Description of event / rule broken:**
shot him down him and restain him

> **Fixed (staged b0067):** both restrain paths (`fn_restrain`, `fn_restrainAction`) already blocked
> west-on-west, so the gap was the DOWN — the non-lethal stun gate in `fn_handleDamage` had no target-side
> check, so a cop could taze a fellow cop to the ground (then the zip-tie attempt). Added a cop-on-cop guard:
> when a west shooter hits a west target the rounds still do zero damage but the down-accumulator is skipped
> (no knockdown). Civ→cop tazing is unaffected.

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000233/100000000000000237/20260615175035_1.jpg?ex=6a317145&is=6a301fc5&hm=9e3aa4f24b63254814164e41778cf0f91cd89fcb223a30ae3cc2791332f47a2d&

---

### #243 · FIXED · 2026-06-15T16:10Z

> Fixed (staged). Dup of #237 -- cartel garage spawn point on the flag pole killed players on pull. Spawn now nudged off the pole to clear ground (fn_spawnVehicle + fn_gangGaragePull).
- **By:** player003  ·  **Channel:** #report  ·  **ref:** 100000000000000238/100000000000000239

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000223> (`player003` · `100000000000000223`)
**Date / Time:** just now

**Description of event / rule broken:**
i was at drug cartel after i capped it i went to the creat that was next to the pole it have a mk200 in it i tried to spawn my car to store the weapons in it the car spawned right on top of the flag and killed me

**Evidence:**
_none provided_

---

### #244 · FIXED · 2026-06-15T16:34Z

> Fixed (staged) same as #241 -- cop/med owned vehicles no longer markered on the map. NOTE: if this meant the blue cop-DOTS (cops seeing other cops), that's an intended MaxSec feature (fn_trackMarkers, gated to playerSide west) -- not changed; say if you want it removed.
- **By:** player047  ·  **Channel:** #report  ·  **ref:** 100000000000000240/100000000000000241

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000066> (`player047` · `100000000000000066`)
**Date / Time:** just now

**Description of event / rule broken:**
you can now see cops in ground vehicles on the map at any given time

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000079/100000000000000242/206B9D1.JPG?ex=6a317b21&is=6a3029a1&hm=d6a7f08f7bb4b018d56c232997c641c966d5ddbcddea2a9162ed691d0c57c4e0&

---

### #245 · FIXED · 2026-06-15T18:04Z

> Fixed (staged). Jail remaining time (AP_is_arrested[2]) was only refreshed at the 300s DB sync, so a restart landing before the first sync persisted the FULL original sentence -> prisoner re-served it all ("jail resets on restart"). Now the remaining is updated EVERY tick (graceful-flush captures the live value) + DB sync 300s->60s (bounds a crash loss to ~1 min).
- **By:** player004  ·  **Channel:** #report  ·  **ref:** 100000000000000243/100000000000000244

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000232> (`player004` · `100000000000000232`)
**Date / Time:** server restarted and my time on prison with back on 25 after being on 16 min need testing

**Description of event / rule broken:**
with to prison and server restarted

**Evidence:**
_none provided_

---

### #246 · FIXED · 2026-06-15T18:14Z

> Fixed (staged). CfgSounds had `class unlock` but NO `class lock` -> locking house doors threw "Lock sound not found" + only the unlock sfx played. Added `class lock` (sounds\lock.ogg already shipped).
- **By:** player027  ·  **Channel:** #report  ·  **ref:** 100000000000000245/100000000000000246

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000247> (`player027` · `100000000000000247`)
**Date / Time:** just now

**Description of event / rule broken:**
Locking all house doors sometimes displays a pop up that says "Lock sound not found", and it never plays the lock sound, only unlock

**Evidence:**
_none provided_

---

### #247 · FIXED · 2026-06-15T20:20Z

> Fixed (staged). The cartel-capture airdrop (fn_airDrop) searched for a cartel marker within 300m of a RANDOM online gang member; if that member (often the leader) had walked off, it fell back to getPosATL _member -> crate parachuted onto the leader "wherever he is on the map". Now resolves the capped cartel deterministically from the flag's AP_capData gang match and drops THERE.
- **By:** player017  ·  **Channel:** #report  ·  **ref:** 100000000000000248/100000000000000249

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000250> (`player017` · `100000000000000250`)
**Date / Time:** JUST NOW

**Description of event / rule broken:**
when you cap cartels the crate spawns on the gang leader where ever he is in the map

**Evidence:**
_none provided_

---

### #248 · FIXED · 2026-06-15T20:37Z

> Fixed (staged). Greenhouse grow timer used raw unix timestamps (~1.75e9) in SQF SINGLE-PRECISION floats -> ULP ~128 swallowed the per-second serverTime increments + str save/load lost precision -> plants "stuck". Now subtract a fixed epoch (AP_bootUnix -= 1.7e9) so values are ~5e7 (ULP ~4s) -> hour growth + DB round-trip exact. Also tidied the status text. (Old crops reset to Seed once -- acceptable.)
- **By:** player006  ·  **Channel:** #report  ·  **ref:** 100000000000000251/100000000000000252

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000127> (`player006` · `100000000000000127`)
**Date / Time:** just now/few hours

**Description of event / rule broken:**
so i think there might be something wrong with these greenhouses (again) my seeds were at the hour ish mark around a hour and a half ish ago but they are still at an hour (i havent been in the server, i left to go join rocket league and 5m but both got boring so i came back and they still havent moved)

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000165/100000000000000253/image.png?ex=6a31b3ef&is=6a30626f&hm=16573a161035a447f1a319f20f8f671317fdb8644c9d466f48399a1f23761bf9&

---

### #249 · FIXED · 2026-06-15T20:38Z

> Fixed (staged). AP_unitCopLevel/AP_unitCopRole/AP_showrank are set only in fn_initCop at the INITIAL spawn; a respawn is a NEW unit object that lost them -> fn_playerTags read AP_unitCopLevel default 0 -> no rank/police icon = cop looked undercover. fn_onPlayerRespawn now re-applies them (west only) from the persistent client vars; SCD/'all' stay undercover by design.
- **By:** player007  ·  **Channel:** #sergeant  ·  **ref:** 100000000000000254/100000000000000255

cadets get undercover when they come back to life

---

### #250 · FIXED · 2026-06-15T22:56Z

> Fixed (staged). AP_fnc_createDialog CLOSED an already-open display of the same idd when re-triggered -> a double-fired open flashed the shop open then shut ("spam sometimes works" = race). Now re-shows instead of closing. Fixes all cop shops.
- **By:** player014  ·  **Channel:** #report  ·  **ref:** 100000000000000256/100000000000000257

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000258> (`player014` · `100000000000000258`)
**Date / Time:** Now, 18:55 EST 15-JUN-2026

**Description of event / rule broken:**
Cop Weapon Shop at Air HQ does not load correctly. Flashes open on button press, then immediately closes.

**Evidence:**
_none provided_

---

### #251 · FIXED · 2026-06-15T22:59Z

> Fixed (staged). DUP of #237/#243 -- cartel garage spawn point on the flag pole killed players on pull. Spawn now nudged off the pole to clear ground (fn_spawnVehicle + fn_gangGaragePull findSafePos).
- **By:** player002  ·  **Channel:** #bug-reports  ·  **ref:** 100000000000000220/100000000000000220

drug cartel vehicle garage — pulling hatchback sport at drug cartel causes it to spawn too close to the pole. causes it to desync and kill players. Had to revive 1x player as a result.

---

### #252 · FIXED · 2026-06-15T22:59Z

> Resolved (staged, owner spec). Gang bank stays its OWN scroll-wheel action ("Gang Account" on gas/shops/vehicle NPCs) -- it was never on the main ATM. Gated to TOP gang ranks only: rank 1 (leader), 2, 3 -- regular members get "Only your gang's top ranks can access the gang bank." One check in fn_gangAtmMenu (AP_gang_data[2] in [1,2,3]).
- **By:** player002  ·  **Channel:** #bug-reports  ·  **ref:** 100000000000000259/100000000000000259

gang bank not working. doesnt show up on atm — Unable to see funds, or withdraw, depsoit etc

---

### #253 · NOTABUG · 2026-06-15T23:06Z

> Not a bug (owner): earplugs are already implemented. Player skill issue / didn't find the keybind. Closing.
- **By:** .8.0000  ·  **Channel:** #report  ·  **ref:** 100000000000000260/100000000000000261

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000262> (`.8.0000` · `100000000000000262`)
**Date / Time:** Right now

**Description of event / rule broken:**
Add in ear plugs

**Evidence:**
Nah

---

### #254 · FIXED · 2026-06-15T23:22Z
- **By:** player002  ·  **Channel:** #bug-reports  ·  **ref:** 100000000000000220/100000000000000220

drug cartel vehicle garage — pulling hatchback sport at drug cartel causes it to spawn too close to the pole. causes it to desync and kill players. Had to revive 1x player as a result.

---

### #255 · FIXED · 2026-06-15T23:22Z
- **By:** player002  ·  **Channel:** #bug-reports  ·  **ref:** 100000000000000259/100000000000000259

gang bank not working. doesnt show up on atm — Unable to see funds, or withdraw, depsoit etc

---

### #256 · FIXED · 2026-06-15T23:30Z
- **By:** player014  ·  **Channel:** #report  ·  **ref:** 100000000000000263/100000000000000264

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000258> (`player014` · `100000000000000258`)
**Date / Time:** Now

**Description of event / rule broken:**
Search menu from cop side when searching a civ stays open for approximately 60 seconds

> **Fixed (staged b0067):** not a menu — it's the search-result readout (`fn_copSearch`) shown as a `basic`
> handleMessage. `fn_handleMessage` sets a `basic` message's on-screen time = `(len(str text) - 256)/4` seconds,
> and that length counts every HTML tag in the big contraband block -> ~60s. Capped `basic` duration at 20s.

**Evidence:**
_none provided_

---

### #257 · FIXED · 2026-06-15T23:31Z
- **By:** player014  ·  **Channel:** #report  ·  **ref:** 100000000000000265/100000000000000266

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000258> (`player014` · `100000000000000258`)
**Date / Time:** Now

**Description of event / rule broken:**
Invisible backpack on cop still reverts to a black visible backpack after being revived. For reference, tested with the invisible Carryall

> **Fixed (staged b0067):** see #263 — same root. `fn_copLoadout` hard-set the backpack skin index to `-1` on
> every gear-up, and a revive re-gears, so the saved invisible-Carryall skin was wiped and setBackpack painted
> nothing. copLoadout now preserves + re-applies the saved `AP_clothingSkinsCop` backpack index.

**Evidence:**
_none provided_

---

### #258 · FIXED · 2026-06-15T23:38Z
- **By:** player014  ·  **Channel:** #report  ·  **ref:** 100000000000000267/100000000000000268

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000258> (`player014` · `100000000000000258`)
**Date / Time:** Now

**Description of event / rule broken:**
Police NPCs/Shops still have an Asylum uniform on

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000269/100000000000000270/20260615193321_1.jpg?ex=6a31de75&is=6a308cf5&hm=0a5ecafd89b17439a9f816b183b1c8d80be84e87a879243ad9e12c7b3de34999&

---

### #259 · FIXED · 2026-06-15T23:48Z
- **By:** player028  ·  **Channel:** #report  ·  **ref:** 100000000000000271/100000000000000272

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000273> (`player028` · `100000000000000273`)
**Date / Time:** just now

**Description of event / rule broken:**
not letting me access the weapon shops in pd shops

**Evidence:**
https://medal.tv/games/arma-3/clips/mViTcETUGBcAryJB1?invite=cr-MSx5cUYsMzIwNDkzMzE&v=7

> **Addressed (staged b0067):** this is the dialog-open race — the action double-fires (scroll wheel), the 2nd
> `createDialog` saw the just-opened display and CLOSED it ("flashes open then closes; spamming sometimes
> works"). Fix already in `fn_createDialog.sqf` (re-SHOW the existing display instead of closing it) — generic,
> covers PD weapon/equipment shops. Rides the next reboot. (Rebel-shop #272 was a separate root — the `exitWith`.)

---

### #260 · FIXED · 2026-06-15T23:49Z
> triage 2026-07-04 (bugs-triage): was NEEDTEST, code-verified FIXED — server/AP_server/core/system/fn_playerDisconnected.sqf:43 · A dead/downed civilian disconnect now writes an empty position (mode 10, []) so reconnect opens the spawn-select menu instead of respawning alive at the corpse 
- **By:** player006  ·  **Channel:** #report  ·  **ref:** 100000000000000274/100000000000000275

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000127> (`player006` · `100000000000000127`)
**Date / Time:** just now

**Description of event / rule broken:**
so i  went to suicide and then close the game so that i could go play another game and when i got back on that i would be abler to chose where i wanted to spawn like i did on asylum but when i did so it basically made me alive again as you can see in the video (no gear or anything thats why i bought a outfit and items to see if i would get them back) but i came back into the server alive and without any of my gear idk if you guys did that on purpous? but figured i would show my findings i dont want my reports to seem continues and annoy yall ❤️

**Evidence:**
First video is the gear and alt f4 and the second is me returning back into the server
https://medal.tv/games/arma-3/clips/mViMKzmnwVRmhUubi?invite=cr-MSw3NWssNDI5MjIwNTM1
https://medal.tv/games/arma-3/clips/mViLUlakCP4Q5jWY8?invite=cr-MSx2OW0sNDI5MjIwNTM1

> **NEEDTEST** (owner 2026-06-19): intended behaviour = die + disconnect -> reconnect to the city spawn-selection screen. Root cause: `fn_playerDisconnected` saved the exact position **only if alive**, but never CLEARED it when dead, so the stale pre-death position stayed in the DB and `queryRequest` respawned the player alive there (naked, since death stripped gear). Fix: on a DEAD disconnect, write an empty position so the reconnect opens the spawn menu. NEEDS testing: suicide -> alt-F4 -> rejoin -> should land on the spawn screen.

---

### #261 · INVALID · 2026-06-16T00:50Z
- **By:** player067  ·  **Channel:** #report  ·  **ref:** 100000000000000276/100000000000000277

> Non-report ('67diddyyblud' / '67') — junk/troll entry, no bug.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000278> (`player067` · `100000000000000278`)
**Date / Time:** 67diddy

**Description of event / rule broken:**
67diddyyblud

**Evidence:**
67

---

### #262 · FIXED · 2026-06-16T02:14Z
- **By:** player002  ·  **Channel:** #report  ·  **ref:** 100000000000000279/100000000000000280

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000281> (`player002` · `100000000000000281`)
**Date / Time:** Just now

**Description of event / rule broken:**
When on cop or medic it notifies on screen with pop up that cartels are being capped

**Evidence:**
Black

> **Fixed (staged b0067):** the popup is the gang fortress / gang boat "Ready For Capture!" alert (a gang/civ
> event the reporter called a "cartel"). `fn_gangFortressSRV.sqf` remoteExecs `AP_fnc_initGangFortClient`/
> `...BoatClient` to `-2` (EVERY client) with no side check, so cops + medics ran it and got the notification +
> sound + capture marker. Added a `playerSide isEqualTo civilian` gate at the top of both client fns (same
> west/independent exclusion the cartel event already got in #176). The actual 4 cartels + cartel-event were
> already civ-only.

---

### #263 · FIXED · 2026-06-16T03:05Z
- **By:** player039  ·  **Channel:** #report  ·  **ref:** 100000000000000282/100000000000000283

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000183> (`player039` · `100000000000000183`)
**Date / Time:** just now

**Description of event / rule broken:**
my invisible backpack is no longer invis after restart

> **Fixed (staged b0067):** the custom backpack skin (`AP_uniformBackpack_skins[1]`) persists in
> profileNamespace and is reloaded on login (`fn_requestReceived`), but the spawn path only re-painted the
> UNIFORM skin and `fn_copLoadout` then overwrote the backpack index with `-1`. Now: copLoadout preserves the
> saved backpack skin index (instead of `-1`), and cop+medic spawn (`fn_initCop`/`fn_initMedic`) re-apply
> `setBackpack` alongside `setUniform`. (Civ backpacks weren't reported; flag if they also revert.)

**Evidence:**
_none provided_

---

### #264 · FIXED · 2026-06-16T03:06Z
- **By:** player036  ·  **Channel:** #report  ·  **ref:** 100000000000000284/100000000000000285

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000092> (`player036` · `100000000000000092`)
**Date / Time:** just now

**Description of event / rule broken:**
if you are just outside of the gather zone with a tempest device and you start using it to gether it bugs you the hell out where you cant interact with anything

> **Fixed (staged b0067):** `fn_deviceMine.sqf` matches the resource zone within 290m but each field has a
> tighter gather radius (50/150m). Standing between the two, the script hit `if (dist > _distance) exitWith {}`
> which — unlike every other early-exit — never reset `AP_action_in_use` (set TRUE at the top). A stuck
> action-lock blocks all interaction = "bugged to shit." Now that exit clears the lock and tells the player.

**Evidence:**
im the proof im bugged to shit

---

### #265 · FIXED · 2026-06-16T04:02Z
- **By:** player036  ·  **Channel:** #report  ·  **ref:** 100000000000000286/100000000000000287

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000092> (`player036` · `100000000000000092`)
**Date / Time:** just now

**Description of event / rule broken:**
i was doing a weed run last night for for some reason interacting with the kavala drug dealer was causing my fps to shit the bed

**Evidence:**
_none provided_

---

### #266 · FIXED · 2026-06-16T04:11Z
- **By:** player019  ·  **Channel:** #report  ·  **ref:** 100000000000000288/100000000000000289
- **Fix (staged b0070):** the gang-bank gate correctly allows ranks 1/2/3 (`fn_gangAtmMenu`), but `APS_fnc_updateGangMem` persisted a rank change to the DB ONLY — it never updated the member's live `AP_gang_data[2]`. So a member promoted to rank 2 kept their old rank in memory until a relog, and the bank kept rejecting them. `updateGangMem` now pushes the new rank to the online member via the CfgRE-whitelisted `AP_fnc_gangRanks` (sets `AP_gang_data[2]` + the `gang_data` var) for online rank changes → takes effect instantly, no relog. Also fixes other rank-gated actions (set gang house, garage, etc.).

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000083> (`player019` · `100000000000000083`)
**Date / Time:** Just now

**Description of event / rule broken:**
Gang rank 2 cannot access the gang bank

**Evidence:**
_none provided_

---

### #267 · FIXED · 2026-06-16T04:45Z
- **By:** player019  ·  **Channel:** #report  ·  **ref:** 100000000000000290/100000000000000291

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000083> (`player019` · `100000000000000083`)
**Date / Time:** just now

**Description of event / rule broken:**
Not sure if this is a bug but MK200 Tracer mags are only $100 while the non tracers are $2500

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000292/100000000000000293/Screenshot_20260616_004450.png?ex=6a322683&is=6a30d503&hm=8980b6b7f3bf8b4e162f90c21cc9bc91f98518a820f323161ad618792465dfd7&

---

### #268 · DEFERRED · 2026-06-16T04:55Z
- **By:** player036  ·  **Channel:** #report  ·  **ref:** 100000000000000294/100000000000000295

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000092> (`player036` · `100000000000000092`)
**Date / Time:** just now

**Description of event / rule broken:**
if you are spectating someone who disconnects you get broken as if you are the dead body that is the only view you have and you cant open anything even phone

**Evidence:**
_none provided_

---

### #269 · WONTFIX · 2026-06-16T05:06Z
- **By:** player036  ·  **Channel:** #report  ·  **ref:** 100000000000000296/100000000000000297

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000092> (`player036` · `100000000000000092`)
**Date / Time:** just now

**Description of event / rule broken:**
ppl can draw on the map

> **WONTFIX** (owner 2026-06-19): map drawing stays. Arma 3 has no clean way to disable freehand map drawing without a hacky per-frame clear / custom mod — not worth it.

**Evidence:**
_none provided_

---

### #270 · FIXED · 2026-06-16T05:25Z
> triage 2026-07-04 (bugs-triage): was NEEDTEST, code-verified FIXED — mission/LooneyBin.Altis/evh/fn_handleDamage.sqf:175 · Hits-to-down scales with target protection and adds vehicle armor to the required hits (fn_handleDamage.sqf:175-178, cited to #270 at line 99) so an armored Ifr
- **By:** player042  ·  **Channel:** #report  ·  **ref:** 100000000000000298/100000000000000299

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000210> (`player042` · `100000000000000210`)
**Date / Time:** all time

**Description of event / rule broken:**
Downing rounds ignor iffrit armor/ glass , got downed by first bullet on a perfect frit

**Evidence:**
_none provided_

---

### #271 · FIXED · 2026-06-16T05:37Z
- **By:** player036  ·  **Channel:** #report  ·  **ref:** 100000000000000300/100000000000000301

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000092> (`player036` · `100000000000000092`)
**Date / Time:** just now

**Description of event / rule broken:**
crates you get from cartels despawn loot after a few seconds

**Evidence:**
nonr

> **Fixed (staged b0067):** regression from the #276 anti-dupe lock. `fn_airDrop.sqf` did
> `_crate enableSimulationGlobal false;` on landing, but a NON-SIMULATED supply crate stops streaming its cargo
> in MP -> loot "despawns after a few seconds." Now the crate stays SIMULATED (loot works) and is instead
> anchored to a hidden static helper (`Land_Can_V3_F`, hideObject+noSim) via `attachTo` — an attached object
> can't be slingloaded OR vehicle-in-vehicle loaded, so #276's intent holds without killing the loot. Anchor
> is cleanup-exempt and deleted with the crate at the 20-min despawn.

---

### #272 · FIXED · 2026-06-16T05:40Z
- **By:** player042  ·  **Channel:** #report  ·  **ref:** 100000000000000302/100000000000000303

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000210> (`player042` · `100000000000000210`)
**Date / Time:** all time

**Description of event / rule broken:**
Trying to acess weapon shop at rebel unknown if its all shops it opens then closes for like 20 times

**Evidence:**
https://medal.tv/games/arma-3/clips/mVp9ZphDHLV2E9rhW?invite=cr-MSxTdEYsMzk4NzUyOA&v=14

> **Fixed (staged b0067):** root = `fn_weaponShopMenu.sqf` `if (_flagGangID isEqualTo 0) exitWith {};`. That
> `exitWith` exits the WHOLE shop function (not just the arms-cartel block) whenever no gang owns the arms
> cartel flag — the normal state. The dialog was already created one line earlier, so it opened and then the
> script bailed before populating/holding it → "opens then closes." Restructured to only apply the cartel bonus
> when a gang owns the flag and otherwise keep the shop running (`AP_armsCartel` defaulted to `[false,0,-1]`).

---

### #273 · NEEDINFO · 2026-06-16T06:27Z
- **By:** player095  ·  **Channel:** #report  ·  **ref:** 100000000000000304/100000000000000305

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000119> (`player095` · `100000000000000119`)
**Date / Time:** now

**Description of event / rule broken:**
i have title i didnt do

> **NEEDINFO** (owner 2026-06-19): which title specifically? Each unlock is gated on its own stat threshold (`APV_statTotals`), so I need the exact title name to find the wrong condition/stat-index.

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000306/100000000000000307/image.png?ex=6a323e46&is=6a30ecc6&hm=6838df8f3f9575869c785cb2445b4ecf98606ac5a22d111bb13593184d7f3ddf&

---

### #274 · FIXED · 2026-06-16T06:48Z
> triage 2026-07-04 (bugs-triage): was NEEDTEST, code-verified FIXED — server/AP_server/init.sqf:373 · The 8-min periodic DB_fnc_saveVehicles loop (init.sqf:373-375) plus fn_restoreVehicles.sqf:191 no-longer-wipes vehicle_mem persist spawned vehicles across ungra
- **By:** player095  ·  **Channel:** #report  ·  **ref:** 100000000000000308/100000000000000309

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000119> (`player095` · `100000000000000119`)
**Date / Time:** now

**Description of event / rule broken:**
had 2 tempest full of coke at processor they are gone after restart

> **NEEDTEST** (owner 2026-06-19, persistence cluster): added a PERIODIC vehicle save -- the server now snapshots vehicle_mem (positions + AP_vinv trunk cargo) every 8 min, and the boot restore no longer wipes the table. Previously the graceful save ran ONLY on the scheduled restart, so manual hard restarts (deploys, !srv hardr, raw restart_now=1) and crashes lost every spawned/left-out vehicle. Now they survive any ungraceful exit (lose <=8 min). NEEDS in-game verification across a restart.

**Evidence:**
clip uploading

---

### #275 · FIXED · 2026-06-16T07:14Z
- **By:** player042  ·  **Channel:** #report  ·  **ref:** 100000000000000310/100000000000000311

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000210> (`player042` · `100000000000000210`)
**Date / Time:** map

**Description of event / rule broken:**
no actual oil cartel to cap

**Evidence:**
_none provided_

---

### #276 · FIXED · 2026-06-16T07:34Z
- **By:** player042  ·  **Channel:** #report  ·  **ref:** 100000000000000312/100000000000000313
- **Fix (staged b0070):** cap-loot dupe. The static cartel capture crate (`init.sqf` capture_container) could be slingload-hooked (or pushed) off the flag; capping then filled a fresh crate too, so the moved one + the new one BOTH carried the cap loot. Added `enableRopeAttach false` (kills the slingload — same fix the airdrop crate already got) + a 5s snap-home watcher (returns it if dragged >10m). Capture loop only fills via the `gangContainer` var, never repositions, so no conflict.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000210> (`player042` · `100000000000000210`)
**Date / Time:** cartels

**Description of event / rule broken:**
you can hook or move the crate away and when you capture the point both of them give the loot that you get from capping

**Evidence:**
_none provided_

---

### #277 · FIXED · 2026-06-16T08:07Z
- **By:** player051  ·  **Channel:** #report  ·  **ref:** 100000000000000314/100000000000000315

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000074> (`player051` · `100000000000000074`)
**Date / Time:** just now

**Description of event / rule broken:**
house weed timer isnt working on my end still after patch

**Evidence:**
_none provided_

---

### #278 · FIXED · 2026-06-16T11:11Z
- **By:** player090  ·  **Channel:** #report  ·  **ref:** 100000000000000316/100000000000000317

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000103> (`player090` · `100000000000000103`)
**Date / Time:** just now

**Description of event / rule broken:**
growing weed in yoru house is broke after the most recent change, doesnt grow or process at all in the house

**Evidence:**
_none provided_

---

### #279 · FIXED · 2026-06-16T11:46Z
- **By:** player006  ·  **Channel:** #report  ·  **ref:** 100000000000000318/100000000000000319

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000127> (`player006` · `100000000000000127`)
**Date / Time:** just now/overnight

**Description of event / rule broken:**
same issue with these seeds. am i the only one having the problem?

**Evidence:**
i planted them at like 11pm est last night
https://cdn.discordapp.com/attachments/100000000000000165/100000000000000320/image.png?ex=6a32892e&is=6a3137ae&hm=21b5651dd27155fb86e46ef5ed3623eb1eaefa383dce1e955bd37da4ebd79c7a&

---

### #280 · FIXED · 2026-06-16T13:39Z
> fixed 2026-06-21: the spirit-distillery building (house 916020794 @ [9160,20793]) is a PROCESSING building, not a livable home. Prior buyer ebola refunded $1,000,000 + evicted (house row deleted); fn_buyHouse now blocks any purchase within 40m of the spirit_distillery_area marker (staged, ships next deploy). #280 = dup.
- **By:** player047  ·  **Channel:** #report  ·  **ref:** 100000000000000321/100000000000000322

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000066> (`player047` · `100000000000000066`)
**Date / Time:** just now

**Description of event / rule broken:**
i bought the actual spirit distillery house

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000079/100000000000000323/2027981.JPG?ex=6a32a38c&is=6a31520c&hm=87c125963e510b3a102c6f956fc6131aa3fe4932f65ba09941f5711e50d94b5e&

---

### #281 · FIXED · 2026-06-16T13:51Z
- **By:** player066  ·  **Channel:** #BOUNTY HUNTER.  ·  **ref:** 100000000000000324/100000000000000324

BOUNTY HUNTER. — .45 ACP ROUNDS DO NOT DOWN AND 5.56 RUBBER ROUNDS DO NOT DOWN EITHER

---

### #282 · FIXED · 2026-06-16T13:53Z
- **By:** player055  ·  **Channel:** #report  ·  **ref:** 100000000000000325/100000000000000326

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000327> (`player055` · `100000000000000327`)
**Date / Time:** Just now

**Description of event / rule broken:**
CarteL, SPECIFICALLY Drug Cartel are church cannot be capped

**Evidence:**
none but im sure it can be replicated

---

### #283 · FIXED · 2026-06-16T17:09Z
> fixed: marked fixed per owner 2026-06-21 (owner-dispositioned).
- **By:** player083  ·  **Channel:** #report  ·  **ref:** 100000000000000328/100000000000000329

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000226> (`player083` · `100000000000000226`)
**Date / Time:** now

**Description of event / rule broken:**
i think gang funds are kinda glitched

**Evidence:**
I held arms and i was on discord watching player099 share he bought ifrit couple load outs and stuff grenades etc and at the end of the day when i check funds i had only like 10k extra and i feel thats like too little to be accurate or maybe im wrong just wanted to bring this one up

---

### #284 · FIXED · 2026-06-16T17:22Z
- **By:** player018  ·  **Channel:** #report  ·  **ref:** 100000000000000330/100000000000000331

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000332> (`player018` · `100000000000000332`)
**Date / Time:** now

**Description of event / rule broken:**
Customs licenses plates dont work ( I paid for my Payton custom plate and didnt apply it twice )

**Evidence:**
Customs licenses plates dont work ( I paid for my Payton custom plate and didnt apply it twice )

---

### #285 · FIXED · 2026-06-16T19:24Z
- **By:** player039  ·  **Channel:** #report  ·  **ref:** 100000000000000333/100000000000000334

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000183> (`player039` · `100000000000000183`)
**Date / Time:** just now

**Description of event / rule broken:**
cartel crate doesnt let me take anything out

**Evidence:**
https://medal.tv/games/arma-3/clips/mVDsrMOP8XQi1P9am?invite=cr-MSxxZ1AsMTU0MzQ2NTY&v=12

---

### #286 · FIXED · 2026-06-16T19:28Z
- **By:** player039  ·  **Channel:** #report  ·  **ref:** 100000000000000335/100000000000000336

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000183> (`player039` · `100000000000000183`)
**Date / Time:** just now

**Description of event / rule broken:**
oil cartel not gaining rubber

**Evidence:**
_none provided_

---

### #287 · NOTABUG · 2026-06-16T19:36Z
- **By:** player047  ·  **Channel:** #report  ·  **ref:** 100000000000000337/100000000000000338

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000066> (`player047` · `100000000000000066`)
**Date / Time:** just now

**Description of event / rule broken:**
not sure if its intended but the vehicle processing on illegal items goes very fast. i did ~ 160 weed > golden wax in less than 30 seconds

> **NOTABUG (owner):** fast vehicle processing is BY DESIGN.

**Evidence:**
_none provided_

---

### #288 · FIXED · 2026-06-16T20:12Z
- **By:** player047  ·  **Channel:** #report  ·  **ref:** 100000000000000339/100000000000000340
- **Fix (staged b0070):** store-side disconnect dupe. In `fn_storeInventory`, the VIRTUAL-item branch saved gear after the store but the PHYSICAL-item branch did `player removeItem` + wrote the container's `AP_pinv` (global, force-saved on disconnect) WITHOUT persisting the player's gear -> the DB `*_gear` kept the stored item, so store-physical -> alt+F4 -> reconnect gave it back while the container also held it. Added the same gear save `fn_onPutItem` uses (`saveGear` + side-aware `ClupdatePartial` mode 3) right after the `AP_pinv` write, so the removal persists immediately (covers vehicle-trunk stores too). Pairs with the existing TAKE-side disconnect fix in `fn_playerDisconnected`.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000066> (`player047` · `100000000000000066`)
**Date / Time:** today

**Description of event / rule broken:**
this was flagged by CLANKR however i have not tried to see if i wait introduce a delay it can avoid detection

**Evidence:**
Open House Virtual Inventory > store any physical items > alt+f4 > reconnect > items are easily duplicated

---

### #289 · NEEDINFO · 2026-06-16T20:49Z
- **By:** player006  ·  **Channel:** #report  ·  **ref:** 100000000000000341/100000000000000342

> **INVESTIGATED (2026-06-21) — needs the screenshot.** The in-game 'apply' (fn_applyCop) is just an info message pointing to Discord; the real MaxSec application = the LIVE Officer Maggot bot (loonybot/officer_maggot.py, token set). Most likely defect: run_wizard inserts the pending row THEN calls parent.create_thread with NO try/except (line ~302) -> if thread creation fails (perms/channel type), the applicant gets no 'submitted' DM, no review post is created, AND the pending row blocks them from re-applying (maxsec_pending_for). Other candidates: reviewer_role_ids empty -> falls back to thread_view_role_ids (Accept/Deny may say 'MaxSec command only' if those aren't the command roles). Ambiguous without the screenshot -- what did it show (error text? stuck? wrong accept outcome?).

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000127> (`player006` · `100000000000000127`)
**Date / Time:** JUST NOW

**Description of event / rule broken:**
caps lock my b but it is a issue with the police application

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000165/100000000000000343/image.png?ex=6a33086c&is=6a31b6ec&hm=ad0e6ed80bcd73710b3f0016e0d1965ed1f025320a1da72f1886ef2ee31cb16a&

---

### #290 · FIXED · 2026-06-16T21:07Z
- **By:** player029  ·  **Channel:** #report  ·  **ref:** 100000000000000344/100000000000000345

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000346> (`player029` · `100000000000000346`)
**Date / Time:** just now

**Description of event / rule broken:**
killing cop defusing bank does not stop the defuse

**Evidence:**
ill uplkoad

---

### #291 · FIXED · 2026-06-16T21:18Z
- **By:** player042  ·  **Channel:** #report  ·  **ref:** 100000000000000347/100000000000000348

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000210> (`player042` · `100000000000000210`)
**Date / Time:** on respawn

**Description of event / rule broken:**
THe timer says 30 mins to respawn but after 5 mins it force respawns you

**Evidence:**
nonew

---

### #292 · FIXED · 2026-06-16T21:18Z
- **By:** player066  ·  **Channel:** #force respawned  ·  **ref:** 100000000000000349/100000000000000349

force respawned — i was forced respawned after five minutes still had over 20 min before my timer ran out.

---

### #293 · DEFERRED · 2026-06-16T21:44Z
- **By:** player006  ·  **Channel:** #report  ·  **ref:** 100000000000000350/100000000000000351

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000127> (`player006` · `100000000000000127`)
**Date / Time:** like 10 minutes ago

**Description of event / rule broken:**
glitching through the furnaces watch the video and its easy to hide as long as you dont go too far into the furnace

> **Deferred to mapdesign.md** — furnace collision/geometry exploit; needs a map blocker (Eden), not a script fix.

**Evidence:**
https://medal.tv/games/arma-3/clips/mVFPPvHVfd9ANI2EK?invite=cr-MSxrY2gsNDI5MjIwNTM1

---

### #294 · NOTABUG · 2026-06-16T21:57Z
- **By:** player017  ·  **Channel:** #report  ·  **ref:** 100000000000000352/100000000000000353

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000250> (`player017` · `100000000000000250`)
**Date / Time:** just now

**Description of event / rule broken:**
i had 200k in my acount 5 minutas ago now i have zero after buying my kit for 43k

**Evidence:**
_none provided_

---

### #295 · FIXED · 2026-06-16T22:12Z
- **By:** player071  ·  **Channel:** #report  ·  **ref:** 100000000000000354/100000000000000355
- **Fix (staged b0070):** covered by the #290 bank rework. The vault dirty money was a single OWNED `Land_Money_F` pile — effectively only the driller could take it (others "unable to pick up"). `fn_bankDrillVault` now pays out as multiple ownerless `Land_Suitcase_F` briefcases (`AP_droppedItems`=`bank_money`, grab-anyone — same mechanic as the fed gold cases) spread over the vault floor, split across `(cops+2)` clamped 4–10, so the whole crew can each grab one.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000178> (`player071` · `100000000000000178`)
**Date / Time:** ROBBED Bank 450k dirty money unable to pick up

**Description of event / rule broken:**
didn't let me get it

**Evidence:**
_none provided_

---

### #296 · FEATURE · 2026-06-16T22:15Z
> closed 2026-06-22: feature request (invisible backpacks in the rebel clothing shop), not a bug -- out of scope per the standing "all but feature requests" rule.
- **By:** player047  ·  **Channel:** #report  ·  **ref:** 100000000000000356/100000000000000357

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000066> (`player047` · `100000000000000066`)
**Date / Time:** just now

**Description of event / rule broken:**
add invisble backpacks to "rebel clothing shop"

**Evidence:**
_none provided_

---

### #297 · FIXED · 2026-06-16T22:18Z
- **By:** player047  ·  **Channel:** #report  ·  **ref:** 100000000000000358/100000000000000359

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000066> (`player047` · `100000000000000066`)
**Date / Time:** just now

**Description of event / rule broken:**
the MK200 is 9k in rebel and the tracer mags are available for purchase for $100 ea

**Evidence:**
none'

---

### #298 · DEFERRED · 2026-06-16T22:58Z
- **By:** player071  ·  **Channel:** #general  ·  **ref:** 100000000000000179/100000000000000360

jewerly imp door opened without drilling

---

### #299 · DEFERRED · 2026-06-16T22:58Z
- **By:** player071  ·  **Channel:** #report  ·  **ref:** 100000000000000361/100000000000000362

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000178> (`player071` · `100000000000000178`)
**Date / Time:** Jewerly imp broken

**Description of event / rule broken:**
door is opened without drilling

**Evidence:**
_none provided_

---

### #300 · FIXED · 2026-06-16T22:59Z
- **By:** player087  ·  **Channel:** #report  ·  **ref:** 100000000000000363/100000000000000364

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000365> (`player087` · `100000000000000365`)
**Date / Time:** 2026-16-6

**Description of event / rule broken:**
When drugs are seased from tempest they stay in the tempest even after it is impounded. I was cought at ephedra they seised the inventory and it was still in there.

**Evidence:**
_none provided_

---

### #301 · FIXED · 2026-06-16T23:03Z
- **By:** player039  ·  **Channel:** #report  ·  **ref:** 100000000000000366/100000000000000367

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000183> (`player039` · `100000000000000183`)
**Date / Time:** just now

**Description of event / rule broken:**
jewelry doesnt add a charge

**Evidence:**
_none provided_

---

### #302 · FIXED · 2026-06-16T23:06Z
- **By:** player031  ·  **Channel:** #report  ·  **ref:** 100000000000000368/100000000000000369
- **Fix (staged b0070):** confirmed from the live log (jewelry 18:01:40 + fed 18:04:45 overlapped). Root: `activeFederalEvent` was enforced CLIENT-side only, and event flags set late (the fed only flips `AP_fed_robbed` at the alarm, ~10s after a 105s breach) → a 2nd event slips through the window, and nothing re-checked server-side. Added `APS_fnc_fedEventActive` (server-authoritative twin, reads the same flags) and called it inside every event's server activation — fed (`fn_fedGoldSpawn` loot + `fn_fedAlarm`), jewelry (`robberyStarted`), bank (`fn_bankDrillVault`), prison (`fn_handlePrisonBreak`), convoy (`fn_convoyRobbery`), loonybin (`fn_loonyBinSRV`), evidence (`fn_handleTimer` case 0). Now if a client slips past, the server refuses to activate/pay out the second event.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000370> (`player031` · `100000000000000370`)
**Date / Time:** JUST NOW

**Description of event / rule broken:**
fed and other events can be done at the same time

**Evidence:**
black men

---

### #303 · DEFERRED · 2026-06-16T23:06Z
- **By:** player039  ·  **Channel:** #report  ·  **ref:** 100000000000000371/100000000000000372
- **Deferred to mapdesign.md** — jewelry emporium back gate has no blocking collision (drive-through). Map-geometry fix (block/lock the gate object near [20720,16620]); do with the next map-edit batch.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000183> (`player039` · `100000000000000183`)
**Date / Time:** just now

**Description of event / rule broken:**
You can drive through the back gate in jewelry

**Evidence:**
https://gyazo.com/e96bf23d41af0189ee2ada22b9b34e2b

---

### #304 · DEFERRED · 2026-06-16T23:13Z
- **By:** player071  ·  **Channel:** #report  ·  **ref:** 100000000000000373/100000000000000374
- **Deferred to mapdesign.md (jewelry rework)** — break cases / cut safe before drilling done. Root: `robberyStarted` sets state slot 2 (`safeDrilled`) true the instant the event goes active, so case-break + safe-weld unlock together with no enforced drill→cases→safe sequence. Splitting the unlocks is a DESIGN decision (what's the intended order) — captured in mapdesign.md with #306 for the combined jewelry pass.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000178> (`player071` · `100000000000000178`)
**Date / Time:** You can break the cases before the door is finshed drilling same with the plamas cutting you can drill it before all cases are depoed

**Description of event / rule broken:**
N/a

**Evidence:**
_none provided_

---

### #305 · FIXED · 2026-06-16T23:19Z
- **By:** player087  ·  **Channel:** #report  ·  **ref:** 100000000000000375/100000000000000376
- **Fix (staged b0070):** gang `house_pos` DID persist + re-tag at boot, but the building's `AP_homeOwner` was only set by `fn_receiveHouses` on the OWNER's login -> when the owner was offline, every member's `fn_initGang` bailed (`_gangOwner isEqualTo ""`) and the house looked gone. Three fixes: (1) `AP_server\init.sqf` now restores `AP_homeOwner`/`AP_houseID` for ALL houses at boot; (2) `fn_initGang` no longer bails on empty owner (gang building is identified by `AP_house_gang`); (3) `fn_queryRequest` normalizes a NULL `house_pos` to `[0,0,0]` (was `[]`, which falsely tripped the "you already have a gang house" guard so the leader could never re-set it).

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000365> (`player087` · `100000000000000365`)
**Date / Time:** Just now

**Description of event / rule broken:**
The gang house does not stay the gang house. I have add to make it the gang house at least 3 times now.

**Evidence:**
_none provided_

---

### #306 · DEFERRED · 2026-06-16T23:23Z
- **By:** player071  ·  **Channel:** #report  ·  **ref:** 100000000000000377/100000000000000378
- **Deferred to mapdesign.md (jewelry rework)** — safe won't open + "Qilin" spawns no goods. Root: the SRV `weldSafe` case only sets the welded flag — it never swaps the closed safe for the `Fridge_01_open_F` the loot action targets (so the safe never "opens"), and there is NO reward-vehicle/Qilin spawn anywhere in the jewelry code (only payout path is carrying jewelBags to the container). Both are unfinished-feature gaps — needs owner design intent (safe-open swap + whether the Qilin reward exists) then a combined code+map pass. Written up in mapdesign.md. The case-smash loot path works today.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000178> (`player071` · `100000000000000178`)
**Date / Time:** Jewrly IMP dosn't spawn qullin with loot an the safe dosn't open

**Description of event / rule broken:**
after finshing all basic reqs the qullin didn't spawn in with any of the goods

**Evidence:**
_none provided_

---

### #307 · FIXED · 2026-06-16T23:34Z
- **By:** .8.0000  ·  **Channel:** #report  ·  **ref:** 100000000000000379/100000000000000380
- **Fix (staged b0070):** house keys vanished. Root = extDB3 multi-threaded out-of-order writes: the buy-time `REPLACE INTO houses` (which omits keyholders/vinv/pinv) executes late and lands AFTER a key given seconds later, and REPLACE=DELETE+INSERT so it wiped the fresh keys. Proven from live logs/DB: a key given 68s after buy was lost (keyholders NULL); one given 29min after survived. Fixes: (1) `fn_addHouse` REPLACE -> `INSERT … ON DUPLICATE KEY UPDATE` of identity cols only -> a late buy write can never delete the row or clobber later per-column writes; (2) `AP_server\init.sqf` +30s house loop now restores `AP_house_keys` (with `AP_homeOwner`/`AP_houseID`=oid) after a restart so persisted keys actually work for the holder. (Note: `fn_bldgUpdateKeys` already wrote keyholders correctly + audit-logs every change.)

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000262> (`.8.0000` · `100000000000000262`)
**Date / Time:** Last night

**Description of event / rule broken:**
Spent 10k giving keys to my boy, today they’re gone

**Evidence:**
_none provided_

---

### #308 · FIXED · 2026-06-16T23:37Z
- **By:** player048  ·  **Channel:** #report  ·  **ref:** 100000000000000381/100000000000000382

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000383> (`player048` · `100000000000000383`)
**Date / Time:** today after patch

**Description of event / rule broken:**
you can store drug ingredients in the garage still? maybe not a bug?

**Evidence:**
_none provided_

---

### #309 · FIXED · 2026-06-16T23:38Z
- **By:** player089  ·  **Channel:** #report  ·  **ref:** 100000000000000384/100000000000000385
- **Fix (staged b0070):** root = stock `difficulty="regular"` sets `mapContentFriendly=1`, and Arma treats the `civilian` side as friendly with `west`, so every civ's map natively revealed moving MaxSec units (the scripted `fn_trackMarkers` is correctly side-gated — this was the engine, not the script). Added `deploy/looneybin.Arma3Profile` (CustomDifficulty: `mapContentFriendly=0`/`mapContentEnemy=0`/`friendlyTags=0`, third-person KEPT on), set `server.cfg difficulty="Custom"`, and run-boot2 now installs the profile. Server-authoritative; applies on natural restart.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000386> (`player089` · `100000000000000386`)
**Date / Time:** we can see poilce on the map

**Description of event / rule broken:**
we all looked at the map and saw the police moving

**Evidence:**
https://medal.tv/games/arma-3/clips/mVIgmxHkXRY6x2XLs?invite=cr-MSx3dzcsMTAyNTUyMDc3

---

### #310 · FIXED · 2026-06-16T23:49Z
- **By:** player039  ·  **Channel:** #report  ·  **ref:** 100000000000000387/100000000000000388
- **Fix (staged b0070):** same root + fix as #305 (gang building lost on restart -> `AP_homeOwner` not restored at boot). Boot now restores house ownership tags; client no longer bails on empty owner; NULL `house_pos` loads as `[0,0,0]`.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000183> (`player039` · `100000000000000183`)
**Date / Time:** just now

**Description of event / rule broken:**
gang building doesnt carry over to next restart

**Evidence:**
_none provided_

---

### #311 · FIXED · 2026-06-16T23:51Z
- **Fix (staged b0070):** the LIVE Market board (`fn_mark1et`) showed raw `getLowestPrice`, but the actual shop sell is `getLowestPrice * getDiscount[shop,false]` — and for SELLING getDiscount is a bonus (gang talents, infamy, and the server-wide `SRV_bustBonusActive` +12%). So during a bust bonus / for bonus players the board under-reported what they'd actually get. Board now applies the same `getDiscount` (list + detail panel) so it matches the till.
- **By:** player039  ·  **Channel:** #report  ·  **ref:** 100000000000000389/100000000000000390

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000183> (`player039` · `100000000000000183`)
**Date / Time:** just now

**Description of event / rule broken:**
market not reflecting the same as sell price

**Evidence:**
_none provided_

---

### #312 · FIXED · 2026-06-17T00:16Z
- **By:** player039  ·  **Channel:** #report  ·  **ref:** 100000000000000391/100000000000000392
- **Fix (staged b0070):** same stuck-fed state as the live fed-reset issue. A robbery that doesn't cleanly end can leave domes in a DEADLOCK — `AP_vaultlocked=0` (so `fn_openVault` refuses "already unlocked") while the doors stay disabled+shut (won't open). The boot lockdown already re-locks the whole fed on every restart (so this self-heals on the next restart), and `APS_fnc_resetFed` now also calls the new `APS_fnc_fedLockdown` to re-lock domes/safes/gates mid-session (`!srv resetfed`). Stuck fed is now recoverable without a reboot.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000183> (`player039` · `100000000000000183`)
**Date / Time:** just now

**Description of event / rule broken:**
wont let us open domes

**Evidence:**
_none provided_

---

### #313 · FIXED · 2026-06-17T00:23Z
> triage 2026-07-04 (bugs-triage): was NEEDTEST, code-verified FIXED — mission/LooneyBin.Altis/core/gangs/fn_captureCartel.sqf:105 · Cartel-capture audience is filtered by 'side _x isEqualTo civilian', so on-duty cops/medics carrying gang_data no longer get the ping.
- **By:** player006  ·  **Channel:** #report  ·  **ref:** 100000000000000393/100000000000000394

> **ALREADY FIXED — verify (2026-06-21).** Cop/medic getting their civ-gang's cartel-capture pings = fn_captureCartel targeted playableUnits by gang only; an on-duty cop/medic still carries gang_data. The working tree already has the `side _x isEqualTo civilian` filter (fn_captureCartel:~217, baked in b0083+). #313 predates it (Jun-17). Re-test on current build; likely DUP of #336.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000127> (`player006` · `100000000000000127`)
**Date / Time:** mehhhh like a half hour or so but it is happening more and more everytime it hits

**Description of event / rule broken:**
its just constantly pulling the notif on my side as a cop and they arent even owned by my gang

**Evidence:**
https://medal.tv/games/arma-3/clips/mVIqLvgeEmuukmA28?invite=cr-MSx5MWEsNDI5MjIwNTM1

---

### #314 · FIXED · 2026-06-17T00:57Z
- **By:** player007  ·  **Channel:** #MaxSec bug no van in the shop  ·  **ref:** 100000000000000395/100000000000000395

MaxSec bug no van in the shop — MaxSec needs the VAN

---

### #315 · FIXED · 2026-06-17T01:17Z
- **By:** player039  ·  **Channel:** #report  ·  **ref:** 100000000000000396/100000000000000397

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000183> (`player039` · `100000000000000183`)
**Date / Time:** just now

**Description of event / rule broken:**
you can see people on the map, was able to see cops earlier on the map

**Evidence:**
https://gyazo.com/62f311cd4d509360dc69e47b065bf4e0

---

### #316 · FIXED · 2026-06-17T01:26Z
- **By:** player080  ·  **Channel:** #report  ·  **ref:** 100000000000000398/100000000000000399

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000400> (`player080` · `100000000000000400`)
**Date / Time:** Just now

**Description of event / rule broken:**
I ran for gov on day 1 of server going live. It said I won in game after restart but I am not governor and it also took my $75k 😢

**Evidence:**
_none provided_

---

### #317 · NEEDINFO · 2026-06-17T02:17Z
- **By:** player078  ·  **Channel:** #report  ·  **ref:** 100000000000000401/100000000000000402

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000403> (`player078` · `100000000000000403`)
**Date / Time:** Jost now

**Description of event / rule broken:**
yall know

**Evidence:**
yall know about it

> ask: We can't act on "yall know about it" — no idea what's broken. Reply here with: (1) what system/feature (map, storage, money, cop, house, vehicle, processing?), (2) exact steps to reproduce it, (3) a screenshot or clip. Without specifics this report gets closed.

---

### #318 · FIXED · 2026-06-17T02:27Z
- **By:** player055  ·  **Channel:** #report  ·  **ref:** 100000000000000404/100000000000000405

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000327> (`player055` · `100000000000000327`)
**Date / Time:** 6/16/2026 just now

**Description of event / rule broken:**
Essentially, my friend sold his shed back to the bank and I was trying to buy it but its not allowing me to buy it and pops up with an error even after two hours

**Evidence:**
Look at top right for error
https://cdn.discordapp.com/attachments/100000000000000406/100000000000000407/20C4191.JPG?ex=6a335790&is=6a320610&hm=82632a3bf8005178b2f142c4d3ef7c8c978d470d190988399accd307c6b52bfa&

**Resolution (STAGED, deploys next restart):** ROOT FOUND. Selling a house back to the bank (`fn_srvSellHouse`) only ran its `DELETE FROM houses` when `AP_houseID` was set on the object — but that var is `""`/`-1` whenever the boot ownership re-tag didn't stamp it (the #305/#307 timing). So the sell PAID the seller and cleared their client (handleHouse mode 2), but the DB row SURVIVED with `owners`=seller → the shed read "already owned" forever and every re-buyer got refunded by `fn_addHouse`'s theft pre-check (my .70 anti-theft guard, working as intended). Fix: `fn_srvSellHouse` now derives the oid from the house POSITION (the same `getPosWorld` hash `addHouse` builds) and ALWAYS deletes by it (+ by `AP_houseID` if a valid different legacy value), so a sale can never leave an orphaned owned row again. — DATA REPAIR PENDING: the friend's already-stuck shed row still has `owners`=friend in the live DB; the code fix prevents recurrence but can't retro-clear it. Need the shed location (grid/coords) or the friend's name/UID to clear that one row (no-reboot DB repair).

---

### #319 · FIXED · 2026-06-17T03:00Z
> triage 2026-07-04 (bugs-triage): was NEEDTEST, code-verified FIXED — server/AP_server/init.sqf:370-378 (+ fn_restoreVehicles.sqf:191-193) · A periodic 8-min vehicle_mem snapshot loop runs and the boot restore no longer wipes vehicle_mem, so spawned/left-out vehicles survive ungraceful restarts.
- **By:** player047  ·  **Channel:** #report  ·  **ref:** 100000000000000408/100000000000000409

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000066> (`player047` · `100000000000000066`)
**Date / Time:** just now

**Description of event / rule broken:**
missing 2 orcas

> **NEEDTEST** (owner 2026-06-19, persistence cluster): added a PERIODIC vehicle save -- the server now snapshots vehicle_mem (positions + AP_vinv trunk cargo) every 8 min, and the boot restore no longer wipes the table. Previously the graceful save ran ONLY on the scheduled restart, so manual hard restarts (deploys, !srv hardr, raw restart_now=1) and crashes lost every spawned/left-out vehicle. Now they survive any ungraceful exit (lose <=8 min). NEEDS in-game verification across a restart.

**Evidence:**
_none provided_

---

### #320 · NEEDINFO · 2026-06-17T03:01Z
- **By:** player039  ·  **Channel:** #report  ·  **ref:** 100000000000000410/100000000000000411

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000183> (`player039` · `100000000000000183`)
**Date / Time:** just now

**Description of event / rule broken:**
getting titles and achievements for not doing anything

> **NEEDINFO** (owner 2026-06-19): need the exact title(s)/achievement(s) shown as earned -- each is gated on its own stat threshold, so I can't pinpoint the bad condition without the name. (If it's ALL of them, likely `APV_statTotals` loaded empty/-1 at check time -- say so.)

**Evidence:**
https://gyazo.com/98a9527fccb456a92d52c5afb1374d60

---

### #321 · DUP · 2026-06-17T03:09Z
> DUP 2026-06-21: #441→#435 (Y-inv relog dupe, fixed b0081); #321→#184 (invis bag restart, fixed); #437→#167/#182 (house stays for-sale after sold, fixed).
- **By:** player095  ·  **Channel:** #report  ·  **ref:** 100000000000000412/100000000000000413

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000119> (`player095` · `100000000000000119`)
**Date / Time:** yes

**Description of event / rule broken:**
invis backpacks still come back after restart

**Evidence:**
no

---

### #322 · FIXED · 2026-06-17T03:49Z
- **By:** player056  ·  **Channel:** #report  ·  **ref:** 100000000000000414/100000000000000415

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000416> (`player056` · `100000000000000416`)
**Date / Time:** Just now

**Description of event / rule broken:**
Not able to process your vehicle inventory at lsd processor even with the car being as close as possible

**Resolution (STAGED, deploys next restart):** ROOT FOUND. The "LSD processor" is the Fungi Den (`npcs/fn_civFungi.sqf`) — and it was the ONLY processor with NO bulk "Process Vehicle" scroll options (every other processor offers them next to the hand actions), so there was simply nothing to click to process a trunk there. On top of that, `fn_processVehicle`'s recipe table was missing the `fungi → lsd_0` recipe (it only had `lsd_0 → lsd_1`). Fix: (1) added the `fungi` (Dark Fungi → LSD Pill) recipe to `fn_processVehicle` (capIndex 1 = drug cartel, matching the existing `lsd_1`); (2) added two scroll options at the Fungi Den — "Process Vehicle: LSD" (fungi→lsd_0) and "Process Vehicle: LSD Sheets" (lsd_0→lsd_1). Bulk vehicle-trunk LSD processing now works like every other drug.

---

### #323 · FIXED · 2026-06-17T04:16Z
- **By:** player042  ·  **Channel:** #report  ·  **ref:** 100000000000000417/100000000000000418

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000210> (`player042` · `100000000000000210`)
**Date / Time:** gang garage

**Description of event / rule broken:**
Gang garage bugs out if the person who put them in the garage is nto the one who pulls it, it makes you not able to store the vehicals anywhere or any other car and if they are out at restart they poof, was a known issue on asylum for a while

**Evidence:**
_none provided_

**Resolution (STAGED, deploys next restart):** Store-lockup ROOT FOUND + fixed. The only global gate on the "Store Vehicle in Garage" action is `!AP_garage_store`. The client sets that flag `true` during a store; `fn_vehicleStore` (personal) clears it on every exit, but the GANG path `fn_gangGarageStore` never did → after any gang-garage store the flag stayed stuck `true` and the store action vanished for ALL vehicles ("can't store any car"; a relog reset it, hence "until restart"). Fix: gang store now releases `AP_garage_store` (+`AP_impound_inuse`) on every exit, PLUS a client-side 15s auto-clear watchdog in `fn_storeVehicle` so a missed clear from ANY path can never permanently lock storing again. — The "vehicles poof at restart" half is a SEPARATE gang-vehicle world-persistence issue, split out to #335.

---

### #324 · FIXED · 2026-06-17T04:19Z
- **By:** player042  ·  **Channel:** #report  ·  **ref:** 100000000000000419/100000000000000420

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000210> (`player042` · `100000000000000210`)
**Date / Time:** gang house

**Description of event / rule broken:**
You can not see (ever) and sometimes can not unlock a gang house, also gang leader only sees it as a normal house for them you also cant spawn at it

**Evidence:**
_none provided_

**Resolution (STAGED, deploys next restart):** "Can't see (ever)" + "leader sees it as a normal house" ROOT FOUND + fixed. The green gang-house map marker was only created AFTER `fn_initGang` found the building OBJECT within 14m — which requires being near the HQ when it streams in (≤90s window, no retry). Log in far from the HQ → the building never streams → the marker was never drawn; the leader was never marked at all (`setGangHouseForMembers` excludes `- [player]`, and `fn_setGangHouse` drew no marker), so the leader saw only their blue OWNED-house marker. Fix: draw the green marker from the stored HQ position (`gang_data[3]`) IMMEDIATELY — independent of streaming — in all three paths (`fn_initGang` relog, `fn_setGangHouse` leader live-set, `fn_setGangHouseForMembers` members), unified marker name `phouse_gang_<gangID>`. The building-find still runs to wire `AP_gangBuilding` for spawn/access/unlock. — KNOWN LIMITATION (owner-scoped): spawn-at and unlock still need the building object, so if you log in FAR from the HQ and the building never streams during the 90s find, "can't spawn/unlock" can persist until you're near it or relog nearby. Possible follow-up: drive the gang spawn point from `gang_data[3]` (pos) instead of the streamed object.

---

### #325 · FIXED · 2026-06-17T04:23Z
- **By:** player019  ·  **Channel:** #report  ·  **ref:** 100000000000000421/100000000000000422

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000083> (`player019` · `100000000000000083`)
**Date / Time:** Just now

**Description of event / rule broken:**
Scotch does not age

**Evidence:**
Process all of this yesterday and it has not aged 1 strage
https://cdn.discordapp.com/attachments/100000000000000292/100000000000000423/Screenshot_20260617_002249.png?ex=6a3372db&is=6a32215b&hm=7914d7cb4b30456f5fb8caa29df17ffd4b260dee27b578a6ab66a83a2f613052&
https://cdn.discordapp.com/attachments/100000000000000292/100000000000000424/Screenshot_20260617_002328.png?ex=6a3372db&is=6a32215b&hm=5da8a4a7d6627a47c65f6dc6420719f675be2b50cadbf827e9e7a1684ecc2b14&

**Resolution (STAGED stopgap + feature backlogged):** ROOT FOUND. Scotch ages in `fn_addStorage` at boot (one stage per restart, in the `Land_WaterBarrel_F` aging barrel), gated on `!(houseId in AP_scanned_houses)`. But the scanned-marking was a 5s-DELAYED spawn (`fn_query`) that raced the async `addStorage` aging at a congested boot and usually WON → the guard saw the house already "scanned" → scotch never aged. STOPGAP shipped: mark the house scanned ATOMICALLY inside `fn_addStorage`'s aging block (removed the delayed marker), so per-restart aging fires reliably. — Owner chose **time-based (6h/stage)** over per-restart; that's a feature-sized rebuild blocked on the tangled legacy storage subsystem (the barrel is a `storage`-table container using a `Trunk` var vs the modern `AP_vinv` house model) which needs LIVE verification before touching (high blast radius). Logged in `features.md` → "[ECONOMY] Time-based barrel aging" with the full plan. The stopgap makes scotch age now; the 6h time-based version ships from the backlog after live mapping.

---

---

### #326 · FIXED · 2026-06-17T04:34Z
> triage 2026-07-04 (bugs-triage): was NEEDTEST, code-verified FIXED — mission/LooneyBin.Altis/core/functions/fn_manageSidechat.sqf:38 · Side-chat toggle now drives the engine Side channel via enableChannel and is wired from the settings menu, no longer a no-op.
- **By:** player019  ·  **Channel:** #report  ·  **ref:** 100000000000000425/100000000000000426

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000083> (`player019` · `100000000000000083`)
**Date / Time:** Just now

**Description of event / rule broken:**
Side chat toggle does not work

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000292/100000000000000427/Screenshot_20260617_003413.png?ex=6a337549&is=6a3223c9&hm=13ac1c96a695b49120d5694ed18b97e076d528ccff001715802f91eeb8714818&

---

### #327 · FIXED · 2026-06-17T05:18Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — mission/LooneyBin.Altis/core/actions/fn_storeVehicle.sqf:141 · The 15s self-heal watchdog that clears a stuck AP_garage_store is present on the normal (gang+personal) store path, matching the staged fix.
- **By:** player042  ·  **Channel:** #report  ·  **ref:** 100000000000000428/100000000000000429

> **FIXED+STAGED (mission).** 'Can't store anything until restart' = `AP_garage_store` flag stuck TRUE. It gates the Store scroll action (!AP_garage_store) and is cleared by the server on store-complete; the 15s self-heal watchdog (from #323) only existed on the cop-equipment branch -> the NORMAL store path (gang+personal, fn_storeVehicle.sqf:116) set the flag with NO watchdog, so a lost server-clear left it stuck server-wide. Added the same 15s watchdog to the normal path. (Note: a true FULL relog already clears it via configuration.sqf re-init, so the 'relog doesn't fix it' was likely a soft/seamless reconnect.)

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000210> (`player042` · `100000000000000210`)
**Date / Time:** Garage

**Description of event / rule broken:**
WHen pulling car at truck shop (i think its a truck shop issue) then you cant store anything anywhere until resatrt soft log and full log do not fix it

**Evidence:**
_none provided_

**Status note (kept NEW pending repro):** Same "can't store anything" symptom as #323, but #327 is reported as relog-PROOF, which the store-gate flag (`AP_garage_store`) shouldn't be (it re-inits `false` on every connect). Need one fact from player042: when stuck, is the "Store Vehicle in Garage" scroll option GONE (= stuck flag → the #323 gang-clear + 15s auto-clear watchdog already covers it), or is the option THERE but it errors (= a different server-side reject needing its own fix)? The #323 defensive auto-clear is staged and will likely cover #327 if it's the stuck-flag class. Owner to confirm symptom with reporter.

---

### #328 · FIXED · 2026-06-17T05:48Z
> triage 2026-07-04 (bugs-triage): was NEEDTEST, code-verified FIXED — mission/LooneyBin.Altis/core/inventory/fn_storeInventory.sqf:174 · Store logic now adds primaryWeaponItems (bipod included) to the stored inventory before removeWeaponGlobal, comment cites #328/#341, so the bipod is stored not 
- **By:** player042  ·  **Channel:** #report  ·  **ref:** 100000000000000430/100000000000000431

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000210> (`player042` · `100000000000000210`)
**Date / Time:** House storage

**Description of event / rule broken:**
When trying to put guns in to a house if it has a bipod it gets rid of the bipod off the gun and not in the house storage

**Evidence:**
_none provided_

---

### #329 · DEFERRED · 2026-06-17T07:03Z
- **By:** player095  ·  **Channel:** #report  ·  **ref:** 100000000000000432/100000000000000433

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000119> (`player095` · `100000000000000119`)
**Date / Time:** no

**Description of event / rule broken:**
We are unable to see houses that we do not own but have keys too we used to be able to see friends houses with keys on old asylum.

**Evidence:**
no

**Resolution (DEFERRED → feature):** Not a quick fix — the client has zero keyed-house data (`AP_houses` is owned-only; nothing sends a player the houses they hold keys to). Owner decision 2026-06-17: deferred to the feature backlog. Logged in `features.md` under "[HOUSING] Show keyed houses on the map" with a full build sketch (server keyed-house query → client `AP_keyedHouses` list → distinct-color markers, kept in sync on key grant/revoke).

---

### #330 · FIXED · 2026-06-17T07:31Z
- **By:** player013  ·  **Channel:** #Governor system doesn't work  ·  **ref:** 100000000000000434/100000000000000434

Governor system doesn't work — I voted for myself yesterday and so did my friends but I have zero votes today.

**Resolution (STAGED, deploys next restart):** TWO problems. (1) ROOT: `init.sqf:173` ran `DELETE FROM votes` on EVERY boot ("elections are per-session") — but the rebuilt 7-day-term gov system PERSISTS votes (its `reload` rebuilds tallies from the table; votes clear only when a governor is seated). So every 4-hour restart wiped the whole ballot → "voted yesterday, 0 today." Removed the boot-wipe. (2) DESIGN GAP: no governor was ever seated, and the system only resolves an election at a term end (which needs a seated governor), so persisted votes still elected nobody. Per owner: built a SELF-STARTING election — with a vacant seat + candidates, the race auto-resolves at an open-election window (`GOV_ELECTION` = 7 days from the first candidacy), seating the current top-voted as the first governor, then the normal 7-day cycle continues (armed on boot via `reload` + on each `runForOffice`, idempotent, aborts if someone's appointed). Current race resolves in ~4.3 days. — NOTE: the votes cast BEFORE this fix were already wiped by bug (1) and can't be recovered; players should re-vote once b-next deploys.

---

### #331 · FIXED · 2026-06-17T08:52Z
> triage 2026-07-04 (deep-dive): was NEEDTEST, code-verified FIXED — deploy/looneybin.Arma3Profile:36 — `waypoints = 2;` (Always Show), changed from 1 (Fade Out); committed at HEAD (git diff HEAD empty). Deploy caveat: 
- **By:** player083  ·  **Channel:** #report  ·  **ref:** 100000000000000435/100000000000000436

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000226> (`player083` · `100000000000000226`)
**Date / Time:** just now

**Description of event / rule broken:**
The waypoint disappeares of your screen and u need to open map to see it again

**Evidence:**
https://youtu.be/6PXip9KnLFQ

---

### #332 · FIXED · 2026-06-17T10:01Z
- **By:** player083  ·  **Channel:** #report  ·  **ref:** 100000000000000437/100000000000000438

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000226> (`player083` · `100000000000000226`)
**Date / Time:** now

**Description of event / rule broken:**
you can store hemtt with drugs inside and pull it out wherever u want and u will still have it

**Evidence:**
you can check it

**Resolution (STAGED, deploys next restart):** Not a dupe — traced load-into-trunk (decrements inv) → store (DB) → pull (clears DB copy, restores), single copy throughout. It was the owner's 2026-06-14 design (garage kept contraband as-is). Per owner: re-added a SERVER-authoritative illegal-item strip on garage store (`DB_fnc_updateVehicle` active=0, set = `getIllegalItems`) — drugs/contraband removed when a vehicle is garaged/impounded/idle-cleaned; legal cargo + the hydro/phos precursors kept (owner's chosen set). Client store warning reworded + gated to match. World persistence (`vehicle_mem`) untouched — contraband still survives an OUT vehicle across a restart, as intended.

---

### #333 · FIXED · 2026-06-17T14:16Z
- **By:** player008  ·  **Channel:** #report  ·  **ref:** 100000000000000439/100000000000000440

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000064> (`player008` · `100000000000000064`)
**Date / Time:** just now

**Description of event / rule broken:**
can rob gas with no cops. increase to 1 cop on

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000441/100000000000000442/image.png?ex=6a33fdd5&is=6a32ac55&hm=c16d16715d2193b90906c7f355636943593c41ca922049969fb07fa12cc7313f&

**Resolution (STAGED, deploys next restart):** Gas-station robbery (`fn_robStoreAction`) was the ONE crime that never called `AP_fnc_policeRequired`, so it stayed robbable with 0 cops even though the beta zero-cop waiver is already off (`init.sqf:535` publishes `AP_betaZeroCops=false`; every federal event already enforces cops). Fix: gas now calls `[1] call AP_fnc_policeRequired` → needs ≥1 police online. Also flipped `fn_policeRequired`'s default `true→false` so the requirement holds even on a JIP client whose flag hasn't synced yet (matches the server-side fed/bank/jewelry checks). Owner chose "turn off beta zero-cops" — it was already off server-side; this closes the gas loophole + hardens the client default. launch.md #2b marked DONE. — Player-facing note for the next deploy: "Gas stations now require ≥1 police online to rob."

---

### #334 · FIXED · 2026-06-17T18:01Z
- **By:** internal (code audit, found during #332)  ·  **Channel:** internal

**Report Type:** Bug
**Reporter:** Claude code audit

**Description of event / rule broken:**
Gang garage store (`APS_fnc_gangGarageStore` / `server/AP_server/core/TON/fn_gangGarageStore.sqf:16`) serializes the trunk from `getVariable["Trunk"]` — the WRONG variable. The live trunk var is `AP_vinv`. So a vehicle stored in the GANG garage always saves an EMPTY trunk → the entire trunk (legal cargo + items) is LOST on store, and the gang vehicle returns empty on pull. Distinct from #332 (personal garage). Fix in the #323/#327 gang-garage pass: read `AP_vinv` (matching `fn_saveVehicles`' 2026-06-13 fix) and apply the same #332 illegal-item strip for consistency (strip illegal, keep legal).

**Evidence:**
`fn_gangGarageStore.sqf:16` — `private _inv = [_veh getVariable ["Trunk", [[], 0]]] call DB_fnc_mresArray;`

**Update (scope — bigger than a typo):** Gang-trunk persistence is MISSING on BOTH ends, not just the store typo. (1) Store writes the trunk from the wrong `Trunk` var = empty. (2) The pull side never restores a trunk anyway: `fn_gangGarageGetVehicles` doesn't even `SELECT inventory`, and `APS_fnc_gangGarageSetActive` has no trunk restore (unlike the personal `fn_vehicleSetActive`). So fixing the typo alone does nothing visible — gang vehicles simply never keep a trunk. Real fix = build gang-trunk persistence mirroring personal (store `AP_vinv` stripped per #332 → `SELECT inventory` on pull → restore + clear the DB copy for the single-place anti-dupe invariant). Pending owner decision: build the full feature vs. just warn players to empty before gang-storing (prevents silent item loss). NOT a lockup — #323 lockup fixed separately.

**Resolution (STAGED, deploys next restart):** Built full gang-trunk persistence mirroring personal. (1) `fn_gangGarageStore` now serializes the real `AP_vinv` (illegal stripped per #332, weight recomputed) into `gang_vehicles.inventory` in the same str-format `fn_updateVehicle` uses. (2) `fn_gangGarageSetActive` now RECEIVES the pulled vehicle — the 5th client arg was mis-typed as a Number `_active`, so the object was dropped, which is why a trunk could never be restored — and it SELECTs the stored trunk (the `active='0'` row), CLEARs the DB copy in the same activate UPDATE (single-place anti-dupe), then restores into the live vehicle with the same `AP_vinv`-wait anti-race as personal. Backward-compatible (old empty / `Trunk`-typo rows restore empty). Zombie-row observation routed to #335.

---

### #335 · FIXED · 2026-06-17T18:05Z
> triage 2026-07-04 (bugs-triage): was NEEDTEST, code-verified FIXED — server/AP_server/init.sqf:373 · Periodic 8-min vehicle_mem snapshot loop present (uiSleep 480 -> DB_fnc_saveVehicles [true]) and fn_restoreVehicles.sqf:191 no longer wipes vehicle_mem; save lo
- **By:** internal (split from #323)  ·  **Channel:** internal

**Report Type:** Bug
**Reporter:** Claude code audit (player042's #323 second symptom)

**Description of event / rule broken:**
Gang vehicles left OUT (not garaged) at server restart "poof" — disappear instead of persisting. Second half of player042's #323 (the store-lockup half is fixed). Likely gang-vehicle world-persistence: `fn_saveVehicles` snapshots spawned vehicles into `vehicle_mem` by plate, but gang vehicles carry a gang-scoped `AP_dbInfo` (`[str gangID, plate, true]`) and live in `gang_vehicles` (not `vehicles`); need to verify the save AND the boot restore (`fn_restoreVehicles`) round-trip a gang vehicle's ownership/active state so it respawns gang-owned after a restart instead of vanishing.

> **NEEDTEST** (owner 2026-06-19, persistence cluster): added a PERIODIC vehicle save -- the server now snapshots vehicle_mem (positions + AP_vinv trunk cargo) every 8 min, and the boot restore no longer wipes the table. Previously the graceful save ran ONLY on the scheduled restart, so manual hard restarts (deploys, !srv hardr, raw restart_now=1) and crashes lost every spawned/left-out vehicle. Now they survive any ungraceful exit (lose <=8 min). NEEDS in-game verification across a restart.

**Evidence:**
player042 #323: "if they are out at restart they poof"

**Related finding (from #334):** `fn_gangGarageStore` INSERTs a fresh `gang_vehicles` row on every store but never removes the vehicle's prior row, so a store→pull→store cycle leaves an `active=1` zombie row behind each cycle. These duplicates inflate the gang vehicle count and are a prime suspect for the restart "poof" (boot restore mishandling duplicate/zombie plate rows). Fix candidate: add a UNIQUE key on `gang_vehicles(gang_id, plate)` + REPLACE / ON DUPLICATE KEY UPDATE, or a synchronous delete-then-insert — NOT two async queries (extDB3 ordering not guaranteed, could delete the just-stored row).

---

### #336 · FIXED · 2026-06-17T19:13Z
> triage 2026-07-04 (bugs-triage): was NEEDTEST, code-verified FIXED — mission/LooneyBin.Altis/core/gangs/fn_captureCartel.sqf:216 · fn_captureCartel now filters the cartel-capture alert to gang members playing as civilian (side _x isEqualTo civilian), so a gang member on medic/cop duty no lo
- **By:** player011  ·  **Channel:** #report  ·  **ref:** 100000000000000443/100000000000000444

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000141> (`player011` · `100000000000000141`)
**Date / Time:** just now

**Description of event / rule broken:**
i was chilling on medic and i saw this notification pop up i thought it was fixed in a previous patch but it seems it's not fully fixed cause the moment arms was contested i got this message

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000142/100000000000000445/20260617221102_1.jpg?ex=6a34436a&is=6a32f1ea&hm=74fd263fa58544842f5ba908b8977b0b2ee116ab9c8f05fbd5e445d035bba0e9&

---


### #337 · FIXED · 2026-06-17T20:38Z
- **By:** owner (economy deep-dive)  ·  **Channel:** internal

**Report Type:** Exploit / Balance
**Reporter:** owner — "players wait for restart where the market resets, dump house-weed wax for MILLIONS. House weed should be fun money, not rich (other drugs are for getting rich)."

**Description / fix (STAGED, deploys next restart):**
1. **MARKET RESET EXPLOIT — ROOT FOUND + FIXED.** The dynamic market (`AP_price_index`, a neglect-premium model) is supposed to persist via an `itemstock` table, but **the table never existed** — so `fn_queryStock` (boot load) + `fn_saveVehicles:68` (restart save) both failed silently → the market RESET to baseline (prem=1 = max price) EVERY restart. Players hoarded goods, waited for a restart, dumped at reset-high prices. Fix: created the `itemstock` table (className PK, quantity=premium FLOAT, sales INT) — the existing load/save now work → premiums + sale-counters survive restarts.
2. **HOUSE-WEED → WAX MILLIONS — REBALANCED** (owner: modest, not rich). (a) Lowered prices in `fn_virtItemCfg`: Golden Wax (canna_dab) $1200→$350, Indica/Sativa buds $700/$500→$200. (b) Added `canna_dab` to `AP_marketGoods` (demand-tracked) with a **per-item anti-hoard override** `AP_marketItemOv=[["canna_dab",400,1.4]]` — a small dump (400) crashes its price back to base, and its neglect premium is capped at 1.4x ($490) so it can't inflate. New override threaded (findIf-safe) through the marketTick climb, the crash hook (`eventhandlers`), and the client clamp (`fn_marketFactor`).
3. **SATIVA → WAX REMOVED** (owner: indica-only). Stripped the `cannas_3`→`canna_dab` recipe + scroll actions from `fn_processAction`, `fn_processVehicle`, `fn_civProcessItem`, `fn_shops`. Sativa bud now sells as a bud only; only Indica bud (`cannai_3`) makes wax.

Tune wax further via `AP_marketItemOv` (lower base/crash/maxPrem) if still too lucrative. Full notes in the `loonybin-dynamic-market` memory.

---
### #338 · FIXED · 2026-06-17T20:53Z
- **By:** player051  ·  **Channel:** #report  ·  **ref:** 100000000000000446/100000000000000447

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000074> (`player051` · `100000000000000074`)
**Date / Time:** just now

**Description of event / rule broken:**
I dont think the market is working as its intended too. i havent seen the prices deviate on the phone since dynamic market was put into place. its either stuck or the phone market isnt representing the actual pricing

**Evidence:**
_none provided_

**Resolution (STAGED, deploys next restart):** THREE parts. (1) The phone board was NOT out of sync with the till — verified both use `getLowestPrice × getDiscount[shop]` with the market factor baked into `getLowestPrice` (same number). (2) Prices were genuinely STUCK because the market never persisted — the `itemstock` table never existed, so it reset to baseline every restart (fixed: created the table, see #337). (3) ROOT of "haven't seen prices deviate": the old NEGLECT-PREMIUM model floored every good at its MAX and only rose for *neglected* goods — it could never drop a price below max, so the goods players actually trade sat flat forever. Per owner (option C): reworked to a HYBRID supply/demand model — `factor ∈ [0.6, 1.3]`, SELLING pushes a good DOWN toward the 0.6 floor (oversupply discount), IDLE ticks recover/climb it toward the 1.3 ceiling (scarcity premium). So prices now move BOTH ways (dump → drops; leave alone → recovers/rises) AND it's strong anti-hoard (dumping a hoard tanks the price). Tunables: `AP_marketFloor` 0.6, `AP_marketMaxPrem` (ceiling) 1.3, `AP_marketCrash` (drop depth) 2500, per-item `AP_marketItemOv` (wax: depth 400, ceiling 1.0). Files: `fn_marketTick`, `eventhandlers` (sell hook), `fn_marketFactor`, `fn_mark1et` (board labels/arrows now show drops). Stale "Oversupplied"-always label fixed. ECONOMY-WIDE, untested in-game — watch prices after deploy.

---

---

### #339 · FIXED · 2026-06-17T22:59Z
> triage 2026-07-04 (deep-dive REALBUG -> FIXED): fn_handleItem.sqf switch default -> accessory kept in inventory
- **By:** player077  ·  **Channel:** #report  ·  **ref:** 100000000000000448/100000000000000449

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000450> (`player077` · `100000000000000450`)
**Date / Time:** just now

**Description of event / rule broken:**
bought a a 7.62 sup and a ams scope didnt go in my inv

**Evidence:**
_none provided_

---

### #340 · FIXED · 2026-06-17T23:03Z
- **By:** player039  ·  **Channel:** #report  ·  **ref:** 100000000000000451/100000000000000452

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000183> (`player039` · `100000000000000183`)
**Date / Time:** just now

**Description of event / rule broken:**
free granitBs in gang shop

> **FIXED** (owner 2026-06-19): already resolved — the gang shop no longer hands out free Granit.

**Evidence:**
_none provided_

---

### #341 · FIXED · 2026-06-17T23:19Z
> triage 2026-07-04 (bugs-triage): was NEEDTEST, code-verified FIXED — mission/LooneyBin.Altis/core/inventory/fn_storeInventory.sqf:172 · fn_storeInventory.sqf:172-179 now iterates primaryWeaponItems (bipod) into the stored inventory, and line 34 keeps loose weapon attachments from being dropped, 
- **By:** player038  ·  **Channel:** #report  ·  **ref:** 100000000000000453/100000000000000454

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000455> (`player038` · `100000000000000455`)
**Date / Time:** just now

**Description of event / rule broken:**
Putting a bipod in a house delete it

**Evidence:**
https://medal.tv/games/arma-3/clips/mW7oY3gS5WwGHXS6Z?invite=cr-MSxwcnMsMjE1Njc0NzAz

---

### #342 · FIXED · 2026-06-17T23:37Z
> triage 2026-07-04 (bugs-triage): was NEEDTEST, code-verified FIXED — server/AP_server/core/jail/fn_startPrisonBreak.sqf:95 · Completion path now clears the SRV_prisonData[1] start-gate (deferred 70s) with an explicit #342 comment, so a new prison break can start after a successful one
- **By:** player024  ·  **Channel:** #report  ·  **ref:** 100000000000000456/100000000000000457

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000458> (`player024` · `100000000000000458`)
**Date / Time:** 6/17 6:35pm

**Description of event / rule broken:**
prison break not working after successful prison break

**Evidence:**
_none provided_

---

### #343 · FIXED · 2026-06-17T23:37Z
- **By:** player094  ·  **Channel:** #report  ·  **ref:** 100000000000000459/100000000000000460

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000461> (`player094` · `100000000000000461`)
**Date / Time:** just now

**Description of event / rule broken:**
>Gang building was not set by gang leader (via previous bug).
>He set it while I was dead/bleeding out and when I went to click respawn and click on the gang building, respawn screen went to the very bottom left of the map. Could not spawn there. Was told "Error. Please wait a bit or try a different spawn point." 
>Respawned in a town, suicide'd to try again (maybe it was bugged since I was bleeding out when the gang house was set.)
>Tried selecting gang house and same result as above ^^

**Evidence:**
https://youtu.be/p4d-yeCHRKk

---

### #344 · FIXED · 2026-06-17T23:38Z
- **By:** player050  ·  **Channel:** #report  ·  **ref:** 100000000000000462/100000000000000463

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000464> (`player050` · `100000000000000464`)
**Date / Time:** now

**Description of event / rule broken:**
Gang building does not show up on spawn menu

**Evidence:**
_none provided_

---

### #345 · FIXED · 2026-06-17T23:43Z
- **By:** player006  ·  **Channel:** #report  ·  **ref:** 100000000000000465/100000000000000466

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000127> (`player006` · `100000000000000127`)
**Date / Time:** a few minutes ago

**Description of event / rule broken:**
been having problems with members of the gang not being able to see the gang building in the respawn menu and then i had also just seen this happen, also mikey (the gang leader) had even removed the gang house as the gang building to be able to let the members use the house and spawn there but its a 50/50 chance that it work, or it doesnt do anything

**Evidence:**
https://medal.tv/games/arma-3/clips/mW7LeXaE3ZDpzyQ-x?invite=cr-MSxpYnIsNDI5MjIwNTM1

---

### #346 · FIXED · 2026-06-17T23:43Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — mission/LooneyBin.Altis/core/vehicle/fn_prepareVehicle.sqf:49 · fn_prepareVehicle now sets the "spawned" var and fn_cleanup.sqf:37-47 reaps idle empty vehicles at the 40-min tier, so abandoned cars despawn.
- **By:** player056  ·  **Channel:** #report  ·  **ref:** 100000000000000467/100000000000000468

> **INVESTIGATED (2026-06-21) — half fixed, half is an owner tuning decision.** Two parts: (1) 'vehicles go missing' = the ghost-vehicle delete (fn_cleanup deleting a pulled vehicle without the active=0 DB write) — ALREADY FIXED (fn_cleanup.sqf:37-62, dated 2026-06-20, after this report) + the #457 boot reset. (2) 'cars don't despawn / only return on restart' = the `"spawned"` object var is NEVER set anywhere, so fn_cleanup always uses the 60-min branch, AND idleTime is re-stamped on every get-in/out/trunk-open -> a touched vehicle almost never sits 60 min untouched -> effectively never despawns in-session; the restart restore (active 1->0 + idleTime=1) is what reaps them. The long timer is DELIBERATE (#239, so a parked processing truck doesn't vanish mid-run). DECISION NEEDED: keep the long timer, or make abandoned vehicles reap faster (and should get-in/out reset the clock)? **OWNER CHOSE: reap faster. FIXED+STAGED (mission):** the `"spawned"` var (never set anywhere) is now set in fn_prepareVehicle on every pull/buy -> pulled vehicles use the SPAWNED 40-min idle tier instead of the dead 60-min STORED tier = abandoned cars reap ~33% faster. Restored vehicles (don't run that fn) stay 60 min; occupied (crew>0) + any get-in/out/trunk-open (re-stamps idleTime) still protected, so processing trucks per #239 are safe. (Can drop the 2400s further if you want more aggressive.)

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000416> (`player056` · `100000000000000416`)
**Date / Time:** 1

**Description of event / rule broken:**
2026-06-16

**Evidence:**
Cars do not appear to be on a timer/ do not despawn. Cars seem to only return to garage after restart. Id even say some vehicles might get deleted. I had a hatch go missing completely and when retracing my steps, I cannot see a situation where the hatch blew up or got chopped. Not sure but vehicles do seem to not despawn

---

### #347 · FIXED · 2026-06-17T23:44Z
- **By:** player077  ·  **Channel:** #report  ·  **ref:** 100000000000000469/100000000000000470

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000450> (`player077` · `100000000000000450`)
**Date / Time:** restart

**Description of event / rule broken:**
when server restart spawned me in the water

**Evidence:**
no

---

### #348 · DEFERRED · 2026-06-17T23:57Z
- **By:** player050  ·  **Channel:** #report  ·  **ref:** 100000000000000471/100000000000000472

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000464> (`player050` · `100000000000000464`)
**Date / Time:** just now

**Description of event / rule broken:**
Virtual Arsenal hardlocks game, forces restart to fix

**Evidence:**
_none provided_

---

### #349 · FIXED · 2026-06-18T00:35Z
> triage 2026-07-04 (bugs-triage): was NEEDTEST, code-verified FIXED — server/AP_server/core/bank/fn_bankDrillVault.sqf:195 · Bank briefcases are re-anchored to the real vault-interior coord and clustered (fn_bankDrillVault.sqf:195-209, explicitly citing #349) instead of spawning outsi
- **By:** player023  ·  **Channel:** #report  ·  **ref:** 100000000000000473/100000000000000474

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000475> (`player023` · `100000000000000475`)
**Date / Time:** just now

**Description of event / rule broken:**
bank loot spawned outside ?

**Evidence:**
https://medal.tv/games/arma-3/clips/mW8LFbCGhuJWNIuT6?invite=cr-MSxBd2csMzMyNDUxMTUy&v=8

---

### #350 · FIXED · 2026-06-18T01:35Z
- **By:** player055  ·  **Channel:** #report  ·  **ref:** 100000000000000476/100000000000000477

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000327> (`player055` · `100000000000000327`)
**Date / Time:** TODAY

**Description of event / rule broken:**
if you click ESC before getting downed and restrained, it still allows you to suicide

**Evidence:**
none  but it just works

---

### #351 · FIXED · 2026-06-18T02:10Z
- **By:** player038  ·  **Channel:** #report  ·  **ref:** 100000000000000478/100000000000000479

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000455> (`player038` · `100000000000000455`)
**Date / Time:** just now

**Description of event / rule broken:**
Y items dont save to loadouts

**Evidence:**
https://medal.tv/games/arma-3/clips/mWarsQ27Bz37ehabd?invite=cr-MSxNMUEsMjE1Njc0NzAz

---

### #352 · FIXED · 2026-06-18T02:13Z
> staged (deploys next restart b0074): login-price relog exploit. Root = the market-index config seed gave items premium=0, so on relog (before the market factor syncs) the price factor read as the 0.6 FLOOR = buy cheap → sell double. Removed the seed; `fn_marketFactor` now returns full price (1.0) for any unsynced/legacy/`prem≤0` item, so the relog window is full-price, not discounted.
- **By:** player054  ·  **Channel:** #report  ·  **ref:** 100000000000000480/100000000000000481

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000482> (`player054` · `100000000000000482`)
**Date / Time:** just now

**Description of event / rule broken:**
you can log out of server and when you log back in the prices are fucked as in hella low for a few seconds allowing you to buy meth from dealer cheap af and then sell it back for double what you paid

**Evidence:**
_none provided_

---

### #353 · FIXED · 2026-06-18T02:19Z
> staged (deploys next restart b0074): SDAR couldn't cap cartels. `AP_nonCartelGuns` (configuration.sqf) is the BLACKLIST of weapons that don't count toward a cartel cap, and `arifle_sdar_f` was in it. Removed it → SDAR now counts as a cap weapon (all cartels). Blacklist still blocks binos/rangefinder/PDW/SMG_02/shotguns. (oil was already exempt from the blacklist via a separate staged guard; this makes SDAR work at every cartel.)
- **By:** doomba  ·  **Channel:** #report  ·  **ref:** 100000000000000483/100000000000000484

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000485> (`doomba` · `100000000000000485`)
**Date / Time:** just now

**Description of event / rule broken:**
cant cap oil cartel with sdar 
Sdar needs to be added to the list of cappable weapons

**Evidence:**
bite me

---

### #354 · DUP · 2026-06-18T02:20Z
> dup: #353 (cap oil cartel with SDAR)
- **By:** player087  ·  **Channel:** #report  ·  **ref:** 100000000000000486/100000000000000487

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000365> (`player087` · `100000000000000365`)
**Date / Time:** just now

**Description of event / rule broken:**
Cannot cap oil cartel with SDAR

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000488/100000000000000489/201F081.JPG?ex=6a34a786&is=6a335606&hm=21218e7fc91580e8a568d6ee9a5d92d115c260fa7ced1f329c81ee551ed4d154&

---

### #355 · DEFERRED · 2026-06-18T02:21Z
- **By:** player087  ·  **Channel:** #report  ·  **ref:** 100000000000000490/100000000000000491

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000365> (`player087` · `100000000000000365`)
**Date / Time:** just now

**Description of event / rule broken:**
Flag at oil cartell can only get cars

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000488/100000000000000492/2010B91.JPG?ex=6a34a7b9&is=6a335639&hm=be06533b41cafe27f2381d8cba20ff57eda2132e5f8fa46019d67689f9a79451&

---

### #356 · FIXED · 2026-06-18T02:26Z
> staged (deploys next restart): cop weapon screen "loads for a second then disappears." Confirmed via the DB `-SCRIPTERR-` log (recurring 06-13 → 06-18): `ctrlSetText: Type Bool, expected String` in `fn_weaponShopMenu` (title set, `_titleText = weaponShopCfg select 0`). Root = `fn_weaponShopCfg`'s `police_weapons` `_shopName` switch on `call AP_copLevel` had cases 1–7 but **no `default`** — and an SQF switch with no matching case + no default returns the Bool `false`. So any cop whose copLevel reads outside 1–7 (e.g. an admin on cop side = copLevel 0, or a transient unsynced read) got `_shopName = false` → `ctrlSetText false` errored → population aborted → blank/vanished shop. Fix: added `default{"Police Armory"}` to that inner switch (in-place python; giant one-liner; backup `.bak-356`). Now always a string → no crash; valid cops still get their rank-named armory.
- **By:** player056  ·  **Channel:** #report  ·  **ref:** 100000000000000493/100000000000000494

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000416> (`player056` · `100000000000000416`)
**Date / Time:** Just now

**Description of event / rule broken:**
Trying to access cop weapon screen but it does not come up. It loads for a second then disappears

**Evidence:**
_none provided_

---

### #357 · FIXED · 2026-06-18T03:13Z
> staged (deploys next restart b0074): sold a house, still shows 5 owned / can't buy. The buy-limit check is `count AP_houses >= AP_houseLimit` (fn_buyHouse:130, client array). On sell, `fn_handleHouse` mode 2 removed the house from `AP_houses` by EXACT string match `str(getPosATL _building)` — but `AP_houses` reloads from the DB on login (`fn_requestReceived:206`, a saved worldspace string), which won't character-match the live getPosATL. So after a relog the sold house lingered in `AP_houses` → count stayed maxed. Fix: `_fnc_dropHouse` removes by NEAREST stored position (parseSimpleArray + distance2D < 10m; you're standing at the house you're selling), exact-string fallback for same-session. Applied to mode 2 (sell to bank) + mode 4 (sold on market). NOTE: the DB row WAS deleted correctly, so an affected player (player051) can **relog now** to refresh their count to the correct value; the code fix prevents it recurring.
- **By:** player051  ·  **Channel:** #report  ·  **ref:** 100000000000000495/100000000000000496

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000074> (`player051` · `100000000000000074`)
**Date / Time:** just now

**Description of event / rule broken:**
i had 5 houses and sold my 5th one to buy a shed. Says i cant buy anymore houses and that i have 5 still

**Evidence:**
_none provided_

---

### #358 · FIXED · 2026-06-18T03:22Z
> staged (deploys next restart b0074): moonshine truck unobtainable. The distillery action (`fn_setupActions`: "Get the distillery ready") requires a `C_Van_01_fuel_F` carrying `images\moonshineback.jpg`, but that skin was cut in the 308-skin de-brand strip — referenced nowhere, so no working moonshine van existed (plain Van Fuel buys at civ_truck but has no skin). Owner chose RE-ADD: restored the skin as a `_textureArray` entry `[0,"C_Van_01_fuel_F",["civ"],...,"Moonshine","images\moonshineback.jpg"]` (id 0 = default/only skin for that class; asset `images/moonshineback.jpg` still present). Now buying the Van (Fuel) at the civ_truck shop carries the Moonshine skin → getObjectTextures includes the path → distillery action fires. In-place python edit (giant one-liner; backup `.bak-moonshine`). ⚠️ NEEDS IN-GAME TEST: confirm the van spawns skinned + the "Get the distillery ready" scroll appears (the getObjectTextures path-match is a reconstruction).
- **By:** player051  ·  **Channel:** #report  ·  **ref:** 100000000000000497/100000000000000498

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000074> (`player051` · `100000000000000074`)
**Date / Time:** just now

**Description of event / rule broken:**
Im at the rv shop trying to purchase the moonshine truck but i can only get the fuel truck or a box truck lol

**Evidence:**
_none provided_

---

### #359 · FIXED · 2026-06-18T03:47Z
> staged (deploys next restart b0074): Shift+Click custom map waypoints faded ~10s after closing the map. Root = the difficulty profile (`deploy/looneybin.Arma3Profile`, CustomDifficulty) had `waypoints = 1` (Fade Out). Set to `2` (Always Show) — dedicated waypoint-indicator setting, no effect on group dots (`groupIndicators`). Covers dups #365 + #371. NOT a script issue (no showHUD).
- **By:** player058  ·  **Channel:** #report  ·  **ref:** 100000000000000499/100000000000000500

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000501> (`player058` · `100000000000000501`)
**Date / Time:** just now

**Description of event / rule broken:**
Waypoints disappear from the HUD 10 seconds after closing the map.

**Evidence:**
https://youtu.be/hdBYYMDqTFI

---

### #360 · NEEDINFO · 2026-06-18T03:55Z
- **By:** player046  ·  **Channel:** #report  ·  **ref:** 100000000000000502/100000000000000503

> **INVESTIGATED (2026-06-21) — no member cap; needs a clip.** Read the entire temp-group system end-to-end: NO 2-3 member cap anywhere (join is global, all member loops uncapped). The 'more than 2-3' is symptom magnitude. The real complaint is visual: the custom hex renderer (fn_coloredHexes.sqf) draws every groupmate with the VIEWER's own color + drops icons for members who never picked one -> 'buggy hexs / players dont show proper' (only with custom hex mode ON). Fix needs an owner intended-behavior call (per-member color vs viewer color) + a clip from player046 (he had none). Not blind-fixing per protocol. DEFERRED pending clip.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000504> (`player046` · `100000000000000504`)
**Date / Time:** here and there groups buggy hexs and players dont show proper

**Description of event / rule broken:**
making group and having more than 2 or 3 in it

**Evidence:**
dont have clipping rn

---

### #361 · FIXED · 2026-06-18T04:05Z
> staged (deploys next restart b0074): hands-up (TAB → `AP_surrendered`) didn't cancel the `Acts_carFixingWheel` kneel-and-fix actions → stuck mid-repair, shot for non-compliance. Added a `AP_surrendered` exit check to each action's progress loop: `fn_repairTruck`, `fn_fixFiringPin`, `fn_jewelryEmporium`, `fn_medicRepairBuilding` (the loop exit then stops the anim via the existing `[] spawn AP_fnc_handleAnim`). Also: `fn_fixFiringPin` now cancels on **ESC** too (`!isNull (findDisplay 49)`, the pause menu — owner's addendum); and `fn_repairTruck` no longer plays its get-up recovery anim when the interrupt was the surrender (would've overridden the hands-up pose). ⚠ in-game RP test (visual: confirm hands-up shows promptly when cancelling a repair).
- **By:** doomba  ·  **Channel:** #report  ·  **ref:** 100000000000000505/100000000000000506

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000485> (`doomba` · `100000000000000485`)
**Date / Time:** N/A

**Description of event / rule broken:**
Hands up action (TAB KEY) (AP_surrendered and fn_keyDownHandler.sqf around line 80ish if I recall) doesn't cancel other animations like for example, the repair animation (fn_repairTruck.sqf). Needs to or else players can get shot for non-compliance in a roleplay situation. Same animation used elsewhere 
fn_fixFiringPin.sqf
fn_medicRepairBuilding.sqf
fn_jewelryEmporium.sqf

Routed through AP_fnc_handleAnim

Triage at level 3. Should be a simple fix in the AM. 

Addendum: This should also cancel the "Fix firing pin" function along with hitting ESC

**Evidence:**
None needed

---

### #362 · DUP · 2026-06-18T04:11Z
> dup: #372 (vehicle-trunk store↔repull dupe — fix STAGED b0074)
- **By:** player054  ·  **Channel:** #report  ·  **ref:** 100000000000000507/100000000000000508

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000482> (`player054` · `100000000000000482`)
**Date / Time:** just now

**Description of event / rule broken:**
so its quick difficult to time this but i did it after 3 tries just to see if it worked but you can have someone take from Y inventory of a vehicle as the other person stores the vehicle and you get the item and its also still in the vehicle when you pull it back out told you im good at finding shit lmaoooo

**Evidence:**
none but happy to show you on stream next time i see you

---

### #363 · FIXED · 2026-06-18T05:18Z
> staged (deploys next restart b0074): concurrent-seize money dupe. Root = the `AP_seizing` lock that's meant to block a 2nd cop was CLIENT-side (check + async public `setVariable`), so two cops both passed it before either broadcast landed → both ran the seize → `APS_fnc_copSplit` fired twice = everyone paid double (repeatable). Affected ALL THREE seize flows that pay copSplit (`fn_vehBaseSeize`, `fn_vehicleInvSeize`, `fn_seizeIllegalTent`). Fix = new server fn `APS_fnc_seizeLock` doing an ATOMIC test-and-set of the lock, called UNSCHEDULED via remoteExecCall (can't be time-sliced mid-sequence) → exactly one cop wins; loser instantly gets "already being seized," no wasted bar. 30s stale auto-release (cop dc/crash safe). AP_seizing kept as a broadcast bool for the existing readers (openInv etc.); atomic key lives in server-only AP_seizeLockMeta. Registered in config.cpp + CfgRE.hpp (allowedTargets=2).
- **By:** player031  ·  **Channel:** #report  ·  **ref:** 100000000000000509/100000000000000510

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000370> (`player031` · `100000000000000370`)
**Date / Time:** just now

**Description of event / rule broken:**
if two people sieze an illigal vehicle on cop at the same time it doesnt seize, and gives both players money. can be repeated over and over

**Evidence:**
black

---

### #364 · FIXED · 2026-06-18T05:31Z
> staged (deploys next restart b0074): "robbed bank and briefcase didn't spawn" = same root as the owner's "briefcases spawn outside the vault" (#376). `fn_bankDrillVault` spawned the briefcases at a HARDCODED `_casePos` (~[14786.6,10755.8]) that was ~28m from the vault door marker `AP_bank_door` ([14768,10729.6], where the drill + player actually are) — the bank building (`Land_Offices_01_V1_F`, now [14776.6,10734.3]) was moved and the coords never updated → cases spawned out in the open / looked un-spawned. Fix: override `_casePos` to anchor on the door marker, offset ~2m toward the building interior (inside the vault), clustered 2×5. Robust to the bank's actual position. ⚠ verify the inside-offset in-game (tune the 2m / Z if needed).
- **By:** player065  ·  **Channel:** #report  ·  **ref:** 100000000000000511/100000000000000512

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000513> (`player065` · `100000000000000513`)
**Date / Time:** just now

**Description of event / rule broken:**
robbed bank and briefcase didnt spawn

**Evidence:**
_none provided_

---

### #365 · DUP · 2026-06-18T05:59Z
> dup: #359 (map waypoint / shift-click marker fades ~10s)
- **By:** player026  ·  **Channel:** #report  ·  **ref:** 100000000000000514/100000000000000515

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000516> (`player026` · `100000000000000516`)
**Date / Time:** the shift left click to mark on the map disappears

**Description of event / rule broken:**
the shift left click to mark on the map disappears

**Evidence:**
non

---

### #366 · WONTFIX · 2026-06-18T07:04Z
- **By:** player013  ·  **Channel:** #report  ·  **ref:** 100000000000000517/100000000000000518

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000519> (`player013` · `100000000000000519`)
**Date / Time:** 10:50 PM PST 2026-06-18

**Description of event / rule broken:**
drug dealer while selling sativa seeds

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000520/100000000000000521/9180db31bfc48635d2437ea239d338b8.png?ex=6a34ea0a&is=6a33988a&hm=1f3c59fc752e93aae0922b59c11a2bea429a0654335ebee0611feac992092dd2&

---

### #367 · FIXED · 2026-06-18T08:36Z
> staged (deploys next restart b0074): relog with a vehicle in the world → can lock/unlock but can't open the trunk until you store+pull. `AP_vehicles` = the client KEYCHAIN; the trunk keybind (fn_keyDownHandler ~259/276/288) gates on `veh in AP_vehicles`. Login rebuilds the keychain from a server list (`_this select 18`) that misses out-in-world vehicles (stream-in timing, same class as the house #305 miss) → no key in keychain → no trunk. Lock/unlock use `AP_vehOwners` (the PERSISTED owner/keyholder list) which IS restored → they work. Fix: on trunk-key press, if you're in the vehicle's `AP_vehOwners` but it's not in `AP_vehicles`, restore the key (`pushBackUnique`) → the checks pass. keyDrop clears AP_vehOwners, so a key you intentionally dropped won't re-grant. Owners always match; passengers/non-owners don't.
- **By:** player095  ·  **Channel:** #report  ·  **ref:** 100000000000000522/100000000000000523

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000119> (`player095` · `100000000000000119`)
**Date / Time:** today

**Description of event / rule broken:**
when you leave and rejoin the server with your vehicle you are unable to access the truck only lock and unlock features, you have to store the vic and pull it out again to get it out

**Evidence:**
https://medal.tv/games/arma-3/clips/mWdsFo4LETjIk-9W0?invite=cr-MSxrOXgsMjIxMTM2MDMw&v=123

---

### #368 · FIXED · 2026-06-18T14:16Z
> triage 2026-07-04 (bugs-triage): was NEEDTEST, code-verified FIXED — server/AP_server/init.sqf:376 · init.sqf:376 runs DB_fnc_updateCaptures inside the 8-min periodic save, so cartel/turf ownership persists through manual restarts.
- **By:** player015  ·  **Channel:** #report  ·  **ref:** 100000000000000524/100000000000000525

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000229> (`player015` · `100000000000000229`)
**Date / Time:** just now

**Description of event / rule broken:**
Turfs dont pop and cartel owner ship still not going to next restart

> **NEEDTEST** (owner 2026-06-19): cartel-ownership half -- DB_fnc_updateCaptures now also runs in the new 8-min periodic save, so cartel ownership persists through manual restarts/crashes (was graceful-restart-only). The 'turfs dont pop' (turf-spawning) half = FIXED by owner 2026-06-19. The cartel-ownership persistence half still NEEDS testing across a restart.

**Evidence:**
_none provided_

---

### #369 · FIXED · 2026-06-18T15:38Z
> staged (deploys next restart b0074): couldn't store a DMS scope (or any loose weapon attachment) in a house/vehicle — "This item cannot be stored." Root = `fn_storeInventory`'s physical-store guard blocks 0-weight items not in worn-gear/weapons; attachments (`optic_DMS` etc.) have no CfgWeights entry → weight 0, and aren't worn gear → wrongly blocked. Fix: also exempt any valid CfgWeapons class (`isClass (configFile >> "CfgWeapons" >> item)`) — optics/pointers/muzzles/bipods now store; genuine non-storables (no CfgWeapons class) still blocked.
- **By:** player029  ·  **Channel:** #report  ·  **ref:** 100000000000000526/100000000000000527

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000346> (`player029` · `100000000000000346`)
**Date / Time:** just now

**Description of event / rule broken:**
Cant store dms scope in house

**Evidence:**
_none provided_

---

### #370 · FIXED · 2026-06-18T15:39Z
> staged (deploys next restart b0074): gang members couldn't spawn at the gang building. Reworked `fn_spawnPointCfg` (gang-building spawn now driven off `AP_gang_data[3]` HQ pos, not the missing `AP_gangBuilding` object) + `fn_spawnConfirm` (resolves the `gangbldg` spawn from the HQ pos via nearestObjects→buildingPos, HQ-pos fallback). Any gang member, owner offline OK.
- **By:** player029  ·  **Channel:** #report  ·  **ref:** 100000000000000528/100000000000000529

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000346> (`player029` · `100000000000000346`)
**Date / Time:** anytime

**Description of event / rule broken:**
gang members cant spawn in gang building.
Tried all teirs, after restart etc

**Evidence:**
_none provided_

---

### #371 · DUP · 2026-06-18T16:19Z
> dup: #359 (map waypoint / shift-click marker fades ~10s)
- **By:** player013  ·  **Channel:** #report  ·  **ref:** 100000000000000530/100000000000000531

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000519> (`player013` · `100000000000000519`)
**Date / Time:** 2026-06-17 around 11 PM PST

**Description of event / rule broken:**
Shift+Left Click waypoints fade away on screen after about 10 seconds. Can only bring it back by opening map, but it still fades again after 10 seconds.

**Evidence:**
_none provided_

---

### #372 · FIXED · 2026-06-18T16:40Z
- **By:** owner (direct)  ·  **Channel:** direct  ·  **ref:** —

Anti-cheat / economy exploit: vehicle-trunk store↔repull item duplication (owner-reported direct; player099 + player100, plate 179067, ~23:11 CDT 2026-06-17). Title carries EXCLUDE keywords on purpose — never shown to players.

**Root cause:** trunk inventory `AP_vinv` (+`AP_pinv`) is mutated CLIENT-side via public `setVariable[...,true]` that reaches the server ASYNC. The garage/impound/gang-store serialize paths read `AP_vinv` SERVER-side then `deleteVehicle` — a store fired mid-take read the PRE-take trunk, so the DB row kept an item the player had already pocketed → re-pull = dupe. (Logs: `-VEHINV-` close shows `Owner: NoVehData` = vehicle deleted DURING the take.) The "single source of truth" active=0 design was defeated by client→server propagation lag.

**Resolution (STAGED, deploys next restart b0074):** server-side trunk SETTLE before every attacker-controlled active=0 serialize-and-delete. `fn_vehicleStore` (personal + impound) + `fn_gangGarageStore` set `AP_trunkLock=true` (the `fn_openInventory` monitor force-closes any open dialog; new open-time guard blocks reopen) then `uiSleep 1.25` so any in-flight take broadcast lands before snapshotting `AP_vinv`+cargo. Lock cleared on the two store validation-fail exits; delete handles the rest. Cleanup path left alone (idle-reset makes the race unreachable; bulk loop). CLANKR: new live per-plate store↔repull cycling rule (`-VEHICLEPULL-` ≥3 same plate <300s, HIGH) + `loonybot/scan_trunk_dupe.py` retro-scan. Confirmed haul (read-only, resurrection-verified): player099 ~300 cannas_0 + 96 bluemeth + 3 rubber; player100 6 soda + 1 rubber (testing-scale). Scan also surfaced player102 (144 ephedrau) + player101 (192 cannabis — player101 is admin, verify legit vs test). Residual: a take broadcast slower than 1.25s (= unplayable lag) — caught by the clankr rule anyway.

---

### #373 · NOTABUG · 2026-06-18T16:44Z
> notabug: screenshot = "Tempest [Device]" trunk at 1350/1350 (4452 cocaine). That's the legit storage upgrade: `O_Truck_03_device_F` base virtual cap = 1250 (fn_vehicleConfig), + the garage "+100 Storage" mod (fn_garageModMenu offers Base/+50/+75/+100, applied in fn_prepareVehicle:33 as `getVirtCap + _mods[1]`) = 1350. Capped, working as designed. Reporter saw a feature. (Owner declined the optional balance change to block storage upgrades on gathering-device trucks.)
- **By:** player083  ·  **Channel:** #report  ·  **ref:** 100000000000000532/100000000000000533

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000226> (`player083` · `100000000000000226`)
**Date / Time:** now

**Description of event / rule broken:**
expanded vehicle inventory limit

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000534/100000000000000535/image.png?ex=6a3571ec&is=6a34206c&hm=8691f69b3dad2ce876d2de3db52310d94c74d4a280c1768f57ec2507ec6b397a&

---

### #374 · FIXED · 2026-06-18T16:46Z
> staged (deploys next restart b0074): house tax paid → relog → charged again (~40k ×2 = money loss). Root = `fn_houseTaxSRV` paid with `UPDATE houses SET tax_paid=NOW(), tax_playtime=0 WHERE id='%1'`, but the client sends `_houseID = AP_houseID = the house OID` (init.sqf:444), NOT the `id` PK. So the WHERE matched the wrong row / nothing → `tax_paid` never updated (the atm-charge on the line above ran regardless) → on relog `DATEDIFF(NOW(),tax_paid)` stayed high → house showed unpaid + charged again. Broken for ALL house-tax payers since the 6-09 stub. Fix = `WHERE oid='%1'` (oid is `varchar(32) UNIQUE`, the identity key the rest of the system uses). NOTE: houses have accrued "back tax" the whole broken period — owner deciding clean-slate reset + comp for over-charged players (separate from the code fix).
- **By:** player037  ·  **Channel:** #report  ·  **ref:** 100000000000000536/100000000000000537

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000538> (`player037` · `100000000000000538`)
**Date / Time:** just now

**Description of event / rule broken:**
i payed my house tax, logged off and when i logged on it says i haven't payed it, twice its happened to me and both times its took almost 40k from my account

**Evidence:**
_none provided_

---

### #375 · FIXED · 2026-06-18T17:10Z
- **By:** owner (direct)  ·  **Channel:** direct  ·  **ref:** —

Cadets on death sometimes get the undercover (SCD) loadout instead of the default cadet loadout.

> staged (deploys next restart b0074): root = `fn_copLoadout.sqf:5` gave SCD/undercover gear when `AP_copRole == "all"` OR an SCD slot. `AP_copRole` is set to "all" for **adminLevel≥3 OR copLevel≥6** (fn_initCop:48), so an ADMIN playing a low-rank cop (cadet) got "all" → undercover gear on every respawn (fn_respawned:26). "Sometimes" = whenever an admin plays a cadet; a non-admin cadet can never be "all" or take an SCD slot (init blocks it), so they were never affected. Owner's call (keep real captains undercover): gated the "all" clause on `(call AP_copLevel) >= 6`, so admins below Captain get their RANK loadout; real Captains (copLevel≥6) + SCD slots still go undercover. Default cadet loadout (kept): U_Rangemaster (cadet skin) · V_Rangemaster_belt · H_Cap_police · SMG_05_F + optic_ACO_grn_smg (7 mags) · hgun_P07_F + suppressor (3 mags) · 2 SmokeShell · Binocular/Map/Compass/GPS · medkits · debitcard.

---

### #376 · FIXED · 2026-06-18T17:30Z
- **By:** owner (direct)  ·  **Channel:** direct  ·  **ref:** —

Bank briefcases spawn outside of the vault once it's opened.

> staged (deploys next restart b0074): same fix as #364. `fn_bankDrillVault` spawned briefcases at hardcoded `_casePos` ~28m from the vault door (`AP_bank_door`) — the bank building moved, coords never updated. Re-anchored on the door marker + ~2m inside toward the building, clustered. ⚠ verify the inside-offset in-game. See #364 for detail.

---

### #377 · FIXED · 2026-06-18T19:40Z
> triage 2026-07-04 (bugs-triage): was NEEDTEST, code-verified FIXED — server/AP_server/core/bank/fn_bankDrillVault.sqf:199 · Briefcases now spawn at the owner-supplied Altis vault-interior coord [14765.7,10732,0.44] instead of the exterior door marker, resolving the pending-coord note
- **By:** player055  ·  **Channel:** #report  ·  **ref:** 100000000000000539/100000000000000540

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000327> (`player055` · `100000000000000327`)
**Date / Time:** now

**Description of event / rule broken:**
dirty money briefcases spawn outside of bank in the front after drill finishes

**Evidence:**
_none provided_

> note (owner): this is the #364/#376 fix still wrong — my b0074 fix re-anchored the briefcases on the `AP_bank_door` marker + 2m inside, but that marker is the EXTERIOR drill spot (front of the bank), so they still land out front. I can't derive the real vault-interior position without loading the map. PENDING the correct spot from owner (stand inside the vault → run `copyToClipboard str (getPosATL player)` in the debug console → paste it). Then I anchor the cluster there.

---

### #378 · FIXED · 2026-06-18T19:45Z
> staged (deploys next restart): bank drill progress bar blocked other actions' progress bars (rez/lockpick). Root = the drill HUD loop (initPlayerLocal) was moved onto the SHARED `AP_progress` layer (5, ctrls 38201/38202) — same layer rez/lockpick/repair use — so the bank HUD's `cutText ""` nuked another action's freshly-`cutRsc`'d bar. Reverted to the dedicated `AP_bank_hud` RscTitle (own layer 2470, ctrls BankBar 247012 / BankTimer 247011, idd 247003 — still defined in chat_hud.hpp). Dropped the `!AP_action_in_use` gate (only added to dodge the conflict) so the drill % shows mid-action too.
- **By:** player055  ·  **Channel:** #report  ·  **ref:** 100000000000000541/100000000000000542

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000327> (`player055` · `100000000000000327`)
**Date / Time:** just now

**Description of event / rule broken:**
So when you start a bank you have the bank progress bar at the top, but if you attempt to do any other action with a progress bar, you cant see it. For example if you attempt to rez or lockpick something you cant see the progress bar for that action, its just make the bank bar glitch out.

**Evidence:**
_none provided_

---

### #379 · FIXED · 2026-06-18T21:28Z
> triage 2026-07-04 (bugs-triage): was NEEDTEST, code-verified FIXED — mission/LooneyBin.Altis/CfgSounds.hpp:20-21 (+ fn_loonyBin.sqf progress bars) · The previously-missing loonyBinThermite CfgSounds classes were added (fixing the silent step) and every loony-bin step in fn_loonyBin.sqf drives a progress-bar 
- **By:** player029  ·  **Channel:** #report  ·  **ref:** 100000000000000543/100000000000000544

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000346> (`player029` · `100000000000000346`)
**Date / Time:** just now

**Description of event / rule broken:**
mental asylum start no sounds, timers on any of the steps

**Evidence:**
_none provided_

---

### #380 · NEEDTEST · 2026-06-18T21:52Z
- **By:** player055  ·  **Channel:** #report  ·  **ref:** 100000000000000545/100000000000000546

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000327> (`player055` · `100000000000000327`)
**Date / Time:** now

**Description of event / rule broken:**
Mental Testing Notes:

DEMO WORKS AND BLOWS UP FRONT GATE 
BACK WALL DOES NOT BLOW UP WHEN WE BLOW UP FRONT GATE
thermite works on loony bin door but no progress bar for the 10 minutes
no explosion happens for thermite and box remains on front door
loonybin door is unlocked even before thermite blows up front door

**Evidence:**
after doing the trojan usb for the five laptops, the curch door was already unlocked
it gave us a code but no patient remains nor a tempest spawned in

---

### #381 · NEEDTEST · 2026-06-18T22:27Z
- **By:** player055  ·  **Channel:** #report  ·  **ref:** 100000000000000547/100000000000000548

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000327> (`player055` · `100000000000000327`)
**Date / Time:** now

**Description of event / rule broken:**
you can click escape and log out while in cop restraints

**Evidence:**
none, easily replicated

---

### #382 · FIXED · 2026-06-18T22:41Z
> triage 2026-07-04 (bugs-triage): was NEEDTEST, code-verified FIXED — mission/LooneyBin.Altis/core/functions/fn_loadDeadGear.sqf:119 · loadDeadGear now loads a compatible inventory mag into any still-empty weapon on revive (comment explicitly cites #382), so revived guns are no longer empty.
- **By:** player029  ·  **Channel:** #report  ·  **ref:** 100000000000000549/100000000000000550

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000346> (`player029` · `100000000000000346`)
**Date / Time:** just now

**Description of event / rule broken:**
after defib when you get up you have no bullets in your guns

**Evidence:**
_none provided_

---

### #383 · FIXED · 2026-06-18T22:45Z
> triage 2026-07-04 (bugs-triage): was NEEDTEST, code-verified FIXED — server/AP_server/core/TON/fn_srvMobileHQ.sqf:44 · Mobile HQ command post is now offset [0,-11,0] behind the ~8.5m truck (no longer spawns inside it) and each deployed object has allowDamage false (line 36), so 
- **By:** player040  ·  **Channel:** #report  ·  **ref:** 100000000000000551/100000000000000552

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000553> (`player040` · `100000000000000553`)
**Date / Time:** 2026-06-18 1900 AST

**Description of event / rule broken:**
Mobile police HQ deploys a command center in part of the vehicle which caused it to blow up about 30 secs after it spawned in

**Evidence:**
_none provided_

---

### #384 · NEEDINFO · 2026-06-18T22:49Z
- **By:** player097  ·  **Channel:** #report  ·  **ref:** 100000000000000554/100000000000000555

> Only a gyazo link, no text (player097) — can't classify without the image. Needs a description.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000556> (`player097` · `100000000000000556`)
**Date / Time:** now

**Description of event / rule broken:**
https://gyazo.com/9a0325e4c64181804e24feb0774c38cd

**Evidence:**
_none provided_

---

### #385 · FIXED · 2026-06-18T23:31Z
> fixed: marked fixed per owner 2026-06-21 (owner-dispositioned).
- **By:** player029  ·  **Channel:** #report  ·  **ref:** 100000000000000557/100000000000000558

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000346> (`player029` · `100000000000000346`)
**Date / Time:** just now

**Description of event / rule broken:**
weapon attachments goes the the void if you already have them on you gun
also can i get 200k comp 
https://medal.tv/games/arma-3/clips/mWx7kb7GQtdsIo300?invite=cr-MSw4d3ksNDE2MzgzMTYx

**Evidence:**
sent

---

### #386 · FIXED · 2026-06-19T00:19Z
> triage 2026-07-04 (bugs-triage): was NEEDTEST, code-verified FIXED — mission/LooneyBin.Altis/core/actions/fn_storeVehicle.sqf:11 · The gang-fort/off-vehicle store radius was widened in response to #386 and later tuned to 40m specifically so large airframes (Blackfish) on the pad are storabl
- **By:** player039  ·  **Channel:** #report  ·  **ref:** 100000000000000559/100000000000000560

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000183> (`player039` · `100000000000000183`)
**Date / Time:** just now

**Description of event / rule broken:**
increase the range of storing vehicle at gang fort for the helis on the pad

**Evidence:**
_none provided_

---

### #387 · NOTABUG · 2026-06-19T00:38Z
- **By:** player051  ·  **Channel:** #report  ·  **ref:** 100000000000000561/100000000000000562

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000074> (`player051` · `100000000000000074`)
**Date / Time:** just now

**Description of event / rule broken:**
I still dont think the dynamic market is working as intended. The prices have stayed the exact same since it was introduced. And some stuff on wongs hasnt changed at all. like uranium and moonshine. But scotch did a little bit

**Evidence:**
_none provided_

---

### #388 · NEEDINFO · 2026-06-19T01:27Z
- **By:** player052  ·  **Channel:** #report  ·  **ref:** 100000000000000563/100000000000000564

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000565> (`player052` · `100000000000000565`)
**Date / Time:** just now

**Description of event / rule broken:**
theres no heli garage at the bounty hunter base

> **NEEDINFO** (owner 2026-06-19): I just tested every skiptracer and each one has a heli garage, do you have a BH licence?

**Evidence:**
_none provided_

---

### #389 · FIXED · 2026-06-19T01:33Z
- **By:** player087  ·  **Channel:** #report  ·  **ref:** 100000000000000566/100000000000000567

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000365> (`player087` · `100000000000000365`)
**Date / Time:** just now

**Description of event / rule broken:**
I spawned a orca at Drug Runner 4 and it disappeared and deleted from garadge. So i gues this is a bug report and comp report.

> **FIXED** (owner 2026-06-19): resolved. Mid-session live deletion (vehicleDead/cleanup), separate from the restart-loss persistence cluster.

**Evidence:**
https://medal.tv/games/arma-3/clips/mWz6sFmcdBN9TOTBZ?invite=cr-MSxUN3gsMzEzODExMDY5&v=38

---

### #390 · FIXED · 2026-06-19T03:40Z
- **By:** player094  ·  **Channel:** #report  ·  **ref:** 100000000000000568/100000000000000569

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000461> (`player094` · `100000000000000461`)
**Date / Time:** just now

**Description of event / rule broken:**
Not sure it's exactly a  bug, but the weapon is listed as illegal. As an avid shotgun enthusiast, please allow us to capture cartels with one <a:peepoShotgunpump:100000000000000570>

**Evidence:**
Inside the circle of Wong's, no status bar. I am not looking for comp, pls <a:PLS:100000000000000571>
https://cdn.discordapp.com/attachments/100000000000000572/100000000000000573/image.png?ex=6a360ba8&is=6a34ba28&hm=6d13bd3354001da9b362d09295bcaf01d150198346121c966ed419877d3339cd&

---

### #391 · NOTABUG · 2026-06-19T06:05Z
- **By:** player036  ·  **Channel:** #report  ·  **ref:** 100000000000000574/100000000000000575

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000092> (`player036` · `100000000000000092`)
**Date / Time:** just now

**Description of event / rule broken:**
so cops can just bypass any type of scripted way of searching a house and are able to just press T to open shed possibly even all house inventory

**Evidence:**
_none provided_

---

### #392 · FIXED · 2026-06-19T06:15Z
- **By:** player036  ·  **Channel:** #report  ·  **ref:** 100000000000000576/100000000000000577

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000092> (`player036` · `100000000000000092`)
**Date / Time:** just now

**Description of event / rule broken:**
selling a shed to another player can bug out taking the asking price from the person buying and only refunding them the base cost of the house (200k for shed) saying the purchase has been denied because the house is already owned, the funds of 200k has been returned to your bank balance

**Evidence:**
_none provided_

---

### #393 · FIXED · 2026-06-19T08:39Z
- **By:** player057  ·  **Channel:** #report  ·  **ref:** 100000000000000578/100000000000000579

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000580> (`player057` · `100000000000000580`)
**Date / Time:** now

**Description of event / rule broken:**
i got dirty money from gas station, i logged out, when i logged in now it stays dirty

**Evidence:**
_none provided_

---

### #394 · NOTABUG · 2026-06-19T08:54Z
- **By:** player036  ·  **Channel:** #report  ·  **ref:** 100000000000000581/100000000000000582

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000092> (`player036` · `100000000000000092`)
**Date / Time:** just now

**Description of event / rule broken:**
Tempest device cant mine at Quarry

**Evidence:**
_none provided_

---

### #395 · FIXED · 2026-06-19T09:50Z
- **By:** player057  ·  **Channel:** #report  ·  **ref:** 100000000000000583/100000000000000584

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000580> (`player057` · `100000000000000580`)
**Date / Time:** now

**Description of event / rule broken:**
fishing, everytime u catch a fish over 1kg it triggers a new acheivment, basically it doesnt remember your acheivments

**Evidence:**
_none provided_

---

### #396 · NOTABUG · 2026-06-19T13:34Z
- **By:** player055  ·  **Channel:** #report  ·  **ref:** 100000000000000585/100000000000000586

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000327> (`player055` · `100000000000000327`)
**Date / Time:** now

**Description of event / rule broken:**
Mental Asylum is still set to 0 cops, so im running it as we speak to find any bugs. (DID NOT TAKE ANY REWARDS)

**Evidence:**
_none provided_

---

### #397 · INVALID · 2026-06-19T15:34Z
- **By:** player029  ·  **Channel:** #report  ·  **ref:** 100000000000000587/100000000000000588

> **WORKING AS DESIGNED (2026-06-21).** Ifrit (B_MRAP_01_F) front glass taking ~30 DMR rounds to crack = base-Arma armored-MRAP glass. The custom heavy-vehicle damage scaling in fn_handleVehicleDamage (0.15/0.35) applies ONLY to COLLISION damage (`isNull _source && _projectile==''`), NOT bullets -> glass-vs-bullets is vanilla. Not a code bug; the Ifrit is meant to be bulletproof.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000346> (`player029` · `100000000000000346`)
**Date / Time:** Anytime

**Description of event / rule broken:**
Bug

**Evidence:**
Ifrit front glass seems off, takes about 30 rounds from an mk1 just to crack when you are above it looking down meaning it should normally be a 1 shot kill

---

### #398 · FIXED · 2026-06-19T16:31Z
- **By:** player087  ·  **Channel:** #report  ·  **ref:** 100000000000000589/100000000000000590

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000365> (`player087` · `100000000000000365`)
**Date / Time:** just now

**Description of event / rule broken:**
When server restarts helis spawn belly up or on its side i have lost 2 orcas from this rolling down hills or unflipping

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000488/100000000000000591/20C43F1.JPG?ex=6a36c074&is=6a356ef4&hm=69fc187a4ccc1a03583cee5e1eadcfe89b6667c9b086f0a99c5284abdbc686fe&

---

### #399 · FIXED · 2026-06-19T17:21Z
- **By:** player029  ·  **Channel:** #report  ·  **ref:** 100000000000000592/100000000000000593

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000346> (`player029` · `100000000000000346`)
**Date / Time:** just now

**Description of event / rule broken:**
on connecting loonybinthermite loop something missing error

**Evidence:**
_none provided_


> staged: "loonyBinThermiteLoop"/"loonyBinThermiteEnded" (Loony Bin thermite phase, fn_loonyBin.sqf) were say3D'd but had NO CfgSounds class -> engine "sound not found" RPT spam (what the reporter saw) + silent thermite. FIXED: declared both in CfgSounds.hpp reusing on-disk oggs (jewelrySafeTorchLoop = burn loop, break = burn-through).
---

### #400 · FIXED · 2026-06-19T17:33Z
- **By:** player044  ·  **Channel:** #report  ·  **ref:** 100000000000000594/100000000000000595

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000596> (`player044` · `100000000000000596`)
**Date / Time:** Just now

**Description of event / rule broken:**
When looking at a players name, if they are have a title it will cut the rest in half.

**Evidence:**
https://gyazo.com/8bcfdba490799bef156a9622ab5fc32f


> staged: over-head tag (fn_playerTags) stacks up to 3 structured-text lines (name + gang/group + title) into the AP_hud_nametags control, which was only h=0.05 (~2 lines) -> a title overflowed and clipped the name. FIXED: chat_hud.hpp AP_NameTagBase h 0.05 -> 0.10 (box grows downward from the head; single-line tags unaffected).
---

### #401 · FIXED · 2026-06-19T17:44Z
- **By:** player097  ·  **Channel:** #report  ·  **ref:** 100000000000000597/100000000000000598

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000556> (`player097` · `100000000000000556`)
**Date / Time:** today

**Description of event / rule broken:**
You keep sui vest after being sent to jail

**Evidence:**
_none provided_


> staged: sui vest = contraband V_HarnessOGL_brn. jailMe strips it on ENTRY, but fn_loadGear restored the full saved loadout (incl. vest) on RELEASE and only stripped weapons. FIXED: fn_loadGear now confiscates the sui vest on jail release; fn_suicideVest also blocks self-detonation while serving time (AP_is_arrested).
---

### #402 · NEEDINFO · 2026-06-19T17:50Z
- **By:** player061  ·  **Channel:** #dm  ·  **ref:** 100000000000000599/100000000000000600

dupe


> needinfo: report body is just "dupe" with no method/steps. Need the exact repro from player061 before it can be actioned. Paired with #403.
---

### #403 · NEEDINFO · 2026-06-19T17:51Z
- **By:** player061  ·  **Channel:** #report  ·  **ref:** 100000000000000601/100000000000000602

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000603> (`player061` · `100000000000000603`)
**Date / Time:** money for dupe was taken off me?

**Description of event / rule broken:**
money for dupe was taken off me?

**Evidence:**
_none provided_


> needinfo: "money for dupe taken off me" -- likely the 2026-06-12 pre-launch DB wipe erasing a pre-launch comp (same pattern as the player109 1.2M trace). Confirm with player061 what dupe + when comped.
---

### #404 · INVALID · 2026-06-19T18:05Z
- **By:** player083  ·  **Channel:** #report  ·  **ref:** 100000000000000604/100000000000000605

> Empty/garbage report (':' / ',') — no content.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000226> (`player083` · `100000000000000226`)
**Date / Time:** .

**Description of event / rule broken:**
:

**Evidence:**
,

---

### #405 · FIXED · 2026-06-19T18:09Z
- **By:** player071  ·  **Channel:** #report  ·  **ref:** 100000000000000606/100000000000000607

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000178> (`player071` · `100000000000000178`)
**Date / Time:** you can attach a speed bomb as they drive/fly away the animation dose not stop

**Description of event / rule broken:**
you can attach a speed bomb as they drive/fly away the animation dose not stop

**Evidence:**
you can attach a speed bomb as they drive/fly away the animation dose not stop


> staged: the distance check ran BEFORE the 3.5s arm-sleep, so a vehicle that drove/flew off during arming still got bombed AND the kneel animation never stopped. FIXED: fn_speedbomb arms DURING the anim, switchMove "" stops it, then re-validates distance (refund if gone).
---

### #406 · FIXED · 2026-06-19T19:38Z
- **By:** player044  ·  **Channel:** #report  ·  **ref:** 100000000000000608/100000000000000609

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000596> (`player044` · `100000000000000596`)
**Date / Time:** just now

**Description of event / rule broken:**
When trying to seize an ifrit it completes the seize and pays you, but does not actually seize the ifrit, I assume this happens with any vehicle being seized.

**Evidence:**
_none provided_


> staged: root = fn_vehicleDead read getVariable "dbInfo", but garage-pulled vehicles (fn_vehicleGaragePull/gangGaragePull) set only "AP_dbInfo" -> count 0 -> exited BEFORE deleteVehicle. Cop seize paid (copSplit) but the vehicle stayed. FIXED: read AP_dbInfo (fallback legacy dbInfo) and ALWAYS deleteVehicle.
---

### #407 · FIXED · 2026-06-19T20:42Z
- **By:** player087  ·  **Channel:** #report  ·  **ref:** 100000000000000610/100000000000000611

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000365> (`player087` · `100000000000000365`)
**Date / Time:** nopw

**Description of event / rule broken:**
Everyone can talk in sidechat

**Evidence:**
no


> staged: fn_manageSidechat (#326 rewrite) ran `1 enableChannel [_enable,_enable]` -> re-enabled side VOICE for the local player (default on), overriding the global disableChannels {1,false,true} voice-off. FIXED: pinned side voice to false; the toggle now controls side TEXT only.
---

### #408 · FIXED · 2026-06-19T21:01Z
- **By:** player029  ·  **Channel:** #report  ·  **ref:** 100000000000000612/100000000000000613

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000346> (`player029` · `100000000000000346`)
**Date / Time:** just now

**Description of event / rule broken:**
i was alive when i got off, now when i got on i just got a respawn screen.
had hella good kit with suppressor and dms etc

**Evidence:**
i can upload my respawn screen at logon if you wanna see lol

> staged (b0078, ships next pack -- clean patchnote line added at deploy): KIT-LOSS / RESPAWN-SCREEN ON RESTART cluster (#408/#409/#413/#414/#416/#417/#418, +#415). Root: NO restart path force-saves online players' LIVE state. Civ gear persisted only on inventory CHANGE + the T-55 scheduled-restart sync; position only every 240s (mode-10 PFH). The graceful save (saveVehicles -> flushAllPlayers) merely DRAINS AP_update_buffer, it does not snapshot clients. A crash / deploy / manual hard-restart (watchdog pkill, no disconnect handler) reverted gear to the last change-save = lost kit; a death+respawn <240s pre-restart left position empty = respawn menu. FIX (2 layers, stage-only): (1) periodic civ gear save added to the 240s PFH (fn_initCiv) -> ungraceful exit loses <=4min not the whole kit; (2) T-0 server-force client gear+pos+money flush (AP_fnc_ClupdateRequest -2) before BOTH graceful-save paths (init.sqf scheduled restart + the gracefulsave bot cmd = !srv softr/hardr/deploys). Server is CfgRE-exempt so the MP runs. Comps: owner handling.

---

### #409 · FIXED · 2026-06-19T21:01Z
- **By:** player038  ·  **Channel:** #report  ·  **ref:** 100000000000000614/100000000000000615

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000455> (`player038` · `100000000000000455`)
**Date / Time:** now

**Description of event / rule broken:**
losing kits after relog

**Evidence:**
anytime you relog you have to respawn and you lose your kit. seems to only have happen after a battle eye error

---

### #410 · FIXED · 2026-06-19T21:09Z
- **By:** player038  ·  **Channel:** #report  ·  **ref:** 100000000000000616/100000000000000617

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000455> (`player038` · `100000000000000455`)
**Date / Time:** now

**Description of event / rule broken:**
owned houses doors are unlocked after restart and or randomly

**Evidence:**
https://medal.tv/games/arma-3/clips/mWU9MpNE9kBAXeFKt?invite=cr-MSwxdFAsMjE1Njc0NzAz


> staged: root = fn_receiveHouses (boot loader) restored the AP_buildingLocked VARIABLE from the DB `locked` column but NEVER disabled the native engine door action (bis_disabled_Door_N) like fn_lockHouse does. AP_buildingLocked only gates the custom storage-open, not the physical door -> after every restart the "Open Door" action was ENABLED on every owned house = anyone walked in (and "randomly" as buildings streamed in). FIXED: receiveHouses now disables + closes each door (global) for any house whose DB row is locked=1 (the default). Owners enter by toggling the existing "Toggle All House Locks" action. NOTE: fn_lockHouse still doesn't persist toggles to the `locked` column, so houses always re-lock on restart (the safe direction).
---

### #411 · FIXED · 2026-06-19T21:29Z
> fixed: marked fixed per owner 2026-06-21 (owner-dispositioned).
- **By:** player029  ·  **Channel:** #report  ·  **ref:** 100000000000000618/100000000000000619

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000346> (`player029` · `100000000000000346`)
**Date / Time:** just now

**Description of event / rule broken:**
if you die with an admin gift it disappears not in new inventory or bodybag

**Evidence:**
i can upload if reqired

---

### #412 · FIXED · 2026-06-19T21:50Z
> resolved 2026-06-21: player083 (76561190000000006 / in-game 'player074') logged in successfully multiple times on 06-20 AFTER this 06-19 report -- not banned, player row intact (gear/lic normal), bank 897k. Transient; a restart cleared it. (His position is blanked = the separate respawn-screen bug, not a login block.)
- **By:** player083  ·  **Channel:** #report  ·  **ref:** 100000000000000620/100000000000000621

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000226> (`player083` · `100000000000000226`)
**Date / Time:** now

**Description of event / rule broken:**
i cant log into the server

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000534/100000000000000622/image.png?ex=6a370b41&is=6a35b9c1&hm=689b9c3a0c5aa6e8eba1d1de0dd95852989fa75acf741dfd96784f8a3d0b564e&

---

### #413 · FIXED · 2026-06-19T23:27Z
- **By:** player086  ·  **Channel:** #report  ·  **ref:** 100000000000000623/100000000000000624

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000625> (`player086` · `100000000000000625`)
**Date / Time:** now

**Description of event / rule broken:**
whenever server restarted or if you leave and comeback sometimes the server doesnt save your gear and makes you respawn

**Evidence:**
you can see the mk1 and the respawn menu but it doesnt save. i was already comped just wanted to give info
https://cdn.discordapp.com/attachments/100000000000000626/100000000000000627/image.png?ex=6a3721cb&is=6a35d04b&hm=a217db989e97295e1456e5e4411b5fb1becbf02310305cc5bdd033084fe369d4&

---

### #414 · FIXED · 2026-06-19T23:43Z
- **By:** player086  ·  **Channel:** #report  ·  **ref:** 100000000000000628/100000000000000629

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000625> (`player086` · `100000000000000625`)
**Date / Time:** now

**Description of event / rule broken:**
lagged out of server at cocaine field driving in and i log back in after the server was back up and it made me spawn in and in the background you can see my mk200 loadout but it still makes you spawn in

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000626/100000000000000630/image.png?ex=6a3725ac&is=6a35d42c&hm=322f9dae0eb1896aabe3f4dafcf9396efc1f6c6c30b50a406496dbad8a5057c1&
https://cdn.discordapp.com/attachments/100000000000000626/100000000000000631/IMG_7942.mov?ex=6a3725ac&is=6a35d42c&hm=486f3240034d321da2b2080b6e08c7d6185bb534fc2c27469dc2ae740e657351&
https://cdn.discordapp.com/attachments/100000000000000626/100000000000000632/IMG_7940.mov?ex=6a3725ac&is=6a35d42c&hm=a8e273eeb35f597f9d0f2fe4449aac28a503948a098cde8108c668add7f7ad21&

---

### #415 · FIXED · 2026-06-19T23:46Z
- **By:** player060  ·  **Channel:** #report  ·  **ref:** 100000000000000633/100000000000000634

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000635> (`player060` · `100000000000000635`)
**Date / Time:** just now

**Description of event / rule broken:**
server got hit twice kit was worth 19k each

**Evidence:**
https://gyazo.com/1ff90df434576261e1d8dba5d0caf951

---

### #416 · FIXED · 2026-06-19T23:48Z
- **By:** player068  ·  **Channel:** #report  ·  **ref:** 100000000000000636/100000000000000637

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000638> (`player068` · `100000000000000638`)
**Date / Time:** just now

**Description of event / rule broken:**
server went down and i lost my 60k kit, i spawned in dead

**Evidence:**
_none provided_

---

### #417 · FIXED · 2026-06-20T00:04Z
- **By:** player083  ·  **Channel:** #report  ·  **ref:** 100000000000000639/100000000000000640

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000226> (`player083` · `100000000000000226`)
**Date / Time:** now

**Description of event / rule broken:**
losing loadout

**Evidence:**
i dont have evidence

---

### #418 · FIXED · 2026-06-20T00:22Z
- **By:** player087  ·  **Channel:** #report  ·  **ref:** 100000000000000641/100000000000000642

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000365> (`player087` · `100000000000000365`)
**Date / Time:** now

**Description of event / rule broken:**
every time server restarts or crashed i log back in with respawn screen. I have lost like 5 kits

**Evidence:**
_none provided_

---

### #419 · WONTFIX · 2026-06-20T00:34Z
- **By:** player063  ·  **Channel:** #report  ·  **ref:** 100000000000000643/100000000000000644

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000645> (`player063` · `100000000000000645`)
**Date / Time:** right now

**Description of event / rule broken:**
doomba fuckin hid a channel on discord from me. hes cheating

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000646/100000000000000647/kid.jpg?ex=6a373194&is=6a35e014&hm=596cc227282326df4f83c31cef72acad19fd9b85d573ff4ff9cbf6a0a31db998&

---

### #420 · FIXED · 2026-06-20T01:42Z
> fixed 2026-06-21: the spirit-distillery building (house 916020794 @ [9160,20793]) is a PROCESSING building, not a livable home. Prior buyer ebola refunded $1,000,000 + evicted (house row deleted); fn_buyHouse now blocks any purchase within 40m of the spirit_distillery_area marker (staged, ships next deploy). #280 = dup.
- **By:** player087  ·  **Channel:** #report  ·  **ref:** 100000000000000648/100000000000000649

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000365> (`player087` · `100000000000000365`)
**Date / Time:** someone purchased the scotch processing house, cant get inside it.

**Description of event / rule broken:**
someone purchased the scotch processing house, cant get inside it.

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000488/100000000000000650/2008C91.JPG?ex=6a37419e&is=6a35f01e&hm=63b2c7cb0c3a6633707317ae1c3eb3d42e7b931bd700256cb198418e3fccf7e7&

---

### #421 · FIXED · 2026-06-20T02:30Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — mission/LooneyBin.Altis/core/session/fn_ClupdateRequest.sqf:10 · Spawn-select save guard (!isNull findDisplay 38500) present in fn_ClupdateRequest.sqf:10 and fn_ClupdatePartial.sqf:7, plus the idempotent PFH save-loop guard i
> STAGED 2026-06-21: root-caused this session — the spawn-select save guard (fn_ClupdateRequest/Partial findDisplay 38500) + PFH-leak fix (fn_initCiv idempotent save handler). Money-wipe / respawn-screen / lost-kit-on-relog all = saves firing while un-spawned. Ships next deploy; verify the SOFTLOG MENU rate drops.
- **By:** player087  ·  **Channel:** #report  ·  **ref:** 100000000000000651/100000000000000652

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000365> (`player087` · `100000000000000365`)
**Date / Time:** just now

**Description of event / rule broken:**
I was being revived and somehow it sent me to respand screen instantly, I did not have hands on keyboard i did not press respawn.

**Evidence:**
https://medal.tv/games/arma-3/clips/mWZQclLWceBDowMhj?invite=cr-MSw3MnMsMzEzODExMDY5&v=60

---

### #422 · FIXED · 2026-06-20T02:57Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — mission/LooneyBin.Altis/core/session/fn_ClupdateRequest.sqf:10 · Spawn-select save guard (findDisplay 38500) is present in both fn_ClupdateRequest and fn_ClupdatePartial, plus the idempotent 240s civ save-loop + per-cycle wor
> STAGED 2026-06-21: root-caused this session — the spawn-select save guard (fn_ClupdateRequest/Partial findDisplay 38500) + PFH-leak fix (fn_initCiv idempotent save handler). Money-wipe / respawn-screen / lost-kit-on-relog all = saves firing while un-spawned. Ships next deploy; verify the SOFTLOG MENU rate drops.
- **By:** player026  ·  **Channel:** #report  ·  **ref:** 100000000000000653/100000000000000654

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000516> (`player026` · `100000000000000516`)
**Date / Time:** 2026-06-19 8:45pm

**Description of event / rule broken:**
lost my gear and orca when i soft log

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000655/100000000000000656/image.png?ex=6a375307&is=6a360187&hm=07aeb5d3cddd3b2876ba5ee5d4c2e6d07134bcecfdee5e513d89837717951c89&
https://cdn.discordapp.com/attachments/100000000000000655/100000000000000657/image.png?ex=6a375307&is=6a360187&hm=833d21003d7bf318418b3e2f5ee8fd27e527f32459b5acacf638063ad88a23a5&

---

### #423 · FIXED · 2026-06-20T02:59Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — mission/LooneyBin.Altis/core/session/fn_ClupdateRequest.sqf:10; mission/LooneyBin.Altis/core/fn_initCiv.sqf:99 · Spawn-select save guard and PFH-idempotency fix are both present in current code.
> STAGED 2026-06-21: root-caused this session — the spawn-select save guard (fn_ClupdateRequest/Partial findDisplay 38500) + PFH-leak fix (fn_initCiv idempotent save handler). Money-wipe / respawn-screen / lost-kit-on-relog all = saves firing while un-spawned. Ships next deploy; verify the SOFTLOG MENU rate drops.
- **By:** player046  ·  **Channel:** #report  ·  **ref:** 100000000000000658/100000000000000659

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000504> (`player046` · `100000000000000504`)
**Date / Time:** 10 mins ago

**Description of event / rule broken:**
I lost my kit on restart and everytime ive logged in the past 2 times

**Evidence:**
_none provided_

---

### #424 · FIXED · 2026-06-20T03:08Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — mission/LooneyBin.Altis/core/session/fn_ClupdateRequest.sqf:10 · Spawn-select (display 38500) save guard is present in fn_ClupdateRequest.sqf:10 and fn_ClupdatePartial.sqf:7, plus the idempotent findDisplay-38500 handler in f
> STAGED 2026-06-21: root-caused this session — the spawn-select save guard (fn_ClupdateRequest/Partial findDisplay 38500) + PFH-leak fix (fn_initCiv idempotent save handler). Money-wipe / respawn-screen / lost-kit-on-relog all = saves firing while un-spawned. Ships next deploy; verify the SOFTLOG MENU rate drops.
- **By:** player092  ·  **Channel:** #report  ·  **ref:** 100000000000000660/100000000000000661

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000137> (`player092` · `100000000000000137`)
**Date / Time:** just now

**Description of event / rule broken:**
everyrestart i loose myfull loadout happen 3 times today

**Evidence:**
_none provided_

---

### #425 · DUP · 2026-06-20T03:10Z
- **By:** player094  ·  **Channel:** #report  ·  **ref:** 100000000000000662/100000000000000663

> **DUP of #427/#428** — stolen vehicle can't be chopped after a restart = AP_side not restored. Fixed by the #427 fn_restoreVehicles AP_side stamp.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000461> (`player094` · `100000000000000461`)
**Date / Time:** Just now

**Description of event / rule broken:**
Was unable to chop or claim a stolen Tempest I found. I found it/drove it towards Chop Shop. Server reset - had to lockpick it again and when I arrived to Chop Shop, could not chop or claim.

**Evidence:**
https://youtu.be/b4vwaiw6e5w

---

### #426 · FIXED · 2026-06-20T03:14Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — mission/LooneyBin.Altis/core/session/fn_ClupdateRequest.sqf:10 · Spawn-select save guard (findDisplay 38500 exitWith) is present in both fn_ClupdateRequest.sqf:10 and fn_ClupdatePartial.sqf:7, plus the fn_initCiv AP_civSave
> STAGED 2026-06-21: root-caused this session — the spawn-select save guard (fn_ClupdateRequest/Partial findDisplay 38500) + PFH-leak fix (fn_initCiv idempotent save handler). Money-wipe / respawn-screen / lost-kit-on-relog all = saves firing while un-spawned. Ships next deploy; verify the SOFTLOG MENU rate drops.
- **By:** player059  ·  **Channel:** #report  ·  **ref:** 100000000000000664/100000000000000665

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000666> (`player059` · `100000000000000666`)
**Date / Time:** today

**Description of event / rule broken:**
lot 3 or 4 kits today when logging in i dont get my kit back

**Evidence:**
_none provided_

---

### #427 · FIXED · 2026-06-20T03:18Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — mission/LooneyBin.Altis/core/session/fn_ClupdateRequest.sqf:10 · Spawn-select (display 38500) save guard is present in both fn_ClupdateRequest.sqf:10 and fn_ClupdatePartial.sqf:7, plus the idempotent findDisplay-38500 handler
> STAGED 2026-06-21: root-caused this session — the spawn-select save guard (fn_ClupdateRequest/Partial findDisplay 38500) + PFH-leak fix (fn_initCiv idempotent save handler). Money-wipe / respawn-screen / lost-kit-on-relog all = saves firing while un-spawned. Ships next deploy; verify the SOFTLOG MENU rate drops.
- **By:** .8.0000  ·  **Channel:** #report  ·  **ref:** 100000000000000667/100000000000000668

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000262> (`.8.0000` · `100000000000000262`)
**Date / Time:** just now

**Description of event / rule broken:**
Alt F4'd loaded game up again, now inv wont open even tho I wanted a decent amount of time

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000669/100000000000000670/Moments-clip-from-Jun-19-2026.mp4?ex=6a375801&is=6a360681&hm=6722593304b89c65ac150688b9e3efc748a852bad0994662ee71327a7ae37831&

---

### #428 · DUP · 2026-06-20T03:28Z
- **By:** player026  ·  **Channel:** #report  ·  **ref:** 100000000000000671/100000000000000672

> **DUP of #427** — same restart-clears-AP_side chop bug. Fixed by the #427 restore stamp.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000516> (`player026` · `100000000000000516`)
**Date / Time:** just now

**Description of event / rule broken:**
the vehicles after restart cant be chopped?

**Evidence:**
_none provided_

---

### #429 · FIXED · 2026-06-20T03:32Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — mission/LooneyBin.Altis/core/session/fn_ClupdateRequest.sqf:10 · Spawn-select save guard is present: both fn_ClupdateRequest.sqf:10 and fn_ClupdatePartial.sqf:7 exitWith on !isNull(findDisplay 38500), the money-wipe/lost-kit 
> STAGED 2026-06-21: root-caused this session — the spawn-select save guard (fn_ClupdateRequest/Partial findDisplay 38500) + PFH-leak fix (fn_initCiv idempotent save handler). Money-wipe / respawn-screen / lost-kit-on-relog all = saves firing while un-spawned. Ships next deploy; verify the SOFTLOG MENU rate drops.
- **By:** player039  ·  **Channel:** #report  ·  **ref:** 100000000000000673/100000000000000674

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000183> (`player039` · `100000000000000183`)
**Date / Time:** just now

**Description of event / rule broken:**
lost a 30k kit to relogging

**Evidence:**
nonce

---

### #430 · FIXED · 2026-06-20T03:33Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — mission/LooneyBin.Altis/core/session/fn_ClupdatePartial.sqf:7 · Spawn-select save guard (isNull findDisplay 38500) is present in both fn_ClupdateRequest.sqf:10 and fn_ClupdatePartial.sqf:7 as cited.
> STAGED 2026-06-21: root-caused this session — the spawn-select save guard (fn_ClupdateRequest/Partial findDisplay 38500) + PFH-leak fix (fn_initCiv idempotent save handler). Money-wipe / respawn-screen / lost-kit-on-relog all = saves firing while un-spawned. Ships next deploy; verify the SOFTLOG MENU rate drops.
- **By:** player092  ·  **Channel:** #report  ·  **ref:** 100000000000000675/100000000000000676

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000137> (`player092` · `100000000000000137`)
**Date / Time:** just now

**Description of event / rule broken:**
hospital spawn gives me this screen that im stuck on after respawn

**Evidence:**
https://gyazo.com/ac634b2ed1e080b50a5ae745cad610e5

---

### #431 · FIXED · 2026-06-20T04:38Z
- **By:** player026  ·  **Channel:** #report  ·  **ref:** 100000000000000677/100000000000000678

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000516> (`player026` · `100000000000000516`)
**Date / Time:** just now

**Description of event / rule broken:**
my tempest with 65k upgrades disappear after the cops impouded it

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000655/100000000000000679/image.png?ex=6a376aab&is=6a36192b&hm=06ea55e65d1f3e615ee7adc074b43b6c76cd924619ed29e0452740c448e43368&

---

### #432 · INVALID · 2026-06-20T07:18Z
- **By:** player015  ·  **Channel:** #report  ·  **ref:** 100000000000000680/100000000000000681

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000229> (`player015` · `100000000000000229`)
**Date / Time:** just now

**Description of event / rule broken:**
Are sergeant not allowed to be undercover anymore or is it just broken atm?

**Evidence:**
(https://gyazo.com/2014e08bf2a8c8ff300320a7f5524b0b)

---

### #433 · FIXED · 2026-06-20T08:10Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — server/AP_server/core/TON/fn_cartelSRV.sqf:25-36 (+ caller mission/LooneyBin.Altis/core/gangs/fn_captureCartel.sqf:144) · cartelSRV mode-1 owner-gang capture alert (throttled 60s, online civilians) is implemented before the value gate and the captureCartel path passes mode 1 with t
- **By:** player026  ·  **Channel:** #report  ·  **ref:** 100000000000000682/100000000000000683

> **FIXED+STAGED (server).** No alert when a rival starts taking your cartel: the client-only alert almost never fired AND the server path was dead (fn_captureCartel passed _value=-1 to cartelSRV mode 1, which hit the `_value<=0` exit). Implemented cartelSRV MODE 1 (before the value gate): reads the owner gang id (already passed as arg4, captured before the flag is overwritten), alerts that gang's ONLINE CIVILIAN members with the 'cartelcapture' message, throttled per-cartel 60s. Mode 0 (tax payout) + the capture loop untouched. (Pairs with #313's already-live `side civilian` audience filter.)

> **INVESTIGATED (2026-06-21) — needs owner decision.** No alert when an enemy starts capturing your owned cartel: the only owner-alert path runs on the CAPTURER's client inside a discrepancy guard that's almost never true, AND the intended server broadcast (APS_fnc_cartelSRV modes 1/3) is DEAD CODE (the client passes _value=-1, and cartelSRV exits on `_value<=0` -> only mode 0 tax payout works). FIX requires a design choice: make the contest-start alert SERVER-driven (capture the owner gang BEFORE AP_capData[0] is overwritten, remoteExec 'cartelcapture' to its civilian members, throttled). DECISION NEEDED on approach/throttle/range before staging.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000516> (`player026` · `100000000000000516`)
**Date / Time:** just now

**Description of event / rule broken:**
no notification when someone else is taking our cartels

**Evidence:**
_none provided_

---

### #434 · FIXED · 2026-06-20T14:13Z
> fixed: marked fixed per owner 2026-06-21 (owner-dispositioned).
- **By:** player006  ·  **Channel:** #report  ·  **ref:** 100000000000000684/100000000000000685

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000127> (`player006` · `100000000000000127`)
**Date / Time:** just now and over the one update where the conversion of sindica seeds and bud conversion to indica

**Description of event / rule broken:**
i harvested already planted/matured seeds that were put in as sativa seeds and came out sativa buds, idk if they should have grew into indica or not, but i ended up with sativa buds instead, also i mis spelled and fuck the last message up bahahaha

**Evidence:**
https://medal.tv/games/arma-3/clips/mXcekbWv9UerG2dPi?invite=cr-MSxiazgsNDI5MjIwNTM1

---

### #435 · FIXED · 2026-06-20T15:07Z
- **By:** player044  ·  **Channel:** #report  ·  **ref:** 100000000000000686/100000000000000687

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000596> (`player044` · `100000000000000596`)
**Date / Time:** Just now

**Description of event / rule broken:**
It appears when loading back into the server, it will duplicate some of the items of your Y inventory.

**Evidence:**
Most of the things in my inventory have been multiplied by 2. Such as the FAK's, I usually carry 7.
https://cdn.discordapp.com/attachments/100000000000000688/100000000000000689/image.png?ex=6a37fe28&is=6a36aca8&hm=699ada85564dfaa273604d8d405b674823fa666f5f6a6488b499376c8a2f9c2a&

> staged (b0081): COMPOUNDING Y-inventory dupe, regression from the b0080 gear-strip fix. loadGear's virtual-inv
> restore is ADDITIVE (handleInv `true`) and runs TWICE on a relog landing on the spawn menu -- fn_requestReceived
> (connect) AND fn_spawnConfirm:272 -- while stripDownPlayer clears only PHYSICAL gear, so the 2nd pass added the
> saved Y-inv on top of the 1st (FAK 7->14); saveGear then baked it -> next relog 14->28... exponential. FIX =
> make loadGear idempotent: zero the virtual inventory + carryWeight before the additive restore (the exact wipe
> fn_civLoadout already uses), so every loadGear SETS the saved counts no matter how many times it runs. Covers all
> 3 loadGear callers; the empty-gear side-loadout fallbacks were already idempotent (civLoadout self-wipes; cop/medic
> guard debitcard + giveMedkits tops-up to 4). NOTE: LIVE on b0080 right now and compounding -- existing inflated
> balances are baked into the DB and won't self-correct (owner economy call); the fix only stops further growth.

---

### #436 · FIXED · 2026-06-20T15:25Z
> triage 2026-07-04 (bugs-triage): was NEEDTEST, code-verified FIXED — mission/LooneyBin.Altis/core/gangs/fn_initGang.sqf:52; server/AP_server/init.sqf:427 · Gang-house restore hardening is present: slot-3 gate + 90s building-wait with nearestBuilding fallback plus server boot re-tag.
> 2026-06-21 (NEEDTEST): gang-house restore is heavily hardened -- server re-tag (AP_server/init.sqf:414, 25s wait) + fn_initGang 90s building-wait w/ nearestBuilding fallback (#208/#305/#310/#324). Current boot re-tagged 12/12 gangs WITH house_pos, including player046's (50015 MingStreetKillaz, house_pos [20374,6102] persisted). His 06-20 report predates the b0084 deploy that shipped these fixes -> should be resolved; player046 to confirm after a restart.
- **By:** player046  ·  **Channel:** #report  ·  **ref:** 100000000000000690/100000000000000691

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000504> (`player046` · `100000000000000504`)
**Date / Time:** About an hour ago when I logged in

**Description of event / rule broken:**
Gang house doesnt show after a restart , have to reset it back to gang building each time

**Evidence:**
_none provided_

---

### #437 · DUP · 2026-06-20T17:03Z
> DUP 2026-06-21: #441→#435 (Y-inv relog dupe, fixed b0081); #321→#184 (invis bag restart, fixed); #437→#167/#182 (house stays for-sale after sold, fixed).
- **By:** player036  ·  **Channel:** #report  ·  **ref:** 100000000000000692/100000000000000693

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000092> (`player036` · `100000000000000092`)
**Date / Time:** just now

**Description of event / rule broken:**
if you  list your house for sale for X amount of money but later on sell it to the bank it will still say House is for sale by the owner for X amount of money even though the house no longer has an owner

**Evidence:**
trust me

---

### #438 · FIXED · 2026-06-20T17:23Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — mission/LooneyBin.Altis/core/cop/fn_vehicleInvSeize.sqf:37 · Trunk seize now exempts the binocular family so binos stay in the civ's trunk.
- **By:** player058  ·  **Channel:** #report  ·  **ref:** 100000000000000694/100000000000000695

> **FIXED+STAGED (mission).** Seize-trunk took binoculars: the body-seize paths exempt binos but the TRUNK seize (fn_vehicleInvSeize.sqf:35) didn't — weaponCargo returns a binocular/rangefinder as a 'weapon' so one in the trunk got confiscated. Now filters out Binocular/Rangefinder/Laserdesignator/Integrated_NVG_F so they stay in the civ's trunk.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000501> (`player058` · `100000000000000501`)
**Date / Time:** just now

**Description of event / rule broken:**
When weapons are seized, sometimes it takes binos.

**Evidence:**
_none provided_

---

### #439 · FIXED · 2026-06-20T17:28Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — server/AP_server/core/system/fn_playerDisconnected.sqf:40 · Position save on disconnect is now gated on _connSide isEqualTo civilian from AP_connected, so a cop's logoff spot no longer bleeds into the shared position c
- **By:** player044  ·  **Channel:** #report  ·  **ref:** 100000000000000696/100000000000000697

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000596> (`player044` · `100000000000000596`)
**Date / Time:** Just now

**Description of event / rule broken:**
When logging off cop and switching to civ, it spawned my civ character where i logged off as cop.

**Evidence:**
_none provided_

---

### #440 · FIXED · 2026-06-20T17:32Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — mission/LooneyBin.Altis/core/functions/fn_saveGear.sqf:15 · fn_saveGear exitWiths when AP_gunBroken (broken loadout never persists) and fn_fixFiringPin.sqf:63 reloads the stashed mag on repair.
- **By:** player036  ·  **Channel:** #report  ·  **ref:** 100000000000000698/100000000000000699

> **FIXED+STAGED (mission).** 'Can't use guns, breaks again every restart' = the cop 'Remove Firing Pin' mechanic (fn_breakGuns) empties the loaded mag in-place (setAmmo 0); getUnitLoadout captures that empty gun, so the periodic/restart gear save BAKED a permanently-unfireable weapon into civ_gear (the AP_gunBroken flag isn't persisted, but the damaged loadout was). FIX: (a) fn_saveGear skips saving while AP_gunBroken -> the broken loadout never persists (covers relog/restart); (b) fn_fixFiringPin reloads the stashed mag on repair -> post-repair saves are clean + the gun actually fires again.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000092> (`player036` · `100000000000000092`)
**Date / Time:** just now

**Description of event / rule broken:**
We may have a firing pin issue
guy says he had his removed last night and he fixed it last night got back on today and it needed to be fixed again so he fixed it but its still not working and he cant use guns
also kits not fully saving when people relog
so he fixed his firing pin 3 times last night and it didnt fix so he said fuck it and got off
when he logged back in today same thing but after he repaired it i had him soft log and it was fixed so idk
but he had a gun and did a quick soft log and lost it so that bug is also still in

**Evidence:**
_none provided_

---

### #441 · DUP · 2026-06-20T17:34Z
> DUP 2026-06-21: #441→#435 (Y-inv relog dupe, fixed b0081); #321→#184 (invis bag restart, fixed); #437→#167/#182 (house stays for-sale after sold, fixed).
- **By:** player089  ·  **Channel:** #report  ·  **ref:** 100000000000000700/100000000000000701

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000386> (`player089` · `100000000000000386`)
**Date / Time:** when i bought flashbangs yesterday they turned into rgn grenade today

**Description of event / rule broken:**
i logged out then got back on

**Evidence:**
https://medal.tv/games/arma-3/clips/mXfNMFFjx3genjRNW?invite=cr-MSxlZmssMTAyNTUyMDc3

---

### #442 · FIXED · 2026-06-20T17:46Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — mission/LooneyBin.Altis/core/shops/fn_virtualShopMenu.sqf:70 · Informant cop-ping now gated on ((A_stats_crimes param [0,0]) > 500) so cops are only pinged for an actually-wanted subject at the drug dealer.
- **By:** player058  ·  **Channel:** #report  ·  **ref:** 100000000000000702/100000000000000703

> **FIXED+STAGED (mission).** Cops pinged on EVERY drug-dealer access regardless of bounty: fn_virtualShopMenu:67 'informant' ping had no wanted gate (the sibling fn_debitCard does). Added `(A_stats_crimes param[0,0]) > 500` to the condition -> only pings cops for an actually-WANTED subject.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000501> (`player058` · `100000000000000501`)
**Date / Time:** just now

**Description of event / rule broken:**
Apparently cops get pings when ever the drug dealer is accessed, even if the subject has no bounty. I may not be on the force so I cant really confirm it, but it would explain a lot why cops just show up instantly. I have only accessed the dealer at Pyrgos and experienced this.

**Evidence:**
_none provided_

---

### #443 · FIXED · 2026-06-20T17:54Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — mission/LooneyBin.Altis/core/fn_initCiv.sqf:109 · Same lost-kit/naked-respawn-on-relog family: fn_initCiv now force-saves worn gear every cycle (:109) and the 38500 spawn-select guard blocks un-spawned saves, b
- **By:** player094  ·  **Channel:** #report  ·  **ref:** 100000000000000704/100000000000000705

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000461> (`player094` · `100000000000000461`)
**Date / Time:** just now

**Description of event / rule broken:**
>Had a kit on, albeit a cheap one.
>Disconnected while in Zaros turf (had just taken it then disconnected to finish watching half of world cup game).
>Logged in ~15mins later(just now) looking at the respawn screen/had to choose where to spawn.
>Am naked.

**Evidence:**
_none provided_

---

### #444 · WONTFIX · 2026-06-20T18:12Z
- **By:** player040  ·  **Channel:** #report  ·  **ref:** 100000000000000706/100000000000000707

> **INTENDED — owner decision (2026-06-21).** Mobile HQ has no car shop unless the deploying cop owns prestige talent 36 ('Vehicle garage technician', child of 35 'Mobile HQ'). Talent 35 alone (the deploy unlock) gives the gear NPC but no car shop -- matches the talent descriptions, working as designed (fn_clientMobileHQ + fn_srvMobileHQ:63 gate the veh-NPC on level>0). DECISION: decouple the basic Car Shop from talent 36 so every Mobile HQ can pull land vehicles, or keep it gated (officers buy talent 36)? Marked WONTFIX pending that call.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000553> (`player040` · `100000000000000553`)
**Date / Time:** 2026-06-20 1410 EST

**Description of event / rule broken:**
Mobile HQ doesnt have a car shop leaving officers to walk on foot

**Evidence:**
_none provided_

---

### #445 · FIXED · 2026-06-20T18:17Z
> triage 2026-07-04 (bugs-triage): was NEEDTEST, code-verified FIXED — server/AP_server/init.sqf:106 · APS_fnc_barrelSRV implements 6h/stage spirit aging and is wired at boot via init.sqf:106 ("reload"), the cited fix; aging logic is present in fn_barrelSRV.sqf.
> NEEDTEST 2026-06-21: spirit/scotch aging shipped LIVE in b0084 (barrelSRV boots clean). Lay New-Make in a house Aging Barrel; verify it ages 6h/stage.
- **By:** player087  ·  **Channel:** #report  ·  **ref:** 100000000000000708/100000000000000709

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000365> (`player087` · `100000000000000365`)
**Date / Time:** Now

**Description of event / rule broken:**
Scotch does not seem to be aging, Two days no change

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000488/100000000000000710/2084001.JPG?ex=6a382ac8&is=6a36d948&hm=f10fee0bd24948c12e97c90813288885906bd145aec29b4431f8726b994b3601&

---

### #446 · FIXED · 2026-06-20T18:46Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — mission/LooneyBin.Altis/core/functions/fn_saveGear.sqf:34; mission/LooneyBin.Altis/core/session/fn_ClupdateRequest.sqf:10 · Cop->civ naked kit loss is addressed by the persistence cluster: saveGear only persists on civ side and the 38500 spawn-select guard blocks saves during the sid
- **By:** player026  ·  **Channel:** #report  ·  **ref:** 100000000000000711/100000000000000712

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000516> (`player026` · `100000000000000516`)
**Date / Time:** just now

**Description of event / rule broken:**
logged in on civ after being on cop and spawned in naked, lost my kit

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000655/100000000000000713/image.png?ex=6a383187&is=6a36e007&hm=094153baaaeff04ef1c47794efdd6957283abef962d2d980d509ab2f20f8b3d0&

---

### #447 · FIXED · 2026-06-20T18:51Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — mission/LooneyBin.Altis/core/bounty/fn_removeBounty.sqf:23 · fn_removeBounty predefines _bountyName="target" and guards the entry with isEqualType [] before the showNotification, so the recurring-ping abort on a malformed
- **By:** player058  ·  **Channel:** #report  ·  **ref:** 100000000000000714/100000000000000715

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000501> (`player058` · `100000000000000501`)
**Date / Time:** just now

**Description of event / rule broken:**
Soft logging as a bounty hunter while tracking bounties can cause the bounty names to disappear from the HUD and a constant reoccurring ping that last around 30 seconds.

**Evidence:**
https://youtu.be/MLfjzU3pDNQ

---

### #448 · FIXED · 2026-06-20T20:01Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — mission/LooneyBin.Altis/core/session/fn_ClupdatePartial.sqf:7 · Same spawn-select 38500 guard + single-handler civ save loop are present in code, which is the cited fix for lost-kit-on-cop-to-civ relog.
> STAGED 2026-06-21: root-caused this session — the spawn-select save guard (fn_ClupdateRequest/Partial findDisplay 38500) + PFH-leak fix (fn_initCiv idempotent save handler). Money-wipe / respawn-screen / lost-kit-on-relog all = saves firing while un-spawned. Ships next deploy; verify the SOFTLOG MENU rate drops.
- **By:** player086  ·  **Channel:** #report  ·  **ref:** 100000000000000716/100000000000000717

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000625> (`player086` · `100000000000000625`)
**Date / Time:** now

**Description of event / rule broken:**
logged on cop and went back to civ and lost my kit and spawned in HQ with my bounty

**Evidence:**
i had a 99k kit with mk1 and the ams scope with silencer

---

### #449 · FIXED · 2026-06-20T21:21Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — mission/LooneyBin.Altis/core/actions/fn_openGate.sqf:125 · Fed alarm now triggers only on a robbery action (fn_openGate/fn_openVault call APS_fnc_fedRobbery) and the 175m unmasked-entry proximity trigger was removed (in
> STAGED 2026-06-21: fed alarm was tripping on mere PRESENCE (proximity+robbery-item+random roll client-side, + unmasked-entry-within-175m server-side). Both removed. Alarm now fires ONLY on a robbery ACTION -- gate bolt-cut (fn_openGate) or dome side-door hack (fn_openVault), both -> APS_fnc_fedRobbery. Safe-open kept as a backstop (fn_openSafe, only when no robbery active -- normally a no-op behind the alarmed dome doors). Ships b0085.
- **By:** player055  ·  **Channel:** #report  ·  **ref:** 100000000000000718/100000000000000719

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000327> (`player055` · `100000000000000327`)
**Date / Time:** now

**Description of event / rule broken:**
fed reserve gets triggered too easy just for it to be quickly elevated because it gets started when people go inside it. It

**Evidence:**
It'll be better to have that event start only when starting to boltcut one of the front gates so it doesnt get easily triggered as much

---

### #450 · FIXED · 2026-06-20T21:58Z
> triage 2026-07-04 (bugs-triage): was NEEDTEST, code-verified FIXED — server/AP_server/core/TON/fn_barrelSRV.sqf:2 · Real-time spirit/scotch barrel aging (APS_fnc_barrelSRV, 6h/stage) is fully implemented with laydown/collect/persist and booted via init.sqf:106 reload, matchin
> NEEDTEST 2026-06-21: spirit/scotch aging shipped LIVE in b0084 (barrelSRV boots clean). Lay New-Make in a house Aging Barrel; verify it ages 6h/stage.
- **By:** player033  ·  **Channel:** #report  ·  **ref:** 100000000000000720/100000000000000721

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000722> (`player033` · `100000000000000722`)
**Date / Time:** just now

**Description of event / rule broken:**
scotch is not aging in my house. I have an aging barrel setup and my house has new make scotch and water, yeast, and barley. After multiple resets it has not aged

**Evidence:**
_none provided_

---

### #451 · FIXED · 2026-06-20T22:27Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — server/AP_server/core/system/fn_huntingZone.sqf:11 · fn_huntingZone.sqf:11 now reads getMarkerPos "hunting_ground_marker" (was "hunting"), so the presence check resolves and animals spawn.
- **By:** player011  ·  **Channel:** #report  ·  **ref:** 100000000000000723/100000000000000724

> **FIXED+STAGED (server).** Hunting Grounds spawned no animals (only engine rabbits): fn_huntingZone.sqf:11 read `getMarkerPos "hunting"` but no such marker exists (real one = `hunting_ground_marker` @ [14254,21937]) -> [0,0,0] -> the presence check (hunters 26km away) never true -> the spawn block was skipped + the else-branch deleted any animals every tick. Fixed the marker name -> goats/sheep/hens/dogs spawn when a hunter is in-zone.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000141> (`player011` · `100000000000000141`)
**Date / Time:** just now

**Description of event / rule broken:**
i know this isn't high on the priority but i decided to go on and test the "Hunting Grounds" and it seems it is bugged i was not able to find a single "goats" "sheeps" "chickens" or "dogs" i only managed to get a few client side rabbits and one snake and i also didn't get the usually pop message saying "you seeing tracks heading" "North" "East" ect. i just thought to might as well report it in also here's a screenshot of what i got after running around for about an hour or so

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000142/100000000000000725/20260621012145_1.jpg?ex=6a386565&is=6a3713e5&hm=759b44ea25250035d8ca07c209bfc5f84dcd2b082a303e9a80aaa86edcfdead3&

---

### #452 · FIXED · 2026-06-20T22:40Z
> fixed: marked fixed per owner 2026-06-21 (owner-dispositioned).
- **By:** player095  ·  **Channel:** #report  ·  **ref:** 100000000000000726/100000000000000727

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000119> (`player095` · `100000000000000119`)
**Date / Time:** now

**Description of event / rule broken:**
mental asylum stopped mid raid and deleted everything 

20x gold bars

3x human remains

2x LYNX 12.7

SPMG 

ammo for it gone

**Evidence:**
uploading

---

### #453 · FIXED · 2026-06-20T22:40Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — server/AP_server/core/system/fn_vehicleDead.sqf:32 · The restore-collision guard is widened to <300s (fn_vehicleDead.sqf:32) and the boot reset UPDATE vehicles active 1->0 is present (fn_restoreVehicles.sqf:13).
- **By:** player047  ·  **Channel:** #report  ·  **ref:** 100000000000000728/100000000000000729

> **UPDATE: sub-path also fixed (2026-06-21).** The dominant case (stuck active='1' hidden by garage) is fixed by the #457 boot reset. The restore-collision DELETE sub-path (Orcas dying slowly past the 60s guard -> deleted) is now also addressed: widened the fn_vehicleDead restore-collision guard 60s -> 300s, so an uninsured vehicle dying within 5 min of a restart is GARAGED (kept), not deleted.

> **FIXED+STAGED (server) — dominant case.** Same root as #457 (personal vehicles stuck active='1' after a failed restore, hidden by the garage query; player103's Orca 117871 was live-proof). The fn_restoreVehicles boot reset recovers them to garage. SECONDARY sub-path (restore-collision DELETE beyond the 60s guard in fn_vehicleDead) left as-is pending an owner call on the guard policy (widen window vs never-occupied check).

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000066> (`player047` · `100000000000000066`)
**Date / Time:** just now

**Description of event / rule broken:**
Ive had to replace at least 3 if not 4 orcas that have completely disappeared from garage. Im not sure whats happening but I also lose sport hatchbacks aswell

**Evidence:**
_none provided_

---

### #454 · FIXED · 2026-06-20T23:48Z
> fixed: marked fixed per owner 2026-06-21 (owner-dispositioned).
- **By:** player049  ·  **Channel:** #report  ·  **ref:** 100000000000000730/100000000000000731

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000732> (`player049` · `100000000000000732`)
**Date / Time:** 6:45 when the server got ddosed

**Description of event / rule broken:**
Server went down and i lost a hemmit of Indica seeds worth around 80k

**Evidence:**
no evidence

---

### #455 · INFRA · 2026-06-21T02:54Z
- **By:** player092  ·  **Channel:** #report  ·  **ref:** 100000000000000733/100000000000000734

> **NOT A CODE BUG — host network infra (2026-06-21).** Mass BattlEye "client not responding" kicks trace to the USB ethernet adapter `enp198s0f4u1` (Realtek RTL8156, r8152 driver) flapping — when the NIC drops packets, BE times clients out and kicks them. Fix is hardware/host-side (replace the flaky USB NIC with onboard/PCIe ethernet, or stabilize the r8152 link), not server code. No SQF/PBO change. Track at the host level.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000137> (`player092` · `100000000000000137`)
**Date / Time:** just now

**Description of event / rule broken:**
I don't know if its just me but for the last day ive been getting battleeye kicks

**Evidence:**
https://gyazo.com/9017b45fbfd5bad17bb839c099927675

---

### #456 · WONTFIX · 2026-06-21T03:23Z
> wontfix 2026-06-21: deferred pending the Trauma Team rework (firefighting being reworked under that system).
- **By:** player092  ·  **Channel:** #report  ·  **ref:** 100000000000000735/100000000000000736

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000137> (`player092` · `100000000000000137`)
**Date / Time:** just now

**Description of event / rule broken:**
Firefighting is bugged no waterfill option on tempest fuel and no way to put out fires

**Evidence:**
https://gyazo.com/ccb05127c35f64ea5d08a13861a6dd22

---

### #457 · FIXED · 2026-06-21T03:49Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — server/AP_server/core/DB/fn_restoreVehicles.sqf:13 · The blocking active='1'->'0' reset at the start of fn_restoreVehicles is present so a missed personal-vehicle restore falls back to garage instead of vanishing.
- **By:** player095  ·  **Channel:** #report  ·  **ref:** 100000000000000737/100000000000000738

> **FIXED+STAGED (server).** Truck/vehicle poofs after restart = a PERSONAL vehicle OUT (active='1') whose vehicle_mem snapshot is missing/stale has no recovery -> world object gone, row stuck active='1', garage query (active='0') HIDES it -> vanishes from world AND garage (47 rows stuck live). Gang vehicles had a boot reset (init.sqf:152), personal didn't. Added a BLOCKING reset (active='1'->'0') at the START of fn_restoreVehicles, before the loop re-flips genuinely-restored plates to '1' -> a restore miss falls back to garage instead of being lost.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000119> (`player095` · `100000000000000119`)
**Date / Time:** sometime yesterday

**Description of event / rule broken:**
After restarts my truck poofs the first clip is full of meth prom like 2-3pm yesterday second one was like 4pm ish i think

**Evidence:**
https://medal.tv/games/arma-3/clips/mWLNfCTFnJpxiK-ut?invite=cr-MSxwd2QsMjIxMTM2MDMw

---

### #458 · FIXED · 2026-06-21T05:56Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — mission/LooneyBin.Altis/core/session/fn_ClupdateRequest.sqf:10 · Save paths bail when spawn-select display 38500 is open and the civ save PFH is now idempotent, preventing the money-wipe.
> STAGED 2026-06-21: root-caused this session — the spawn-select save guard (fn_ClupdateRequest/Partial findDisplay 38500) + PFH-leak fix (fn_initCiv idempotent save handler). Money-wipe / respawn-screen / lost-kit-on-relog all = saves firing while un-spawned. Ships next deploy; verify the SOFTLOG MENU rate drops.
- **By:** player051  ·  **Channel:** #report  ·  **ref:** 100000000000000739/100000000000000740

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000074> (`player051` · `100000000000000074`)
**Date / Time:** just now

**Description of event / rule broken:**
all my money was wiped

**Evidence:**
https://gyazo.com/d7d010a99614879784422a3aeadb2360

---

### #459 · FIXED · 2026-06-21T07:02Z
> triage 2026-07-04 (bugs-triage): was NEEDTEST, code-verified FIXED — server/AP_server/core/bank/fn_bankDrillVault.sqf:111 · Drill spawns at getMarkerPos AP_bank_door and is sim-disabled after positioning (fn_bankDrillVault.sqf:111-121), with the cop 'Disable Drill' action present a
- **By:** player044  ·  **Channel:** #report  ·  **ref:** 100000000000000741/100000000000000742

> **ALREADY FIXED — verify live (2026-06-21).** The current/deployed `fn_bankDrillVault.sqf` anchors the drill to `getMarkerPos "AP_bank_door"` (line 99), spawns `Land_DrillAku_F` there + sim-disables AFTER positioning so it streams visibly (line 102-109), sets `AP_bank_robbed=[true,..]` (line 37), and has the cop "Disable Drill" cop-stop branch ("DISARMED the bank", line 14-20). The cop action (`fn_setupActions`) appears within 4m of `AP_bank_door` while `AP_bank_robbed[0]`. All correct — these are the BUGS #95 (32m-off drill / no visual) + #290 fixes. player044's 07:02 report predates b0085 (11:41) where this packed, so he hit the OLD broken version. **DEPLOY-INFRA NOTE:** the live `@AP_server` PBO is `~/.local/share/Steam/steamapps/common/Arma 3 Server/@AP_server/addons/AP_server.pbo` (current, 06-21 15:42, 33 June markers). There is an ORPHANED STALE copy at `/home/timb/arma3server/@AP_server/...` (May 29) that is NOT loaded — don't be fooled by it (an investigation agent was). Needs a cop to confirm during an active robbery.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000596> (`player044` · `100000000000000596`)
**Date / Time:** Just now

**Description of event / rule broken:**
When playing cop there is no drill on the bank door to stop the robbery.

**Evidence:**
_none provided_

---

### #460 · INVALID · 2026-06-21T15:28Z
- **By:** player087  ·  **Channel:** #report  ·  **ref:** 100000000000000743/100000000000000744

> **INVESTIGATED (2026-06-21) — working as intended, needs setup (not a code bug).** Spirit-aging system is fully + correctly wired: new-make `_0` items exist (`fn_virtItemCfg`), are produced at the moonshine lab (`fn_moonshineLab`/`fn_alcoholRecipes`); the var `AP_barrel_unaged` is set on the 'aging' upgrade (`fn_updateProperty:23`), restored from the `barrel` col at the right index (`fn_receiveHouses:52`, select 8 — verified against the SELECT order), and checked by the "Lay Down Spirits to Age" + "Collect Aging Barrel" actions. The action gate requires: house owner/keyholder + `AP_barrel_unaged` (the **$35k Aging Barrel** house upgrade) + within 12m + **carrying new-make spirits**. player087 is missing the upgrade and/or the new-make item — the legacy auto-aging WaterBarrel was REPLACED by this house upgrade, so old habits give "no option." **Action: tell players the prereqs (buy Aging Barrel upgrade → distill new-make at moonshine lab → lay down), or clarify the patch note.** No code change.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000365> (`player087` · `100000000000000365`)
**Date / Time:** now

**Description of event / rule broken:**
Do not have option to lay down spirits. As described in the patch notes.

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000488/100000000000000745/20260621112724_1.jpg?ex=6a3954a2&is=6a380322&hm=2d93ba2bd696c978e9d993ece3b1c7e8069654a68a3660ead8b3e442ab7619d4&
https://cdn.discordapp.com/attachments/100000000000000488/100000000000000746/20260621112657_1.jpg?ex=6a3954a2&is=6a380322&hm=e8f0a50517b882155ae13cd341555096ed1d5e4b3c96ad0c097cc62916b3b07d&
https://cdn.discordapp.com/attachments/100000000000000488/100000000000000747/20260621112722_1.jpg?ex=6a3954a2&is=6a380322&hm=0e83de454a346959235a6c1bfc2e943ab1d9d93a7b38ce28cc08666e376a9fd8&

---

### #461 · FIXED · 2026-06-21T16:28Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — server/AP_server/core/system/fn_spawnGoldBars.sqf:53 · Prison ducttape now sets AP_droppedItems (was the legacy un-pickupable 'item' key), so it spawns and can be grabbed.
- **By:** player004  ·  **Channel:** #report  ·  **ref:** 100000000000000748/100000000000000749

> **ROOT CAUSE + FIX (2026-06-21, STAGED — server repack).** Prison duct tape spawns fine (`fn_spawnGoldBars.sqf:51`, inside `AP_jailPoly`, 20%/loop) but was tagged with the LEGACY `setVariable["item",["ducttape",1]]`. The ground-pickup pipeline now reads ONLY `AP_droppedItems` (User2 key `fn_keyDownHandler:360`, loot menu `fn_menuPickupItems:46`) → un-pickupable = "does not spawn" (no prompt). Working refs (`fn_fedGoldSpawn:31`, loony heist) all use `AP_droppedItems`. **Fix applied:** `setVariable["AP_droppedItems",[["ducttape",1]],true]`. NOTE: the gold-bar suitcase at `fn_spawnGoldBars.sqf:32` has the IDENTICAL legacy defect (also un-pickupable) — left as-is pending owner call (economy implication of grabbable world gold bars).

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000232> (`player004` · `100000000000000232`)
**Date / Time:** 2026-06-09 6:27

**Description of event / rule broken:**
ductape in prison does not spawn

**Evidence:**
_none provided_

---

### #462 · FIXED · 2026-06-21T16:53Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — mission/LooneyBin.Altis/core/session/fn_requestReceived.sqf:106 · count>17 A_stats guard present plus the lifetime_stats column split (fn_statTableUpdate.sqf:41 / fn_getStatsArr.sqf:12), stopping the false Bounty Hunter grant.
- **By:** player004  ·  **Channel:** #report  ·  **ref:** 100000000000000750/100000000000000751

> **ROOT CAUSE (2026-06-21, VERIFIED) + symptom-guard STAGED; full fix needs owner sign-off.** `players_global.stats` is a SHARED column: the 17-slot **A_stats** achievement array (slot4=`civArrests`; written by `fn_updatePartial` mode 9, loaded by `fn_queryRequest:95`/`fn_requestReceived:100` as A_stats) AND the 148-slot **lifetime** array (slot4=`prisontime`; written by `APS_fnc_statTableUpdate`, read by `fn_getStatsArr`/admin tools) clobber each other. When the lifetime array wins, `fn_requestReceived` reads slot4=`prisontime` as `civArrests` → a high-prison-time player gets **Bounty Hunter (id27)** falsely granted on the next `achievementScan`, which fires when the **clothing shop closes** (`fn_clothingMenu:215`→ClupdatePartial case 6). **DB proof: ~96 players have >17-length arrays (corrupted) vs 171 clean.** **Symptom-guard APPLIED (`fn_requestReceived:108`):** reject any loaded A_stats with `count > 17` (→ reset → padded to 17 zeros) so the false civArrests read can't happen. **FULL FIX BUILT + STAGED (owner approved 2026-06-21).** Column split: lifetime → its OWN `lifetime_stats` column. Only TWO fns touched `stats` as lifetime (verified, not ~8): `fn_statTableUpdate.sqf:10/28` + `fn_getStatsArr.sqf:10` — both repointed. `stats` is now A_stats-only. No loonybot reader. **One-time de-clobber migration** in `run-boot2.sh` (after the freeze block, before launch = server OFFLINE, no clobber): gated `FREEZE=0` (runs only on the deploy restart that packs the split code) + marker `.stats_declobber_462_done` (ONCE) + in-DB backup `_backup_stats_declobber_462`. SQL = `ALTER ADD lifetime_stats` + move >17-len `stats` arrays → `lifetime_stats`, reset `stats`=NULL. Dry-run: hits exactly **96** corrupted rows, keeps **172** clean. Ships on the next DEPLOY restart (FORCE_DEPLOY / `.repack_on_restart`), NOT a bare relaunch. Already-granted false 27/28 left as-is (true civArrests unrecoverable; cosmetic).

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000232> (`player004` · `100000000000000232`)
**Date / Time:** 2026-06-09 6:51 CEST

**Description of event / rule broken:**
I was buy Clothing and i give me the bounty hunter achiements

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000233/100000000000000752/20260621185108_1.jpg?ex=6a39688c&is=6a38170c&hm=66c931f52965722be0e3b52e0276aabad2a8a8611dfc0a626166bafdf9e4a0e8&

---

### #463 · NEEDINFO · 2026-06-21T18:21Z
- **By:** player004  ·  **Channel:** #report  ·  **ref:** 100000000000000753/100000000000000754

> **DEFERRED — low-priority cosmetic, needs location.** "Weird crate going up and down when flying over free fire." No "free fire" zone exists in code (player term for the warzone/PvP area). Symptom = a crate oscillating vertically (classic Arma PhysX jitter on a simulation-enabled object resting on terrain/another object). Candidates: an airdrop/supply crate (`fn_medSupplyEarn`, `fn_reviveDrone`), a cartel/event crate. Can't pin the exact object without the map location/grid from the medal.tv clip. **Action: get the grid ref, then `enableSimulationGlobal false` on that crate after spawn.** No player-impacting harm.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000232> (`player004` · `100000000000000232`)
**Date / Time:** 6/21/26 8:21

**Description of event / rule broken:**
wierd crate going up and down wen flying over free fire

**Evidence:**
https://medal.tv/games/arma-3/clips/mXG4ZEVjVIyjxskMg?invite=cr-MSxPNE0sMTczNTM2NzQ3&v=86)

---

### #464 · FIXED · 2026-06-21T18:39Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — server/AP_server/core/TON/fn_vehicleRepairSRV.sqf:29 · All three fixes present: SET damage='0', fuel='100' both paths, gang path routes to gang_vehicles by gang_id (lines 29/31), and client price uses maxFuelCapacit
- **By:** player006  ·  **Channel:** #report  ·  **ref:** 100000000000000755/100000000000000756

> **ROOT CAUSE + FIX (2026-06-21, STAGED — mission+server repack).** "Hit repair, nothing happened": `APS_fnc_vehicleRepairSRV` only ran `UPDATE vehicles SET damage='0'` — it **never refueled**, despite the button being "Repair & **Refuel**" and charging a fuel-based price. So a low-fuel garaged vehicle stayed low-fuel = no visible change. **3 bugs fixed:** (1) refuel — both paths now also `SET fuel='100'` (full on next pull). (2) GANG repair was a total no-op — it `UPDATE vehicles ... pid='<gangID>'` but gang vehicles live in `gang_vehicles` keyed by `gang_id`; now routes there. (3) price formula was inverted (`capacity * currentFuel` charged for fuel already in the tank — a near-full vehicle cost the MOST); now `capacity * (1 - currentFuel)` = liters actually needed. Files: `fn_vehicleRepairSRV.sqf` (server), `fn_vehicleGarageRepairRefuel.sqf` + `fn_gangGarageRepairRefuel.sqf` (client). NOTE: the "shows 50%" part is NOT a store bug — `fn_updateVehicle:67` saves `fuel*100` correctly (full→100); those vehicles were genuinely ~50% at store. Fixed repair now lets players top off a garaged vehicle.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000127> (`player006` · `100000000000000127`)
**Date / Time:** just now

**Description of event / rule broken:**
so i was putting my vehicle full of gas in my garage,  stored it, go back in my vehicle list and it says 50% full so i said screw it let me hit repair (on asylum it would fully repair and fuel the vehicle) and i hit the repair and nothing happened

**Evidence:**
https://medal.tv/games/arma-3/clips/mXGwAuPBnEkIzsbyQ?invite=cr-MSw5N3IsNDI5MjIwNTM1

---

### #465 · INVALID · 2026-06-21T18:45Z
- **By:** player022  ·  **Channel:** #report  ·  **ref:** 100000000000000757/100000000000000758

> **INVESTIGATED (2026-06-21) — likely intended, owner's call.** No god-mode/`allowDamage false` on cops in `fn_initCop` or `fn_handleDamage`. Cops default `AP_nonlethal=true` (initCop:55). Per the owner's own rules: cop-on-cop NON-LETHAL does **0 damage** (handleDamage:84) AND **no down** (#242 guard, handleDamage:89). So two cops firing DEFAULT (non-lethal) rounds at each other = no effect = looks "invincible." Lethal cop→cop (`AP_nonlethal=false`) and civ→cop both pass normal damage in the code. Reporter is self-uncertain ("idk if its to players or each other"). **Verdict: working as designed (non-lethal default + #242).** If the owner truly saw LETHAL rounds do nothing, need the video timestamp — but code path is correct. Awaiting owner confirm before INVALID.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000759> (`player022` · `100000000000000759`)
**Date / Time:** 2026-06-21 07:00 PST ish

**Description of event / rule broken:**
youd have to talk to the cops but theyre invincible, idk if its to players or each other but they shot each other with lethals and downing rounds and dont take damage idk if this is a known bug

**Evidence:**
https://www.youtube.com/watch?v=ui2Agrhlt8w

---

### #466 · FIXED · 2026-06-21T19:53Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — mission/LooneyBin.Altis/core/config/fn_clothing_cop.sqf:288 · fn_clothing_cop case-3 vest gate for V_PlateCarrier1_blk is now rank-based ((call AP_copLevel) >= 4) so Sgt+ can buy the Carrier Light without prestige talent
- **By:** player053  ·  **Channel:** #report  ·  **ref:** 100000000000000760/100000000000000761

> **INVESTIGATED (2026-06-21) — intended talent-gating, OWNER DECISION.** The cop uniform shop Vests tab (`fn_clothing_cop.sqf` case 3) is NOT empty for a Sgt — belts/bandolliers show — but every BODY-ARMOR vest is talent-gated: TacVest needs side talent 83 ("Prudent"), `V_PlateCarrier1_blk` (Carrier Light) needs cop prestige talent 42 ("Invested (SGT+)") for rank 4, higher plates are LT+/Capt+ by rank. With beta god-stats now OFF (`AP_betaMaxStats=false`, init.sqf:638; god-stats auto-grant skipped), an un-prestiged Sgt has no armored vest = "no vests." The matching spawn loadout (`fn_copLoadout.sqf:28-32`) gives `V_Rangemaster_belt` without talent 83. **OWNER CHOSE: rank-based (2026-06-21). FIXED + STAGED.** Changed `fn_clothing_cop.sqf:284` gate `((call AP_copLevel)>=5)||((call AP_copLevel)>=4 && 42 in AP_cop_talents)` → `(call AP_copLevel) >= 4`, so every Sgt+ can buy the Carrier Light (`V_PlateCarrier1_blk`) without prestige talent 42. Level IV/V plates still LT+/Capt+. Spawn loadout (`fn_copLoadout.sqf:28`) left as-is (cops buy their kit). Mission repack.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000762> (`player053` · `100000000000000762`)
**Date / Time:** now

**Description of event / rule broken:**
No vests in cop unifrom shop for Sgt+ slot on cop

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000763/100000000000000764/image.png?ex=6a3992cc&is=6a38414c&hm=81717954d5f0eba2fa395c15352a39fcae93686e190cd8f4ca9acf968a56a03b&

---

### #467 · DUP · 2026-06-21T20:01Z
- **By:** player055  ·  **Channel:** #report  ·  **ref:** 100000000000000765/100000000000000766

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000327> (`player055` · `100000000000000327`)
**Date / Time:** now

**Description of event / rule broken:**
jewelry emporium is still bugged. You can load the jewels and do the plasma cutter, but the quilin minigun doesnt spawn at all, nothing happens

**Evidence:**
_none provided_

---

### #468 · INVALID · 2026-06-21T20:31Z
- **By:** player070  ·  **Channel:** #report  ·  **ref:** 100000000000000767/100000000000000768

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000769> (`player070` · `100000000000000769`)
**Date / Time:** just now

**Description of event / rule broken:**
a person came up to me we have been mining next to eachother for a while he told me to check my vic inv since his half of inv was gone and i check mine and my half was gone to we had out vics locked both and i had almost filled my vic

**Evidence:**
i am now looking i have 29 uncut diamons 13 gold dabloons ( got it in admin gift its correct value ) 6 flawless diamonds what i had was around 223 uncut diamonds and 42 flawless diamonds and one gold nugget
https://cdn.discordapp.com/attachments/100000000000000770/100000000000000771/image.png?ex=6a399bb7&is=6a384a37&hm=e5edb4aa8de04f140bb6ccf55db7721d2547278eca87f1828561470e63c55968&

---

### #469 · FIXED · 2026-06-21T20:48Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — mission/LooneyBin.Altis/core/session/fn_requestReceived.sqf:203 · fn_requestReceived now reads the gang house position from param[3] instead of param[5], with the #469 fix comment.
- **By:** player004  ·  **Channel:** #report  ·  **ref:** 100000000000000772/100000000000000773

> **ROOT CAUSE (2026-06-21):** client `fn_requestReceived.sqf` rebuilt `AP_gang_data` reading the gang HOUSE position from `param[5]` (a vestigial `[0,0,0]` placeholder) instead of `param[3]`, where the server packs it (`fn_queryRequest.sqf:212`, "slot 3 = gang HOUSE position"). So `AP_gang_data[3]` was **always `[0,0,0]`** for every member + leader → `fn_initGang:24` (map marker + building-find + `AP_gangBuilding` for garage/access) AND `fn_spawnPointCfg:73` (the "gangbldg" spawn point) are BOTH gated on `[3] != [0,0,0]` → both skipped → no map marker, no spawn, no garage/access at the gang house, server-wide. Lines up with the 06-16 server slot move + the 06-18 spawn rewrite (#343-347) that newly drove spawn off `AP_gang_data[3]` = "broke ~3 days ago". **FIX (STAGED, needs mission repack+deploy):** read `param[3]`. One line. Affects every gang. DB `gangs.house_pos` was fine all along (12 gangs have valid positions).

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000232> (`player004` · `100000000000000232`)
**Date / Time:** just now

**Description of event / rule broken:**
gang houses are still broken we can't spawn on them or see on the map they not on or keychain and can't be used

**Evidence:**
_none provided_

---

### #470 · DUP · 2026-06-21T21:00Z
- **By:** player006  ·  **Channel:** #report  ·  **ref:** 100000000000000774/100000000000000775

> **DUP of #469** — same gang-house-dead bug (`AP_gang_data[3]` read from wrong slot). thelotus's gang Menace (50005) HAS a valid `house_pos`; the member-side init was skipped. Fixed by the #469 one-liner.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000127> (`player006` · `100000000000000127`)
**Date / Time:** been a while i wanna say the last 3 days or so maybe more

**Description of event / rule broken:**
the gang house isnt accessable to sppawn at or see... i bet yall are getting constant reports for that tho

**Evidence:**
_none provided_

---

### #471 · FIXED · 2026-06-21T21:18Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — mission/LooneyBin.Altis/core/config/fn_vehicleTextures.sqf:1 · The Crank RV texture row [2,"C_Van_01_box_F",["civ"],"civ_special",...,"Crank RV","images\Van_01_adds_crank.jpg"] is present, so the RV shop skin list is popula
- **By:** player086  ·  **Channel:** #report  ·  **ref:** 100000000000000776/100000000000000777

> **ROOT CAUSE + FIX (2026-06-21, STAGED — mission repack).** The crank/meth RV vendor (chop-shop RV Shop, tag `civ_special` per `fn_chopshop.sqf:13/23`) sells a crank-skinned `C_Van_01_box_F`, but the shop's skin dropdown (`fn_vehicleShopLBChange`→`ownedTextures`) shows ONLY texture rows whose field-3 == `"civ_special"` (the normal color branch is explicitly excluded for `civ_special`). **No texture row had field-3=`civ_special`** — only White(0)/Red(1), both field-3="" — so the skin list was empty → you could only buy a plain box van ("truck boxer"), and the crank-lab actions (which gate on the `Van_01_adds_crank.jpg` texture) never lit up. **Fix applied:** added one row to `fn_vehicleTextures.sqf` — `[2,"C_Van_01_box_F",["civ"],"civ_special",0,0,0,0,-1,[],"Crank RV","images\Van_01_adds_crank.jpg"]` (skinID 2 unique; image asset present). Verify in-game the lab scroll-actions appear on a bought Crank RV (texture-path resolution); if not, switch field-11 to the full `mpmissions\__cur_mp.altis\images\...` path.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000625> (`player086` · `100000000000000625`)
**Date / Time:** now

**Description of event / rule broken:**
not able to buy an RV for crank

**Evidence:**
RV shop only sells truck boxers

---

### #472 · FIXED · 2026-06-21T21:57Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — server/AP_server/core/TON/fn_gangBank.sqf:143 · Gang transfer case 4 online branch now writes the credit durably to the DB (UPDATE players SET bankacc) with an explicit #475/#472 comment, so a relogged recipi
- **By:** player026  ·  **Channel:** #report  ·  **ref:** 100000000000000778/100000000000000779

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000516> (`player026` · `100000000000000516`)
**Date / Time:** just now

**Description of event / rule broken:**
sent money to gangmates from the gang account and they didnt receive it

**Evidence:**
https://streamable.com/6jsg3z

---

### #473 · FIXED · 2026-06-21T22:00Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — mission/LooneyBin.Altis/dialog/function/fn_gangBankHist.sqf:18 · fn_gangBankHist.sqf:18-19 now waits for BOTH the data and ready flag with a 10s timeout and distinguishes empty history from a real failure, closing the async r
> staged 2026-06-22: ROOT-CAUSED. Server sent data + ready flag as two UNORDERED async netSetVar msgs; client woke on ready before data -> false "Failed to fetch". Fix (fn_gangBankHist.sqf): wait for BOTH (+10s timeout), distinguish "no history yet" from a real failure, dropped the stray lnbAddColumn (4th col over the .hpp's 3).
- **By:** player019  ·  **Channel:** #report  ·  **ref:** 100000000000000780/100000000000000781

> **INVESTIGATED (2026-06-21) — narrowed, needs live test.** Dialog IS defined (MasterHandler.h includes gangBankHistory.hpp; idd=100300 + idc=100302 MATCH fn_gangBankHist.sqf) and the netSetVar transport is whitelisted + server-origin-gated OK. So not the include/IDC/transport. Most likely: (a) the gang has NO gang_bank_log rows -> _hist=[] -> the misleading 'Failed to fetch the gang history' message (UX, not a real failure), or (b) a render-loop edge in fn_gangBankHist.sqf after the data arrives. Needs the reporter's screenshot + a live test with a gang that HAS history. Low-impact (display only).

> **INVESTIGATED (2026-06-21) — narrowed, not yet root-caused.** APS_fnc_gangBHistory queries gang_bank_log + replies via AP_fnc_netSetVar; BOTH AP_gangBank_History + AP_gangHistory_Ready ARE on the netSetVar whitelist AND the server-origin gate (remoteExecutedOwner==2) passes, so transport is NOT the blocker. gang_bank_log has rows. Suspect the client dialog (display 100300 / ctrl 100302 'gangBankHistory') definition or its render loop. Needs a dialog-class check + live test. DEFERRED for a focused pass.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000083> (`player019` · `100000000000000083`)
**Date / Time:** Just now

**Description of event / rule broken:**
Gang Bank History does not work

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000292/100000000000000782/Screenshot_20260621_175931.png?ex=6a39b060&is=6a385ee0&hm=cd3f5879da5258145b965a3100e246a7811abb5aa0f0e9e6df0ddf57f4c14986&

---

### #474 · FIXED · 2026-06-21T22:04Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — server/AP_server/core/TON/fn_gangFortressSRV.sqf:53 · fn_gangFortressSRV.sqf:53-59 creates an invisible marker per spawn spot and passes their NAMES to the shop, fixing the position-array 'blocked' bug.
- **By:** player039  ·  **Channel:** #report  ·  **ref:** 100000000000000783/100000000000000784

> **FIXED+STAGED (server).** Gang-fort rebel vehicle spawn 'blocked when nothing's there': fn_gangFortressSRV passed BIS_fnc_findSafePos POSITION ARRAYS as the shop spawn points, but fn_vehicleShopBuy only resolves marker-name strings (getMarkerPos) or objects (getPosATL) -> getMarkerPos([x,y,z])->[0,0,0]->no valid spot->'blocked'. Now creates invisible markers at the spawn spots + passes their NAMES (like normal outposts 'reb_g_4'); added to outpost cleanup.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000183> (`player039` · `100000000000000183`)
**Date / Time:** just now

**Description of event / rule broken:**
vehicle spawn at gang fort rebel is showing blocked when nothing is there

**Evidence:**
_none provided_

---

### #475 · FIXED · 2026-06-21T22:44Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — server/AP_server/core/TON/fn_gangBank.sqf:143 · The online gang-transfer branch now writes a durable UPDATE players SET bankacc to the DB in addition to the live HUD sync.
- **By:** player046  ·  **Channel:** #report  ·  **ref:** 100000000000000785/100000000000000786

> **FIXED+STAGED (server).** Gang transfer to an ONLINE gangmate credited CLIENT-SIDE only (AP_fnc_uC) -> lost if they relogged/crashed/sat at spawn-select before saving (comp/mailbox shape). fn_gangBank op4 online branch now ALSO writes the credit to the DB (durable, converges, no double-count). 'lost on cartel payouts' = likely the same client-side pattern in the cartel payout path — flagged for a follow-up check.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000504> (`player046` · `100000000000000504`)
**Date / Time:** Start of last restart

**Description of event / rule broken:**
Sending payment through gang bank to gang mates doesnt arrive lost 200 on cartel payouts once didnt receive im assuming other didnt as well

**Evidence:**
_none provided_

---

### #476 · DUP · 2026-06-21T22:54Z
- **By:** player055  ·  **Channel:** #report  ·  **ref:** 100000000000000787/100000000000000788

> **DUP of #474** — same gang-fort rebel vehicle-spawn bug (position-array spawn points). Fixed by the #474 marker conversion.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000327> (`player055` · `100000000000000327`)
**Date / Time:** now

**Description of event / rule broken:**
rebels for gang fort do not work. Cant spawn vehicles

**Evidence:**
_none provided_

---

### #477 · FIXED · 2026-06-21T23:04Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — server/AP_server/core/system/fn_chopShopSell.sqf:44-45,82-83 (+ client mission/LooneyBin.Altis/core/shops/fn_chopShopSell.sqf:17) · Server chop falls back to AP_dbInfo and DELETEs gang vehicles from gang_vehicles, and the client gate now allows gang vehicles past the AP_side check.
- **By:** player026  ·  **Channel:** #report  ·  **ref:** 100000000000000789/100000000000000790

> **ROOT CAUSE + FIX (2026-06-21, STAGED — mission+server).** Gang-vehicle twin of #427. The server chop handler (APS_fnc_chopShopSell) read `dbInfo`, but gang (and garage-pulled) vehicles set only `AP_dbInfo` -> dbInfo came back [] -> the handler EXITED at the count-0 guard = a SILENT no-op (click chop, nothing happens). Even past that it called DB_fnc_deleteVehicle on the PERSONAL `vehicles` table, where a gang vehicle has no row -> the owning gang could re-pull it = 'chop didn't work'. FIX: (1) server falls back to AP_dbInfo, and for a gang vehicle (AP_dbInfo=[gangId,plate,true]) DELETEs from `gang_vehicles` by gang_id+plate so it's actually destroyed; (2) client gate (fn_chopShopSell.sqf) also allows gang vehicles past the AP_side check in case side is unstamped. Personal chop unchanged.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000516> (`player026` · `100000000000000516`)
**Date / Time:** just now

**Description of event / rule broken:**
cant chop a gang vehicle??

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000655/100000000000000791/image.png?ex=6a39bf6b&is=6a386deb&hm=17eaa3f5d999fa01bead0f5dbb42676b155311939b5117eaa294212ab3efc0a9&

---

### #478 · DUP · 2026-06-21T23:05Z
- **By:** player077  ·  **Channel:** #report  ·  **ref:** 100000000000000792/100000000000000793

> **DUP of #453/#457** — Orca/Hummingbird gone from garage = personal vehicle stuck active='1' after a failed restore (hidden by the garage query). Fixed by the #457 fn_restoreVehicles boot reset (returns them to garage next restart).

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000450> (`player077` · `100000000000000450`)
**Date / Time:** Few days ago

**Description of event / rule broken:**
I had a orca and a humming bird now they aren’t in my garage

**Evidence:**
No

---

### #479 · FIXED · 2026-06-22T00:23Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — server/AP_server/init.sqf:1031 · Per-owning-gang crate fill gate AP_crateFilledFor is present so the crate no longer empties/refills on uncap.
> staged 2026-06-22: SAME root cause as #499 (cartel weapon-crate fill/empty loop), NOT a separate decision. "Open full of guns, next time it's gone" = the 60s loop emptied the crate the moment the gang's cap decayed (stepped off the flag) -- the intended anti-street-loot wipe -- compounded by the dupe-refill churn. #499's per-owning-gang fill gate (AP_crateFilledFor) is the real fix and ships in b0088. Resolved with #499. (Retracts an earlier "physics box-swap" framing -- that was wrong.)
- **By:** player077  ·  **Channel:** #report  ·  **ref:** 100000000000000794/100000000000000795

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000450> (`player077` · `100000000000000450`)
**Date / Time:** Now

**Description of event / rule broken:**
Cartel those loot boxes open it full of guns next time you open it’s all gone

**Evidence:**
_none provided_

---

### #480 · FIXED · 2026-06-22T00:23Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — server/AP_server/init.sqf:1031 · The per-gang AP_crateFilledFor fill gate (the #499 fix #480 folded into) is present, and the 'one gun in hotbar' half is not a bug.
> staged 2026-06-22: same as #479/#499 (cartel crate empties on uncap + dupe-loop churn -> fixed via #499's per-gang fill gate, b0088). The "only hold 1 gun in your hotbar" half is NOT a bug: Arma permits one primary at a time (rifle goes on the back), extra rifles ride in the trunk/inventory, not a hotbar slot. No separate fix needed.
- **By:** player023  ·  **Channel:** #report  ·  **ref:** 100000000000000796/100000000000000797

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000475> (`player023` · `100000000000000475`)
**Date / Time:** just now

**Description of event / rule broken:**
Cartel crates show the loot then once you close out of it you cant see it anymore and plus you can only hold 1 gun in your hotbar?

**Evidence:**
no clips

---

### #481 · FIXED · 2026-06-22T00:32Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — server/AP_server/core/jail/fn_startPrisonBreak.sqf:95 · The SRV_prisonData[1] release gate is now cleared after a deferred uiSleep 70 instead of the same frame, preserving the escape window.
> staged 2026-06-22: prison-release gate (SRV_prisonData[1]) cleared in the same frame as the release -> deferred ~70s in fn_startPrisonBreak so the escape window survives.
- **By:** player009  ·  **Channel:** #report  ·  **ref:** 100000000000000798/100000000000000799

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000800> (`player009` · `100000000000000800`)
**Date / Time:** 6/21/2026 8:31 ET

**Description of event / rule broken:**
Prsion break broken. Did not let me out of prison when I clicked to be released

**Evidence:**
_none provided_

---

### #482 · NOTABUG · 2026-06-22T00:49Z
> closed 2026-06-22: NOT a b0087 regression -- pre-existing gang-vehicle store edge that self-heals on the next restart (stale active flag). Monitor; reopen if it recurs post-deploy.
- **By:** player010  ·  **Channel:** #report  ·  **ref:** 100000000000000801/100000000000000802

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000803> (`player010` · `100000000000000803`)
**Date / Time:** just now

**Description of event / rule broken:**
gang vehicle bug being presistance and not storing

**Evidence:**
_none provided_

---

### #483 · NOTABUG · 2026-06-22T00:54Z
> closed 2026-06-22: NOT a bug -- no $25M loss in the DB or logs; the player never held it. No action.
- **By:** player045  ·  **Channel:** #report  ·  **ref:** 100000000000000804/100000000000000805

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000806> (`player045` · `100000000000000806`)
**Date / Time:** just now

**Description of event / rule broken:**
i dont have 25 million dollars in my account

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000807/100000000000000808/image.png?ex=6a39d95f&is=6a3887df&hm=0fbd9f007d1d5981a9fa720b4fe0da3f394182a18adb0e43a6616e6bbf03df88&

---

### #484 · NOTABUG · 2026-06-22T01:05Z
> notabug 2026-06-22: NO LOSS -- DB-checked, mint's truck (plate 820691 B_Truck_01_transport_F) HAS rubber 425 in the trunk (active=0, in garage). Trunk persists on store + the graceful restart save (waitUntil scriptDone) + the 8-min vehicle_mem fallback. Transient at the 00:43 restart; recovered. (The #494 blocking-store fix also tightens the store path.)
- **By:** player010  ·  **Channel:** #report  ·  **ref:** 100000000000000809/100000000000000810

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000803> (`player010` · `100000000000000803`)
**Date / Time:** just now

**Description of event / rule broken:**
vehicle was stored after restart and didnt have my rubber in the vehicle

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000811/100000000000000812/ArmA_3_Screenshot_2026.06.21_-_18.04.10.72.png?ex=6a39dbc9&is=6a388a49&hm=8eff161bbe79649b1d2062831d1930d82e6c685de44b2c0676e542dd35cbdf1f&
https://cdn.discordapp.com/attachments/100000000000000811/100000000000000813/ArmA_3_Screenshot_2026.06.21_-_18.04.06.36.png?ex=6a39dbc9&is=6a388a49&hm=600799cf46ab1da9c40047406a706c109c14ac0dddb06b4c543e44f2aca615ae&

---

### #485 · WONTFIX · 2026-06-22T01:06Z
> wontfix 2026-06-22 (owner: "cantfix arma issue"): "bank texture issues" (screenshot) = client-side Arma texture/LOD streaming glitch on the base-map bank building, not a server/mission fault. Nothing in our code controls stock-map building textures, so it can't be fixed from the backend. Reporter remedy: verify game files / raise texture-memory preset if it persists.
- **By:** player053  ·  **Channel:** #report  ·  **ref:** 100000000000000814/100000000000000815

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000762> (`player053` · `100000000000000762`)
**Date / Time:** now

**Description of event / rule broken:**
bank texture issues

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000763/100000000000000816/image.png?ex=6a39dc2a&is=6a388aaa&hm=7a5f53561ed87e768f5e2b02ea776fe118930521f450708153440103cbca7a91&

---

### #486 · FIXED · 2026-06-22T01:20Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — server/AP_server/core/system/fn_monitorCaptures.sqf:80 · On owner-flip (_new==1) fn_monitorCaptures now flushes DB_fnc_updateCaptures immediately (lines 75-80), closing the up-to-8-min loss window on a fresh cartel ca
> staged 2026-06-22: ROOT-CAUSED. Cartel ownership only saved on the 8-min periodic updateCaptures -> a restart inside that window dropped a fresh cap. Fix: fn_monitorCaptures now flushes updateCaptures IMMEDIATELY on owner-flip (_new==1). Zero loss window now.
- **By:** player023  ·  **Channel:** #report  ·  **ref:** 100000000000000817/100000000000000818

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000475> (`player023` · `100000000000000475`)
**Date / Time:** just now

**Description of event / rule broken:**
We had cartels capped before restart and they didnt transfer after restart

**Evidence:**
_none provided_

---

### #487 · NEEDINFO · 2026-06-22T01:22Z
> needinfo 2026-06-22: fn_handleJail ALREADY re-fetches the offender's real bounty before jailing (existing race-fix), and bail = the CRIME bounty, NOT the bounty-hunter catch-reward -- a 50k BH bounty with low crimes legitimately yields a low bail. Need the reporter's exact repro: what CHARGES did they have (the wanted menu), and was the "50k" the crime bounty or a BH bounty?
- **By:** player047  ·  **Channel:** #report  ·  **ref:** 100000000000000819/100000000000000820

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000066> (`player047` · `100000000000000066`)
**Date / Time:** hour ago

**Description of event / rule broken:**
had a 50k bounty

**Evidence:**
i pressed 1 inventory of plates and my bail was 1.5kj

---

### #488 · NOTABUG · 2026-06-22T01:31Z
> notabug 2026-06-22: NO LOSS -- DB-checked, Type03's heli (plate 732674 O_Heli_Light_02_unarmed_F) IS in the garage (active=0); all 5 personal vehicles intact; gang 50004 had no gang vehicles. Out-vehicles return to the garage via the boot active=1->0 reset. Transient stuck-active at the 00:43 restart; self-healed. (Covered by the #494 blocking-store tightening too.)
- **By:** player077  ·  **Channel:** #report  ·  **ref:** 100000000000000821/100000000000000822

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000450> (`player077` · `100000000000000450`)
**Date / Time:** Now

**Description of event / rule broken:**
Same thing my helis aren’t in my garage

**Evidence:**
No

---

### #489 · FIXED · 2026-06-22T01:36Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — server/AP_server/core/system/fn_monitorCaptures.sqf:80 · Depends on #486 cartel-persist fix, which is present: fn_monitorCaptures flushes DB_fnc_updateCaptures immediately on owner-flip (_new==1), and the comment expl
> staged 2026-06-22: NOT a gang-bank bug -- gang 50004 had ZERO bank history (deposits/income/withdraws), and the bank is robustly DB-authoritative. The "50k" was CARTEL INCOME that died when the cartels reset on restart (#486). Fixed by the #486 cartel-persist fix.
- **By:** player023  ·  **Channel:** #report  ·  **ref:** 100000000000000823/100000000000000824

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000475> (`player023` · `100000000000000475`)
**Date / Time:** JUST NOW

**Description of event / rule broken:**
we had 50k in gang bank now its gone?

**Evidence:**
_none provided_

---

### #490 · NEEDINFO · 2026-06-22T02:23Z
> needinfo 2026-06-22: "mined a full inventory, got 1 gold nugget." Most likely the WEIGHT CAP -- a full virtual inventory only had room for 1 more nugget. Need: was the inventory already near full? what's the gather yield per attempt vs free weight? Screenshot of the inv weight before/after.
- **By:** player047  ·  **Channel:** #report  ·  **ref:** 100000000000000825/100000000000000826

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000066> (`player047` · `100000000000000066`)
**Date / Time:** just now

**Description of event / rule broken:**
just did these inventories mining.....all I got was 1 golden nugget

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000079/100000000000000827/207E3B1.JPG?ex=6a39ee09&is=6a389c89&hm=20451b4bbe86c112757bf700921550689fdd755cc0cf753c6659ed3eb0708d95&

---

### #491 · FIXED · 2026-06-22T03:33Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — server/AP_server/core/DB/fn_updateRequest.sqf:17; mission/LooneyBin.Altis/core/session/fn_ClupdateRequest.sqf:16 · Both the server MONEYGUARD nil/type check and the client nil-money guard are present.
> staged 2026-06-22: ROOT-CAUSED (money-wipe). At connect, fn_ClupdateRequest fired before the session loaded AP_cash/atmcash (AP_session_completed stale-TRUE) -> packet shipped [..,any,any] -> server DB_fnc_updateRequest defaulted nil->0 -> wrote bankacc=0 a split-second before the login read it back (Vista 423,432 -> 0). Fix: nil-money guard in BOTH fn_ClupdateRequest (client) + DB_fnc_updateRequest (server backstop, -MONEYGUARD- log). Complete victim sweep = Vista + kylej ONLY (both self-recovered). 38500 guard did NOT cover this pre-load path.
- **By:** player069  ·  **Channel:** #report  ·  **ref:** 100000000000000828/100000000000000829

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000830> (`player069` · `100000000000000830`)
**Date / Time:** 06/21/2026

**Description of event / rule broken:**
Logged in and my money was all gone down to 0 dollars

**Evidence:**
https://gyazo.com/2eb2aaf7ac6a7f5ee8555973da3487bd

---

### #492 · FIXED · 2026-06-22T06:40Z
> triage 2026-07-04 (bugs-triage): was NEW, code-verified FIXED — mission/LooneyBin.Altis/core/config/fn_mapData.sqf · A truckShop NPC now exists in Sofia at [25819,21442] (absent from the older fn_mapData.sqf.bak2) and fn_civVehicles.sqf:118-120 opens the Truck Shop, so Sofia h
- **By:** player092  ·  **Channel:** #report  ·  **ref:** 100000000000000831/100000000000000832

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000137> (`player092` · `100000000000000137`)
**Date / Time:** just now

**Description of event / rule broken:**
No truck shop in sofia

**Evidence:**
https://gyazo.com/41d56b55c208ccd1272854831b466cf7

---

### #493 · FIXED · 2026-06-22T06:51Z
> triage 2026-07-04 (bugs-triage): was NEW, code-verified FIXED — mission/LooneyBin.Altis/core/actions/fn_crankLab.sqf:131 · RV cook smoke was reworked to render globally/JIP-safe via AP_labMode broadcast, fn_attachSmoke _isLab flag, and the initPlayerLocal.sqf:291 per-client rendere
- **By:** player086  ·  **Channel:** #report  ·  **ref:** 100000000000000833/100000000000000834

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000625> (`player086` · `100000000000000625`)
**Date / Time:** Now

**Description of event / rule broken:**
RV does not emit smoke during cooking

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000626/100000000000000835/IMG_7968.jpg?ex=6a3a2cd2&is=6a38db52&hm=c98c1a2bceaea097a41e3ba6e86a86c8980f724434ad905d12147def15259096&

---

### #494 · FIXED · 2026-06-22T07:03Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — server/AP_server/core/DB/fn_updateVehicle.sqf:74 · fn_updateVehicle now honors a _blocking param (line 14/74) and fn_vehicleStore.sqf:69,94 pass true, so active=0 commits before the 'stored in your garage' reply
> staged 2026-06-22: NO LOSS -- DB-checked, player092's Ifrit (plate 550703 O_MRAP_02_F) IS in the garage (active=0). No $70k comp. Root of "stored it but it's gone": fn_updateVehicle's active=0 + trunk write was ASYNC, so reopening the garage before it committed showed nothing. FIX: store/impound now pass _blocking=true -> active=0 commits BEFORE the "stored in your garage" reply, so the garage reliably shows it. Restore/idle stay async.
- **By:** player092  ·  **Channel:** #report  ·  **ref:** 100000000000000836/100000000000000837

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000137> (`player092` · `100000000000000137`)
**Date / Time:** just now

**Description of event / rule broken:**
claimed a ifrit went to garage and stored it and it's not in my garage anymore i need 70k back

**Evidence:**
_none provided_

---

### #495 · NOTABUG · 2026-06-22T07:27Z
> closed 2026-06-22: NOT a bug -- 25yr scotch still legitimately comes from the aging step ("Age Scotch (Aging Chemicals)", scotch_2 -> scotch_3). The house barrel caps at 15yr; the factory/aging path still exists. Distillery text is correct; reporter misread it.
- **By:** player092  ·  **Channel:** #report  ·  **ref:** 100000000000000838/100000000000000839

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000137> (`player092` · `100000000000000137`)
**Date / Time:** just now

**Description of event / rule broken:**
the text for the spirit distillery says you have to go to purification factory for 25 years scotch which doesnt exist anymore cause it goes up to 25 years in ur house

**Evidence:**
https://gyazo.com/8a6e3b68e1f3fbb8075b8edf08f0fe5c

---

### #496 · FIXED · 2026-06-22T07:35Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — server/AP_server/init.sqf:689 · AP_fnc_tenuredCops (300s continuous on-duty gate) is defined in init.sqf and enforced by the bank/jewelry/fed heist gates (fn_bankDrillVault.sqf:29 etc.), clos
> staged 2026-06-22: CONFIRMED exploitable (NOT already fixed). Every heist cop-count gate (bank/jewelry/fed) counted a raw `west countSide allPlayers` snapshot, so whitelisted players flipping to cop side counted instantly -> a gang soft-logs members to cop to hit the bank's 4-cop requirement, starts the drill, then switches back to civ. FIX: server now tracks each cop's CONTINUOUS on-duty time (AP_copDutySince + 20s maintenance loop in init.sqf) and the gates count only cops on-duty >= AP_copTenureReq (300s) via AP_fnc_tenuredCops -> a just-switched soft-logger contributes 0. Side effect: heists blocked ~5 min after a restart (no tenured cops yet) -- acceptable/desirable. Threshold tunable; fed still beta-waived to 0.
- **By:** player019  ·  **Channel:** #report  ·  **ref:** 100000000000000840/100000000000000841

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000083> (`player019` · `100000000000000083`)
**Date / Time:** Just now

**Description of event / rule broken:**
player104 Street Killas except one Just all soft logged to cop to start a bank and then logged back to civ

**Evidence:**
_none provided_

---

### #497 · CLOSED · 2026-06-22T07:56Z
> closed 2026-06-22: owner comped the affected houses. Separately, Enrique now consumes house-stored seeds before buying (no relation to the sativa->golden-wax processing the reporter mentioned). No further action unless it recurs.
- **By:** player013  ·  **Channel:** #report  ·  **ref:** 100000000000000842/100000000000000843

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000519> (`player013` · `100000000000000519`)
**Date / Time:** just now

**Description of event / rule broken:**
My Sativa bud never turned into Indica, and I am now unable to process my sativa into golden wax after the update. I got comp for one house, now these are the other two houses that I have bud in. Thanks!

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000520/100000000000000844/7a4e478baa1ea29502134372c84e9959.png?ex=6a3a3c14&is=6a38ea94&hm=72a4a5843cd8442bd24fcee03ce92abfa3f3548e14deb74df2efad140e747621&
https://cdn.discordapp.com/attachments/100000000000000520/100000000000000845/30b96e161ab692607e01e3da69fd6d7d.png?ex=6a3a3c14&is=6a38ea94&hm=6b54dbffb612455a5da5aefa7b22bca368541947cb50e88705bd7e72d821c59f&

---

### #498 · FIXED · 2026-06-22T14:49Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — mission/LooneyBin.Altis/core/configuration.sqf:7 · Cop 'Gangs Online' phone button (playerSide west) calling AP_fnc_gangListMenu is present in configuration.sqf, with fn_gangListMenu.sqf and the cop 9-key gate
> staged 2026-06-22: cops can now pull the existing "Gangs Online" roster (AP_fnc_gangListMenu -- lists every civ gang online + its members, built from broadcast gang_data; the owner's 2026-06-13 press-9 civ roster). Two cop access paths: (1) NEW cop phone button "Gangs Online" (always available); (2) the 9 key, but ONLY when 9 isn't already MaxSec-redeploy/medic-respond for that cop (AP_copEviReq nil + non-medic role) so redeploy is untouched. NOTE: 9 can't be the SOLE bind because it's MaxSec redeploy for cops -- the phone button covers that. Flip to "9 always opens the roster for cops (override redeploy)" on request. (Earlier mismatch note retracted: the relevant fn was gangListMenu, not the personal gangMenu.)
- **By:** player055  ·  **Channel:** #report  ·  **ref:** 100000000000000846/100000000000000847

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000327> (`player055` · `100000000000000327`)
**Date / Time:** now

**Description of event / rule broken:**
Playing cop and dont have the ability to see whos in civ groups/gang

**Evidence:**
_none provided_

---

### #499 · FIXED · 2026-06-22T17:56Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — server/AP_server/init.sqf:1031 · init.sqf:1031-1033 gates the cartel crate refill once per owning gang via AP_crateFilledFor, so step-out/re-enter no longer refills.
> staged 2026-06-22: ROOT CAUSE -- the cartel weapon-crate fill loop (init.sqf) refilled ANY empty+capped crate every 60s, AND a leave/re-enter re-triggered it (cap decays on step-out, re-climbs on step-in) = infinite loot for a holding gang. FIX: gate the fill to ONCE per OWNING GANG (AP_crateFilledFor, NOT cleared on a brief uncap) -> step-out/re-enter by the same gang never refills; a DIFFERENT gang capping (or a reboot) gives a legit new fill. The dirty-money/rubber gangContainer income is a separate loop, unaffected.
- **By:** player017  ·  **Channel:** #report  ·  **ref:** 100000000000000848/100000000000000849

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000250> (`player017` · `100000000000000250`)
**Date / Time:** just now

**Description of event / rule broken:**
when you have a cartel and empty the crate then lveve the cap and reenter it the crate refuills its self

**Evidence:**
_none provided_

---

### #500 · FIXED · 2026-06-22T19:12Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — server/AP_server/core/system/fn_vehicleStore.sqf:42 · fn_vehicleStore reconstructs a valid 4-field dbInfo from AP_dbInfo when legacy dbInfo is empty, so pulled/restored vehicles store instead of being rejected.
> staged 2026-06-22: "This vehicle isn't a persistent vehicle" on store = fn_vehicleStore read the legacy `dbInfo`, which some pulled/restored vehicles lack (they carry only `AP_dbInfo`) -> _vInfo empty -> rejected (and IMPOUND would DELETE it). FIX: reconstruct dbInfo from AP_dbInfo [uid,plate] (mirrors the fn_saveVehicles #406 fallback) so owned vehicles store; a truly wild vehicle still correctly fails. The 425-rubber load is preserved (serialized into the inventory col on store).
- **By:** player005  ·  **Channel:** #report  ·  **ref:** 100000000000000850/100000000000000851

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000852> (`player005` · `100000000000000852`)
**Date / Time:** Just now

**Description of event / rule broken:**
I'm underwater at cartel oil collecting rubber. All 3 vehicles are fully loaded with 425 rubber but I can't store them. When I try I get a message saying "This vehicle isn't a persistent vehicle"

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000853/100000000000000854/rn_image_picker_lib_temp_12169aab-89a8-465f-9d30-2969992a172f.jpg?ex=6a3ada8f&is=6a39890f&hm=018b13ebc6b50740227fd686c949ce4b850d513261ba874958ab308322651ce1&

---

### #501 · FIXED · 2026-06-22T20:45Z
> triage 2026-07-04 (bugs-triage): was NEW, code-verified FIXED — server/AP_server/init.sqf:786-796 (+ fn_queryCaptures.sqf:85-101) · Turf now uses Asylum-style RECAP-ON-RED (owner loses it when the turf goes active) and held turf ownership is persisted/restored on boot, both explicitly tagged
- **By:** player054  ·  **Channel:** #report  ·  **ref:** 100000000000000855/100000000000000856

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000482> (`player054` · `100000000000000482`)
**Date / Time:** from the start

**Description of event / rule broken:**
from the start Turfs are lost on restart i imagine its not meant to do that as sometimes nobody can own it until 60mins before restart i believe asylum had it where when it would go red whoever owned it would lose it and have to recap it again

**Evidence:**
_none provided_

---

### #502 · FIXED · 2026-06-22T20:59Z
> triage 2026-07-04 (bugs-triage): was NEW, code-verified FIXED — server/AP_server/core/DB/fn_restoreVehicles.sqf:76 · restoreVehicles now gives ground vehicles a collision-settle and zeroes velocity + re-asserts saved damage before allowDamage, preventing the restart explosion.
- **By:** player020  ·  **Channel:** #report  ·  **ref:** 100000000000000857/100000000000000858

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000859> (`player020` · `100000000000000859`)
**Date / Time:** just now

**Description of event / rule broken:**
server restarted and my truck was exploded

**Evidence:**
scrren record caputed my other monitor for some reason. sorry for the report, but i did lose a full cargo van of unprocessed diamonds, at the processing plant

---

### #503 · FIXED · 2026-06-22T23:30Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — mission/LooneyBin.Altis/core/functions/fn_clientWireTransfer.sqf:2-16 · The receiver-side scriptAvailable(4) cooldown that silently dropped concurrent incoming wires was removed (comment explicitly cites #503), so a 3-mil transfer i
- **By:** player054  ·  **Channel:** #report  ·  **ref:** 100000000000000860/100000000000000861

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000482> (`player054` · `100000000000000482`)
**Date / Time:** now

**Description of event / rule broken:**
just sent someone 3 mil and they only got 2

**Evidence:**
logs

---

### #504 · WONTFIX · 2026-06-23T02:16Z
- **By:** player077  ·  **Channel:** #report  ·  **ref:** 100000000000000862/100000000000000863

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000450> (`player077` · `100000000000000450`)
**Date / Time:** Now

**Description of event / rule broken:**
Players can just log off and spawn inside a rebel that’s a bug?

**Evidence:**
_none provided_

---

### #505 · FIXED · 2026-06-23T03:51Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — server/AP_server/core/system/fn_cleanup.sqf:21 · fn_cleanup skips idle-reap for alive vehicles flagged AP_ignitionBombArmed so rigged traps persist.
- **By:** player087  ·  **Channel:** #report  ·  **ref:** 100000000000000864/100000000000000865
- **Resolution (2026-06-23):** Bomb was a red herring (never detonated; bomb code doesn't touch despawn timers). Qilin hit the 40-min idle-reap from #346. Per owner: vehicles with a LIVE ignition bomb now skip idle-reap (fn_cleanup.sqf), so traps persist until detonation/restart; flag cleared on detonation so wrecks still reap. STAGED — applies next repack.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000365> (`player087` · `100000000000000365`)
**Date / Time:** now

**Description of event / rule broken:**
No so much a bug but wanted to see if you would comp for it i had a quilit at rebel with a ignition exsplosive on it and it despawned before any other car there was a bunch of sports there and they didnt despawn.

**Evidence:**
Putting it on - https://medal.tv/games/arma-3/clips/mYfS3zYciepSUhNnb?invite=cr-MSwwR1QsMzEzODExMDY5&v=57

---

### #506 · FIXED · 2026-06-23T03:54Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — server/AP_server/init.sqf:1107 · Oil rubber generation is nerfed to rate 1 / cap 100 with a comment explicitly citing #506/#508, so it is capped, not infinite or refill-to-full.
- **By:** player094  ·  **Channel:** #report  ·  **ref:** 100000000000000866/100000000000000867

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000461> (`player094` · `100000000000000461`)
**Date / Time:** just now

**Description of event / rule broken:**
I believe oil cartel is infinitely spawning far more than intended rubber. It's an infinite money "glitch" right now.

**Evidence:**
none. only what gangmates are saying in discord

---

### #507 · NEEDINFO · 2026-06-23T04:11Z
- **By:** player055  ·  **Channel:** #report  ·  **ref:** 100000000000000868/100000000000000869

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000327> (`player055` · `100000000000000327`)
**Date / Time:** now

**Description of event / rule broken:**
MaxTac Garage does not work still lol

**Evidence:**
_none provided_

---

### #508 · FIXED · 2026-06-23T04:12Z
> triage 2026-07-04 (deep-dive): was STAGED, code-verified FIXED — server/AP_server/init.sqf:1107 (rate 25->1, cap 250->100, tick 120->60s, comment explicitly cites #506/#508) and init.sqf:1132 (`_new = (_cur + _rat
- **By:** .8.0000  ·  **Channel:** #report  ·  **ref:** 100000000000000870/100000000000000871

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000262> (`.8.0000` · `100000000000000262`)
**Date / Time:** now

**Description of event / rule broken:**
Hey was just at oil and saw that it reset to the full amount after every few mins

**Evidence:**
_none provided_

---

### #509 · NOTABUG · 2026-06-23T12:38Z
- **By:** player076  ·  **Channel:** #report  ·  **ref:** 100000000000000872/100000000000000873

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000874> (`player076` · `100000000000000874`)
**Date / Time:** just now

**Description of event / rule broken:**
server lost connection or restarted randomly, i dont know, but i was flying full kit in my orca and crashed when it lost connection.

**Evidence:**
https://youtu.be/KpLd3onhn4Q

---

### #510 · NOTABUG · 2026-06-23T17:29Z
- **By:** player020  ·  **Channel:** #report  ·  **ref:** 100000000000000875/100000000000000876

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000859> (`player020` · `100000000000000859`)
**Date / Time:** JUST NOW

**Description of event / rule broken:**
Having a vehicle crash into you, blows it up

**Evidence:**
https://youtu.be/duJNEnEMyRE   I was using the processed diamonds to craft and as soon as i was pulling out player071 was flying down the MSR with no sirens. partly my fault for not looking both ways. If i can get comp of the diamonds and a new van ill be happy. those diamonds take FOREVER to mine.

---

### #511 · NOTABUG · 2026-06-23T23:26Z
> notabug 2026-06-24: troll/nonsense report ("scream microaggressions at the exploit and it gets triggered" + an unrelated stock twitter image). No actionable content.
- **By:** player063  ·  **Channel:** #report  ·  **ref:** 100000000000000877/100000000000000878

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000645> (`player063` · `100000000000000645`)
**Date / Time:** tomorrow

**Description of event / rule broken:**
scream microaggressions at the exploit and it gets triggered

**Evidence:**
https://pbs.twimg.com/media/FLilaMYXEAIvw31.jpg

---

### #512 · NEEDINFO · 2026-06-23T23:37Z
> needinfo 2026-06-24: traced statically, can't reproduce. Store routes gang-vs-personal in `fn_storeVehicle.sqf:60-63`
> (`_isGang = str(AP_dbInfo[0]) == str(myGangId)` -> gang `gangGarageStore`, else personal `vehicleStore` = the
> "doesn't belong to you" msg). The pull (`gangGaragePull:195` sets `AP_dbInfo=[str(gangId),plate,true]`) and restore
> (`restoreVehicles:104`, slot-0 preserved as the gang-id string) BOTH tag it correctly, and `prepareVehicle` does NOT
> clobber dbInfo -> `_isGang` should be true. So the static paths look right; need repro to pinpoint. QUESTIONS for
> player012: (1) stored from INSIDE the Orca (piloting) or standing next to it? (2) same gang that pulled it, or did
> your gang/rank change since? (3) was it freshly pulled or out across a server restart? (4) does it happen with gang
> CARS too or only air? One concrete robustness lead if confirmed: `fn_storeVehicle:61` reads `AP_dbInfo[0]` with a
> STRING type-filter (`param[0,"",[""]]`) while the near-veh findIf (:12) uses none — if slot 0 is ever non-string the
> filter defaults it to "" -> false personal-route. Harden both to `str()`-normalize once repro confirms the trigger.
- **By:** player012  ·  **Channel:** #report  ·  **ref:** 100000000000000879/100000000000000880

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000881> (`player012` · `100000000000000881`)
**Date / Time:** just now

**Description of event / rule broken:**
im not able to store Orcas Transfered to gang air garage but im able to pull them out, when i try to store it says "this vehicle does not belong to you"

**Evidence:**
_none provided_

---

### #513 · NEEDS-REPRO · 2026-06-24T00:07Z
> investigated 2026-06-24 (NO FIX — cannot root-cause from logs, no guess): player038 = UID 76561190000000007. DB bank=1,210,929; his LAST logged+persisted bank value was 1,233,429 (WITHDRAW id 1027791 @ 03:19:26, 20s before DC). Gap = exactly −22,500, with NO ledger row accounting for it on his account. DISPROVED the easy theory: `DB_fnc_numberSafe` does NOT corrupt — 1,233,429 is exactly float32-representable and numberSafe(1233429)="1233429" (verified). The final bank packet sent (FNCALL 1027792) was case-6 SET bankacc=1,233,429; no later client packet wrote a lower value; disconnect saved POSITION ONLY (`fn_playerDisconnected.sqf:43/47/50` mode 10) + `flushPlayer` (drains buffer, no live bank). So a −22,500 landed server-side AFTER his SET, but: he paid NO in-game house tax that session, owns 4 houses, has NO `-HOUSETAXDISCORD-` (Latoya bot) charge, and no tax/fee/rent log row matches. STRUCTURAL LATENT ISSUE found (not proven to be his cause): periodic `core/session/fn_ClupdateRequest.sqf:128` writes bankacc as an ABSOLUTE SET from client `AP_atmcash`, while server/offline paths (`fn_processMailbox`, `fn_gangBank`, `loonybot/latoya.py`, `enrique.py`) do direct `bankacc=bankacc±X` increments → an absolute SET from a stale client packet landing AFTER a direct increment in the async queue silently clobbers it ("online session clobbers direct edits"). NEEDS: the reporter's medal.tv clip (shows the actual number he saw) OR a repro — without it the exact −22,500 can't be pinned, and the fix (touching hot money-save code w/ the existing player108/Vista 0-wipe guards) is too risky to guess. Restitution if owner approves & player OFFLINE: `UPDATE players SET bankacc=1233429 WHERE playerid='76561190000000007'` (back up first).

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000455> (`player038` · `100000000000000455`)
**Date / Time:** now

**Description of event / rule broken:**
lost money at bank

**Evidence:**
https://medal.tv/games/arma-3/clips/mYBgOTwIklWW956eE?invite=cr-MSx1Rk8sMjE1Njc0NzAz

---

### #514 · NEW · 2026-06-24T01:16Z
- **By:** player056  ·  **Channel:** #report  ·  **ref:** 100000000000000882/100000000000000883

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000416> (`player056` · `100000000000000416`)
**Date / Time:** 6/23/2026 around 9:00 PM

**Description of event / rule broken:**
I was processing weed and got brought into skip as I had a bounty, I was downed and blindfolded then they sent me to jail it say I have been arrested by X. however, i did not get sent immediately to jail my screen was still black and says i am blindfolded. I then alt f4 as I was arrested and had to go get ready i wasnt going to be on long tonight. I logged in to maybe see if i can pay my bounty as i had some weed i was processing and trying to save when i logged in i was not in jail, still with bounty and at skip

**Evidence:**
vid

---

### #515 · FIXED · 2026-06-24T01:27Z
> triage 2026-07-04 (bugs-triage): was NEW, code-verified FIXED — server/AP_server/core/TON/fn_govSystemSRV.sqf:139 · AP_fnc_govPurgeStaleAndSync purges zombie candidacies before arming/resolving the open election (comment cites player095/#515), so a fresh candidacy no longer insta
- **By:** player095  ·  **Channel:** #report  ·  **ref:** 100000000000000884/100000000000000885

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000119> (`player095` · `100000000000000119`)
**Date / Time:** just

**Description of event / rule broken:**
paid 150k investment for gov and 30 secs later it closed tf

**Evidence:**
https://medal.tv/games/arma-3/clips/mYCNl800QwNyYQLbS?invite=cr-MSx6TGUsMjIxMTM2MDMw&v=72

---

### #516 · FIXED · 2026-06-24T01:37Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — deploy/battleye/scripts.txt:1 · scripts.txt lists explicit 1 "setVelocity"/setVelocityModelSpace/setVelocityTransformation exception lines above the catch-all 1 "" so legit heli-takeoff veloci
> staged 2026-06-24: heli-takeoff BE kick. ROOT: takeoff applies velocity (RotorLib + `core/functions/fn_jump.sqf` bail / `fn_activateNitro` / IgiLoad para-drop all use `setVelocity`), which a kick-mode `scripts.txt` flags. NOTE: live BE is currently LOG-ONLY (every `deploy/battleye/*.txt` = `1 ""`, per server.cfg "raise to 7 later") so NO shipped filter can kick today — a kick happening NOW is BE's own non-filter enforcement (global ban / client BE-service fail / RotorLib packet desync) OR an action an admin locally raised; that can't be fixed by a filter edit and needs the player's exact kick string ("BattlEye: Script Restriction #N" vs other). FIX (pre-stage, harmless while log-only, correct once raised to 7): `deploy/battleye/scripts.txt` now lists explicit `1 "setVelocity"` / `1 "setVelocityModelSpace"` / `1 "setVelocityTransformation"` exception lines ABOVE the catch-all, so legit takeoff stays LOGGED-not-kicked when the catch-all is later raised to `7 ""`. Precise (velocity only), not a blanket allow. (`setpos.txt` left log-only — HALO/skydive `setPos` is a separate path, not "takeoff".)

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000475> (`player023` · `100000000000000475`)
**Date / Time:** JUST NOW

**Description of event / rule broken:**
kicked for battleye something while taking off in heli

**Evidence:**
_none provided_

---

### #517 · FIXED · 2026-06-24T01:38Z
> triage 2026-07-04 (bugs-triage): was STAGED, code-verified FIXED — server/AP_server/core/wantedsys/fn_wantedBounty.sqf:39 · fn_wantedBounty now deleteAt's the wanted entry, zeros AP_wantedAmt, and DB-deletes the row BEFORE paying, so a second Send-to-Jail finds _id==-1 = no repeat m
> staged 2026-06-24: CONFIRMED double-jail money+honor farm. Root = `APS_fnc_wantedBounty` paid from `AP_wanted_list` but NEVER removed the entry, and `fn_arrestAction:119` cleared its `AP_arrest` guard before the async `handleJail` -> a 2nd "Send to Jail" re-paid the SAME bounty. FIX (server, single-fire): wantedBounty now CLEARS the offender's wanted on pay (mirror `wantedPardon` -- `deleteAt` the list entry + `wantedListAdd 999` zeros their client crimes + DB delete), so a re-call finds `_id==-1` (no 2nd pay), AP_wantedAmt drops to 0 (re-clicks bail at the "not wanted" guard = no repeat honor), AND the arrest finally clears the bounty (latent still-wanted-after-jail bug). Server-only, no change to the arrest/jail/AP_arrest flow. STAGED (frozen) -> live next deploy.
- **By:** player089  ·  **Channel:** #report  ·  **ref:** 100000000000000886/100000000000000887

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000386> (`player089` · `100000000000000386`)
**Date / Time:** we sent someone to prison on bounty hunter and we could keep sending them to prison and getting money and honor

**Description of event / rule broken:**
hit send to jail then hit it again

**Evidence:**
https://medal.tv/games/arma-3/clips/mYD23OGfKzYBQ8UcO?invite=cr-MSw1ejksMTAyNTUyMDc3

---

### #518 · NEW · 2026-06-24T04:48Z
- **By:** player055  ·  **Channel:** #report  ·  **ref:** 100000000000000888/100000000000000889

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000327> (`player055` · `100000000000000327`)
**Date / Time:** now

**Description of event / rule broken:**
none of the changes that were implemented for bank/prison etc are working i blieve

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000406/100000000000000890/2001741.JPG?ex=6a3cb339&is=6a3b61b9&hm=8a1d0955f54d5b11e868f3cf424b0a7cd20ccb7355f38ecaa53175ea813b3bc3&

---

### #519 · FIXED · 2026-06-24T05:11Z
> triage 2026-07-04 (bugs-triage): was NEW, code-verified FIXED — mission/LooneyBin.Altis/core/groups/fn_groupBrowser.sqf:16 · fn_groupBrowser no longer sorts the non-sortable 5-tuple array (which silently emptied the list); it sorts a name-keyed copy so custom/player-created groups now
- **By:** player055  ·  **Channel:** #report  ·  **ref:** 100000000000000891/100000000000000892

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000327> (`player055` · `100000000000000327`)
**Date / Time:** now

**Description of event / rule broken:**
you can see gang groups but not custom groups

**Evidence:**
_none provided_

---

### #520 · FIXED · 2026-06-24T05:28Z
> triage 2026-07-04 (deep-dive REALBUG -> FIXED): fn_vehicleGaragePull findSafePos nudge -> no more spawn-on-flag
- **By:** player092  ·  **Channel:** #report  ·  **ref:** 100000000000000893/100000000000000894

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000137> (`player092` · `100000000000000137`)
**Date / Time:** just now

**Description of event / rule broken:**
move the vehicle spawn at church cap to little bit away from the flag like it was on asylum it always spawns on you and sometimes it kills you

**Evidence:**
https://gyazo.com/ce7d7cfadbc6af3d167056e854e33871

---

### #521 · FIXED · 2026-06-24T05:41Z
> triage 2026-07-04 (bugs-triage): was NEW, code-verified FIXED — server/AP_server/core/TON/fn_govSystemSRV.sqf:206 · The reload path strips the SQL QUOTE() wrapping on gov_state playerid via AP_fnc_govUnq (fn_govSystemSRV.sqf:204-212), so a restarted governor's UID matches ge
- **By:** player024  ·  **Channel:** #report  ·  **ref:** 100000000000000895/100000000000000896

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000458> (`player024` · `100000000000000458`)
**Date / Time:** now

**Description of event / rule broken:**
gov not working thru restart

**Evidence:**
_none provided_

---

### #522 · FIXED · 2026-06-24T06:19Z
> triage 2026-07-04 (deep-dive): was NEW, code-verified FIXED — Fix commit 29c58c8 (ancestor of HEAD; commit message: '#522 crank RV + moonshine skins were progressive JPEGs (Arma renders them black) -> re-encoded 
- **By:** player092  ·  **Channel:** #report  ·  **ref:** 100000000000000897/100000000000000898

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000137> (`player092` · `100000000000000137`)
**Date / Time:** just now

**Description of event / rule broken:**
Crank Rv skin doesn't have the skin textures on the box it's just a black box truck not a rv

**Evidence:**
https://gyazo.com/8a022681b8fc5b32196fc548455250e6

---

### #523 · FIXED · 2026-06-24T06:52Z
> triage 2026-07-04 (deep-dive): was NEW, code-verified FIXED — 15s client gate: mission/LooneyBin.Altis/core/fn_setupActions.sqf:4296-4312; ban trigger loonybot/clankr.py:729-732; single-log-per-call fn_MP.sqf:26-
- **By:** player046  ·  **Channel:** #report  ·  **ref:** 100000000000000899/100000000000000900

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000504> (`player046` · `100000000000000504`)
**Date / Time:** i got clankr for starting a bank

**Description of event / rule broken:**
I was banned by clankr for starting bank lol

**Evidence:**
clankr ban

---

### #524 · FIXED · 2026-06-24T14:50Z
> triage 2026-07-04 (deep-dive): was NEW, code-verified FIXED — mission/LooneyBin.Altis/custom_p3ds/load.sqf:61 — RebelRig moved 13m along bearing 117.1 from [15011.36,6849.66] to [15017.28,6838.09], placing o
- **By:** player020  ·  **Channel:** #report  ·  **ref:** 100000000000000901/100000000000000902

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000859> (`player020` · `100000000000000859`)
**Date / Time:** just now

**Description of event / rule broken:**
Oil Cartel, how exactly are you supposed to get the rubber from flag, cant seem to find an easy way to flag. only one way and thats going under the oil rig base, and can barely get it

**Evidence:**
very weird spot for the flag
https://cdn.discordapp.com/attachments/100000000000000903/100000000000000904/20260624095027_1.jpg?ex=6a3d404b&is=6a3beecb&hm=e6fce90e08e0f7bf1c6d5d1352cd344089a5c2f08fa849c75520298812889a28&

---

### #525 · FIXED · 2026-06-24T15:50Z
> triage 2026-07-04 (bugs-triage): was NEW, code-verified FIXED — mission/LooneyBin.Altis/core/fn_survival.sqf:242 · fn_survival explicitly skips the forceWalk penalty over water and lifts any existing forceWalk so a weighed-down player can swim instead of sinking and drowning
- **By:** player087  ·  **Channel:** #report  ·  **ref:** 100000000000000905/100000000000000906

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000365> (`player087` · `100000000000000365`)
**Date / Time:** now

**Description of event / rule broken:**
Walked into water and died

**Evidence:**
https://medal.tv/games/arma-3/clips/mYS81qPCfdYyoiGxx?invite=cr-MSxlTkgsMzEzODExMDY5

---

### #526 · BENIGN/NO-CHANGE · 2026-06-24T16:29Z
> investigated 2026-06-24: "crate falling from the sky" = an INTENDED event, not a bug. There are exactly 3 parachute-crate spawners, all player-triggered with broadcasts: `server/.../fn_airDrop.sqf` (cartel-cap reward, broadcasts "A cartel supply drop is inbound..." to all civ), `fn_airDropMedic.sqf` (1-in-3 medic-revive reward), `fn_medSupplySpawn.sqf` (the medDrop item, 15-min cooldown). All drop `B_supplyCrate_F`/`B_CargoNet_01_ammo_F` under `B_Parachute_02_F`, tag an `owner`, and despawn 15-30 min. No timed/looped/orphaned crate spawner exists (the loonyBin tomb crate is ground-placed inside the church, not airborne). Reporter just witnessed a normal drop. NO CODE CHANGE.

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000538> (`player037` · `100000000000000538`)
**Date / Time:** just now

**Description of event / rule broken:**
crate falling from the sky

**Evidence:**
https://medal.tv/games/arma-3/clips/mYSOlofBMvDDTZWZ7?invite=cr-MSxEVW0sMzAzNDcyODQ5&v=24

---

### #527 · FIXED · 2026-06-24T16:38Z
> triage 2026-07-04 (deep-dive): was NEW, code-verified FIXED — /home/timb/loonybin-doomba/server/AP_server/core/TON/fn_updateHouseTrunk.sqf:86
- **By:** player054  ·  **Channel:** #report  ·  **ref:** 100000000000000907/100000000000000908

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000482> (`player054` · `100000000000000482`)
**Date / Time:** unsure just realised

**Description of event / rule broken:**
all my lv 4 vests and lv 5 vests have been wiped from my houses and the gang building

**Evidence:**
_none provided_

---

### #528 · FIXED · 2026-06-24T16:40Z
> triage 2026-07-04 (bugs-triage): was NEW, code-verified FIXED — server/AP_server/core/TON/fn_copSplit.sqf:54 · APS_fnc_copSplit (previously a no-op stub) now distributes the ticket pool and credits each active officer's bank.
- **By:** player091  ·  **Channel:** #report  ·  **ref:** 100000000000000909/100000000000000910

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000911> (`player091` · `100000000000000911`)
**Date / Time:** 6/24/26 12:30pm est

**Description of event / rule broken:**
when people pay their ticket cops dont get money (ticketing officer and officers around)

**Evidence:**
https://gyazo.com/1d378444497850bd53ce782c8bdee3a5

---

### #529 · FIXED · 2026-06-24T17:31Z
> triage 2026-07-04 (bugs-triage): was NEW, code-verified FIXED — loonybot/enrique.py:560 · A flock single-instance guard explicitly citing '#529 DOUBLE-CHARGE' prevents a second Enrique instance from double-charging players.
- **By:** player004  ·  **Channel:** #report  ·  **ref:** 100000000000000912/100000000000000913

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000232> (`player004` · `100000000000000232`)
**Date / Time:** just now

**Description of event / rule broken:**
i believe your enrique bot is double chargin some of player but i have not sure

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000233/100000000000000914/Screenshot_2026-06-24_192931.png?ex=6a3d65d1&is=6a3c1451&hm=b643a53187a3ac1a1d6eb08e3a03426749f122d6fc4ff502efaf5c8519e0a1fe&

---

### #530 · FIXED · 2026-06-24T18:12Z
> triage 2026-07-04 (bugs-triage): was NEW, code-verified FIXED — mission/LooneyBin.Altis/core/config/fn_weaponShopCfg.sqf · Every MX variant is tagged only to police_weapons and skiptracer (both talent-gated) with no rebelwep tag, and fn_initCiv.sqf:143-146 strips it without the BH l
- **By:** player004  ·  **Channel:** #report  ·  **ref:** 100000000000000915/100000000000000916

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000232> (`player004` · `100000000000000232`)
**Date / Time:** just now

**Description of event / rule broken:**
You need to bounty hunter talent to pick up the mx but you can buy it in rebel as wel

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000233/100000000000000917/20260624201054_1.jpg?ex=6a3d6f7d&is=6a3c1dfd&hm=2b49420b05d7dd0de1e42fdbbaf8faefb94132655c72483314c6fd26483c682f&

---

### #531 · FIXED · 2026-06-24T20:29Z
> triage 2026-07-04 (bugs-triage): was NEW, code-verified FIXED — mission/LooneyBin.Altis/core/actions/fn_gatherObject.sqf:12 · Sickle now guarantees the +1 grain bonus: if (AP_inv_sickle >= 1 && {_item in ["barley","corn","rye"]}) yields 2 barley reliably.
- **By:** player049  ·  **Channel:** #report  ·  **ref:** 100000000000000918/100000000000000919

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000732> (`player049` · `100000000000000732`)
**Date / Time:** just no

**Description of event / rule broken:**
sicle doesnt give 2 barley when harvesting bushes

**Evidence:**
_none provided_

---

### #532 · FIXED · 2026-06-24T23:10Z
> triage 2026-07-04 (bugs-triage): was NEW, code-verified FIXED — mission/LooneyBin.Altis/core/actions/fn_storeVehicle.sqf:74 · fn_storeVehicle now derives _isGang by format-normalizing the raw AP_dbInfo[0] uid against str(gangID) instead of wrapping it in str, so pulled gang vehicles t
- **By:** player046  ·  **Channel:** #report  ·  **ref:** 100000000000000920/100000000000000921

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000504> (`player046` · `100000000000000504`)
**Date / Time:** Just now

**Description of event / rule broken:**
Me or gang mates cannot store gang vics into garage after being pulled "Cant store as this does not belong to you"

**Evidence:**
_none provided_

---

### #533 · FIXED · 2026-06-25T00:51Z
> triage 2026-07-04 (deep-dive): was NEW, code-verified FIXED — mission/LooneyBin.Altis/description.ext:25 (MasterHandler include restored) -> dialog/MasterHandler.h:27 (chop_shop.hpp -> dialog 39400); server chop 
- **By:** player087  ·  **Channel:** #report  ·  **ref:** 100000000000000922/100000000000000923

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000365> (`player087` · `100000000000000365`)
**Date / Time:** now

**Description of event / rule broken:**
Chop shop not working

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000488/100000000000000924/20680D1.JPG?ex=6a3dcd14&is=6a3c7b94&hm=566c11ec2dcd68a72781144c8f989fbb6ceaa49b818d31cf723ac363cf26bd3e&
https://cdn.discordapp.com/attachments/100000000000000488/100000000000000925/20FDB91.JPG?ex=6a3dcd14&is=6a3c7b94&hm=4b74d4018c00ca35a00b7d9420bf7d6314d24ac608c72e9097d3d20190745f95&

---

### #534 · FIXED · 2026-06-25T01:07Z
> triage 2026-07-04 (deep-dive): was NEW, code-verified FIXED — mission/LooneyBin.Altis/core/config/fn_vehicleConfig.sqf:591-596 (west maxtac_car/srt_car now use `then`, not `exitWith`) + fn_vehicleConfig.sqf:19-46 (
- **By:** player053  ·  **Channel:** #report  ·  **ref:** 100000000000000926/100000000000000927

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000762> (`player053` · `100000000000000762`)
**Date / Time:** Now

**Description of event / rule broken:**
MAXTAC SHOP STILL BROKEN

**Evidence:**
_none provided_

---

### #535 · FIXED · 2026-06-25T01:11Z
> triage 2026-07-04 (deep-dive): was NEW, code-verified FIXED — server/AP_server/core/TON/fn_updateHouseTrunk.sqf:86 (isClass CfgWeapons/CfgMagazines/CfgVehicles/CfgGlasses + CfgWeights fallback; owner 2026-06-24
- **By:** player046  ·  **Channel:** #report  ·  **ref:** 100000000000000928/100000000000000929

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000504> (`player046` · `100000000000000504`)
**Date / Time:** 8:40EST

**Description of event / rule broken:**
My house inventory physical where my kitswere i had 4 or 5 full mk1 kits and now they arent there but my virtual is fine

**Evidence:**
_none provided_

---

### #536 · FIXED · 2026-06-25T03:00Z
> triage 2026-07-04 (bugs-triage): was NEW, code-verified FIXED — mission/LooneyBin.Altis/core/actions/fn_chopTree.sqf:31 · The 2026-07-03 #536 fix sends the chop RPC before felling the tree (fn_chopTree.sqf:26-31) and the server re-acquires the live tree by position and spawns the t
- **By:** player033  ·  **Channel:** #report  ·  **ref:** 100000000000000930/100000000000000931

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000722> (`player033` · `100000000000000722`)
**Date / Time:** JUST NOW

**Description of event / rule broken:**
When cutting down trees timber does not go into inventory or drop in case. I was trying to complete the paul bunyun quest but cannot obtain timber

**Evidence:**
_none provided_

---

### #537 · NEW · 2026-06-25T03:29Z
- **By:** player010  ·  **Channel:** #report  ·  **ref:** 100000000000000932/100000000000000933

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000803> (`player010` · `100000000000000803`)
**Date / Time:** just now

**Description of event / rule broken:**
insta respwn

**Evidence:**
_none provided_

---

### #538 · NEW · 2026-06-25T03:32Z
- **By:** player054  ·  **Channel:** #report  ·  **ref:** 100000000000000934/100000000000000935

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000482> (`player054` · `100000000000000482`)
**Date / Time:** just now

**Description of event / rule broken:**
so when i got shot i got respawned after 20 seconds and when i crashed into my friend just fucking around he got instant respawned "mint" is the friend

**Evidence:**
_none provided_

---

### #539 · NEW · 2026-06-25T04:24Z
- **By:** player055  ·  **Channel:** #report  ·  **ref:** 100000000000000936/100000000000000937

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000327> (`player055` · `100000000000000327`)
**Date / Time:** now

**Description of event / rule broken:**
MaxSec captains dont have mk-1s in their shop

**Evidence:**
_none provided_

---

### #540 · FIXED · 2026-06-25T04:56Z
> triage 2026-07-04 (bugs-triage): was NEW, code-verified FIXED — server/AP_server/core/wantedsys/fn_wantedBounty.sqf:52 · fn_wantedBounty no longer wipes A_stats_crimes (only zeroes AP_wantedAmt), fixing the zero-sentence instant-release on arrest.
- **By:** player036  ·  **Channel:** #report  ·  **ref:** 100000000000000938/100000000000000939

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000092> (`player036` · `100000000000000092`)
**Date / Time:** just now

**Description of event / rule broken:**
when you get arrested it teleports you into jail then you get instantly released

**Evidence:**
im the proof i had the cops arrest me and it was out instantly

---

### #541 · FIXED · 2026-06-25T05:35Z
> triage 2026-07-04 (deep-dive REALBUG -> FIXED): configuration.sqf AP_revokedBH=[] init -> bounty license buyable
- **By:** player024  ·  **Channel:** #report  ·  **ref:** 100000000000000940/100000000000000941

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000458> (`player024` · `100000000000000458`)
**Date / Time:** now

**Description of event / rule broken:**
cant purchase BH license

**Evidence:**
https://medal.tv/games/arma-3/clips/mZ6zRx1g0St28NFqj?invite=cr-MSx5MzksMjA1OTE0NDUx

---

### #542 · FIXED · 2026-06-25T11:59Z
> triage 2026-07-04 (bugs-triage): was NEW, code-verified FIXED — mission/LooneyBin.Altis/core/inventory/fn_refreshInventory.sqf:54 · The nil-throw that blanked house storage is fixed with a default-0 getVariable (dated 2026-06-26, after the report) and matching save-path guards in fn_handleIn
- **By:** player015  ·  **Channel:** #report  ·  **ref:** 100000000000000942/100000000000000943

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000229> (`player015` · `100000000000000229`)
**Date / Time:** just now

**Description of event / rule broken:**
I was getting the weed out of my house then the next moment my house inventory is gone like all of it even my mags and bags.

**Evidence:**
https://medal.tv/games/arma-3/clips/mZd9p6enJdwGft0lk?invite=cr-MSwwbTgsMTY4Mjc2Nzcz&v=68

---

### #543 · FIXED · 2026-06-25T18:13Z
> triage 2026-07-04 (bugs-triage): was NEW, code-verified FIXED — mission/LooneyBin.Altis/core/config/fn_clothing_cop.sqf:276 · Player report is WAI (owner-closed): Tactical Police Vest is gated behind Prudent talent 83 (line 275-276), matching intended behavior; the dev-noted SRT exitWi
- **By:** player075  ·  **Channel:** #report  ·  **ref:** 100000000000000944/100000000000000945

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000946> (`player075` · `100000000000000946`)
**Date / Time:** just now

**Description of event / rule broken:**
Not sure if it's already been reported but you are not able to purchase Tactical Police Vests or Rigs as a Corporal and maybe below/higher, when you are on a normal cop slot.

**Evidence:**
_none provided_

> WAI (owner 2026-06-25, closed): the Tactical Police Vest (V_TacVest_blk_POLICE/_gen_F) is gated behind the **"Prudent" cop talent** (talent 83 — literally "Able to purchase protective tactical vest"); learn it to unlock. Plate-carrier rigs are rank-gated by design (#466: Carrier Light = Sgt+/4, Level IV = 5, Level V = 6). Not a code bug. Same answer covers #544.

---


### #543 · FIXED · 2026-06-25 · (dev-noted, owner)
> triage 2026-07-04 (bugs-triage): was NEW, code-verified FIXED — mission/LooneyBin.Altis/core/config/fn_clothing_cop.sqf:276 · Player report is WAI (owner-closed): Tactical Police Vest is gated behind Prudent talent 83 (line 275-276), matching intended behavior; the dev-noted SRT exitWi

**Report Type:** Bug (latent) — pinned for a closer look

**Description:**
SRT cop clothing (fn_clothing_cop.sqf) uses the SAME `exitWith`-bails-out-of-the-list-build footgun that blanked the MaxTac vehicle shop (#534) — 5 sites: SRT uniform (:101), helmet (:187), goggles/balaclava (:215), vest (:252), backpack (:302). `if (_isSRT) exitWith { _ret pushBack[...] }` short-circuits fn_clothing_cop's return, so an SRT member's clothing menu (each filter category) likely comes back blank/garbage instead of the list.

**Status:** NOT fixed yet — needs a decision on intended SRT wardrobe (SRT-exclusive list vs SRT + normal rank clothing) before picking the if/else vs `then` fix. Same fix class as the b0098-pending vehicleConfig maxtac/srt/firefighter/medic fixes.

**Verify:** have an SRT member open the cop clothing shop on each tab; if blank, it's confirmed.

---
### #544 · FIXED · 2026-06-25T19:51Z
> triage 2026-07-04 (bugs-triage): was NEW, code-verified FIXED — mission/LooneyBin.Altis/core/config/fn_clothing_cop.sqf:280 · Owner-closed WAI (dup of #543): the Tactical vest is intentionally gated behind the Prudent talent (talent 83) and plate rigs by rank, and #466 already gives Sg
- **By:** player062  ·  **Channel:** #report  ·  **ref:** 100000000000000947/100000000000000948

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000949> (`player062` · `100000000000000949`)
**Date / Time:** just now

**Description of event / rule broken:**
You cannot buy police vests in police uniform shop

**Evidence:**
_none provided_

> WAI (owner 2026-06-25, closed): duplicate of #543 — the Tactical Police Vest is gated behind the **"Prudent" cop talent** (learn it to unlock); plate rigs are rank-gated by design. Not a code bug.

---

### #545 · FIXED · 2026-06-25T21:26Z
> triage 2026-07-04 (bugs-triage): was NEW, code-verified FIXED — mission/LooneyBin.Altis/core/inventory/fn_takeInventory.sqf:302 · fn_takeInventory now rejects taking a second backpack while one is worn instead of silently losing it.
- **By:** player033  ·  **Channel:** #report  ·  **ref:** 100000000000000950/100000000000000951

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000722> (`player033` · `100000000000000722`)
**Date / Time:** just now

**Description of event / rule broken:**
back packs disappear if attempting to move multiple from house inventory. I did not have a backpack on, attempted to move two carryalls by double clicking, one went onto my back and the other disappeared instead of giving exception/error.

**Evidence:**
_none provided_

> FIXED (deployed Beta 0.0.99 b0099): in fn_takeInventory, taking a 2nd backpack while already wearing one did `player addItem <backpack>` — which silently fails (a backpack can't be stored as cargo / nested) — AFTER the item was already removed from the container, so the extra backpack was LOST. Now it's rejected with a message and stays in storage. Shared house + vehicle-trunk take path.

---

### #546 · FIXED · 2026-06-25T22:06Z
> triage 2026-07-04 (deep-dive): was NEW, code-verified FIXED — /home/timb/loonybin-doomba/mission/LooneyBin.Altis/core/config/fn_talentCfg.sqf:142 and /home/timb/loonybin-doomba/mission/LooneyBin.Altis/core/talent
- **By:** player019  ·  **Channel:** #report  ·  **ref:** 100000000000000952/100000000000000953

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000083> (`player019` · `100000000000000083`)
**Date / Time:** Just now

**Description of event / rule broken:**
I cannot pull orcas because the game thinks I dont have the commercial pilot talent but talents dont exist anymore. Also probably related I have the talent notification on my phone as if I had talents point to spend.

**Evidence:**
_none provided_

---

### #547 · NEW · 2026-06-25T23:46Z
- **By:** player002  ·  **Channel:** #report  ·  **ref:** 100000000000000954/100000000000000955

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000281> (`player002` · `100000000000000281`)
**Date / Time:** Now

**Description of event / rule broken:**
Talents still not working, drill speed and bolt cutting talents don’t change speed, toolkits don’t spawn in cars etc

**Evidence:**
_none provided_

---

### #548 · NEW · 2026-06-26T01:06Z
- **By:** player087  ·  **Channel:** #report  ·  **ref:** 100000000000000956/100000000000000957

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000365> (`player087` · `100000000000000365`)
**Date / Time:** now

**Description of event / rule broken:**
I was collecting my aging barrel and putting it into my house, i lost 74 of the 100 while it transfered into the house. Not sure why buy i removed all from the barrel and added to house but only 26 stored the rest deleted.

**Evidence:**
https://cdn.discordapp.com/attachments/100000000000000488/100000000000000958/MedalTVArma320260625205913340-trim-1782435645057.mp4?ex=6a3f21f8&is=6a3dd078&hm=8e7cf2943b4ddd249a4cdc37198a8bbe7d5010d3edb6fb0c946902d066d6a769&

---

### #549 · FIXED · 2026-06-26T20:50Z
> triage 2026-07-04 (bugs-triage): was NEW, code-verified FIXED — mission/LooneyBin.Altis/core/inventory/fn_refreshInventory.sqf:54 · fn_refreshInventory.sqf:54 now defaults missionNamespace getVariable to 0 (dated 2026-06-26, comment explicitly credits reporter nolovenova) fixing the nil>0 th
- **By:** player021  ·  **Channel:** #report  ·  **ref:** 100000000000000959/100000000000000960

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000961> (`player021` · `100000000000000961`)
**Date / Time:** 4:36GMT EASTERN

**Description of event / rule broken:**
I was pulling drugs out my house when I kept being notified of a vehicle being saved and I lost 180 Opium

**Evidence:**
if u look at screen shot 1 youll see my debit card. if u look at screenshot 2 youll see me close my house inventory menu and then when u open it again the items gone.
https://cdn.discordapp.com/attachments/100000000000000962/100000000000000963/ArmA_3_2026.06.26-16.47_1.png?ex=6a403788&is=6a3ee608&hm=090c96fb061a08f78d445ffdbb51842d6715fab3565d4b6bee75ba4fcf432c93&
https://cdn.discordapp.com/attachments/100000000000000962/100000000000000964/ArmA_3_2026.06.26-16.48.png?ex=6a403788&is=6a3ee608&hm=36053df18a6c552deaecf783a98423874470de0f40de3604e4336ac06615352c&
https://cdn.discordapp.com/attachments/100000000000000962/100000000000000965/ArmA_3_2026.06.26-16.48_1.png?ex=6a403788&is=6a3ee608&hm=43a3fd0a05939ad06b92566d8c8007345355a4c97968b3a3e3a0230d925c2cf4&

---

### #550 · FIXED · 2026-06-26T22:29Z
> triage 2026-07-04 (deep-dive): was NEW, code-verified FIXED — mission/LooneyBin.Altis/evh/fn_handleDamage.sqf:43 ('side _source != west &&' guard, Infamous-arma commit e7387b3) + :51 ('== 1' syntax fix, commit 1b
- **By:** player036  ·  **Channel:** #report  ·  **ref:** 100000000000000966/100000000000000967

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000092> (`player036` · `100000000000000092`)
**Date / Time:** just now

**Description of event / rule broken:**
some guns on cop are lethal only like the p90 so i believe its any new gun we added in that is lethal only

**Evidence:**
_none provided_

---

### #551 · FIXED · 2026-06-26T22:41Z
> FIXED by owner (self-solved 2026-07-04): Cadet P90 was lethal-only (no less-lethal/taser round) because a newly-added gun wasn't in the less-lethal weapon set. Owner resolved directly.
- **By:** player086  ·  **Channel:** #report  ·  **ref:** 100000000000000968/100000000000000969

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000625> (`player086` · `100000000000000625`)
**Date / Time:** now

**Description of event / rule broken:**
Cadet p90 is bugged only lethals

**Evidence:**
it would say (name) was killed instead of downing or killed by me

---

### #552 · NEW · 2026-07-10T01:25Z
- **By:** player092  ·  **Channel:** #report  ·  **ref:** 0/100000000000000970

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000137> (`player092` · `100000000000000137`)
**Date / Time:** just now

**Description of event / rule broken:**
I wanna link my asylum money on here

**Evidence:**
https://gyazo.com/55ae1f8fe7a42070e67e6d4b25a48e05

---

### #553 · NEW · 2026-07-10T01:34Z
- **By:** player092  ·  **Channel:** #report  ·  **ref:** 0/100000000000000971

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000137> (`player092` · `100000000000000137`)
**Date / Time:** just now

**Description of event / rule broken:**
I don't think my ticket went through the first time it didn't add a new channel

**Evidence:**
its for adding myasylum money on here https://gyazo.com/55ae1f8fe7a42070e67e6d4b25a48e05

---

### #554 · NEW · 2026-07-14T20:53Z
- **By:** player004  ·  **Channel:** #report  ·  **ref:** 0/100000000000000972

**Report Type:** Bug / Exploit
**Reporter:** <@100000000000000232> (`player004` · `100000000000000232`)
**Date / Time:** 2026-06-09  9-12AM

**Description of event / rule broken:**
i did the recovery wreck on my blackfish but did not appear in my garage

**Evidence:**
_none provided_

---


### #555 · STAGED · 2026-07-22T00:00Z
- **By:** owner (verbal)  ·  **Channel:** session  ·  **ref:** live LoonyCoin collect dupe

Mining rig collect dupes LoonyCoin on LIVE (b0182 single-rig code). Root cause, proven against the live
file + live DB: collect read the extDB3 result ROW instead of the cell (`_rows param [0,""]`, missing the
second `param [0]`), so each collect wrote the formatted row-array back into `houses.miner` (`["[""...`
garbage, quotes doubling per collect) with sci-notation stamps (`8.4554e+07` — numeric `_nowUnix` through
`format %2`). After 4 collects the string exceeds varchar(48); STRICT_TRANS_TABLES rejects the UPDATE,
the result is never checked, `last_collect` freezes, and every later collect re-mints the full capped 96
LoonyCoin. 10 of 13 live rigs are frozen (len 41-42 = generation 4). Delete pays the same accrual once
more, then re-place resets clean.

> staged (doomba only — owner said do NOT patch live yet): multi-rig rewrite had already closed the three
> root vectors (row-then-cell unwrap, `toFixed 0` stamps, INT columns). This session adds the missing
> fail-closed layer in `fn_miningSRV.sqf`: collect proves the stamp moved (readback == written) before
> minting; delete proves the row is gone (COUNT(*)=="0") before paying/refunding/despawning. Plus
> `sql/mining.sql` now carries the `house_rigs` DDL (was dev-only, hand-created) and the live-migration
> rules: never parse corrupted `houses.miner`, placements only, accrual restarts at migration time.
> Live economy note: affected users already minted an unknown amount; forensics (collect counts per UID
> from server logs) available on request.
---

### #556 · NEW · 2026-07-23T15:40Z
- **By:** Claude (0.2.0 pre-deploy audit)  ·  **Channel:** internal  ·  **ref:** deploy-audit

PRE-EXISTING (not introduced by 0.2.0): 10 `"AP_fnc_*"` / `"APS_fnc_*"` strings are remoteExec'd but have NO CfgFunctions registration, so those calls are dead. 9 of them are identical in git and on the live box (upstream gaps); 1 is live-only obfuscation drift.

> **FIXED 2026-07-23 (staged for 0.2.0).** Two independent faults, and the first masked the second:
>
> 1. **No CfgRE entry — affects git AND live.** `fn_query.sqf:221` remoteExecs `"AP_fnc_jail"` to a reconnecting player whose uid is in `AP_restrained_players`, but `CfgRE.hpp` (`mode = 1`, whitelist) had no entry for it, so the call was silently dropped. Arrest-evasion by relog worked on every build. Added `class AP_fnc_jail { allowedTargets = 1; }` (server→client).
> 2. **Name drift — live only.** Upstream renamed the real implementation `jail` → `jailPlayer` (`core/civilian/fn_jailPlayer.sqf`) and made `core/compat/fn_jail.sqf` a thin login wrapper that calls it with `_onLogin = true`. The live box never received either file (neither changed inside the shipping diff, so nothing staged them) and still had the pre-rename `core/civilian/fn_ja1l.sqf` plus the original 111-byte no-op `compat/fn_jail.sqf`. Shipped both current files, and repointed the three live callers still using the old name (`fn_initCiv.sqf:23`, `fn_turnedIn.sqf:26`, `fn_respawned.sqf:42`) at `AP_fnc_jailPlayer`. The orphaned `fn_ja1l.sqf` is left on disk, unregistered and unreferenced.
>
> Verified end to end on the staged tree: caller string → CfgRE whitelist → `class jail` (compat) → 591-byte wrapper → `class jailPlayer` (civilian) → 4326-byte implementation. Dev mission load is clean.
>
> **Two process lessons.** (a) A whitelist miss and a name mismatch produce the *same* symptom — silence — so fixing only the visible one leaves the feature just as broken; check every link in a cross-machine call chain, not the first one that looks wrong. (b) Registration audits must be **block-aware**: `file = "..."` is a class attribute that applies to its whole block regardless of declaration order, so a line-order scan reports every member declared above its own `file=` line as missing. A naive scan produced a false "`class miningRig` is unregistered" here; `class Housing` declares it before the attribute and it resolves correctly.
>
> **UPSTREAM (present in git too, unchanged by this wave):** `APS_fnc_createTimeTrialVehSRV` (fn_timeTrial.sqf:82), `APS_fnc_markIllegalArea` + `APS_fnc_unmarkIllegalArea` (fn_markIllegalAreasMenu.sqf:136,140), `APS_fnc_rebelCarePackages` (fn_useItem.sqf:532), `APS_fnc_wacClient` (fn_settingsInit.sqf:41), `AP_fnc_eventGungameKill` (fn_onPlayerKilled.sqf:3), `AP_fnc_forceRagdoll` (fn_ownerSpangle.sqf:24), `AP_fnc_initGangFortClient` (fn_gangFortressSRV.sqf:160). `AP_fnc_MP_queue` is a false positive (a getVariable key, not a function).
>
> Separately, **57 distinct fn-name strings are not in the CfgRE whitelist** — the count is IDENTICAL in git and on the live box, so it is an upstream gap, not deploy drift. Every one of those is a silent no-op if it is ever remoteExec'd. Worth a dedicated pass; too large to fold into the 0.2.0 deploy.

Audit method (repeatable): parse `class (\w+)` from `Functions.h` / `config.cpp` for the registered set, grep every `"AP_fnc_*"` / `"APS_fnc_*"` string literal in mission+server, diff. Run it against BOTH git and the on-box tree — the delta is exactly the obfuscation drift.

---

### #557 · NEW · 2026-07-23T15:40Z
- **By:** Claude (0.2.0 pre-deploy audit)  ·  **Channel:** internal  ·  **ref:** deploy-audit

`deploy/run-boot2.sh` shipped a MULTI-RIG migration that ran unconditionally on every boot: it copied `houses.rig` into `house_rigs` and then `UPDATE houses SET rig=NULL, miner=NULL`. On a frozen or natural restart — i.e. still running the OLD PBO, whose reload path reads `houses.rig` — that would have NULLed the column out from under the live code and **despawned all 13 placed rigs** with no way for the old code to find them again.

> staged (0.2.0). Split in two: `CREATE TABLE IF NOT EXISTS house_rigs` stays boot-unconditional (purely additive), while the destructive copy-in moved to a `FREEZE=0` + done-marker one-shot block that only fires on the deploy restart that actually packs the multi-rig code — the same pattern as the #462 stats de-clobber and the b0097 talent wipe. It also now writes `_backup_rigs_multirig` before touching anything. General lesson: **a boot script's DB migrations must be gated on the code that consumes them actually shipping in the same boot**, otherwise a restart under the old PBO applies a schema change the running code cannot survive.

---

### #558 · NEW · 2026-08-19T20:05Z
- **By:** Claude (observed while verifying the binarize deploy)  ·  **Channel:** internal  ·  **ref:** dev b0681

**Four `Missing ]` errors fire on every player login**, from the two `_dec` calls in `fn_queryRequest.sqf` that decode the character row's blob columns:

```
fn_queryRequest.sqf:170   private _gear = [_p select 3]  call _dec;
fn_queryRequest.sqf:222   private _lic  = [_p select 22] call _dec;
```

Each throws twice. The expressions in the RPT are the gear and licence arrays with their quotes doubled:

```
Error in expression <[[[],[],[],[""U_I_G_resistanceLeader_F"",[]],[],[],""">
  Error position: <U_I_G_resistanceLeader_F"",[]],[],[],""">
  Error Missing ]

Error in expression <[[""license_civ_boat"",true],[""license_civ_>
  Error Missing ]
```

**Lead, not a confirmed root cause** — the investigation was stopped deliberately (see below). `Error in expression` means a `call compile`, and `_dec` itself does not compile: it deliberately uses `parseSimpleArray`, because a poisoned free-text column would otherwise execute as SQF on login (the Lystic compile-RCE class). The only `call compile` under it is in `DB_fnc_mresToArray`, which branches on engine:

```sqf
_array = if (missionNamespace getVariable ["AP_db_postgres", false]) then {
    call compile _array
} else {
    call compile format["""%1""", _array]
};
```

Dev is on **extDB3/MariaDB** (the log is full of `ON DUPLICATE KEY UPDATE` and `QUOTE()`), so it takes the second branch and wraps a value that already carries its own outer quotes. `fn_queryRequest.sqf:67-69` says exactly that about these two columns: the gear and licence columns are stored UNQUOTED precisely because they are str2-encoded *with* their own outer double-quotes, and quoting them again "would double-wrap and break `_dec`". That is consistent with the doubled quotes in the error text, but it has not been proven and the postgres branch has not been compared.

**Blast radius is guarded but non-zero.** `_dec` ends with `if (isNil "_a") then { _a = [] };`, so a failed decode returns an empty array rather than nil — the guard that exists to stop players spawning naked and never re-saving. That means the failure mode is not a crash, it is **gear and licences silently falling back to defaults on login**. Whether that is actually happening to a real character, or whether the value recovers by another path, was not established. Check it before assuming logins are lossless.

> **Deliberately not fixed.** Owner 2026-08-19: the other factions are being removed and this whole area is being reworked, so the per-side blob columns (`civ_gear`, the `license_<side>_*` set, the whole `_sideflag`/`_gearcol` split this function is built around) are on their way out. Patching the decode now would be work thrown away, and it would touch login, gear and licence code to do it. Re-check against the new model instead: if the rewrite drops str2/mres blobs for these columns, this dies with them; if it keeps them, this is the first thing to test.

---
