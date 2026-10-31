#include "..\..\macro.h"
private["_diff", "_mods", "_trunk", "_itemClass"];
disableSerialization;
if (isNull AP_trunk_vehicle || !alive AP_trunk_vehicle) exitWith {};
if (!alive player) exitwith {closeDialog 0;};
if (AP_is_virtual) exitWith {closeDialog 0;};
if ((lbCurSel 4502) isEqualTo - 1) exitWith {["You did not select anything.", "basic"] spawn AP_fnc_handleMessage;};
private _fnc_updatePhysicalTrunk = {params["_trunkObj", "_items"];
    private _weight = _items call AP_fnc_physicalInventoryWeight;
    _trunkObj setVariable["AP_pinv", [_items, _weight], true];};
private _trunkItemSelected = getSelData(4502);
private _quantity = ctrlText 4505;
if (_trunkItemSelected isEqualTo "") exitWith {["You didn't select anything.", "basic"] spawn AP_fnc_handleMessage;};
if (!([_quantity] call AP_fnc_isNumber)) exitWith {["Invalid Number format.", "basic"] spawn AP_fnc_handleMessage;};
_quantity = parseNumber(_quantity);
if ((_quantity isEqualTo 0) && (AP_effSide isEqualTo civilian)) exitWith {
    ["You need to enter an amount to take!", "basic"] spawn AP_fnc_handleMessage;};
if ((_quantity < 1) && (AP_effSide isEqualTo civilian)) exitWith {
    ["You can't enter anything below one!", "basic"] spawn AP_fnc_handleMessage;};
private _vehPos = getPos AP_trunk_vehicle;
private _playerPos = getPos player;
// owner 2026-07-03: skip when INSIDE the vehicle + size-aware on-foot reach (big airframe -> "too far away"). See fn_storeInventory.
if ((vehicle player) isNotEqualTo AP_trunk_vehicle && {_vehPos distance _playerPos > (10 + 0.5 * (sizeOf typeOf AP_trunk_vehicle))}) exitWith {
    closeDialog 0;
    ["You are too far away!", "basic"] spawn AP_fnc_handleMessage;};
AP_inventoryInteraction = true;
private _data = AP_trunk_vehicle getVariable["AP_pinv", [[], 0]];
private _inv = _data select 0;
private _currentWeight = _data select 1;
private _weight = getNumber(missionConfigFile >> "CfgWeights" >> (_trunkItemSelected) >> "weight");
_itemClass = ([_trunkItemSelected] call BIS_fnc_itemType) select 1;
private _maxValue = lbValue[4502, (lbCurSel 4502)];
private _pilotHelms = ["H_PilotHelmetFighter_B", "H_PilotHelmetFighter_O", "H_PilotHelmetFighter_I"];
if (_quantity > _maxValue) then {_quantity = _maxValue};
private _fnc_adjustArray = {params["_item", "_array"];
    private _index = -1; {if !(_index isEqualTo - 1) exitWith {};
        if (_item isEqualTo(_x select 0)) exitWith {_index = _forEachIndex;};}
    forEach _array;
    if (_index isEqualTo - 1) exitWith {};
    if (((_array select _index) select 1) > 1) then {_array set[_index, [_item, ((_array select _index) select 1) - 1]];} else {
        _array set[_index, -1];};
    _array = _array - [-1];
    _array;};
private _fnc_dropItem = {
    params[["_classname", "", [""]], ["_count", 0, [0]], ["_playertarget", objNull, [objNull]], ["_player", objNull, [objNull]], ["_holder", objNull, [objNull]]];
    if !(isNull _holder) then {private _distance = _player distance2D _holder;
        if (_distance > 5) then {_holder = createVehicle["groundWeaponHolder", getPosATL _player, [], 0, "can_collide"];};} else {
        _holder = createVehicle["groundWeaponHolder", getPosATL _player, [], 0, "can_collide"];};
    private _itemClass = ([_classname] call BIS_fnc_itemType) select 1;
    switch _itemClass do {case "Backpack": {_holder addBackpackCargoGlobal[_classname, _count];}; default {
                if ((_itemClass isKindOf["Rifle", configFile >> "CfgWeapons"]) || (_itemClass isKindOf["Launcher", configFile >> "CfgWeapons"]) || (_itemClass isKindOf["Pistol", configFile >> "CfgWeapons"])) then {
                    _holder addWeaponCargoGlobal[_classname, _count];} else {_holder addItemCargoGlobal[_classname, _count];};};}; [
        [ true ], "AP_fnc_saveGear", _player, false] spawn AP_fnc_MP; [[_holder, 300], "APS_fnc_setCleanTime", 2] spawn AP_fnc_MP;};
private _holder = nearestObject[player, "groundWeaponHolder"];
for "_i"
from 1 to _quantity do {switch (true) do {case (_trunkItemSelected isKindOf["Rifle", configFile >> "CfgWeapons"]): {
                _inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;};
        case (_trunkItemSelected isKindOf["Launcher", configFile >> "CfgWeapons"]): {
                _inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;};
        case (_trunkItemSelected isKindOf["Pistol", configFile >> "CfgWeapons"]): {_inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;};
        case (_itemClass isEqualTo "Headgear"): {_inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;};
        case (_itemClass isEqualTo "Glasses"): {_inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;};
        case (_itemClass isEqualTo "Vest"): {_inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;};
        case (_itemClass isEqualTo "Backpack"): {_inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;};
        case (_itemClass isEqualTo "Uniform"): {_inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;};
        case (_itemClass isEqualTo "NVGoggles"): {_inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;};
        default {_inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
            [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;};};};
[] call AP_fnc_suiteStorageSync;   // suite: record the removal before the items reach the ground
[ _trunkItemSelected , _quantity, AP_trunk_vehicle, player, _holder] call _fnc_dropItem;
[AP_trunk_vehicle, AP_is_virtual] call AP_fnc_refreshInventory;