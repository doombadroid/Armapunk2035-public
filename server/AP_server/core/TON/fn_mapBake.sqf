/*
    APS_fnc_mapBake  (Armapunk 2035) -- bake the 3D map's static assets into the log.

    The HTML map needs two things that never change at runtime: the island's
    heightfield and its buildings as simplified boxes. A page cannot read the
    world and SQF cannot write files, so the bake goes out through diag_log in
    tagged chunks and tools/harvest_map_bake.py turns the server log into
    ui/html/malden_hf.txt, malden_bld.txt and malden_fen.txt (the kind-5
    fence/wall rows, split out so the map does not parse 74% of the island
    before it can show the opening view), which ship in the mission and are
    read back with A3API.RequestFile.

    Run ONCE per terrain (or after the custom skyline changes), harvest, and
    remove the boot call -- ~5k log lines per run is nothing at a dev boot and
    unacceptable spam on every boot forever.

        [] spawn APS_fnc_mapBake;

    HEIGHTFIELD: 200x200 samples on a 64 m cell (12800/64), north row FIRST to
    match the page's parser, 50 values per log line.

    BUILDINGS: terrain structures via nearestTerrainObjects, the mission's own
    placed skyline via allMissionObjects, deduped by position. Footprint and
    height from boundingBoxReal -- the real model bounds, which is what makes
    the custom towers arrive tall with no special-casing. kind is classified
    off the model name; anything mission-placed is kind 4, the neon skyline.
*/

if (!isServer) exitWith {};

private _t0 = diag_tickTime;
diag_log "[MAPBAKE] start";

// ── heightfield ──────────────────────────────────────────────────────────────
#define HF_N    200
#define HF_CELL 64

private _minH = 1e9; private _maxH = -1e9;
private _rows = [];
for "_r" from 0 to (HF_N - 1) do {
    // row 0 = NORTH edge: worldY descends as the row index climbs
    private _y = 12800 - ((_r + 0.5) * HF_CELL);
    private _vals = [];
    for "_c" from 0 to (HF_N - 1) do {
        private _h = getTerrainHeightASL [(_c + 0.5) * HF_CELL, _y];
        _h = (round (_h * 10)) / 10;
        if (_h < _minH) then { _minH = _h };
        if (_h > _maxH) then { _maxH = _h };
        _vals pushBack _h;
    };
    _rows pushBack _vals;
};
diag_log format ["[HFDUMP] META %1 %2 %3 %4", HF_N, HF_CELL, _minH, _maxH];
{
    private _r = _forEachIndex;
    private _vals = _x;
    private _i = 0;
    while { _i < HF_N } do {
        // 50 values a line keeps every line far under any log truncation
        private _chunk = _vals select [_i, 50];
        diag_log format ["[HFDUMP] R%1C%2 %3", _r, _i, _chunk joinString ","];
        _i = _i + 50;
    };
} forEach _rows;
diag_log format ["[HFDUMP] END rows=%1 t=%2s", count _rows, (diag_tickTime - _t0) toFixed 1];

