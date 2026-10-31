/*
    AP_fnc_hcTurnAround  (LooneyBin, owner 2026-07-16) -- 3-POINT / U TURN.
    Rotates a LOCAL vehicle to face _targetDir in a tight space. setAngularVelocity is heavily DAMPED on a grounded
    car at low speed (the wheels resist it -- the forward autopilot only gets away with it at speed), so the
    rotation is FORCED with setDir (kinematic, undampable) while setVelocity rolls the hull forward along the arc;
    if a wall is close ahead it reverses to make room (the "3-point"). Same setVelocity family as the autopilot,
    plus a forced heading. Blocking (call it): returns when it faces _targetDir, dies, or times out. Runs where the
    vehicle is local (the HC). Reusable by any autopilot flow (dead-ends, U-turns, three-point parking).

    [_veh, _targetDir]   _targetDir compass degrees to end up facing
    Out: true if it reached the heading, false otherwise
*/
params [["_veh", objNull, [objNull]], ["_targetDir", 0, [0]]];
if (isNull _veh || {!local _veh} || {!(_veh isKindOf "LandVehicle")}) exitWith { false };

_veh engineOn true;
_veh disableBrakes true;
private _speed = 3.0;      // roll speed along the arc
private _rate  = 45;       // forced rotation, deg/sec
private _end = time + 20; private _fno = diag_frameNo - 1;
private _ok = false;

while { !isNull _veh && {alive _veh} && {local _veh} && {time < _end} && {((getPosASL _veh) select 2) > -1.2} } do {
    waitUntil { diag_frameNo != _fno };
    _fno = diag_frameNo;
    private _dt = diag_deltaTime min 0.1;
    if (_dt <= 0) then { _dt = 0.02; };
    private _signed = ((_targetDir - (getDir _veh) + 540) mod 360) - 180;
    if (abs _signed < 8) exitWith { _ok = true; };

    // FORCE the heading a capped step toward the target (setDir isn't damped like setAngularVelocity)
    private _step = ((_rate * _dt) min (abs _signed)) * (if (_signed >= 0) then { 1 } else { -1 });
    _veh setDir ((getDir _veh) + _step);

    // roll forward along the arc; only reverse when a wall is genuinely CLOSE ahead (short ray + tight threshold
    // so it uses the room it has and 3-points only in a real pinch, instead of backing off with space to spare).
    private _dir = getDir _veh; private _pos = getPosASL _veh;
    private _eye = _pos vectorAdd [0, 0, 0.6];
    private _hitF = lineIntersectsSurfaces [_eye, [(_eye select 0) + (sin _dir) * 3.0, (_eye select 1) + (cos _dir) * 3.0, (_eye select 2)], _veh, objNull, true, 1, "GEOM", "NONE"];
    private _wallAhead = (count _hitF > 0) && {!isNull ((_hitF select 0) select 2)} && {(_eye distance ((_hitF select 0) select 0)) < 2.7};
    private _v = if (_wallAhead) then { -_speed } else { _speed };
    _veh setVelocityModelSpace [0, _v, (velocityModelSpace _veh) select 2];};
if (!isNull _veh && {local _veh}) then { _veh setVelocity [0, 0, 0]; _veh setAngularVelocity [0, 0, 0]; _veh disableBrakes false; };
_ok
