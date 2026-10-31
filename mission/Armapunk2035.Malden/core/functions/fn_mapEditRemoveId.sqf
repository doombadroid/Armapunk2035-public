/*
    File: fn_mapEditRemoveId.sqf  (AP_fnc_mapEditRemoveId)
    Forget one row by id: out of its cell index and the row map; if it is live, mark it dirty so
    the next AP_fnc_mapTick deletes the object (this function never touches the world itself).
    params: 0 = id     returns: rows removed (0 or 1)
*/
params [["_id", -1, [0]]];
private _rowMap = localNamespace getVariable "AP_mapRows";   // the stores: localNamespace, see AP_fnc_mapStreamInit
if (_id < 1 || {isNil "_rowMap"}) exitWith { 0 };
private _row = _rowMap get _id;
if (isNil "_row") exitWith { 0 };
private _k = [_row select 1, _row select 10] call AP_fnc_mapCellFor;
private _cellRows = localNamespace getVariable "AP_mapCellRows";
private _ids = _cellRows getOrDefault [_k, []];
private _i = _ids find _id;
if (_i > -1) then { _ids deleteAt _i; _cellRows set [_k, _ids]; };
_rowMap deleteAt _id;
if (_id in (localNamespace getVariable "AP_mapLive")) then { (localNamespace getVariable "AP_mapDirty") pushBackUnique _id; };
1
