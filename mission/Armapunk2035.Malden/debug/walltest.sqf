/*
    debug\walltest.sqf  --  SERVER ONLY. DEV INSTRUMENTATION -- remove the initServer.sqf call
    before any live deploy (same rule as hc_rayprobe.sqf).

    Character-collision truth for the asylum: rays (lineIntersectsSurfaces) hit geometry the walking
    capsule can ignore (measured 2026-08-01: on the baked-x3 model, boxes beyond ~+17m model-space x
    were character-dead while rays reported them solid). Spawns one AI unit per test, stands it on a
    floor inside the building, drives it into each facade, and logs whether it ended up past the
    facade plane. grep [WALLTEST] in loonydev.log.

    All positions are FRACTIONS of boundingBoxReal, so the same test works whatever the model scale
    or the engine's model-frame semantics for scaled simple objects.
*/
if (!isServer) exitWith {};
private _tag = "[WALLTEST]";

uiSleep 18;      // buildings + rayprobe settle

private _objs = (allSimpleObjects []) select { "mentalasylum13_r24" in toLower ((getModelInfo _x) select 0) };
if (count _objs isEqualTo 0) exitWith { diag_log format ["%1 ABORT model not present", _tag]; };
private _o = _objs select 0;
private _bb = boundingBoxReal _o;
(_bb select 0) params ["_bx0","_by0","_bz0"];
(_bb select 1) params ["_bx1","_by1","_bz1"];
diag_log format ["%1 ==== start  pos=%2 dir=%3 scale=%4 bb=%5 ====", _tag, getPosASL _o, getDir _o, getObjectScale _o, _bb];

private _zspan = _bz1 - _bz0;
private _zGnd = _bz0 + 0.17 * _zspan;
private _zUp  = _bz0 + 0.49 * _zspan;

// [label, start(fractions of bx1/by1 + absolute z), push(model dir), facadeAxis(0=x,1=y), sign]
private _tests = [
    ["+X end  ground", [ 0.79, 0.0], _zGnd, [ 3, 0], 0,  1],
    ["-X end  ground", [-0.79, 0.0], _zGnd, [-3, 0], 0, -1],
    ["+Y frnt ground", [ 0.0,  0.63], _zGnd, [ 0, 3], 1,  1],
    ["-Y back ground", [ 0.0, -0.55], _zGnd, [ 0,-3], 1, -1],
    ["+X end  upper",  [ 0.79, 0.0], _zUp,  [ 3, 0], 0,  1],
    ["-X end  upper",  [-0.79, 0.0], _zUp,  [-3, 0], 0, -1],
    ["+Y frnt upper",  [ 0.0,  0.63], _zUp,  [ 0, 3], 1,  1],
    ["-Y back upper",  [ 0.0, -0.55], _zUp,  [ 0,-3], 1, -1],
    // the character-extent discriminators: far +/-X stretches of the front wall
    ["+Y far+X ground", [ 0.79, 0.63], _zGnd, [ 0, 3], 1,  1],
    ["+Y far-X ground", [-0.79, 0.63], _zGnd, [ 0, 3], 1,  1],
    ["+Y far+X upper",  [ 0.79, 0.63], _zUp,  [ 0, 3], 1,  1]
];

private _grp = createGroup [east, true];
{
    _x params ["_label", "_fr", "_z", "_push", "_ax", "_sgn"];
    private _start = [(_fr select 0) * _bx1, (_fr select 1) * _by1, _z];
    private _wStart = AGLToASL (_o modelToWorldVisual _start);
    private _u = _grp createUnit ["O_Soldier_F", ASLToAGL _wStart, [], 0, "CAN_COLLIDE"];
    _u allowDamage false;
    _u disableAI "ALL";
    _u setPosASL _wStart;
    uiSleep 1.5;                                   // settle onto the floor
    private _m0 = _o worldToModelVisual (ASLToAGL (getPosASL _u));
    private _t0 = diag_tickTime;
    while {diag_tickTime - _t0 < 6} do {
        _u setVelocity [
            (_push select 0) * cos (getDir _o) + (_push select 1) * sin (getDir _o),
            (_push select 1) * cos (getDir _o) - (_push select 0) * sin (getDir _o),
            -0.5
        ];
        uiSleep 0.05;
    };
    private _m1 = _o worldToModelVisual (ASLToAGL (getPosASL _u));
    private _lim = [_bx1, _by1] select _ax;
    private _c1 = _m1 select _ax;
    private _crossed = if (_sgn > 0) then { _c1 > _lim + 0.05 * _lim } else { _c1 < -_lim - 0.05 * _lim };
    diag_log format ["%1 %2  start(model)=%3  end(model)=%4  axis%5 -> %6 (limit %7)  CROSSED=%8",
        _tag, _label, _m0 apply {round (_x*100)/100}, _m1 apply {round (_x*100)/100},
        _ax, round (_c1*100)/100, round (_lim*100)/100, _crossed];
    deleteVehicle _u;
    uiSleep 0.5;
} forEach _tests;
deleteGroup _grp;
diag_log format ["%1 ==== done ====", _tag];

