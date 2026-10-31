# LooneyBin — Stub Repair TODO

Working checklist for the stub/missing-feature grind. Full inventory: `STUBS.md`. Anti-cheat (WAC): `CLANKR.md`.
Status: `[ ]` todo · `[x]` done · `[~]` verified-OK (no change) · `[-]` deferred (needs design/schema).

## Done
- [x] **gangBank** — router (modes 0/1/2/4) + client receive, balance-gated, atomic (2026-06-06)
- [x] **handleWireTransfer** — credit the receiver (was a money-loss bug; sender debited, receiver never paid) (2026-06-07)
- [x] **wacClient** — clean gear scan + record tamper report (see CLANKR) (2026-06-07)
- [x] **vehicleRepairSRV** — garage repair now zeroes stored damage in DB (was a no-op) (2026-06-07)
- [x] **cartelSRV** — killed the loop-accumulation + double-capture bug; restored the cartel TAX payout to the controlling gang's bank (2026-06-07)
- [x] **duelArenaSystemSRV** — implemented match start (teleport both into the arena); scoring + payout + refunds already client-wired. ⚠️ NEEDS in-game test (2026-06-07)
- [x] **medicSplit** — assisting medics now get their revive-reward share (server-authoritative bank credit) (2026-06-07)
- [x] **adminDelVeh** — admin despawn vehicle, non-destructive (owned → returns to garage via active=0) (2026-06-07)
- [x] **enableCoPilot** — heli pilot dies → a living passenger is promoted to the controls (2026-06-07)
- [x] **transferGangOwnerSRV** — gang ownership transfer (swap gangrank0: new→1, old→2, persisted) (2026-06-07)
- [x] **setGangTagSRV** — gang tag now sets network-wide so everyone sees it (session-live; DB persist needs a column) (2026-06-07)

## Tier 1 — money/persistence passthroughs
- [~] **statTableUpdate** (→update) — REDUNDANT: stats persist via `ClupdatePartial[9]` (stats blob). Broken passthrough loses nothing live.
- [~] **bulkAdd** (→addQueue) — REDUNDANT: crimes persist via `ClupdatePartial[8]` (crimes blob). Same.
- [-] **updateVehicleMods** (→updateVehicle) — vehicle mods never persist; needs a `mods` column (schema) → DEFER
- [-] **varPersist** (→update) — ga_banktrace/drugtrace/choptrace anti-exploit cooldowns; needs columns/blob → DEFER. Real (relog resets cooldowns) but low-pri.

## Tier 2 — ownership / admin / data (MED)
- [x] **adminDelVeh** — DONE (despawn + return-to-garage)
- [ ] **transferHouse** (→setOwnerID) — house buy-from-player; setOwnerID only sets a netvar (no DB)
- [x] **transferGangOwnerSRV** — DONE (gangrank0 swap, persisted)
- [ ] **getID** (→setOwnerID) — verify call site / intent
- [ ] **updateHousePrice** (→updateHouse)
- [x] **setGangTagSRV** — DONE (session-live network set; DB persist needs a column → deferred)
- [ ] **updateGangMem** (→gangMember) — gang member DB row
- [ ] **update1GangTalents** (→setGangTalents)
- [ ] **adminPlayerQuerySRV** (→getAdmin) — admin ESP/suspect query
- [ ] **checkPlayer** (→getGuid)
- [ ] **getStatsArr** (→query)
- [x] **cartelSRV** — DONE (see Done): loop bug fixed + cartel tax payout restored
- [ ] **exchangeSystemSRV** (→reduceMarket) — market price decay on sells
- [ ] **srvObjectMonitor** (→addObjectWhitelist) — crankSmoke object whitelist
- [ ] **spawnPhysicalItem** (→placeStorage)
- [ ] **eventParticipants** (→addToEvent)
- [ ] **timeTrialSRV** (→finishRace)

## Tier 3 — VERIFY passthroughs (args checked = aligned to targets; confirm in-game, rewrite only if they misbehave)
- [~] bankRobbery · fedRobbery · srvRobStore · huntingGrounds · handlePrisonBreak — args aligned
- [~] trialSystemSRV · handleDispatch · registerMaxTac · srvSpikeStrip · srvChopShopSell — args aligned
- [~] changeWeather · govSystemSRV · processMailbox · add2Lotto · changeServCycle — args aligned

