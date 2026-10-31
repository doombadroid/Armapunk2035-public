if !(params[["_vehicle", objNull, [objNull]]]) exitWith {};
if !((_vehicle isKindOf "Car") || (_vehicle isKindOf "Air") || (_vehicle isKindOf "Ship") || (_vehicle isKindOf "Tank")) exitWith {
    ["The explosive cannot be fitted to this vehicle!"] spawn AP_fnc_handleMessage};
if (isEngineOn _vehicle) exitWith {
    ["This vehicle must have its engine turned off, before you start adding explosives!"] spawn AP_fnc_handleMessage};
if (speed(vehicle player) > 0) exitWith {
    ["This vehicle must be at a standstill before you start adding explosives!"] spawn AP_fnc_handleMessage};
if (player isNotEqualTo(driver(vehicle player))) exitWith {
    ["You must be in the driver seat of a vehicle to use this."] spawn AP_fnc_handleMessage};
if !([false, "ignitionbomb", 1] call AP_fnc_handleInv) exitWith {
    ["You don't have an ignition bomb in your inventory!"] spawn AP_fnc_handleMessage};
disableSerialization;
5 cutRsc["AP_progress", "PLAIN"];
private _text = "Attaching ignition bomb";
private _ui = uiNamespace getVariable "AP_progress";
private _progress = _ui displayCtrl 38201;
private _pgText = _ui displayCtrl 38202;
_pgText ctrlSetText format["%2 (1%1)...", "%", _text];
_progress progressSetPosition 0.01;
private _cP = 0.01;
private _success = false;
AP_action_in_use = true;
for "_i"
from 0 to 1 step 0 do {uiSleep 0.25;
    _cP = _cP + 0.01;
    _progress progressSetPosition _cP;
    _pgText ctrlSetText format["%3 (%1%2)...", round(_cP * 100), "%", _text];
    if (_cP >= 1) exitWith {_success = true;};
    if (isNull objectParent player) exitWith {["You cannot exit the vehicle while planting the explosives."] spawn AP_fnc_handleMessage};
    if (speed(vehicle player) > 0) exitWith {["The vehicle cannot move while planting the explosives."] spawn AP_fnc_handleMessage};
    if (isEngineOn _vehicle) exitWith {};
    if !(alive player) exitWith {};
    if !(AP_action_in_use) exitWith {};}; 5 cutText["", "PLAIN"];
AP_action_in_use = false;
if !(_success) exitWith {[true, "ignitionbomb", 1] call AP_fnc_handleInv;};
AP_side_exp = AP_side_exp + 20; [[_vehicle, profileName, getPlayerUID player, player], "APS_fnc_ignitionBombSRV", 2] spawn AP_fnc_MP;
[format["You have attached an ignition bomb to this %1!", (getText(configFile >> "CfgVehicles" >> (typeOf _vehicle) >> "displayName"))]] spawn AP_fnc_handleMessage;