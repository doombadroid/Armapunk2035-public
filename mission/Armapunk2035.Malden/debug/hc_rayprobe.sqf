/*
    debug\hc_rayprobe.sqf   --  HEADLESS CLIENT ONLY

    Measures a custom .p3d's collision by ray casting instead of by eye. lineIntersectsSurfaces can
    be aimed at a specific LOD ("GEOM" = the solid volume, "FIRE" = what bullets hit, "ROADWAY" =
    walkable surfaces, top-down only), so this answers "is that wall actually solid" and "is that
    doorway actually open" to the centimetre, which walking around cannot.

    Rays are specified in MODEL space and converted with modelToWorldVisual, so the object's dir and
    scale are handled by the engine and there is no transform to get wrong. NOTE the axis order:
    SQF model space is [x=right, y=FORWARD, z=UP] while the .p3d file is (x, y=up, z=depth), i.e.
    sqf [x, y, z] == p3d (x, z, y).

    Runs on any machine with no interface -- the dedicated server or a headless client.
    custom_p3ds\malden_buildings.sqf now passes local=true to createSimpleObject, so ONLY a
    machine that RUNS the spawner has the buildings. The server gets them from initServer.sqf; an HC
    runs neither initServer.sqf nor initPlayerLocal.sqf and so must build its own set first, which
    also makes it a faithful stand-in for a player's client.

    NB the fork's mission.sqm has no HeadlessClient_F slot (LooneyBin.Altis does), so an HC currently
    connects and then sits in the lobby without ever loading the mission -- hence the server path.

    Output goes to diag_log -> loonydev.log (server) or loonyhc_direct.log (HC). grep [RAYPROBE].
    DEV INSTRUMENTATION -- remove the initServer.sqf call before any live deploy.
*/
if (hasInterface) exitWith {};

private _tag   = "[RAYPROBE]";
private _model = "mentalasylum13_r24";

diag_log format ["%1 ==== start, target %2, isServer=%3 ====", _tag, _model, isServer];

if (!isServer) then {
    [] execVM "custom_p3ds\malden_buildings.sqf";
    uiSleep 10;
} else {
    uiSleep 12;      // let initServer.sqf finish spawning the customs
};

private _objs = (allSimpleObjects []) select { _model in toLower ((getModelInfo _x) select 0) };
diag_log format ["%1 simpleObjects total=%2  matching=%3", _tag, count (allSimpleObjects []), count _objs];
if (count _objs isEqualTo 0) exitWith { diag_log format ["%1 ABORT model not present on this machine", _tag]; };

private _o = _objs select 0;
diag_log format ["%1 posASL=%2 dir=%3 scale=%4", _tag, getPosASL _o, getDir _o, getObjectScale _o];
diag_log format ["%1 boundingBoxReal=%2", _tag, boundingBoxReal _o];

// model-space X sweep: for each forward offset, fire one ray straight through the building and
// record every GEOM crossing. The sequence of crossings per line IS the measured floor plan.
private _fn_scan = {
    params ["_o", "_tag", "_lod", "_h", "_yFrom", "_yTo", "_step"];
    private _lines = 0; private _solid = 0;
    for "_i" from 0 to (floor ((_yTo - _yFrom) / _step)) do {
        private _y = _yFrom + _i * _step;
        private _b = AGLToASL (_o modelToWorldVisual [-30, _y, _h]);
        private _e = AGLToASL (_o modelToWorldVisual [ 30, _y, _h]);
        private _hits = lineIntersectsSurfaces [_b, _e, objNull, objNull, true, -1, _lod, "NONE", false];
        private _xs = [];
        {
            if ((_x select 2) isEqualTo _o) then {
                _xs pushBack (round (100 * (((_o worldToModelVisual (ASLToAGL (_x select 0))) select 0))) / 100);
            };
        } forEach _hits;
        _lines = _lines + 1;
        if (count _xs >= 2) then { _solid = _solid + 1 };
        diag_log format ["%1 %2 h=%3 y=%4 n=%5 xs=%6", _tag, _lod, _h, _y, count _xs, _xs];
    };
    diag_log format ["%1 SUMMARY %2 h=%3 -- %4/%5 lines hit solid geometry", _tag, _lod, _h, _solid, _lines];
};

// DO NOT hardcode heights from the .p3d file's own coordinates. Arma AUTOCENTERS a model unless the
// p3d carries autocenter=0 (none of these do), so engine model space is recentred on the bounding
// box: this building reads z -8.33..+8.33 in-engine while the file's Y runs -0.64..16.03 -- a ~7.7m
// offset that silently puts every probe in the wrong place. Derive everything from the engine
// instead: cast ROADWAY down to find where the floors actually are, then scan walls above each.
private _bb = boundingBoxReal _o;
(_bb select 0) params ["_bx0","_by0","_bz0"];
(_bb select 1) params ["_bx1","_by1","_bz1"];

