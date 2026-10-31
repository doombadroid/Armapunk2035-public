#include "..\..\macro.h"
params[["_house", objNull, [objNull]]];
if !(alive _house) exitWith {
    ["The building you're trying to buy is too damaged at this time for purchasing. Please wait until after a server restart to purchase this home.", "basic"] spawn AP_fnc_handleMessage;
};
if (damage _house > 0.15) exitWith {
    ["The building you're trying to buy is too damaged at this time for purchasing. Please wait until after a server restart to try and purchase this home.", "basic"] spawn AP_fnc_handleMessage;
};
if (AP_houseTxn) exitWith {["You are currently in the process of buying or selling a home.", "basic"] spawn AP_fnc_handleMessage;};
if (isNull _house) exitWith {};
// owner 2026-07-04: a buyable industrial-shed spot keeps the DERELICT Land_u_Shed_Ind_F alongside the intact
// Land_i_Shed_Ind_F -- the derelict is a terrain object (can't be deleted, and setPos won't move it), so
// cursorObject can still resolve it. Redirect the buy to the intact shed at this spot so ownership / upgrades /
// storage / spawn all bind to the spawnable shed (mirrors the _tagHouses classname resolve). Without this the
// buyer ends up owning an un-spawnable derelict (fixed live for 6 rows; this stops it recurring).
if ((typeOf _house) isEqualTo "Land_u_Shed_Ind_F") then {
    private _i = (nearestObjects [_house, ["Land_i_Shed_Ind_F"], 8]) param [0, objNull];
    if (!isNull _i) then { _house = _i; };};
if !(_house isKindOf "House_F") exitWith {};
if !(AP_effSide isEqualTo civilian) exitWith {};
if !(license_civ_home) exitWith {["You do not have a home owners license!", "basic"] spawn AP_fnc_handleMessage;};
if (!isNil {(_house getVariable "AP_house_sold")}) exitWith {
    ["This house was recently sold and is still being processed by the server.", "basic"] spawn AP_fnc_handleMessage;};
if (AP_action_in_use) exitWith {["You are currently busy performing another action...", "basic"] spawn AP_fnc_handleMessage;};
if (_house getVariable["AP_restricted_house", false]) exitWith {["This house cannot be purchased.", "basic"] spawn AP_fnc_handleMessage;
};
// LooneyBin (owner, 2026-06-10): no property within 500m of a cartel zone -- covers both fresh
// purchases and owner-to-owner transfers (both run through this fn).
private _nearCartel = ["arms_cartel", "drug_cartel", "oil_cartel", "wongs_cartel"] findIf {private _mPos = getMarkerPos _x;
    (_mPos isNotEqualTo [0,0,0]) && {(_house distance2D _mPos) < 500}};
if (_nearCartel isNotEqualTo -1) exitWith {
    ["You cannot purchase property within 500m of a cartel zone.", "basic"] spawn AP_fnc_handleMessage;};
// owner 2026-07-10: house-buy processing block SIMPLIFIED to the METH LAB only. Was: no property within 300m
// of ANY red processing/illegal marker (meth/coke/heroin/weed processors, chop shops, illegal areas, etc.).
// Now the ONLY processing block is a tight 150m ring around the meth lab -- the cook markers "blacklace" +
// "blacklaceprime" (fn_processAction) and the visible "Meth Lab" zone marker illegal_marker_3_1. EVERYWHERE else --
// coke/heroin/weed processors, chop shops, illegal areas -- is now buyable. (The 500m cartel block above is a
// separate rule, left intact.) markerType guard skips any marker not present on this map.
private _methMarkers = ["blacklace", "blacklaceprime", "illegal_marker_3_1"];
private _nearMeth = _methMarkers findIf { !((markerType _x) isEqualTo "") && {(_house distance2D (getMarkerPos _x)) < 150} };
if (_nearMeth isNotEqualTo -1) exitWith {
    ["You cannot purchase property within 150m of the meth lab.", "basic"] spawn AP_fnc_handleMessage;};
