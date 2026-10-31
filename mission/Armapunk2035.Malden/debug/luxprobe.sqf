/*
    debug\luxprobe.sqf -- SERVER ONLY, dev instrumentation for the 30F lux
    tower: terrain-fit report, door system check, full stairwell traversal
    (anim-driven capsule, lobby -> roof hut -> helipad). grep [LUXPROBE].
    Remove the initServer hook before commit (file stays, like stairprobe).

    Model frame: p3d (x, y_up, z_north), bbox y 0..119.92, z -18.04..21.70
      arma model = [p3d_x, p3d_z - 1.828, p3d_y - 59.960]
*/
if (!isServer) exitWith {};
private _tag = "[LUXPROBE]";
uiSleep 25;

private _objs = (allSimpleObjects []) select { "skyscraper30_r1" in toLower ((getModelInfo _x) select 0) };
if (count _objs isEqualTo 0) exitWith { diag_log format ["%1 ABORT model not present", _tag]; };
private _o = _objs select 0;
diag_log format ["%1 ==== start pos=%2 dir=%3 ====", _tag, getPosASL _o, getDir _o];

// terrain fit: corner heights vs placement
private _c = getPosASL _o;
private _spread = [];
{
    private _w = _o modelToWorld [_x select 0, _x select 1, -59.66];
    _spread pushBack (getTerrainHeightASL _w);
} forEach [[-18,-18],[18,-18],[18,18],[-18,18],[0,0]];
diag_log format ["%1 terrain corners=%2 spread=%3 m", _tag,
    _spread apply { _x toFixed 2 },
    ((selectMax _spread) - (selectMin _spread)) toFixed 2];

// doors: hut open for the exit path + swing check on 0 and 87
waitUntil { !isNil "AP_LUXDOOR_LEAVES" && { count AP_LUXDOOR_LEAVES > 0 } };
diag_log format ["%1 leaves spawned: %2", _tag, count AP_LUXDOOR_LEAVES];
{
    (AP_LUXDOOR_LEAVES select _x) params ["_leaf"];
    private _d0 = getDir _leaf;
    AP_LUXDOOR_STATE set [_x, 1]; publicVariable "AP_LUXDOOR_STATE";
    uiSleep 2;
    diag_log format ["%1 DOORTEST idx=%2 swing=%3", _tag, _x,
        (((getDir _leaf) - _d0 + 540) mod 360 - 180) toFixed 1];
} forEach [0, 87];

private _mp = { params ["_px", "_pz", "_py"]; [_px, _pz - 1.828, _py - 59.960] };
private _lvl = [0.3];
for "_i" from 1 to 30 do { _lvl pushBack ((_lvl select (_i - 1)) + ([6.0, 3.6] select (_i > 1))); };

private _chain = [];
for "_f" from 0 to 29 do {
    private _h = _lvl select _f;
    private _rise = (_lvl select (_f + 1)) - _h;
    private _half = _rise / 2;
    private _fl = format ["F%1", _f + 1];
    _chain pushBack [format ["%1 laneA base", _fl], -5.25,  1.90, _h];
    _chain pushBack [format ["%1 laneA top",  _fl], -5.25, -1.45, _h + _half];
    _chain pushBack [format ["%1 midLanding", _fl], -3.85, -2.25, _h + _half];
    _chain pushBack [format ["%1 laneB base", _fl], -2.45, -1.45, _h + _half];
    _chain pushBack [format ["%1 laneB top",  _fl], -2.45,  1.55, _h + _rise];
    _chain pushBack [format ["%1 N landing",  _fl], -3.85,  2.25, _h + _rise];
};
_chain pushBack ["ROOF hut door", -0.60, 2.25, 110.7];
_chain pushBack ["ROOF helipad",   9.00, 9.00, 110.7];
private _down = [];
for "_i" from (count _chain - 1) to 0 step -1 do { _down pushBack (_chain select _i); };

private _grp = createGroup [east, true];
private _spawnAt = AGLToASL (_o modelToWorldVisual ([-5.25, 1.90, 0.3] call _mp));
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
            diag_log format ["%1 FAIL %2 %3 -- stuck at model=%4 -- teleporting on", _tag, _legName, _label, _m];
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
