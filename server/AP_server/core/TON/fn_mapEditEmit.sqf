/*
    File: fn_mapEditEmit.sqf  (APS_fnc_mapEditEmit)
    After the authority writes a row: fetch it back, update the cache, broadcast.

    The write itself cannot return the row on this transport, so it is read back by id.
    APS_fnc_mapRowUpdate stores it, bumps APS_mapRev and broadcasts -- so the next poll's
    "rev > APS_mapRev" query no longer returns it.

    Server-only. No CfgRE entry.
*/
params [["_id", -1, [0]]];
if (!isServer || {_id < 1}) exitWith {};
private _rows = [
    "SELECT " + (localNamespace getVariable "APS_mapSelectCols") + " FROM map_objects WHERE world = %s AND id = %s",   // localNamespace: APS_fnc_mapLoad
    2, true, [worldName, _id]
] call DB_fnc_asyncQuery;
if (_rows isEqualTo []) exitWith { diag_log format ["[AP-MAPEDIT] emit: id %1 not found after write", _id]; };
private _t = [_rows select 0] call APS_fnc_mapRowOp;
if (_t isEqualTo []) exitWith {};
[_t, true] call APS_fnc_mapRowUpdate;
