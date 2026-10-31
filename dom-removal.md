<!-- Domination removal tracker (started 2026-06-04). Full strip per owner request.
     Backups: ~/looneybin-backup-pre-domstrip-20260604-153807.tar.gz
     SRT decision: remove dom-tied SRT, KEEP standalone MaxTac (AP_isMaxTac/AP_activeMAXTAC/srt_weapons/MaxTac Armory).
     Status: [x] done+boot-verified · [~] partial · [ ] todo -->

# LooneyBin — Domination Removal

## ✅ Done + boot-verified
- [x] **Dom code files** — deleted ~33 files in `core/domination/` (internals, GUI, loadouts, nuclear, config, mapData), `core/adminSpectate/fn_spectateDomESP.sqf`. 17 still-referenced fns stubbed inert (`if(true)exitWith{false};`): isDominationActive, inDomSafezone, dominationSRT/Mission/Client/SetVehIdle/SetupActions/Repack/Gulag/GearCheck, initDomHUD, closeDomHUD, domGroupMenu, domMiniScoreMenu, domLoadoutMenu, + EVH onPlayerKilledDomination/handleDamageDomination.
- [x] **Functions.h** — removed deleted-fn entries (DominationConfig category gone; GUI/Loadout/Domination trimmed to stubs only).
- [x] **Dialogs** — deleted 4 dom dialogs (dominationGroups/MiniScoreboard/ScoreBoard/LoadoutSystem.hpp) + their MasterHandler.h includes.
- [x] **Titles** (`fn_titleCfg.sqf`) — removed 13: dom 95-105, Nuclear #179, SRT #228.
- [x] **Achievements** (`configuration.sqf` AP_achievementInfo) — removed 19 dom: ids 8,9,10,34,37,55-62,64,68,72,73,74,76.
- [x] **Wallpaper** (`configuration.sqf` AP_wallpapers) — removed id 6 "dominationwinner.paa".
- [x] **Notifications** (`description.ext` CfgNotifications) — removed dominationAlert, domKill, domDeath, srtKill, srtDeath, srtUncap.
- [x] **Assets** — deleted `dominationwinner.paa`, `billboarddomination.jpg`.
- [x] **Dead branch strip, batch 1** — mechanically dropped 33 always-true `&&!(isDom)` / `!(isDom)&&` terms across ~17 files.

## ✅ COMPLETE — dead-branch strip + stub deletion DONE (2026-06-04)
All 180 `isDominationActive`/`AP_serverId==2` call-sites removed (proper keep-else / unwrap / remove / simplify, per-block). `inDomSafezone` call-sites removed. **All 17 stub functions deleted** (`core/domination/` dir gone + 2 EVH stubs) + their Functions.h entries (`Domination`/`DominationGUI`/`DominationLoadout` categories + `handleDamageDomination`/`onPlayerKilledDomination`) + CfgRE whitelist entries (`AP_fnc_domination*` + `APS_fnc_domination*`). Boot clean throughout, braces verified balanced.

**Zero domination function calls remain. Domination feature 100% removed.**

### ✅ Inert residuals ALSO removed (2026-06-04) — **ZERO `dominat` tokens mission-wide**
- `updateRemoteStat` — deleted dom stat cases (death/kill/captures/wins) + display switch + sound switch + `_domKills` destructure
- `statArrUpdate`/`statsConfig` — removed 7 dom stat name→index mappings; `statsFilter` — removed "Live Domination Stats" tab, renamed positional labels
- `ambientAnim` — removed 4 dead dom loadout cases; `hornCfg` — removed 7 dom-stat-gated horns; `vehicleTextures` — emptied dom-reward skin unlocks
- **`images/domination/` → `images/skins/`** + admin-spectate imgs → `images/spectate/` (paths updated in vehicleTextures/clothingTextures/clothing_cop/spectateESP)
- long tail: getInMan/getOutMan CTF vars, spawnPointCfg/onFired/onPlayerKilled `dominationPoly`, handleMessage dom case, vehicleShopMenu SRT gates, isMarkerNull resets, spawnMenu/questSel/questMenu/welcomeUIConfig/weaponShopCfg refs
- **inert var declarations removed**: init.sqf (11 dom vars) + configuration.sqf (8 dom vars)
- description.ext — removed 6 unreferenced SRT-dom `CfgDebriefing` classes

