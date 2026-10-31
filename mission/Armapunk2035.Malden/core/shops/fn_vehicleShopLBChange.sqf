#include "..\..\macro.h"
params["_control", "_index"];
disableSerialization;
AP_veh_shop params["_shopVar", "_spawnPoints", "_shopFlag", ""];
private _classname = _control lbData _index;
private _vehCfgRow = ["getVehicleRowParsed", "", _classname] call AP_fnc_vehicleConfig;
private _vehPrice = (_vehCfgRow select 7) * (["vehshop", true] call AP_fnc_getDiscount);
private _vehSellPrice = _vehCfgRow select 8;
private _vehGarageFee = _vehCfgRow select 9;
private _vehTrunkSpace = _vehCfgRow select 10;
private _price = -1;
_price =
if (ctrlChecked((findDisplay 100100) displayCtrl 100106)) then {_vehPrice + 500} else {_vehPrice};
if !(_shopVar in ["reb_car", "nd_car"]) then {_price = _price + (_price * (call AP_fnc_getGovTax));};
private _vehicleInfo = [_classname] call AP_fnc_fetchVehInfo;
private _display = findDisplay 100100;
private _vehicleTitle = _display displayCtrl 100104;
private _detailsText = _display displayCtrl 100103;
private _skinsList = _display displayCtrl 100105;
private _purchaseButton = _display displayCtrl 100107;
_purchaseButton ctrlEnable!(_index isEqualTo - 1);
private _talentRequired = ["talentCheck", "", _classname] call AP_fnc_vehicleConfig;
if (_talentRequired isEqualTo "") then {_purchaseButton buttonSetAction "[] spawn AP_fnc_vehicleShopBuy;";} else {
    _purchaseButton buttonSetAction(format['["You require the %1 talent before being able to purchase this vehicle.","basic"] spawn AP_fnc_handleMessage', _talentRequired]);
};
private _message = parseText format["<t size='0.40'>&#160;</t><br/><img image='%2' size='1.15'/> | %1", _vehicleInfo select 3, _vehicleInfo select 2];
_vehicleTitle ctrlSetStructuredText _message;
private _quantity = -1;
private _available =
switch (_quantity) do {case -1: {"<t color='#00ff00'>Unlimited</t>"};
    case 0: {"<t color='#ff0000'>HIGH DEMAND</t>"};
    default {format["<t color='#ffe100'>%1 remaining</t>", _quantity]};}; private _asyVehdetails = ""; {_x params["_title", "_value"];
    _asyVehdetails = _asyVehdetails + format["%1: %2<br/><t size='0.25'>&#160;</t><br/>", _title, _value];}
forEach[["Purchase Price",
    // NEW DRACHMA: the nd_car shop prices in ND (fn_ndPriceCfg, else 6000:1). Sell-back is ND too now.
    if (_shopVar isEqualTo "nd_car") then {
        private _ndP = [_classname] call AP_fnc_ndPriceCfg; if (_ndP isEqualTo "") then { _ndP = [_price] call AP_fnc_ndFromLegacy; };
        format["<t color='#8cff9b'>%1 ND</t>", [_ndP] call AP_fnc_ndText]} else {
        format["<t color='#8cff9b'>$%1</t>", [_price] call AP_fnc_numberText]}], ["Quantity Available", _available], ["Sellback Price",
    if (_shopVar isEqualTo "nd_car") then {format["%1 ND", [[_vehSellPrice] call AP_fnc_ndFromLegacy] call AP_fnc_ndText]} else {
        format["$%1", [_vehSellPrice] call AP_fnc_numberText]
    }], ["Garage Fee", format["$%1", [_vehGarageFee] call AP_fnc_numberText]], ["Max Speed", format["%1 km/h", _vehicleInfo select 8]], ["Passenger Seats", (([_classname, true] call BIS_fnc_crewCount) - 1)], ["Trunk Capacity",
if (_vehTrunkSpace >= 1) then {format["%1", [_vehTrunkSpace] call AP_fnc_numberText]} else {
    "None"
}], ["Fuel Capacity", format["%1 litres", [_vehicleInfo select 12] call AP_fnc_numberText]], ["Armor Rating", _vehicleInfo select 9]];
_detailsText ctrlSetStructuredText parseText format["<t size='0.76'>%1</t>", _asyVehdetails];
lbClear _skinsList;
private _textures = ["ownedTextures", _className] call AP_fnc_vehicleTextures;
private _index = -1; {_index = lbAdd[100105, _x select 1];
    lbSetValue[100105, _index, _x select 0];}
forEach _textures;
_skinsList ctrlEnable((lbSize _skinsList) >= 1);
_skinsList lbSetCurSel 0;
// NIGHT CITY buy-time configure: stash the taxed base (no alarm), fill the mod grid, price the total
private _baseTotal = _vehPrice;
if !(_shopVar in ["reb_car", "nd_car"]) then {_baseTotal = _baseTotal + (_baseTotal * (call AP_fnc_getGovTax));};
uiNamespace setVariable ["AP_VehShopBase", round _baseTotal];
uiNamespace setVariable ["AP_VehShopClass", _classname];   // NEW DRACHMA: total panel looks up the exact ND price
[_classname] call AP_fnc_vehicleShopMods;
[] call AP_fnc_vehicleShopTotal;