
// LooneyBin 2026-07-16: HEADLESS CLIENT EXCLUSION. allPlayers INCLUDES the connected headless client, and on
// this box getPlayerUID(HC) returns "HC50998" (non-empty), so the usual `getPlayerUID != ""` filter lets it
// leak into player-processing (proven: it was accruing houses.tax_playtime as owner 'HC50998'). Real Steam64s
// are digits only. AP_fnc_realPlayers = allPlayers minus anything without an all-numeric UID (the HC, plus any
// not-yet-authed client). Use at every AGGREGATE site (pop counts, online-UID lists) so the HC never counts as
// a civ. Point lookups (findIf UID==target) already never match the HC, so they don't need it.
AP_fnc_realPlayers = compileFinal {allPlayers select {private _u = getPlayerUID _x;
        (_u isNotEqualTo "") && { (toArray _u) findIf { _x < 48 || _x > 57 } isEqualTo -1 }}};
// LooneyBin 2026-07-16 (HC-incident fix): AUTHORITATIVE headless-client presence. AP_hcOwner is the "HC online"
// signal the autopilot features key off (no HC -> no driver available). The HC self-announces it, but an
// UNGRACEFUL drop (crash / hard kill) leaves it stale, and the HandleDisconnect EH can lag a 30s timeout. This
// loop is the source of truth: every 15s it sets AP_hcOwner to the connected HeadlessClient's owner id, or 0 if
// none. Cheap; never touches the mission. (AP_UsingHeadless is NOT set anymore -- it armed the legacy
// endMission-on-HC-drop path that booted the whole server.)
// Server code reads the localNamespace copy this loop writes, never AP_hcOwner: that global is also what the
// HC's self-announce (and therefore any client's publicVariable) writes, and setGroupOwner/setOwner on a
// forged owner id hands event AI and summoned vehicles to that client (audit Lsec-0-1).
if (isNil "AP_hcOwner") then { AP_hcOwner = 0; publicVariable "AP_hcOwner"; };
localNamespace setVariable ["AP_hcOwner", 0];
[] spawn {while {true} do {uiSleep 15;
        private _hc = (allPlayers select { (typeOf _x) isEqualTo "HeadlessClient_F" }) param [0, objNull];
        private _o = if (isNull _hc) then { 0 } else { owner _hc };
        localNamespace setVariable ["AP_hcOwner", _o];
        if (_o isNotEqualTo AP_hcOwner) then { AP_hcOwner = _o; publicVariable "AP_hcOwner"; };};};
server_query_running = false;
AP_DB_queue = [];
AP_item_pickups = [];
serv_sv_use = [];

call compile preprocessFileLineNumbers "\AP_server\vars.sqf";

// singleevh.md Phase 1 — install the single-wheel task scheduler API (server-only). Idempotent install;
// AP_fnc_schedulerStart is called AFTER the migration sites register their jobs. Each job used to be
// registered behind an `if (AP_useScheduler)` gate with the pre-migration loop in the else; that flag and
// all 24 legacy else bodies were removed 2026-07-24 (live since 2026-07-05, fallback never once executed).
call APS_fnc_scheduler;
call AP_fnc_schedulerStart;   // starts the wheel; jobs registered later in init are picked up live

// LooneyBin: server_init.sqf was a DEAD FILE — execVM'd nowhere — so the ONLY HandleDisconnect EH in
// the codebase was never registered (disconnected players left a corpse at your feet, no final flush)
// AND the server-side eventhandlers.sqf (serv_* PV handlers) never loaded. Merge gap: the 2017 server
// init was never wired into LooneyBin's init.sqf. Run it on the server now (after vars.sqf, before READY).
if (isServer) then { [] execVM "\AP_server\server_init.sqf"; };

_extDB = false;

// ---------------------------------------------------------------------------
// WHICH DATABASE ENGINE. One flag, read once, and every query follows it --
// DB_fnc_asyncQuery is the single chokepoint all 1478 call sites go through.
//
//   false  extDB3 -> MariaDB.        The engine this game has always used.
//   true   PySQF  -> PostgreSQL.     postgres_plan.md Phase 2.
//
// Set from the server's own environment rather than a committed constant, so
// dev and the new box can differ without a code change and neither can be
// switched by accident: `AP_DB_POSTGRES=1` in the launch environment.
//
// The extDB3 path below still runs either way. It costs one connection and it
// means a rollback is this flag, not a redeploy -- which matters because the
// only way to find the queries that behave DIFFERENTLY (rather than fail) is to
// run the game against the new engine and watch.
// ---------------------------------------------------------------------------
// SQF has no way to read a process environment variable, so the flag is held by
// the one component that must ALREADY be running for PostgreSQL to work at all:
// the PySQF daemon answers `apdb.enabled` from `AP_DB_POSTGRES` in its own
// environment. That makes the switch a systemd drop-in and a daemon restart --
// genuinely runtime, no repack, no code edit -- and it makes the two halves
// impossible to set inconsistently, because there is only one setting.
//
// Default OFF, and off is also what a missing or dead daemon produces. That
// direction is deliberate: a server that keeps running on MariaDB is a bad
// afternoon, and a server that starts on PostgreSQL because nothing said not to
// is a database nobody meant to write to.
// localNamespace, read via DB_fnc_flag: a missionNamespace global here was client-publishable (audit srvdb-0-0).
localNamespace setVariable ["AP_db_postgres", false];
// Queries WAIT for this. The probe is asynchronous -- it has to be, it can take
// several seconds against a cold socket -- and boot fires queries immediately,
// so without a gate the first few land on extDB3 and the rest on PostgreSQL.
// A boot split across two databases is worse than either one of them, and it
// would look like nothing at all: both engines answer, and the rows are simply
// in different places.
localNamespace setVariable ["AP_db_engineDecided", false];
[] spawn {
    // One exit point, so the gate cannot be left shut on a path somebody adds
    // later. `_engine` is the answer; everything below only decides what it is.
    private _engine = false;

    // RETRY. The extension connects to the daemon's socket as it loads and this
    // probe runs in the same instant -- a cold IPC connection answers "refused"
    // once and then works. The conformance suite was bitten by exactly this. A
    // single attempt reads as "PySQF is not running" and would silently leave a
    // PostgreSQL deployment writing to MariaDB.
    private _r = [false, "not attempted"];
    for "_i" from 1 to 5 do {
        _r = ["apdb.enabled", []] call APS_fnc_pysqfCall;
        if (_r param [0, false]) exitWith {};
        uiSleep 1;
    };

    if !(_r param [0, false]) then {
        diag_log format ["[apdb] PySQF unavailable after 5 tries (%1) -- extDB3 / MariaDB",
            _r param [1, ""]];
    } else {
        private _info = _r param [1, []];
        if !(_info isEqualType [] && {count _info > 0} && {(_info select 0) isEqualTo true}) then {
            diag_log "[apdb] PySQF up but AP_DB_POSTGRES is not set -- extDB3 / MariaDB";
        } else {
            // Prove the DATABASE is reachable too, not just the daemon, before a
            // single query is routed at it. A daemon that is up with a dead pool
            // would otherwise turn every query into a failure several seconds
            // into the boot, saying nothing about which half was wrong.
            private _p = ["apdb.ping", []] call APS_fnc_pysqfCall;
            if (_p param [0, false]) then {
                _engine = true;
                diag_log format ["[apdb] PostgreSQL reachable: %1", _p param [1, ""]];
            } else {
                diag_log format ["[apdb] *** AP_DB_POSTGRES is set but PostgreSQL is NOT reachable: %1",
                    _p param [1, ""]];
                diag_log "[apdb] *** staying on extDB3 / MariaDB rather than failing every query.";
            };
        };
    };

    localNamespace setVariable ["AP_db_postgres", _engine];
    localNamespace setVariable ["AP_db_engineDecided", true];      // opens the gate in fn_asyncQuery
    diag_log format ["[apdb] ENGINE: %1",
        ["extDB3 / MariaDB", "PySQF / PostgreSQL"] select _engine];
};

if(isNil {uiNamespace getVariable "AP_sql_id"}) then {AP_sql_id = round(random(9999));
uiNamespace setVariable ["AP_sql_id",AP_sql_id];

// --- extDB3 migration (LooneyBin) -----------------------------------------
// extDB3 raw-SQL: ADD_DATABASE + ADD_DATABASE_PROTOCOL:<db>:SQL:<id>: then
// query via "<mode>:<id>:<sql>" and read with "4:<key>" (see fn_asyncQuery).
// 2026-08-20: the guard below reads AP_db_postgres, and the decision above is SPAWNED -- unwaited, the
// guard ran ~1s before the flag existed, read false, and aborted the whole init on the first
// extension-less boot (b0707: "extDB: Error", zero post-guard init, duty roster fine only because it
// runs earlier). Init is scheduled (45 waits in this file already), so wait for the decision here.
waitUntil { "AP_db_engineDecided" call DB_fnc_flag };

// (mapdb load used to be spawned HERE -- inside this once-per-PROCESS block. Moved below it, 2026-09-07.)      // watch map_meta.rev for edits made outside the game (3DEN -> map_push.py)
_result = "extDB3" callExtension "9:VERSION";
diag_log format ["extDB3: Version: %1", _result];
if(_result == "") exitWith {diag_log "extDB3: Extension not loaded (check @extDB3 mod + extDB3 in serverMod)";
    // 2026-08-20 owner call: extDB3 is REMOVED from the box (PySQF/PostgreSQL only). Absent extension
    // is the NORMAL state now, not an error -- but only when the PG engine actually came up.
    if ("AP_db_postgres" call DB_fnc_flag) then {diag_log "extDB3: absent by design -- engine is PySQF/PostgreSQL";};};

_result = "extDB3" callExtension format["9:ADD_DATABASE:%1","Database"];
if(_result != "[1]") exitWith {diag_log "extDB3: Error with Database Connection (check extdb3-conf.ini [Database] block)";};
_result = "extDB3" callExtension format["9:ADD_DATABASE_PROTOCOL:%1:SQL:%2:","Database",AP_sql_id];
if(_result != "[1]") exitWith {diag_log "extDB3: Error adding SQL protocol";};
"extDB3" callExtension "9:LOCK";
_extDB = true;
diag_log "extDB3: Connected to Database";} else {AP_sql_id = uiNamespace getVariable "AP_sql_id";
_extDB = true;
diag_log "extDB: Still Connected to Database";};

// PR10/owner 2026-08-20: the extension being gone must NOT abort server init when the PySQF/PostgreSQL
// engine is live -- this exitWith used to kill EVERYTHING below it (stored procs, config load, economy,
// duty init, the landing flag) on a box that boots fine on apdb. It still aborts when there is truly no
// database at all (no extension AND no PG), which is a dead server whichever way you slice it.
if (!_extDB && {!("AP_db_postgres" call DB_fnc_flag)}) exitWith {AP_server_extDB_notLoaded = true;
publicVariable "AP_server_extDB_notLoaded";
diag_log "extDB: Error checked extDB/logs for more info";};

// extDB3 raw: stored procedures must exist in the DB (see sql/looneybin_schema.sql TODO: procs)
// pg-native P1: the two stored-proc CALLs are gone. resetLifeVehicles was always just this
// UPDATE (the translator inlined the transcribed body; now it is written outright), and
// updateLifeHouses had been `SELECT 1` -- a no-op -- "for years" per the transcription. Garage
// state after boot proves the reset runs (every vehicle active=false).
["UPDATE vehicles SET active = false WHERE active = true",1] call DB_fnc_asyncQuery;

[] call DB_fnc_queryConfig;
// owner 2026-06-13: legacy APS_fnc_govMaint (5-day positional AP_configuration election) REMOVED -- it
// fought the new 7-day case system (different state vars = conflicting governors). govSystemSRV "reload"
// below is now the sole governor authority (seats from gov_state, runs the 7-day term timer).
["load"] call APS_fnc_economySRV;   // LooneyBin Economy: load owner price overrides -> AP_priceOv
["load"] call APS_fnc_atmSkimSRV;   // LooneyBin 2026-07-16: restore ATM skimmers onto the ATM objects (self-delays 20s for mapData)
["reload"] call APS_fnc_govSystemSRV;   // owner 2026-06-13: seat governor from gov_state, rebuild race, arm 7-day term timer
["boot"] call APS_fnc_bjTableSRV;   // define its compileFinal'd AP_fnc_bj* helpers now, before a client can (exits at the identity check)
// Same for the SRV files whose helpers were first defined 25-32 s in (presenceStart / loonyBinReset): "boot"
// matches no case (loonyBin exits on it), so each defines its helpers and returns without acting.
{ ["boot"] call _x } forEach [APS_fnc_shedHelipadSRV, APS_fnc_loonyBinSRV, APS_fnc_houseFurnitureSRV];
// owner 2026-06-24: load the NAMED-FORESKIN registry (foreskins table) -> AP_foreskinReg, broadcast to all clients so
// any held/traded foreskin renders "<name>'s Foreskin". Must exist BEFORE players load their gear (fn_loadGear grants
// foreskin_<uid> via handleInv, which needs virtItemCfg to know the item). Boot-time, server is the sole writer.
// The SERVER'S copy is in localNamespace (audit r2items): fn_virtItemCfg builds the server's item rows from it, and a
// client publicVariable overwrites the AP_foreskinReg global on the server too -- a truncated list would drop every
// foreskin_<uid> row and fn_updateHouseTrunk would then strip those items from house storage. The global is only the
// published copy, derived from the local one and never read back; server_init.sqf restores it if a client overwrites it.
private _fsReg = [];
// QUOTE both cols: DB_fnc_asyncQuery mode 2 `call compile`s the result, so a bare varchar (name="Unknown"/
// "retro") is read as an UNDEFINED VARIABLE -> the whole result fails to compile -> "0 names" + boot error spam.
// QUOTE(name) makes it a string literal; QUOTE(uid) keeps the Steam64 exact (a bareword digit run -> lossy float).
private _fsRows = [format ["SELECT uid, name FROM foreskins"], 2] call DB_fnc_asyncQuery;
if (!isNil "_fsRows" && {_fsRows isEqualType []}) then {{
        if (_x isEqualType [] && {count _x >= 2}) then { _fsReg pushBack [format ["%1", _x select 0], format ["%1", _x select 1]]; };
    } forEach _fsRows;};
