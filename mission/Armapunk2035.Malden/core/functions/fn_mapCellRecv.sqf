/*
    File: fn_mapCellRecv.sqf  (AP_fnc_mapCellRecv)
    One cell blob from the server. Server -> this client only; rows carry init code that this
    machine compiles, so no client may ever be the sender: NOT in CfgRE, and gated below.
    params: 0 = key, 1 = rev the blob was built at, 2 = deflated literal ("" = empty cell), 3 = rows
    A cell is fetched once per session; an inflate or parse failure resets it so the next tick
    asks again. Edits that raced the fetch (AP_mapPending) replay only when newer than the blob.
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // the self-test's local call passes
params [["_k", "", [""]], ["_rev", -1, [0]], ["_packed", "", [""]], ["_n", 0, [0]]];
private _rowMap = localNamespace getVariable "AP_mapRows";   // the stores: localNamespace, see AP_fnc_mapStreamInit
if (isDedicated || {isNil "_rowMap"}) exitWith {};
private _cells = localNamespace getVariable "AP_mapCells";
private _pending = localNamespace getVariable "AP_mapPending";
private _t0 = (localNamespace getVariable "AP_mapCellAsked") getOrDefault [_k, diag_tickTime];
private _txt = if (_packed isEqualTo "") then { "[]" } else { controlNull ctrlWebBrowserAction ["Inflate", _packed] };
if (_txt isEqualTo "") exitWith {
    diag_log format ["[AP-MAP] inflate FAILED cell %1 (%2 chars) -- will re-request", _k, count _packed];
    _cells set [_k, "none"];
};
private _rows = parseSimpleArray _txt;
if (!(_rows isEqualType []) || {count _rows != _n}) exitWith {
    diag_log format ["[AP-MAP] cell %1: parsed %2 rows, server said %3 -- refused", _k, if (_rows isEqualType []) then { count _rows } else { -1 }, _n];
    _cells set [_k, "none"];
};
private _ids = [];
{
    if (_x isEqualType [] && {count _x >= 12}) then { _rowMap set [_x select 6, _x]; _ids pushBack (_x select 6); };
} forEach _rows;
(localNamespace getVariable "AP_mapCellRows") set [_k, _ids];
_cells set [_k, "loaded"];
(localNamespace getVariable "AP_mapCellRev") set [_k, _rev];
private _mapCellReplay = true;   // origin already checked above; AP_fnc_mapEditApply's gate reads this marker
{
    _x params ["_r", "_op", "_pl"];
    if (_r > _rev) then { [_op, _pl, _r] call AP_fnc_mapEditApply; };
} forEach (_pending getOrDefault [_k, []]);
_pending deleteAt _k;
if (_k isEqualTo "far") then { AP_mapReady = true; };
diag_log format ["[AP-MAP] cell %1 rev %2: %3 rows, %4 packed chars, %5 s", _k, _rev, count _ids, count _packed, (diag_tickTime - _t0) toFixed 2];