// owner 2026-06-21 (#420/#280): the spirit-distillery BUILDING was purchasable as a "house" but is a processing
// building you can't live in -- multiple players bought it and got stuck (couldn't enter). Block buying anything
// at the distillery (40m around the spirit_distillery_area marker; nearest real house is 54m out, so it's clear).
// The prior buyer (ebola) was refunded $1M + evicted. Mirrors the cartel-zone exclusion above.
private _distPos = getMarkerPos "spirit_distillery_area";
if ((_distPos isNotEqualTo [0,0,0]) && {(_house distance2D _distPos) < 40}) exitWith {
    ["This building is part of the spirit distillery and cannot be purchased.", "basic"] spawn AP_fnc_handleMessage;};
if (!(_house getVariable["AP_homeOwner", ""] isEqualTo "") && (_house getVariable["AP_house_price", -1] isEqualTo - 1)) exitWith {
    ["This house is already owned and not for sale!", "basic"] spawn AP_fnc_handleMessage;};
if (isNil {_house getVariable "AP_house_price"} && !(isNil {_house getVariable "AP_houseID"})) exitWith {
    ["This house is already owned and not for sale!", "basic"] spawn AP_fnc_handleMessage;};
closeDialog 0;
private _forSale =
if (_house getVariable["AP_house_price", -1] > 0) then {true} else {false};
private _houseCfg = [typeOf _house] call AP_fnc_houseConfig;
if (_houseCfg isEqualTo[]) exitWith {};
_houseCfg params[["_buyPrice", -1], ["_sellPrice", -1], ["_physInv", []], ["_virtInv", []]];
private _maxPhys = ((_physInv select((count _physInv) - 1)) select 0);
private _maxVirt = ((_virtInv select((count _virtInv) - 1)) select 0);
private _curPhys = 0;
private _curVirt = 0;
private _hasBarrel = "EMPTY";
private _hasGreenhouse = "EMPTY";
private _hasLeadContainer = "EMPTY";
private _canAgeBarrel =
if !((typeOf _house) in ["Land_i_Garage_V1_F", "Land_i_Garage_V2_F", "Land_i_Garage_V1_dam_F", "Land_i_Garage_V2_dam_F"]) then {
    "supports"} else {"does not support"};
private _canAgeGreenhouse =
if !((typeOf _house) in ["Land_i_Garage_V1_F", "Land_i_Garage_V2_F", "Land_i_Garage_V1_dam_F", "Land_i_Garage_V2_dam_F"]) then {
    "supports"} else {"does not support"};
private _canAgeLeadContainer =
if !((typeOf _house) in ["Land_i_Garage_V1_F", "Land_i_Garage_V2_F", "Land_i_Garage_V1_dam_F", "Land_i_Garage_V2_dam_F"]) then {
    "supports"} else {"does not support"}; if (_forSale) then {_curPhys = _house getVariable["AP_phys_cap", -1];
    _curVirt = _house getVariable["AP_vcap", -1];
    _buyPrice = _house getVariable["AP_house_price", -3];
    if (211 in AP_side_talents && {_buyPrice > 0}) then { _buyPrice = round (_buyPrice * 0.8); };   // HOMESTEADER First-Time Buyer -20%
    _hasBarrel =
    if (_house getVariable["AP_barrel_unaged", false]) then {"This building has the aging upgrade already purchased."} else {
        "This building does not currently have the aging upgrade."};
    _hasGreenhouse =
    if (_house getVariable["AP_greenhouse_unaged", false]) then {"This building has the greenhouse upgrade already purchased."} else {
        "This building does not currently have the greenhouse upgrade."};
    _hasLeadContainer =
    if (_house getVariable["AP_leadcontainer_unaged", false]) then {
        "This building has the lead container upgrade already purchased."} else {
        "This building does not currently have the lead container upgrade."};
}; if (_curVirt isEqualTo - 1 || _curPhys isEqualTo - 1 || _buyPrice isEqualTo - 3) exitWith {
    ["An error has occured. Try again...", "basic"] spawn AP_fnc_handleMessage;};