localNamespace setVariable ["AP_foreskinReg", _fsReg];
AP_foreskinReg = +_fsReg;
publicVariable "AP_foreskinReg";
diag_log format ["[LooneyBin][foreskin] registry loaded: %1 names", count _fsReg];
// owner 2026-06-18: restore STIMMY CHECKS from server_control.stimmy (single row id=1) so the 10x cartel stimulus
// survives reboots. fn_cartelSRV reads APS_stimmy to multiply the cartel-owner payout; the admin-menu indicator
// reflects it; CLANKR reads the same DB flag to stay quiet about the conjured cash while it's on.
// 2026-09-26: the server reads localNamespace APS_stimmy (no client publicVariable can reach it); AP_stimmy is
// only the display copy for the admin menu -- one client broadcast of it used to turn on 10x cartel credits.
localNamespace setVariable ["APS_stimmy", (parseNumber format ["%1", (["SELECT stimmy FROM server_control WHERE id=1", 2] call DB_fnc_asyncQuery) select 0]) > 0];
AP_stimmy = localNamespace getVariable "APS_stimmy";
publicVariable "AP_stimmy";
// weed.md: wall-clock reference for the house-weed grow timer (nowUnix = AP_bootUnix + serverTime). Set ONCE
// at boot from the DB; serverTime counts real seconds from mission start, so the sum tracks wall clock across
// the session. Stage = floor((nowUnix - plantedUnix)/3600) -> purely timestamp-driven, restart-proof.
// owner 2026-06-15 (#248): SUBTRACT a fixed epoch. SQF numbers are single-precision floats -- a raw unix
// timestamp (~1.75e9) has a ULP of ~128, so `AP_bootUnix + serverTime` SWALLOWED the per-second serverTime
// increments and `str` save/load of plantedUnix lost precision -> plants "stuck" / never advanced. Working in
// (unix - 1.7e9) keeps values ~5e7 (ULP ~4s), so hour-granularity growth + the DB round-trip are exact enough.
// (Old crops stored against the raw timestamp read as age<0 -> reset to Seed and grow from now -- acceptable.)
AP_GH_EPOCH = 1700000000;
AP_bootUnix = (parseNumber format ["%1", (["SELECT extract(epoch from now())::bigint AS u", 2] call DB_fnc_asyncQuery) select 0]) - AP_GH_EPOCH;
publicVariable "AP_bootUnix";
[] spawn { uiSleep 20; ["reload"] call APS_fnc_greenhouseSRV; };   // restore greenhouse crops after houses + buildings exist
[] spawn { uiSleep 20; ["reload"] call APS_fnc_barrelSRV; };
[] spawn { uiSleep 22; ["reload"] call APS_fnc_miningSRV; };   // owner 2026-07-15: restore house mining rigs       // owner 2026-06-21: restore spirit-barrel crops the same way (after houses exist)
// 3D printer (2026-08-22). The players columns are ensured HERE, synchronously and before anyone
// can log in, because fn_queryRequest SELECTs them on every login -- a lazy first-use ensure would
// make the very first login of a fresh database fail the whole payload query, which surfaces to
// the player as the "There Was An Error In Trying To Setup Your Client Info" loop rather than as
// anything resembling a missing column. house_printers is created by APS_fnc_fabSRV's own ensure.
["ALTER TABLE players ADD COLUMN IF NOT EXISTS fab_level smallint NOT NULL DEFAULT 1", 2] call DB_fnc_asyncQuery;
["ALTER TABLE players ADD COLUMN IF NOT EXISTS fab_xp integer NOT NULL DEFAULT 0", 2] call DB_fnc_asyncQuery;
["ALTER TABLE players ADD COLUMN IF NOT EXISTS fab_schematics text NOT NULL DEFAULT ''", 2] call DB_fnc_asyncQuery;
["ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS rig_kind varchar(16) NOT NULL DEFAULT ''", 2, true] call DB_fnc_asyncQuery;   // resource rig identity survives the garage
["ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS recall boolean NOT NULL DEFAULT false", 2, true] call DB_fnc_asyncQuery;   // SUMMON VEHICLE: the one starred recall vehicle per player
[] spawn { uiSleep 22; ["reload"] call APS_fnc_fabSRV; };   // respawn placed fabricators once houses exist
// asyncExec boot smoke: a write that provably hits nothing must answer
// [1, 0, []] -- proving the write path can DISTINGUISH "guard refused" from
// "failed" from "wrote", which is the whole point of the primitive.
[] spawn {
    uiSleep 24;
    private _r = ["UPDATE players_global SET adminlevel = adminlevel WHERE playerid = %s", ["__asyncexec_smoke__"]] call DB_fnc_asyncExec;
    diag_log format ["[apdb] asyncExec smoke: %1 (want [1,0,[]])", _r];
};
// mapdb: MUST run on EVERY mission start, including a soft '#restart' (owner schedule 2026-09-07: soft every 4 h).
// The AP_sql_id block earlier in this file is guarded by uiNamespace, which SURVIVES a mission restart, so it runs once per PROCESS --
// the first live soft restart (21:41:54) skipped it: APS_mapReady stayed nil, every client's map fetch was
// refused after the 120 s grace ("cache not ready, owner N refused") and no map object streamed to anyone.
// Load the delta AFTER the engine decision, never before -- a read that beats it lands on whichever database
// happens to be selected at that instant.
waitUntil { "AP_db_engineDecided" call DB_fnc_flag };
[] spawn { [] call APS_fnc_mapLoad; [] call APS_fnc_territoryLoad; [] call APS_fnc_mapEditPoll; };   // mapdb: table -> memory -> cells; then watch map_meta.rev
[] call APS_fnc_edenLiveBeat;   // Eden Live: player ghosts for the editors (2 s upserts)
[] call APS_fnc_telemetry;      // telemetry: scheduler jobs -> pysqf telemetry.push -> VictoriaMetrics / Grafana (TELEMETRY_SPEC.md)
// SECURITY boot assert (2026-09-26): a client's publicVariable overwrites a missionNamespace global HERE
// too, so any code-typed global that is not compileFinal'd is server code execution the next time it is
// called. Every inline helper is compileFinal'd where it is defined; this names any that still is not,
// once the boot definers have run (the latest, shedHelipad/loonyBin presence, fires at +25 s).
[] spawn {
    uiSleep 90;
    private _bad = (allVariables missionNamespace) select {
        private _v = missionNamespace getVariable _x;
        !isNil "_v" && {_v isEqualType {}} && {!isFinal _v} && {(_x select [0, 4]) isNotEqualTo "bis_"}
    };
    // Enforce, then report (see core/init.sqf): seal our own non-final code globals in place, report only failures.
    { missionNamespace setVariable [_x, compileFinal (missionNamespace getVariable _x)]; } forEach _bad;
    _bad = _bad select { !isFinal (missionNamespace getVariable _x) };
    if (_bad isNotEqualTo []) then {
        ["-SEC-", objNull, format ["BOOT ASSERT: %1 code global(s) not compileFinal: %2", count _bad, _bad select [0, 60]]] call APS_fnc_logIt;
    };
};

// Free build is a TESTING override and deliberately does not persist: set false on every boot so
// a session that forgot to turn it off cannot carry it into the next one.
AP_fabFreeBuild = false; localNamespace setVariable ["AP_fabFreeBuild", false]; publicVariable "AP_fabFreeBuild";   // server reads localNamespace (Lsec-0-1)
[] spawn { uiSleep 25; ["presenceStart"] call APS_fnc_shedHelipadSRV; };
[] spawn { uiSleep 30; while { true } do { [] call APS_fnc_bonesDeliver; uiSleep 8; }; };
[] spawn { uiSleep 45; while { true } do { [] call APS_fnc_offlineMsgDeliver; uiSleep 12; }; };   // owner 2026-08-11: hand queued texts to players who came back   // owner 2026-07-15: deliver Ben Bones AI replies
// LooneyBin (owner 2026-07-15): PUBLIC rebel weapon airdrops -- every 45-90 min, only when 4+ players are on.
[] spawn {uiSleep 600;   // never within 10 min of a restart
    while { true } do {uiSleep (2700 + random 2700);
        if ((count call AP_fnc_realPlayers) >= 4) then { ["drop"] call APS_fnc_airdropEventSRV; };};
};   // owner 2026-07-15: REBUILD bought helipads at boot (after replace_sheds +6s). This call was never wired -> "helipads don't persist": pads spawned on buy, houses.helipad=1 was written, and nothing ever re-spawned them after a restart.
// LooneyBin (owner 2026-07-17): HOURLY SUPPLY BOMBER -- every ~hour, fly the WEST or EAST hand-drawn route and drop
// ONE sealed crate (10-min lock -> unlock + fill; drop site is a redzone; Ben Bones texts everyone). Plane has no
// map marker. On the single-wheel scheduler (singleevh). Pop-gated like the rebel airdrop; SRV self-picks the route.
["supplyBomberHourly", {params ["_st"];
    if ((count call AP_fnc_realPlayers) < 4) exitWith {};
    [[]] spawn APS_fnc_eventSupplyBomberSRV;   // [] -> SRV self-selects WEST/EAST; detached so the job returns fast
}, 3600, false, true] call AP_fnc_schedule;
// (apStress dev-trigger removed 2026-07-18 -- was spamming the dev server during rig testing)

if(!hasInterface) then {};


// owner 2026-06-18 (#335): GANG-VEHICLE garage hygiene at boot. (1) DEDUPE -- fn_gangGarageStore used to INSERT a
// fresh row on every store WITHOUT clearing the old active='1' row, so each pull->store left a zombie duplicate
// (one plate had 4 rows). Keep only the newest row per (gang_id, plate). (2) UNIQUE key so the store's new UPSERT
// (ON DUPLICATE KEY UPDATE) folds into that one row instead of dup'ing. (3) GARAGE-RETURN -- a hard restart wipes
// the world object and fn_restoreVehicles only relinks PERSONAL-table plates, so an OUT gang vehicle used to POOF
// (gone from world + stuck active='1', which the pull menu (active='0') hides). Reset every active='1' back to '0'
// so they return to the gang garage (re-pullable) instead of being lost. Order matters: dedupe (blocking) must
// finish before ADD UNIQUE, else the ALTER fails on the existing dupes -> no key -> upsert can't de-dup. Respawn-
// at-position is a logged follow-up (needs the fragile vehicle_mem restore to learn gang plates + gang-key relink).
[] spawn {uiSleep 8;
    ["DELETE FROM gang_vehicles gv USING (SELECT gang_id, plate, MAX(id) AS keep_id FROM gang_vehicles GROUP BY gang_id, plate) m WHERE gv.gang_id=m.gang_id AND gv.plate=m.plate AND gv.id < m.keep_id", 2] call DB_fnc_asyncQuery;
    ["CREATE UNIQUE INDEX IF NOT EXISTS uq_gang_plate ON gang_vehicles (gang_id, plate)", 2] call DB_fnc_asyncQuery;
    ["UPDATE gang_vehicles SET active = false WHERE active = true"] call DB_fnc_asyncQuery;
    diag_log "[LooneyBin][gangveh] boot hygiene done: deduped + unique key + garage-returned out vehicles";};

AP_group_list = [];
publicVariable "AP_group_list";

// LooneyBin: 2020 client reads these server->client globals during init (gov/weather/events/HUD);
// the 2017-derived server never set them -> "Undefined variable" spam + glitchy HUD on spawn.
// Publish inert defaults so client init runs clean (real feature logic can populate later).
// AP_instance_id: per-boot session token. Client compares it to DB-stored session ids to detect
// server restarts (gov elections/pardons, quest loot) and uses it as a
// profileNamespace key element. Never set on this server -> nil -> govSystem _serverRestarted /
// _newElection threw. Make it a unique string each boot, broadcast to clients.
AP_instance_id = round(diag_tickTime * 1000) + floor(random 99999);
publicVariable "AP_instance_id";
// The server's governor copy is localNamespace (APS_fnc_govSystemSRV); this global is the display copy, restored by
// server_init.sqf's PVEH if a client publishes it. NOTE (owner call pending): this runs AFTER the govSystemSRV "reload"
// above, so it empties the seat that reload just loaded from gov_state -- kept as-is, it predates the r2gov fix.
localNamespace setVariable ["SRV_governorData", []]; SRV_governorData = localNamespace getVariable "SRV_governorData"; publicVariable "SRV_governorData";
SRV_houseOnFire = [];                  publicVariable "SRV_houseOnFire";
SRV_wcWeather = [0,0,0,0];             publicVariable "SRV_wcWeather";
SRV_ufoCrash = [false,objNull,-99999,[]];  publicVariable "SRV_ufoCrash";  // [active(Bool),obj,crashTime,data]; idx0 read as Bool by fn_initCiv:166 + fn_ufoCrash (was objNull -> "Type Object expected Bool" on every connect)
SRV_winterEvent = [objNull,-99999];    publicVariable "SRV_winterEvent";   // fn_inventoryOpened santa-loot check reads select 1 (timestamp); was undefined
SRV_enabledSeasonalEvents = [];        publicVariable "SRV_enabledSeasonalEvents";
// AP_seasonalEvent: client (initPlayerLocal:190) does `if (AP_seasonalEvent select 1)` (Bool
// enabled-flag) then `switch (AP_seasonalEvent select 2)` (event-name String). Empty [] -> select 1
// nil -> threw at spawn. Default [_, enabled=false, name=""] so the seasonal block skips clean.
AP_seasonalEvent = [false,false,""];  publicVariable "AP_seasonalEvent";
AP_topWealth = [];                   publicVariable "AP_topWealth";
AP_topDonor = [];                    publicVariable "AP_topDonor";
AP_radio_civ = radioChannelCreate [[0, 0.95, 1, 0.8], "Side Channel", "%UNIT_NAME", []];                   
publicVariable "AP_radio_civ";
// AP_radio_med: cop/medic side radio. manageSidechat evaluates `else {AP_radio_med}` for any
// non-civ BEFORE the west early-exit, so cops hit "undefined AP_radio_med" without this default.
AP_radio_med = "";                   publicVariable "AP_radio_med";
AP_allPointsBulletin = [];           publicVariable "AP_allPointsBulletin";
// More server->client globals the 2020 client reads during side-init / EHs. Inert-but-typed
// defaults so client code doing `select N` / `param[N]` on them can't throw and hang init.
// SRV_mobileHQ: client does `SRV_mobileHQ param[1,objNull]` (HQ truck) + `select 3`; needs >=4 elems.
// SRV_mobileHQ: client param[1] = HQ truck; client "setupShops" reads `select 3` as
// [level, gearNPC, vehicleNPC] then derefs each -> index 3 must be a 3-array, not objNull.
// index 2 = ACTIVE bool: the "Setup Mobile HQ" addAction condition does `!(SRV_mobileHQ select 2)` -- the old
// objNull there threw "Type Object, expected Bool" every frame (CLANKR flagged the burst). Match fn_srvMobileHQ
// ([setupTime, truck, activeBool, [level,gearNPC,vehNPC]]): time number @0, false @2.
SRV_mobileHQ = [-1800,objNull,false,[0,objNull,objNull]];  publicVariable "SRV_mobileHQ";
// SRV_gangBoatFortressData: client does `!(... select 0)` / `if (... select 0)` -> select 0 = Bool.
SRV_gangBoatFortressData = [false,[],[]];                publicVariable "SRV_gangBoatFortressData";
// SRV_duelArenaData + randomized_life_group_list: NEVER initialized -> onPlayerKilled (death) threw
// "Undefined variable" on both BEFORE the DeathScreen dialog + doRespawn ran -> with respawnDelay=0 the
// player dropped straight to the missing respawn_west marker = debug island (no revive/medic screen).
// onPlayerKilled reads SRV_duelArenaData select 0/1/2/3/5; group list is a gang array (set by lock/unlockGroup).
SRV_duelArenaData = [false,-1800,"","",objNull,[0,0]]; publicVariable "SRV_duelArenaData";
randomized_life_group_list = [];                       publicVariable "randomized_life_group_list";
// AP_adminEvent: client does `if (AP_adminEvent select 2 != 5) exitWith{}` + `select 3`; >=4 elems,
// select 2 != 5 so the admin-event display path early-exits cleanly until a real event broadcasts.
AP_adminEvent = [false,0,0,0];                         publicVariable "AP_adminEvent";  // [0]=Bool (onPlayerKilled does `select 0 && ...`); [2]=mode number
// LooneyBin (#41 ROOT): these were only ever pushBack/set on-demand, so on a fresh boot they are
// UNDEFINED on clients -> fn_spawnPointCfg lines 44-45 throw -> spawn list build breaks -> debug island.
// BUGS.md #98: boot shape was [false,false] (2 elems) but the client drill gate reads `select 6`
// (cops required) -> out-of-range error silently killed "Start Drilling Door". Full 7-slot shape per
// fn_jewelryEmporiumSRV: [lastBreach, active, safeDrilled, safeWelded, casesLootable, 0, copsRequired].
if (isNil "SRV_jewelryEmporiumSRV") then { SRV_jewelryEmporiumSRV = [-1800, false, false, false, false, 0, 6]; }; publicVariable "SRV_jewelryEmporiumSRV";
// LooneyBin batch-2 federal/event state (2026-06-09):
// SRV_evidence_status = [hasEvidence, defensesUp, unused, lastAttackTime, copsRequired] (evidence lockup)
SRV_evidence_status = [false, true, 0, -1800, 2];      publicVariable "SRV_evidence_status";
SRV_evidencePool = []; SRV_evidenceWeps = [];
SRV_lastMedSupply = -900;                              publicVariable "SRV_lastMedSupply";   // medDrop item 15-min global cooldown
// SRV_loonyBinData = [lastBreach, breached, 0, keycode, tombLocked, remainsObj, copsRequired] (the namesake heist)
// owner 2026-06-18: copsRequired = 0 -- TEST setting so the breach can be triggered solo (intended live value = 2).
// REVERT before public -- tracked in launch.md.
// The server's own copies live in localNamespace (APS_fnc_loonyBinSRV reads only those, audit r2heist); the globals
// are display copies for clients, which a client publicVariable can overwrite.
localNamespace setVariable ["SRV_loonyBinData", [-2700, false, 0, "", true, objNull, 2]];
SRV_loonyBinData = +(localNamespace getVariable "SRV_loonyBinData");   publicVariable "SRV_loonyBinData";
// Malden rework 2026-08-01: the new phase clock lives here. Every Malden heist prop is a client-local
// mapData object the server has no handle on, so the phases are STATE, not object variables.
// [trolleyBlown, doorFuseEndsAt, doorBlown, dbEndsAt, dbDone, tombOpen, firewall, trolleyArming]
localNamespace setVariable ["AP_lbState", [false, 0, false, 0, false, false, false, false]];
AP_lbState = +(localNamespace getVariable "AP_lbState");   publicVariable "AP_lbState";
// Restart cycle (2026-06-09): serverStartTime/serverCycleLength/serverRestartLock were NEVER defined,
// so every restart-aware feature was dead (anywhere-jail near restart, shop/tax restart locks,
// fn_notifyServerRestart) and clients reading the bare serverRestartLock script-errored. The actual
// restart is still done by the host/loonybot (!srv hardr) -- this just drives the in-game countdown QoL.
serverStartTime  = serverTime;                       publicVariable "serverStartTime";
AP_restartPeriod = 4 * 3600;   // owner 2026-06-13: AUTO-RESTART every 4 HOURS, ALWAYS HARD (graceful save -> restart_watchdog). The 2h soft cycle was removed.
serverCycleLength = missionNamespace getVariable ["AP_restartPeriod", 4 * 3600];  publicVariable "serverCycleLength";
serverRestartLock = false;                           publicVariable "serverRestartLock";
// SRV_convoy_status = [active, lastAttack, level, copsExtra] (Altis Shipping convoy robbery)
SRV_convoy_status = [false, -1800, 0, 0];            publicVariable "SRV_convoy_status";
AP_event_queue = [];   // admin-event participants (APS_fnc_eventParticipants/APS_fnc_addToEvent -- was never initialized)
// owner 2026-06-17 (#330): REMOVED the per-boot `DELETE FROM votes`. The rebuilt 7-day-term gov system
// (govSystemSRV) PERSISTS votes across restarts -- "reload" rebuilds the candidate tallies from this table,
// and votes are cleared ONLY when a governor is SEATED (AP_fnc_govSeat = a new term). Wiping every boot meant
// votes never survived a restart -> "voted yesterday, 0 votes today" (#330). The one-vote-per-election gate is
// per-TERM (cleared at govSeat), not per-session.
SRV_prisonData = [-1800, false];   publicVariable "SRV_prisonData";   // [lastBreak, active] -- was NEVER defined; clients read slot 1 (jailMe / doPrisonBreak / activeFederalEvent)
// owner 2026-07-28: per-RUN "this prison break has already armed the 15-minute cross-heist lockout" latch.
// TRUE means "do not arm". Set FALSE in exactly ONE place -- APS_fnc_handlePrisonBreak case 1, alongside
// the SRV_prisonData stamp and BELOW all five of that case's guards -- and set back TRUE by whichever of
// the three prison end paths (startPrisonBreak's natural end, the cop stop, the 1200s watchdog) fires
// first, so a break arms SRV_lastRobbery exactly once no matter how it ends.
// Server-local BY DESIGN: no client reads it, so it is deliberately NOT publicVariable'd. Do NOT stuff it
// into a spare SRV_prisonData slot -- fn_handlePrisonBreak reads `SRV_prisonData param [2, 1]` as the cop
// requirement, and a third element would be silently reinterpreted as that number.
// Seeded TRUE so a fresh boot cannot arm anything before a break has actually run. Every reader spells it
// `missionNamespace getVariable ["AP_prisonEndArmed", true]`, so this seed is documentation rather than
// load-bearing: a missing var reads as "already armed" and arms NOTHING, which is the safe direction --
// an arm nobody earned is a 15-minute server-wide denial of every major heist.
AP_prisonEndArmed = true;

