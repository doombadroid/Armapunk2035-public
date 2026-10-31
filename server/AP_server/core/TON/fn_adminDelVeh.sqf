/*
    APS_fnc_adminDelVeh  (LooneyBin: REPAIRED -- was a broken passthrough to DB_fnc_deleteVehicle)
    Client args: [cursorObject, admin]  (admin keybind, gated adminLevel>=3 in fn_keyUpHandler case 211)

    Despawns the targeted vehicle. NON-DESTRUCTIVE by design: if it's an owned vehicle (AP_dbInfo), mark
    it active=0 so it returns to the owner's garage rather than being permanently deleted (the old wiring
    fed mismatched args to DB_fnc_deleteVehicle anyway -> nuked nothing or the wrong row). Players riding
    it are moved out first so the admin can't accidentally delete a person.
*/
params [["_veh", objNull, [objNull]], ["_admin", objNull, [objNull]]];
if (isNull _veh || {_veh isKindOf "CAManBase"}) exitWith {};

// owner 2026-06-23 SECURITY (security.md §2.3 — no admin check): this had NO server-side authz, so any
// client could remoteExec [anyVeh, anyObj] to despawn ANY vehicle (grief). Re-query the NON-SPOOFABLE
// caller's adminlevel and require >= 3 (client keybind gate fn_keyUpHandler case 211 = adminLevel>=3).
private _src = remoteExecutedOwner;
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
private _callerUID = getPlayerUID _caller;
private _lvl = if (_src isEqualTo 0) then { 999 } else {
    private _rows = [format ["SELECT adminlevel FROM players_global WHERE playerid='%1'", _callerUID], 2, true] call DB_fnc_asyncQuery;
    parseNumber format ["%1", (_rows param [0, [0]]) param [0, 0]]};
if (_lvl < 3) exitWith { ["-SEC-", _caller, format ["BLOCKED adminDelVeh by %1", _callerUID]] call APS_fnc_logIt; };

private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };
private _dbInfo = _veh getVariable ["AP_dbInfo", []];
if (count _dbInfo >= 2) then {private _owner = _dbInfo select 0;
    private _plate = _dbInfo select 1;
    if (!(_owner isEqualTo "") && {_plate isEqualType 0} && {_plate > 0}) then {
        // owner 2026-06-23 SECURITY (security.md §2.3): escape _owner (server-side veh var, but defensively
        // sanitized) + _plate forced numeric via params type [0] above -> round for the SQL.
        [format ["UPDATE vehicles SET active = false WHERE pid='%1' AND plate='%2'", _owner call _san, round _plate]] call DB_fnc_asyncQuery;   // return to garage, not destroyed
    };};
{ if (isPlayer _x) then { moveOut _x; }; } forEach (crew _veh);
deleteVehicle _veh;
[[992, _admin, format ["admin %1 (%2) despawned a %3 (returned to garage if owned). Srv %4", name _admin, getPlayerUID _admin, typeOf _veh, AP_server_instance]], "APS_fnc_logIt", false, false] spawn AP_fnc_MP;
