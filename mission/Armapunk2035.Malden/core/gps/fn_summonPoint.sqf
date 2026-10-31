/*
    AP_fnc_summonPoint  (client) -- where a summoned vehicle appears: ~1 km out.

        [_from, _isAir] call AP_fnc_summonPoint     -> [x, y, 0, dir] or []

    Land: five bearings 72 degrees apart from a random start, 1000 m out, the nearest
    road within 150 m of each, kept only if AP_fnc_routeFind can route it back to
    _from with at least 4 points (what hcDrive needs). Nothing at 1000 m -> the same
    sweep at 700 m. Air: the same bearings, an isFlatEmpty spot within 150 m of the
    1000 m point (8 m clear, gradient <= 0.3 over 12 m), else the nearest road there.
    Runs on the CLIENT: it has the road graph (routeFind) and no server frames are spent.
*/
params [["_from", [], [[]]], ["_isAir", false, [false]]];
if (count _from < 2) exitWith { [] };
private _f2 = [_from select 0, _from select 1, 0];
private _out = [];
private _start = random 360;

private _fnRoad = {
    params ["_p"];
    private _rds = _p nearRoads 150;
    if (_rds isEqualTo []) exitWith { [] };
    private _best = _rds select 0;
    { if ((_p distance2D _x) < (_p distance2D _best)) then { _best = _x; }; } forEach _rds;
    getPosATL _best
};
private _fnFlat = {
    params ["_p"];
    private _hit = [];
    for "_r" from 0 to 150 step 25 do {
        for "_a" from 0 to 300 step 60 do {
            private _c = [(_p select 0) + _r * sin _a, (_p select 1) + _r * cos _a, 0];
            private _flat = _c isFlatEmpty [8, -1, 0.3, 12, 0, false, objNull];
            // never on a road: isFlatEmpty does not see road segments, and a Blackfish set down across one
            // collides with it and is destroyed within a second of spawning (b0854, twice)
            if (_flat isNotEqualTo [] && {!(isOnRoad [_flat select 0, _flat select 1, 0])}) exitWith { _hit = [_flat select 0, _flat select 1, 0]; };
        };
        if (_hit isNotEqualTo []) exitWith {};
    };
    _hit
};

{
    private _range = _x;
    for "_i" from 0 to 4 do {
        private _b = _start + _i * 72;
        private _p = _f2 getPos [_range, _b];
        if ((_p select 0) < 100 || {(_p select 1) < 100} || {(_p select 0) > worldSize - 100} || {(_p select 1) > worldSize - 100}) then { continue };
        if (surfaceIsWater _p) then { continue };
        private _sp = if (_isAir) then { [_p] call _fnFlat } else { [] };
        if (_sp isEqualTo [] && {!_isAir}) then { _sp = [_p] call _fnRoad; };   // air: flat ground or nothing, never a road
        if (_sp isEqualTo []) then { continue };
        if (!_isAir) then {
            private _r = [_sp, _f2] call AP_fnc_routeFind;
            if (!((_r param [0, []]) isEqualType []) || {count (_r param [0, []]) < 4}) then { continue };
        };
        // nose toward the summoner
        private _dir = ((_f2 select 0) - (_sp select 0)) atan2 ((_f2 select 1) - (_sp select 1));
        _out = [_sp select 0, _sp select 1, 0, _dir];
    };
    if (_out isNotEqualTo []) exitWith {};
} forEach [1000, 700];
_out
