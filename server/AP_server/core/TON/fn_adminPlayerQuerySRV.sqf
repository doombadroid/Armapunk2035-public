/*
    APS_fnc_adminPlayerQuerySRV  (LooneyBin -- implemented 2026-06-09; the passthrough fed a player
    OBJECT into the 2017 adminlevel lookup's uid slot -> the spectate/ESP suspect-info panel never
    populated.)  Client (adminSpectate) sends [adminObj, adminUID, suspectObj, suspectUID]; expects
    AP_suspectInfo (netSetVar-approved) = a flat info array the ESP panel formats.
*/
params [["_admin", objNull, [objNull]], ["_adminUID", "", [""]], ["_suspect", objNull, [objNull]], ["_suspectUID", "", [""]]];
if (isNull _admin || {_suspectUID isEqualTo ""}) exitWith {};

// owner 2026-06-23 SECURITY (security.md §2.2/2.3 — no admin check + SQLi): this had NO server-side authz,
// so any client could remoteExec it to dump ANY player's cash/bank/levels, and the client _suspectUID was
// interpolated RAW into the SELECTs (injection/exfil). Re-query the NON-SPOOFABLE caller's adminlevel and
// require >= 2 (query gate); send the result to the REAL caller (not the passed _admin object); escape the
// suspect UID. remoteExecutedOwner 0 = server-internal = trusted.
private _src = remoteExecutedOwner;
private _caller = if (_src isEqualTo 0) then { _admin } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
private _callerUID = getPlayerUID _caller;
private _lvl = if (_src isEqualTo 0) then { 999 } else {
    private _rows = [format ["SELECT adminlevel FROM players_global WHERE playerid='%1'", _callerUID], 2, true] call DB_fnc_asyncQuery;
    parseNumber format ["%1", (_rows param [0, [0]]) param [0, 0]]};
if (_lvl < 2) exitWith { ["-SEC-", _caller, format ["BLOCKED adminPlayerQuerySRV by %1", _callerUID]] call APS_fnc_logIt; };
private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };
_suspectUID = _suspectUID call _san;
private _p = [format ["SELECT name, cash, bankacc, new_drachma FROM players WHERE playerid='%1'", _suspectUID], 2] call DB_fnc_asyncQuery;
private _g = [format ["SELECT adminlevel, coplevel, mediclevel FROM players_global WHERE playerid='%1'", _suspectUID], 2] call DB_fnc_asyncQuery;
private _info = [_suspectUID];
if (_p isEqualType [] && {count _p >= 4}) then {
    _info append [format ["%1", _p select 0], parseNumber format ["%1", _p select 1], parseNumber format ["%1", _p select 2], parseNumber format ["%1", _p select 3]];
};
if (_g isEqualType [] && {count _g >= 3}) then {
    _info append [parseNumber format ["%1", _g select 0], parseNumber format ["%1", _g select 1], parseNumber format ["%1", _g select 2]];
};
[["AP_suspectInfo", _info], "AP_fnc_netSetVar", _caller, false, false] spawn AP_fnc_MP;
["-ADMINACTION-", _caller, format ["queried suspect info for %1", _suspectUID]] call APS_fnc_logIt;
