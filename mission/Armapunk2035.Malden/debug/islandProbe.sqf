/*
    debug/islandProbe.sqf -- one-shot, DEV ONLY. Delete the call site when done.

    Answers "is the federal reserve on an island, and how big is it?" with the engine's own water
    test rather than by eyeballing the map. Samples surfaceIsWater on a grid, flood-fills the land
    the Fed stands on, and reports its bounds, its centre, and how far the nearest OTHER land is --
    which is what decides an air-defence radius.
*/
if (!isServer) exitWith {};

private _fed = [9834.63, 3955.65];   // owner landed here unopposed 2026-07-27
private _step = 25;
private _half = 2600;                       // 3 km box -- the island may be bigger than the last guess

diag_log "-ISLANDPROBE- START";
// ground truth first, unconditionally: what does the engine say AT the Fed and around it?
diag_log format ["-ISLANDPROBE- fed %1: water=%2 terrainASL=%3 worldSize=%4",
    _fed, surfaceIsWater _fed, (getTerrainHeightASL _fed) toFixed 2, worldSize];
{
    private _p = [(_fed select 0) + (_x select 0), (_fed select 1) + (_x select 1)];
    diag_log format ["-ISLANDPROBE-   offset %1 -> %2  water=%3 terrainASL=%4",
        _x, _p, surfaceIsWater _p, (getTerrainHeightASL _p) toFixed 2];
} forEach [[0,100],[0,-100],[100,0],[-100,0],[0,300],[0,-300],[300,0],[-300,0],[0,600],[0,-600],[600,0],[-600,0]];
// ASCII map of the area: '#' land, '.' water, 'F' the Fed marker. 50 m per character.
private _R = 25;                             // +-2500 m at 100 m steps
for "_gy" from _R to -_R step -1 do {
    private _line = "";
    for "_gx" from -_R to _R do {
        private _p = [(_fed select 0) + (_gx * 100), (_fed select 1) + (_gy * 100)];
        _line = _line + (if (_gx isEqualTo 0 && _gy isEqualTo 0) then {"F"} else {
            if (surfaceIsWater _p) then {"."} else {"#"}});
    };
    diag_log format ["-ISLANDMAP- %1 %2", ((_fed select 1) + (_gy * 100)) toFixed 0, _line];
};
private _cols = round ((2 * _half) / _step);
private _grid = [];                          // row-major, true = land
for "_gy" from 0 to _cols do {
    private _row = [];
    for "_gx" from 0 to _cols do {
        private _p = [(_fed select 0) - _half + (_gx * _step), (_fed select 1) - _half + (_gy * _step)];
        _row pushBack (!surfaceIsWater _p);
    };
    _grid pushBack _row;
};

// flood fill from the Fed's own cell -> the landmass it stands on
private _c = round (_cols / 2);
private _seen = [];
{ _seen pushBack ((_grid select _forEachIndex) apply { false }); } forEach _grid;
private _stack = [[_c, _c]];
private _land = [];
while {count _stack > 0} do {
    private _cell = _stack deleteAt 0;
    _cell params ["_x", "_y"];
    if (_x < 0 || _y < 0 || _x > _cols || _y > _cols) then { continue };
    if ((_seen select _y) select _x) then { continue };
    (_seen select _y) set [_x, true];
    if !((_grid select _y) select _x) then { continue };
    _land pushBack [_x, _y];
    { _stack pushBack _x; } forEach [[_x + 1, _y], [_x - 1, _y], [_x, _y + 1], [_x, _y - 1]];
};

private _world = { params ["_gx", "_gy"]; [(_fed select 0) - _half + (_gx * _step), (_fed select 1) - _half + (_gy * _step)] };
private _xs = _land apply { ([_x select 0, _x select 1] call _world) select 0 };
private _ys = _land apply { ([_x select 0, _x select 1] call _world) select 1 };
if (count _land isEqualTo 0) exitWith { diag_log "-ISLANDPROBE- the Fed cell reads as WATER -- check the coordinates"; };
private _minX = selectMin _xs; private _maxX = selectMax _xs;
private _minY = selectMin _ys; private _maxY = selectMax _ys;
private _cx = (_minX + _maxX) / 2; private _cy = (_minY + _maxY) / 2;
private _far = 0;
{ private _d = [_cx, _cy] distance2D ([_x select 0, _x select 1] call _world); if (_d > _far) then { _far = _d }; } forEach _land;
diag_log format ["-ISLANDPROBE- landmass under the Fed: %1 cells (%2 m grid), x %3..%4, y %5..%6",
    count _land, _step, _minX, _maxX, _minY, _maxY];
diag_log format ["-ISLANDPROBE- centre [%1, %2], furthest land point %3 m from it, extent %4 x %5 m",
    _cx toFixed 1, _cy toFixed 1, _far toFixed 0, (_maxX - _minX) toFixed 0, (_maxY - _minY) toFixed 0];
diag_log format ["-ISLANDPROBE- Fed marker sits %1 m from that centre", (_fed distance2D [_cx, _cy]) toFixed 1];

// is it separated from everything else? nearest land NOT part of this landmass
private _sep = 1e9; private _sepAt = [];
{
    private _row = _x; private _gy = _forEachIndex;
    {
        if (_x && {!([_forEachIndex, _gy] in _land)}) then {
            private _p = [_forEachIndex, _gy] call _world;
            private _d = [_cx, _cy] distance2D _p;
            if (_d < _sep) then { _sep = _d; _sepAt = _p; };
        };
    } forEach _row;
} forEach _grid;
if (_sep < 1e8) then {
    diag_log format ["-ISLANDPROBE- nearest OTHER land: %1 m away at %2 (gap from this landmass edge ~%3 m)",
        _sep toFixed 0, _sepAt, (_sep - _far) toFixed 0];
} else {
    diag_log "-ISLANDPROBE- no other land inside the sampled box";
};

// the designer's own air-defence furniture, relative to the Fed
{
    _x params ["_nm", "_pos"];
    diag_log format ["-ISLANDPROBE- %1 at %2 -> %3 m from the Fed, on this landmass: %4",
        _nm, _pos, (_fed distance2D _pos) toFixed 0, !surfaceIsWater _pos];
} forEach [["Defense Systems (marker_119)", [9643.8, 3319.9]], ["Air Defenses Online (marker_151)", [10483.7, 4820.0]],
           ["Response Police HQ", [10494.1, 4055.6]], ["Malden Prison", [9765.1, 3895.3]]];
diag_log "-ISLANDPROBE- DONE";
