/*
    AP_fnc_hcReverse  (LooneyBin, owner 2026-07-16) -- physics REVERSE.
    Backs a LOCAL vehicle straight back ~_dist metres using the SAME command family as the forward autopilot,
    just a NEGATIVE model-space Y velocity (+Y is forward, so -Y drives the hull backward -- setVelocity is a
    direct PhysX override, it doesn't care the wheels can't spin backward). Raycasts BEHIND every frame so it
    never reverses into a wall. Blocking (call it): returns when it has gone _dist, is blocked, dies, or times out.
    Runs on the machine that owns the vehicle (the HC, or the server). Reusable by any autopilot flow.

    [_veh, _dist, _speed]   _speed m/s (default 4.5 -- gentle)
    Out: "done" | "blocked" | "lost"
*/
params [["_veh", objNull, [objNull]], ["_dist", 12, [0]], ["_speed", 4.5, [0]]];
if (isNull _veh || {!local _veh} || {!(_veh isKindOf "LandVehicle")}) exitWith { "lost" };

_veh engineOn true;
_veh disableBrakes true;
private _start = getPosASL _veh;
private _end = time + (_dist / (_speed max 0.5)) + 6;
private _fno = diag_frameNo - 1;
private _reason = "done";

while { !isNull _veh && {alive _veh} && {local _veh} && {time < _end} } do {waitUntil { diag_frameNo != _fno };
    _fno = diag_frameNo;
    private _pos = getPosASL _veh;
    if ((_pos distance2D _start) >= _dist) exitWith { _reason = "done"; };

    // obstacle behind (reverse direction = opposite of facing)
    private _dir = getDir _veh;
    private _bx = -(sin _dir); private _by = -(cos _dir);
    private _eye = _pos vectorAdd [0, 0, 0.6];
    private _reach = 3.5 + _speed;
    private _hit = lineIntersectsSurfaces [_eye, [(_eye select 0) + _bx * _reach, (_eye select 1) + _by * _reach, (_eye select 2)], _veh, objNull, true, 1, "GEOM", "NONE"];
    if (count _hit > 0 && {!isNull ((_hit select 0) select 2)} && {(_eye distance ((_hit select 0) select 0)) < 3.5}) exitWith { _reason = "blocked"; };

    _veh setVelocityModelSpace [0, -_speed, (velocityModelSpace _veh) select 2];
    _veh setAngularVelocity [0, 0, 0];   // straight back, no steer
};
if (!isNull _veh && {local _veh}) then { _veh setVelocity [0, 0, 0]; _veh disableBrakes false; };
if (isNull _veh || {!alive _veh}) then { _reason = "lost"; };
_reason