// LooneyBin (owner, 2026-06-11): MAX-VERBOSITY logging. Global flag any future verbose gate can read, + a
// server-side ScriptError handler so EVERY script error on the server (mission + @AP_server) is dumped to
// console.log with its full callstack (tagged [LB-SCRIPTERR]). Returns false -> engine still logs normally.
AP_verboseLog = true; publicVariable "AP_verboseLog";
addMissionEventHandler ["ScriptError", { diag_log format ["[LB-SCRIPTERR][server] %1", _this]; false }];

// ND WARKILL PROOF (audit 2026-09-26, mints/docsopen-0-0). APS_fnc_ndSRV pays a client's "warkill" credit only
// against a player kill the SERVER saw: one kill files one proof for the killer, one proof buys one credit, and a
// proof is good for 10 minutes. localNamespace, because a client publicVariable cannot reach it. A death the engine
// attributes to nobody (killer = the victim, e.g. a scripted setDamage) files nothing, so it pays no ND.
localNamespace setVariable ["AP_ndKillProof", createHashMap];
// DEATH STAMP (r2logs): APS_fnc_createItem takes a "money" pile only as a death drop, but respawnDelay=0 and the
// Killed EH is spawned, so the drop arrives from the caller's NEW, living unit and `alive` cannot tell. Stamp the
// owner of every client-local man the server sees die; createItem reads (and consumes) it.
localNamespace setVariable ["AP_diedAt", createHashMap];
addMissionEventHandler ["EntityKilled", {
    params ["_unit", "_killer", "_instigator"];
    if (_unit isKindOf "CAManBase" && {owner _unit > 2}) then { (localNamespace getVariable ["AP_diedAt", createHashMap]) set [owner _unit, diag_tickTime]; };
    private _k = if (isNull _instigator) then { effectiveCommander _killer } else { _instigator };
    if (isPlayer _unit && {isPlayer _k} && {_k isNotEqualTo _unit}) then {
        private _proofs = localNamespace getVariable ["AP_ndKillProof", createHashMap];
        private _u = getPlayerUID _k;
        _proofs set [_u, ((_proofs getOrDefault [_u, []]) select { serverTime - _x < 600 }) + [serverTime]];
    };
}];

// LooneyBin (owner, 2026-06-11): alert EVERY online MaxSec officer with the "Federal Event" admin-style popup
// (+ audible ping) whenever ANY federal event STARTS -- bank, fed reserve, evidence lockup, PRISON BREAK,
// convoy, Loony Bin, jewelry. The federaleventcop message style existed in fn_handleMessage but was wired to
// nothing. Single server-side edge-detector: same active predicates fn_activeFederalEvent uses; fires once on
// each event's false->true transition. nil-safe reads so var-load order/timing can't break it.
// singleevh.md Phase 1b: fed-event -> MaxSec alert edge-detector migrated onto the single-wheel scheduler
// (id "fedAlert", 5s). Cross-iteration state (the _events config + the _prev false->true edge tracker) lives
// in the per-job _st; the one-shot boot settle (uiSleep 30 + seed _prev with current state) runs on the first
// fire only. Flag OFF => the original loop runs byte-for-byte (else branch) = ZERO behavior change.
["fedAlert", {params ["_st"];
    if !(_st getOrDefault ["init", false]) then {
        uiSleep 30;   // let event vars + clients settle after boot (and don't alert for state that was already live)
        private _events = [
            ["Federal Reserve robbery",   { ((missionNamespace getVariable ["AP_fed_robbed", [false]]) param [0, false]) }, "fed",      { getMarkerPos "fed_reserve" }],
            ["Bank robbery",              { ((missionNamespace getVariable ["AP_bank_robbed", [false]]) param [0, false]) }, "bank",     { getMarkerPos "AP_bank_door" }],
            ["Evidence Lockup raid",      { !((missionNamespace getVariable ["SRV_evidence_status", [false, true]]) param [1, true]) }, "evidence", { [20898.6, 19221.7, 0] }],
            ["Prison Break",              { ((missionNamespace getVariable ["SRV_prisonData", [0, false]]) param [1, false]) }, ""],
            ["Prisoner Transport convoy", { ((missionNamespace getVariable ["SRV_convoy_status", [false]]) param [0, false]) }, "shipping", { [] }],
            ["Loony Bin breach",          { ((localNamespace getVariable ["SRV_loonyBinData", [0, false]]) param [1, false]) }, "loonybin", { [24096.3, 15532.6, 0] }],
            ["Jewelry Emporium robbery",  { ((missionNamespace getVariable ["SRV_jewelryEmporiumSRV", [0, false]]) param [1, false]) }, "jewelry",  { [20720, 16620, 0] }]
        ];
        _st set ["events", _events];
        _st set ["prev", _events apply { call (_x select 1) }];   // seed with current state -> no spam for events already active at boot
        _st set ["init", true];};
    private _events = _st getOrDefault ["events", []];
    private _prev   = _st getOrDefault ["prev", []]; {private _active = call (_x select 1);
        if (_active && {!(_prev select _forEachIndex)}) then {
            // admin-style "Federal Event" popup + ping to every online MaxSec officer (side west)
            [[(_x select 0), "federaleventcop"], "AP_fnc_handleMessage", west, false, false] spawn AP_fnc_MP;
            // owner 2026-07-18: the standalone mining-component crate is RETIRED -- components now spawn
            // INSIDE each heist's own loot (loonyBin gold case / fed + bank cash case / jewelry display case).
            ["-FEDALERT-", objNull, format ["MaxSec alerted: %1 started", (_x select 0)]] call APS_fnc_logIt;};
        _prev set [_forEachIndex, _active];} forEach _events;}, 5, false, true] call AP_fnc_schedule;

[] spawn {
    // owner 2026-06-13: AUTO-RESTART scheduler (every serverCycleLength = 2h). Countdown is delivered as
    // admin-message BOXES (APS_fnc_adminMsg -> clientMessage type 5 "adminall" = the phone-admin box + sound).
    // DEFAULT = SOFT restart: instance 1 -> "#restart" (players bounced to lobby, mission reloads, NO forced
    // disconnect). If server_control.hard_pending=1 (operator staged fixes that need a fresh PBO) -> HARD:
    // flag restart_now=1 so the external restart_watchdog relaunches the PROCESS. Every restart is logged to
    // restart_log (powers the owner-connect tally / until-10am count). Self-heals: if no restart lands within
    // 3 min past T-0 (watchdog down / endMission no-op), clear the lock + extend a cycle so features don't freeze.
    private _pnum = { parseNumber (format ["%1", _this]) };
    private _offsets = [[3600, "1 Hour until RESTART"], [1800, "30 Minutes Till RESTART"],
        [900,  "15 minutes till RESTART"], [600,  "10 minutes till RESTART"],
        [300,  "5 minutes till RESTART -- SYNC NOW"], [120,  "2 minutes until RESTART -- SYNC NOW"],
        [60,   "1 minute until RESTART (you should have synced)"]];
    private _sent = [];
    private _fired = false;
    while {true} do {uiSleep 15;
        private _left = serverCycleLength - (serverTime - serverStartTime);
        // T-5 feature lock + the press-Y SYNC DATA client prompt
        if (_left <= 300 && {!serverRestartLock}) then {serverRestartLock = true; publicVariable "serverRestartLock";
            [[], "AP_fnc_notifyServerRestart", -2, true, false] spawn AP_fnc_MP;
            // HOLD'EM DRAINS AT THE FEATURE LOCK, not at T-0. AP_holdemTable is memory: a buy-in has
            // already left a real bankacc row, so a stack still sat on a seat when the watchdog
            // pkills the process is money that exists nowhere. This is the announcement point --
            // players have just been told -- and it gives the bank writes five minutes of headroom
            // rather than racing the save. The drain aborts any live hand and refunds it; the flag
            // stops a fresh one being dealt into the last five minutes and stops anyone re-sitting.
            if (!isNil "AP_holdemTable") then {
                SRV_holdemCloseReason = "server restart";
                SRV_holdemEnabled = false; publicVariable "SRV_holdemEnabled";
                ["drain", ["server restart"]] call APS_fnc_holdemSRV;
            };}; {_x params ["_off", "_msg"];
            if (_left <= _off && {!(_off in _sent)}) then {_sent pushBack _off;
                ["SERVER RESTART", _msg] call APS_fnc_adminMsg;};} forEach _offsets;
        // uptime guard (owner 2026-06-14): never fire a restart in the first 20 min of uptime. Defense against
        // a premature T-0 if serverTime/serverStartTime are ever off at boot -- the restart only runs once the
        // server has genuinely been up a while, so it can't "restart right after the warning" on a fresh boot.
        if (_left <= 0 && {!_fired} && {(serverTime - serverStartTime) > 1200}) then {_fired = true;
            // owner 2026-06-13: ALWAYS HARD now (the 2h soft/endMission cycle was removed). GRACEFUL SAVE first
            // (vehicle_mem incl. AP_vinv trunks + storage), let the writes flush, THEN hand
            // to the restart_watchdog (server_control.restart_now=1 -> it pkills + run-boot2 = fresh process).
            // owner 2026-06-18: hard_pending=0 here -> the watchdog reloads the DEPLOYED PBOs as-is (NO_REPACK,
            // no code deploy). Staged source only goes live via the in-game UPDATE button or a manual run-boot2.
            // owner 2026-06-19 (kit-loss-on-restart cluster #408/#409/#413/#414/#416/#417/#418): FORCE every online
            // client to flush gear+position+money NOW, before the snapshot. Nothing on the server side
            // snapshots live client state -- saveVehicles persists the WORLD -- so a player
            // whose last auto-save predated the restart reverted on rejoin (= "lost my kit" / respawn menu). Clupdate-
            // Request is the full client save; the server is CfgRE-exempt so this server->client MP runs (same path as
            // the T-55 notifyServerRestart sync, just guaranteed here for late-joiners + anyone the countdown missed).
            [[], "AP_fnc_ClupdateRequest", -2, false, false] spawn AP_fnc_MP;
            uiSleep 8;   // let the client row-writes land before the vehicle snapshot + watchdog handoff
            private _h = [] spawn DB_fnc_saveVehicles;
            waitUntil { scriptDone _h };
            uiSleep 35;   // let extDB3 commit the async save queue before the watchdog kills the process
            // restart_log is written by the watchdog with the REAL mode (soft/hard) -- owner 2026-09-07: soft every 4 h, hard every 12 h
            ["UPDATE server_control SET restart_now=1, hard_pending=0 WHERE id=1"] call DB_fnc_asyncQuery;
            ["SERVER RESTART", "Restarting now -- back to the lobby in ~30s (if you get disconnected, rejoin from the browser)."] call APS_fnc_adminMsg;
            diag_log "[LooneyBin][autorestart] T-0 -> saved + restart_now=1 (the watchdog picks soft/hard: owner 2026-09-07 soft every 4 h, hard at 12 h)";};
        if (_fired && {_left <= -180}) then {
            // SAFETY NET: 3 min past T-0 and the process never relaunched -> the restart_watchdog didn't act
            // (it's down, or busy). Re-assert restart_now=1, clear the lock + extend ONE cycle so nothing stays
            // frozen, and re-arm the countdown so the NEXT cycle tries again (rather than hanging forever).
            ["UPDATE server_control SET restart_now=1 WHERE id=1"] call DB_fnc_asyncQuery;
            serverRestartLock = false; publicVariable "serverRestartLock";
            serverCycleLength = serverCycleLength + AP_restartPeriod; publicVariable "serverCycleLength";
            _sent = []; _fired = false;
            ["SERVER", "Restart is taking a moment -- standby."] call APS_fnc_adminMsg;
            diag_log "[LooneyBin][autorestart] watchdog didn't relaunch within 3min -> re-asserted restart_now=1 (lock cleared, cycle extended)";
        };};};
// owner 2026-06-19 (persistence cluster #335/#274/#319/#192/#190): PERIODIC vehicle save. The graceful save
// only ran on a SCHEDULED restart -- manual hard restarts (deploys, !srv hardr, a raw restart_now=1) and
// crashes pkilled the process with NO save, losing every spawned/left-out vehicle. Snapshot vehicle_mem every
// 8 min so the world survives any ungraceful exit (lose <=8 min, not everything). Lightweight: _vehiclesOnly
// skips the heavy player/storage/gang flush. Pairs with fn_restoreVehicles no longer wiping vehicle_mem.
// singleevh.md Phase 1c: periodic vehicle-save migrated onto the single-wheel scheduler (id "vehSave",
// 480s). The one-shot boot settle (uiSleep 300, so saveVehicles never snapshots a half-restored world --
// saveVehicles DELETEs then re-fills vehicle_mem, so an early snapshot could wipe it) runs on the FIRST
// fire only; the periodic body keeps its own blocking DB saveVehicles/updateCaptures. Flag OFF => the
// original loop runs byte-for-byte (else branch) = ZERO behavior change.
["vehSave", {params ["_st"];
    if !(_st getOrDefault ["init", false]) then { uiSleep 300; _st set ["init", true]; };   // let the boot restore settle before the first snapshot
    if !("AP_server_training" call DB_fnc_flag) then {[true] call DB_fnc_saveVehicles;
        [] call DB_fnc_updateCaptures;   // #368: persist cartel/turf ownership changes too (was graceful-restart-only)
    };}, 480, false, true] call AP_fnc_schedule;

