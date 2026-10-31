# LooneyBin performance audit — 2026-07-05

Post-b0130 sweep. 5 parallel read-only agents, non-overlapping domains: DB/extDB3, server loops/sim, network, client PFH/UI, hot-path micro. Every finding git-blame-checked. **Only ONE finding touches Infamous-arma code** (setupActions, flagged — needs owner sign-off). Everything else Doomba-authored.

Already-shipped (excluded, not re-reported): singleevh scheduler (20 loops), stat double-buffer, `-FNCALL-` save-path doubling. Server-loop domain returned **no high-severity** — the per-tick world-scan killers were already handled by that work.

---

## TIER 1 — HIGH impact, safe, widest reach (do first)

### 1. `virtItemCfg` rebuilds the 277-row item catalog on EVERY call
`mission/LooneyBin.Altis/core/config/fn_virtItemCfg.sqf:3-288` (build) / `:294-388` (lookups)
- 183 call sites. Each call re-allocates a 277×11 literal (~3000 elements) + O(n) `findIf`; `getShortName`/`getName` run `format` per row scanned (up to 277 formats/call).
- **Compounds:** `calWe1ght.sqf:5-12` calls it 2× per owned item (30 items = ~60 full rebuilds; runs every 50s + every pickup/drop/give-medkit); `calWeightDiff.sqf:3-14` rebuilds it per `while`-loop iteration (add 100 = ~99 rebuilds).
- **Fix:** build the static array ONCE into a mission var; invalidate only when `count AP_foreskinReg` changes. Add `createHashMap` indexes at cache time (`classname→row`, `"AP_inv_"+cls→row`). Every lookup → O(1) `get`, zero alloc, zero format.
- Risk low-med (cache invalidation on foreskin registry). Confidence high. **Single widest-reach change in the client tree.**

### 2. `fn_playerTags` full re-render + LOS raycast every frame
`mission/LooneyBin.Altis/core/init.sqf:122` (EachFrame EH) / `fn_playerTags.sqf`
- Per nearby unit, EVERY frame: `lineIntersects` LOS raycast + full `parseText`/`ctrlSetStructuredText` rebuild. Name string already cached in `AP_nameCache` yet re-parsed + re-pushed each frame.
- **Fix:** cache last `_nameTag` per idc, skip `parseText`+`ctrlSetStructuredText` when unchanged (keep only `ctrlSetPosition` — head still moves); throttle LOS to every ~3-5 frames (feeder scan already cadenced at 1.3s).
- Risk med (tag flicker if key wrong). Confidence high. **Biggest always-on client cost.**

### 3. Mobile HQ `setupShops` JIP-queue leak (also a dupe-action bug)
`server/AP_server/core/TON/fn_srvMobileHQ.sqf:100`
- Persistent remoteExec (`true`) with NO named JIP id → mints an immortal auto-id every cop deploy. JIP queue grows unbounded; every new joiner replays ALL historical deploys → duplicate shop scroll-actions + duplicate "Pack Up" on the same base.
- **Fix:** named slot `"AP_mobileHQ_jip"`, cleared on teardown (`remoteExec ["", "AP_mobileHQ_jip"]`), mirroring the correct `fn_changeWeather.sqf:32/58` snowFX pattern. Or drop JIP entirely — client can run setupShops locally off the already-published `SRV_mobileHQ`.
- Risk low. Confidence high. **Correctness + perf.**

### 4. Login N+1 — redundant SELECTs through the one DB mutex
`server/AP_server/core/DB/fn_queryRequest.sqf:116, :123, :312, :330`
- 2 separate `discord_links` SELECTs (`reward_pending`, `beta_pending`) + 2 re-reads of the already-fetched `players` row (`lb_*`, drone cols). ~9 queries/civilian login. Worst at boot-rush (40-60 clients through the serialized mutex in ~2 min).
- **Fix:** merge discord reads into one; append `lb_*`/drone cols to the main `_pq` SELECT (strictly trailing indices, keeps existing `_p select N` valid). ~9→6 queries/login.
- Risk low-med (keep cols appended, re-test returning-player + medic login). Confidence med-high.

---

## TIER 2 — MED impact, safe-ish

### 5. Adjacent `ClupdatePartial` → 2-3 UPDATEs to same row
router `mission/LooneyBin.Altis/core/session/fn_ClupdatePartial.sqf:276`; sites `fn_weaponShopMenu.sqf:164-165`, `fn_ticketPay.sqf:30,41,42`, `fn_vehicleShopBuy.sqf:166,168`, `fn_clothingMenu.sqf:215,219`
- Every gun buy = 2 UPDATEs, ticket-pay = 3, clothing = 2, all same `players` row. Biggest *sustained* DB load at peak pop.
- **Fix:** coalesced mode (gear+cash+bank in one UPDATE) or client-side same-frame debounce. Must preserve mode-3 gear anti-cheat/dupe guards.
- Risk med (gear guards). Do cleanest pairs first.

