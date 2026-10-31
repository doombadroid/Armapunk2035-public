params["_target", "_caller", "_actionId", "_modifier"];
private _nearVehicles = nearestObjects[_target, ["Car"], 30];
private _vehicle = _nearVehicles param[_nearVehicles findIf {(_x getVariable["AP_convoyTransport", false]) && alive _x}, objNull];
if (isNull _vehicle) exitWith {["The stolen transport is not close enough!", "basic"] spawn AP_fnc_handleMessage};
if (_modifier > 1.0 || _modifier < 0.0) exitWith {}; [
    [_vehicle, _caller, _modifier, getPos _target], "APS_fnc_endConvoyRobbery", 2, false, false] spawn AP_fnc_MP;