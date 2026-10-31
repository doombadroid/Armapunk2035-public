params[["_object", objNull, [objNull]]];
if (isNull _object) exitWith {};
if (_object in AP_vehicles) then {AP_vehicles = AP_vehicles - [_object];};