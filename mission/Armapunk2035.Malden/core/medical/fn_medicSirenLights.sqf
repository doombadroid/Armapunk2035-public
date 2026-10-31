params[["_vehicle", objNull, [objNull]]];
if (isNull _vehicle) exitWith {};
if ((typeOf _vehicle) == "Steerable_Parachute_F") exitWith {};
private _lightState = _vehicle getVariable["AP_lights", false];
if (_lightState) then {_vehicle setVariable["AP_lights", false, true];} else {_vehicle setVariable["AP_lights", true, true]; [
        [_vehicle, 0.22], "AP_fnc_medicLights", -2, false, false] call AP_fnc_MP;};