## Tier 4 — DEAD features (implement; bigger, lower priority)
- [x] **duelArenaSystemSRV** DONE (needs in-game test) · [ ] still dead: eventBRSRV, eventGunGameSRV, eventPurgeSRV, eventGraveyardSRV
- [ ] Heists: loonyBinSRV (signature), jewelryEmporiumSRV, convoyRobbery + endConvoyRobbery
- [ ] Racing: createTimeTrialVehSRV
- [ ] Gang houses: addGangHouse, changeGangHouseSRV, removeGangHouseSRV, gangBHistory
- [x] **medicSplit** + **enableCoPilot** DONE · [ ] still dead: airDrop, airDropMedic, medSupplySpawn
- [ ] Cop: evidenceTruck, evidenceAppend, srvMobileHQ
- [ ] Econ/misc: loginBonusSRV, houseTaxSRV, wantedRemoveCharge, handleTimer, discordEmbed, doBuySkin (skins stripped)
- [ ] Seasonal: easterSeasonalEvent, xmasTreeAndPresentsSRV · bankLightHouseToggle

## `gang1` column bug (this DB only has gang0) — same class as the gang-bank root
- [x] **fn_queryGangs** — boot gang-cache loader counted `gang1` → query threw → cache empty → ALL gang ops broke (gang bank, cartel tax, etc.). Fixed → gang0 (2026-06-07)
- [ ] **fn_update.sqf:70** — full-player-save field map uses `gang%instance`/`gangrank%instance` (= gang1) → the whole buffered UPDATE errors → that save path is a silent no-op (ClupdatePartial covers persistence, so no data loss). Fixing RE-ENABLES a dormant save path → needs care/testing before flipping.
- [ ] **fn_receiveHouses.sqf:85** — `UPDATE players SET gang%instance WHERE gang%instance` (gang id remap) → dormant/failing. Same re-enable caution.

## Mission-side silent no-ops (38)
- [ ] Triage which are actually live-referenced vs dead legacy duplicates (court/dispatch/MaxTac/wanted clusters). Most are harmless reverse-drift shims.

## mentalasylum13 — DONE 2026-08-01: replaced and removed
The custom p3d is gone: the owner rebuilt the site around a vanilla `Land_Hotel_02_F` (the same
building the Altis heist laptops live in) placed via the map pipeline, plus a dressed compound
(~324 mapData rows: plaza, walls, ruins ring, coffins, portable servers, blood pools). Old
`createSimpleObject` line and all four asylum p3ds removed from the mission (~31 MB PBO saved,
b0207). Native engine collision everywhere — the whole custom-collision problem class is gone.
The saga's reusable outputs: `debug/walltest.sqf` (AI-shove character-collision probe),
`debug/hc_rayprobe.sqf` (ray probe), and the engine lessons in `p3dmemories.md` §4. The Altis
heist's building/tomb/keypad classes for the Malden port: `Land_Hotel_02_F` /
`Land_OrthodoxChurch_03_F` (loot inside) / `Land_Tablet_01_F` keypad / `Land_Bomb_Trolley_01_F`
gate prop.

## Air defences: the cop repair (owner 2026-07-27, NOT built)

Blowing the radar tower drops the island's anti-air (`APS_fnc_fedRadarSRV`). Bringing it back is
owed, and deliberately not written yet because it depends on something that does not exist:

- MaxSec repair the tower **on site**, and it only becomes available **10 minutes after the last
  federal event resolves**.
- None of Malden's federal events are wired yet (`fn_activeFederalEvent` still reads Altis state:
  fed, bank, evidence, prison, convoy, loonybin, jewelry). So there is no "last fed event resolved"
  timestamp to count from.

Until it exists: **a blown tower stays blown for the session**, and a server restart is the only
thing that puts the umbrella back (SRV_fedRadar is not persisted).

When the feds are wired, this needs: a resolve-time stamp on the federal event state, a cop-side
scroll action at the tower gated on `serverTime - _lastFedResolve > 600`, a repair progress bar,
`AP_fedAirDefense = true` + publicVariable, `[true] call AP_fnc_fedRadarMarkers`, and the tower
object restored (`setDamage 0` will not revive a destroyed terrain object -- it may need hiding the
wreck and spawning a replacement prop).

## Malden Federal Reserve (built 2026-07-27, see maldenfed.md)

- **Lengthen the HIGH SECURITY lockout.** It is 300 s in `APS_fnc_maldenFedSRV` case `"reset"`, chosen
  so testing does not spend its life waiting. Owner's call on the real number once the heist has been
  played through a few times.
- **Restore the cop requirement.** `fn_fedAlarm`'s tenured-cop gate is `< 0` for Malden testing; the
  public-launch value is `< 6` and is in the comment beside it.
