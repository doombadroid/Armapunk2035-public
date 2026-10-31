class BIS_AddonInfo
{
author="76561190000000041";
timepacked="1472138527";
};

class DefaultEventhandlers;
class CfgPatches 
{
class AP_server
{
units[] = {"C_man_1"};
weapons[] = {};
requiredAddons[] = {"A3_Data_F","A3_Soft_F","A3_Soft_F_Offroad_01","A3_Characters_F"};
fileName = "AP_server.pbo";
author[]= {"Loonybin"}; 
};
};

class CfgFunctions
{
class STS_DB
{
tag = "DB";
class MySQL
{
file = "\AP_server\core\DB";
class numberSafe {};

class mresArray {};
class mresToArray {};

class asyncQuery {};
 class asyncExec {}; // one WRITE with an answer: [1,rowcount,rows] / [0,msg] -- ends the [] write ambiguity
class flag {}; // the one reader of the DB control flags (localNamespace: publicVariable cannot overwrite them)

class insertVehicle {};
class queryStock {};
class queryVehicle {};

class queryConfig {};
class insertHouse {};
class updateHouse {};
class deleteHouse {};

class deleteVehicle {};
class queryHouses {};
class queryStorage {};
class insertStorage {};
class updateStorage {};
class insertGang {};
class queryGangs {};
class updateGang {};
class deleteGang {};
class queryGangMembers {};
class gangMember {};
class queryCaptures {};
class updateCaptures {};
class updateTurf {};
class updateConfig {};
class updateVehicle {};
class saveVehicles {};
class restoreVehicles {};
class insertWanted {};
class deleteWanted {};
class bool{};
class insertRequest{};
class queryRequest{};
class updateRequest{};
class updatePartial{};
class dutyLoad{}; // faction rework: saved duty character for one player + faction (server-internal only)
};
};

class AP_System
{
tag = "AP";
class Wanted_Sys
{
file = "\AP_server\core\wantedsys";
class wantedFetch {};
class wantedPerson {};
class wantedBounty {};

class wantedPardon {};

class createDispatch {};
class maxtacDispatch {};
class setRestrained {};
};

class Jail_Sys
{
file = "\AP_server\core\jail";
class jailSys {};
class startPrisonBreak {};
class trialRequest {};
class trialBegin {};

class juryVote {};
};
};

// PySQF — call Python from SQF. Server-only, so the names take the APS_ prefix
// per the machine-ownership rule: the server compiles both CfgFunctions trees
// into missionNamespace, and a client fn sharing a name would silently win.
// The extension and daemon live in their own repo; only the client is vendored
// here (server/AP_server/core/pysqf/). Nothing calls these yet — they are the
// seam for the PostgreSQL work. Runbook: pysqf.md
class STS_PySQF
{
tag = "APS";
class PySQF
{
file = "\AP_server\core\pysqf";
class pysqfRaw {};   // verb-level: call/poll/chunk/free/version/stats
class pysqfCall {};  // ergonomic wrapper, returns [ok, result]
class pysqfSmoke {}; // five-stage diagnostic — run this first when it "doesn't work"
class pysqfConform {}; // exhaustive in-engine conformance suite — run after the smoke test passes
class pysqfDiag {};    // the one admin-gated entry point clients may remoteExec
};
};

class STS_System
{
tag = "APS";
class System
{
file = "\AP_server\core\system";
class doRestart {};
class scheduler {}; // singleevh.md Phase 1: single-wheel server task scheduler (AP_fnc_schedule/unschedule/schedulerStart/schedulerDump)
class resetFed {}; // owner 2026-06-16: admin live Federal Reserve / bank lockout reset (debug `call APS_fnc_resetFed` or `!srv resetfed`)
class fedLockdown {}; // owner 2026-06-16 (#312): re-lock the fed domes/safes/gates to a clean robbable state (called by resetFed)
class fedEventActive {}; // owner 2026-06-16 (#302): server-authoritative federal-event mutual-exclusion check
class playerDisconnected {};
class bankMove {}; // the ONE guarded server-side bank movement primitive (lifted verbatim out of fn_holdemSRV; hold'em + duty bounty payoff both call it)
class dutySRV {}; // faction rework: the authority for duty shifts (roster, whitelist, cooldown, watchdog)
class preSpawnPos {}; // PR10: pre-position the server's copy of a spawn-held player before the client releases simulation (kills the 50 km release yank)
class dbSoak {}; // pg conversion: in-game database soak -- every DB fn class on scratch rows, [DBSOAK] PASS/FAIL to RPT (bot verb `dbsoak`)
class dutyLookup {}; // faction rework: read a player's duty roster entry (server-local; NO CfgRE entry)
class isDutyCop {};  // faction rework: server-side "may this unit exercise MaxSec authority" predicate
class isDutyMed {};  // faction rework: the Trauma Team half of isDutyCop
class setOwnerID {};
class queryHouses {};

class houseContainerPos {};

class initEvent {};
class addToEvent {};

class manageRadio {};
class managePhone {};
class cleanup {};
class cleanupHouses {};
class cleanupStorage {};

class huntingZone {};
class spawnCaptures {};
class maxtacRegistered {};

class setWaypoint {};
class reduceMarket {};
class marketTick {};
class stockUpdate {};   // market sell/buy hook (client -> server via CfgRE); replaced the AP_stock_update PV handler
class spawnVehicle {};
class addVehicle2Chain {};
class removeStorage {};
class experienceReq {};
class getVehicles {};
class vehicleStore {};
class vehicleCreate {};
class vehicleDelete {};
class vehicleDead {};
class recoverWreck {};

class joinRace {};

class getHouses {};
class addToLottery {};
class spikeStrip {};

class logIt {};

class rebootMonitor {};
class patchServer {};

class hardRestart {};

class weatherSync {};
class laserQueue {};
class laserTag {};
class laserEliminated {};
class getGuid {};
class getIpAddress {};

class placeStorage {};
class addStorage {};
class receiveHouses {};
class checkHacks {};

class chopShopSell {};
class igiInit {};
class robStore {};
class spawnGoldBars {};
class isUIDActive {};
class queryGangs {};

class updateGang {};
class receiveGangs {};

class gangMember {};

class monitorCaptures {};
class updateGangBank {};

class setIdletime {};
class flipVehicle {};
class addObjectWhitelist {};
class insured {};
class updateWar {};
class visible {};
class getAdmin {};
class createP3DObjects {};
};

class Bank_Sys
{
file = "\AP_server\core\bank";
class fedAlarm {};
class bankDrillVault {};
};

class Politics
{
file = "\AP_server\core\politics";

};
};
class GEServer
{
tag = "KBW";
class GE
{
file = "\AP_server\core\GE";

class fixBadOffers {};

};
};
	class TONServer
	{
 tag = "APS";
 // LooneyBin: EXISTS aliases -- same 2017 files exposed under APS_fnc_* for the 2020 client.
 class Web_TON
 {
 file = "\AP_server\core\web";
 class webPageSRV {};   // serve a UI page's markup to one client -- UI ships without a client repack
 class hudLayoutSRV {};  // HUD UI EDITOR (hudeditor.md): get/set players_global.ui_layout for the CALLER
 };
 class System_TON
 {
 file = "\AP_server\core\system";
 class flipVehicle {};
 class getVehicles {};
 class igiInit {};
 class laserEliminated {};
 class laserQueue {};
 class logIt {};
 class updateWar {};
 class vehicleCreate {};
 class vehicleDead {};
 class recoverWreck {};
 class vehicleDelete {};
 class vehicleStore {};
 class visible {};
 };
 class MySQL_TON
 {
 file = "\AP_server\core\DB";
 class insertGang {};
 class aqSql {};   // ArmaQuest sql store host bridge (fn_aqSql.sqf) -- APS_ prefix required,
                    // it is the machine-ownership one ArmaQuest's sqlExec setting names.
 };
 class Jail_TON
 {
 file = "\AP_server\core\jail";
 class jailSys {};
 };
 class Wanted_TON
 {
 file = "\AP_server\core\wantedsys";
 class wantedBounty {};
 class wantedFetch {};
 class wantedPardon {};
 class claimBodybagSRV {}; // LooneyBin: claim a combat-log fugitive bodybag (jail offline + pay)
 };
 class Renamed_TON
 {
 file = "\AP_server\core\TON";
 // Live map editor. These MUST live in a core\TON block: they were first registered
 // beside dutySRV, which sits in the core\system block, and the engine looked for
 // \AP_server\core\system\fn_mapEditLoad.sqf and logged "Script ... not found" --
 // a WARNING, not an error, so the boot simply did nothing and said nothing useful.
class mapLoad {};         // mapdb: boot -- every live map row into memory, by cell; spawn the server's own rows (server-local; NO CfgRE entry)
class mapRowUpdate {};    // mapdb: the single mutator of the in-memory map (server-local; NO CfgRE entry)
class mapBlob {};         // mapdb: one cell as a deflated literal, cached per rev, round-trip checked (server-local; NO CfgRE entry)
class mapFetch {};        // mapdb: a client asks for cells; read-only, requester from remoteExecutedOwner, reply to it alone
class territoryLoad {};   // postgis: faction_territory -> AP_factionPolys (publicVariable); boot + bot verb territoryreload
class mapEditSRV {};      // live map editor: the in-game authority -- caller from remoteExecutedOwner, level 5 re-read per call, class allowlist, never a client-supplied init
class mapEditAudit {};    // live map editor: one map_edit_log row per accepted edit (server-local; NO CfgRE entry)
class mapEditPoll {};     // live map editor: watch map_meta.rev, broadcast out-of-band edits (server-local; NO CfgRE entry)
class edenLiveBeat {};    // Eden Live: player positions -> eden_live_players every 2 s for editor ghosts (server-local; NO CfgRE entry)
class telemetry {};       // telemetry: 5 s server tick + 60 s object census -> pysqf telemetry.push -> VictoriaMetrics (server-local; NO CfgRE entry)
class telemetryBeat {};   // telemetry: a client's 10 s beat lands here -- caller from remoteExecutedOwner, nineteen clamped numbers, one hashMap write
class telemetryProfile {}; // telemetry: once-per-session client profile (resolution, fov, build, branch, language) -- same caller rule, strings sanitised
class mapRowOp {};        // live map editor: ONE place a map_objects row becomes an op (server-local; NO CfgRE entry)
class mapEditEmit {};     // live map editor: after a write, read the row back, update the cache, broadcast (server-local; NO CfgRE entry)
 class fedAirDefenseSRV {};   // Fed platform anti-air (Malden)
 class fedRadarSRV {};        // blowing the radar tower takes the anti-air down
 class maldenFedSRV {};      // the Malden Federal Reserve heist (one authority: state, timers, gold, boat, reset)
 class maldenBankSRV {};     // the Malden bank's door: resolve, bind AP_bank_building, lock/unlock
 class maldenJewelSRV {};    // Malden wiring for the Jewelry Emporium (binds the three Eden objects, spawns the safe)
 class prisonGateSRV {};    // the Malden prison sally-port gates + the cop disarm latch
 // LooneyBin: 59 renamed-layer wrappers -> 2017 fns. See docs/APS_RENAMED_REVIEW.md.
 class add2Lotto {};
 class addHouse {};
 class adminDelVeh {};
 class adminPlayerQuerySRV {};
 class bankRobbery {};
 class blackJackSRV {}; // LooneyBin: Casino phone app -- blackjack server engine (fn_blackJackSRV.sqf)
 class bjTableSRV {};   // DEALERBOT'S TABLE -- the shared 5-seat blackjack engine
 class holdemSRV {};    // TEXAS HOLD'EM -- the shared 6-seat table (fn_holdemSRV.sqf)
 class holdemEval {};   // hold'em hand ranking + its 16-vector self-test; server-local, NOT in CfgRE
class mapBake {};      // one-shot: bake heightfield + buildings into the log (see fn_mapBake)
 class bjChips {}; // blackjack powerup chip wallet (server-only, not in CfgRE)
 class casinoSRV {}; // LooneyBin: Casino -- Coin Flip/Wheel/Slots/Roulette/Hi-Lo engine (fn_casinoSRV.sqf)
 class bulkAdd {};
 class cartelSRV {};