// Ambient earthquakes (2026-06-09): wires the dormant AP_fnc_earthquakeClient. Rare flavor event --
// every 2-4 h a light-to-moderate quake centered on a random land position.
[] spawn {while {true} do {uiSleep (7200 + random 7200);
        private _center = [random worldSize, random worldSize, 0];
        if (!surfaceIsWater _center) then {private _mag = selectRandom [1, 1, 2];
            [[_mag, _center], "AP_fnc_earthquakeClient", -2, false, false] spawn AP_fnc_MP;
            diag_log format ["[LooneyBin] ambient earthquake mag %1 at %2", _mag, _center];};};};
// evidence laptop: nothing in the mission defines the global `evidenceLaptop` -> find or create it at
// the lockup so the whole evidence chain (hack/repair/cop-redeploy) has its object, and publish for JIP.
[] spawn {uiSleep 20;
    private _domePos = [20898.6, 19221.7, 0];
    private _laptop = nearestObject [_domePos, "Land_Laptop_unfolded_F"];
    if (isNull _laptop || {_laptop distance2D _domePos > 60}) then {_laptop = "Land_Laptop_unfolded_F" createVehicle _domePos;
        _laptop setPosATL [20893.5, 19224.0, 0];
        _laptop allowDamage false;};
    _laptop setVariable ["AP_laptopstatus", 1, true];
    missionNamespace setVariable ["evidenceLaptop", _laptop, true];
    diag_log format ["[LooneyBin][evidence] laptop published at %1", getPosATL _laptop];
    // lock the lockup dome at boot -- nothing else seals door 3 until a cop "secures" mid-event,
    // so after every restart the evidence dome stood open to anyone
    private _dome = nearestObject [_domePos, "Land_Dome_Big_F"];
    if (!isNull _dome) then {_dome setVariable ["AP_bombPlanted", false, true];
        _dome setVariable ["AP_evidenceOpen", false, true];
        _dome setVariable ["AP_vaultBreached", false, true];
        _dome setVariable ["bis_disabled_Door_3", 1, true];
        _dome animate ["door_3_rot", 0];
        diag_log "[LooneyBin][evidence] dome sealed at boot";};};
// house furniture: presence-spawn manager -- only spawns a house's furniture while the homeowner (or, for a
// gang house, any gang member) is online; despawns when nobody's home. Runs after the gang re-tag below so
// buildings already carry AP_house_gang.
[] spawn {uiSleep 32;
    ["presenceStart"] call APS_fnc_houseFurnitureSRV;};
// gang houses: re-tag each persisted gang building (gangs.house_pos) with AP_house_gang so members'
// initGang (which waits on that var) finds it after every restart. Houses are objects by ~20s.
[] spawn {uiSleep 25;
    private _rows = ["SELECT id, house_pos FROM gangs WHERE house_pos IS NOT NULL", 2, true] call DB_fnc_asyncQuery;
    if !(_rows isEqualType []) exitWith {}; {private _gid = _x param [0, -1];
        private _pos = parseSimpleArray format ["%1", _x param [1, "[]"]];
        if (_pos isEqualType [] && {count _pos >= 2}) then {
            // owner 2026-06-14 (#208): nearestBuilding (ANY building type) instead of nearestObjects["House_F"].
            // An industrial SHED gang-HQ (Land_i_Shed_Ind_F) is NOT isKindOf "House_F", so the old filter never
            // tagged shed HQs -> shed gang buildings gave members no keys/marker/spawn/pull. Distance-gate so a
            // deleted HQ can't tag a random nearby structure.
            private _b = nearestBuilding _pos;
            if (!isNull _b && {(_b distance _pos) < 14}) then {_b setVariable ["AP_house_gang", _gid, true];} else {
                diag_log format ["[LooneyBin][gangHouse] no building at %1 for gang %2", _pos, _gid];};};} forEach _rows;
    diag_log format ["[LooneyBin][gangHouse] re-tagged %1 gang building(s)", count _rows];};
// house tax (2026-06-09): tag every owned house with AP_house_tax = [overdue, canPayTax, playtime(min),
// lastPayed(days)] (all the client tax menu reads), then +5 playtime per 5 min while the owner is online.
// Pay/reset handled by APS_fnc_houseTaxSRV. Overdue threshold = 14 days unpaid.
// singleevh.md Phase 1c: house-tax tagger migrated onto the single-wheel scheduler (id "houseTax", 300s).
// The closures (_decKeys / _tagHouses) are redefined each fire -- pure code with no captured mutable state,
// so this is behaviorally identical. The one-shot boot setup (uiSleep 30 settle so buildings have streamed,
// then the ALTER TABLE + the first tag pass) runs on the FIRST fire only via exitWith; every later fire does
// the +5 playtime UPDATE + a re-tag. _tagHouses calls _decKeys, both privates of the SAME callback scope
// (the exact call-scope sharing the original relied on). Flag OFF => the original loop runs byte-for-byte
// (else branch) = ZERO behavior change.
["houseTax", {params ["_st"];
// decode an mres-encoded keyholders blob the same way fn_receiveHouses does
private _decKeys = {params [["_v", "", [""]]];
    if (_v isEqualTo "" || {_v isEqualTo "NULL"}) exitWith {[]};
    private _a = [_v] call DB_fnc_mresToArray;
    if (typeName _a == "STRING") then { _a = parseSimpleArray (format ["%1", _a]); };
    if (isNil "_a" || {!(_a isEqualType [])}) then { _a = []; };
    _a};
private _tagHouses = {
    // owner 2026-06-20 (mres decode spam -- 76 errors/5min): keyholders is an mres/str2-encoded blob whose
    // OWN outer double-quotes are the string delimiters asyncQuery's call-compile consumes (the project RULE,
    // see fn_queryRequest:56-58). QUOTE()-ing it added a SECOND quote layer -> mresToArray got `"[[``...``]]"`
    // with literal outer quotes -> its inner `call compile` went nil -> "Undefined variable: _array" x76 every
    // 5-min tag pass AND the keyholder list never decoded -> shared-house keys never restored after a restart
    // (#307). fn_receiveHouses reads keyholders BARE (fn_queryHouses:15) and decodes fine with 0 errors -> match
    // it exactly: bare column, no QUOTE/COALESCE (the _decKeys guard already handles ""/"NULL").
    // owner 2026-07-04: classname MUST be QUOTE()'d. extDB3 returns varchars BARE and DB_fnc_asyncQuery
    // call-compiles the whole result string, so an unquoted `Land_u_Shed_Ind_F` compiled as an UNDEFINED
    // VARIABLE -> that result slot nil'd -> _x param [7,""] fell back to "" for EVERY shed row -> _dbCls=""
    // -> _isShedRow=false -> the entire shed-resolution branch below was DEAD (the b0125 fix never ran).
    // Same footgun the code documents at fn_getVehicles (QUOTE(classname) / QUOTE(COALESCE(mods,'[]'))).
    // keyholders stays BARE on purpose -- it is an mres blob that carries its own quotes (see line ~466).
    private _rows = ["SELECT id, worldspace, tax_playtime, COALESCE((now()::date - tax_paid::date), 0) AS tax_days, owners, oid, keyholders, COALESCE(classname,'') AS classname, vcap, phys_cap, keycap, barrel, greenhouse, leadcontainer, locked FROM houses", 2, true] call DB_fnc_asyncQuery;
    if !(_rows isEqualType []) exitWith { 0 };
    private _n = 0; {private _ws = parseSimpleArray format ["%1", _x param [1, "[]"]];
        if (_ws isEqualType [] && {count _ws >= 2}) then {
            // owner 2026-07-04: resolve the House_F whose TYPE matches the DB classname (param 7), not just
            // the nearest. Some worldspaces have MULTIPLE House_F -- most notably a buyable industrial shed
            // (Land_i_Shed_Ind_F, createVehicle'd by replace_sheds) whose spot ALSO holds the banished derelict
            // Land_u_Shed_Ind_F. A bare `param [0]` grabbed the wrong one, so the owned shed never got
            // AP_homeOwner -> "buy your own shed" while inventory (keyed on AP_house_keys / AP_vehicles)
            // still worked. Fall back to the nearest House_F for old rows with no stored classname.
            private _dbCls = format ["%1", _x param [7, ""]];
            // owner 2026-07-04: SHED rows are special. The derelict Land_u_Shed_Ind_F lingers at every buyable
            // shed spot (terrain object -- can't be deleted, hideObjectGlobal only hides it, setPos won't move
            // a static map object), so a bought shed's worldspace sits ON the hidden derelict while the intact,
            // createVehicle'd Land_i_Shed_Ind_F stands at the SAME spot (both House_F, both dist 0). A plain
            // nearest-House_F grab is a coin-flip that keeps landing on the derelict. For a shed row, resolve
            // the intact by its EXACT class (NOT a "House_F" filter -- Land_i_Shed_Ind_F is not reliably
            // isKindOf "House_F" per the gang-tagger #208 note above) and force the classname write to intact so
            // the DB self-heals (683/684/685/686/689/692). Never tag/write the derelict for a shed row.
            private _isShedRow = (_dbCls isEqualTo "Land_i_Shed_Ind_F") || (_dbCls isEqualTo "Land_u_Shed_Ind_F");
            private _cands = nearestObjects [_ws, ["House_F"], 10];
            private _b = objNull;
            if (_isShedRow) then {_b = (nearestObjects [_ws, ["Land_i_Shed_Ind_F"], 18]) param [0, objNull];
                if (!isNull _b) then { _dbCls = "Land_i_Shed_Ind_F"; };} else {
                if (_dbCls isNotEqualTo "" && {_dbCls isNotEqualTo "NULL"}) then {
                    _b = (_cands select { (typeOf _x) isEqualTo _dbCls }) param [0, objNull];};
                if (isNull _b) then { _b = _cands param [0, objNull]; };};
            if (!isNull _b) then {private _pt   = parseNumber format ["%1", _x param [2, 0]];
                private _days = parseNumber format ["%1", _x param [3, 0]];
                _b setVariable ["AP_house_tax", [_days > 14, _days >= 1, _pt, _days], true];
                // owner 2026-06-16 (#305/#307/#310): fn_receiveHouses tags house OWNERSHIP/ID/KEYS at boot, but it
                // resolves the building with nearestObjects and the map buildings stream in ~20s AFTER it runs ->
                // it tagged nothing -> AP_homeOwner="" (gang houses died for members whenever the owner was
                // offline, #305/#310) AND AP_houseID=-1 so fn_bldgUpdateKeys SKIPPED its `WHERE oid=...` write
                // -> given house keys NEVER persisted (#307; keyholders column was NULL for every row). This loop
                // runs at +30s (buildings loaded), so re-establish the identity tags (keyed on `oid`, exactly
                // like fn_receiveHouses) + restore the keyholder list. owner/oid don't change in-session; keys
                // come straight from the DB (bldgUpdateKeys writes them immediately) so re-reading stays correct.
                private _oid = format ["%1", _x param [5, ""]];
                private _own = format ["%1", _x param [4, ""]];
                if (_own isNotEqualTo "" && {_own isNotEqualTo "NULL"}) then {_b setVariable ["AP_homeOwner", _own, true];
                    // owner 2026-06-20: a registered house sitting within 10m of a shop NPC was getting wrongly
                    // flagged AP_restricted_house=true by fn_shops' nearest-building grab (before/around this
                    // tagging), killing the owner's House Menu + grab-ID. Clear it on every owned house here (this
                    // loop re-runs every 5min, so it also self-heals an early-connect race). Shops aren't in the
                    // `houses` table so their flag is never touched. Pairs with the fn_shops/fn_copShops fix.
                    _b setVariable ["AP_restricted_house", false, true];};
                if (_oid isNotEqualTo "" && {_oid isNotEqualTo "NULL"}) then {_b setVariable ["AP_houseID", _oid, true];
                    _b setVariable ["AP_buildID", _oid, true];
                    _b setVariable ["houseId", _oid, true];};
                // owner 2026-06-21 (Latoya IRS bot): persist the house TYPE so the offline Discord tax bot can
                // compute exact upkeep (the houses table only stored worldspace). Write only when missing/changed.
                if (_oid isNotEqualTo "" && {_oid isNotEqualTo "NULL"}) then {private _cls = typeOf _b;
                    if (_cls isNotEqualTo "" && {(format ["%1", _x param [7, ""]]) isNotEqualTo _cls}) then {
                        [format ["UPDATE houses SET classname='%1' WHERE oid='%2'", _cls, _oid]] call DB_fnc_asyncQuery;};};
                private _kh = [format ["%1", _x param [6, ""]]] call _decKeys;
                if (_kh isEqualType [] && {count _kh > 0}) then {_b setVariable ["AP_house_keys", _kh, true];};
                // owner 2026-07-06: SHED 100-CAP FIX. fn_receiveHouses (the only boot cap-restorer) resolves houses
                // via nearestObjects["House_F"] at init, but buyable sheds are createVehicle'd ~6s LATER
                // (replace_sheds) so the intact shed doesn't exist yet -> its AP_vcap/phys_cap/keycap/upgrade-flags
                // are never stamped -> reads fall to the 100 fallback + fn_upgradeProperty treats the NIL cap as
                // maxed and refuses to expand. This loop runs at +30s (after the shed exists) + already re-resolves
                // the intact shed, so restore the storage state receiveHouses missed (mirrors fn_receiveHouses:49-54).
                // Self-heals ANY house the boot race skipped, sheds included. The DB row still holds the correct
                // values (fn_addHouse INSERT + fn_upgradeProperty writes) -> no data loss; affected sheds heal next restart.
                private _shedVcap = parseNumber format ["%1", _x param [8, -1]];   // guard NULL/empty -> don't zero the cap
                if (_shedVcap > 0) then { _b setVariable ["AP_vcap", _shedVcap, true]; };
                private _shedPcap = parseNumber format ["%1", _x param [9, -1]];
                if (_shedPcap > 0) then { _b setVariable ["AP_phys_cap", _shedPcap, true]; };
                _b setVariable ["AP_keycap",               parseNumber format ["%1", _x param [10, 0]],   true];
                _b setVariable ["AP_barrel_unaged",        (parseNumber format ["%1", _x param [11, 0]]) isEqualTo 1, true];
                _b setVariable ["AP_greenhouse_unaged",    (parseNumber format ["%1", _x param [12, 0]]) isEqualTo 1, true];
                _b setVariable ["AP_leadcontainer_unaged", (parseNumber format ["%1", _x param [13, 0]]) isEqualTo 1, true];
                _b setVariable ["AP_buildingLocked",               (parseNumber format ["%1", _x param [14, 0]]) isEqualTo 1, true];
                _n = _n + 1;};};} forEach _rows;
    _n};
    if !(_st getOrDefault ["init", false]) exitWith {uiSleep 30;
        // owner 2026-06-21 (Latoya IRS bot): ensure the classname column exists (idempotent) before the tag loop writes
        // house types into it. Additive nullable column -> safe for the live extDB3 named-column house INSERTs.
        ["ALTER TABLE houses ADD COLUMN IF NOT EXISTS classname VARCHAR(64) DEFAULT NULL"] call DB_fnc_asyncQuery;
        private _n = call _tagHouses;
        diag_log format ["[LooneyBin][houseTax] tagged %1 house(s)", _n];
        _st set ["init", true];};
    private _uids = (call AP_fnc_realPlayers) apply { format ["'%1'", getPlayerUID _x] };
    if !(_uids isEqualTo []) then {
        ["UPDATE houses SET tax_playtime = tax_playtime + 5 WHERE owners IN (" + (_uids joinString ",") + ")"] call DB_fnc_asyncQuery;};
    call _tagHouses;   // refresh the client-visible tax vars (cheap: one SELECT + setVariables)
}, 300, false, true] call AP_fnc_schedule;

// LUXE SUITES rent clock (suites.md). Same 300s cadence as house tax and for the
// same reason: it only ever touches leases whose deadline has already passed, so
// the interval is a latency bound, not a correctness one. Charges work with the
// tenant offline -- that is what makes the renewal "automatic".
["suiteRent", { params ["_st"]; call APS_fnc_suiteRentSweep; }, 300, false, true] call AP_fnc_schedule;
localNamespace setVariable ["APS_wantedList", []];
client_session_list = [];

