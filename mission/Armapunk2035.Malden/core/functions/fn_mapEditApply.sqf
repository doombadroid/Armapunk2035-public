/*
    File: fn_mapEditApply.sqf  (AP_fnc_mapEditApply)
    Apply ONE map op to this client's row maps. Two ops, both by id. Server-origin only: rows
    carry init code, so this is NOT in CfgRE and a remoteExec from any other sender is dropped.

      upsert [row]   row = the 12-element wire row (mapdb.md D2)
      del [id]

    This edits the maps and marks ids dirty; it NEVER creates objects. remoteExec'd functions
    run in the scheduled environment and would interleave with AP_fnc_mapTick, which is the
    one creator/deleter. A row whose cell is "wanted" is buffered until that blob lands (its
    rev decides); a row whose cell was never fetched is dropped -- the fetch carries it.
    params: 0 = op, 1 = payload, 2 = rev (optional; -1 = unknown, always applied)
*/
// Local calls (self-test) pass. The mapCellRecv replay is a `call` deep inside that fn's scheduled remoteExec,
// past a possible suspension, so it is recognised by its caller-scope marker rather than by
// remoteExecutedOwner there; a local variable cannot be sent over the network.
if (isRemoteExecuted && {remoteExecutedOwner != 2} && {isNil "_mapCellReplay"}) exitWith {};
params [["_op", "", [""]], ["_payload", [], [[]]], ["_rev", -1, [0]]];
if (isDedicated) exitWith {};      // the server keeps its own copy in APS_fnc_mapRowUpdate
private _rowMap = localNamespace getVariable "AP_mapRows";   // the stores: localNamespace, see AP_fnc_mapStreamInit
if (isNil "_rowMap") exitWith {};   // streamer not up (a headless client outside the self-test)
switch (toLower _op) do {
    case "upsert": {
        _payload params [["_row", [], [[]]]];
        if (count _row < 12) exitWith { diag_log format ["[AP-MAPEDIT] upsert with %1 elements refused", count _row]; };
        private _id = _row select 6;
        if (!(_id isEqualType 0) || {_id < 1}) exitWith {};
        private _k = [_row select 1, _row select 10] call AP_fnc_mapCellFor;
        private _st = (localNamespace getVariable "AP_mapCells") getOrDefault [_k, "none"];
        if (_st isEqualTo "wanted") exitWith {
            private _pending = localNamespace getVariable "AP_mapPending";
            private _p = _pending getOrDefault [_k, []];
            _p pushBack [_rev, "upsert", _payload];
            _pending set [_k, _p];
        };
        [_id] call AP_fnc_mapEditRemoveId;   // a move out of a held cell must still delete the old object
        if (_st isEqualTo "none") exitWith {};
        _rowMap set [_id, _row];
        private _cellRows = localNamespace getVariable "AP_mapCellRows";
        private _ids = _cellRows getOrDefault [_k, []];
        _ids pushBackUnique _id;
        _cellRows set [_k, _ids];
        diag_log format ["[AP-MAPEDIT] apply upsert id=%1 cell=%2 rev=%3", _id, _k, _rev];
    };
    case "del": {
        _payload params [["_id", -1, [0]]];
        private _n = [_id] call AP_fnc_mapEditRemoveId;
        diag_log format ["[AP-MAPEDIT] apply del id=%1 removed=%2", _id, _n];
    };
    default { diag_log format ["[AP-MAPEDIT] unknown op %1", _op]; };
};
