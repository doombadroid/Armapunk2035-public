#include "..\..\macro.h"
disableSerialization;
if ((lbCurSel 4503) isEqualTo - 1) exitWith {["You did not select anything.", "basic"] spawn AP_fnc_handleMessage;};
if (AP_is_virtual) exitWith {closeDialog 0;};
private _playerItemSelected = getSelData(4503);
private _quantity = ctrlText 4506;
if (_playerItemSelected isEqualTo "") exitWith {["You did not select anything.", "basic"] spawn AP_fnc_handleMessage;};
if !([_quantity] call AP_fnc_isNumber) exitWith {["Invalid Number format", "basic"] spawn AP_fnc_handleMessage;};
_quantity = parseNumber(_quantity);
if (_quantity isEqualTo 0) exitWith {["You need to enter an amount to store!", "basic"] spawn AP_fnc_handleMessage;};
if (_quantity < 1) exitWith {["You can't enter anything below one!", "basic"] spawn AP_fnc_handleMessage;};
private _vehPos = getPos AP_trunk_vehicle;
private _playerPos = getPos player;
if (_vehPos distance _playerPos > 10) exitWith {closeDialog 0;
    ["You are too far away!", "basic"] spawn AP_fnc_handleMessage;};
private _itemWeight = 0;
private _data = [[], 0];
AP_inventoryInteraction = true;
_itemWeight = getNumber(missionConfigFile >> "CfgWeights" >> (_playerItemSelected) >> "weight");
_data = AP_trunk_vehicle getVariable["AP_pinv", [[], 0]];
private _totalWeight = (AP_trunk_vehicle getVariable["AP_phys_cap", 100]);
private _currentWeight = _data select 1;
private _combinedWeight = _itemWeight;
private _tempItem = "";
private _index = -1;
private _maxValue = lbValue[4503, (lbCurSel 4503)];
if (_quantity > _maxValue) then {_quantity = _maxValue};
private _fnc_dropItem = {
    params[["_classname", "", [""]], ["_count", 0, [0]], ["_playertarget", objNull, [objNull]], ["_player", objNull, [objNull]], ["_holder", objNull, [objNull]]];
    if !(isNull _holder) then {private _distance = _player distance2D _holder;
        if (_distance > 5) then {_holder = createVehicle["groundWeaponHolder", getPosATL _player, [], 0, "can_collide"];};} else {
        _holder = createVehicle["groundWeaponHolder", getPosATL _player, [], 0, "can_collide"];};
    private _itemClass = ([_classname] call BIS_fnc_itemType) select 1;
    switch _itemClass do {case "Backpack": {_holder addBackpackCargoGlobal[_classname, _count];}; default {
                if ((_itemClass isKindOf["Rifle", configFile >> "CfgWeapons"]) || (_itemClass isKindOf["Launcher", configFile >> "CfgWeapons"]) || (_itemClass isKindOf["Pistol", configFile >> "CfgWeapons"])) then {
                    _holder addWeaponCargoGlobal[_classname, _count];} else {_holder addItemCargoGlobal[_classname, _count];};};}; [
        [ true ], "AP_fnc_saveGear", _player, false] spawn AP_fnc_MP;};