[] spawn {private["_logic","_queue","_chopOptions","_vehClass"];
while {true} do {

AP_chopVehicle = [];
_chopOptions = ["C_Hatchback_01_F","C_Hatchback_01_F","C_Offroad_01_F","C_SUV_01_F","C_Hatchback_01_sport_F","C_Van_01_transport_F","B_G_Offroad_01_F","I_Truck_02_transport_F","I_Truck_02_covered_F","B_Truck_01_transport_F","B_Truck_01_box_F","B_Truck_01_box_F","B_Truck_01_box_F"];
for "_i" from 1 to 3 do {while {true} do {_vehClass = _chopOptions call BIS_fnc_selectRandom;
if (!(_vehClass in AP_chopVehicle)) exitWith { AP_chopVehicle pushBack _vehClass; };};};
publicVariable "AP_chopVehicle";

sleep (30 * 60);

_logic = missionnamespace getvariable ["bis_functions_mainscope",objnull];
_queue = _logic getvariable "AP_fnc_MP_queue";
_logic setVariable["AP_fnc_MP_queue",[],TRUE];

// LooneyBin 2026-07-18: dead 2017 group-race event DISABLED (owner "leave it dead"; superseded by the
// time-trial system). APS_fnc_initEvent teleported queued players onto a race grid into fuel-less cars and
// then called the stubbed AP_fnc_joinRace -> nothing happened. Worse, it did `AP_event_queue = []`, which
// could clobber the LIVE admin-event participant queue (GunGame/Graveyard/etc. share that var). Trigger removed
// -> no more phantom event window / grid teleport. fn_initEvent + joinRace/finishRace/startRace/raceWon are now
// unreferenced inert dead code (safe to delete later).
};};

[] spawn {if (worldName == "Stratis") then { AP_restart_delay = 6000; };

[] spawn {private ["_rand","_max"];
_max = AP_restart_delay;
_rand = floor random (_max * 2);
if (_rand < _max) then {sleep _rand;
_rand = ceil random 4;
[[_rand],"BIS_fnc_earthquake",true,false] spawn AP_fnc_MP;
sleep 12;
[[[0,1],format["A factor %1 earthquake has been detected on the island of %2.",_rand,worldName]],"AP_fnc_broadcast",true,false] spawn AP_fnc_MP;
};};

[] spawn {while {true} do {_max = AP_restart_delay * 0.5;
_rand = floor random (_max - 300);
if (_rand < 960) then { _rand = 960; };
sleep _rand;
_largest = [nil,nil,nil,0,nil]; {if (_x select 3 > _largest select 3 && !((_x select 1) in AP_past_APB)) then {_wanted = _x;
_online = false;
{ if (_wanted select 1 == getPlayerUID _x && side _x == civilian && !(_x getVariable ["prisoner",false])) then { _online = true; } } forEach allPlayers;
if (_online) then {	_largest = _x; };};} forEach (localNamespace getVariable "APS_wantedList");
// The APB target lives in localNamespace (was the published AP_allpoints, which no client reads): APS_fnc_wantedBounty
// pays 1.5x on it, and a client publicVariable of the global picked whose arrest got the bonus.
if (_largest select 3 > 0) then {localNamespace setVariable ["APS_allpoints", [_largest select 0, _largest select 1, _largest select 3]];
AP_past_APB pushBack (_largest select 1);
[] spawn {sleep 900;
private _apb = localNamespace getVariable ["APS_allpoints", []];
if (count _apb > 0) then {[[_apb select 1],"AP_fnc_removeBounty",west,false] spawn AP_fnc_MP;
_online = objNull;
{ if (_apb select 1 == getPlayerUID _x) then { _online = _x; } } forEach allPlayers;
if (!isNull _online) then { [[6,1],"AP_fnc_addStatistic",_online,false] spawn AP_fnc_MP; };
localNamespace setVariable ["APS_allpoints", []];};};};};};};

fnc_serv_kick = compileFinal {endMission "loser";};
publicVariable "fnc_serv_kick";

[] spawn APS_fnc_queryHouses;
[] spawn APS_fnc_queryGangs;
[] spawn DB_fnc_queryCaptures;

// LooneyBin TEST: load the new-player role-grant toggle from config (index 200). Default ON; the Owner
// phone button persists OFF here via REPLACE. fn_queryRequest reads SRV_grantNewbieRoles for new players.
// >>> LAUNCH (launch.md #2, 2026-06-13): default DISABLED for public. config[200] also set to 0 in DB.
SRV_grantNewbieRoles = false; localNamespace setVariable ["SRV_grantNewbieRoles", false];   // fn_queryRequest must read localNamespace (Lsec-0-1)
// >>> LAUNCH HARDENING (launch.md #1 god-stats, #2b zero-cop federal events): toggles OFF for public.
AP_betaMaxStats = false; publicVariable "AP_betaMaxStats";
AP_betaZeroCops = false; localNamespace setVariable ["AP_betaZeroCops", false]; publicVariable "AP_betaZeroCops";   // server gates read localNamespace (Lsec-0-1)
// owner 2026-06-19: restore FED OVERRIDE (server_control.fedoverride) so a persisted owner toggle survives reboots.
// ON -> re-assert the cop-requirement waiver (AP_betaZeroCops) + restart the cooldown-clear loop. Placed AFTER the
// betaZeroCops=false above so the override wins. (Loop zeroes cooldown TIMESTAMPS only -- never active-robbery flags.)
// The flag the clear loop keys on is the localNamespace copy (audit r2heist): as a global, one client publishing
// AP_fedOverride=false stopped the clears while the waiver stayed on. The global is the admin-menu display copy.
localNamespace setVariable ["AP_fedOverride", (parseNumber format ["%1", (["SELECT fedoverride FROM server_control WHERE id=1", 2] call DB_fnc_asyncQuery) select 0]) > 0];
AP_fedOverride = localNamespace getVariable "AP_fedOverride";
publicVariable "AP_fedOverride";
if (localNamespace getVariable "AP_fedOverride") then {AP_betaZeroCops = true; localNamespace setVariable ["AP_betaZeroCops", true]; publicVariable "AP_betaZeroCops";
    // singleevh.md Phase 1b: fed-override cooldown-clear migrated onto the single-wheel scheduler (id
    // "fedOverrideClear", 4s). Conditional-while (`while { AP_fedOverride }`) -> registered ONLY here, where
    // the override activates (mirrors the original spawn site), and self-exits + unschedules the instant the
    // override is turned off (so !srv resetfed / a manual toggle stops it exactly like the old loop's while
    // predicate did). Flag OFF => the original loop runs byte-for-byte (else branch) = ZERO behavior change.
    ["fedOverrideClear", {params ["_st"];
        if !(localNamespace getVariable ["AP_fedOverride", false]) exitWith { ["fedOverrideClear"] call AP_fnc_unschedule; };
        if (!isNil "SRV_lastRobbery" && {SRV_lastRobbery != -99999}) then { SRV_lastRobbery = -99999; publicVariable "SRV_lastRobbery"; };
        if (!isNil "AP_fed_robbed"  && {(AP_fed_robbed  param [1, 0]) != -99999}) then { AP_fed_robbed  set [1, -99999]; publicVariable "AP_fed_robbed"; };
        if (!isNil "AP_bank_robbed" && {(AP_bank_robbed param [1, 0]) != -99999}) then { AP_bank_robbed set [1, -99999]; publicVariable "AP_bank_robbed"; };
        // Loony Bin + Malden Fed: clear the SERVER-PRIVATE copy (the only one their gates read), then republish.
        private _lb = localNamespace getVariable "SRV_loonyBinData";
        if (!isNil "_lb" && {(_lb param [0, 0]) != -99999}) then { _lb set [0, -99999]; SRV_loonyBinData = +_lb; publicVariable "SRV_loonyBinData"; };
        // The Malden Fed's HIGH SECURITY lockout is slot 4 of its own state array, not a AP_*_robbed
        // timestamp, so the clears above cannot reach it. Same rule as the others: cooldown only, never
        // the phase -- slot 0 is left exactly as it is, so an in-progress robbery is untouched.
        private _mf = localNamespace getVariable "SRV_maldenFed";
        if (!isNil "_mf" && {(_mf param [4, -1]) != -1}) then {
            _mf set [4, -1]; SRV_maldenFed = +_mf; publicVariable "SRV_maldenFed"; };
    }, 4, false, true] call AP_fnc_schedule;};
// owner 2026-06-22 (#496 anti soft-log heist gate): the heist cop-count gates (bank/jewelry/fed) counted a raw
// `west countSide allPlayers` snapshot, so a gang could flip whitelisted members to cop side, instantly satisfy
// the requirement (e.g. 4 for the bank), start the robbery, then switch right back to civ. Track each cop's
// CONTINUOUS time on west side and count only cops on-duty >= AP_copTenureReq toward a heist requirement -> a
// just-switched soft-logger contributes 0 until they've actually served. AP_copDutySince = [[uid, joinTime], ...],
// maintained by the loop below (stamp newcomers to west, drop anyone who left west so their tenure restarts on return).
AP_copTenureReq = 300;        // seconds continuously on cop side before a cop counts toward a heist requirement
AP_copDutySince = [];
// Armapunk 2035 (faction rework PR6): WITH THE DUTY FLAG ON, THE EPOCH COMES FROM THE ROSTER. The
// AP_copDutySince ledger below is a reconstruction of "how long have they been west", rebuilt by a 20s
// scheduler pass -- and once duty exists the server already HOLDS that fact exactly, stamped by
// APS_fnc_dutySRV at the moment the shift was granted (roster slot 2). Reading it directly fixes three
// things the ledger gets wrong for a duty officer: the stamp is quantised to the next 20s tick instead of
// being the real sign-on instant; the ledger is DROPPED the moment one pass sees the player off west, which
// a death does (the respawned unit is a new object and need not land back in the duty group -- see
// evh\fn_onPlayerRespawn.sqf), so dying reset an officer's tenure to zero; and the ledger is derived state
// that a scheduler hiccup can desynchronise from the roster that authorises them.
// The ack (slot 3) is required as well as the epoch. An unacked entry is a player whose side has not yet
// moved -- truthfully still a civilian, and at most the ~10s the grant watchdog allows -- so requiring it
// cannot change any real answer against a 300s threshold, and it keeps this predicate agreeing with every
// other roster reader in the tree (DB_fnc_updatePartial and friends all wait for slot 3).
// UNITS MATTER: the roster stamps mission `time`, the ledger stamps diag_tickTime. _now is picked to match
// the branch, never mixed.
// Flag OFF is the ledger path, unchanged -- same expression, same variables, same result.
AP_fnc_tenuredCops = compileFinal {params [["_wantList", false]];
    private _dutyOn = localNamespace getVariable ["AP_dutyEnabled", false];
    private _now = if (_dutyOn) then { time } else { diag_tickTime };
    private _units = []; {private _u = _x;   // capture unit -- the nested findIf below rebinds _x to a [uid,time] pair
        if (_u call APS_fnc_isDutyCop) then {
            if (_dutyOn) then {private _e = _u call APS_fnc_dutyLookup;
                if ((_e param [3, false]) && {(_now - (_e param [2, 0])) >= AP_copTenureReq}) then { _units pushBack _u; };
            } else {private _uid = getPlayerUID _u;
                private _ix = AP_copDutySince findIf { (_x select 0) isEqualTo _uid };
                if (_ix > -1 && {(_now - ((AP_copDutySince select _ix) select 1)) >= AP_copTenureReq}) then { _units pushBack _u; };};};
    } forEach allPlayers;
    if (_wantList) then { _units } else { count _units }};
// singleevh.md Phase 1b: cop duty-tenure tracker migrated onto the single-wheel scheduler (id "copTenure",
// 20s). Body is self-contained -- all privates (_now/_westUids/_u/_uid) declared inside it, only GLOBAL
// AP_copDutySince mutated. Flag OFF => original loop runs byte-for-byte (else branch) = ZERO behavior change.
// PR6: this job is UNCHANGED and keeps maintaining AP_copDutySince even with AP_dutyEnabled on, although
// AP_fnc_tenuredCops no longer reads it in that state. Two reasons, both about not burning a bridge: the
// ledger is the flag-OFF path and has to be warm if the flag is ever turned back off mid-session, and the
// pass over allPlayers happens here anyway to compute the publish below. It also stays consistent either
// way -- its membership test is the same APS_fnc_isDutyCop, so with the flag on it tracks exactly the
// rostered cops. What this job publishes, AP_tenuredCopCount, is untouched and still the number every
// server heist gate and AP_fnc_policeRequired compare against.
["copTenure", {private _now = diag_tickTime;
    private _westUids = []; {private _u = _x;   // capture unit -- nested findIf rebinds _x to a [uid,time] pair
        if (_u call APS_fnc_isDutyCop) then {private _uid = getPlayerUID _u;
            if (_uid != "") then {_westUids pushBack _uid;
                if ((AP_copDutySince findIf { (_x select 0) isEqualTo _uid }) isEqualTo -1) then {AP_copDutySince pushBack [_uid, _now];
                };};};} forEach allPlayers;
    AP_copDutySince = AP_copDutySince select { (_x select 0) in _westUids };
    // owner 2026-07-28 (parity): PUBLISH the tenured count, because the CLIENT half of the same gate was
    // counting a different number. AP_fnc_policeRequired counted `west countSide allPlayers` -- every cop
    // online, raw -- while every server gate counts AP_fnc_tenuredCops (jewelry :30, fed :28, convoy :29,
    // Loony Bin :117). A cop who had just come on duty therefore satisfied the client and not the server:
    // the client let the drill start, the player stood through the full 10-second bar, and the server
    // refused the job afterwards. Nothing else can carry this number to a client -- tenure lives in
    // AP_copDutySince, which is server-only state.
    // Computed HERE, at the END of the pass, so it reads the list the gates will read: the line above
    // REASSIGNS AP_copDutySince (select returns a new array), and AP_fnc_tenuredCops re-reads the global,
    // so computing before it would count a cop who has just left west.
    // Published only when it CHANGES, the same idiom as the fedOverrideClear job above -- publicVariable is
    // JIP-persistent (BIKI publicVariable: JIP clients receive the value the variable held at the time), so
    // a client that connects between two changes still gets the current count.
    private _tenured = [] call AP_fnc_tenuredCops;
    if (isNil "AP_tenuredCopCount" || {AP_tenuredCopCount isNotEqualTo _tenured}) then {
        AP_tenuredCopCount = _tenured;
        publicVariable "AP_tenuredCopCount";
    };}, 20, false, true] call AP_fnc_schedule;
[] spawn {private _row = [format ["SELECT value FROM config WHERE index=200"], 2] call DB_fnc_asyncQuery;
    private _grant = localNamespace getVariable ["SRV_grantNewbieRoles", false];
    if (!isNil "_row" && {!(_row isEqualTo [])}) then {_grant = ((format ["%1", _row select 0]) != "0");};
    localNamespace setVariable ["SRV_grantNewbieRoles", _grant];   // never copied back from the client-writable global (Lsec-0-1)
    SRV_grantNewbieRoles = _grant;
    publicVariable "SRV_grantNewbieRoles";};

publicVariable "APS_fnc_addVehicle2Chain";
publicVariable "APS_fnc_experienceReq";

[] spawn DB_fnc_queryStock;
[] spawn APS_fnc_marketTick;   // LooneyBin dynamic-market engine (autonomous drift + events)

