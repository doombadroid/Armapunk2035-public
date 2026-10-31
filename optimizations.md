<!-- LooneyBin optimization / cleanup backlog from the 2026-06-04 code audit.
     Work top-down (priority order). Check a box only after the change is staged + reboot-verified.
     Status: [ ] todo · [~] in progress · [x] done -->

# LooneyBin — Optimization & Cleanup Backlog

Audit date: 2026-06-04. Order = highest value / lowest risk first.

## 🔴 Performance blockers (server FPS)

- [ ] **P2 — Gate per-query SQL logging behind a debug flag**
  `server/AP_server/core/DB/fn_asyncQuery.sqf:22` and `fn_queryGangs.sqf:13`
  `diag_log format["SQL Query: %1", _queryStmt]` fires **unconditionally on every query**. At load = constant RPT disk writes (FPS) **and** leaks raw SQL (player UIDs, money, positions) to a plaintext log (security).
  Fix: wrap in `if (LB_DB_DEBUG) then {…}` (default off). Quick win, do first.

- [ ] **P1 — DB global lock + CPU busy-spin** (the big one — see `features.md` PERF entry)
  `server/AP_server/core/DB/fn_asyncQuery.sqf`
  - L15 `waitUntil {!DB_Async_Active}` → every SQL op server-wide runs single-file; loads queue linearly with player count. The player-sync bottleneck.
  - L37-40 + L46-50 `while {true}` result-spin with **no `uiSleep`** → burns a scheduler fiber per query.
  Fix: `uiSleep 0.001` in the spin loops; batch the per-player connect load into ONE query; drop the lock for READS (keep write serialization). Target 200 ms sync @ 100 players.

- [ ] **P3 — 259 `addAction`s registered per client, conditions eval'd every frame**
  `mission/LooneyBin.Altis/core/fn_setupActions.sqf` (103 KB)
  Engine re-evaluates each action's condition SQF ~every frame while interaction is possible. Many gate side/role **inside the condition string** (eval'd forever) instead of at registration.
  Fix: wrap cop/medic/admin action blocks in `if (playerSide …)/(call AP_*Level …) then {…}` so they're never registered for players who can't use them. Cuts per-frame eval substantially.

## 🟡 Optimizations / done better

- [ ] **Hot-path `diag_log` cleanup** — 98 `diag_log` calls server-side; the DB ones fire per-query. Wrap debug logging behind a flag (folds into P2).
- [ ] **Public `setVariable [...,true]` audit** — 145 server-side. Review the ones inside `while`/`forEach` loops for redundant network broadcasts (network churn).
- [ ] **Draw3D / PFH early-exit check** — 15 client per-frame handlers (ESP/HUD/spectate). Confirm each bails immediately when its feature is off (don't iterate `allUnits` every frame for a closed ESP).
- [ ] **DB result `call compile` per query** — inherent to the extDB protocol; low priority, note only.

## ⚪ Dead code — 55 mission fn classes with ZERO call-sites (sqf/hpp/h, mission+server)

No dynamic `format["AP_fnc_%1"]` dispatch exists, so these aren't hidden-live. **Verify the `dom*` set first** — they may just mean domination mode is unused on this server (`AP_serverId != 2`) rather than orphaned.

- [ ] **Domination cluster (~16)** — `domLoadoutSelection domOverviewMenu domSaveLoadout domChooseLoadoutCurrency domDeleteLoadout domEquipLoadout domGetLoadoutItems domGetLoadoutPrice domGetVirtualInv dominationCapture dominationCutscene dominationEnded dominationMissionHardpoint domLoadoutPreview getDomCTF spectateDomESP`
- [ ] **Misc dead (~39)** — `achievementMenu adjustMoney armory boltcutter civBH clientWireTransfer copDeploy ctrlCreate earthquakeClient evidenceVaultOpen fetchPersistentBounties forceRagDoll formatNumber fullScreenNVG gangBankTransfer gangNewLeader garageLBChange garageSpawnCfg handleSwat isMarkerNull keyDrop lockEvidence marketSel nearUnits notifyAdmins notifyServerRestart playerCount pushVehicle removePerFrameHandler removeWantedCharges sellOil serviceChopper sidechatMonitor sortArray speedbomb srvFullPercent statsConfig vehicleWeightCfg welcomeNotification`
  Each: remove the `class <name> {};` from `Functions.h` + delete the `fn_<name>.sqf` file. Do in small batches, reboot-verify between.

## Known (tracked elsewhere, listed for completeness)

- [ ] **CfgRE remoteExec backdoor** — close before public launch (see memory `loonybin-cfgre-rce-deferred`). NOT during testing.
- [ ] Deobf `CfgSounds` artifact — emptied stub, restore real defs if sound work needed.
