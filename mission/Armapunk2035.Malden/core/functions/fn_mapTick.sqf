/*
    File: fn_mapTick.sqf  (AP_fnc_mapTick)
    One streamer tick -- the ONLY code that creates or deletes map objects on this machine.
    AP_fnc_mapEditApply only edits the row maps and marks ids dirty: remoteExec'd functions run
    scheduled and would interleave with this. mapdb.md D5.

      1. request cells within fetchR that we do not hold (or asked for and never got)
      2. dirty ids: the live object goes; step 4 recreates it if still wanted
      3. delete pass over everything live: row gone, above the detail tier, or beyond
         stream_r + hyst from the focus (held while within that of the last vehicle)
      4. create pass over the far bucket + in-range cells, nearest first, createBatch per uiSleep
*/
private _rowMap = localNamespace getVariable "AP_mapRows";   // the stores: localNamespace, see AP_fnc_mapStreamInit
if (isDedicated || {isNil "_rowMap"}) exitWith {};
private _cellRows = localNamespace getVariable "AP_mapCellRows";
private _cells = localNamespace getVariable "AP_mapCells";
private _asked = localNamespace getVariable "AP_mapCellAsked";
private _live = localNamespace getVariable "AP_mapLive";
private _dirty = localNamespace getVariable "AP_mapDirty";
private _cfg = call AP_fnc_mapCfg;
// Foci, in priority: an explicit AP_mapFocus (the self-test, AP_fnc_mapWaitLoaded); else AP_mapFoci, an
// array of positions -- the headless client streams around every autopilot job it owns (init.sqf,
// 2026-09-07: its landing picker put an Orca beside a container it had never been sent); else the player.
// A headless client with no job streams nothing. Every distance below is to the NEAREST focus, so one
// focus behaves exactly as before.
private _foci = if (!isNil "AP_mapFocus") then { if (AP_mapFocus isEqualTo []) then { [] } else { [AP_mapFocus] } } else {
    if (!isNil "AP_mapFoci" && {AP_mapFoci isEqualType []} && {AP_mapFoci isNotEqualTo []}) then { AP_mapFoci } else {
        if (!hasInterface) then { [] } else { private _f = call AP_fnc_mapFocus; if (_f isEqualTo []) then { [] } else { [_f] } }
    }
};
if (_foci isEqualTo []) exitWith {};
private _fnDist = { params ["_p"]; private _d = 1e9; { _d = _d min (_x distance2D _p); } forEach _foci; _d };
// (The old loop skipped everything within 600 m of respawn_civilian. That marker is in the middle
// of town on Malden -- it only worked because everything outside a zone circle was "static" and
// loaded once at init. There is no static set now, so no such gate: owner hit an empty town, 2026-09-04.)
private _hyst = _cfg get "hyst";
private _defR = _cfg get "defaultR";
private _batch = _cfg get "createBatch";
// 1. cells
private _need = [];
{ { _need pushBackUnique _x; } forEach ([_x, _cfg get "fetchR"] call AP_fnc_mapCellsNear); } forEach _foci;
private _ask = _need select {
    private _st = _cells getOrDefault [_x, "none"];
    _st isEqualTo "none" || {_st isEqualTo "wanted" && {diag_tickTime - (_asked getOrDefault [_x, 0]) > (_cfg get "retry")}}
};
if (_ask isNotEqualTo []) then {
    { _cells set [_x, "wanted"]; _asked set [_x, diag_tickTime]; } forEach _ask;
    [["cells", _ask, player], "APS_fnc_mapFetch", 2, false] call AP_fnc_MP;
};
// the far bucket too: the init's one request can go unanswered (a headless client asking in the same second
// it connects is refused as "no resolvable requester", 2026-09-07) and nothing re-asked -- no towers, ever
if ((_cells getOrDefault ["far", "none"]) isEqualTo "wanted" && {diag_tickTime - (_asked getOrDefault ["far", 0]) > (_cfg get "retry")}) then {
    _asked set ["far", diag_tickTime];
    [["far", [], player], "APS_fnc_mapFetch", 2, false] call AP_fnc_MP;
};
// 2. dirty
private _nd = 0;
{
    private _o = _live get _x;
    if (!isNil "_o") then { deleteVehicle _o; _live deleteAt _x; _nd = _nd + 1; };
} forEach _dirty;
_dirty resize 0;   // in place: the stored array is the one AP_fnc_mapEditRemoveId appends to
// 3. delete pass
private _hold = if (isNull AP_dynamicMap_lastVehicle) then { [] } else { getPosWorld AP_dynamicMap_lastVehicle };
private _del = [];
{
    private _row = _rowMap get _x;
    if (isNil "_row") then { _del pushBack _x; } else {
        private _r = _row select 10;
        if (_r < 0) then { _r = _defR; };
        private _out = _r > 0 && {([_row select 1] call _fnDist) > _r + _hyst}
                       && {_hold isEqualTo [] || {(_hold distance2D (_row select 1)) > _r + _hyst}};
        if (_out || {(_row select 9) > AP_mapDetail}) then { _del pushBack _x; };
    };
} forEach (keys _live);
{
    private _o = _live get _x;
    if (!isNil "_o") then { deleteVehicle _o; };
    _live deleteAt _x;
    _nd = _nd + 1;
    if (_nd mod _batch == 0) then { uiSleep 0.002; };
} forEach _del;
// 4. create pass, nearest first
private _mk = [];
{
    {
        if !(_x in _live) then {
            private _row = _rowMap get _x;
            if (!isNil "_row" && {!(_row select 4)} && {(_row select 9) <= AP_mapDetail}) then {
                private _r = _row select 10;
                if (_r < 0) then { _r = _defR; };
                private _d = [_row select 1] call _fnDist;
                if (_r isEqualTo 0 || {_d < _r}) then { _mk pushBack [_d, _x]; };
            };
        };
    } forEach (_cellRows getOrDefault [_x, []]);
} forEach (["far"] + _need);
_mk sort true;
private _nc = 0;
{
    private _row = _rowMap get (_x select 1);
    if (!isNil "_row") then {
        private _o = _row call AP_fnc_createVehicleLocal;
        if (!isNull _o) then { _live set [_x select 1, _o]; };
        _nc = _nc + 1;
        if (_nc mod _batch == 0) then { uiSleep 0.001; };
    };
} forEach _mk;
if (AP_mapReady && {!AP_mapFarDone}) then {
    AP_mapFarDone = true;
    private _loaded = count ((keys _cells) select { (_cells get _x) isEqualTo "loaded" });
    diag_log format ["[AP-MAP] join: far %1 rows, %2 cells loaded, %3 live after first pass, %4 s since init",
        count (_cellRows getOrDefault ["far", []]), _loaded, count _live, (diag_tickTime - AP_mapT0) toFixed 1];
};
if (_nc + _nd > 0) then { diag_log format ["[AP-MAP] tick: +%1 -%2 live=%3", _nc, _nd, count _live]; };
AP_mapTickN = (missionNamespace getVariable ["AP_mapTickN", 0]) + 1;   // a waiter counts full ticks (the create pass included)
