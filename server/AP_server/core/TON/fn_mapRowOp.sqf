/*
    File: fn_mapRowOp.sqf  (APS_fnc_mapRowOp)
    One database row of map_objects -> [id, rev, op] for AP_fnc_mapEditApply.

    The ONLY place a row becomes an op. The boot load, the poll and every in-game
    write all pass through here, so a client can never receive two shapes for one row.

    Column order is fixed and shared by every SELECT that feeds this (APS_mapSelectCols,
    set in localNamespace by APS_fnc_mapLoad):
      id, classname, x, y, z, vdir_x, vdir_y, vdir_z, vup_x, vup_y, vup_z,
      init, is_server, COALESCE(loadout,'') AS loadout, deleted, rev,
      model, scale, lod, COALESCE(stream_r,-1) AS stream_r, on_server   -- v3 (mapdb.md D2)
    Numbers pass through untouched, strings are parsed, booleans go through a string test:
    the transport's typing is observed, not assumed -- and never rounded.
*/
params [["_r", [], [[]]]];
if (count _r < 21) exitWith { [] };
// A Number stays a Number: format prints six significant figures, so a coordinate east of
// x = 10000 would lose up to 5 cm on the way through (mapdb.md D2). Only a String is parsed.
private _n = { if (_this isEqualType 0) then { _this } else { parseNumber format ["%1", _this] } };
private _b = { (toLower format ["%1", _this]) in ["true", "t", "1"] };
_r params ["_id", "_cls", "_px", "_py", "_pz", "_dx", "_dy", "_dz", "_ux", "_uy", "_uz",
           "_init", "_srv", "_lo", "_del", "_rev", "_model", "_scale", "_lod", "_sr", "_os"];
_id = _id call _n; _rev = _rev call _n;
if (_del call _b) exitWith { [_id, _rev, ["del", [_id]]] };
private _loadout = if ((format ["%1", _lo]) isEqualTo "") then { [] } else { parseSimpleArray (format ["%1", _lo]) };
[_id, _rev, ["upsert", [[
    format ["%1", _cls],
    [_px call _n, _py call _n, _pz call _n],
    [[_dx call _n, _dy call _n, _dz call _n], [_ux call _n, _uy call _n, _uz call _n]],
    format ["%1", _init],
    _srv call _b,
    _loadout,
    _id,
    format ["%1", _model],
    _scale call _n,
    _lod call _n,
    _sr call _n,
    _os call _b]]]]
