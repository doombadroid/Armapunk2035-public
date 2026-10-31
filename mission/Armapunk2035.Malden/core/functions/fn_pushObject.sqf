private _object = cursorObject;
if !(local _object) exitWith {};
if !(alive _object) exitWith {};
private _direction = getDir player;
private _speed =
if (cursorObject isKindOf "Air") then {3} else {6};
_object setVelocity[(sin _direction * _speed), (cos _direction * _speed), 3];
uiSleep 2;
_object setVelocity([0, 0, 0]);