- **Restore the bank's cop requirement.** `fn_bankDrillVault`'s tenured-cop gate is `< 0` for Malden
  testing; the public-launch value is `< 4` and is in the comment beside it.
- **MaxTac has no Malden spawn table.** `AP_fnc_maxtacDispatch` switches on `worldName` and only carries
  Altis and Australia, so the Reserve never calls MaxTac here.

## Jewelry Emporium (Malden, built 2026-07-28, see maldenjewelry.md)

- **14 dead display cases, off Malden's terrain.** Fourteen `Coffin_02_F` rows in
  `core/config/fn_mapData.sqf` still carry the original map's coordinates (`~[20695-20710,
  16625-16639]`, ~14.5 km from the Malden site, verified: none of the 14 carry `_xIsServer`) instead
  of being removed or relocated. They resolve to nothing a player can reach on this map -- dead props,
  not a bug -- and the owner has not decided whether to strip them or leave them as harmless map-data
  cruft.
- **`SRV_lastRobbery`, the 15-minute cross-heist cooldown, is unmirrored server-side for this heist.**
  `APS_fnc_jewelryEmporiumSRV` case `"robberyStarted"` never reads it -- only the client action
  (`fn_jewelryEmporium.sqf` case `"startDrill"`) does -- so a modified client could skip the wait
  entirely. Same vulnerability class as the 30-minute own-re-breach cooldown (slot 0), which *was*
  mirrored server-side in this branch's 2026-07-28 audit. Left alone here because the variable is
  shared cross-heist state (bank, convoy, prison break, Loony Bin all read it) and a jewelry-only mirror
  risks drifting out of step with the others. Closing it means either mirroring it in every heist's
  server half, or moving the check into one shared gate function all of them call.
- **`fn_jewelryEmporium.sqf`'s `clientInit` torch loop keys on state slot 4.** Slot 4 (`casesLootable`)
  now means "the event is live" for the whole run, not "the safe is being cut" the way the slot name
  once implied. Currently harmless: the loop's real gate is the adjacent
  `nearestObjects [..., ["Land_ButaneTorch_F"], 3]` proximity test, which only passes standing at the
  safe. Pre-existing, not introduced by this branch's changes; noted because the slot's meaning shifted
  under it when the #304 order fix landed.
- **"Break Jewel Case" offers before the drill completes.** The scroll condition in
  `fn_setupActions.sqf` (the class-and-polygon test) does not check `SRV_jewelryEmporiumSRV` slot 4;
  the option is visible on any unlooted case from the moment the emporium loads. `fn_jewelryEmporium.sqf`
  case `"breakGlassCase"` then refuses with "You can't open this until the drilling has completed!"
  Judged intentional -- it matches the existing crowbar-possession guard, which is offered the same way
  and refused the same way. Closing it means adding the slot-4 check to the scroll condition too, at the
  cost of one more place that can drift out of step with the handler.
- **`lockInventory` on the promoted display cases is unverified on clients.** Added so the eight
  server-side cases (real `Coffin_01_base_F` containers: `maximumLoad = 4000`,
  `transportMaxMagazines = 100`) can't be used as a free gear stash. BIKI documents the command as
  `eff = local`, so the honest claim is belt-and-braces on the server's own copy; whether it actually
  locks the container for clients has not been checked against a live server. The freeze
  (`enableSimulationGlobal false`) is the load-bearing half either way. Closing it needs an in-game
  test: stand at a case and try to place an item in it.
- **`AP_jewerlySafe` is never published; clients bind it once and never rebind.** The server publishes
  `AP_jewelSafe`, not `AP_jewerlySafe` itself; each client derives its local copy exactly once, in
  `initPlayerLocal.sqf`, from whatever `AP_jewelSafe` holds at that moment (`objNull` if the publish
  hasn't landed yet). Unlike the drill gate, which re-reads
  `missionNamespace getVariable ["AP_jewelGate", objNull]` live at menu-build time, the "Laser Cut
  Safe" scroll condition in `fn_setupActions.sqf` tests the frozen local copy directly -- so a client
  that loses the mission-start publish race has a dead safe option for the rest of the session, with
  nothing to warn it or self-heal it. Closing it means switching that condition (and the `weldSafe` /
  `takeSafeContents` handlers, which read the same local copy) to the live-guarded-read idiom the gate
  already uses.
- **Cop requirement is whatever `SRV_jewelryEmporiumSRV` slot 6 holds, floored at 1.**
  `server/AP_server/init.sqf` seeds it at `6` (the inherited Altis default); the 2026-07-03 `max 1`
  floor exists only to protect against beta data holding `0`, not to deliberately relax it for testing
  the way `fn_fedAlarm` (`< 0`, public-launch value `6`) and `fn_bankDrillVault` (`< 0`, public-launch
  value `4`) do in their own comments above. No comment anywhere on this branch records an
  owner-confirmed production number for the jewelry heist specifically. `6` is the value actually in
  effect today; owner's call on the real number once the heist has been played through a few times.
- **`tools/sqf_balance.py` still has known blind spots** (its own trailing comment block, not hit by
  any file in this feature): a condition built from a non-literal operand (`"..." + _var + "..."`) is
  skipped because its content isn't statically knowable; a code-bearing string with no SQF "tell" (no
  hard keyword, fewer than two soft ones) reads as prose and is not checked; a bracket inside nested
  display text (e.g. inside a `hint` string) is deliberately out of scope; and it only ever sees
  `.sqf` -- `.hpp`, `description.ext` and `config.cpp` are never passed to it.

---

## 2026-07-28 -- opened by the A1030 parity pass, deliberately not actioned

These came out of comparing the Malden build against the A1030 Altis reference and out of the
reviews that followed. None is jewelry-specific except the first two; all are owner decisions.

### Map data and the designer pipeline

- **`mapImportAll_data.sqf` will silently revert the lamp fix.** It is a git-tracked, byte-for-byte
  mirror of the map data as it stood BEFORE commit `042ce3b`, still carrying 144
  `_this allowDamage true;` lamp rows, and `mapImportAll.sqf` reads it. The next designer map
  round-trip re-imports the old flags and undoes the fix. Closing it means re-running
  `python3 tools/mapdata_all.py extract` and committing the regenerated mirror, which is a
  designer-facing artefact -- hence not done unilaterally.
- **216 lamp rows may not be emitting light at all.** They carry an EMPTY init string, so on every
  client `AP_fnc_createVehicleLocal` builds them with `createSimpleObject`, and BIKI's
  `createSimpleObject` page lists built-in lights among the features that do not work on simple
  objects. Giving them `_this enableSimulation true; _this allowDamage false;` would route them
  through the normal spawner instead. That is a visible night-time change across the whole map, so
  it wants an in-game look before and after rather than a blind edit. The same question applies to
  196 building rows with empty inits.
- **The blackout event may reach nothing.** `fn_eventBlackoutSRV.sqf:4` asserts that `switchLight
  "OFF"` is a global effect; BIKI documents `switchLight` as `eff = local`. Combined with 132 of the
  144 mission-placed lamps being `isServer = false` client-local objects, a server-side `switchLight`
  sweep may darken nothing on a connected client. Test in game before anyone tunes its radius or
  reports it broken; if confirmed, the fix is to broadcast the switch to clients.
- **One floodlight still contradicts the lights rule.** `Land_FloodLight_F` at
  `[24972.500, 16747.699, 87.803]` carries `enableSimulation false`. It is at an Altis coordinate,
  ~24.9 km out on a 12.8 km map, so it never spawns and the row is dead either way.
- **The African Warlord stands alone in a field.** The fence was moved to the owner's chosen spot at
  `[8546.79, 7674.1, 0.54]`, but the scenery he was standing in stayed on the Altis coordinate --
  six rows within 31 m of his old position, including a `Land_Cargo_House_V2_F` 3.4 m away, an
  abandoned boat, a patrol tower and HBarrier walls. There is no authored scenery within 400 m of
  the new site. Moving those rows too would make the site read as intentional.
- **The restored 1000 m no-mobile-HQ ring covers two other sites.** Cocaine Field at 423 m and the
  Lumber Mill at 786 m; cops can no longer deploy an HQ at either. Reported rather than silently
  shrinking the radius.
- **`fn_dynamicMapCfg.sqf:4` forces the Altis zone table whenever `AP_serverId == 1`** (the default),
  so Malden's own zone table is dead code map-wide. This governs what streams in near players, so it
  is bigger than any one feature.

### Content the reference has and Malden does not

- **The Hope Diamond is gone.** `jewelHope` is still configured at 108000 -- the heist's jackpot item
  and its only variance -- but nothing spawns it any more. Roughly one `setVariable` in the server
  trophy spawn plus ~10 lines restoring the client branch.
- **The getaway Qilin's trunk has no geofence**, so the haul no longer has to travel; on the
  reference it did. Small once a fence position exists.
- **Cops lost all three emporium security cameras.** Four coordinates: three registry rows plus the
  shared range anchor.
- **`jewelBag` is priced at 17500 pending a balance pass.** Owner picked the figure with the
  arithmetic in front of him -- about 23 bags a run, so roughly $402,500, which likely exceeds a Fed
  run. Recorded as a deliberate decision, not a settled number.

### Security and logging

- **`-SEC-` rows crediting a client-supplied player object are a PATTERN, not incidents.** Three were
  found and fixed today -- jewelry `weldSafe` (`f41e47c`), the Loony Bin breach (`a761d6e`), the shed
  helipad (`543b2d6`) -- each logging a name taken straight from the remoteExec payload into the
  table CLANKR's auto-ban rules query, so a modified client could manufacture evidence against an
  innocent player. A repo-wide census taken afterwards puts the total at 107 rows across 78 files,
  with the remainder caller-derived. Worth a standing rule: a `-SEC-` subject must come from
  `remoteExecutedOwner`, never from the payload, and server faults log `objNull`.
- [x] **server-side event handler renamed to remove foreign branding** — `fn_eventGridrunnerSRV.sqf` was renamed from carrying a foreign server's brand name in the filename, touching `config.cpp` registration and all call sites (2026-08-21)
- **The mobile-HQ deploy exclusion has no server-side counterpart.** `fn_srvMobileHQ.sqf` validates
  nothing about position, so the whole exclusion list is honour-system against a modified client.
- **Four dead marker names remain in `fn_clientMobileHQ.sqf`'s gang ring** -- `gang_fortress_marker`,
  `turf_area_panagia_flag`, `turf_area_rodo_flag`, `turf_area_zaros_flag`. None exists on Malden, so
  each tests against `[0,0,0]`. `illegal_warlord` was the fifth and now has a real marker.
- **`gang_fortress_flag` is never assigned anywhere in the tree** but is read in ~14 client files,
  including a `waitUntil` in `fn_initGangFortClient.sqf:35` that throws every 15 seconds on a live
  client. The gang fortress system is effectively unwired on this map.

### The statistics and titles table -- its own job, not a side task

The audit is written up in full at `.superpowers/sdd/title-index-audit.md` (209 rows). Headlines:

- **Player stats are being corrupted right now.** `AP_fnc_addStatistic` takes a raw slot index and
  its three callers pass OLD-layout numbers: capturing turf or a cartel increments **Successful
  Lockpicks**, and claiming a bounty increments **Suicide Vests**, while `turfscaptured` and
  `cartelscaptured` stay at zero.
- **Titles are granting for the wrong deeds.** "Open N Fed safes" fires on cartel captures;
  "Capture 35 turfs" on RPG vehicle hits; "Capture 75 cartels" on downing cops; "Detonated N remote
  explosives" on governor pardons.
- **The index drift is not a constant shift** -- it is a five-band staircase (`+0/+2/+4/+6/+7/+8/+9`)
  and the first mismatch is at old index 18, not in the 90s as first assumed.
- **There are THREE copies of the stat layout.** `fn_statArrUpdate.sqf` (the writer) and
  `website/src/lib/leaderboards.ts` are on the NEW layout, so the DB and the site agree.
  `fn_titleCfg.sqf` AND `dialog/function/fn_statsFilter.sqf` are both on the OLD one -- fixing titles
  alone would leave "My Stats" labelling iron ore as "Donuts Eaten".
- **27 stat slots are defined but incremented by nothing**, so ~60 titles would still be unearnable
  even after their indices are corrected.
- **Every uranium process and sale has always been discarded**: the code emits `uraniump_proc` /
  `uraniump_sold` while the map defines `uranium_proc` / `uranium_sold`, so the lookup misses. Four
  more names are passed and silently dropped: `civkill_headshots`, `cash_send`, `bankmoneyconv`,
  and `boltcut` (the code writes `boltcutted` instead).
- 209 titles: 34 correct and earnable, 146 defective, 29 using no stat at all. Safe fix order is
  writer first, then both readers together.

### Found while arming the prison break's end-of-heist lockout (2026-07-28)

The lockout change itself (`ef1cb14`) verified sound -- the latch fires exactly once per break and
no refusal can reach it -- but two reviewers turned up the following, none of it introduced by that
commit.

- **CORRECTION TO THE RECORD.** `ef1cb14`'s commit message states the mission copy of
  `fn_startPrisonBreak` "is regenerated from the server copy so the twins cannot drift." That is
  FALSE -- no tooling anywhere in the repo regenerates it. The two copies are synced BY HAND and are
  currently byte-identical below the compat header, which was verified. Treat that sentence as
  wrong: the twins can absolutely drift, and this repo has already been bitten by a compat copy
  shadowing its server twin (the `if (true) exitWith {}` stub that silently stopped the prison break
  running, recorded in that file's own header).
- **BattlEye is not filtering client `publicVariable` traffic.** `deploy/battleye/publicvariable.txt`
  is the single rule `1 ""`, and action 1 is LOG, not kick or block. So a modified client can
  broadcast any public variable it likes and the server only writes a log line. That undercuts the
  assumption behind several server-authority gates added today -- `SRV_lastRobbery`,
  `SRV_prisonData`, `AP_tenuredCopCount` are all client-writable in practice. Closing it means a
  real whitelist on the box (not git-tracked here): allow server-originated names, kick on
  client-originated writes.
- **The prison break's "restrained" abort path has never worked.** `fn_startPrisonBreak` reads
  `_unit getVariable ["restrained", false]` in both its `waitUntil` and its success condition, but
  nothing in the tree ever sets a variable of that name -- the codebase uses `AP_restrained`. A
  breaker who is restrained mid-break therefore keeps the break running.
- **The prison progress bar finishes 300 seconds early.** `initPlayerLocal.sqf:401` hardcodes
  `_dur = 500` under a comment saying it MUST match `fn_startPrisonBreak`'s `_breakTimer`, which is
  `800` (or `600` on Australia). The other two sites compute it; this one does not.
- **`SRV_prisonData select 2` reads a slot that does not exist.** The array is seeded 2-element and
  re-stamped 2-element, so `select 2` yields nil at both client read sites and the cop requirement
  falls through to `params`' default of 1. The server reads the same slot as `param [2, 1]`. They
  agree today only by coincidence; use `param` on both sides so a future third slot cannot diverge
  them.
- **A cop-stopped prison break leaves an orphaned `startPrisonBreak` running.** Its `waitUntil`
  watches the breaker, not `SRV_prisonData`, so after a cop stops the break the script runs on and
  re-broadcasts its own failure message and re-restores the marker. The minimal fix is to make that
  `waitUntil` also exit on `!(SRV_prisonData param [1, false])`.

### Open items from the Malden prison design (2026-07-29) — see `maldenprison.md`

The design itself is approved and specced; these four are inputs it cannot supply for itself.

- [ ] **Four Malden MaxTac insertion positions needed.** `fn_startPrisonBreak.sqf:39-44`'s
  `_maxtacPos = switch (worldName)` has Altis/Tanoa/Stratis/Australia, **no Malden case and no
  default**, so `_maxtacPos` is nil and `fn_maxtacDispatch.sqf:50` evaluates `(_locations select 0)
  select 1` on it. The bank's equivalent table (`fn_bankDrillVault.sqf:93`) has a default; this one
  does not. The implementation makes it safe (no table for this world → skip MaxTac and log), but real
  insertion points have to come from the owner or the designer. Until they do, MaxTac does not deploy
  for the prison break.
- [ ] **Minigame difficulty for the prison gate breach.** The Fed perimeter gate uses
  `[10] call AP_fnc_cyberdeckSeq`; the buffer length range is 3..12. Owner's call.
- [ ] **Cops have no spawn points on Malden at all.** `dialog/function/fn_spawnPointCfg.sqf`
  references `cop_spawn_1` .. `cop_spawn_7`; `custom_p3ds/malden_markers.sqf` creates exactly
  one marker, `civ_spawn_1` at La Trinite, resolved from `CfgWorlds >> Malden >> Names`. Nothing
  creates a single `cop_spawn_*` or `med_spawn_*`. Outside the prison work, but it is a live gap.
- [ ] **The other Altis polygons on `core/configuration.sqf:2`.** The prison pass re-coordinates
  `AP_jailPoly` only. Still Altis on that same line: `AP_warzonePoly`, `AP_drugPenPoly`,
  `AP_eviFencePoly` and all seven `AP_*_hq_poly`. The HQ ones have a visible consequence — the
  HQ-polygon branch of the cop "Send to Prison" action (`core/fn_setupActions.sqf:1107`) can never
  be true on Malden, which is why the `jail_release2 < 30` branch is the only reachable one. The
  jewelry poly on that line was already re-coordinated, so this is a half-finished pass.

**Design-time caveat worth repeating here**, because the prison release leans on it: the escape gate
is `fn_jailMe.sqf:91` `(SRV_prisonData select 1) && AP_breakout`, i.e. a client flag ANDed with
server state. Per the BattlEye finding logged above (`deploy/battleye/publicvariable.txt` is `1 ""`,
and action 1 is LOG, not block), `SRV_prisonData` is client-writable in practice, so that AND is
weaker than it reads. Nothing in the prison design makes this worse — it adds no new client-reachable
flag to that expression — but the guard is not sound until the BE whitelist lands on the box.

### Altis carryover sweep (2026-07-30) — follow-ups

The map half is done: 7,070 Altis rows removed from `core/config/fn_mapData.sqf` and its tracked
duplicate `mapImportAll_data.sqf`, identified by exact class+position match against
`~/loonybin-doomba`'s own `fn_mapData.sqf`. The file halved, 1.90 MB → 0.98 MB. Two things fall out.

- [ ] **Malden has no world ATMs, so ATM hacking is dormant.** All 19 `Land_Atm_01_F`/`Land_Atm_02_F`
  rows were Altis carryovers — 18 outside the world, 1 in a transplanted Altis town — and they were
  also the anti-spoof position whitelist in `APS_fnc_cyberdeckSRV`. That whitelist's empty-list
  fallback SKIPPED the check rather than enforcing it, so removing the rows would silently have made
  any position within 8 m of the hacker valid. The fallback now hard-blocks (owner's call), so the
  feature is dormant rather than exploitable. **Place `Land_Atm_01_F` rows at Malden's real ATMs and
  it lights up again with no code change** — `AP_atmPts` is built from mapData on first use.
- [ ] **641 unconditional off-Malden coordinates remain in CODE**, across 42 files — separate from the
  map data and needing per-site judgement, not a sweep. A further 124 literals are in explicit
  `case "Altis":` branches of world switches (`vars.sqf`, `fn_bankDrillVault`, `fn_trialBegin`,
  `fn_queryCaptures`, `fn_laserTag`, `fn_fedAlarm`, `fn_startPrisonBreak`) and are CORRECT to keep —
  this codebase supports several maps. The unconditional ones are whole features still pointed at
  Altis and are dead where they stand; each needs a Malden home or a deliberate removal:
  `fn_spawnCaptures.sqf` (115), `core/configuration.sqf` (89, the polys already logged above),
  `fn_dynamicMapCfg.sqf` (62 zones), `fn_eventGraveyardClient.sqf` (52), `fn_eventRoutes.sqf` (44),
  `fn_timeTrialCfg.sqf` (40), `init.sqf` (26 fed walls), `fn_eventCfg.sqf` (22), `fn_setupActions.sqf`
  (18, incl. an unconditional `player distance [20898.6,19221.7]` at :664), `fn_zoneCreator.sqf` (13
  triggers), `fn_airdropEventSRV.sqf` (6), `fn_loonyBinSRV.sqf` (8, comments only).
  Note `fn_houseConfig.sqf` (66) and `fn_vehicleConfig.sqf` (18) are FALSE POSITIVES — those are price
  and level pairs like `[2000, 20000]`, not positions. Filter before acting.
- [x] **client-side event handler renamed to remove foreign branding** — `core/adminEvents/fn_eventGridrunnerClient.sqf` was renamed from breaking the naming rule against foreign server references, touching the file, `Functions.h` and all callers (2026-08-21)

### Prison mine / cave — rocks blocking the stairwells (2026-07-30)

**Owner report:** "the composition for the mine got mangled ... mostly rocks blocking stair wells and
stuff, kinda like the sea fortress was back on Altis we fixed."

**It is NOT our data, and it is not the sea-fortress bug.** Measured, not assumed:

- `core/config/fn_mapData.sqf` and the engine sweep (`build/mapexport_malden.log`) agree **exactly**
  within 30 m of the cave — 0 rows either way.
- Every object our pipeline places is **exactly** where the array says: 23 of 23 matched at 0.00 m
  horizontal and 0.00 m vertical (cargo platforms, bunker, factory tunnel, pole walls, lights, all
  eight `Land_Slums01_8m` sections, the tan repair depot).
- `mission.sqm` has **0** objects within 30 m, so nothing is double-spawning.
- The cave's 13 stacked groups all have **distinct z** — the class+XY join that mangled the fed and
  the prison (`67e8156`) has not recurred. `tools/mapdata_rebuild_from_export.py` agrees: 8,655
  matched, every raw row consumed at most once, over-count 0. **Do not re-run it with `--write`** —
  it would fix nothing here and would revert the prison gate promotion in `c0f2edb8`.
- The sea-fortress cause was Eden re-grounding stacked objects on import; that guard exists and this
  fork has it (`ANTI-DRIFT` in all three `mapExportAll.sqf` copies).

**What is actually there:** 12 objects sit inside the composition that have **no array row and were
never in the engine sweep** — i.e. they are Malden's own TERRAIN, part of the map, not placed by
anyone and not removable by editing our data. The designer's composition is placed exactly as
delivered; it intersects native rock.

Probe point was `[2985.63, 7091.79, 19.81]` (inside the structure). Ranked by distance from it:

```
Land_Cliff_wall_tall_F            [2993.00, 7096.71, 15.71]    9.8 m   dz  -4.10
Land_PierWooden_01_10m_noRails_F  [2976.08, 7097.21, 17.72]   11.2 m   dz  -2.09
Land_Cliff_wall_tall_F            [2975.74, 7101.02, 17.78]   13.7 m   dz  -2.03
Land_Cliff_wall_round_F           [2994.42, 7092.08,  1.56]   20.3 m   dz -18.25
Land_Cliff_wall_round_F           [2997.75, 7090.27,  3.27]   20.6 m   dz -16.54
Land_Cliff_wall_tall_F            [2978.63, 7110.90, 26.23]   21.3 m   dz  +6.42
Land_Cliff_wall_tall_F            [2998.93, 7106.06, 29.07]   21.6 m   dz  +9.26
Land_Cliff_wall_round_F           [3003.39, 7093.72,  4.01]   23.8 m   dz -15.80
Land_Cliff_wall_tall_F            [2963.71, 7103.85, 21.49]   25.1 m   dz  +1.68
Land_Cliff_wall_tall_F            [2977.91, 7078.20, 44.55]   29.3 m   dz +24.74
Land_Cliff_wall_tall_F            [3010.10, 7101.34, 36.98]   31.4 m   dz +17.17
Land_Cliff_wall_tall_F            [2996.21, 7079.51, 49.44]   33.8 m   dz +29.63
```

Positions are ATL (the frame the array and the sweep both use). Some of these are the cave's own
outer walls and MUST stay — only the ones actually intruding should go, which needs eyes in-game.
The wooden pier reading as terrain is unusual; worth a second look, but it is genuinely absent from
the sweep.

- [ ] **Decide the route. Two exist, and only one needs the designer.**
  - **Designer route** — he deletes the offending terrain objects in 3DEN and re-sends the .sqm. Fits
    his workflow (place → save → send, he runs nothing). **OPEN QUESTION, resolve before delegating:**
    it is not established that a 3DEN terrain-object deletion survives our pipeline, because the map
    layer is stripped out of the .sqm into `allLocalMapEntities` and the sqm's dataType census shows
    no terrain-hider entity (Object 4260 / Marker 228 / Logic 227 / Group 159 / Comment 36 / Layer 34
    / Trigger 1). **Cheap test first:** have him delete ONE named rock, send the .sqm, and check
    in-game whether it is gone. If it is not, this route is dead and the delegation wastes his time.
  - **Our route, no designer needed** — a server-side hide list in `custom_p3ds/`, exactly the
    shape of `custom_p3ds/replace_sheds.sqf`. That file documents the footgun and it is
    live-confirmed: **`hideObjectGlobal` on a TERRAIN object only takes, and JIP-persists, when run on
    the SERVER** — a client/debug-console call silently no-ops. Use its `AP_shedsReplaced`-style
    idempotent guard. Reversible in one line, and it cannot be lost by a future .sqm redelivery.
- [ ] **Identify WHICH of the 12 to remove.** Needs someone in-game. Console tool (local hide, purely
  visual, reverts on rejoin):
  `AP_hidTest = [];` then, aiming at each offender:
  `AP_hidTest = AP_hidTest + [cursorObject]; cursorObject hideObject true; diag_log format ["-HIDETEST- %1 %2", typeOf cursorObject, getPosATL cursorObject];`
  Undo: `{ _x hideObject false } forEach AP_hidTest; AP_hidTest = [];`
  The `-HIDETEST-` lines land in the client RPT and give the exact list to bake.

**Already fixed, separately (`a2f0280c`):** `Land_RepairDepot_01_civ_ruins_F` at
`[2987.443, 7174.259, 11.305]` was in the engine sweep but in neither the .sqm nor the array — a
genuine pipeline loss, the only object in the whole cave the two disagreed on, and unrelated to the
7/26 join bug. Restored verbatim; the cave is 484 objects again, matching the sweep exactly. Worth
knowing that a second, separate loss happened at all — see the 546-row question logged above.