[] spawn {private ["_toCap","_capIndex","_turf","_delay","_started","_winSecs"];
// Armapunk 2035: the Rodopoli/Zaros/Panagia turf rotation is an Altis feature with no equivalent
// here (see custom_p3ds/malden_cartels.sqf). Bail before touching the flags -- they are objNull
// on this map, and `count AP_turf_list` is 0, which would divide by zero on the next line.
if (!(missionNamespace getVariable ["AP_turfSystem", true])) exitWith {
    diag_log "[Armapunk2035][turf] rotation disabled on this world -- scheduler not started";};
_toCap = [0,1,2]; private _flags = [rodo_flag, zaros_flag, panagia_flag]; private _flagNames = ["rodo_flag","zaros_flag","panagia_flag"];
_delay = (AP_restart_delay / (count AP_turf_list)) - (AP_restart_delay / (AP_restart_delay / 1000));
diag_log format ["[LooneyBin][turf] scheduler START -- delay=%1s, window=900s, turfs=%2 (restart_delay=%3)", round _delay, count AP_turf_list, AP_restart_delay];   // owner 2026-06-20: the turf system had ZERO logging, so "check the logs for why turfs aren't popping" was impossible. Instrument START + each activation/deactivation.
// owner 2026-06-20: SELF-HEAL the single-row turf_state (id=1). The row was WIPED (launch wipe / a migration) leaving
// the table EMPTY -> the resume SELECT below returned nothing AND every `UPDATE ... WHERE id=1` no-op'd, so the active
// turf + remaining window NEVER persisted across a restart (same single-row footgun as gang_fortress). Without resume,
// EVERY restart/crash/deploy restarts the 33-min first-pop countdown from scratch (with frequent restarts -> turfs
// rarely survive to activation). INSERT IGNORE re-creates the row without clobbering a real mid-cycle saved state.
["INSERT INTO turf_state (id, active_idx, ends) VALUES (1, -1, 0) ON CONFLICT DO NOTHING"] call DB_fnc_asyncQuery;
// LooneyBin (owner 2026-06-11): persist the ACTIVE turf + remaining window across reboot. If a turf
// was mid-capture at shutdown, resume the same one for the time left instead of restarting the rotation.
private _nowUnix = { parseNumber format ["%1", (["SELECT extract(epoch from now())::bigint AS u", 2] call DB_fnc_asyncQuery) param [0, 0]] };
private _resumeIdx = -1; private _resumeSecs = 0;
private _tsRow = ["SELECT active_idx, ends FROM turf_state WHERE id=1", 2, true] call DB_fnc_asyncQuery;
if (_tsRow isEqualType [] && {count _tsRow > 0}) then {private _ai = parseNumber format ["%1", (_tsRow select 0) param [0, -1]];
    private _en = parseNumber format ["%1", (_tsRow select 0) param [1, 0]];
    if (_ai in [0,1,2] && {_en > (call _nowUnix) + 20}) then { _resumeIdx = _ai; _resumeSecs = _en - (call _nowUnix); };};
while {true} do {if (_toCap isEqualTo []) then { _toCap = [0,1,2]; };
_winSecs = 900;
if (_resumeIdx isNotEqualTo -1) then {
    _capIndex = _resumeIdx; _winSecs = _resumeSecs; _resumeIdx = -1;   // one-shot resume of the saved turf
    _toCap = _toCap - [_capIndex];
    diag_log format ["[LooneyBin][turf] resumed active turf %1, %2s left", _capIndex, _winSecs];} else {sleep _delay;
[] spawn APS_fnc_reduceMarket;
_capIndex = _toCap call BIS_fnc_selectRandom;
_toCap = _toCap - [_capIndex];};
_turf = AP_turf_list select _capIndex;
AP_active_turf = _capIndex;
publicVariable "AP_active_turf";
diag_log format ["[LooneyBin][turf] ACTIVATED turf %1 (%2) for %3s -- area+label markers RED, flag AP_turf_data active", _capIndex, (_turf select 0), round _winSecs];   // owner 2026-06-20: turf instrumentation
_marker = format["turf_label_%1", _flagNames select _capIndex];
_marker setMarkerColor "ColorRed";
(format["turf_area_%1", _flagNames select _capIndex]) setMarkerColor "ColorRed";
private _fd = (_flags select _capIndex) getVariable ["AP_turf_data", [-1,"Unknown",false,"Unknown"]]; _fd set [2, true]; (_flags select _capIndex) setVariable ["AP_turf_data", _fd, true];
AP_turf_captor = [];
publicVariable "AP_turf_captor";
[format ["UPDATE turf_state SET active_idx=%1, ends=%2 WHERE id=1", _capIndex, (call _nowUnix) + _winSecs]] call DB_fnc_asyncQuery;
// owner 2026-06-24 (#501, model B = RECAP-ON-RED): this turf just went ACTIVE (red) -> the previous owner LOSES it.
// Drop it to neutral/Contested + PERSIST the wipe, so everyone (incl. the old owner) must RE-CAPTURE it this window. A
// held turf still survives a RESTART while it's NOT red (queryCaptures restores it); it's only cleared here, when its
// own cycle comes up. If nobody recaptures before the window ends it stays neutral -- you must defend to keep it. The
// window-end block below re-commits + saves the new captor (or leaves it neutral). Persisting the wipe means a restart
// during/after the red window can't resurrect the old owner.
_turf set [1, "0"]; _turf set [2, "Contested"];
AP_turf_list set [_capIndex, _turf];
publicVariable "AP_turf_list";
[] spawn DB_fnc_updateTurf;
diag_log format ["[LooneyBin][turf] RECAP-ON-RED: turf %1 (%2) went active -> owner cleared, up for grabs", _capIndex, (_turf select 0)];
_started = time;
waitUntil { (time - _started) > _winSecs };
["UPDATE turf_state SET active_idx=-1, ends=0 WHERE id=1"] call DB_fnc_asyncQuery;
AP_active_turf = -1;
publicVariable "AP_active_turf";
diag_log format ["[LooneyBin][turf] window ENDED for turf %1 (%2) -- captor=%3", _capIndex, (_turf select 0), (if (count AP_turf_captor > 0) then { AP_turf_captor select 0 } else { "none (uncaptured)" })];   // owner 2026-06-20: turf instrumentation
_marker setMarkerColor "ColorUNKNOWN";
(format["turf_area_%1", _flagNames select _capIndex]) setMarkerColor "ColorUNKNOWN";
private _fd2 = (_flags select _capIndex) getVariable ["AP_turf_data", [-1,"Unknown",false,"Unknown"]]; _fd2 set [2, false]; (_flags select _capIndex) setVariable ["AP_turf_data", _fd2, true];
_benefits = switch (_capIndex) do {case 0: { "double gathering speed of most drugs" };
case 1: { "increased gas station robbery and chop shop payouts" };
case 2: { "reduced material cost at the black market" };};
if (count AP_turf_captor > 0) then {_pdist = if (worldName == "Stratis") then { 700 } else { 2000 };
_members = []; { if (_x getVariable ["gang","0"] == (AP_turf_captor select 2) && (getMarkerPos _marker) distance _x < _pdist) then { _members pushBack _x; }} forEach allPlayers;
if (count _members > 5) exitWith {{
[[1, format["<t color='#ff0000'><t size='2'><t align='center'>Gang Turf<br/><br/><t size='1'><t color='#ffffff'>The gang turf of <t color='#ff0000'>%1</t> failed to be taken by your gang due to too many gang members in the region!", _turf select 0]],"AP_fnc_broadcast",_unit,false] spawn AP_fnc_MP;
} forEach _members;};
_turf set [1, AP_turf_captor select 2];
_turf set [2, AP_turf_captor select 1];
AP_turf_list set [_capIndex, _turf];
publicVariable "AP_turf_list";
_owned = 0; { if (_x select 1 == AP_turf_captor select 2) then { _owned = _owned + 1 } } forEach AP_turf_list;
if (_owned > 1) then { _benefits = _benefits + " as well as reduced weapon prices for holding multiple turf areas"; };
[[1, format["<t color='#ff0000'><t size='2'><t align='center'>Gang Turf<br/><br/><t size='1'><t color='#ffffff'>The gang turf of <t color='#ff0000'>%1</t> was captured by %2 for <t color='#ff0000'>%3</t>! Gang benefits are %4.", _turf select 0, AP_turf_captor select 0, AP_turf_captor select 1, _benefits]],"AP_fnc_broadcast",_unit,false] spawn AP_fnc_MP;
[] spawn DB_fnc_updateTurf;
 {[[2,3],"AP_fnc_addStatistic",_x,false] spawn AP_fnc_MP;} forEach _members;};};};

[] spawn {private ["_query"];
_query = format["SELECT p.name FROM %1 AS p LEFT JOIN players_global AS g ON p.playerid=g.playerid AND g.wealth > 0 AND g.adminlevel = '0' AND p.lastupdated > now() - interval '2 weeks' ORDER BY g.wealth DESC LIMIT 10", "players"];  // LooneyBin: QUOTE name -- unquoted names with spaces (e.g. "player107 Fire") broke call-compile of the result -> empty top-wealth board
AP_topWealth = [_query,2,true] call DB_fnc_asyncQuery;};

[] spawn APS_fnc_monitorCaptures;

// owner 2026-07-28: the ALTIS-SHAPED FED LOCKDOWN that stood here (2026-06-09 rework) is gone. It was a
// second, independent boot lockdown, +12 s after startup, that searched 400 m of the fed_reserve marker
// for Land_Dome_Big/Small_F domes, Land_Research_* safe buildings and Land_BarGate_F gates. It had been
// dormant for the whole Malden fork because fed_reserve did not exist as a marker -- its own
// `_fed isEqualTo [0,0,0]` guard exited first -- and creating that marker for the Reserve woke it back up.
// Three reasons it had to go, and why removing it is safe:
//   1. It re-sealed the dome a SECOND time, after APS_fnc_fedLockdown had already sealed it at boot.
//      Redundant at best; at worst a 12-second window in which it could land on top of a live state.
//   2. It overwrote AP_bank_gates / AP_bank_vaults / AP_bank_safes. Those are the LEGACY Altis
//      object lists, and the rewritten APS_fnc_fedLockdown deliberately stopped maintaining them -- it
//      works off the anchors APS_fnc_maldenFedSRV resolves at boot (AP_fedGate / AP_fedDome /
//      AP_fedCentre / AP_fedSafes) instead. Nothing reads the legacy three any more: fn_fedAlarm's
//      end-of-robbery relock that used to iterate them was removed when the ending moved to
//      APS_fnc_maldenFedSRV case "reset". The only remaining reader was the boot spawn further down
//      this file, which is removed with it (see the note at its old site).
//   3. It permanently registered a 3-second "fedGateRelock" scheduler job. The Reserve's gate is a
//      Land_ConcreteWall_01_l_gate_F, not a Land_BarGate_F, so that job iterated an empty list forever
//      -- and had it ever matched, it would have fought APS_fnc_fedLockdown and case "gate" for control
//      of the same animation sources.
// The deer-stand repair pass that shared the block went with it: it repaired broken TERRAIN objects
// within 600 m of the marker, which is a cosmetic Altis-era fix for an Altis-era problem.
// The Reserve is locked at boot by APS_fnc_maldenFedSRV ["boot"] -> APS_fnc_fedLockdown, which is
// idempotent and is also what every reset and !srv resetfed call.
// owner 2026-06-21: REMOVED the unmasked-entry fed-alarm trigger (this loop rang the alarm whenever an unmasked
// civilian came within 175m of fed_reserve). Per owner, the Federal Reserve alarm now fires ONLY when a gate bolt-cut
// (fn_openGate) or a dome side-door hack (fn_openVault) sends a hack request to the server; fn_iceTrace validates
// the hack and calls APS_fnc_fedRobbery server-side. The matching client proximity+items trigger in mission
// core/fn_initCiv.sqf is removed too. (APS_fnc_fedAlarm stays -- still used by fedLockdown's relock + any direct
// calls; it just isn't auto-tripped by mere presence anymore.)

// LooneyBin (2026-06-09): the four cartel CAPTURE CONTAINERS (capture_container_1..4 = Arms/Drug/Oil/
// Wong, index order = AP_capture_list) were never placed in this mission build -> the 300s dirty-money
// /rubber filler loop + DB_fnc_updateCaptures errored on undefined vars every pass, and the cartel stash
// had no physical crate. Create them at the cartel markers + publish (client Captures app + retrieve
// actions read the published objects / gangContainer var).
// LooneyBin (owner 2026-06-13): cartel crate LOOT TABLE. Owner spec: crates may ONLY contain items that
// are buyable at the REBEL shop (fn_weaponShopCfg "rebelwep"). The old per-cartel switch dropped a fixed,
// partly-non-rebel set (Mk20/Medikit/SMG_02...) ONCE at boot and never refilled -> "wrong loot or no loot"
// the moment it was looted. Now: one shared rebel pool, randomised per fill, mags auto-resolved from the
// weapon's CfgWeapons >> magazines, plus a refill loop so an emptied crate restocks (never permanently bare).
// Pools below are all confirmed "rebelwep"-buyable classnames. End-game items (Zafir/LMG_03/RPG/Titan) are
// intentionally left OUT so they aren't free cartel spam, even though they're rebel-buyable.
// owner 2026-07-05: cartel WEAPON crates removed ENTIRELY (owner: "physical crate that spawns weapons at the
// cartels ... they need to go"). No more B_supplyCrate_F, no gun loot, no weapon fill/lock loop. The four
// income containers (dirty money / oil rubber) now live on the FLAG objects -- the gangContainer var is still
// DB-persisted via fn_updateCaptures/fn_queryCaptures and shown in the Captures phone app exactly as before.
// Oil rubber retrieval (fn_getCartelRubber, off the flag's AP_cap_oil) and the cartel tax (fn_cartelSRV) are
// crate-independent and unaffected.
[] spawn {uiSleep 10;
    private _flagNames = ([] call AP_fnc_cartelCfg) apply { _x select 2 };
    AP_capture_containers = []; {private _c = missionNamespace getVariable [(_flagNames param [_forEachIndex, ""]), objNull];
        if (!isNull _c) then {private _item = if (_x isEqualTo "oil_cartel") then { "AP_inv_rubber" } else { "AP_inv_dirty_money" };
            // only seed a fresh container -- fn_queryCaptures may have already restored the DB amount onto the flag
            if (isNil { _c getVariable "gangContainer" }) then { _c setVariable ["gangContainer", [_item, 0], true]; };} else {
            diag_log format ["[LooneyBin][cartel] flag %1 missing -- container %2 left null", (_flagNames param [_forEachIndex, ""]), _forEachIndex + 1];
        };
        missionNamespace setVariable [format ["capture_container_%1", _forEachIndex + 1], _c, true];
        AP_capture_containers pushBack _c;} forEach (([] call AP_fnc_cartelCfg) apply { _x select 3 });
    publicVariable "AP_capture_containers";
    diag_log format ["[LooneyBin][cartel] income containers on flags (%1 live); weapon crates removed", {!isNull _x} count AP_capture_containers];
};

// LooneyBin (owner 2026-06-16): CARTEL OWNERSHIP PERSISTENCE. AP_capData (which gang owns each cartel) was
// ONLY ever set client-side in fn_captureCartel and networked with `true` -- it was never written to the DB
// and never restored on boot, so EVERY cartel (arms/drug/oil/wongs) reset to Neutral on every reboot. Save
// each flag's ownership to a `cartel_state` table and restore it at boot. We store only gang_id + progress
// (both numeric -> no SQL string-injection from gang names); the gang NAME is re-derived from
// AP_server_gangs on restore. A cartel whose owning gang no longer exists (disbanded) stays Neutral.
// singleevh.md Phase 1c: cartel-ownership persistence save migrated onto the single-wheel scheduler (id
// "cartelOwnSave", 60s). The one-shot boot setup (CREATE TABLE + waitUntil gangs/flags loaded + the restore
// pass) runs on the FIRST fire only via exitWith, which also seeds the cross-iteration _last signature
// de-dupe -- the exact local the simple pattern couldn't carry -- into the per-job _st alongside the
// _flagNames/_cartels config; later fires read them back and run the conditional REPLACE. Flag OFF => the
// original loop runs byte-for-byte (else branch) = ZERO behavior change.
["cartelOwnSave", {params ["_st"];
    if !(_st getOrDefault ["init", false]) exitWith {
        // Armapunk 2035: six cartels, from the config, instead of the four Altis names. The
        // cartel_state PRIMARY KEY is the config id, so Grimstone and Wreckridge persist too.
        private _roster    = [] call AP_fnc_cartelCfg;
        private _flagNames = _roster apply { _x select 2 };
        private _cartels   = _roster apply { _x select 0 }; [
            "CREATE TABLE IF NOT EXISTS cartel_state ("
            + "cartel varchar(16) PRIMARY KEY, gang_id varchar(32), progress double precision, updated timestamptz"
            + ")"] call DB_fnc_asyncQuery;
        // restore once the flags AND the gang list are loaded (need the gang list to map id -> name)
        waitUntil { uiSleep 2; (!isNil "AP_server_gangs")
            && {({!isNull (missionNamespace getVariable [_x, objNull])} count _flagNames) isEqualTo (count _flagNames)} };
        // owner 2026-06-20: QUOTE(cartel) -- the cartel column is a plain VARCHAR bareword. Without QUOTE, extDB3
        // returned arms/drug/oil/wongs UNQUOTED -> the mode-2 result `[1,[[arms,'0',0],...]]` hit `call compile`
        // as undefined variables ("Undefined variable in expression: arms") -> the whole restore THREW and aborted,
        // so cartel ownership reset to Neutral on EVERY reboot (the exact failure this block was written to fix).
        // Same compile-safety fix as QUOTE(class) in fn_restoreVehicles. (gang_id was already QUOTE'd; cartel wasn't.)
        private _rows = ["SELECT cartel, COALESCE(gang_id,'0') AS gang_id, COALESCE(progress,0) AS progress FROM cartel_state", 2, true] call DB_fnc_asyncQuery;
        if (_rows isEqualType []) then {{_x params [["_cName", ""], ["_gid", "0"], ["_prog", 0]];
                private _idx = _cartels findIf { _x isEqualTo _cName };
                if (_idx >= 0 && {(format ["%1", _gid]) != "0"}) then {   // owner 2026-07-05: persist owner even at partial progress (dropped the _prog>=1 gate) so a captured cartel never reverts to Neutral on restart -- the last owner keeps it until someone re-captures
                    private _flag = missionNamespace getVariable [(_flagNames select _idx), objNull];
                    private _gIdx = AP_server_gangs findIf { (format ["%1", _x select 0]) isEqualTo (format ["%1", _gid]) };
                    if (!isNull _flag && {_gIdx >= 0}) then {private _gname = (AP_server_gangs select _gIdx) select 1;
                        _flag setVariable ["AP_capData", [parseNumber (format ["%1", _gid]), _gname, 1], true];   // owner 2026-07-05: restore at FULL ownership (was _prog) so the previous owner solidly holds it until someone captures
                        diag_log format ["[LooneyBin][cartel] restored %1 cartel -> gang %2 (%3) prog %4", _cName, _gid, _gname, _prog];};
                };} forEach _rows;};
        _st set ["flagNames", _flagNames];
        _st set ["cartels", _cartels];
        _st set ["last", _flagNames apply { "" }];   // cross-iteration ownership-signature de-dupe
        _st set ["init", true];};
    // periodic save: write a cartel's row only when its ownership signature changes (cheap, no DB spam)
    private _flagNames = _st getOrDefault ["flagNames", []];
    private _cartels   = _st getOrDefault ["cartels", []];
    private _last      = _st getOrDefault ["last", _flagNames apply { "" }]; {private _flag = missionNamespace getVariable [_x, objNull];
        if (!isNull _flag) then {(_flag getVariable ["AP_capData", [0, "Neutral", 0]]) params [["_gid", 0], ["_gname", ""], ["_prog", 0]];
            private _sig = format ["%1|%2", _gid, _prog];
            if (_sig isNotEqualTo (_last select _forEachIndex)) then {_last set [_forEachIndex, _sig];
                [format ["INSERT INTO cartel_state (cartel, gang_id, progress, updated) VALUES ('%1','%2',%3,NOW()) ON CONFLICT (cartel) DO UPDATE SET gang_id=EXCLUDED.gang_id, progress=EXCLUDED.progress, updated=EXCLUDED.updated",
                    (_cartels select _forEachIndex), (format ["%1", _gid]), _prog]] call DB_fnc_asyncQuery;};};} forEach _flagNames;
}, 60, false, true] call AP_fnc_schedule;

