private _vehicle = cursorTarget;
if (isNull _vehicle) exitWith {["You need to look at the vehicle you want to refuel!", "basic"] spawn AP_fnc_handleMessage;};
if !(_vehicle isKindOf "LandVehicle" || _vehicle isKindOf "Air" || _vehicle isKindOf "Ship") exitWith {};
if (player distance _vehicle > 7.5) exitWith {["You need to be closer to the vehicle!", "basic"] spawn AP_fnc_handleMessage;};
if !([false, "fuelF", 1] call AP_fnc_handleInv) exitWith {};
private _displayName = getText(configFile >> "CfgVehicles" >> typeOf _vehicle >> "displayName");
private _capacity = getNumber(configFile >> "CfgVehicles" >> typeOf _vehicle >> "fuelCapacity");
titleText[format["Refuelling %1.....", _displayName], "PLAIN"];
player playMove "AinvPknlMstpSlayWrflDnon_medic";
uiSleep 5;
private _tick = 20 / _capacity;
private _level = (fuel _vehicle) + _tick;
if (_level > 1) then {_level = 1;};
if !(local _vehicle) then {[[_vehicle, _level], "AP_fnc_setFuel", _vehicle, false, false] spawn AP_fnc_MP;} else {
    _vehicle setFuel _level;};
titleText[format["You have added 20 litres of fuel to the %1.", _displayName], "PLAIN"];
[true, "fuelE", 1] call AP_fnc_handleInv;
["fuelcans", 1] call AP_fnc_statArrUpdate;