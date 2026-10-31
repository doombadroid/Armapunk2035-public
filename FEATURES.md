<!-- LooneyBin feature / requirements backlog. One entry per planned feature or hard requirement.
     Status: FLAGGED (captured, not started) -> IN PROGRESS -> DONE. -->

# LooneyBin — Feature / Requirements Backlog

## [PERF] Player sync ≤ 200 ms at 100+ concurrent players — FLAGGED
**Requirement:** a player's full state load/save (sync) must complete in **≤ 200 ms even with 100+ players online**.

**Why (security, not just QoL):** slow/serialized sync opens **dupe + sync exploits** —
- **Duping**: a save that lags behind an action (drop/trade/store, then disconnect/crash before the save lands) lets the item exist twice. Tight, atomic, fast sync closes the window.
- **Ghosting**: position/state desync lets a player appear in two places / re-log to dodge a fight or skip a load gate.
- The smaller the sync window, the smaller the exploit window.

**Current state — the DB engine is NOT the bottleneck.** MariaDB answers a player-row SELECT in microseconds.
The minutes are lost in the **extDB3 ↔ SQF bridge** (`server/AP_server/core/DB/fn_asyncQuery.sqf`):
- **One global `DB_Async_Active` lock** → every DB op on the whole server runs single-file, one query at a time. extDB3 is multi-threaded (`Threads=0`) but the lock throws that away → loads queue linearly with player count.
- **Blocking mode-2 queries** → each connect runs several sequential SELECTs (`fn_queryRequest`: global row, player row, gang, …), each grabbing the lock + waiting ≥1 frame.
- **Busy `while {true}` result-spin with no `uiSleep`** → starves the scheduler under load.

