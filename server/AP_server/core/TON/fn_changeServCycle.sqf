/*
    APS_fnc_changeServCycle  (LooneyBin -- REWIRED 2026-06-18 to actually restart the box.)
    Client (core/admin/fn_srvCycAdjust.sqf): [mode, obj, uid]. The admin-menu "SERVER ADJUSTMENTS" buttons:

      mode 13 = HARD now            mode 14 = UPDATE now
      mode 4/5/6/7   = HARD   in 1/10/30/60 min
      mode 8/9/10/11 = UPDATE in 1/10/30/60 min

    HARD   = relaunch the ALREADY-DEPLOYED PBOs as-is (no repack). hard_pending=0 -> the watchdog runs
             run-boot2.sh with NO_REPACK=1 (freeze branch = reload current build). For lag/hang recovery.
    UPDATE = repack the staged loose source into fresh PBOs + sign + patch notes, then relaunch.
             hard_pending=1 -> the watchdog runs run-boot2.sh with FORCE_DEPLOY=1 (repacks AND forces through
             the nightly / .deploy_freeze lock). DEPLOYS code -> OWNER-ONLY.

    Both paths: GRACEFUL-SAVE first (a manual restart_now=1 skips the scheduler's save), then set
    server_control.restart_now=1 so restart_watchdog.sh kills + relaunches the process.
    (The old 2017 body only shifted the in-game countdown by +-30 min and ignored every other mode.)
*/
params [["_mode", -1, [0]], ["_pObj", objNull, [objNull]], ["_uid", "", [""]]];
if (_mode isEqualTo -1 || isNull _pObj) exitWith {};
// owner 2026-06-23 SECURITY (security.md §2.3 — restart DoS / unauth deploy): re-derive the caller server-side.
// _uid + _pObj are client-supplied and the owner UID is PUBLIC, so the old `_uid == owner` UPDATE gate was
// spoofable and HARD had only a CLIENT-side admin gate -> any client could force-restart the box (DoS). Capture
// the NON-SPOOFABLE sender now (0 = server-internal = trusted); admin level is re-queried server-side at the gate.
private _src = remoteExecutedOwner;
private _realCaller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
private _callerUID = getPlayerUID _realCaller;
private _isOwner = (_src isEqualTo 0) || {_callerUID isEqualTo "76561190000000001"};

// mode -> [isUpdate, delayMinutes]
private _spec = switch (_mode) do {case 13: { [false, 0] };
    case 14: { [true,  0] };
    case 4:  { [false, 1] };
    case 5:  { [false, 10] };
    case 6:  { [false, 30] };
    case 7:  { [false, 60] };
    case 8:  { [true,  1] };
    case 9:  { [true,  10] };
    case 10: { [true,  30] };
    case 11: { [true,  60] };
    default { [] };   // legacy SOFT modes 0-3 / 12 were removed from the menu
};
if (_spec isEqualTo []) exitWith {};
_spec params ["_isUpdate", "_delayMin"];

// UPDATE repacks + DEPLOYS staged code -> OWNER-only (re-derived caller, NOT the spoofable client _uid arg).
if (_isUpdate && {!_isOwner}) exitWith {
    ["-SEC-", _realCaller, format ["BLOCKED changeServCycle UPDATE (deploy) by non-owner %1", _callerUID]] call APS_fnc_logIt;
    [["UPDATE restart (repack + deploy staged code) is owner-only. Use HARD to reload the current build.", "basic"], "AP_fnc_handleMessage", _pObj, false] spawn AP_fnc_MP;
};
// HARD restart -> server-verified admin (lvl 3+). Was client-gated only -> any client could force-restart (DoS).
private _adminLvl = if (_isOwner || _isUpdate) then { 99 } else {
    private _ar = [format ["SELECT adminlevel FROM players_global WHERE playerid='%1'", _callerUID], 2] call DB_fnc_asyncQuery;
    if (_ar isEqualType [] && {count _ar > 0}) then { parseNumber format ["%1", (_ar select 0) select 0] } else { 0 }};
if (!_isUpdate && {!_isOwner} && {_adminLvl < 3}) exitWith {
    ["-SEC-", _realCaller, format ["BLOCKED changeServCycle HARD restart by non-admin %1 (lvl %2)", _callerUID, _adminLvl]] call APS_fnc_logIt;
};

