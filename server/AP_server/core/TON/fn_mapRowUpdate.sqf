/*
    File: fn_mapRowUpdate.sqf  (APS_fnc_mapRowUpdate)
    The single mutator of the server's in-memory map (mapdb.md D4).
    params: 0 = [id, rev, op] from APS_fnc_mapRowOp, 1 = broadcast to clients (false at boot)
    Removes the old row from its cell, stores the new one, invalidates both cell blobs,
    moves or re-spawns the server's own copy for is_server / on_server rows (after boot), and
    broadcasts [op, payload, rev] to every client. Server-only, no CfgRE entry.

    The server's object SURVIVES a geometry edit. The boot resolvers (the Reserve's perimeter
    gates, ring safes, dome and centre; the bank's back-alley gate; the emporium's gates; the
    compound gates) hold handles to is_server objects, and since props pass 2 (2026-09-09) those
    objects are table rows: a delete + recreate on every Eden drag left every handle stale until
    the next restart. So a row whose identity is unchanged -- class, init, is_server, loadout,
    model, on_server -- keeps its object and is moved with AP_fnc_mapPlace; anything else is a
    new object as before. Model rows and simple objects always recreate (creation is what
    places a fresh simple object; nothing binds to them).
*/
params [["_t", [], [[]]], ["_broadcast", true, [true]]];
_t params ["_id", "_rev", "_op"];
// The stores live in localNamespace (APS_fnc_mapLoad), bound once here and mutated in place.
private _mapRows = localNamespace getVariable "APS_mapRows";
private _mapText = localNamespace getVariable "APS_mapText";
private _mapCells = localNamespace getVariable "APS_mapCells";
private _mapBlobs = localNamespace getVariable "APS_mapBlobs";
private _mapLive = localNamespace getVariable "APS_mapLive";
private _cellDel = {
    params ["_k", "_id"];
    private _ids = _mapCells getOrDefault [_k, []];
    private _i = _ids find _id;
    if (_i > -1) then {
        _ids deleteAt _i;
        if (_ids isEqualTo []) then { _mapCells deleteAt _k; } else { _mapCells set [_k, _ids]; };
    };
    _mapBlobs deleteAt _k;
};
private _upsert = (_op select 0) isEqualTo "upsert";
private _txt = "";
private _row = [];
if (_upsert) then {
    // The row this server holds IS the parse of the text a client will receive. The table
    // carries doubles with up to 16 decimals (the pavement z-fix wrote them); the text has 3/4
    // (what the baked file always shipped), and a float that went through toFixed no longer
    // isEqualTo its origin -- ten cells failed APS_fnc_mapBlob's round-trip check that way on
    // 2026-09-04. Canonicalising here makes server, blob and client agree by construction.
    _txt = [(_op select 1) select 0] call AP_fnc_mapRowText;
    _row = parseSimpleArray _txt;
};
// A row that does not parse is dropped BEFORE the old one is touched (it used to be removed first,
// so a bad update deleted the object it failed to replace).
if (_upsert && {!(_row isEqualType []) || {count _row < 12}}) exitWith { diag_log format ["[AP-MAP] row %1 does not parse back from its own text -- dropped", _id]; };
private _old = _mapRows get _id;
private _live = _mapLive get _id;   // the server's own object, is_server / on_server rows only
private _keep = _upsert && {!isNil "_old"} && {!isNil "_live"} && {!isNull _live} && {!isSimpleObject _live}
    && {(_row select 7) isEqualTo ""}
    && {[_old select 0, _old select 3, _old select 4, _old select 5, _old select 7, _old select 11]
        isEqualTo [_row select 0, _row select 3, _row select 4, _row select 5, _row select 7, _row select 11]};
if (!isNil "_old") then {
    [[_old select 1, _old select 10] call AP_fnc_mapCellFor, _id] call _cellDel;
    _mapRows deleteAt _id;
    _mapText deleteAt _id;
    if (!_keep && {!isNil "_live"}) then { deleteVehicle _live; _mapLive deleteAt _id; };
};
if (_upsert) then {
    _op set [1, [_row]];
    _mapRows set [_id, _row];
    _mapText set [_id, _txt];
    private _k = [_row select 1, _row select 10] call AP_fnc_mapCellFor;
    private _ids = _mapCells getOrDefault [_k, []];
    _ids pushBackUnique _id;
    _mapCells set [_k, _ids];
    _mapBlobs deleteAt _k;
    if (_keep) then {
        [_live, _row select 2, _row select 1, _row select 8] call AP_fnc_mapPlace;
        diag_log format ["[AP-MAP] row %1 (%2) moved in place, object kept", _id, _row select 0];
    } else {
        // The boot load spawns its rows once the world has settled (APS_fnc_mapLoad); only a
        // post-boot edit spawns here.
        if (localNamespace getVariable ["APS_mapReady", false] && {(_row select 4) || {_row select 11}}) then {
            private _o = _row call AP_fnc_createVehicleLocal;
            if (!isNull _o) then { _mapLive set [_id, _o]; };
        };
    };
};
if (_broadcast) then {
    if (_rev > (localNamespace getVariable ["APS_mapRev", 0])) then { localNamespace setVariable ["APS_mapRev", _rev]; };
    [[_op select 0, _op select 1, _rev], "AP_fnc_mapEditApply", 0, false] call AP_fnc_MP;
};
