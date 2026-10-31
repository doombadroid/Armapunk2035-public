# LooneyBin — Dead Features (deobfuscation casualties)

Things the 2017→2020 deobfuscation **gutted, emptied, or stubbed** so they silently do nothing. The code/UI
still references them; the implementation is gone. Compiled 2026-06-11 (server on Beta 0.0.26).

Legend: 🔴 high impact / likely wanted · 🟠 medium · 🟡 low / cosmetic · ✅ already fixed this session.
Most are mechanically restorable (the assets/oggs exist, only the config/logic was wiped — same as the horns).

---

## 1. 🔴 Silent custom sounds — CfgSounds.hpp was emptied

The deobf emptied `CfgSounds.hpp` (mis-mapped briefing SQF). I restored only the **horns** (#133). Everything
else `say3D`/`playSound`s a class that no longer exists → **plays nothing**. The `.ogg` files still live in
`mission/LooneyBin.Altis/sounds/`, so these are restorable exactly like the horns (regenerate the CfgSounds
class → ogg path).

**RESTORABLE (42 — ogg present, just needs a CfgSounds class):**
`airplane`, `bombarm`, `bombPhoneAnswer`, `bombPhoneAnswerTalk`, `bombPhoneInit`, `bombPhoneLoop`, `camera`,
`chop`, `CokeSlosh1`, `CokeSlosh2`, `elechair` (electric chair), `executionerAnyLastWords`,
`executionerFatality`, `executionerGunshot`, `executionerHeadshot`, `executionerWaitWait`,
`executionerWeDontCare`, `flashbang`, `gatherLsd`, `govSpeaker`, `handcuffs`, `jewelryAlarm`,
`jewelrySafeTorchLoop`, `loottick`, `medicFireFlames1`, `medicFireFlames2`, `medicFireHose`,
`medicFireHoseFill`, `metalDetectScan`, `phonedial`, `phonering`, `pickaxe`, `purchase`, `questDoneNormal`,
`questDoneSeasonal`, `questStart`, `racebeep1`, `racebeep2`, `spraycanstart`, `ufoCrash`, `ufoHover`,
`ufoLeave`.
(NOTE: there are ~114 oggs total in `sounds/` — more than are currently referenced, so additional sounds can
be wired too. Also the cannabis/moonshine/alarm oggs exist and likely want classes.)

**NEED A FILE (referenced, no ogg):** `air_raid`, `device_disassembled_loop`, `loonyBinThermiteLoop`,
`loonyBinThermiteEnded` (the Loony Bin heist thermite), `missileLocking`, `missileLocked` (AA/RPG lock),
`tazersound`, `ziptie`.
(`taskAssigned` = vanilla engine sound, fine. `iLoveLoonybin` = the horn already removed in #133.)

---

## 2. Stubbed functions — `mission/LooneyBin.Altis/core/compat/`

AUDIT 2026-06-11: the compat dir is **load-bearing**, NOT dead weight — 45 of 49 files have live callers
(some are real impls: `fn_uC` money helper, `fn_getBuildID`, `fn_gangBank`; the rest are no-op shims that are
still CALLED, so deleting them would make the call site error). These stubs run on whichever machine calls
them — and since the mission's CfgFunctions compiles them on the **server** too, the 2017 server's own
`call AP_fnc_X` lines hit them. Only 4 files had 0 callers and were safe to remove (see below). Do NOT
bulk-delete this directory.

### 🟡 Economy / election VALUE stubs — called by the server, but their OUTPUT feeds nothing player-facing (VESTIGIAL)
Re-audited 2026-06-11, traced every consumer. These are NOT live bugs — the live systems use other code:
- `fn_calcPrice` (ret 0) + `fn_getQuantity` (ret 0): only reachable through server `fn_vehicleDelete.sqf`, whose
  **only** caller is `fn_gangGarageDestroy.sqf`. That caller passes 3 args → server `_type=""` / `_unit=objNull`
  → the `exitWith` on `fn_vehicleDelete.sqf:16` fires *before* the price calc + "$0" hint. So the $0 path is
  **dormant**. Players sell goods through the virtual shop (static prices, works). There is **no** "sell vehicle
  for cash" feature wired to vehicleDelete — adding one is a new feature, not a stub fix.
- `fn_itemDemand` (ret 1): used by `fn_reduceMarket.sqf` / `fn_saveVehicles.sqf` to decay `AP_price_index`.
  But `AP_price_index` is **server-only** — no mission/pricing code reads it (verified). Shop prices come from
  `AP_fnc_virtItemCfg` "getBasePrice" (static) in `fn_virtualShopPopulate.sqf:29`. So the whole dynamic market
  (index + demand + stock accumulation) is **cosmetic** — it churns a number nothing consumes. itemDemand only
  matters if the dynamic market is re-wired into shop pricing (= feature work).
- `fn_candidate` / `fn_candidates` (ret []): receivers for the OLD politics path (`fn_getCandidate(s)`), which has
  **zero callers**. The live election uses `APS_fnc_govSystemSRV "getCandidates"` → `SRV_govCandidates` →
  `AP_govCandidates` (read by `fn_govVotingMenu.sqf:137`). Elections populate fine; these two stubs are dead.
- `fn_vehicleColorCfg` (ret []): `fn_spawnVehicle.sqf:33` reads it for spawn colors → vehicles spawn default-colored (cosmetic).
- `fn_setReturnValue` (ret nil): `fn_verifyPickup.sqf:32` RE return-value plumbing.
Bottom line: reviving the dynamic market or adding vehicle-sell-for-cash are **features** (sizeable), not stub fixes.

> ✅ UPDATE 2026-06-12: BOTH built (staged, BUGS #143/#144). `fn_itemDemand` + `fn_calcPrice` are no longer
> vestigial — `itemDemand` now feeds a live `AP_fnc_marketFactor` wired into `getLowestPrice`, and selling
> reports `AP_stock_update` so the dynamic market actually moves shop prices (recovering via `fn_reduceMarket`).
> Personal-garage "Sell Vehicle" is wired to the pre-existing `APS_fnc_srvSellVehicle`. Still dead/vestigial:
> `fn_candidate`/`candidates` (elections use govSystemSRV), `fn_vehicleColorCfg`, `fn_setReturnValue`.

### ✅ Jury trial / courtroom system — RESTORED (#0027, 2026-06-11)
- The 2020 client (`core/civilian/fn_trialSystem.sqf`, 347L) was fully intact + NPC-triggered
  (`npcs/fn_prison.sqf` request, `npcs/fn_courthouse.sqf` register), but the server never initialized/
  published `SRV_trialData` (clients threw on `SRV_trialData select N`) and the OLD server (`fn_trialRequest`/
  `fn_trialBegin`) drove dead, un-whitelisted stubs. Fix: init+publish `SRV_trialData`/`SRV_trialPreviousDefenders`
  (server vars + client nil-guard), whitelist `AP_fnc_trialSystem` in CfgRE, retarget the server MPs at the
  client case protocol (juryInviteToTrial / defendantTrialStart / juryTrialStart / trialEnded) and retime
  the orchestration to the client's 180s plead + 120s deliberation. **Needs a live courtroom (1 defendant +
  >3 jurors) to validate timing** — bridge already logs `-TRIAL-` to console.log.
- Superseded compat stubs with **0 callers** → DELETED 2026-06-11 (backup in `/tmp/lb_compat_backup_*`):
  `fn_trialDefendant`, `fn_trialJury`, `fn_jurySummons`. `fn_trialBegin` is **KEPT** — server
  `fn_trialRequest.sqf:51` still does `call AP_fnc_trialBegin` (currently a no-op; loose end in the trial
  bridge but harmless — deleting it would error that call).

### ✅ Police CAD / Dispatch — event-pings RESTORED (#0027); full console deferred
- `fn_newDispatch`/`fn_finishDispatch`/`fn_newWaypoint` fleshed out; server `createDispatch` now passes the
  crime position and pings EVERY on-duty officer (was a random subset) on bank drill / fed reserve / prison
  break / store robbery → CAD popup + map marker. The full **CAD dispatcher console** (AP_dispatcher role +
  task-board dialog) is intentionally deferred to a later task (owner chose "both: pings now, console later").
- `fn_maxtacDispatched`/`fn_maxtacDeactivate` RESTORED: officer gets a summons popup + "Join MaxTac Deployment"
  scroll action → MaxTac kit + `APS_fnc_registerMaxTac` → the intact server flow spawns the MaxTac MRAP/boat and
  deploys the squad. `maxtacDeactivate` self-routes server→officers and restores patrol gear.

### ⏭️ Racing — DESCOPED by owner (2026-06-11)
- `fn_joinRace`/`fn_startRace`/`fn_raceWon` + server `fn_initEvent`/`fn_joinRace`/`fn_finishRace` are intact,
  but the mission has **zero race-track markers** (`race_N_pos_1..10`, `race_N_start` for events 1-6 were never
  placed). Needs ~70 markers / route design. Owner: skip for now — revisit when tracks can be laid out.

### ✅/⏭️ Casino / fun
- ✅ `fn_jackpot` — RESTORED (#0027). It's the **lottery** jackpot payout (server `fn_addToLottery` → winner);
  forwarded to the existing win UI + bank credit from `fn_lottoTix` case 2.
- ⏭️ `fn_playKaraoke` — DESCOPED by owner: no song oggs (lav/dsb/iab/ymca) and no `kar_monitor` object exist.
  Revisit when music files + a karaoke spot are provided.

### 🟡 Wanted / Jail / Gang (mostly DUPLICATES — real logic lives elsewhere, these compat shims are dead weight)
- `fn_jail`, `fn_jailSys`, `fn_prisonBreaker`, `fn_startPrisonBreak` — jail/prison-break (REAL logic =
  `APS_fnc_handleJail` / `APS_fnc_handlePrisonBreak`, working). These compat dupes are inert.
- `fn_setBounty`, `fn_setRestrained`, `fn_wantedPardon`, `fn_wantedPerson` — wanted system (real server-side
  exists; e.g. server `fn_wantedPerson` is real, the compat one is a stub).
- `fn_addToGang`, `fn_forceJoinGroup` — gang/group add.

### 🟡 Misc handlers (inert no-ops, but each has live call-sites → must EXIST, do NOT delete)
`fn_addStatistic`, `fn_applyWeather`, `fn_battlEyeReceive`, `fn_capNotice`, `fn_createVehicle`, `fn_GEMenu`,
`fn_localChatMessage`, `fn_receiveOwner`, `fn_reqsync`, `fn_sessionReceive`, `fn_vehicleExit`.
(`fn_impoundMenu` was the only 0-caller misc stub → DELETED 2026-06-11.)

### ✅ NOT dead (compat shims already repaired — leave alone)
`fn_gangBank`, `fn_gangMembersReceive`, `fn_getBuildID`, `fn_uC`.

---

## 3. 🟡 Other casualties

- **`VAS_prompt`** — referenced (Virtual Arsenal prompt) but no class defined. Likely unused; verify.
- **Orphaned `ga_hud_nametags`** in `dialog/hud_nameTags.h` — the ga_→AP_ sweep (#134) skipped `.h` files,
  so the ORIGINAL (fuller, type-13) nametag dialog kept its `ga_` name and is now dead. My #135 replacement
  (`AP_hud_nametags` in chat_hud.hpp) is what's active. Cleanup: rename the .h class to `AP_hud_nametags`
  and delete the #135 duplicate to use the original, OR just delete the orphan.
- **Mag-repack keybind** — `fn_keyDownHandler` note: "deobf kept the addon but dropped the keybind CHECK."
  Verify the Outlawed mag-repack key actually fires.

---

## 4. ✅ Already restored this session
- Custom **horns** + CfgSounds skeleton — #133
- Player **nametag HUD** (`AP_hud_nametags`) — #135
- **Billboard rotation** (was gutted to one static image) — #139
- `AP_activeQuest` undefined throw — #135
- Login splash / rules boards / flag textures (grumpycat replaced) — #139
- **Lottery jackpot** payout (`fn_jackpot`) — #0027
- **Police auto-dispatch** event pings + map markers (bank/fed/prison/store) — #0027
- **MaxTac dispatch** (summons popup + Join action + MRAP deploy + stand-down) — #0027
- **Jury trial / courtroom** end-to-end (needs live-courtroom playtest) — #0027
- (Owner-descoped this pass: **racing** = no track markers; **karaoke** = no song oggs/monitor)

---

### Suggested fix order
1. **Sounds** (§1) — fast, mechanical, high player-noticeable value. One CfgSounds.hpp pass.
2. **Dynamic market** (§2) — currently vestigial: `AP_price_index` is updated server-side but read by NO
   pricing code (shops use static `virtItemCfg` prices). Reviving it is a *feature* — wire the index into
   `fn_virtualShopPopulate` + build a real `itemDemand` table — not a quick stub fix. Same for vehicle-sell-for-cash.
3. Pick the fun systems you want live (trials / races / casino / karaoke / dispatch) — each needs both the
   compat stub fleshed out AND its server-side counterpart, so these are bigger.
