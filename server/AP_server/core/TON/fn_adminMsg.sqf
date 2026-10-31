/*
    APS_fnc_adminMsg  (LooneyBin) -- relay an admin's message to ALL players as a privileged
    "Admin Message" (clientMessage type 5 -> handleMessage "adminall").
    MUST be server-origin: handleMessage anti-spoofs "adminall" unless remoteExecutedOwner==2, so a
    client broadcasting it directly is either blocked + false-flagged, or a spoof vector. The staff
    gate is client-side (AP_fnc_adminMessage, level 2+); BE backstops injected direct calls.
    Args: [_adminName, _msg]
*/
params [["_name", "", [""]], ["_msg", "", [""]]];
if (_name isEqualTo "" || {_msg isEqualTo ""}) exitWith {};

// owner 2026-06-23 SECURITY (security.md §2.2 — admin-impersonation): this had NO server-side authz, so any
// client could remoteExec it to broadcast a privileged "Admin Message" (staff impersonation). The _name arg
// is just a label string and is NOT identity -- re-query the NON-SPOOFABLE caller's adminlevel and require
// >= 2 (client gate AP_fnc_adminMessage, level 2+). remoteExecutedOwner 0 = server-internal = trusted.
private _src = remoteExecutedOwner;
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
private _callerUID = getPlayerUID _caller;
private _lvl = if (_src isEqualTo 0) then { 999 } else {
    private _rows = [format ["SELECT adminlevel FROM players_global WHERE playerid='%1'", _callerUID], 2, true] call DB_fnc_asyncQuery;
    parseNumber format ["%1", (_rows param [0, [0]]) param [0, 0]]};
if (_lvl < 2) exitWith { ["-SEC-", _caller, format ["BLOCKED adminMsg by %1", _callerUID]] call APS_fnc_logIt; };

[[5, _name, _msg, objNull], "AP_fnc_clientMessage", -2, false, false] spawn AP_fnc_MP;
[[990, objNull, format ["ADMIN MSG by %1: %2", _name, _msg]], "APS_fnc_logIt", false, false] spawn AP_fnc_MP;
