/*
    File: fn_mapCellFor.sqf  (AP_fnc_mapCellFor)
    Which cell holds a row. A pure function of (x, y, stream_r), so the server index, every
    client's index and the editor cannot disagree -- the same reason AP_fnc_mapZoneFor used to be
    the one binning rule.
    params: 0 = position (world frame), 1 = stream_r (-1 = default, 0 = always)
    returns: "far" or "<cx>_<cy>"
*/
params [["_pos", [], [[]]], ["_r", -1, [0]]];
private _cfg = call AP_fnc_mapCfg;
if (_r < 0) then { _r = _cfg get "defaultR"; };
if (_r isEqualTo 0 || {_r > (_cfg get "far")}) exitWith { "far" };
private _c = _cfg get "cell";
format ["%1_%2", floor ((_pos select 0) / _c), floor ((_pos select 1) / _c)]
