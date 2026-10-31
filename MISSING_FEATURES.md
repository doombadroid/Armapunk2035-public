# LooneyBin — Missing / Not-Implemented Features (codebase audit 2026-06-09)

Method: swept both PBO sources for deobf stubs (`Safe stub` headers, log-only bodies), TODO/ADAPT
markers, registered-but-missing functions, calls to undefined functions, and cross-checked every stub
against its live client call-sites. House persistence was re-verified as IMPLEMENTED (stale note).

---

## 🔴 TIER 1 — whole features dead (server fn is a log-only stub, client side fully built & calling it)

| Feature | Stub(s) | Player impact |
|---|---|---|
| **Loony Bin / Mental-Hospital heist** (the namesake!) | `APS_fnc_loonyBinSRV` | Client side is COMPLETE (gate demo-charge breach, thermite front door, 5-laptop virus hack, patient-remains loot, cop firewall-reset + bury counterplay). `SRV_loonyBinData` is never published by the server → every gate reads defaults → the heist can never start. Biggest single gap. |
| **Convoy robbery** | `APS_fnc_convoyRobbery`, `APS_fnc_endConvoyRobbery` | Start + finish both stubbed → entire convoy event dead (client actions + `npcs/fn_civConvoy` exist). |
| **Jewelry Emporium heist (server half)** | `APS_fnc_jewelryEmporiumSRV` | Client action exists; server orchestration (loot/state/cooldown) never runs. |
| **Evidence system chain** | `APS_fnc_evidenceAppend`, `APS_fnc_evidenceTruck`, `APS_fnc_handleTimer` | Cop seizures never append to evidence, evidence-vault open has no server half, evidence timers dead. (Client `evidenceVaultOpen`/`lockEvidence` are ALSO unhooked — double-dead.) |
| **Admin events** | `APS_fnc_event{GunGame,BR,Graveyard,Purge}SRV` | Already tracked — deferred to features.md (#50). |
| **Gang houses (server half)** | `APS_fnc_addGangHouse`, `APS_fnc_changeGangHouseSRV`, `APS_fnc_removeGangHouseSRV` | Set/change/remove gang house never persists or applies server-side. |
| **House tax** | `APS_fnc_houseTaxSRV` | Phone → Housing tax menu does nothing server-side. |
| **Daily login bonus** | `APS_fnc_loginBonusSRV` | Login bonus never pays out. |
| **Mobile HQ (server half)** | `APS_fnc_srvMobileHQ` | Cop prestige tree SELLS Mobile HQ (40–75k nodes) but the server half of deploy/garage is a stub — buyers get a dud. Either implement or pull the prestige nodes. |
| **Time trials vehicle spawn** | `APS_fnc_createTimeTrialVehSRV` | Race vehicle never spawns → time trials can't run. (`timeTrialSRV` finish-line fn exists but is TODO-ADAPT, see Tier 3.) |
| **Cartel capture airdrop** | `APS_fnc_airDrop` | Cartel-capture airdrop reward never spawns. |
| **Medic airdrop / med supply** | `APS_fnc_airDropMedic`, `APS_fnc_medSupplySpawn` | Medic supply-drop + med-supply item use are dead. |
| **Drop charge** | `APS_fnc_wantedRemoveCharge` | pmenu "drop charge" never actually removes the charge from the server wanted list. |
| **Vehicle skin shop purchase** | `APS_fnc_doBuySkin` | Skin purchase never applies/persists (moot-ish: custom skins currently stripped anyway). |
| **Gang bank history** | `APS_fnc_gangBHistory` | Gang bank history dialog always empty. |
| **Bank lighthouse toggle** | `APS_fnc_bankLightHouseToggle` | Lighthouse signal during bank robbery dead (cosmetic). |
| **Seasonal events** | `APS_fnc_easterSeasonalEvent`, `APS_fnc_xmasTreeAndPresentsSRV` | Easter event + Christmas tree presents dead (off-season, low prio). |
| **Vehicle key mgmt (server half)** | `APS_fnc_keyManagement` | Called by `prepareVehicle` + `chopShopClaim` — claimed/chopped vehicle key grants incomplete. |
| **Discord webhook embeds** | `APS_fnc_discordEmbed` | Server→Discord embed posts dead (internal; loonybot covers most of this now). |

## 🟡 TIER 2 — calls to functions that DON'T EXIST anywhere (runtime script error when the path fires)

| Missing fn | Called from | Impact |
|---|---|---|
| `AP_fnc_animSync` | `fn_boltcutter` (+1) | Boltcutter anim sync errors. |
| `AP_fnc_pushFunction` | `fn_pushVehicle` | Vehicle-push dead (fn also unhooked — double-dead). |
| `AP_fnc_gangWars` | `fn_warChallenged` | War-challenged notification path errors. |
| `AP_fnc_clothing_barber`, `AP_fnc_clothing_faces` | `fn_clothingFilter` | Barber / face shop tabs error if opened. |
| `AP_fnc_blindfold` | `fn_onPlayerKilled` | One stale ref (real fn = `blindfoldClient`) — error on a blinded death path. |
| `AP_fnc_vehicleColorStr` | `dialog/fn_garageLBChange` | Garage listbox color label (fn itself dormant). |
| `MP_queue` | `server init.sqf` (2 refs) | Legacy 2017 remnant. |

## 🟡 TIER 3 — implemented but UNVERIFIED (deobf "TODO ADAPT": 2017 server fn vs 2020 client args may mismatch)

`exchangeSystemSRV` (market price reduction), `srvObjectMonitor`, `transferHouse`, `updateHousePrice`,
`varPersist`, `adminPlayerQuerySRV`, `checkPlayer`, `spawnPhysicalItem` (storage crates),
`getStatsArr`, `update1GangTalents`, `bulkAdd`, `timeTrialSRV`, `eventParticipants`, `getID`,
`setGangTagSRV` (ALSO needs a schema column add — tracked in its header).
**Each may silently mis-parse args.** Worth one functional test apiece.

## 🟡 TIER 4 — written client mechanics with NO trigger wired (dormant; from features.md audit, re-verified)

evidenceVaultOpen · lockEvidence · copDeploy · handleSwat · serviceChopper · removeWantedCharges ·
sellOil · civBH (vendor NPC) · armory (vendor NPC) · earthquakeClient · clientWireTransfer (server
`handleWireTransfer` EXISTS — wiring this one is cheap) · keyDrop · pushVehicle · garageLBChange ·
garageSpawnCfg · sidechatMonitor · notifyServerRestart · gangNewLeader.
> Correction: `fetchPersistentBounties` was listed dormant in features.md but IS live (jailMe + srvPersistentBounties) — remove from that list.

## ⚪ TIER 5 — host-integration placeholders (deliberate, post-extDB3-migration gaps)

- `fn_getGuid` — returns UID, not a real BattlEye GUID.
- `fn_getIpAddress` — returns `0.0.0.0` (needs an extension).
- `fn_banPlayer` — logs only; not wired to BE/RCON (loonybot `!srv ban` = DB ban + kick covers it).
- `fn_hardRestart` / `fn_patchServer` / `fn_doRestart` (+`1M` variants) — old `.bat` shells; log-only
  (loonybot `!srv hardr/softr` covers restarts).

## ⚪ TIER 6 — already tracked elsewhere (don't double-count)

- Admin event system build → **features.md** (FLAGGED).
- Revive drone: charge persistence, real DB vehicle row, revive race-lock → features.md.
- Vehicle skins: de-brand + re-add 157 customs → features.md.
- Player sync ≤200 ms @ 100 players (async-bridge rework) → features.md [PERF].
- 29-dormant-mechanics list → features.md (Tier 4 above is the live-verified remainder).
- CfgRE/server.cfg hardening + beta god-stats + newbie auto-admin → **launch.md**.
- loonybot: `!pid` by-Discord-ID lookup "not built" — now trivial via the new `discord_links` table;
  `!link` has no in-game ownership verification (noted in launch.md).

---

### Suggested priority if implementing
1. **Loony Bin heist server half** (namesake; client 100% done — highest value per effort)
2. Convoy robbery start/finish (event content)
3. Evidence chain (cop gameplay loop) + drop-charge
4. Mobile HQ server half (prestige tree already sells it — currently a paid dud)
5. Login bonus (small, daily retention)
6. House tax + gang houses (economy/gang depth)
7. Tier 2 quick fixes (point refs at the right fn names — mostly 1-liners)
8. Tier 3 verification pass (one test each)
