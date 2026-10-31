/*
    debug/probe_townspawn.sqf -- DEV PROBE, server side. Finds places in a town where a player can
    actually stand, and logs them. Offline data cannot answer this: Malden's own houses are TERRAIN
    objects, so they are in neither mission.sqm nor map_objects, and a marker placed by eye lands
    inside a wall.

        [] execVM "debug\probe_townspawn.sqf";

    Read it with: journalctl --user -u armapunk-arma | grep "AP-PROBE..townspawn"

    HOW A POINT IS JUDGED, and why not the obvious way:
      * isFlatEmpty's PROXIMITY test is useless in a town. It counts an object's whole BOUNDING
        SPHERE (BIKI, Killzone_Kid's note), so a building 15 m away fails a 3 m check -- on the
        first run every one of 36 candidates failed it while sitting on an open road with nothing
        within 4 m. Only its gradient and land/water tests are used here.
      * isFlatEmpty's SECOND argument (mode) must be -1. Anything else, 0 included, makes the
        command "unusable" (BIKI, Problems) and it answers [] for every position on the map.
      * The real question -- "is this spot indoors or against a wall?" -- is asked with geometry
        rays: one straight up (a roof above means indoors or under an overhang) and eight short
        horizontal ones at chest height (a hit means a wall, fence or post within 1.2 m).
    Positions are built ASL from getTerrainHeightASL so there is no AGL/ASL confusion.
*/
private _towns = [
    ["La Port",     [8175, 3163]],
    ["Chapoi",      [5870, 3535]],
    ["La Pessagne", [3130, 6323]]
];
private _radius = 150;
private _step   = 12;

private _standable = {
    params ["_x", "_y"];
    private _p = [_x, _y, 0];
    if (surfaceIsWater _p) exitWith { [] };
    if ((_p isFlatEmpty [-1, -1, 0.3, 8, 0, false, objNull]) isEqualTo []) exitWith { [] };   // gradient + land only
    if ((count (nearestTerrainObjects [_p, ["BUILDING", "HOUSE", "CHURCH", "HOSPITAL", "FUELSTATION", "SHOP", "RUIN", "FORTRESS", "WALL", "FENCE"], 3, false, true])) > 0) exitWith { [] };
    if ((count ((nearestObjects [_p, ["Building", "Wall"], 3]) select { alive _x })) > 0) exitWith { [] };
    private _g = getTerrainHeightASL _p;
    private _chest = [_x, _y, _g + 1.0];
    // a roof overhead = indoors
    if ((count (lineIntersectsSurfaces [_chest, [_x, _y, _g + 40], objNull, objNull, true, 1, "GEOM", "NONE"])) > 0) exitWith { [] };
    // a wall within 1.2 m in any of eight directions
    private _hit = false;
    {
        private _r = _x * 45;
        private _e = [(_chest select 0) + 1.2 * sin _r, (_chest select 1) + 1.2 * cos _r, _chest select 2];
        if (!_hit && {(count (lineIntersectsSurfaces [_chest, _e, objNull, objNull, true, 1, "GEOM", "NONE"])) > 0}) then { _hit = true; };
    } forEach [0, 1, 2, 3, 4, 5, 6, 7];
    if (_hit) exitWith { [] };
    [_x, _y]
};

diag_log format ["[AP-PROBE][townspawn] start -- %1 m radius, %2 m grid", _radius, _step];
{
    _x params ["_town", "_ctr"];
    _ctr params ["_cx", "_cy"];
    private _hits = [];
    for "_dx" from -_radius to _radius step _step do {
        for "_dy" from -_radius to _radius step _step do {
            private _x2 = _cx + _dx;
            private _y2 = _cy + _dy;
            if (_dx * _dx + _dy * _dy <= _radius * _radius) then {
                private _ok = [_x2, _y2] call _standable;
                if (_ok isNotEqualTo []) then { _hits pushBack [(([_x2, _y2, 0] distance2D [_cx, _cy, 0])), _x2, _y2, count ([_x2, _y2, 0] nearRoads 12)]; };
            };
        };
        uiSleep 0.05;
    };
    _hits sort true;   // nearest the centre first
    // thin to points at least 30 m apart, so five spawns do not stack on one street corner
    private _picks = [];
    {
        _x params ["_d", "_px", "_py", "_road"];
        if ((_picks findIf { ((_x select 1) - _px) ^ 2 + ((_x select 2) - _py) ^ 2 < 900 }) < 0) then { _picks pushBack _x; };
    } forEach _hits;
    diag_log format ["[AP-PROBE][townspawn] %1: %2 standable of the grid, %3 spread >=30 m", _town, count _hits, count _picks];
    {
        _x params ["_d", "_px", "_py", "_road"];
        diag_log format ["[AP-PROBE][townspawn] PICK %1 #%2 [%3,%4] %5 m from centre, roads12=%6", _town, _forEachIndex, _px, _py, _d toFixed 0, _road];
    } forEach (_picks select [0, 10]);
} forEach _towns;
diag_log "[AP-PROBE][townspawn] done";
