/*
    debug\stairprobe.sqf -- SERVER ONLY. DEV INSTRUMENTATION -- remove the initServer.sqf
    call before any live deploy (same rule as walltest.sqf / hc_rayprobe.sqf).

    Skyscraper20 stairwell traversal truth: drives one AI walking capsule up the full
    switchback core (lobby -> roof deck through the hut door) and back down, waypoint by
    waypoint, with velocity pushes -- the same collision consumer as a player. Rays are NOT
    trusted here (walltest lesson). On a failed segment the unit is teleported to the
    segment target and the sweep continues, so one run reports every bad segment.

    grep [STAIRPROBE] in loonydev.log.

    Model-frame mapping (generated alongside Skyscraper20_r6 -- regen if the bbox changes):
    p3d (x, y_up, z_depth), bbox y 0..77.19, z -12.03..14.80 (autocentered)
      arma model = [p3d_x, p3d_z - 1.385, p3d_y - 38.595]
*/
if (!isServer) exitWith {};
private _tag = "[STAIRPROBE]";

uiSleep 20;    // buildings settle

private _objs = (allSimpleObjects []) select { "skyscraper20_r12" in toLower ((getModelInfo _x) select 0) };
if (count _objs isEqualTo 0) exitWith { diag_log format ["%1 ABORT model not present", _tag]; };
private _o = _objs select 0;
diag_log format ["%1 ==== start pos=%2 dir=%3 bb=%4 ====", _tag, getPosASL _o, getDir _o, boundingBoxReal _o];

// DOOR SYSTEM ACCEPTANCE (no-addon route): flip two doors via the shared state
// array and verify this machine's local leaves actually swung (dir changed).
waitUntil { !isNil "AP_SKYDOOR_LEAVES" && { count AP_SKYDOOR_LEAVES > 0 } };
diag_log format ["%1 leaves spawned: %2", _tag, count AP_SKYDOOR_LEAVES];
private _probeDoor = {
    params ["_i"];
    (AP_SKYDOOR_LEAVES select _i) params ["_leaf"];
    private _d0 = getDir _leaf;
    AP_SKYDOOR_STATE set [_i, 1]; publicVariable "AP_SKYDOOR_STATE";
    uiSleep 2;
    private _d1 = getDir _leaf;
    diag_log format ["%1 DOORTEST idx=%2 dir %3 -> %4 (swing %5)", _tag, _i,
        _d0 toFixed 1, _d1 toFixed 1, ((_d1 - _d0 + 540) mod 360 - 180) toFixed 1];
};
[0] call _probeDoor;          // first apartment door
[95] call _probeDoor;         // roof hut door — stays open for the exit path

// p3d (x, z_depth, y_up) -> arma model frame
private _mp = { params ["_px", "_pz", "_py"]; [_px, _pz - 1.385, _py - 38.595] };

// floor levels (top of slab)
private _lvl = [0.3];
for "_i" from 2 to 20 do { _lvl pushBack (5.3 + 3.4 * (_i - 2)); };
_lvl pushBack 69.9;    // roof deck

// build the UP waypoint chain: per flight 6 stations, then hut exit + helipad
private _chain = [];   // [label, p3d x, p3d z, p3d y]
for "_f" from 0 to 19 do {
    private _h = _lvl select _f;
    private _rise = (_lvl select (_f + 1)) - _h;
    private _half = _rise / 2;
    private _fl = format ["F%1", _f + 1];
    _chain pushBack [format ["%1 laneA base", _fl], -3.75,  1.60, _h];
    _chain pushBack [format ["%1 laneA top",  _fl], -3.75, -1.15, _h + _half];
    _chain pushBack [format ["%1 midLanding", _fl], -2.25, -1.85, _h + _half];
    _chain pushBack [format ["%1 laneB base", _fl], -0.75, -1.15, _h + _half];
    _chain pushBack [format ["%1 laneB top",  _fl], -0.75,  1.25, _h + _rise];
    _chain pushBack [format ["%1 N landing",  _fl], -2.25,  1.85, _h + _rise];
};
_chain pushBack ["ROOF hut door", 1.40, 1.90, 69.9];
_chain pushBack ["ROOF helipad",  6.00, 0.00, 69.9];

// DOWN = reverse of the chain, ending at the lobby lane A base
private _down = [];
for "_i" from (count _chain - 1) to 0 step -1 do { _down pushBack (_chain select _i); };

private _grp = createGroup [east, true];
private _spawnAt = AGLToASL (_o modelToWorldVisual ([-3.75, 1.60, 0.3] call _mp));
private _u = _grp createUnit ["O_Soldier_F", ASLToAGL _spawnAt, [], 0, "CAN_COLLIDE"];
_u allowDamage false;
_u disableAI "ALL";
_u setPosASL _spawnAt;
uiSleep 2;

private _walked = 0; private _failed = [];
private _runLeg = {
    params ["_legName", "_stations"];
    {
        _x params ["_label", "_px", "_pz", "_py"];
        private _tgt = AGLToASL (_o modelToWorldVisual ([_px, _pz, _py] call _mp));
        private _t0 = diag_tickTime;
        private _ok = false; private _stall = false;
        private _lastP = getPosASL _u; private _lastT = _t0;
        while { !_ok && !_stall && diag_tickTime - _t0 < 18 } do {
            private _p = getPosASL _u;
            private _dx = (_tgt select 0) - (_p select 0);
            private _dy = (_tgt select 1) - (_p select 1);
            private _dist = sqrt (_dx * _dx + _dy * _dy);
            if (_dist < 0.5 && abs ((_tgt select 2) - (_p select 2)) < 0.9) then { _ok = true; } else {
                // ANIMATION-driven walk: raw setVelocity bypasses the engine's
                // step-up logic entirely (b0297 lesson) — a velocity-pushed
                // capsule cannot climb 0.17 m risers a walking player steps
                // over. Root motion of the walk move goes through the real
                // movement controller, the same collision consumer as input.
                _u setDir ((_dx atan2 _dy) mod 360);
                if (animationState _u != "amovpercmrunsraswrfldf") then {
                    _u playMoveNow "AmovPercMrunSrasWrflDf";
                };
                if (diag_tickTime - _lastT > 3.5) then {
                    if (_p distance _lastP < 0.25) then { _stall = true; };
                    _lastP = _p; _lastT = diag_tickTime;
                };
                uiSleep 0.1;
            };
        };
        if (_ok) then {
            _walked = _walked + 1;
        } else {
            private _m = _o worldToModelVisual (ASLToAGL (getPosASL _u));
            _failed pushBack format ["%1/%2", _legName, _label];
            diag_log format ["%1 FAIL %2 %3 -- capsule stuck at model=%4 (want [%5,%6,%7]) -- teleporting on",
                _tag, _legName, _label, _m, _px, _pz - 1.385, _py - 38.595];
            _u setPosASL _tgt;
            uiSleep 0.5;
        };
    } forEach _stations;
    diag_log format ["%1 leg %2 done: walked=%3 failed=%4", _tag, _legName, _walked, count _failed];
};

["UP", _chain] call _runLeg;
["DOWN", _down] call _runLeg;

diag_log format ["%1 ==== RESULT segments=%2 walked=%3 failed=%4 %5 ====",
    _tag, 2 * count _chain, _walked, count _failed, _failed];
deleteVehicle _u;
deleteGroup _grp;
