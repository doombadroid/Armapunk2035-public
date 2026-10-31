/*
    File: fn_mapCellsNear.sqf  (AP_fnc_mapCellsNear)
    Every cell whose square comes within _rad of _pos (nearest-edge test, not centre distance,
    so a row 10 m over a cell border is fetched as early as one 10 m on this side of it).
    params: 0 = position, 1 = radius (m)
    returns: [keys]; never includes "far"
*/
params [["_pos", [], [[]]], ["_rad", 0, [0]]];
private _c = (call AP_fnc_mapCfg) get "cell";
private _x0 = _pos select 0;
private _y0 = _pos select 1;
private _out = [];
for "_cx" from floor ((_x0 - _rad) / _c) to floor ((_x0 + _rad) / _c) do {
    for "_cy" from floor ((_y0 - _rad) / _c) to floor ((_y0 + _rad) / _c) do {
        private _nx = (_x0 max (_cx * _c)) min ((_cx + 1) * _c);
        private _ny = (_y0 max (_cy * _c)) min ((_cy + 1) * _c);
        if (([_x0, _y0, 0] distance2D [_nx, _ny, 0]) <= _rad) then { _out pushBack format ["%1_%2", _cx, _cy]; };
    };
};
_out