**Note:** `AP_enableDomHUD`/`AP_domHudID`/`AP_domLoadout*` (no "dominat" substring) remain as inert positional client-settings — harmless, not dom-feature tokens.

### ~~Inert residuals~~ (superseded — all removed above)
- `fn_updateRemoteStat.sqf` (~26) — dead dom kill/death stat-tracking (`A_stats_dominationStats`, `AP_dominationStatCache`); var-based, only reachable via removed dom-kill paths. Big block in a critical fn — left inert.
- `init.sqf` / `configuration.sqf` — inert dom var defaults (`A_stats_dominationStats=[0,0,0,0]`, `AP_dominationPotCache`, `SRV_domination*`, `AP_enableDomHUD`, etc.).
- `fn_statsConfig.sqf` / `fn_statArrUpdate.sqf` / `fn_statsFilter.sqf` — dom stat NAME mappings (62-65, 140-142). **Positional indices — removing risks shifting other stats.** Left.
- Dead `private _isDomination = false;` locals (clothing_reb, virtualShopUpdate, questMenu, redeployMenu, vehicleConfig) + their dead `if(_isDomination)` branches.
- Shared assets KEPT (referenced by non-dom code): `icons/dom/` (gangfort HUD), `images/domination/` + `sounds/horns/dom/` (clothing/vehicle/horn/ESP), `fn_vehicleTextures`/`fn_hornCfg`/`fn_ambientAnim`/`fn_spectateESP` dom refs.
- SRT-dom `CfgDebriefing` (description.ext) — referenced by kept standalone-MaxTac code.

## ~~Remaining — dead-branch strip~~ (superseded — see COMPLETE above)
### Strip progress
- [x] batch 1: 33 always-true `&&!(isDom)` terms (sed, ~17 files)
- [x] `fn_weaponShopCfg.sqf` (36 — dom/SRT shop entries) · `fn_vehicleShopBuy.sqf` (6) · `fn_vehicleGaragePull.sqf` (5) · `fn_gangGaragePull.sqf` (5)
- [x] `init.sqf` (6 — mapData switch, dominationClient, loadingScreen) · `fn_initCop.sqf` (5 — SRT cop-count blocks) · Cat-2 empty exitWith ×4 (addInfamy, passiveMode, clientMobileHQ, questMenu)