// one restart in flight at a time
if (missionNamespace getVariable ["AP_restartPending", false]) exitWith {
    [["A server restart is already scheduled.", "basic"], "AP_fnc_handleMessage", _pObj, false] spawn AP_fnc_MP;};
AP_restartPending = true;

private _label = if (_isUpdate) then { "UPDATE (repack + deploy)" } else { "HARD (reload current build)" };
["-ADMINACTION-", _pObj, format ["triggered a %1 restart in %2 min", _label, _delayMin]] call APS_fnc_logIt;

[_isUpdate, _delayMin, _label] spawn {params ["_isUpdate", "_delayMin", "_label"];
    private _end = time + (_delayMin * 60);
    if (_delayMin > 0) then {private _marks = [3600, 1800, 900, 600, 300, 120, 60, 30, 10];
        private _sent = [];
        [[0, format ["Server %1 restart scheduled in %2 minute(s). Sync your gear & vehicles.", _label, _delayMin]], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
        while { time < _end } do {private _left = ceil (_end - time); {
                if (_left <= _x && {!(_x in _sent)} && {_x <= (_delayMin * 60)}) then {_sent pushBack _x;
                    private _fmt = if (_x >= 60) then { format ["%1 minute(s)", _x / 60] } else { format ["%1 seconds", _x] };
                    ["SERVER RESTART", format ["%1 restart in %2.", _label, _fmt]] call APS_fnc_adminMsg;};} forEach _marks;
            uiSleep 2;};};
    // HOLD'EM DRAINS BEFORE THE SAVE. AP_holdemTable is memory, and a buy-in has already left a real
    // bankacc row -- so a stack still sat on a seat when the watchdog pkills the process is money
    // that exists nowhere. At T-0 rather than at the countdown's start, because _delayMin can be an
    // hour and closing the poker table for an hour to protect five minutes of risk is the wrong
    // trade. The drain aborts any live hand and refunds every chip; the flag stops a fresh hand
    // being dealt in the seconds that follow.
    // THE FLAG ONLY, and deliberately not a ["drain"] call. This function is remoteExec'd by the
    // admin who pressed the button, and whether remoteExecutedOwner still reads that client's id
    // inside this spawned child is not a thing to bet six players' stacks on -- the "drain" case
    // asserts owner 0 and would refuse, silently, at the one moment it matters. The 1 s holdemClock
    // tick is unambiguously owner 0 and drains on its very next pass, so flip the flag and then WAIT
    // for the table to actually come back empty rather than assuming it did.
    if (!isNil "AP_holdemTable") then {
        SRV_holdemCloseReason = "server restart";
        SRV_holdemEnabled = false; publicVariable "SRV_holdemEnabled";
        private _dl = time + 15;
        waitUntil { uiSleep 0.5; (AP_holdemTable getOrDefault ["drained", false]) || {time > _dl} };
        if !(AP_holdemTable getOrDefault ["drained", false]) then {
            diag_log "[HOLDEM] !! table did NOT drain within 15 s of the restart flag -- seated stacks are at risk; check the holdemClock job";
        };
    };
    // GRACEFUL SAVE (trunks/vehicles) before the kill -- a raw restart_now=1 skips the scheduler's own save.
    ["SERVER RESTART", format ["%1 restart NOW -- saving + relaunching. Rejoin from the server browser shortly.", _label]] call APS_fnc_adminMsg;
    private _h = [] spawn DB_fnc_saveVehicles;
    waitUntil { scriptDone _h };
    uiSleep 20;   // let extDB3 flush the async save queue before the watchdog pkills the process
    ["INSERT INTO restart_log (mode) VALUES ('hard')"] call DB_fnc_asyncQuery;
    // hard_pending = 1 (UPDATE) -> watchdog launches run-boot2 with FORCE_DEPLOY=1 (repack + force past freeze).
    // hard_pending = 0 (HARD)   -> watchdog launches run-boot2 with NO_REPACK=1 (relaunch deployed PBOs as-is).
    [format ["UPDATE server_control SET hard_pending=%1, restart_now=1 WHERE id=1", [0, 1] select _isUpdate]] call DB_fnc_asyncQuery;};