// Armapunk 2035: THE WEEKLY FIXER WAR. Every 300s, ask the database what ISO week
// it is and compare it to the week stored on the faction_war row; when they differ,
// rank the three territorial factions by the contract score their aligned gangs
// earned and schedule the new matchup. All of that lives in APS_fnc_factionWarSRV
// -- this is only the wheel it rides on.
//
// runAtStart = true, deliberately: the job's first act is to publish AP_factionWar,
// and until it has, no client can render whose war it is. Waiting out a jittered
// first interval would leave every player on a freshly booted server looking at a
// blank war state for up to five minutes for no reason.
//
// 300s rather than something slower because the interval is the WORST-CASE lag
// between the week turning over and the server noticing, and it costs one indexed
// single-row read. It is not a deadline -- a missed tick, a restart, or a server
// that was down across the boundary all resolve on the next fire, because the
// rollover compares week KEYS and never elapsed time.
["factionWar", { ["tick"] call APS_fnc_factionWarSRV; }, 300, true, true] call AP_fnc_schedule;

// LooneyBin: oil-cartel RUBBER GENERATION. fn_getCartelRubber only ever DECREMENTS oil_flag's AP_cap_oil
// (the player retrieve action) -- nothing ever produced it, so the oil cartel never had any rubber. Generate
// it server-side while a gang fully owns the cartel, up to a cap. Tune _rate / _cap / _tick.
// singleevh.md Phase 1b: oil-cartel rubber generation migrated onto the single-wheel scheduler (id
// "oilRubber", 60s = the old _tick). The one-shot boot setup (config _rate/_cap, waitUntil oil_flag, the
// over-water standing-deck placement, AP_cap_oil seed) runs on the FIRST fire only; _rate/_cap are stashed
// in the per-job _st and read by the periodic body. Flag OFF => the original loop runs byte-for-byte (else
// branch) = ZERO behavior change.
["cartelAccrue", {params ["_st"];
    // Armapunk 2035: generalised from the oil-only rubber job. Every cartel whose payout is
    // ["items", ...] accrues its goods ON ITS FLAG; the owning gang collects them there
    // (AP_fnc_cartelCollect). Rates/caps come from core/config/fn_cartelCfg.sqf -- 1 per 60s tick,
    // cap 100 per item, matching the figures the oil cartel was already tuned to.
    // Production is UNCONDITIONAL (capped, contested or neutral), exactly as the oil cartel behaved:
    // whoever holds the cartel gates who may RETRIEVE, not whether it produces. Otherwise a cartel
    // nobody owns yet is worth nothing to take.
    if !(_st getOrDefault ["init", false]) then {
        private _roster = [] call AP_fnc_cartelCfg;
        waitUntil { uiSleep 5;
            ({!isNull (missionNamespace getVariable [(_x select 2), objNull])} count _roster) isEqualTo (count _roster) };
        // A flag standing over water needs something to stand on, or collection means swimming
        // (BUGS.md #72, originally hit by the Altis oil cartel).
        {   private _f = missionNamespace getVariable [(_x select 2), objNull];
            if (!isNull _f && {surfaceIsWater (getPosATL _f)}) then {private _fp = getPosASL _f;
                private _deck = "Land_HelipadRescue_F" createVehicle [0,0,0];
                _deck setPosASL [_fp select 0, _fp select 1, 0.1];
                _deck allowDamage false;
                _deck setVariable ["owner", "cartel", true];
                diag_log format ["[Armapunk2035][cartel] standing deck placed under %1", _x select 1];};
        } forEach _roster;
        _st set ["roster", _roster];
        _st set ["init", true];};

    {   _x params ["_id", "_name", "_flagVar", "", "", "", "_payout", ""];
        if ((_payout param [0, ""]) isEqualTo "items") then {
            private _flag = missionNamespace getVariable [_flagVar, objNull];
            if (!isNull _flag) then {
                private _stock = +(_flag getVariable ["AP_cartelStock", []]);
                private _changed = false;
                {   _x params ["_cls", "_rate", "_cap"];
                    private _i = _stock findIf { (_x select 0) isEqualTo _cls };
                    private _cur = if (_i < 0) then { 0 } else { (_stock select _i) select 1 };
                    private _new = (_cur + _rate) min _cap;
                    if (_new != _cur) then {
                        if (_i < 0) then { _stock pushBack [_cls, _new]; } else { (_stock select _i) set [1, _new]; };
                        _changed = true;};
                } forEach (_payout param [1, []]);
                if (_changed) then { _flag setVariable ["AP_cartelStock", _stock, true]; };};};
    } forEach (_st getOrDefault ["roster", []]);
}, 60, false, true] call AP_fnc_schedule;

// singleevh.md Phase 1c: periodic storage-save migrated onto the single-wheel scheduler (id "storageSave",
// 300s). No cross-iteration state -- _changed is a per-item temp. The inner `sleep 2` throttle between
// per-object DB writes stays in the body (the scheduler runs each job in its own spawn WITH overlap
// protection, so an in-body suspend is safe). Flag OFF => the original loop runs byte-for-byte (else branch)
// = ZERO behavior change.
["storageSave", {params ["_st"];
    private "_changed"; {if (typeName _x == "OBJECT") then {_changed = _x getVariable["lootModified", false];
    if (_changed) then {[_x] spawn DB_fnc_updateStorage;
    sleep 2;};};} forEach AP_storage_array;
    [] spawn DB_fnc_updateCaptures;
    10 setFog 0;}, 300, false, true] call AP_fnc_schedule;

// owner 2026-07-28: the boot spawn that stood here was the ONLY remaining reader of AP_bank_vaults /
// AP_bank_safes. It waitUntil'd on both, then re-shut every door on them -- a third pass over objects
// APS_fnc_fedLockdown had already sealed. It is removed with the Altis-shaped lockdown block above that
// was their only writer: left in place it would have parked a `waitUntil {!isNil "AP_bank_vaults"}` in
// the scheduler for the whole session, re-evaluated every frame and never satisfied.
if (worldName in ["Altis","Australia","Tanoa"]) then { [] spawn APS_fnc_spawnGoldBars; }; 

// singleevh.md Phase 1b: bank-vault passive funds accrual migrated onto the single-wheel scheduler (id
// "bankFunds", 300s). The one-shot boot setup (seed AP_bank_drilling/last + publish, compute _bankInc
// per world) runs on the FIRST fire only; _bankInc is stashed in the per-job _st. Flag OFF => the
// original loop runs byte-for-byte (else branch) = ZERO behavior change.
// The setup also used to waitUntil AP_bank_building, then shut a "door4_rot" / bis_disabled_Door_4 on
// it. Both went with the Malden bank: APS_fnc_maldenBankSRV binds AP_bank_building to the back-alley
// gate, whose only door is Door_1, so those two lines named an animation and a door index the object
// does not have and did nothing at all. That gate is sealed at boot by APS_fnc_maldenBankSRV ["boot"]
// instead, and nothing left in this job reads AP_bank_building, so the wait went with them.
["bankFunds", {params ["_st"];
    if !(_st getOrDefault ["init", false]) then {AP_bank_drilling = false;
        AP_bank_last = -2000;
        publicVariable "AP_bank_drilling";
        publicVariable "AP_bank_funds";
        publicVariable "AP_bank_last";
        _st set ["bankInc", (if (worldName == "Altis") then { 7000 } else { 5000 })];
        _st set ["init", true];};
    private _bankInc = _st getOrDefault ["bankInc", 5000];
    AP_bank_funds = AP_bank_funds + _bankInc;
    publicVariable "AP_bank_funds";}, 300, false, true] call AP_fnc_schedule;

[] spawn {{if(!isPlayer _x) then {removeAllWeapons _x;
removeBackpack _x;};} foreach allUnits;};

PLBObjectWhitelist = ["Rope","Box_East_Support_F","Box_East_WpsSpecial_F","Land_WaterBarrel_F","Steerable_Parachute_F","Land_BagBunker_Small_F","Land_BagFence_Corner_F","Land_BagFence_Long_F","Land_BagFence_Round_F","Land_Hbarrier_3_F","Land_Hbarrier_Big_F","Land_CamoNet_open_F","Land_Razorwire_F","Land_HBarrierTower_F","Land_BagFence_End_F","Land_HBarrierWall4_F","Land_Hbarrier_1_F","Land_BagBunker_Tower_F","Land_FieldToilet_F","Land_Pier_small_F","Land_BagFence_Short_F","Land_Research_house_V1_F","Land_Research_HQ_F"];
{if (!((typeOf _x) in PLBObjectWhitelist)) then {PLBObjectWhitelist pushBack (typeOf _x);};} forEach vehicles;