### Remaining by pattern (reboot-verify each batch; `fn_*` files compile-check on boot, `init*`/`initServer` do too, plain `init.sqf` does NOT → brace-check it)
- [ ] **Cat A — `if (AP_serverId isEqualTo 2) exitWith {…}` standalone dead blocks** → remove block. Files: actions/fn_drillOil, fn_ga1ther, fn_gatherObject, fn_gatherWater, fn_refillAmmo, fn_robStoreAction, gangs/fn_captureCartel, housing/fn_buyHouse(+then) /fn_handleHouse/fn_sellHouse, items/fn_spikeStrip, vehicle/fn_deviceMine, pmenu/fn_wantedMenu, functions/fn_enableActions, dialog/fn_loadingScreen, initPlayerLocal, initServer.
- [ ] **Cat B — `if (isDom) then {X}` / `exitWith {body}` blocks** → remove (or keep `else`). Files: actions/fn_refillAmmo, config/fn_vehicleConfig(×2), fn_weaponAddons(×3), fn_setupEVH(×3), functions/fn_fetchWeaponMagazines/fn_getRankString/fn_initStats/fn_jump/fn_setVehicleIdle, items/fn_redgull, medical/fn_respawned/fn_revived(×2), session/fn_requestReceived(×3), shops/fn_clothingFilter/fn_vehicleShopMenu/fn_virtualShopManage/fn_virtualShopMenu/fn_virtualShopPopulate(×2)/fn_weaponShopBuy/fn_weaponShopFilter(×3)/fn_weaponShopMenu(×2)/fn_weaponShopSelection(×2)/loadouts(equip/getLoadoutPrice), dialog/fn_createDialog/fn_spawnConfirm(×4)/fn_spawnPointCfg/fn_statsMenu/fn_welcomeUI, evh/fn_getInMan/fn_getOutMan/fn_onFired(×3)/fn_keyDownHandler(×2)/fn_keyUpHandler, npcs/fn_civRebelVehicles(×2)/fn_civRebelWeapon(×2)/fn_copShops(×2)/fn_copVehicles(×2).
- [ ] **Cat C — `if !(isDom)` / `if !!(isDom)` unwrap/remove** → config/fn_vehicleAnimate(×2), fn_survival, fn_initCiv, medical/fn_revived, session/fn_requestReceived, pmenu/fn_capt1ure /fn_captureSel, shops/fn_chopShopMenu, dialog/fn_welcomeUI.
- [ ] **Cat D — local `private _isDom… = call isDom;` → `false`** (kills the call so stub deletable; dead local-var branches remain) → config/fn_clothing_reb /fn_vehicleConfig, functions/fn_playerTags /fn_trackMarkers, quests/fn_questMenu, shops/fn_virtualShopPopulate /fn_virtualShopUpdate, dialog/fn_redeployMenu, initPlayerLocal, config/fn_clothing_cop (`_isSRT`).
- [ ] **Cat E — condition simplify** (`&&inDomSafezone`, `||call isDom`, `&&(isDom)`) → fn_vehicleConfig (`||`), fn_weaponAddons (`||`), shops/fn_buyClothes /fn_weaponShopMenu /fn_virtualShopMenu, vehicle/fn_prepareVehicle(×2), evh/fn_onFired(inDomSafezone).
- [ ] **Cat G — `evh/fn_onPlayerKilled.sqf` (minified monster)** — dom CTF drop block + `case(…AP_serverId==2&&isDom):{"SRT Trooper "}` in killfeed switch. Careful literal edits.
- [ ] **then delete the 17 stubs** + Functions.h `Domination`/`DominationGUI`/`DominationLoadout` categories + EVH stubs + `inDomSafezone`.

## ✅ this-batch also done
- [x] dom achievements (19) + wallpaper (configuration.sqf) · dom notifications (description.ext) · 2 assets

## 🔵 Deferred (low-value / entangled — confirm before doing)
- [ ] **Dom stat name mappings** (`fn_statsConfig.sqf` 62-65 dominationkills/deaths/captures/won, 140-142 srtdomination) — internal DB index→name, invisible, always 0. Removing risks index assumptions.
- [ ] **Dom client vars** (`configuration.sqf` + `init.sqf` — AP_dominationPotCache, AP_dominatonCTF, AP_dominationGulagData, AP_enableDomHUD, AP_dom*, A_stats_dominationStats, SRV_domination*) — already inert defaults; remove after call-sites stripped.
- [ ] **CfgRE.hpp** dom whitelist entries — harmless (whitelist of stubbed/missing fns); clean up at end.
- [ ] **SRT-dom CfgDebriefing** (SRTmoreThan10On etc., "domination session" text) — referenced by KEPT SRT/MaxTac code; left in place (won't trigger with dom off). Could reword text.
- [ ] **`images/domination/`** (11 files) + **`sounds/horns/dom/`** (8) — referenced by non-dom clothing/vehicle/ESP/horn code → NOT safe to blanket-delete. Audit per-file if wanted.
- [ ] **KEEP `icons/dom/`** (12 files) — reused by the Gang Boat HUD (`fn_gangBoatHud`). Do NOT delete.
