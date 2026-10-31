private _vehicle = vehicle player;
private _speed = speed _vehicle;
if (isNull objectParent player) exitWith {};
if !((driver _vehicle) isEqualTo player) exitWith {};
if (isNull _vehicle || !(_vehicle isKindOf "Car" || _vehicle isKindOf "Air" || _vehicle isKindOf "Ship")) exitWith {};
if (player getVariable["AP_downed", false] || player getVariable["AP_restrained", false]) exitWith {};
if !(local _vehicle) exitWith {["This vehicle is not yours.", "basic"] spawn AP_fnc_handleMessage;};
_vehicle setCruiseControl[_speed, true];
["Cruise Control enabled. Brake to disable.", "basic"] spawn AP_fnc_handleMessage;