### 6. `handleInv` sums ~200 monitor vars per transaction
`mission/LooneyBin.Altis/core/functions/fn_handleInv.sqf:19-22`
- `forEach AP_invMonVars { getVariable }` full-set sum on EVERY buy/sell/craft/process/pickup/drop, feeding the anti-dupe drift check.
- **Fix:** maintain running total incrementally (fn already adjusts `AP_invMonitor` at :55/:71).
- Risk med (security tripwire — keep drift check correct). Confidence med.

### 7. `restoreVehicles` N+1 (boot-only)
`server/AP_server/core/DB/fn_restoreVehicles.sqf:60-61, :184`
- SELECT-per-vehicle + UPDATE-per-vehicle. ~2N queries at boot.
- **Fix:** per 20-row page, one `SELECT ... WHERE plate IN(...)` + one `UPDATE ... active='1' WHERE plate IN(...)`. Keep QUOTE(classname/mods).
- Risk low-med, boot-only easy to validate.

### 8. `hudUpdate` micro
`mission/LooneyBin.Altis/core/functions/fn_hudUpdate.sqf:59, :79-90`
- `position player` 2×, throwaway `[x,y,0]`, `getMarkerPos` static marker resolved every call, 3D `distance` where `distance2D` fits; bounty `allPlayers findIf` per entry.
- **Fix:** cache respawn-marker pos at init, `distance2D`, hoist `position player`.
- Risk low. Confidence high.

---

## TIER 3 — LOW impact / quick trivial wins

- **Sleepless `waitUntil`s** (server): turf window `init.sqf:1086`, maxtac `fn_maxtacDispatch.sqf:43/60/107`, trial `fn_trialBegin.sqf:68/81`, goldbars `fn_spawnGoldBars.sqf:17`. Add `uiSleep 1;` as first stmt — behavior-identical, frees per-frame scheduler slots. Trivial/safe.
- **`fn_MP` micro** `fn_MP.sqf:16,22,49`: hoist `_denyAudit` to compile-time const, `toLower` only inside the log branch, `_target isEqualTo []` not `count _target isEqualTo 0`. (Phase-0 `_denyAudit` is mine.) Trivial.
- **loonybot bridge 5s poll** `init.sqf:1805`: relax to 8-10s or adaptive backoff. Mutex 12×/min forever even idle. One-line.
- **`fn_survival` per-tick** `:221,256,273`: hoist `visiblePosition player` (4×/tick), cache backpack `maximumload` on backpack-change not config-read/sec.
- **Streamer profanity filter** `fn_setupEVH.sqf:43-64`: `forEach allControls`/frame while scoreboard open (streamers only) → throttle 0.5s. Well-gated for everyone else.
- **`ProjectileCreated`** `fn_setupEVH.sqf:68-81`: memoize explosive-vs-not per ammo class (`createHashMap`) — per-shot config read.
- **Market tick** `fn_marketTick.sqf:96`: skip `publicVariable "AP_price_index"` when unchanged vs last tick. Marginal.
- **Jewelry PFH + DP-mission Draw leak** `fn_jewelryEmporium.sqf:284-295`, `fn_getDPMission.sqf:158`: capture handles + remove on reset/complete. Correctness smell, minor FPS.
- **playerTags micro-hoists** `fn_playerTags.sqf:43,48,99,254,268`: compute `goggles _x in AP_masks` once, hoist `_x in allPlayers`, cache group→name on the group object.
- **Governor timer DB-poll** `fn_govSystemSRV.sqf:114,169`: `SELECT UNIX_TIMESTAMP()` every 30s for up to 7 days (~20k queries/term). Compute wake instant once. Risk med (election timing) — flag, don't auto-apply.

---

## NEEDS OWNER SIGN-OFF — FLAG-INFAMOUS

### `fn_setupActions` — 290 player scroll-actions, 24 with ungated `nearestObjects` conditions
`mission/LooneyBin.Altis/core/fn_setupActions.sqf`
- All 290 conditions evaluated every frame while scroll menu open (~7s window). 21 `nearestObjects` + 3 `nearestTerrainObjects` + 1 `nearEntities` run the spatial scan UNCONDITIONALLY FIRST, no cheap short-circuit = the classic scroll-wheel stutter. HIGH impact (bounded to menu-open).
- **Fix:** prepend a cheap boolean (`&&` lazy short-circuits) before each spatial call so the scan only runs when plausibly relevant.
- **BLOCKED:** file wholesale-reformatted by Infamous (commit `269d1d12`, 2026-06-26) → blame attributes the condition lines to him. Per standing rule: needs explicit owner sign-off + blame check before any edit.

---

## NO ACTION — by design / dead code (checked, not flagged)

- Kill feed 7×`-2` broadcast (~1/kill, JIP-off — fine); `AP_group_list` rebroadcast (vanilla); cartel-decay notice 60s (tiny payload).
- `asyncQuery` per-query `diag_log` = deliberate max-verbosity for CLANKR.
- `fn_queueManagement.sqf:12` sleepless loop = DEAD (never spawned; live path is asyncQuery). Leave or delete.
- Cleanup coverage complete (bodies/vehicles/wrecks/items all reaped); idle-sim disabled on props/NPCs/goldbars/furniture; cartelSRV now one-shot; all periodic world-scans on 20-300s cadence.