private _levels = [];
private _road = 0; private _tot = 0;
private _xs0 = round (_bx0 + 1); private _xs1 = round (_bx1 - 1);
private _ys0 = round (_by0 + 1); private _ys1 = round (_by1 - 1);
for "_ix" from _xs0 to _xs1 step 2 do {
    for "_iy" from _ys0 to _ys1 step 2 do {
        private _b = AGLToASL (_o modelToWorldVisual [_ix, _iy, _bz1 + 20]);
        private _e = AGLToASL (_o modelToWorldVisual [_ix, _iy, _bz0 - 2]);
        private _mine = (lineIntersectsSurfaces [_b, _e, objNull, objNull, true, -1, "ROADWAY", "NONE", false])
                        select { (_x select 2) isEqualTo _o };
        _tot = _tot + 1;
        if (count _mine > 0) then {
            _road = _road + 1;
            { _levels pushBack (round (2 * ((_o worldToModelVisual (ASLToAGL (_x select 0))) select 2)) / 2) } forEach _mine;
        };
    };
};
diag_log format ["%1 SUMMARY ROADWAY -- %2/%3 sample points walkable", _tag, _road, _tot];

// cluster the roadway hits into storeys, keep the ones with real coverage
private _floors = []; private _counts = [];
{
    private _i = _floors find _x;
    if (_i < 0) then { _floors pushBack _x; _counts pushBack 1 } else { _counts set [_i, (_counts select _i) + 1] };
} forEach _levels;
private _storeys = [];
{ if ((_counts select _forEachIndex) >= 6) then { _storeys pushBack _x } } forEach _floors;
_storeys sort true;
diag_log format ["%1 STOREYS (engine model z) = %2", _tag, _storeys];

{
    private _h = _x + 1.2;                                   // head height above that floor
    if (_h < _bz1) then {
        [_o, _tag, "GEOM", _h, _by0 + 0.5, _by1 - 0.5, 0.5] call _fn_scan;
    };
} forEach _storeys;

// ---- Z-SWEEP. The X-sweep above fires rays along model X, which run PARALLEL to any wall whose
// normal is Z and therefore can never cross one: every "wall is solid" result so far only ever
// proved X-facing walls collide. Sweep along model Y (= the model's depth axis) to test the
// Z-facing walls independently -- that is the family the SW wall belongs to.
private _fn_scanZ = {
    params ["_o", "_tag", "_h", "_xFrom", "_xTo", "_step"];
    private _lines = 0; private _solid = 0;
    for "_i" from 0 to (floor ((_xTo - _xFrom) / _step)) do {
        private _x2 = _xFrom + _i * _step;
        private _b = AGLToASL (_o modelToWorldVisual [_x2, -30, _h]);
        private _e = AGLToASL (_o modelToWorldVisual [_x2,  30, _h]);
        private _ys = [];
        {
            if ((_x select 2) isEqualTo _o) then {
                _ys pushBack (round (100 * (((_o worldToModelVisual (ASLToAGL (_x select 0))) select 1))) / 100);
            };
        } forEach (lineIntersectsSurfaces [_b, _e, objNull, objNull, true, -1, "GEOM", "NONE", false]);
        _lines = _lines + 1;
        if (count _ys >= 2) then { _solid = _solid + 1 };
        diag_log format ["%1 GEOMZ h=%2 x=%3 n=%4 ys=%5", _tag, _h, _x2, count _ys, _ys];
    };
    diag_log format ["%1 SUMMARY GEOMZ h=%2 -- %3/%4 lines hit solid geometry", _tag, _h, _solid, _lines];
};
{
    private _h = _x + 1.2;
    if (_h < _bz1) then { [_o, _tag, _h, _bx0 + 0.5, _bx1 - 0.5, 1.0] call _fn_scanZ };
} forEach _storeys;

