#include "..\..\macro.h"
if (scriptAvailable(5)) exitWith {
    ["Wait a few seconds before trying to repair/refuel another vehicle!", "basic"] spawn AP_fnc_handleMessage;};
params["_selectedVehicleData", ["_fromDeck", false, [false]]];
if (!_fromDeck && {(lbCurSel 100151) isEqualTo - 1}) exitWith {
    ["You did not select a vehicle to repair from your garage!", "basic"] spawn AP_fnc_handleMessage;};
_selectedVehicleData params["_classname", "_plate", "_color", "_insured", "_mods", "_vehWear", "_customPlate"];
_vehWear params["_currentVehDamage", "_currentVehFuelPercent", "_currentVehArmour"];
if (_currentVehFuelPercent > 0.9 && _currentVehDamage < 0.75) exitWith {
    ["You can't repair/refuel vehicles that have more than 90% tank capacity full and have less than 75% damage!", "basic"] spawn AP_fnc_handleMessage;
};
private _vehInfo = [_classname] call AP_fnc_fetchVehInfo;
private _maxFuelCapacity = _vehInfo select 12;
// owner 2026-06-21 (#464): liters NEEDED to fill = capacity * the EMPTY fraction (1 - current fuel), not the
// fuel already in the tank. Old formula charged for current fuel -> a near-full vehicle cost the MOST to top off.
private _litersNeeded = (_maxFuelCapacity * (1 - _currentVehFuelPercent));
private _repairPrice = round((_litersNeeded * 6) + 150);
if (AP_atmcash < _repairPrice) exitWith {["You can't afford to repair/refuel your vehicle!", "basic"] spawn AP_fnc_handleMessage;};
if (!_fromDeck) then {
    private _action = [format["Would you like to repair/refuel your %1 for $%2?", getText(configFile >> "CfgVehicles" >> _className >> "displayName"), [_repairPrice] call AP_fnc_numberText], "Repair & Refuel Vehicle", "Yes", "No"] call BIS_fnc_guiMessage;
    if !(_action) exitWith {["You chose not to repair/refuel your vehicle!", "basic"] spawn AP_fnc_handleMessage;};
};
AP_atmcash = AP_atmcash - _repairPrice;
AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
[1] call AP_fnc_ClupdatePartial; [
    [_plate, (getPlayerUID player), getText(configFile >> "CfgVehicles" >> _className >> "displayName"), [_repairPrice] call AP_fnc_numberText], "APS_fnc_vehicleRepairSRV", 2] spawn AP_fnc_MP;
if (!_fromDeck) then { closeDialog 0; };