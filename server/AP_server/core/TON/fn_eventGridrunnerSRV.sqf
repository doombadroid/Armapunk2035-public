/*
    APS_fnc_eventGridrunnerSRV  (LooneyBin -- new admin event, 2026-06-28)
    Admin event mode 7: GRIDRUNNER (self-contained parkour mini-game at Kavala BH, location 1000).
    The eventCfg menu start lambda remoteExecs [1, objNull, _locID] here. The jump/parkour mechanic is
    fully client-side (fn_eventGridrunnerClient, joined via the event key -> keyUpHandler dispatch on
    AP_adminEvent select 2 == 7). Server = admin-gated START, OPEN joins (select 1 stays false; the
    client key handlers all leave when select 2 != 7), ~20-min round, close.
    AP_adminEvent = [active, joinsLocked, eventMode, locationID]
*/
params [["_mode", -1, [0]], ["_x1", objNull, [objNull]], ["_locID", 1000, [0]]];
if !(_mode isEqualTo 1) exitWith {};

// owner 2026-06-28 SECURITY (mirrors fn_eventGunGameSRV / security.md §2.1): START is an ADMIN action but is
// CfgRE-whitelisted (allowedTargets=2), so any client could remoteExec [1, ...] to spam-launch the event.
// Re-query the NON-SPOOFABLE caller's admin level (remoteExecutedOwner -> DB) and require >= 3 to START.
// server-internal (_src==0) passes.
private _src = remoteExecutedOwner;
private _starter = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
private _lvl = if (_src isEqualTo 0) then { 999 } else {
    private _rows = [format ["SELECT adminlevel FROM players_global WHERE playerid='%1'", getPlayerUID _starter], 2, true] call DB_fnc_asyncQuery;
    parseNumber format ["%1", (_rows param [0, [0]]) param [0, 0]]};
if (_lvl < 3) exitWith { ["-SEC-", _starter, format ["BLOCKED eventGridrunnerSRV START by %1 (admin %2)", getPlayerUID _starter, _lvl]] call APS_fnc_logIt; };

if (AP_adminEvent param [0, false]) exitWith {};
if (isNil "AP_event_queue") then { AP_event_queue = []; };
AP_event_queue = [];
AP_adminEvent = [true, false, 7, _locID];
publicVariable "AP_adminEvent";
[[0, "ADMIN EVENT: GRIDRUNNER! Civilians -- press your event key to take on the Kavala BH parkour course!"], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
[] spawn {uiSleep 1200;   // 20-min round
    if (AP_adminEvent param [0, false] && {(AP_adminEvent param [2, 0]) isEqualTo 7}) then {
        AP_adminEvent = [false, false, 0, 0]; publicVariable "AP_adminEvent";
        AP_event_queue = [];
        [[0, "The Gridrunner admin event has ended!"], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;};};