private _holder = nearestObject[player, "groundWeaponHolder"];
private _multipleDrop = false;
for "_i"
from 1 to _quantity do {switch (true) do {
        case (_playerItemSelected isEqualTo(primaryWeapon player) && !(_playerItemSelected in (items player))): {{
                    [_x, 1, AP_trunk_vehicle, player, _holder] call _fnc_dropItem;}
                forEach(primaryWeaponItems player); {[_x, 1, AP_trunk_vehicle, player, _holder] call _fnc_dropItem;}
                forEach(primaryWeaponMagazine player);
                player removeWeaponGlobal _playerItemSelected;
                [_playerItemSelected, 1, AP_trunk_vehicle, player, _holder] call _fnc_dropItem;};
        case ((_playerItemSelected in (primaryWeaponItems player)) || (_playerItemSelected in (primaryWeaponMagazine player))): {
                player removePrimaryWeaponItem _playerItemSelected;
                [_playerItemSelected, 1, AP_trunk_vehicle, player, _holder] call _fnc_dropItem;};
        case (_playerItemSelected isEqualTo(secondaryWeapon player)): {{[_x, 1, AP_trunk_vehicle, player, _holder] call _fnc_dropItem;}
                forEach(secondaryWeaponItems player); {[_x, 1, AP_trunk_vehicle, player, _holder] call _fnc_dropItem;}
                forEach(secondaryWeaponMagazine player);
                player removeWeaponGlobal _playerItemSelected;
                [_playerItemSelected, 1, AP_trunk_vehicle, player, _holder] call _fnc_dropItem;};
        case ((_playerItemSelected in (secondaryWeaponItems player)) || (_playerItemSelected in (secondaryWeaponMagazine player))): {
                player removeSecondaryWeaponItem _playerItemSelected;
                [_playerItemSelected, 1, AP_trunk_vehicle, player, _holder] call _fnc_dropItem;};
        case (_playerItemSelected isEqualTo(handgunWeapon player)): {{[_x, 1, AP_trunk_vehicle, player, _holder] call _fnc_dropItem;}
                forEach(handgunItems player); {[_x, 1, AP_trunk_vehicle, player, _holder] call _fnc_dropItem;}
                forEach(handgunMagazine player);
                player removeWeaponGlobal _playerItemSelected;
                [_playerItemSelected, 1, AP_trunk_vehicle, player, _holder] call _fnc_dropItem;};
        case ((_playerItemSelected in (handgunItems player)) || (_playerItemSelected in (handgunMagazine player))): {
                player removeHandgunItem _playerItemSelected;
                [_playerItemSelected, 1, AP_trunk_vehicle, player, _holder] call _fnc_dropItem;};
        case (_playerItemSelected isEqualTo(headgear player)): {removeHeadgear player;
                [_playerItemSelected, 1, AP_trunk_vehicle, player, _holder] call _fnc_dropItem;};
        case (_playerItemSelected isEqualTo(goggles player)): {removeGoggles player;
                [_playerItemSelected, 1, AP_trunk_vehicle, player, _holder] call _fnc_dropItem;};
        case (_playerItemSelected in (assignedItems player)): {if (_playerItemSelected in ["Binocular", "Rangefinder"]) then {
                    player removeWeapon _playerItemSelected;
                    [_playerItemSelected, 1, AP_trunk_vehicle, player, _holder] call _fnc_dropItem;} else {
                    player unassignItem _playerItemSelected;
                    player removeItem _playerItemSelected;
                    [_playerItemSelected, 1, AP_trunk_vehicle, player, _holder] call _fnc_dropItem;};};
        case (_playerItemSelected isEqualTo(uniform player)): {private _uniformItems = uniformItems player;
                if (count _uniformItems > 0) then {{[_x, 1, AP_trunk_vehicle, player, _holder] call _fnc_dropItem;}
                    forEach _uniformItems;};
                removeUniform player;
                [_playerItemSelected, 1, AP_trunk_vehicle, player, _holder] call _fnc_dropItem;};
        case (_playerItemSelected isEqualTo(vest player)): {private _vestItems = vestItems player;
                if (count _vestItems > 0) then {{[_x, 1, AP_trunk_vehicle, player, _holder] call _fnc_dropItem;}
                    forEach _vestItems;};
                removeVest player;
                [_playerItemSelected, 1, AP_trunk_vehicle, player, _holder] call _fnc_dropItem;};
        case (_playerItemSelected isEqualTo(backpack player)): {private _backpackItems = backpackItems player;
                if (count _backpackItems > 0) then {{[_x, 1, AP_trunk_vehicle, player, _holder] call _fnc_dropItem;}
                    forEach _backpackItems;};
                removeBackpackGlobal player;
                [_playerItemSelected, 1, AP_trunk_vehicle, player, _holder] call _fnc_dropItem;};
        default {if !(_playerItemSelected in (itemsWithMagazines player)) exitWith {};
            _multipleDrop = true;
            player removeItem _playerItemSelected;};};}; if (_multipleDrop) then {
    [_playerItemSelected, _quantity, AP_trunk_vehicle, player, _holder] call _fnc_dropItem;};
if !(AP_adminForce) then {[AP_trunk_vehicle, AP_is_virtual] call AP_fnc_refreshInventory;} else {
    [AP_trunk_vehicle, false] call AP_fnc_refreshAdminInventory;};