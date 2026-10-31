/*
    AP_fnc_flyLandSpot  (Armapunk 2035, 2026-09-07) -- the clear landing spot NEAREST a target,
    where the aircraft can take off again.

        [_target, _veh, _rMax] call AP_fnc_flyLandSpot     -> [x, y]  or  [] (nothing within _rMax)

    One picker for every rotorcraft host: the engine-AI flight on the HC drops its helipad here
    (AP_fnc_hcFlyAI), the scripted core descends onto it (AP_fnc_flyStep: the seated autopilot, the
    VTOL hand-over, the emergency "land where it is"). Before this the AI path landed on a pad at the
    summoner's own feet with no test at all -- three Orcas set down in the La Trinite plaza among the
    vending rows and the HQ fronts (2026-09-07) -- and the core's own spiral cleared only 70% of half a
    hull (under the rotor radius), saw no vehicle, person or canopy, and stopped at 60 m.

    Candidates spiral out from the target (rings 8 m apart to _rMax, ~12 m along each ring, starting
    on the aircraft's side), tested NEAREST FIRST; the first that passes every gate wins:
      1. isFlatEmpty, proximity OFF: gradient <= 0.3 over max(rotor radius, 8 m), land only. Its
         proximity test is by bounding SPHERE and counts paving: the HQ plaza (45 kerbs, cobblestone
         squares, sidewalks and tree grates within 20 m) read as solid and 378 candidates died in 2 ms
         (HC log 18:55, first live run) -- so obstacles are judged by their own height, below.
      2. a VTOL never on a road (a Blackfish across a road segment was destroyed on contact, b0854);
         a helicopter may land on one.
      3. no object with its centre within ROTOR RADIUS + 2 m that stands taller than 0.6 m
         (nearestObjects, 2D): lamp posts, bollards, hedges, planters, walls, trees, buildings, the
         summoner, a parked car. Kerbs, paving, grates and drainage decks are ground. The aircraft,
         its crew and helipads (ours, the fabricator anchors) are ignored.
      4. nothing alive or parked within the same clearance (nearEntities -- cheap, explicit).
      5. downward rays over the disc -- the centre, four points at half the radius and twelve at
         radius + 2 m, from 60 m up to the ground ("GEOM" + "VIEW"): the FIRST (highest) surface must
         be ground or paving (<= 0.6 m over the terrain). A wall edge inside the disc, a canopy, an
         awning, a bridge or a wire above it is a hit. This is what "take off again" means.
    Rotor radius = the larger horizontal half-extent of boundingBoxReal (blades included), 3..14 m.
    Cost: the cheap gates go first; a target deep in a town can test ~400 candidates in one frame,
    once per flight and again when the summoner walks > 25 m; open ground exits on the first ring.
    One [FLYSPOT] line per pick with a per-gate rejection count -- read it before loosening a gate.
*/
params [["_target", [], [[]]], ["_veh", objNull, [objNull]], ["_rMax", 150, [0]]];
if (count _target < 2) exitWith { [] };
private _tx = _target select 0; private _ty = _target select 1;
private _bb = if (isNull _veh) then { [[-4, -4, -1], [4, 4, 1]] } else { boundingBoxReal _veh };
private _half = ((((_bb select 1) select 0) max ((_bb select 1) select 1)) max 3) min 14;
private _clear = _half + 2;
private _gradR = _half max 8;
private _isVtol = !isNull _veh && {_veh isKindOf "Plane"};
private _crew = if (isNull _veh) then { [] } else { crew _veh };
private _drv = if (isNull _veh) then { objNull } else { driver _veh };
private _a0 = if (isNull _veh) then { 0 } else { (((getPosASL _veh) select 0) - _tx) atan2 (((getPosASL _veh) select 1) - _ty) };
private _ws = worldSize;
// ray pattern over the disc, relative to the candidate
private _ring = [[0, 0], [_half * 0.5, 0], [-_half * 0.5, 0], [0, _half * 0.5], [0, -_half * 0.5]];
for "_k" from 0 to 330 step 30 do { _ring pushBack [_clear * sin _k, _clear * cos _k]; };
private _out = [];
private _tested = 0;
private _rej = [0, 0, 0, 0, 0];   // slope/water, road, object, entity, rays
private _t0 = diag_tickTime;
private _r = 0;
while { _r <= _rMax && {_out isEqualTo []} } do {
    private _n = if (_r < 1) then { 1 } else { ((ceil (2 * pi * _r / 12)) max 4) min 24 };
    for "_i" from 0 to (_n - 1) do {
        if (_out isNotEqualTo []) exitWith {};   // first hit on the ring wins; exitWith leaves the for loop
        private _a = _a0 + _i * (360 / _n);
        private _px = _tx + _r * sin _a; private _py = _ty + _r * cos _a;
        if (_px < 50 || {_py < 50} || {_px > _ws - 50} || {_py > _ws - 50}) then { continue };
        _tested = _tested + 1;
        private _p = [_px, _py, 0];
        if ((_p isFlatEmpty [-1, -1, 0.3, _gradR, 0, false, _veh]) isEqualTo []) then { _rej set [0, (_rej select 0) + 1]; continue };
        if (_isVtol && {isOnRoad _p}) then { _rej set [1, (_rej select 1) + 1]; continue };
        private _tall = (nearestObjects [_p, [], _clear, true]) findIf {
            _x isNotEqualTo _veh && {!(_x in _crew)} && {!(_x isKindOf "Land_HelipadEmpty_F")}
            && { private _b = boundingBoxReal _x; (((_b select 1) select 2) - ((_b select 0) select 2)) > 0.6 }
        };
        if (_tall >= 0) then { _rej set [2, (_rej select 2) + 1]; continue };
        private _ent = (_p nearEntities [["Car", "Tank", "Air", "Ship", "CAManBase"], _clear]) findIf { _x isNotEqualTo _veh && {!(_x in _crew)} };
        if (_ent >= 0) then { _rej set [3, (_rej select 3) + 1]; continue };
        private _blocked = false;
        {
            private _ox = _px + (_x select 0); private _oy = _py + (_x select 1);
            private _ter = getTerrainHeightASL [_ox, _oy, 0];
            private _h = lineIntersectsSurfaces [[_ox, _oy, _ter + 60], [_ox, _oy, _ter - 1], _veh, _drv, true, 1, "GEOM", "VIEW"];
            if (_h isNotEqualTo [] && {((((_h select 0) select 0) select 2) - _ter) > 0.6}) exitWith { _blocked = true; };
        } forEach _ring;
        if (_blocked) then { _rej set [4, (_rej select 4) + 1]; continue };
        _out = [_px, _py];
    };
    _r = _r + 8;
};
diag_log format ["[FLYSPOT] target=%1 spot=%2 dist=%3 half=%4 clear=%5 tested=%6 rej[slope,road,object,entity,rays]=%7 ms=%8 veh=%9 mapLive=%10", [round _tx, round _ty],
    (if (_out isEqualTo []) then { "NONE" } else { _out apply { round _x } }), (if (_out isEqualTo []) then { -1 } else { round (_out distance2D [_tx, _ty]) }),
    round (_half * 10) / 10, round (_clear * 10) / 10, _tested, _rej, round ((diag_tickTime - _t0) * 1000), typeOf _veh,
    (if (isNil {localNamespace getVariable "AP_mapLive"}) then { -1 } else { count (localNamespace getVariable "AP_mapLive") })];
_out