// ── buildings ────────────────────────────────────────────────────────────────
private _classify = {
    params ["_model", "_isMission", ["_path", ""]];
    // kind 4 is the NEON SKYLINE -- the mission's own models. Being spawned by
    // the mission is not enough: replace_sheds.sqf swaps hundreds of map sheds
    // for simple objects with STOCK a3\ models, and those are sheds, not
    // skyline. The model PATH is the tell: a3\ classifies by name like any
    // terrain building; anything else (mission-embedded p3d) is ours.
    if (_isMission && { !((toLower _path) select [0, 3] isEqualTo "a3\") }) exitWith { 4 };
    private _m = toLower _model;
    switch (true) do {
        case (["church"    , _m] call BIS_fnc_inString): { 3 };
        case (["chapel"    , _m] call BIS_fnc_inString): { 3 };
        case (["lighthouse", _m] call BIS_fnc_inString): { 3 };
        case (["barrack"   , _m] call BIS_fnc_inString): { 2 };
        case (["cargo_hq"  , _m] call BIS_fnc_inString): { 2 };
        case (["cargo_tower",_m] call BIS_fnc_inString): { 2 };
        case (["bunker"    , _m] call BIS_fnc_inString): { 2 };
        case (["mil_"      , _m] call BIS_fnc_inString): { 2 };
        case (["factory"   , _m] call BIS_fnc_inString): { 1 };
        case (["indus"     , _m] call BIS_fnc_inString): { 1 };
        case (["warehouse" , _m] call BIS_fnc_inString): { 1 };
        case (["silo"      , _m] call BIS_fnc_inString): { 1 };
        case (["tank_big"  , _m] call BIS_fnc_inString): { 1 };
        case (["shed_big"  , _m] call BIS_fnc_inString): { 1 };
        default { 0 };
    }
};

private _emit = {
    params ["_obj", "_isMission", ["_zbase", -999], ["_minSz", 2.5], ["_kOverride", -1], ["_minArea", 12]];
    // The mission REMOVES some map buildings (hideObjectGlobal); the sweep
    // returns them anyway, so the first bake drew ghosts of demolished
    // structures. Hidden means gone.
    if (isObjectHidden _obj) exitWith { false };
    // THE RAY SCAN. The 3DEN Hide-Terrain-Objects modules remove buildings by a
    // mechanism isObjectHidden does not report, so existence is verified by
    // geometry instead of by API: five rays straight down through the object's
    // own bounding box, and the OBJECT ITSELF must appear in its intersections.
    // A hidden building has no geometry to hit; a present one cannot dodge all
    // five (centre + four quarter points, rotated with the model, so hollow
    // courtyard centres do not false-drop). Mechanism-independent by design.
    private _mdlOK = true;
    if (!isNull _obj) then {
        private _pw = getPosWorld _obj;
        // DEGREES: SQF sin/cos take degrees, so the old `* (pi / 180)` made this
        // rotation a no-op (cos of ~0..6.3 DEGREES ~= 1) and the four quarter rays
        // stayed world-axis-aligned -- a rotated hollow building could miss all
        // five and be dropped as hidden.
        private _dirR = -(getDir _obj);
        private _bb2 = boundingBoxReal _obj;
        private _qx = (((_bb2 select 1) select 0) - ((_bb2 select 0) select 0)) * 0.3;
        private _qy = (((_bb2 select 1) select 1) - ((_bb2 select 0) select 1)) * 0.3;
        private _zTop = (_pw select 2) + ((_bb2 select 1) select 2) + 4;
        private _zBot = (_pw select 2) + ((_bb2 select 0) select 2) - 4;
        private _found = false;
        {
            _x params ["_ox", "_oy"];
            private _wx2 = (_pw select 0) + (_ox * cos _dirR) - (_oy * sin _dirR);
            private _wy2 = (_pw select 1) + (_ox * sin _dirR) + (_oy * cos _dirR);
            private _hits = lineIntersectsSurfaces [[_wx2, _wy2, _zTop], [_wx2, _wy2, _zBot], objNull, objNull, true, 8, "GEOM", "NONE"];
            if ((_hits findIf { (_x select 2) isEqualTo _obj || { (_x select 3) isEqualTo _obj } }) > -1) exitWith { _found = true };
        } forEach [[0, 0], [_qx, 0], [-_qx, 0], [0, _qy], [0, -_qy]];
        _mdlOK = _found;
    };
    if (!_mdlOK) exitWith { false };
    // the fed crossing is represented by a single hand-measured span in the
    // harvest; its 16 seabed-seated pieces must not come back
    if (["bridgestraight", toLower ((getModelInfo _obj) param [0, ""])] call BIS_fnc_inString
        || { ["bridgemiddle", toLower ((getModelInfo _obj) param [0, ""])] call BIS_fnc_inString }) exitWith { false };
    private _bb = boundingBoxReal _obj;
    _bb params ["_lo", "_hi"];
    private _sx = ((_hi select 0) - (_lo select 0)) max 0;
    private _sy = ((_hi select 1) - (_lo select 1)) max 0;
    private _sz = ((_hi select 2) - (_lo select 2)) max 0;
    // skip street furniture: a box the page draws must be worth a box
    if (_sx * _sy < _minArea || { _sz < _minSz }) exitWith { false };
    private _pos = getPosWorld _obj;
    private _mi = getModelInfo _obj;
    private _kind = if (_kOverride > -1) then { _kOverride } else {
        [_mi param [0, ""], _isMission, _mi param [1, ""]] call _classify
    };
    // 9th field: the model path -- the mesh library's key. Real objects always
    // have one; the harvester treats an empty tail as "no mesh, box fallback".
    diag_log format ["[BLDUMP] %1,%2,%3,%4,%5,%6,%7,%8,%9",
        (round ((_pos select 0) * 10)) / 10,
        (round ((_pos select 1) * 10)) / 10,
        round (getDir _obj),
        (round (_sx * 10)) / 10,
        (round (_sy * 10)) / 10,
        (round (_sz * 10)) / 10,
        _kind,
        if (_zbase < -900) then { -999 } else { (round (_zbase * 10)) / 10 },
        toLower (_mi param [1, ""])];
    true
};

private _seen = createHashMap;
private _n = 0;

// ── THE DESIGNER'S WORLD: APS_fnc_mapLoad's snapshot (localNamespace APS_mapEntities) ──
// The custom compounds (the fed dome, the castles, every designer structure)
// are CLIENT-LOCAL and ZONE-STREAMED -- the server never spawns them, a client
// only has the ones near the player, so no world sweep on any machine can see
// them all. The DATA can: fn_mapData is the literal placement table, complete
// with class, position and real altitude. Sizes come from a one-shot
// measurement pass -- each unique class spawned once high over the sea,
// boundingBoxReal read, deleted -- and every structure row is emitted with an
// ABSOLUTE base from its own entry.
//
// Structure footprints also become a KILL LIST for the terrain sweep below:
// where the designer built, the terrain building underneath was hidden by a
// mechanism no API reliably reports, so replacement wins and the ghost dies.
private _mdRows = [];   // [x, y, halfDiag] for the overlap purge
if (!isNil {localNamespace getVariable "APS_mapEntities"}) then {
    private _bbCache = createHashMap;
    {
        _x params ["_cls", "_pos", "_ori", "", ""];
        if (_cls isKindOf "CAManBase" || { !(_cls isKindOf "Static") && { !(_cls isKindOf "Building") } && { !(_cls isKindOf "Thing") } }) then { continue };
        private _bb = _bbCache getOrDefault [_cls, []];
        if (_bb isEqualTo []) then {
            private _tmp = createVehicle [_cls, [200, 200, 900], [], 0, "CAN_COLLIDE"];
            if (isNull _tmp) then { _bb = [0] }
            else {
                private _r = boundingBoxReal _tmp;
                _bb = [((_r select 1) select 0) - ((_r select 0) select 0),
                       ((_r select 1) select 1) - ((_r select 0) select 1),
                       ((_r select 1) select 2) - ((_r select 0) select 2),
                       (_r select 0) select 2,
                       toLower ((getModelInfo _tmp) param [1, ""])];   // mesh key
                deleteVehicle _tmp;
            };
            _bbCache set [_cls, _bb];
        };
        if (count _bb < 4) then { continue };
        _bb params ["_sx", "_sy", "_sz", "_loZ"];
        // walls/fences are long+thin+low, so the building gate would drop them
        // all; they pass a relaxed gate and land as kind 5 (fence tier)
        private _lcw = toLower _cls;
        private _isFence = (["wall", _lcw] call BIS_fnc_inString) || { ["fence", _lcw] call BIS_fnc_inString };
        if (_isFence) then {
            if (_sx * _sy < 1.5 || { _sz < 0.8 }) then { continue };
        } else {
            if (_sx * _sy < 12 || { _sz < 2.5 }) then { continue };
        };
        private _key = format ["%1_%2_d", round (_pos select 0), round (_pos select 1)];
        if (_key in _seen) then { continue };
        _seen set [_key, true];
        private _dir = ((_ori select 0) select 0) atan2 ((_ori select 0) select 1);
        if (_dir < 0) then { _dir = _dir + 360 };
        private _lc = toLower _cls;
        private _kind = switch (true) do {
            case (_isFence): { 5 };
            case (["dome", _lc] call BIS_fnc_inString): { 3 };
            case (["castle", _lc] call BIS_fnc_inString): { 3 };
            case (["cargo_hq", _lc] call BIS_fnc_inString);
            case (["mil_", _lc] call BIS_fnc_inString);
            case (["barrack", _lc] call BIS_fnc_inString): { 2 };
            case (["factory", _lc] call BIS_fnc_inString);
            case (["indus", _lc] call BIS_fnc_inString);
            case (["warehouse", _lc] call BIS_fnc_inString): { 1 };
            default { 0 };
        };
        private _zb = (_pos select 2) + _loZ;
        diag_log format ["[BLDUMP] %1,%2,%3,%4,%5,%6,%7,%8,%9",
            (round ((_pos select 0) * 10)) / 10, (round ((_pos select 1) * 10)) / 10,
            round _dir, (round (_sx * 10)) / 10, (round (_sy * 10)) / 10, (round (_sz * 10)) / 10,
            _kind, (round (_zb * 10)) / 10, _bb param [4, ""]];
        // ONLY BUILDINGS KILL GHOSTS. A designer fence is not a replacement for a
        // terrain building, so it must not create a suppression disc -- before the
        // fence gate existed, walls never reached this list at all, and adding them
        // silently deleted real buildings standing next to designer walls.
        if (!_isFence) then {
            _mdRows pushBack [_pos select 0, _pos select 1, (sqrt (_sx * _sx + _sy * _sy)) / 2 + 3];
        };
        _n = _n + 1;
    } forEach (localNamespace getVariable "APS_mapEntities");
    diag_log format ["[MAPBAKE] designer table: %1 structures, %2 classes measured", count _mdRows, count _bbCache];
};

// replacement wins: a terrain candidate standing inside a designer footprint is
// the hidden original showing through a mechanism the APIs do not report
private _fnGhost = {
    params ["_px", "_py"];
    ([_px, _py] distance2D [0, 0]) isEqualType 0 &&   // keeps the params honest
    { (_mdRows findIf { ([_px, _py] distance2D [_x select 0, _x select 1]) < (_x select 2) }) > -1 }
};

// the mission's own skyline first, so the dedupe keeps the kind-4 row
{
    private _key = format ["%1_%2", round ((getPosWorld _x) select 0), round ((getPosWorld _x) select 1)];
    if !(_key in _seen) then {
        _seen set [_key, true];
        if ([_x, true] call _emit) then { _n = _n + 1 };
    };
} forEach ((allMissionObjects "Building") + (allSimpleObjects []));
// allSimpleObjects catches the createSimpleObject skyline -- simple objects have
// no class, so allMissionObjects never returns them. The size filter in _emit is
// what keeps the neon signs and door panels from becoming boxes.

{
    private _pw2 = getPosWorld _x;
    private _key = format ["%1_%2", round (_pw2 select 0), round (_pw2 select 1)];
    if !(_key in _seen) then {
        _seen set [_key, true];
        if !([_pw2 select 0, _pw2 select 1] call _fnGhost) then {
            if ([_x, false] call _emit) then { _n = _n + 1 };
        };
    };
} forEach (nearestTerrainObjects [[6400, 6400], ["BUILDING", "HOUSE", "CHURCH", "CHAPEL", "FUELSTATION", "HOSPITAL", "BUNKER", "FORTRESS", "TOURISM", "LIGHTHOUSE"], 9100, false]);

// FENCES + WALLS (owner 2026-08-27): their own sweep, kind 5, relaxed gate --
// a fence is long, thin and low, so the building gate excludes all of them.
// The page draws kind 5 only in the close (mesh) tier; zoomed out they are noise.
{
    private _pw2 = getPosWorld _x;
    private _key = format ["%1_%2", round (_pw2 select 0), round (_pw2 select 1)];
    if !(_key in _seen) then {
        _seen set [_key, true];
        if !([_pw2 select 0, _pw2 select 1] call _fnGhost) then {
            if ([_x, false, -999, 0.8, 5, 1.5] call _emit) then { _n = _n + 1 };
        };
    };
} forEach (nearestTerrainObjects [[6400, 6400], ["WALL", "FENCE"], 9100, false]);

// BRIDGES. getTerrainHeightASL knows nothing about them -- the deck is an
// OBJECT above a bay the heightfield renders at seabed -- so they carry an
// ABSOLUTE base (world Z of the model's bounding floor) in the 8th column and
// the page seats them there instead of on the terrain. kind 1 keeps them in
// the page's existing palette. The size gate drops to 1m because a deck is
// thin by design.
{
    private _key = format ["%1_%2_b", round ((getPosWorld _x) select 0), round ((getPosWorld _x) select 1)];
    if !(_key in _seen) then {
        _seen set [_key, true];
        private _zb = ((getPosWorld _x) select 2) + ((boundingBoxReal _x select 0) select 2);
        if ([_x, false, _zb, 1, 1] call _emit) then { _n = _n + 1 };
    };
} forEach (nearestTerrainObjects [[6400, 6400], ["BRIDGE"], 9100, false]);

// The object sweep above catches bridge STRUCTURES if the terrain classes any
// ("BRIDGE" returned zero on Malden). The real answer is the road network:
// bridges here are ROAD PIECES, and getRoadInfo hands over an isBridge flag
// plus true world begin/end positions -- including Z, which is the entire
// point. One slab per bridge segment: centre, heading, width, length, thin
// deck, kind 1, ABSOLUTE base from the segment's own altitude.
{
    // width came back 0 on Malden's bridge pieces -- clamp to a sane deck
    (getRoadInfo _x) params ["", "_width", "", "", "", "", "_beg", "_end", ["_isBridge", false]];
    _width = _width max 6;
    // The isBridge flag caught six culverts and missed the actual bridge, so
    // the flag is advisory: any deck sitting well clear of the terrain under it
    // IS a bridge, whatever the road piece thinks it is. Embankments stay out
    // on their own -- an embankment raises the TERRAIN, so deck minus terrain
    // stays small and the heightfield already renders it.
    private _elev = false;
    if (_beg isNotEqualTo [] && { _end isNotEqualTo [] }) then {
        private _cx0 = ((_beg select 0) + (_end select 0)) / 2;
        private _cy0 = ((_beg select 1) + (_end select 1)) / 2;
        private _th = getTerrainHeightASL [_cx0, _cy0];
        private _dz = (((_beg select 2) min (_end select 2)) - _th);
        // a handful of pieces report [0,0,0] positions; origin is open sea, so
        // the elevation test passes and a ghost slab lands at the map corner
        _elev = ((_dz > 2.5) || { _th < -0.8 && _dz > 1 }) && { (_cx0 > 1) || (_cy0 > 1) };
    };
    if ((_isBridge || _elev) && { _beg isNotEqualTo [] } && { _end isNotEqualTo [] }) then {
        private _cx = ((_beg select 0) + (_end select 0)) / 2;
        private _cy = ((_beg select 1) + (_end select 1)) / 2;
        private _key = format ["%1_%2_r", round _cx, round _cy];
        if !(_key in _seen) then {
            _seen set [_key, true];
            private _len = _beg distance2D _end;
            private _dir = (_beg getDir _end);
            private _zb = ((_beg select 2) min (_end select 2));
            diag_log format ["[BLDUMP] %1,%2,%3,%4,%5,%6,%7,%8",
                (round (_cx * 10)) / 10, (round (_cy * 10)) / 10, round _dir,
                (round ((_width + 2) * 10)) / 10, (round ((_len + 1) * 10)) / 10, 1.4,
                1, (round (_zb * 10)) / 10];
            _n = _n + 1;
        };
    };
} forEach ([6400, 6400, 0] nearRoads 9100);

diag_log format ["[BLDUMP] END n=%1 t=%2s", _n, (diag_tickTime - _t0) toFixed 1];
diag_log "[MAPBAKE] done";
