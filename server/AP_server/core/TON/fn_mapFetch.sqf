/*
    File: fn_mapFetch.sqf  (APS_fnc_mapFetch)
    A client asks for map cells; the server answers from memory (mapdb.md D4/D6).
    CfgRE allowedTargets = 2. READ-ONLY. The requester is remoteExecutedOwner; a HEADLESS
    client's request arrives with owner 0 (engine, by design) and may name its own unit, exactly
    as APS_fnc_mapEditLoad allowed -- the reply is idempotent and carries nothing the client
    could not already ask for. Replies go to the requester only.
    params: 0 = "far" | "cells" | "index", 1 = [keys] for "cells", 2 = requester unit (HC only)
*/
params [["_kind", "", [""]], ["_keys", [], [[]]], ["_unit", objNull, [objNull]]];
if (!isServer) exitWith {};
private _owner = remoteExecutedOwner;
if (_owner isEqualTo 0 && {!isNull _unit} && {_unit in allPlayers}) then { _owner = owner _unit; };
if (_owner isEqualTo 0) exitWith { diag_log "[AP-MAP] fetch: no resolvable requester -- refused"; };
// The cache and its stores live in localNamespace (APS_fnc_mapLoad): no client can forge them.
if !(localNamespace getVariable ["APS_mapReady", false]) then {
    private _t = diag_tickTime;
    waitUntil { (localNamespace getVariable ["APS_mapReady", false]) || {diag_tickTime - _t > 120} };
};
if !(localNamespace getVariable ["APS_mapReady", false]) exitWith { diag_log format ["[AP-MAP] fetch: cache not ready, owner %1 refused", _owner]; };
// 6 requests per 10 s per owner: a join asks once for the far bucket and once per tick for
// missing cells; the self-test asks in batches of 64.
private _mapRate = localNamespace getVariable "APS_mapFetchRate";
private _rl = _mapRate getOrDefault [_owner, [0, diag_tickTime]];
if (diag_tickTime - (_rl select 1) > 10) then { _rl = [0, diag_tickTime]; };
_rl set [0, (_rl select 0) + 1];
_mapRate set [_owner, _rl];
if ((_rl select 0) > 6) exitWith { diag_log format ["[AP-MAP] fetch: owner %1 rate-limited (%2 in 10 s)", _owner, _rl select 0]; };
if (_kind isEqualTo "index") exitWith {
    private _mapCells = localNamespace getVariable "APS_mapCells";
    private _nRows = count (localNamespace getVariable "APS_mapRows");
    [[keys _mapCells, _nRows, localNamespace getVariable "APS_mapRev"], "AP_fnc_mapIndexRecv", _owner, false] call AP_fnc_MP;
    diag_log format ["[AP-MAP] fetch owner=%1 kind=index cells=%2 rows=%3", _owner, count _mapCells, _nRows];
};
private _list = switch (_kind) do {
    case "far":   { ["far"] };
    case "cells": { (_keys select { _x isEqualType "" && {count _x <= 12} && {_x regexMatch "-?\d+_-?\d+"} }) select [0, 64] };
    default { [] };
};
private _chars = 0;
{
    private _b = [_x] call APS_fnc_mapBlob;
    _chars = _chars + count (_b select 1);
    [[_x, _b select 0, _b select 1, _b select 2], "AP_fnc_mapCellRecv", _owner, false] call AP_fnc_MP;
} forEach _list;
diag_log format ["[AP-MAP] fetch owner=%1 kind=%2 keys=%3 packed=%4 chars", _owner, _kind, count _list, _chars];