 class cartelCollectSRV {};

 class cartelReturnSRV {};
 class changeServCycle {};
 class changeWeather {};
 class checkPlayer {};
 class createAdminVeh {};
 class eventParticipants {};
 class exchangeSystemSRV {};
 class fabSRV {}; // 3D printer authority: place/queue/collect/pickup
 class fabGrantSRV {}; // the single funnel for every schematic grant (roll/give/buy/shard)
 class fabDebugSRV {}; // FREE BUILD testing override (adminlevel >= 3, never persists)
 class rigSRV {}; // resource extractor/processor authority: spawn/state/mining ticks
 class rigAdopt {}; // rig identity onto a truck (NOT in CfgRE -- that absence is the gate)
 class fabXp {};  // fabrication progression (NOT in CfgRE -- that absence is the gate)
 class fedRobbery {};
 class gangBank {};
 class houseFurnitureSRV {};
 class houseRights {}; // house owner/keyholder/gang rights from the DB row (NOT in CfgRE -- server-internal)
 class loveBombSRV {};
 class adminKickBan {};
 class economySRV {};
 class garageCount {};
 class getGangInfo {};
 class getID {};
 class getStatsArr {};
 class govSystemSRV {};
 class greenhouseSRV {};
 class barrelSRV {};
 class stimmySRV {};
 class fedOverrideSRV {};
 class handleDispatch {};
 class handleJail {};
 class handlePhoneCallSRV {};
 class handlePhoneMsg {};
 class handlePrisonBreak {};
 class handleWireTransfer {};
 class huntingGrounds {};
 class initHouseInventory {};
 class processMailbox {};
 class registerMaxTac {};
 class removeGang {};
 class setCleanTime {};
 class gangRenameSRV {};
 class setGangTagSRV {};
 class setJail {};
 class spawnPhysicalItem {};
 class srvChopShopSell {};
 class srvObjectMonitor {};
 class srvRobStore {};
 class srvSellHouse {};
 class srvSellVehicle {};
 class srvSpikeStrip {};
 class statTableUpdate {};
 class timeTrialSRV {};
 class transferGangOwnerSRV {};
 class transferHouse {};
 class trialSystemSRV {};
 class updateGangTalents {};
 class updateGangMem {};
 class updateHousePrice {};
 class updateHouseTrunk {};
 class updateProperty {};
 class updateVehicleMods {};
 class varPersist {};
 class vehOwnerSwap {};
 class vehicleRepairSRV {};
 class vehicleSetActive {};
 class dongClient {};
 class adminMsg {};
 class wantedAdd {};
 class wantedSyncList {};
 class wantedRemove {};
 };
 class New_TON
 {
 file = "\AP_server\core\TON";
 // LooneyBin: NEW 2020 server fns (no 2017 source). Stubs -> upgrade to full impl.
 class addGangHouse {};
 class airDrop {};
 class airDropMedic {};
 class bankLightHouseToggle {};
 class bldgUpdateKeys {};
 class chopTreeSRV {};
 class copUAVSRV {};
 class victimSRV {}; // player-on-player actions: re-checks actor/range/state, forwards to the victim's client
 class registerForeskin {};
 class loonerSRV {}; // LooneyBin: Looner microblog (feed/post)
 class newsPush {}; // LooneyBin: Ben Bones -- world event -> a loon on looner.com
 class summonSRV {}; // SUMMON VEHICLE: star a recall vehicle; spawn it ~1 km out and have the HC bring it
 class avSRV {}; // LUXE AV (ap_av addon): server-flown autonomous air taxi, preset destinations (go/door)
 class avFly {}; // LUXE AV: one flight (door, pods, AP_fnc_hcFly with the pad pinned, settle); spawned by avSRV
 class atmSkimSRV {}; // ATM skimmer backend (apply/remove/credit/load)
 class talentPointsSRV {}; // buyable talent points (load/buy, talent_points table)
 class airdropEventSRV {}; // public rebel weapon airdrops
 class eventRoutes {}; // shared hand-drawn route geometry (supply bomber A/B + smuggler loop)
 class apStress {}; // DEV-ONLY: HC-autopilot map-wide stress/coverage harness (strip before live)
 class eventIceCreamSRV {}; // world event: ice cream truck of doom (loot stops + random detonation)
 class eventSupplyBomberSRV {}; // world event: supply bomber carpet loot-drop
 class eventCropDusterSRV {}; // world event: crop duster gas cloud (buff/debuff zone)
 class eventBlackoutSRV {}; // world event: city blackout
 class miningSRV {}; // LoonyCoin mining rigs
 class cyberdeckSRV {};
 class cdModsSave {}; // the ONE writer of players.cyberdeck_modules -- server copy, parameterised (NOT in CfgRE)
 class talSRV {}; // TAL OS (MaxSec) backend -- records lookup
 class iceTrace {}; // ICE TRACE -- single authority on whether a hack is quiet
 class qhSRV {}; // quickhack authority (server-timed upload channel) // Cyberdeck hacks -- house-door relock + owner-notify (fed/bank later)
 class aqFact {}; // ArmaQuest: report a SERVER-witnessed action verb (AQ_Settings serverFacts[]) -- NOT in CfgRE by design
 class ndSRV {}; // New Drachma authority (server-side wallet, DECIMAL ledger)
 class ndCreditSrv {};
class adminNdSRV {}; // staff ND grant -- wire-callable, admin gate re-checked server-side, credits via ndCreditSrv
        class gangAlignSRV {};
        class factionWarSRV {};       // the weekly fixer war: matchup, contract score, rollover
        class buyFactionPerkSRV {};   // gang -> NPC faction alignment + the published mirror // New Drachma server-internal trusted credit (NOT in CfgRE by design)
 class ndDebitSrv {};  // New Drachma server-initiated debit, suite rent (NOT in CfgRE by design)
 class suiteSRV {};              // Luxe Suites lease authority (CfgRE allowedTargets=2)
 class suiteRelease {};          // the one wipe path, end-lease + repossession (NOT in CfgRE)
 class suiteRentSweep {};       // 300s rent clock: renew, flag arrears, repossess (NOT in CfgRE)
 class suiteStorageSRV {};      // suite storage authority (CfgRE allowedTargets=2)
 class suiteFurnitureSRV {};    // suite furniture authority (CfgRE allowedTargets=2)
 class suiteFurnitureDespawn {}; // remove a suite's spawned furniture (NOT in CfgRE)
 class qhLootSRV {}; // quickhack loot rolls (fed/cartel) -- consumables + rare hack chips
 class qhDeadmanSRV {}; // Dead Man's Clutch: server-side sever + consume when a hijack lands
 class bonesDM {}; // Ben Bones DM router
 class bonesDeliver {}; // Ben Bones reply delivery poll
 class offlineMsg {}; // queue a text for a player who is not on the server
 class offlineMsgDeliver {}; // hand queued texts over once the recipient is back
 class toggleNewbieRoles {};
 class ownerSpangle {};
 class radioSRV {};
 class wantedChargesConfig {};
 class changeGangHouseSRV {};
 class convoyRobbery {};
 class copSplit {};
 class createItem {};
 class invCargo {};   // the I-screen's one serialised vehicle/crate/ground cargo mutator (INVENTORY_SPEC.md §9.4)
 class createTimeTrialVehSRV {};
 class discordEmbed {};
 class doBuySkin {};
 class duelArenaSystemSRV {};
 class easterSeasonalEvent {};
 class enableCoPilot {};
 class endConvoyRobbery {};
 class isAdminCaller {}; // server-internal admin gate for remoteExec'd SRVs (NOT in CfgRE)
 class eventBRSRV {};
 class eventGraveyardSRV {};
 class eventGunGameSRV {};
 class funGunSRV {}; // LooneyBin: owner admin-menu FUN GUNS (Lynx rampage / submarine cannon)
 class eventPurgeSRV {};
 class eventChemtrailSRV {}; // world event: chemtrail flyover
 class eventBugInvasionSRV {}; // world event: bug invasion horde
 class eventLizardPoliceSRV {};// world event: lizard police
 class eventSmugglerBoatSRV {};// world event: smuggler speedboat contraband run
 class eventGridrunnerSRV {};
 class evidenceAppend {};
 class evidenceTruck {};
 class fetchLoadouts {};
 class gangBHistory {};
 class gangGarageAddSRV {};
 class gangGarageCount {};
 class gangGarageGetVehicles {};
 class gangGarageSetActive {};
 class gangGarageStore {};
 class handleLoadouts {};
 class handleTimer {};
 class houseTaxSRV {};
 // owner 2026-07-14: RE-REGISTER the 7/11 malden-migration house fns dropped from config.cpp
 // (git<->on-box divergence) -- fn_*.sqf exist but were uncompiled => malden makeover / storage
 // vault / house rename / shed helipad / intake all silently dead server-side.
 class maldenSRV {}; // Malden Makeover apply (base<->Argo variant)
 class tagHousesSRV {}; // house ownership tagging + malden-skin boot restore
 class storageVaultSRV {}; // house storage vault
 class renameHouseSRV {}; // house rename
 class shedHelipadSRV {}; // shed helipad upgrade
 class intakeSRV {}; // new-player intake
 class ignitionBombSRV {};
 class jewelryEmporiumSRV {};
 class keyManagement {};
 class lagCheck {};
 class loginBonusSRV {};
 class medSupplyPay {};
 class medSupplySpawn {};
 class medicFireSRV {};
 class medicSplit {};
 class seizeLock {};
 class loonyBinSRV {};
 class droneCharges {};
 class fedGoldSpawn {};
 class removeGangHouseSRV {};
 class repairBuildingSRV {};
 class sendKeyHouses {};
 class srvMobileHQ {};
 class srvPersistentBounties {};
 class vehAddAlarm {};
 class wantedRemoveCharge {};
 class xmasTreeAndPresentsSRV {};
 };
	};
};

class CfgVehicles
{
class Car_F;
class Plane_Base_F;
class CAManBase;
class Civilian;

class Civilian_F : Civilian
{
class EventHandlers;
class CfgMovesFatigue
{
staminaCooldown = 7;
staminaDuration = 90;
staminaRestoration = 20;
};
};

class C_man_1 : Civilian_F
{
class EventHandlers;
class CfgMovesFatigue
{
staminaCooldown = 7;
staminaDuration = 90;
staminaRestoration = 20;
};
};
};