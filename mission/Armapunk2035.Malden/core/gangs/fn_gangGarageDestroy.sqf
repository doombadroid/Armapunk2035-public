#include "..\..\macro.h"
if (scriptAvailable(5)) exitWith {["Wait a few seconds before trying to destroy another vehicle!", "basic"] spawn AP_fnc_handleMessage;};
if ((lbCurSel 10301) isEqualTo - 1) exitWith {
    ["You did not select a vehicle to destroy from your gang garage!", "basic"] spawn AP_fnc_handleMessage;};
params["_selectedVehicleData"];
_selectedVehicleData params["_classname", "_plate", "_color", "_insured", "_mods", "_vehWear", "_customPlate"];
_vehWear params["_currentVehDamage", "_currentVehFuelPercent", "_currentVehArmour"];
private _vehCfgRow = ["getVehicleRowParsed", "", _classname] call AP_fnc_vehicleConfig;
private _destroyPrice = (_vehCfgRow select 8) * 0.12;
if (AP_atmcash < _destroyPrice) exitWith {["You can't afford to destroy your vehicle!", "basic"] spawn AP_fnc_handleMessage;};
if !(AP_vehicles findIf {(_x getVariable["AP_dbInfo", []] param[1, -1]) isEqualTo _plate}
isEqualTo - 1) exitWith {["This vehicle is already in use.", "basic"] spawn AP_fnc_handleMessage};
private _action = [format["Do you want to destroy this vehicle from %1's gang garage? It will cost you $%2", getText(configFile >> "CfgVehicles" >> _classname >> "displayName"), [_destroyPrice] call AP_fnc_numberText], "Destroy Gang Vehicle", "Yes", "No"] call BIS_fnc_guiMessage;
if !(_action) exitWith {["You chose not to destroy your gang's vehicle!", "basic"] spawn AP_fnc_handleMessage;};
AP_atmcash = AP_atmcash - _destroyPrice;
AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
[1] call AP_fnc_ClupdatePartial; [[_plate, str(AP_gang_data param[0, -1]), true], "APS_fnc_vehicleDelete", 2] spawn AP_fnc_MP;
lbDelete[10301, lbCurSel 10301];
[format["You have destroyed your gang %1!", getText(configFile >> "CfgVehicles" >> _classname >> "displayName")], "basic"] spawn AP_fnc_handleMessage;
closeDialog 0;