// singleevh.md Phase 1c: periodic cleanup + cartel auto-deposit migrated onto the single-wheel scheduler
// (id "cleanupCartel", 300s). Self-contained body -- no cross-iteration state, no boot setup, no in-body
// suspend. Flag OFF => the original loop runs byte-for-byte (else branch) = ZERO behavior change.
["cleanupCartel", {params ["_st"];
    [] call APS_fnc_cleanup;
    // owner 2026-07-05: cartels AUTO-DEPOSIT money straight into the OWNING GANG's bank (arms/drug/wongs) every
    // 300s tick while fully captured -- no more dirty-money container to accumulate/farm. OIL is the exception:
    // it deposits RUBBER at its flag (oil_flag AP_cap_oil, generated by the rubber loop below, retrieved via the
    // Get Cartel Rubber action) -- excluded here. Only a fully-captured cartel with a still-existing owning gang
    // pays. Same gang-bank write pattern as fn_cartelSRV (the sale tax); this is a separate passive income.
    // Armapunk 2035: money cartels, routed by their config entry rather than a hardcoded list.
    //   ["money", amt, cap, "bank"]  -> straight into the owning gang's bank (Blacksite only)
    //   ["money", amt, cap, "flag"]  -> accrues ON THE FLAG for collection (Bayview)
    // Bank payment requires a FULLY captured cartel with a still-existing gang. Flag accrual is
    // unconditional like item production -- ownership gates collection, not production.
    {   _x params ["_id", "_cname", "_flagVar", "", "", "", "_payout", ""];
        if ((_payout param [0, ""]) isEqualTo "money") then {
            private _flag = missionNamespace getVariable [_flagVar, objNull];
            if (!isNull _flag) then {
                _payout params ["", ["_amt", 0], ["_mcap", 0], ["_dest", "flag"]];
                if (_dest isEqualTo "flag") then {
                    private _cur = _flag getVariable ["AP_cartelCash", 0];
                    private _new = (_cur + _amt) min _mcap;
                    if (_new != _cur) then { _flag setVariable ["AP_cartelCash", _new, true]; };
                } else {
                    (_flag getVariable ["AP_capData", [0, "Neutral", 0]]) params [["_gangID", 0], ["_gangName", ""], ["_progress", 0]];
                    if (_progress >= 1 && {(format ["%1", _gangID]) isNotEqualTo "0"}) then {
                        private _gidx = AP_server_gangs findIf { (format ["%1", _x select 0]) isEqualTo (format ["%1", _gangID]) };
                        if (_gidx >= 0) then {private _gang = AP_server_gangs select _gidx;
                            private _newBank = ((_gang select 5) + _amt) max 0;
                            _gang set [5, _newBank];
                            [str (_gang select 0), 0, 0, _newBank] spawn DB_fnc_updateGang;
                            [[998, objNull, format ["Cartel auto-deposit: %1 -> gang %2 (%3) +$%4 = bank $%5", _cname, _gangID, _gangName, _amt, _newBank]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
                        };};};};};
    } forEach ([] call AP_fnc_cartelCfg);}, 300, false, true] call AP_fnc_schedule;

if (worldName == "Australia") then {

[] spawn {_obj = nearestObjects [[25000,25000,0], ["Land_CommonwealthBank","Land_PoliceStation"], 15000]; {switch (typeof _x) do {
case "Land_PoliceStation": { _x animate ["gatedoor_1", -1.6]; _x animate ["gatedoor_2", 1.6]; };
case "Land_CommonwealthBank": { _x animate ["LeftSlideDoor",-1.7]; _x animate ["RightSlideDoor",1.7] };}} forEach _obj;};

AP_prison_building = nearestObject [getMarkerPos "corrections", "Land_MainSection"];
AP_prison_building animate ["Door3", 1];
AP_prison_building animate ["Door4", 1];
AP_prison_building animate ["Door7", 1];
AP_prison_building animate ["Door13", 1];
AP_prison_building animate ["Door14", 1];};

[] spawn DB_fnc_restoreVehicles;
[] spawn APS_fnc_laserTag;

[] spawn { sleep 20; { _x setDamage 1; } forEach (nearestObjects [getMarkerPos "fed_reserve", ["Land_Cargo_Patrol_V1_F"], 200]); };

[] spawn {_query = format["DELETE FROM online WHERE instance='%1'", (localNamespace getVariable "APS_serverInstance")];
[_query] call DB_fnc_asyncQuery;};

[] spawn KBW_fnc_fixBadOffers;
SRV_exchangeIsReady = true;   publicVariable "SRV_exchangeIsReady";   // LooneyBin: the Exchange menus hard-gate on this -- never published before (menus said "still being initialized" forever)
[] spawn APS_fnc_fedAirDefenseSRV;   // Fed platform anti-air umbrella (server-side on purpose)
[] call APS_fnc_fedRadarSRV;         // resolve + log the radar tower, publish the footings (index -1 = setup only)
// The pass that lets ["boot"] run at all. APS_fnc_maldenFedSRV is on the CfgRE whitelist with
// allowedTargets = 2 and no argument restriction, so any client can call ANY of its modes; boot resets
// the event to phase 0 and re-locks the compound, which makes an unguarded boot a trivial denial of
// service. This sentinel is set ONLY here, one line before the server's own call, is never
// publicVariable'd, and boot consumes it. Do not publish it and do not set it anywhere else.
// mapdb (2026-09-09, props pass 2): the Reserve's perimeter gates, ring safes, dome and centre, the
// bank's back-alley gate, the emporium's gates and the police bar gates are map_objects rows now,
// which APS_fnc_mapLoad createVehicles ~25 s into the boot (table read, settle sleep, then the spawn
// loop). Resolving them synchronously here found NOTHING: the dome and centre had been NULL since
// the 9/4 mapdb move, and pass 2 took the gates and safes with them ("fedLockdown: locked 0", "the
// bank is unwired", "0 gate(s) resolved"). So the three boots run detached, in their original order,
// once the spawn stage reports done (AP_mapFarDone, set at the end of APS_fnc_mapLoad). The fed
// sentinel is set inside the same spawn, still one line before its consumer and still never published.
[] spawn {
    private _t = diag_tickTime;
    waitUntil { uiSleep 0.5; (missionNamespace getVariable ["AP_mapFarDone", false]) || {diag_tickTime - _t > 300} };
    if !(missionNamespace getVariable ["AP_mapFarDone", false]) then {
        diag_log "[AP-MAP] WARN the boot spawn has not finished after 300 s -- resolving the Reserve, the bank and the emporium against whatever exists";
    };
    {_x animate ["Door_1_rot", 1];} forEach allMissionObjects "Land_BarGate_F";   // police bar gates open at boot (was inline above, before the Exchange lines)
    localNamespace setVariable ["AP_fedBootAllowed", true];   // server-only (localNamespace: no client can set it); consumed by the boot mode
    ["boot"] call APS_fnc_maldenFedSRV;   // Malden Federal Reserve: resolve anchors, lock down, start the sweep
    // No sentinel of its own: APS_fnc_maldenBankSRV is deliberately NOT on the CfgRE whitelist, so unlike the
    // Fed above there is no client-reachable path into any of its modes and nothing to defend boot against.
    ["boot"] call APS_fnc_maldenBankSRV;   // Malden bank: resolve the back-alley gate, bind it, seal it
    [] call APS_fnc_maldenJewelSRV;   // Malden Jewelry Emporium: bind the Eden objects, spawn the safe
};
[] spawn APS_fnc_radioSRV;   // LooneyBin car-radio station master -- broadcasts AP_radioNow per station (Build A ready)
_forSaleHouses = [format["SELECT worldspace,sale FROM houses WHERE sale>0",AP_server_instance],2,true] call DB_fnc_asyncQuery;
AP_forSaleHouses = [];
// owner 2026-06-14 (#182): restore the listing into AP_house_price, NOT the dead "salePrice" var. Every
// reader (fn_buyHouse, fn_houseMenu, fn_marketSellHouse, the "Locate Homes for Sale" home-store action) keys
// off AP_house_price; "salePrice" has zero readers. So persisted for-sale houses came back from the DB
// invisible to the market AND un-buyable after every restart -- the locate action marked nothing on the map.
// owner 2026-06-19: asyncQuery returns `worldspace` ALREADY PARSED to an array for these sale>0 rows. The old
// unconditional `call compile (_x select 0)` then threw "compile: Type Array, expected String" and HALTED the
// main init thread BEFORE AP_server_isReady published -> every client hung at "waiting for server ready" =
// total join outage. (Latent: only triggered once b0075's fn_updateHousePrice oid fix made listings persist.)
// Handle array-or-string + skip anything malformed so one bad row can never wedge boot again.
{private _ws = _x select 0;
    if (_ws isEqualType "") then { _ws = parseSimpleArray (format ["%1", _ws]); };
    if (_ws isEqualType []) then {nearestBuilding _ws setVariable ["AP_house_price", _x select 1, true];
        AP_forSaleHouses pushBack _ws;};} forEach _forSaleHouses;
publicVariable "AP_forSaleHouses";
// singleevh.md Phase 1c: exchange listing-timer increment migrated onto the single-wheel scheduler (id
// "exchangeTimer", 3600s). Trivial body -- one UPDATE, no state, no boot setup. Flag OFF => the original
// loop runs byte-for-byte (else branch) = ZERO behavior change.
["exchangeTimer", {params ["_st"];
    private _query = "UPDATE exchange SET timer=timer+1 WHERE active='1'";   // LooneyBin: storage rows (active=2) age by bought_at, not the listing timer
    [_query,1] call DB_fnc_asyncQuery;}, 3600, false, true] call AP_fnc_schedule;

// --- LooneyBin: announce server readiness to the 2020 client ----------------
// The 2020 client (core\init.sqf) gates on these two flags before it runs
// AP_fnc_dataQuery (the player-load DB handshake). The 2017-derived server never
// published them -> client hung forever at waitUntil{!isNil "AP_server_isReady"}
// -> spawned on debug island with no welcome/HUD/markers/phone. Publish them now that
// server init has completed. SRV_VehiclesLoaded gates the client's vehicle wait; restore
// runs async (spawned above) and JIP-syncs vehicles as they load, so it's safe to flag here.
SRV_VehiclesLoaded = true;
publicVariable "SRV_VehiclesLoaded";
AP_server_isReady = true;
publicVariable "AP_server_isReady";
diag_log "::LooneyBin Server:: READY — published AP_server_isReady + SRV_VehiclesLoaded";

// ===== LooneyBin: loonybot command bridge -- executes queued admin commands from the bot_commands table =====
// singleevh.md Phase 1c: loonybot command bridge poll migrated onto the single-wheel scheduler (id
// "botBridge", 5s = the old poll cadence). The one-shot boot settle (uiSleep 30) runs on the FIRST fire
// only via first-run-init so queued commands aren't dispatched before AP_fnc_MP / AP_fnc_* are ready;
// the body is unchanged (DB_Async_Active-gated SELECT + per-command switch). Flag OFF => the original loop
// runs byte-for-byte (else branch) = ZERO behavior change.
["botBridge", {params ["_st"];
    if !(_st getOrDefault ["init", false]) then { uiSleep 30; _st set ["init", true]; };   // let boot settle before dispatching queued commands
    if !("DB_Async_Active" call DB_fnc_flag) then {
        private _rows = ["SELECT id, command, COALESCE(target,'') AS target, COALESCE(arg1,'') AS arg1, COALESCE(arg2,'') AS arg2 FROM bot_commands WHERE status='pending' ORDER BY id ASC LIMIT 10", 2, true] call DB_fnc_asyncQuery;
        if (_rows isEqualType [] && {count _rows > 0}) then {{
                _x params [["_cid", -1, [0]], ["_cmd", "", [""]], ["_tgt", "", [""]], ["_a1", "", [""]], ["_a2", "", [""]]];
                private _ok = true;
                switch (toLower _cmd) do {case "msg": {[[0, _a1], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;};
                    case "kick": {private _u = (allPlayers select { (getPlayerUID _x) isEqualTo _tgt }) param [0, objNull];
                        if (!isNull _u) then { [[_a2], "AP_fnc_botKick", _u, false, false] spawn AP_fnc_MP; };};
                    case "ban": {private _u = (allPlayers select { (getPlayerUID _x) isEqualTo _tgt }) param [0, objNull];
                        if (!isNull _u) then { [[format ["Banned: %1", _a2]], "AP_fnc_botKick", _u, false, false] spawn AP_fnc_MP; };};
                    case "hardkick": {
                        // LooneyBin: engine-level kick from the SERVER -- works even when the
                        // target client's scripts are wedged (frozen-arsenal case; the normal
                        // 'kick' routes endMission through the CLIENT and dies with it).
                        private _u = (allPlayers select { (getPlayerUID _x) isEqualTo _tgt }) param [0, objNull];
                        if (!isNull _u) then {diag_log format ["[LooneyBin][bot] hardkick %1 (%2)", name _u, _tgt];
                            serverCommand format ["#kick %1", owner _u];
                            [_u] spawn {params ["_u"];
                                uiSleep 8;
                                // serverCommand can be unavailable to dedicated-server scripts --
                                // engine fallback: deleting the player object drops the client
                                if (!isNull _u) then { deleteVehicle _u; };};};};
                    case "gracefulsave": {
                        // owner 2026-06-13: DETERMINISTIC soft restart (replaces the endMission attempt, which
                        // depended on a config-specific in-place mission reload that proved unreliable on this
                        // headless box -- -autoInit + no admin/RCON). loonybot's !srv softr fires THIS to do a
                        // FULL graceful save (vehicle_mem incl. AP_vinv trunks + storage)
                        // BEFORE it kills + relaunches the process. restoreVehicles rebuilds the world on boot,
                        // so nothing is lost. Marks the command 'saved' once the async writes have flushed.
                        // Guarded so a repeated softr can't run two concurrent saves (saveVehicles DELETEs then
                        // re-fills vehicle_mem -- overlapping runs would corrupt it).
                        if (isNil "AP_savingForRestart" || {!AP_savingForRestart}) then {AP_savingForRestart = true;
                            [_cid] spawn {params ["_cid"];
                                [[1, "Server saving for a restart -- your progress + vehicles are being persisted..."], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
                                // HOLD'EM FIRST, before the client flush and well before the vehicle
                                // snapshot. Every !srv softr / hardr and every deploy comes through
                                // here, and none of them go anywhere near the 4h cycle's T-5 lock --
                                // so without this the one restart path the owner uses most is the one
                                // that eats the table. The drain aborts the live hand, refunds every
                                // committed chip and banks every stack by uid; the flag keeps anyone
                                // from sitting back down in the seconds before the process dies.
                                if (!isNil "AP_holdemTable") then {
                                    SRV_holdemCloseReason = "server restart";
                SRV_holdemEnabled = false; publicVariable "SRV_holdemEnabled";
                                    ["drain", ["server restart"]] call APS_fnc_holdemSRV;
                                };
                                // owner 2026-06-19 (kit-loss cluster): force a live client gear+pos+money flush BEFORE
                                // the snapshot -- nothing server-side snapshots live client state. This covers
                                // !srv softr / hardr / deploys (all route through gracefulsave). See the scheduled path above.
                                [[], "AP_fnc_ClupdateRequest", -2, false, false] spawn AP_fnc_MP;
                                uiSleep 8;                      // let the client row-writes land before the snapshot
                                [] call DB_fnc_saveVehicles;   // BLOCKING: queues vehicle_mem + storage
                                uiSleep 35;                     // let extDB3 flush its async write queue (established buffer)
                                [format ["UPDATE bot_commands SET status='saved' WHERE id=%1", _cid]] call DB_fnc_asyncQuery;
                                diag_log "[LooneyBin][softr] graceful save complete + flushed -> safe to restart the process";
                                AP_savingForRestart = false;};};};
                    case "summonselftest": {
                        // SUMMON VEHICLE harness: spawn a car/heli/vtol ~1 km from respawn_civilian and
                        // let the HC bring it there. Outcome lands in this log as [SUMMON-TEST].
                        diag_log format ["[SUMMON-TEST] dispatched kind=%1 hcOwner=%2", _a1, localNamespace getVariable ["AP_hcOwner", 0]];
                        ["selftest", _a1, _a2] spawn APS_fnc_summonSRV;};
                    case "territoryreload": {
                        // postgis: re-read faction_territory (after tools/bake_territory.py) and
                        // re-publish; every client flushes its territory cache. No repack.
                        [] call APS_fnc_territoryLoad;};
                    case "mapselftest": {
                        // live map editor: run AP_fnc_mapSelfTest on every connected client (a headless
                        // client is the point -- it exercises the applier, the join replay and the
                        // authority gate with nobody in the game). arg1 = phase, arg2 = npc row id.
                        diag_log format ["[AP-MAPEDIT] mapselftest dispatched: phase=%1 npc=%2", _a1, _a2];
                        [[_a1, parseNumber _a2], "AP_fnc_mapSelfTest", -2, false, false] spawn AP_fnc_MP;};
                    case "teleport": {
                        // ops/Eden Live demo: put a player or the headless client somewhere. target = player
                        // name or UID ("" = every headless client), arg1 = "x y [z]" (ATL, z defaults to 0).
                        private _p = (_a1 splitString " ,") apply { parseNumber _x };
                        private _units = if (_tgt isEqualTo "") then { allPlayers select { _x isKindOf "HeadlessClient_F" } }
                            else { allPlayers select { (getPlayerUID _x) isEqualTo _tgt || { (name _x) isEqualTo _tgt } } };
                        if (count _p < 2 || {count _units isEqualTo 0}) then {
                            _ok = false; diag_log format ["[AP-BOT] teleport: bad args target=%1 pos=%2 units=%3", _tgt, _a1, count _units];
                        } else {
                            { _x setPos [_p select 0, _p select 1, _p param [2, 0]];
                              diag_log format ["[AP-BOT] teleport %1 -> %2", name _x, getPosATL _x]; } forEach _units;
                        };};
                    case "dbsoak": {
                        // pg conversion harness: run the DB soak (optionally one section as arg1).
                        // Same trust tier as resetfed -- writing bot_commands already means DB access.
                        [_a1] spawn APS_fnc_dbSoak;};
                    case "resetfed": {
                        // owner 2026-06-16: clear a stuck/cooling-down Federal Reserve so players can retry
                        // without a reboot (AP_fed_robbed stuck [true,...] or SRV_lastRobbery cooldown).
                        [] call APS_fnc_resetFed;
                        [[2, "Federal Reserve security systems have been reset by command."], "AP_fnc_broadcast", west, false, false] spawn AP_fnc_MP;
                    };
                    case "dutyswitch": {
                        // AP_dutyEnabled at RUNTIME (DUTY_SOAK.md E1/E3), arg1 "on"/"off". The one live path: .96 has
                        // no SERVER EXEC, and a client publicVariable of the flag is refused and restored (server_init).
                        // Server copy first (every server read, and "init" checks it); "off" drains the roster on the
                        // next 60 s sweep. A server that BOOTED false never ran "init", so "on" runs it (its helper
                        // APS_fnc_dutyRecount is defined at boot either way, server_init.sqf) BEFORE the display copy
                        // goes out, so the terminals do not appear on clients before the roster exists.
                        private _v = toLower _a1;
                        if !(_v in ["on", "off"]) then { _ok = false; } else {
                            private _on = _v isEqualTo "on";
                            localNamespace setVariable ["AP_dutyEnabled", _on];
                            if (_on && {isNil {localNamespace getVariable "AP_dutyRoster"}}) then { ["init"] call APS_fnc_dutySRV; };
                            AP_dutyEnabled = _on;
                            publicVariable "AP_dutyEnabled";
                            diag_log format ["[AP-DUTY] kill-switch %1 by bot_commands #%2", _v, _cid];
                        };};
                    case "ghrefresh": {
                        // owner 2026-06-20: the Enrique offline-gardener bot writes a house's vinv + greenhouse_crop
                        // straight to the DB, but the LIVE server caches both on the house OBJECT (AP_vinv /
                        // AP_gh_crop, loaded once at boot) -> without this the DB change is invisible in-game AND a
                        // later house save clobbers it. Re-read both from the DB onto the running object (owner + all
                        // keyholders are offline by Enrique's own gate, so nothing else is touching the house). _tgt =
                        // house oid, _a1 = worldspace "[x,y,z]".
                        localNamespace setVariable ["APS_gh_" + _tgt, nil];   // drop greenhouseSRV's server copy -> next plant/harvest re-reads the row
                        private _pos = parseSimpleArray _a1;
                        private _h = if (_tgt isNotEqualTo "" && {_pos isEqualType []} && {count _pos >= 2}) then { (nearestObjects [_pos, ["House_F"], 14]) param [0, objNull] } else { objNull };
                        if (isNull _h) then { _ok = false; } else {
                            private _row = [format ["SELECT vinv, COALESCE(greenhouse_crop,'') AS greenhouse_crop FROM houses WHERE oid='%1'", _tgt], 2] call DB_fnc_asyncQuery;
                            if (!(_row isEqualType []) || {count _row < 2}) then { _ok = false; } else {
                                // vinv is str2/mres-encoded -> read RAW (project rule, see fn_queryHouses) -> mresToArray -> AP_vinv
                                private _vinv = [_row select 0] call DB_fnc_mresToArray;
                                if (typeName _vinv == "STRING") then { _vinv = parseSimpleArray (format ["%1", _vinv]); };
                                if (!(_vinv isEqualType []) || {count _vinv < 2}) then { _vinv = [[], 0]; };
                                _h setVariable ["AP_vinv", _vinv];   // owner 2026-06-23 (B): server-LOCAL cache (not broadcast); next gated open re-reads the DB row anyway
                                // greenhouse_crop is a PLAIN array string -> parseSimpleArray -> AP_gh_crop
                                private _crop = parseSimpleArray (format ["%1", _row select 1]);
                                if !(_crop isEqualType []) then { _crop = []; };
                                _h setVariable ["AP_gh_crop", _crop, true];
                                diag_log format ["[LooneyBin][enrique] ghrefresh house %1 -> AP_vinv(%2 items)/AP_gh_crop(%3 batches)", _tgt, count (_vinv param [0, []]), count _crop];
                            };};};
                    default { _ok = false; };};
                [format ["UPDATE bot_commands SET status='%1' WHERE id=%2", (["error","done"] select _ok), _cid]] call DB_fnc_asyncQuery;
            } forEach _rows;};};}, 5, false, true] call AP_fnc_schedule;
