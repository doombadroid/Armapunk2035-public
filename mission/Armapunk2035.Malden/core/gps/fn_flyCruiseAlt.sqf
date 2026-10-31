/*
    AP_fnc_flyCruiseAlt -- cruise altitude (ASL) for a straight-line flight from _from to _to.

        [_from, _to, _ignore] call AP_fnc_flyCruiseAlt   -> Number (ASL)

    Highest SURFACE along the line -- terrain OR the top of whatever stands on it -- sampled every 25 m on
    the centreline and 25 m either side, + 80 m; never under 120 m over the start. Objects matter: the
    120 m Lux tower beside the respawn town put its roof ~40 m above a terrain-only cruise altitude and the
    first heli self-tests flew into its side (b0840/b0841, main-rotor strike at 57 m AGL). A ray from 500 m
    above the terrain straight down hits the tallest thing at that spot ("GEOM": what a rotor would hit).
    ~120 rays once per flight. _ignore = the aircraft itself, so its own hull does not count at sample 0.
    A registered function (not a lazily-defined global): every host needs it before its first step --
    the HC's AI flight host got nil and a NaN altitude when it lived inside fn_flyStep (b0849).
*/
params ["_from", "_to", ["_ignore", objNull, [objNull]], ["_margin", 80, [0]], ["_floor", 120, [0]]];
private _d = _from distance2D _to;
private _n = (ceil (_d / 25)) max 1;
private _dx = (_to select 0) - (_from select 0); private _dy = (_to select 1) - (_from select 1);
private _len = (sqrt (_dx * _dx + _dy * _dy)) max 0.01;
private _rx = -_dy / _len * 25; private _ry = _dx / _len * 25;   // 25 m to the side of the line
private _hi = 0;
for "_i" from 0 to _n do {
    private _t = _i / _n;
    private _cx = (_from select 0) + _dx * _t; private _cy = (_from select 1) + _dy * _t;
    {
        private _px = _cx + _rx * _x; private _py = _cy + _ry * _x;
        private _ter = getTerrainHeightASL [_px, _py, 0];
        _hi = _hi max _ter;
        private _hit = lineIntersectsSurfaces [[_px, _py, _ter + 500], [_px, _py, _ter - 1], _ignore, objNull, true, 1, "GEOM", "NONE"];
        if (_hit isNotEqualTo []) then { _hi = _hi max (((_hit select 0) select 0) select 2); };
    } forEach [-1, 0, 1];
};
(_hi + _margin) max ((getTerrainHeightASL [_from select 0, _from select 1, 0]) + _floor)
