// FAST ROPE -- the roping client's whole descent, start to finish.
//
// The player is NOT simulated on the rope: they are attachTo'd to the helicopter at the
// rope station and the attachment's z offset is walked down every tick. That is what makes
// the "pilot pulls away and you ride along" behaviour fall out for free -- you are welded
// to the airframe the entire time, so when it moves, you move with it, and all the hold
// branch does is stop lowering you further until it settles.
//
// Everything here is client-local except the ropes and the doors, which are the
// helicopter owner's job (AP_fnc_fastRopeRope, remoteExec'd to it).
if (AP_fastRoping) exitWith {};

private _heli = objectParent player;
private _classes  = ["classes"]     call AP_fnc_fastRopeCfg;
private _minAlt   = ["minAltitude"] call AP_fnc_fastRopeCfg;
private _maxAlt   = ["maxAltitude"] call AP_fnc_fastRopeCfg;
private _maxSpeed = ["maxSpeed"]    call AP_fnc_fastRopeCfg;
private _rate     = ["descentRate"] call AP_fnc_fastRopeCfg;

if (isNull _heli) exitWith {};
if !((typeOf _heli) in _classes) exitWith {["This helicopter has nothing to rope from.", "basic"] spawn AP_fnc_handleMessage;};

private _anchors = ["anchors", typeOf _heli] call AP_fnc_fastRopeCfg;

if (player isEqualTo (driver _heli)) exitWith {["Somebody has to fly it.", "basic"] spawn AP_fnc_handleMessage;};
if (AP_action_in_use) exitWith {};
if (!alive player || AP_isDowned) exitWith {};
if (player getVariable ["AP_restrained", false]) exitWith {["Not with your hands bound.", "basic"] spawn AP_fnc_handleMessage;};

private _alt = (getPosATL _heli) select 2;
if (_alt < _minAlt) exitWith {[format ["You are only %1m up - just get out.", round _alt], "basic"] spawn AP_fnc_handleMessage;};
if (_alt > _maxAlt) exitWith {[format ["Too high to rope out. Get below %1m.", _maxAlt], "basic"] spawn AP_fnc_handleMessage;};
// abs: speed is signed, so a pilot backing up fast would otherwise pass a plain > test.
if (abs (speed _heli) > _maxSpeed) exitWith {["Tell your pilot to hold it steady.", "basic"] spawn AP_fnc_handleMessage;};

// Pick the station on the side you are already sitting on, so nobody teleports across the
// cabin to reach a rope.
private _model = _heli worldToModel (getPosWorld player);
private _anchor = _anchors select ([1, 0] select ((_model select 0) >= 0));
_anchor params ["_anchorX", "_anchorY"];

AP_fastRoping = true;
AP_action_in_use = true;

// Ropes and doors are owner-side. This is refcounted there, so the first man out opens the
// doors and hangs the ropes and the last man off takes them away.
[_heli, true] remoteExec ["AP_fnc_fastRopeRope", _heli];

private _offsetZ = -1.2;
moveOut player;
player attachTo [_heli, [_anchorX, _anchorY, _offsetZ]];
player switchMove (["LadderRifleStatic", "LadderCivilStatic"] select ((primaryWeapon player) isEqualTo ""));

// X (DIK 0x2D) cuts loose wherever you are -- and nothing catches you, by design.
// Returns false so the key still reaches the game's own handlers.
private _cutHandler = (findDisplay 46) displayAddEventHandler ["KeyDown", {
    params ["", "_key"];
    if (_key isEqualTo 45) then {AP_fastRoping = false};
    false
}];

["Roping out. Press X to cut loose.", "basic"] spawn AP_fnc_handleMessage;

private _step = 0.05;
private _warned = false;
private _struck = false;
private _last = getPosASL player;

while {true} do {
    uiSleep _step;
    if (isNull _heli || {!alive _heli}) exitWith {};
    if !(alive player) exitWith {};
    if !(AP_fastRoping) exitWith {};     // X, or anything else that clears the flag
    if (AP_isDowned) exitWith {};

    private _heliAlt = (getPosATL _heli) select 2;
    private _hold = (abs (speed _heli) > _maxSpeed) || {_heliAlt > _maxAlt};
    private _from = _last;

    if (_hold) then {
        // Ride along. The attachment is untouched, so you simply stop descending and go
        // wherever the airframe goes until the pilot settles again.
        if !(_warned) then {
            _warned = true;
            ["The helicopter is moving - you are holding on until it settles.", "basic"] spawn AP_fnc_handleMessage;
        };
    } else {
        _warned = false;
        _offsetZ = _offsetZ - (_rate * _step);
        player attachTo [_heli, [_anchorX, _anchorY, _offsetZ]];
    };

    // Collision: sweep the segment actually travelled this tick, extended half a metre
    // along the direction of travel, at three heights up the body. attachTo means the
    // engine will happily drag you through a roof, so this is the only thing that notices.
    private _now = getPosASL player;
    private _travel = _now vectorDiff _from;
    _last = _now;
    private _lead = if ((vectorMagnitude _travel) > 0.001) then {(vectorNormalized _travel) vectorMultiply 0.5} else {[0, 0, -0.5]};
    private _end = _now vectorAdd _lead;

    // The ropes and the helicopter itself are always in the way; ignore both.
    private _ropeObjects = ropes _heli;
    private _blocked = -1;
    {
        private _lift = [0, 0, _x];
        private _hits = lineIntersectsSurfaces [_from vectorAdd _lift, _end vectorAdd _lift, player, _heli, true, 5, "GEOM", "NONE"];
        private _real = _hits findIf {
            private _hit = _x select 2;
            private _parent = _x select 3;
            !(_hit in _ropeObjects) && {!(_parent in _ropeObjects)} && {!(_hit isEqualTo _heli)} && {!(_parent isEqualTo _heli)}
        };
        if (_real > -1) exitWith {_blocked = _real};
    } forEach [0.2, 0.9, 1.6];

    if (_blocked > -1) exitWith {_struck = true};
    if (((getPosATL player) select 2) <= 0.7) exitWith {};   // feet down, normal finish
};

(findDisplay 46) displayRemoveEventHandler ["KeyDown", _cutHandler];
detach player;
player switchMove "";
AP_fastRoping = false;
AP_action_in_use = false;

if (_struck) then {["You hit something on the way down and lost the rope.", "basic"] spawn AP_fnc_handleMessage;};

[_heli, false] remoteExec ["AP_fnc_fastRopeRope", _heli];