**Approach (no DB swap — fixes the bridge):**
1. **Measure first** — instrument `fn_queryRequest` / save path: timestamp each step, log total ms per player, sample at load (synthetic 100-player burst if possible). Establish the real baseline + which step dominates.
2. **Batch the per-player load into ONE query** (collapse `queryRequest`'s multiple round-trips into a single SELECT/JOIN) — 1 lock grab instead of ~4.
3. **Drop the global lock for READS / use extDB3 concurrent async** — let extDB3's threads serve players' reads in parallel. (The lock exists to dodge the mode-1 reorder/dupe bug on WRITES — keep serialization/atomicity for writes only; see MEMORY.md "extDB3 / DB gotchas".)
4. **`uiSleep 0.01` in the result-spin** so it yields.
5. **Atomic writes** for anything dupe-sensitive (`REPLACE INTO` / `INSERT … ON DUPLICATE KEY UPDATE`, never DELETE+INSERT as two mode-1 queries — already a project rule).
6. Re-test under a 100+ load before calling it done.

**NOT recommended:** swapping MariaDB → Postgres/Redis/etc. — optimizes the 0.1 ms part, leaves the minutes untouched. (In-memory Redis via an Arma extension is a big rewrite + overkill once the bridge is fixed.)

**Status:** FLAGGED. Target 200 ms @ 100 players. Owner-set requirement (2026-06-03).

## [DONE 2026-06-04] Revive drones (flying little fucks) — land near dead body revive and it takes th
- **Accepted by:** doomba  ·  **From:** #Revive drones (flying little fucks)
- **Feature** (player036): Revive drones (flying little fucks) — land near dead body revive and it takes the normal amount of time to revive.
mainly used for wider range fights where driving around or running around is a pain. example being robbing the chop shop

**Discussion:**
> doomba: What rank do you want these drones to be available to
> doomba: <@100000000000000092>
> player036: I think A-EMT
> player036: I want ppl to want A-EMT and not have it locked to a few ppl who are staff positions
> doomba: What price and how many revives/bloodbags before it needs to "recharge" and how long should that recharge be

**Implemented (core complete):**
- AEMT+ gated (`AP_medicLevel >= 3`). Drone = AL-6 Pelican Medical (`I_UAV_06_medical_F`) w/ IDAP orange livery.
- Buy: drone **backpack** in clothing/uniform shop ($20k) + **UAV terminal** in gear shop ($1k), both AEMT+ only.
- Treat menu (R while piloting, or scroll on drone): **Revive / Bloodbag / First Aid / Adrenaline**, 3 m range, can self-treat (solo testing).
- **10 shared charges → 1 h recharge.**
- Revive **money + XP → owning medic** (the pilot). Mobile medical shop on the drone → revenue to owner's bank.
- **Check Registration** shows the owning medic (runtime `ga_vehOwners` tag).
- **F** = per-rotor medic lights (4 strobes) + siren (same as ambulance van: `medicWail`, say3D 650 m).
- Civs/non-AEMT **cannot keep the drone bag** — self-destructs if picked up off the ground.

**Left to implement / verify:**
- [ ] **Charge persistence** — `AP_droneCharges` is **session-only** (client var). Relog/reboot refills to 10 → mild exploit (relog to skip recharge). Persist to DB if it matters.
- [ ] **True DB vehicle row** — registration is a runtime `setVariable` tag for the Check-Registration readout, **not** a real DB vehicle insert. Drone does not survive reboot / not in garage. Original ask said "registered as a vehicle in the DB" — only do for real if persistence wanted.
- [ ] **Revive race-lock** (optional) — two drones could revive the same body at once → double reward. Add `ga_reviving` lock if it shows up.
- [ ] **User testing (untestable server-side):** R menu + F lights/siren actually fire in UAV terminal view; orange livery applies; 3 m range feels right; siren audible (`medicWail` resolves); 4-rotor light offsets sit on the rotors (`fn_medicLights` `_offs` — nudge if off).

---

## [ACCEPTED 2026-06-04T22:11Z] H box — Adjustable storage and buyable crates
- **Accepted by:** doomba  ·  **From:** #H box
- **Feature** (player002): H box — Adjustable storage and buyable crates

**Discussion:**
> doomba: Notes
igiload, impliment and test

---

---

## [DORMANT CODE — needs wiring] 29 Asylum mechanics present but unhooked — FLAGGED 2026-06-04 · RE-VERIFIED 2026-06-12 (5 now wired, 2 redundant — marked [x] below; the rest still dormant)
**Found during cruft audit.** These functions exist in source but have **0 call-sites** (nothing invokes them — no addAction / marker / NPC init / menu hook). The *logic* is written; what's missing is the **trigger wiring**. Implementing = add the hook (NPC action, map marker, scroll option, or EVH) that calls each, then test. Verify each fn's internals still match current DB schema / vars before relying on it.

### Turf wars

### Prison break

### Evidence vault
- [x] `evidenceVaultOpen` — `core/actions/fn_evidenceVaultOpen.sqf` — civ cracks the evidence vault. **WIRED** (action exists, 2026-06-12 verify).
- [ ] `lockEvidence` — `core/cop/fn_lockEvidence.sqf` — cop re-locks/secures evidence.

### Cop
- [ ] `copDeploy` — `core/cop/fn_copDeploy.sqf` — cop deployable (robbery-linked).
- [ ] `handleSwat` — `core/cop/fn_handleSwat.sqf` — MaxTac event handler (note: standalone MaxTac kept during dom strip — confirm overlap).
- [x] `serviceChopper` — `core/actions/fn_serviceChopper.sqf` — repair/rearm a chopper at a pad. **WIRED** ("Service Chopper ($1,000)" action in fn_setupActions).
- [ ] `removeWantedCharges` — `core/functions/fn_removeWantedCharges.sqf` — clear a player's wanted charges.

### Crime / economy
- [x] `sellOil` — `core/actions/fn_sellOil.sqf` — sell processed oil to a vendor. **REDUNDANT** — oilp already sells at the Oil Trader virtual shop (`fn_virt_shops` case "oil"); fn unused, don't wire.
- [ ] `civBH` — `npcs/fn_civBH.sqf` — civilian bounty-hunter vendor NPC.
- [ ] `armory` — `npcs/fn_armory.sqf` — armory weapon vendor NPC.

### Bounty
- [ ] `fetchPersistentBounties` — `core/bounty/fn_fetchPersistentBounties.sqf` — load persistent bounties from DB.

### Misc
- [ ] `earthquakeClient` — `core/functions/fn_earthquakeClient.sqf` — earthquake screen-shake FX (server triggers on clients).
- [x] `clientWireTransfer` — `core/functions/fn_clientWireTransfer.sqf` — player→player bank wire transfer. **REDUNDANT** — `dialog/function/fn_bankTransfer.sqf` already does player money transfer; fn unused.
- [x] `keyDrop` — `core/pmenu/fn_keyDrop.sqf` — drop/relinquish a vehicle key. **WIRED** (callsite verified 2026-06-12).
- [x] `pushVehicle` — `core/actions/fn_pushVehicle.sqf` — manually push a stuck vehicle (cursorTarget). **WIRED** (addAction in fn_setupActions).
- [ ] `garageLBChange` — `dialog/function/fn_garageLBChange.sqf` — garage listbox selection handler.
- [ ] `garageSpawnCfg` — `core/config/fn_garageSpawnCfg.sqf` — per-house garage spawn-point config.

**Backups:** dead-asset + dead-fn tarballs in `~/looneybin-*-backup-*.tar.gz` if any of these need restoring after the (separate) 14-helper deletion.

### Admin / util (confirmed dormant 2026-06-04)
- [ ] `sidechatMonitor` — `core/functions/fn_sidechatMonitor.sqf` — watch side-chat for spam/abuse (needs a loop/EVH to start it).
- [ ] `notifyServerRestart` — `core/functions/fn_notifyServerRestart.sqf` — warn players of imminent restart (needs a scheduler/cron hook).
- [x] `gangNewLeader` — `core/gangs/fn_gangNewLeader.sqf` — reassign gang leadership. **WIRED** — "Transfer Leadership" button (`gangMenu.hpp` class transferLeader, idc 9638), 2026-06-09.

> **Correction (2026-06-04):** `prisonBreakQuery`, `jailMe`, `initLaser`, `bountyReceive` were initially listed here but are **already LIVE** — called server-side via `AP_fnc_MP` (jail system, prison-break trigger, laser-tag, bounty payout). Removed from this list. (`wantedList` was likewise found live and never deleted.) Root cause: the first bulk dead-code scan used `cat $(find …)` which silently dropped server-side files; reliable `grep -r` re-checks caught the live callers.

> **Correction 2 (2026-06-04):** `captureTurf`, `civTurfShops`, `civTurfVehicles`, `doPrisonBreak`, `stopPrisonBreak`, `bankToggleLighthouse`, `robStoreAction`, `getCartelRubber`, `civDrugRunner` are **already LIVE** — wired through `mission.sqm` object init fields (map flags/NPCs `addAction` them). Removed from the dormant list. Root cause (again): scans never covered `mission.sqm`. The genuinely-dormant remainder below is now verified against code + `mission.sqm`.

---

## Vehicle skins — de-brand + re-add (started 2026-06-06)

All **custom** (non-base-Arma) vehicle skins were **stripped from the server** so it ships base-Arma vehicle textures only while the custom liveries get de-branded.

- **Stripped (2026-06-06):** removed **308** custom entries from `core/config/fn_vehicleTextures.sqf` (133 jpg + 157 paa [camo paths reused across many vehicles] + 18 rvmat gold/iridescence). Kept the **342** base `\A3\` entries. Backup: `fn_vehicleTextures_FULL_ORIGINAL.sqf.bak` at the project root (full original 650 entries; restore = copy it back over the config). The 155 now-orphaned texture **files** were then **deleted** from `images/` (2026-06-06, grep-r verified unreferenced incl. mission.sqm) — mission shrank 60→32 MB. Branded originals backed up: `orphaned-skins-backup-20260606-113114.tar.gz` (project root) + lossless `vehicle_skins_png/`. Re-add later = re-export de-branded PNGs into `images/<subpath>` + restore config entries.
- **Editing pipeline:** all 157 custom skins were converted to editable PNG → `vehicle_skins_png/` (jpg via ImageMagick; 7 LZO-DXT1 `.paa` via a ctypes→liblzo2 + DDS-wrap decoder). Folder mirrors `images/`.
- **De-brand tool:** `asy-strip-tool/` (own venv: torch-CPU + EasyOCR + LaMa). `strip.py detect|inpaint|fill`. First auto-pass (EasyOCR→LaMa) cleaned the asylum **text** off 28 of 157 → `asy-strip-tool/output/` (0 false positives). PaddleOCR was tried for better recall but its paddlepaddle 3.3.1 build crashes (oneDNN/PIR bug) on this box — `paddle-venv/` kept but unused.
- [ ] **Hand-`fill` the rest** — OCR misses curved/badge text (`ASYLUM POLICE` rings), vertical `ASYLUM+`, the +-cross **logos**, and the stylized skins (Honda, neon Ifrits). Paint rough masks → `strip.py fill`.
- [ ] **Re-export** finished PNGs to `.jpg` (and the 7 to `.paa`) back into `mission/.../images/<same subpath>`.
- [ ] **Re-add** the de-branded skins to `fn_vehicleTextures.sqf` (restore from `.bak`, swap branded names, OR add fresh entries). Police/med liveries are currently base-Arma until then.
- **Police carve-out — 2026-08-13 (reverses the "re-add" item above for MaxSec/MaxTac only):** the repo's OWN police skins were **deleted outright** instead of de-branded, because the retired MaxSec / "ALTIS POLICE DEPARTMENT" / LoonyBin wordmarks were baked into the art. Gone: the 11 cop vehicle liveries (`images/skins/apd|maxsec/vehicles/`), the 8 per-rank uniform `.jpg`s (`cadet…chief`), and the loose `police_uniform_*` / `police_rangemaster_*` / `police_combatu_*` / `c_combat_police_co` / `c_coveralls_police` / `mrap_03_police_co` textures, with their `fn_vehicleTextures` / `fn_clothingTextures` / `fn_clothing_cop` / `fn_copLoadout` rows. **MaxSec and MaxTac now ship the stock Arma appearance permanently** — uniforms and cop vehicles are not coming back as retextures. Medic and civ liveries are unaffected and the re-add item still stands for them.

## [ACCEPTED 2026-06-09T14:53Z] Under cover for SGT+ — Payton wants undercover to be a sgt+ perk not corperal if
- **Accepted by:** doomba  ·  **From:** #Under cover for SGT+
- **Feature** (player036): Under cover for SGT+ — Payton wants undercover to be a sgt+ perk not corperal if you can make that change <@100000000000000485> ❤️

**Discussion:**
> doomba: <@100000000000000553> keep warrant corporal+?
> player008: I was High but if I recall he is keeping warrant at CPL+
> doomba: okie
Change is staged and will apply next reboot !accept

---

## [FLAGGED 2026-06-09] Admin event system — 4 events stubbed (GunGame / Battle Royale / Graveyard / PURGE)
**From:** BUG #50 (player002, #event admin menu) — "doesn't start events when trying to use."

**State:** The admin event **menu**, the 4 **client** event fns (`eventGunGameClient` / `eventBRClient` / `eventGraveyardClient` / `eventPurgeClient`), the event/location config, and the **CfgRE whitelist** all EXIST and are wired. The 4 **server** orchestration fns are STUBS (deobf gap — no 2017 source, 7-line log-only):
- `APS_fnc_eventGunGameSRV` · `APS_fnc_eventBRSRV` · `APS_fnc_eventGraveyardSRV` · `APS_fnc_eventPurgeSRV`

So the menu "works" (validates, confirms, calls the SRV fn) but the SRV just logs and returns → **no event ever starts.**

**Build needed (per event):** server orchestration —
1. gather eligible players (opt-in / civ side),
2. set `AP_adminEvent` / `AP_inEvent` (public) — the kill-handling hook in `fn_onPlayerKilled` already keys off these,
3. teleport participants to the chosen location (event location list),
4. assign loadouts / rules per event,
5. run the event loop + win condition,
6. pay / announce winner,
7. clean up — restore players, clear `AP_adminEvent`/`AP_inEvent`, return gear.

Client fns + the gungame-kill branch in `fn_onPlayerKilled` already exist to lean on — this is the missing **server half.**

**Status:** FLAGGED — deferred 2026-06-09. Sizable (4 mini-gamemodes). Pick highest-value event(s) first when started (Gun Game has the most client support already).

---

## [BUILD LOG 2026-06-09] Stub-implementation grind — STAGED (deploy next reboot)
**Batch 1:** daily login bonus (DB lb_* cols + streak compute on connect + giveCar/claim) · drop-charge
(wantedRemoveCharge: partial/full removal + DB persist) · gang bank history (gang_bank_log table +
gangBank logging + fetch) · vehicle key registry (keyManagement: garage-pull add / chop-claim strip).
**Batch 2:** EVIDENCE LOCKUP federal event (handleTimer state machine + evidenceAppend pool from cop
seizures + evidenceTruck loot-truck payout + laptop object published at boot) · cartel-capture airdrop ·
medic revive airdrop + medDrop supply crate · MOBILE HQ server half (NPC shops + level garages +
teardown watch) · gang houses (house_pos col + persist + boot re-tag + load into gang_data slot 3) ·
HOUSE TAX (tax cols + boot tagging + 5-min playtime loop + paySingle/payAll).
**#22 LOONY BIN HEIST server half** — full orchestrator: breach → trolley gates blown → 10-min thermite
holdout → 5 laptop hacks → patient remains + keycode at the church (marker+keypad server-created) →
tomb unlock → loot, vs cop firewall reset + 5-min bury counterplay; 45-min cap + cooldown.
**#23 wiring:** restart-cycle vars (serverStartTime/CycleLength/RestartLock — were NEVER defined; fixes
dead anywhere-jail/notify + latent script-error in tax/shop menus) + notifyServerRestart scheduler +
ambient earthquakes. CORRECTION: clientWireTransfer was already live (bank.hpp) — not dormant.
**#24:** CONVOY ROBBERY (AI shipment truck from AP_convoy_start + live map marker + fence payout
80/140/225k × fence cut + watchdog) · JEWELRY EMPORIUM server state machine (alarm/drill/weld/cases +
20-min window + scene reset). **#25 ADMIN EVENTS — all 4 built:** Gun Game (join window + 15-tier winner
+ $250k), Battle Royale (last-alive monitor + prize), Graveyard (20-min round), PURGE (lawless 20 min);
AP_event_queue init fixed (was never defined). **#26:** drone battery persists (DB cols + save on
every use/flat/recharge + medic-side load push; relog no longer refills).
**Completion round:** evidence VAULT action wired (the loot-truck payoff was unreachable — new
"Breach Evidence Vault" action on the opened dome + vault reset on cop secure) · time-trial race
vehicle spawn (createTimeTrialVehSRV) · bank lighthouse sabotage (authoritative lamp hitpoints) ·
Christmas presents + Easter bunny SRVs (season-gated; xmas_last col) · AP_fnc_animSync created
(boltcutter script-error fixed) · AP_fnc_pushFunction created + "Push Vehicle" action wired.
**Dialog buttons done too:** "Drop Key" in the keychain (idc 2705 + keyDrop hardened: selection guard,
impound_obj guard, precedence-bug fix) · "Transfer Leadership" in the gang menu (idc 9638 → gangNewLeader;
keeps the gang house, unlike Transfer Ownership).
**Owner-list closeout round (2026-06-09):**
- **H BOX SOLVED + BUILT** — the mystery feature was IgiLoad's `IL_Supported_Box_H1/H2` cargo lists,
  shipped EMPTY. Filled (B_supplyCrate_F large / Land_WoodenCrate_01_F small) + two buyable market
  items ("H Box Small/Large Crate", $2.5k/$7.5k) + use-item placement (real vanilla cargo inventory,
  cleanup-spared, IgiLoad-loadable onto offroads/vans/trucks/Tempest/Mohawk/MH9). Session-only crates
  (no DB persistence) — v2 if wanted.
- **serviceChopper LIVE** — `air_sp` was never defined (fn always errored). Now resolves the Air-HQ
  helipad (AP_air_hq_poly) with fallback + a cop "Service Chopper ($1,000)" action within 60 m.
- **[PERF] steps 1+4 done** — asyncQuery's not-ready spin now yields (was starving the scheduler under
  load) + per-connect `[PERF] queryRequest took X ms` baseline metric in the RPT. Steps 2/3/5 (batch the
  load into one JOIN, read-parallelism, atomic writes) still open — measure first under real load.
- **barber/faces (#65) closed safe** — both config fns now exist as documented empty stubs (no script
  error possible); building real barber/face content = owner content decision.
- **sellOil = OBSOLETE** — processed oil already sells at every market with proper tiered pricing;
  fn_sellOil would dump all barrels at the LOWEST price. Recommend never wiring it.
- **civBH NPC = REDUNDANT** — its 3 actions are a strict subset of the live civSkiptracer NPC.
- **armory NPC = REDUNDANT** — generic cop-base bundle; every cop HQ already has copShops NPCs.
**AUDIT/AC LOGGING PIPELINE (2026-06-09, owner: "log everything for the anticheat"):** rebuilt
`fn_logIt` — the 2017 original discarded the message arg + wrote to a nonexistent table, so all ~130
existing call sites (-KILLED-, -ADMINACTION-, -GEAREXPLOIT-, -MONEYWARNING-, -HACKINFO-, -SEIZE-,
-BANKTRANSFER-, gangBank/wire/convoy money ops, AC tamper reports…) never persisted ANYTHING. Now:
universal arg parsing (all legacy shapes), sanitized, INSERT into new indexed `log` table
(ts/tag/playerid/name/message), RPT mirror as [LB-LOG]. Added hooks: -CONNECT- (with load-ms),
-DISCONNECT-, -EVIDENCE- seizures, -FED- gold, -LOONYBIN- heist milestones, -EVENT- winners, -WAC-
tamper (direct). AC queries: `SELECT * FROM log WHERE tag='-GEAREXPLOIT-' ORDER BY ts DESC` /
per-player `WHERE playerid=… ORDER BY ts DESC`. Future: loonybot `!logs <pid>` reader; insert batching
if volume contends with the DB lock.
**SHIM SWEEP (2026-06-09, BUGS.md #70):** 7 passthrough mismatches implemented (stats persistence,
stats fetch, gang-talent persistence, wanted re-registration, admin suspect query, event participants,
FULL governor backend) + mailbox. **Round 2: all 14 shims verified — 8 more implemented** (prison break, cop dispatch, jury trials,
time-trial payout, house-market listing+purchase, dirty-cash trace, restart-cycle adjust) + SRV_prisonData
init (was never defined). 2 fine as-is, 3 dead (no callers). **REMAINING BUILD: exchangeSystemSRV — the
entire player-market (Exchange) backend (6+ client modes, exchange table exists); presumed dead until built.**
**Still genuinely open:**
sellOil/civBH/armory NPC placements, H-box/igiload, vehicle-skin art, [PERF] sync rework, barber/faces
shop decision (bug #65).

## [AUDIT 2026-06-09] Missing / not-implemented features — full codebase sweep → MISSING_FEATURES.md
Full audit lives in **`MISSING_FEATURES.md`** (project root): 24 live-called server stubs (deobf gaps),
7 calls to undefined fns, 15 unverified TODO-ADAPT fns, 18 dormant client mechanics, host placeholders.
**Headliner: the Loony Bin / Mental-Hospital heist (the namesake) is client-complete but its server fn
(`APS_fnc_loonyBinSRV`) is a stub + `SRV_loonyBinData` never published → heist can never start.**
Suggested build order (from the file): 1. Loony Bin heist server half · 2. convoy robbery ·
3. evidence chain + drop-charge · 4. Mobile HQ server half (prestige tree already SELLS it — paid dud) ·
5. login bonus · 6. house tax + gang houses · 7. undefined-fn 1-liners · 8. TODO-ADAPT test pass.

---

## [ACCEPTED 2026-06-11T04:07Z] Replace electric chair with gas chamber. — when death penalty is applied by MaxSec,
- **Accepted by:** doomba  ·  **From:** #Replace electric chair with gas chamber.
- **Feature** (player002): Replace electric chair with gas chamber. — when death penalty is applied by MaxSec, swap the gay electric chair for a gas chamber. add NPC that is in the gas chamber as-well with voice line that says "i can't breathe"

**Discussion:**
> player002: Or add option to choose gas chamber or electric chair, firing squad would also be cool if we went that route. it would be truely immersive to be able to choose my death. hell lets throw in lethal injection with ebola virus
> player013: https://tenor.com/view/meer-plus-one-mulan-plus-one-meer-plus1-and-thats-a-plus1-gif-26257120
> doomba: Approved !accept
> player008: 🤣

---

## [TEASER LIVE — backend TODO 2026-06-11] 4th Faction (OPFOR/EAST) — "Coming Soon"

**Shipped now (teaser only, Beta 0.0.19):**
- 26 EAST playable slots in `mission.sqm` (group `class Item1110`, cloned from the cop group Item351):
  side East, `type="O_Soldier_F"`, names `opfor_1..opfor_26`, all `description="Coming Soon"`,
  ids 33626-33652, top Entities `items` 1110→1111. Role count 176→202. Backup: `mission.sqm.preopfor.bak`.
- Lock/whitelist: `core/init.sqf` `case east` shows "The 4th Faction is COMING SOON" then `endMission`
  (bounce to lobby). Nobody is on the whitelist, so every East pick is blocked.
- DB: `opfor_whitelist` table created, EMPTY — mirrors the cop rank structure
  (`playerid`, `name`, `opforlevel`, `opforretired` ≈ `coplevel`/`copretired`). No ranks set.
- Patch note for the drop was overridden to "teaser tee hee" (deploy/patchnote_override.txt one-shot).

**TODO to actually BUILD the faction (when greenlit):**
1. Replace the `case east` boot with a real `AP_fnc_initOpfor` (mirror fn_initCop): spawn handling,
   loadout, HUD, side init, respawn point(s), markers.
2. Whitelist enforcement: load each player's `opfor_whitelist.opforlevel` on connect (like coplevel);
   `opforlevel = 0` → still blocked; `> 0` → allowed + rank. Wire a query in the login/session flow
   (fn_queryRequest / fn_requestReceived) + a server var like AP_oplevel and `call AP_oplevel`.
3. Rank system: decide the rank ladder (mirror MaxSec's 1-7 or a custom one); admin grant path
   (extend the admin menu / bot grant like cop ranks); persistence already in the table.
4. Faction gameplay: spawn base / HQ markers, vehicle + weapon shops (clone rebel/MaxSec shop gating with
   an `opfor_*` shop family), side relations (East vs West/Civ/Indep — set via setFriend or BIS module),
   objectives/economy, whatever the design is.
5. mission.sqm: real spawn positions for the 26 slots (currently inherited the cop group's coords),
   plus a `respawn_east` marker + spawn-point cfg entry (`fn_spawnPointCfg`).
6. CfgRespawnInventory / loadouts for East; description.ext respawn templates if needed.
7. Re-check `disableChannels` / side voice + the role-count vs maxPlayers Header (bump maxPlayers or
   accept the benign warning).

**Files touched for the teaser:** mission.sqm (Item1110 group + items count), core/init.sqf (case east),
DB `opfor_whitelist`, deploy/gen_patchnotes.py (override path), deploy/patchnote_override.txt (consumed).

## [HOUSING] Show keyed houses (friends' houses you hold keys to) on the map — FLAGGED
**Source:** BUGS.md #329 (player095, 2026-06-17) — "unable to see houses that we do not own but have keys to; we used to be able to see friends' houses with keys on old Asylum." Deferred from bug → feature (owner call 2026-06-17).

**Requirement:** a player should see a map marker for every house they hold a KEY to but don't own (like old Asylum), distinct from owned houses (e.g. cyan vs the blue owned / green gang markers).

**Why it's a feature, not a quick fix:** the client currently has **zero keyed-house data**. `AP_houses` (the only house list a client gets, `fn_requestReceived.sqf:206` `= _this select 27`) is OWNED houses only; `fn_CLinitHouses.sqf` markers only those. The server knows keyholders (`houses.keyholders` + the `AP_house_keys`/`-HOUSEKEY-` trail), but never sends a player their keyed-house list.

**Build sketch:**
1. Server: on the house-init/session path, compute each online player's keyed houses (`houses` rows where the player UID ∈ `keyholders` but ∉ `owners`) and push `[oid, worldspace]` pairs to that client (new `AP_fnc_receiveKeyedHouses` or piggyback the existing house payload).
2. Client: store in a `AP_keyedHouses` list; in `fn_CLinitHouses` (or a sibling) draw a distinct-color marker per keyed house. Refresh on key grant/revoke (`-HOUSEKEY-` events already exist).
3. Keep it in sync when keys change hands (grant → add marker; revoke → remove).

**Files:** `fn_CLinitHouses.sqf`, `fn_requestReceived.sqf`/house-receive path, a new server keyed-house query, key grant/revoke handlers.

## [ECONOMY] Time-based barrel aging for spirits (scotch/whiskey/rum) — FLAGGED
**Source:** BUGS.md #325 (player019, 2026-06-17) — "scotch does not age." Owner decision 2026-06-17: switch the aging model from per-restart to **real-time, 6 HOURS per stage**. Race-fix shipped as a stopgap (ages per-restart); this is the proper version.

**Requirement:** scotch_0→scotch_1→scotch_2 (and whiskeyc_*/whiskeyr_*/rum_* equivalents) age by **elapsed real time, 6h per stage**, restart-proof — like the weed greenhouse (`APS_fnc_greenhouseSRV`). Barrel caps at stage 2 (15-Year); scotch_2→scotch_3 stays the aging-chemicals processor step.

**Why it's a feature, not a quick fix — the blocker:** the aging barrel is a **legacy `storage`-table container** (`fn_addStorage`/`fn_queryStorage`/`DB_fnc_updateStorage`) that stores its contents in a **`Trunk`** object variable, while the modern house storage + UI (`fn_openInventory`/`fn_storeInventory`) read **`AP_vinv`** on the house row (`APS_fnc_updateHouseTrunk` → `houses.vinv`). Two coexisting storage models. Aging the wrong structure (or mis-threading persistence) risks breaking house storage server-wide. **MUST be verified on a live server** (can't run SQF offline).

**Open questions to resolve live FIRST:**
1. At runtime, does a `Land_WaterBarrel_F` container's content live in `Trunk`, `AP_vinv`, or both? How does opening it bridge to `AP_vinv` (the UI reads `AP_vinv`)? Confirm before touching either.
2. Where is the per-container clock stored? Cleanest = a new `houses.barrel_aged_at INT` column (one aging barrel per house, since `AP_barrel_unaged`/the upgrade is house-level), set/read greenhouse-style; persist contents via the existing `lootModified` → `DB_fnc_updateStorage`.

**Build sketch (greenhouse-mirrored):**
1. `houses.barrel_aged_at` column. New `APS_fnc_barrelSRV` (reload + a ~30min aging tick + boot catch-up): for each house with an aging barrel, find its `Land_WaterBarrel_F`, read its contents, advance `floor((nowUnix - aged_at)/21600)` stages (capped), write contents + `lootModified=true`, bump `aged_at`. `nowUnix = AP_bootUnix + serverTime` (the proven restart-proof clock).
2. Set `aged_at = now` when spirits first enter an empty barrel (or lazily: tick sets it when it sees agers + `aged_at=0`).
3. Remove the per-restart aging block from `fn_addStorage` once the tick is proven.

**Files:** `houses` schema, new `APS_fnc_barrelSRV.sqf` + config.cpp registration, `init.sqf` (reload + tick), `fn_addStorage.sqf` (drop the per-restart block). Verify against `fn_openInventory`/`DB_fnc_updateStorage`.

## [VEHICLES] Gang vehicles RESPAWN-AT-POSITION across restart — FLAGGED (follow-up to #335)
**Source:** BUGS.md #335. Owner wants OUT gang vehicles to respawn at their last WORLD POSITION at restart, like personal vehicles. **Shipped the safe garage-return instead (2026-06-18, b0073)** — respawn needs 3 coordinated changes to the FRAGILE `vehicle_mem` path (6 prior extDB3 bugs), **untestable offline** (needs a live restart with a pulled gang vehicle; a restore bug DELETES cars via the spawn-collision path).

**What respawn needs:**
1. **Save side** (`fn_saveVehicles`): saves `vehicles` rows that have `dbInfo` — but a pulled gang vehicle only gets `AP_dbInfo` (`fn_gangGaragePull:188` = `[str gangID, plate, true]`), never `dbInfo`, so it's skipped. Set `dbInfo` on the gang pull, or fall back to `AP_dbInfo` in saveVehicles.
2. **Restore side** (`fn_restoreVehicles:49`): relinks each `vehicle_mem` plate ONLY against the personal `vehicles` table (`srv_table_vehicles`) — gang plates live in `gang_vehicles`, so they fail the `if !(_vInfo isEqualTo [])` gate and never respawn. Add a `gang_vehicles` lookup branch.
3. **Gang-key relink**: a restored gang vehicle must be accessible to gang members. Personal access keys off `AP_dbInfo[0]==uid` (`fn_queryRequest`); gang access is by gang id — replicate the normal pull so members get keys + trunk access.
4. Remove the boot `garage-return` (`UPDATE gang_vehicles SET active='0'` in init.sqf) when respawn is on. KEEP the dedupe + UNIQUE key + store/add upsert (correct either way).

Test on a dev instance: pull a gang vehicle, drive it out, hard-restart, confirm it respawns at position with the gang still able to access + store it.

## [ACCEPTED 2026-06-19T02:00Z] Underwater shipwreck events — The old loot pool was gold nuggets treasure maps c
- **Accepted by:** doomba  ·  **From:** #Underwater shipwreck events
- **Feature** (player049): Underwater shipwreck events — The old loot pool was gold nuggets treasure maps cut diamonds and dubloons

---

## [ACCEPTED 2026-06-19T02:01Z] Increase sell price of human organs — $3,300 for one organ is basically nothing.
- **Accepted by:** doomba  ·  **From:** #Increase sell price of human organs
- **Feature** (player013): Increase sell price of human organs — $3,300 for one organ is basically nothing. Bump it up to 10k or 15k.

**Discussion:**
> player002: make it so you can take both organs, and they have 30 minutes to get a transplant or bleed out
> player002: make a small chance they die from removing both too
> player025: I’m gonna harvest your ass and sell it for 5 mil on the black market
> player053: +1
> player041: after everything gets tested hopefully the economy will be reset. starting with 500k is wild. maybe a 40k start would be good for economy.
> player069: Honestly I love this idea haha
> player069: I can just imagine a kamala rat come out of the God damn sewers and take my spleen lol
> player019: Economy seriously needs a reset, 500k is absolutly bonkers to start people out at. No reason why I should just log on for the first time and buy 3 houses and still have money leftover for other stuff. Houses should be an end goal not the starting point
> player002: It’s 2026 dude
> player002: Everyone lost everything on asylum.
> player002: 10+ years of hard work. Some people like myself checked the same houses for 12+ months just to get one
> player002: 500k is nothing compared to that loss
> player002: 99% of our player base is asylum. We owe it to them to make up for that loss in whatever way we can.
> player002: That’s why we are here
> player002: Also Ethan, you do a hella lot of crying 😭

---

## [ACCEPTED 2026-06-19T02:01Z] Get rid of the spawning with a burger and 2x soda — Takes up valuable inventory 
- **Accepted by:** doomba  ·  **From:** #Get rid of the spawning with a burger and 2x soda
- **Feature** (player047): Get rid of the spawning with a burger and 2x soda — Takes up valuable inventory space

**Discussion:**
> player013: Facts make it redgull
> player013: The soda sucks
> player058: Nah just make it nothing
> player058: Some brokee will farm new spawns for redgulls
> player013: Lmao
> player038: sounds like soemthing a rabbi would do
> player058: TRUE, or George Floyd
> player002: +1

---

## [ACCEPTED 2026-06-19T02:02Z] Player Owned Gas Stations — Bring back that old asylum function, after each rest
- **Accepted by:** doomba  ·  **From:** #Player Owned Gas Stations
- **Feature** (player063): Player Owned Gas Stations — Bring back that old asylum function, after each restart you could run to a gas station that you could rent , and it would generate passive income. they had safes that could be robbed while generating the cash that players could rob if you weren't vigilant, preventing AFK farming. it only alerted the owner though, i believe, so the owner would have to call the cops.

Player who owned the gas station would have to go and collect their cash before the server restarted because it was reset each restart so you'd lose the cash if you didn't grab it.

Yes the gas stations also still had ATMs in them for secure deposit that couldn't be ratted/camped.

**Discussion:**
> player053: +1
> player047: +1
> player002: Great idea

---

## [ACCEPTED 2026-06-19T02:02Z] Add back mineing talents — talent for more rocks and sand. 
- **Accepted by:** doomba  ·  **From:** #Add back mineing talents
- **Feature** (player049): Add back mineing talents — talent for more rocks and sand. 
Talent for more gems
talent for more buried treasure.

And all talents have an increased yeild for those specialities ^

**Discussion:**
> player071: you auto have all talents
> player071: if you didn't know
> player082: not all talents are created equal
> doomba: Going to replace this with different tier pickaxes

---

## [ACCEPTED 2026-06-19T02:03Z] Make Wooden Shacks a 1c buyable house — 20k 1c. These offer some decent spawn po
- **Accepted by:** doomba  ·  **From:** #Make Wooden Shacks a 1c buyable house
- **Feature** (player047): Make Wooden Shacks a 1c buyable house — 20k 1c. These offer some decent spawn points and storage options.

**Discussion:**
> player098: Trying to imitate your house irl?
> player058: Nahhh thats a 1/2C at best
> player047: 1c storage is fine

---

## [ACCEPTED 2026-06-19T02:06Z] Can we please add Gang Tag — Its hard to know how is how red means dead but stil
- **Accepted by:** doomba  ·  **From:** #Can we please add Gang Tag
- **Feature** (player015): Can we please add Gang Tag — Its hard to know how is how red means dead but still

**Discussion:**
> player001: I agree
> player041: Gang Tag would be cool

---

## [ACCEPTED 2026-06-19T02:06Z] Make sprint unlimited OR perk-unlockable — Managing sprint in a roleplaying serv
- **Accepted by:** doomba  ·  **From:** #Make sprint unlimited OR perk-unlockable
- **Feature** (player014): Make sprint unlimited OR perk-unlockable — Managing sprint in a roleplaying server can get kinda annoying

**Discussion:**
> player002: Honestly I was saying the same fucking thing the other day
> player002: Having to buy energy drinks, is a retarded game play loop to just be able to move around
> player002: A tarkov style sprint skill would be way cooler
> player002: And leave red gull in, so if the skill is low you still aren’t handicapped
> player053: +1
> player053: Always hated Stam
> player098: +1
> player040: +1
> player069: +1
> player041: +1 stam is gay - also I am overweight

---

## [ACCEPTED 2026-06-19T02:08Z] Add LVL 4 VEST TO BM FACTORY — No real point to make lvl 1 vests...
- **Accepted by:** doomba  ·  **From:** #Add LVL 4 VEST TO BM FACTORY
- **Feature** (player053): Add LVL 4 VEST TO BM FACTORY — No real point to make lvl 1 vests...

---

## [ACCEPTED 2026-06-19T02:08Z] Add Body Bags for CL — Add bags to turn in when someone combat logs
- **Accepted by:** doomba  ·  **From:** #Add Body Bags for CL
- **Feature** (player039): Add Body Bags for CL — Add bags to turn in when someone combat logs

**Discussion:**
> player055: BUMP
> player040: Approved pushed to <@100000000000000485>
> player002: +1

---

## [ACCEPTED 2026-06-19T02:10Z] Make the mobile HQ a blackfish VTOL — Faster to deploy can also be used to move 
- **Accepted by:** doomba  ·  **From:** #Make the mobile HQ a blackfish VTOL
- **Feature** (doomba): Make the mobile HQ a blackfish VTOL — Faster to deploy can also be used to move a LOT of officers to the location via airdrop then land away and deploy mobile HQ functionality for respawns

**Discussion:**
> player050: So would there be two different mobile hqs? One ground Hemmtt and then an air vtol? 
I’m a little worried about the tuning/balancing factor if the rebels aren’t tuned up as well
> doomba: rebels want titan launchers 
I've seen that work on other life servers but the cops had the blackfish
> doomba: It could be 2
> player050: If rebels have titans then yea I think a vtol could be the fast transport option they’ve always been asking for lol.
So for asy we had 
Mobile HQ for SGT+
Could do blackfish for LT+?

I think the vtol itself should be policy based, but that’s for a different time lol
> doomba: right thats along the lines of what I've been thinking

---

## [ACCEPTED 2026-06-20T02:08Z] Add person identification by using binoculars on them — .
- **Accepted by:** doomba  ·  **From:** #Add person identification by using binoculars on them
- **Feature** (player053): Add person identification by using binoculars on them — .

**Discussion:**
> player031: he wants to be able to see names with rangefinders or binocs when zooming in
> player031: olympus does have it
> player031: +1 <@100000000000000485>
> player041: +1

---

## [ACCEPTED 2026-06-21T15:20Z] Make Transferring Items easier — For example: If I have 20 storage left in my va
- **Accepted by:** doomba  ·  **From:** #Make Transferring Items easier
- **Feature** (player055): Make Transferring Items easier — For example: If I have 20 storage left in my van and I wanna put the rest of my coke in there. Let us double tap the coke and put as much as we can to fill the rest of storage. The current system is set up to where if you try to double tap whatever you have in your inventory, and its over storage capacity, it wont allow to transfer anything over. We currently have to type out the amount and then transfer.

**Discussion:**
> player055: bump
> player047: +1

---

## [ACCEPTED 2026-06-23T19:47Z] Add Malden as an alternative map — The majority of us are here from asy/oly. Bot
- **Accepted by:** doomba  ·  **From:** #Add Malden as an alternative map
- **Feature** (player047): Add Malden as an alternative map — The majority of us are here from asy/oly. Both of which have had altis as the main map for a decade. I whole heartedly believe that considering the size of this community Malden would be a great option to try out. It also would draw more attention of the remaining other life servers as a new and refreshed map. If it fails then just reload where the altis database left off.

**Discussion:**
> player019: <@100000000000000519> And I were talking about this the other day. Would be a huge undertaking to make a new map from the ground up but I think it would be a hit if it could be done
> player019: Another option would be if somebody could find the Asylum Tanoa file
> player047: It’s already made bro lol
> player019: Fr!?
> player047: Yes <@100000000000000556> and <@100000000000000806>  made one for asylum
> player019: Was it ever playable to the public?
> player047: No the asy owners squashed it and the community died
> player019: Sounds about right
> player047: It needs some framework
> player047: But I’m sure it could get pushed out in a couple of weeks
> player013: I really do think a smaller map like Malden is what arma life needs in 2026. You can get away with low pop on a smaller map. Altis just feels dead unless you have 70+ people online
> player045: https://tenor.com/view/lmfao-unfunny-gif-23865640
> player097: The map is done, ( 90% ) there’s just no code one it
> player043: Malden is such a throwback
> player043: Tanoa so dead

---