if (_buyPrice isEqualTo - 1 || {_sellPrice isEqualTo - 1}) exitWith {};
AP_action_in_use = true;
private _text =
if (_forSale) then {
    format["This house is for sale by owner for $%1. It currently is upgraded to %2 physical inventory of %3 max and %4 virutal inventory of %5 max. %6. %7. %8.", [_buyPrice] call AP_fnc_numberText, _curPhys, _maxPhys, _curVirt, _maxVirt, _hasBarrel, _hasGreenhouse, _hasLeadContainer]
} else {_tax = (_buyPrice * (call AP_fnc_getGovTax));
    _buyPrice = (_buyPrice + _tax);
    format["This house is available for $%1, including a tax of $%7. It can hold up to %2 physical inventory and %3 virtual inventory. This building %4 the aging of liquor. This building %5 a greenhouse. This building %6 a lead container.", [_buyPrice] call AP_fnc_numberText, _maxPhys, _maxVirt, _canAgeBarrel, _canAgeGreenhouse, _canAgeLeadContainer, [_tax] call AP_fnc_numberText]
};
private _action = [_text, "Buy House", "Purchase", "Cancel"] call BIS_fnc_guiMessage;
if !(_action) exitWith {closeDialog 0;
    ["You have decided to not purchase the home at this time.", "basic"] spawn AP_fnc_handleMessage;
    AP_action_in_use = false;};
if (scriptAvailable(60)) exitWith {["You cannot rapidly purchase houses!", "basic"] spawn AP_fnc_handleMessage;
    AP_action_in_use = false;};
if (count AP_houses >= (call AP_houseLimit)) exitWith {
    [format["You currently own the max limit of buildings on the server. Limit: %1", call AP_houseLimit], "basic"] spawn AP_fnc_handleMessage;
    AP_action_in_use = false;};
// owner 2026-06-13: TWO industrial sheds (the 200k warehouse) per player. Count owned industrial sheds
// (resolve each AP_houses position -> building -> typeOf); if buying one while already owning 2, deny.
// Existing owners keep theirs. NOTE: the small Stone_Shed types are cheap 1C starter HOUSES, not the
// warehouse -- they are NOT capped (they were wrongly in this list, which blocked 1C buys: Ebola report).
private _shedTypes = ["Land_i_Shed_Ind_F"];
private _shedLimit = 2;
private _buyingShed = (typeOf _house) in _shedTypes;
private _shedCount = 0;
if (_buyingShed) then {{
        private _hp = parseSimpleArray (format ["%1", _x select 0]);   // SECURITY: parse, NEVER compile -- a poisoned house-worldspace string would otherwise run as SQF (Lystic compile-RCE class). Matches fn_CLinitHouses / fn_handleHouse / fn_manageHouseTax.
        if (_hp isEqualType [] && {count _hp >= 2} && {(_hp select 0) isEqualType 0}) then {
            private _b = (nearestObjects [_hp, ["House_F"], 6]) param [0, objNull];
            if ((typeOf _b) in _shedTypes) then { _shedCount = _shedCount + 1 };};} forEach AP_houses;};
if (_buyingShed && _shedCount >= _shedLimit) exitWith {
    [format ["You can only own %1 industrial sheds (warehouses). Sell one before buying another.", _shedLimit], "basic"] spawn AP_fnc_handleMessage;
    AP_action_in_use = false;};
if ((AP_atmcash < _buyPrice) && (AP_cash < _buyPrice)) exitWith {
    [format["You do not have %1 in your bank or on-hand to purchase this building.", [_buyPrice] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
    AP_action_in_use = false;};
if (AP_houseTxn) exitWith {["You are currently in the process of buying or selling a home.", "basic"] spawn AP_fnc_handleMessage;};
AP_houseTxn = true;
if (AP_cash >= _buyPrice) then {AP_cash = AP_cash - _buyPrice;
    AP_cashCacheB = ((AP_cash / 4) + 9);} else {AP_atmcash = AP_atmcash - _buyPrice;
    AP_atmcashCacheB = ((AP_atmcash / 4) + 11);};
[6] call AP_fnc_ClupdatePartial;
if !(_forSale) then {
    // pass base virtual/physical caps (from houseConfig) so the server persists them in the houses row
    [
        [player, getPlayerUID player, _house, _buyPrice, ((_virtInv select 0) select 0), ((_physInv select 0) select 0)], "APS_fnc_addHouse", false, false] spawn AP_fnc_MP;
    ["Contacting the Altis Realtor Group to send an offer...", "basic"] spawn AP_fnc_handleMessage;} else {[
        [player, getPlayerUID player, _house, _buyPrice], "APS_fnc_transferHouse", false, false] spawn AP_fnc_MP;
    ["Contacting the Altis Realtor Group to transfer ownership...", "basic"] spawn AP_fnc_handleMessage;};