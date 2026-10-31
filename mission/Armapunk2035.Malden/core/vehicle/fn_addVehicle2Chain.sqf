params[["_vehicle", objNull, [objNull]], ["_giver", objNull, [objNull]]];
if (isNull _vehicle) exitWith {};
if !(_vehicle in AP_vehicles) then {AP_vehicles pushBack _vehicle;};
if (!isNil "_giver" && !(isNull _giver)) then {private _name = getText(configFile >> "CfgVehicles" >> (typeOf _vehicle) >> "displayName");
    [format["%1 has given you keys for a %2", name _giver, _name], "basic"] spawn AP_fnc_handleMessage;};