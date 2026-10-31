/*
    AP_fnc_pushFunction  (LooneyBin NEW 2026-06-09 -- fn_pushVehicle referenced it but it never
    existed.) Runs WHERE THE VEHICLE IS LOCAL (pushVehicle remoteExecs here): shoves the vehicle away
    from the pusher. For beached boats / stuck cars.
    [caller, target, callerPos, callerDir]
*/
params [["_caller", objNull, [objNull]], ["_target", objNull, [objNull]], ["_posCaller", [0,0,0], [[]]], ["_dir", 0, [0]]];
if (isNull _target || {!local _target}) exitWith {};
if (speed _target > 8) exitWith {};
private _away = (getPosATL _target) vectorDiff _posCaller;
_away set [2, 0];
private _n = vectorMagnitude _away;
private _unitV = if (_n < 0.1) then { [sin _dir, cos _dir, 0] } else { _away vectorMultiply (1 / _n) };
private _mass = (1 max (getMass _target / 1500)) min 4;
_target setVelocity ((velocity _target) vectorAdd (_unitV vectorMultiply (2.2 / _mass)) vectorAdd [0, 0, 0.12]);