// ==== PART 12: r21 -- pavilion wall sealed, B walkway + stair corridor carved ===================
private _tag2 = "[WALLTEST12]";
private _shove2 = {
    params ["_tag", "_o", "_label", "_startModel", "_pushModel", "_ax"];
    private _wStart = AGLToASL (_o modelToWorldVisual _startModel);
    private _grp = createGroup [east, true];
    private _u = _grp createUnit ["O_Soldier_F", [0, 0, 0], [], 0, "NONE"];
    _u allowDamage false; _u disableAI "ALL";
    _u setPosASL _wStart;
    uiSleep 1.0;
    private _m0 = _o worldToModelVisual (ASLToAGL (getPosASL _u));
    private _t0 = diag_tickTime;
    while {diag_tickTime - _t0 < 5} do {
        _u setVelocity [
            (_pushModel select 0) * cos (getDir _o) + (_pushModel select 1) * sin (getDir _o),
            (_pushModel select 1) * cos (getDir _o) - (_pushModel select 0) * sin (getDir _o),
            -0.5
        ];
        uiSleep 0.05;
    };
    private _m1 = _o worldToModelVisual (ASLToAGL (getPosASL _u));
    diag_log format ["%1 %2  %3 -> %4", _tag, _label,
        _m0 apply {round (_x*100)/100}, _m1 apply {round (_x*100)/100}];
    deleteVehicle _u; deleteGroup _grp;
    uiSleep 0.4;
};
private _objs2 = (allSimpleObjects []) select { "mentalasylum13_r24" in toLower ((getModelInfo _x) select 0) };
if (count _objs2 > 0) then {
    private _oo = _objs2 select 0;
    private _bb2 = boundingBoxReal _oo;
    private _zG = ((_bb2 select 0) select 2) + 0.17 * (((_bb2 select 1) select 2) - ((_bb2 select 0) select 2));
    private _zU = ((_bb2 select 0) select 2) + 0.49 * (((_bb2 select 1) select 2) - ((_bb2 select 0) select 2));
    // owner point A: pavilion wall at model x 6.59 -- inside->out must BLOCK now
    [_tag2, _oo, "A pavilion x=6.59 out (expect BLOCK)",  [6.59, 3.0, _zG], [0, 3], 1] call _shove2;
    [_tag2, _oo, "A pavilion x=6.59 in (expect BLOCK)",   [6.59, 4.6, _zG], [0, -3], 1] call _shove2;
    // owner point B: walkway at [0.89,-1.97] -- walk through must PASS now
    [_tag2, _oo, "B walkway (expect travel to ~-1.4)", [0.89, -2.2, _zG], [0, 3], 1] call _shove2;
    // regressions
    [_tag2, _oo, "front x=5.3 gnd (expect BLOCK)",        [5.3, 2.7, _zG], [0, 3], 1] call _shove2;
    [_tag2, _oo, "front x=5.3 up (expect BLOCK)",         [5.3, 2.7, _zU], [0, 3], 1] call _shove2;
    [_tag2, _oo, "+Xend z+3 (expect BLOCK)",              [5.59, 3.0, _zG], [3, 0], 0] call _shove2;
    [_tag2, _oo, "STAIRBAY +X z=-2 (expect PASS)",        [5.2, -2.0, _zG], [3, 0], 0] call _shove2;
    [_tag2, _oo, "STAIRBAY -X z=-2 (expect PASS)",        [-5.2, -2.0, _zG], [-3, 0], 0] call _shove2;
    [_tag2, _oo, "ctl front x=0 (expect BLOCK)",          [0.0, 2.7, _zG], [0, 3], 1] call _shove2;
    // restored stair wall (owner 2026-08-01 [4261.09,3901.23]): comp 15/16 back in -- must BLOCK
    [_tag2, _oo, "stairwall z=2.97 out (expect BLOCK)",   [0.5, 2.45, _zG], [0, 3], 1] call _shove2;
    [_tag2, _oo, "stairwall z=2.97 in (expect BLOCK)",    [0.5, 3.5, _zG], [0, -3], 1] call _shove2;
};
diag_log format ["%1 ==== done ====", _tag2];