// bullets: with no Fire Geometry LOD the engine falls back to Geometry, so this should mirror GEOM
if (count _storeys > 0) then {
    [_o, _tag, "FIRE", (_storeys select 0) + 1.2, _by0 + 0.5, _by1 - 0.5, 2.0] call _fn_scan;
};
// ---- ENGINE-TRUTH COVERAGE MAP. Cast straight DOWN over a grid of the model footprint. A downward
// ray starts above everything, so it can never begin inside a component and the reading is
// unambiguous. Comparing this against the offline box map shows exactly which components the engine
// is actually willing to use -- the file having geometry has already been proven not to be enough.
private _seen = 0; private _miss = 0; private _missList = [];
for "_gx" from (round (_bx0+1)) to (round (_bx1-1)) step 2 do {
    private _row = "";
    for "_gz" from (round (_by0+1)) to (round (_by1-1)) step 2 do {
        private _b = AGLToASL (_o modelToWorldVisual [_gx, _gz, _bz1 + 25]);
        private _e = AGLToASL (_o modelToWorldVisual [_gx, _gz, _bz0 - 3]);
        private _hit = (lineIntersectsSurfaces [_b, _e, objNull, objNull, true, -1, "GEOM", "NONE", false])
                       select { (_x select 2) isEqualTo _o };
        if (count _hit > 0) then { _seen = _seen + 1; _row = _row + "#" }
        else { _miss = _miss + 1; _row = _row + "."; _missList pushBack [_gx,_gz] };
    };
    diag_log format ["%1 GEOMMAP x=%2 |%3|", _tag, _gx, _row];
};
diag_log format ["%1 SUMMARY GEOMMAP -- engine sees geometry at %2/%3 grid cells", _tag, _seen, _seen+_miss];

// ---- TERRAIN vs BUILDING. A single solid convex box still let the player through in exactly the
// same places, so the failure is positional, not geometric. The asylum is the only custom building
// embedded in a hillside: Arma resolves movement against terrain first, and object geometry BELOW
// the terrain surface does not block a player walking on that terrain. Rays ignore terrain, which is
// why every ray measurement reported the walls solid. Sample how deeply each part is buried.
private _base = (getPosASL _o select 2) + _bz0;      // model base in ASL
diag_log format ["%1 TERRAIN model base ASL=%2 top ASL=%3", _tag, _base, (getPosASL _o select 2) + _bz1];
for "_gx" from (round (_bx0+1)) to (round (_bx1-1)) step 3 do {
    private _row = "";
    for "_gz" from (round (_by0+1)) to (round (_by1-1)) step 3 do {
        private _w = _o modelToWorldVisual [_gx, _gz, 0];
        private _t = getTerrainHeightASL [_w select 0, _w select 1];
        private _bury = _t - _base;                   // metres of building below terrain here
        _row = _row + format ["%1 ", round _bury];
    };
    diag_log format ["%1 TERRAINMAP x=%2 buried(m): %3", _tag, _gx, _row];
};

// ---- point inspection: exact world spots reported in game as phasing through or blocking.
// Cast INWARD from 3 m outside toward the point, never outward from the point. A ray started inside
// a closed convex component exits through back-faces, which lineIntersectsSurfaces does not report,
// so an outward cast returns "none" for solid geometry AND for empty space -- the two cases are
// indistinguishable and the reading is worthless. Casting inward, the reported number is the gap
// between the point and the first solid surface on that side: ~0 means solid right here, "none"
// means genuinely nothing solid within 3 m on that side.
{
    _x params ["_label", "_wp"];
    private _p   = ATLToASL _wp;
    private _mdl = _o worldToModelVisual (ASLToAGL _p);
    private _res = [];
    {
        _x params ["_dn", "_dv"];
        private _from = _p vectorAdd (_dv vectorMultiply 3.0);
        private _hit = (lineIntersectsSurfaces [_from, _p, objNull, objNull, true, 1, "GEOM", "NONE", false])
                       select { (_x select 2) isEqualTo _o };
        if (count _hit > 0) then {
            _res pushBack format ["%1=%2m", _dn, round (100 * (_p distance (_hit select 0 select 0)))/100];
        } else { _res pushBack format ["%1=none", _dn] };
    } forEach [["E",[1,0,0]],["W",[-1,0,0]],["N",[0,1,0]],["S",[0,-1,0]],["Up",[0,0,1]],["Dn",[0,0,-1]]];
    diag_log format ["%1 POINT %2 world=%3 model=[%4,%5,%6] nearest-GEOM within 1m: %7",
        _tag, _label, _wp,
        round (100*(_mdl select 0))/100, round (100*(_mdl select 1))/100, round (100*(_mdl select 2))/100,
        _res joinString " "];
} forEach [
    ["SW-wall-phasethrough", [4255.95, 3887.38, 0]],
    ["entry-stairs-blocked", [4246.06, 3912.78, 0.67]],
    ["inner-stairs-blocked", [4261.29, 3902.74, 5.08]],
    ["rail-A",       [4253.09, 3902.00, 6.54]],
    ["rail-B",       [4259.64, 3911.22, 6.65]],
    ["SW-corner1",   [4257.51, 3890.44, 6.37]],
    ["SW-mid",       [4253.95, 3884.94, 6.31]],
    ["SW-far",       [4243.44, 3890.85, 6.43]],
    ["inner-stairs-2", [4260.64, 3901.87, 4.46]]
];

diag_log format ["%1 ==== done ====", _tag];
