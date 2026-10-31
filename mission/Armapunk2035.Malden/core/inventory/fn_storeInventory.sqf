#include "..\..\macro.h"
// DECK ROUTE: see fn_takeInventory -- parameters in, same single copy of the logic.
// _deckMax: see fn_takeInventory's header. Same defect, same shape -- the physical branch's
// ceiling came from `lbValue[4503, lbCurSel 4503]` and collapsed to 0 off dialog 4500. Here
// the number is how many of this class the PLAYER holds (AP_fnc_physTally).
params [["_deckItem", "", [""]], ["_deckQty", "", [""]], ["_deckMax", -1, [0]]];
disableSerialization;
private _fromDeck = _deckItem isNotEqualTo "";
if (!_fromDeck && {(lbCurSel 4503) isEqualTo - 1}) exitWith {["You did not select anything.", "basic"] spawn AP_fnc_handleMessage;};
private _playerItemSelected = if (_fromDeck) then {_deckItem} else {getSelData(4503)};
private _quantity = if (_fromDeck) then {_deckQty} else {ctrlText 4506};
if (_playerItemSelected isEqualTo "") exitWith {["You did not select anything.", "basic"] spawn AP_fnc_handleMessage;};
if !([_quantity] call AP_fnc_isNumber) exitWith {["Invalid Number format", "basic"] spawn AP_fnc_handleMessage;};
private _itemWeight = getNumber(missionConfigFile >> "CfgWeights" >> _playerItemSelected >> "weight");
_quantity = parseNumber _quantity;
if (_quantity isEqualTo 0) exitWith {["You need to enter an amount to store!", "basic"] spawn AP_fnc_handleMessage;};
if (_quantity < 1) exitWith {["You can't enter anything below one!", "basic"] spawn AP_fnc_handleMessage;};
// LooneyBin 2026-06-11: worn gear (vest/uniform/backpack/headgear/goggles) + weapons aren't in CfgWeights, so
// _itemWeight is 0 and the old guard wrongly blocked storing them ("This item cannot be stored" -- e.g. an
// equipped vest). Exempt the player's actual worn gear + weapons; the 0-weight block still catches non-storables.
// owner 2026-06-18 (#369: "can't store DMS scope in house"): a LOOSE weapon attachment (optic_DMS etc.) has
// no CfgWeights entry -> _itemWeight 0, and it's not worn gear -> the guard wrongly blocked it. Exempt any
// valid CfgWeapons class (weapons + attachments: optics/pointers/muzzles/bipods); the store logic's default
// case handles them. The 0-weight block still catches genuine non-storables (no CfgWeapons class).
// owner 2026-07-02 (#581: "can't store PMCL/launcher missiles"): a launcher missile magazine (Titan_AT,
// Titan_AP -- no Config_physWeights entry, so _itemWeight 0) lives in CfgMagazines, not CfgWeapons, so the
// #369 exemption missed it and the guard wrongly blocked it. Exempt any valid CfgMagazines class too; the
// switch's itemsWithMagazines default case handles the removeItem. The 0-weight block still catches genuine
// non-storables (no CfgWeights/CfgWeapons/CfgMagazines class).
if (!AP_is_virtual && _itemWeight isEqualTo 0 && !(_playerItemSelected in [uniform player, vest player, backpack player, headgear player, goggles player, primaryWeapon player, secondaryWeapon player, handgunWeapon player]) && !(isClass (configFile >> "CfgWeapons" >> _playerItemSelected)) && !(isClass (configFile >> "CfgMagazines" >> _playerItemSelected))) exitWith {
    ["This item cannot be stored.", "basic"] spawn AP_fnc_handleMessage};
if ((_playerItemSelected in ["goldbar"]) && AP_trunk_vehicle isKindOf "Air") exitWith {
    ["This is too heavy for safe air transport!", "basic"] spawn AP_fnc_handleMessage;};
if ((_playerItemSelected in ["uraniumu", "uraniump"]) && !(AP_trunk_vehicle isKindOf "House_F") && !((typeOf AP_trunk_vehicle) in ["B_Truck_01_box_F", "C_Van_01_box_F"])) exitWith {
    ["This needs a HEMTT Box or Box Truck to safely transport!", "basic"] spawn AP_fnc_handleMessage;};
if (_playerItemSelected in ["uraniumu"] && AP_trunk_vehicle isKindOf "House_F") exitWith {
    ["The unrefined uranium is too radioactive for your house! Process it into Uranium (Weapon Grade) first."] spawn AP_fnc_handleMessage;
};
if ((_playerItemSelected in ["goldbar", "bank_money"]) && AP_trunk_vehicle isKindOf "House_F") exitWith {
    ["You can't fit this in your house!", "basic"] spawn AP_fnc_handleMessage;};
if ((_playerItemSelected in ["glitter", "glitterbase"]) && AP_trunk_vehicle isKindOf "House_F") exitWith {
    ["This item is too dangerous to store in your home!", "basic"] spawn AP_fnc_handleMessage;};
if (AP_trunk_vehicle getVariable["AP_questloot", false]) exitWith {
    ["This crate is only intended for you to take your items!", "basic"] spawn AP_fnc_handleMessage;};
if ((_playerItemSelected in ["jewelHope", "jewelRolex", "jewelAP", "jewelDiamonds", "jewelGoldBag", "jewelExoJewels", "jewelRing", "jewelBling", "jewelBag"]) && AP_trunk_vehicle isKindOf "House_F") exitWith {
    ["The African Warlord's henchmen will not allow you to store this!!"] spawn AP_fnc_handleMessage;};
if ((_playerItemSelected in ["jewelHope", "jewelRolex", "jewelAP", "jewelDiamonds", "jewelGoldBag", "jewelExoJewels", "jewelRing", "jewelBling", "jewelBag"]) && AP_trunk_vehicle isKindOf "Air") exitWith {
    ["This is too heavy for safe air transport!", "basic"] spawn AP_fnc_handleMessage;};
private _vehPos = getPos AP_trunk_vehicle;
private _playerPos = getPos player;
// owner 2026-07-03: skip the range check when you're INSIDE the vehicle, and make the on-foot reach
// size-aware. A big airframe (Blackfish) puts the pilot/edge >10m from the vehicle CENTER, which wrongly
// tripped "too far away". sizeOf ~ the model's bounding diameter, so 0.5*sizeOf ~ its radius.
if ((vehicle player) isNotEqualTo AP_trunk_vehicle && {_vehPos distance _playerPos > (10 + 0.5 * (sizeOf typeOf AP_trunk_vehicle))}) exitWith {
    closeDialog 0;
    ["You are too far away!", "basic"] spawn AP_fnc_handleMessage;};
private _itemWeight = 0;
private _data = [[], 0];
AP_inventoryInteraction = true;
if (AP_is_virtual) then {_itemWeight = (["getItemWeight", _playerItemSelected] call AP_fnc_virtItemCfg) * _quantity;
    _data = AP_trunk_vehicle getVariable["AP_vinv", [[], 0]];
    private _inv = _data select 0;
    private _currentWeight = _data select 1;
    private _totalWeight = (AP_trunk_vehicle getVariable["AP_vcap", 100]);
    if (((_currentWeight + _itemWeight) > _totalWeight)) exitWith {
        ["The vehicle is either full or cannot hold that much.", "basic"] spawn AP_fnc_handleMessage;};
    private _uExit = false;
    if (_playerItemSelected isEqualTo "uraniump" && {AP_trunk_vehicle isKindOf "House_F"}) then {
        private _index = ["uraniump", _inv] call AP_fnc_index;
        if !(_index isEqualTo - 1) then {private _uraniumCount = (_inv select _index) select 1;
            if ((_uraniumCount + _quantity > 50) && !(AP_trunk_vehicle getVariable["AP_leadcontainer_unaged", false])) then {
                _uExit = true;};};};
    if (_uExit) exitWith {if !(AP_trunk_vehicle getVariable["AP_leadcontainer_unaged", false]) then {
            ["Your home is either full or cannot hold that much uranium. Consider buying a lead container to hold more than 50 uranium!", "basic"] spawn AP_fnc_handleMessage;
        } else {["Your home is either full or cannot hold that much uranium.", "basic"] spawn AP_fnc_handleMessage;};};
    if (!([false, _playerItemSelected, _quantity] call AP_fnc_handleInv) && !(AP_adminForce)) exitWith {
        ["Couldn't remove the items from your inventory to put in the vehicle.", "basic"] spawn AP_fnc_handleMessage;};
    private _index = [_playerItemSelected, _inv] call AP_fnc_index;
    if (_index isEqualTo - 1) then {_inv pushBack[_playerItemSelected, _quantity];} else {private _val = _inv select _index select 1;
        _inv set[_index, [_playerItemSelected, _val + _quantity]];};
    AP_trunk_vehicle setVariable["AP_vinv", [_inv, (_currentWeight) + _itemWeight], true];
    if !(AP_adminForce) then {[AP_trunk_vehicle, AP_is_virtual] call AP_fnc_refreshInventory;} else {
        [AP_trunk_vehicle, true] call AP_fnc_refreshAdminInventory;};
    // suite crate is client-local: persist it AFTER the gear that lost the item (fn_suiteStorageSync)
    [true] call AP_fnc_saveGear;
    [] call AP_fnc_suiteStorageSync;} else {_itemWeight = getNumber(missionConfigFile >> "CfgWeights" >> (_playerItemSelected) >> "weight");
    _data = AP_trunk_vehicle getVariable["AP_pinv", [[], 0]];
    private _inv = _data select 0;
    private _totalWeight = (AP_trunk_vehicle getVariable["AP_phys_cap", 100]);
    private _currentWeight = _data select 1;
    private _combinedWeight = _itemWeight;
    private _tempItem = "";
    private _index = -1;
    private _maxValue = if (_fromDeck && {_deckMax >= 0}) then { _deckMax } else { lbValue[4503, (lbCurSel 4503)] };
    if (_quantity > _maxValue) then {_quantity = _maxValue};
    private _fnc_adjustArray = {params["_item", "_array"];
        if !(_item isEqualTo "") then {private _index = -1; {if !(_index isEqualTo - 1) exitWith {};
                if (_item isEqualTo(_x select 0)) exitWith {_index = _forEachIndex;};}
            forEach _array;
            if (_index isEqualTo - 1) then {_array pushBack[_item, 1];} else {
                _array set[_index, [_item, ((_array select _index) select 1) + 1]];};};
        _array;};
    if !(AP_adminForce) then {for "_i"
        from 1 to _quantity do {switch (true) do {
                case (_playerItemSelected isEqualTo(primaryWeapon player) && !(_playerItemSelected in (items player))): {{
                            if !(_x isEqualTo "") then {
                                _combinedWeight = _combinedWeight + getNumber(missionConfigFile >> "CfgWeights" >> (_x) >> "weight");};}
                        forEach(primaryWeaponItems player); {if !(_x isEqualTo "") then {
                                _combinedWeight = _combinedWeight + getNumber(missionConfigFile >> "CfgWeights" >> (_x) >> "weight");};}
                        forEach(primaryWeaponMagazine player);
                        if ((_currentWeight + _combinedWeight) > _totalWeight) exitWith {
                            ["The vehicle is either full or cannot hold that much.", "basic"] spawn AP_fnc_handleMessage;}; {
                            // owner 2026-06-19 (#328/#341): store the bipod TOO. It was skipped here while
                            // removeWeaponGlobal below still pulled the whole gun (bipod included) -> bipod lost.
                            _inv = [_x, _inv] call _fnc_adjustArray;}
                        forEach(primaryWeaponItems player); {_inv = [_x, _inv] call _fnc_adjustArray;}
                        forEach(primaryWeaponMagazine player);
                        _inv = [_playerItemSelected, _inv] call _fnc_adjustArray;
                        player removeWeaponGlobal _playerItemSelected;};
                case ((_playerItemSelected in (primaryWeaponItems player)) || (_playerItemSelected in (primaryWeaponMagazine player))): {
                        if ((_currentWeight + _combinedWeight) > _totalWeight) exitWith {
                            ["The vehicle is either full or cannot hold that much.", "basic"] spawn AP_fnc_handleMessage;};
                        _inv = [_playerItemSelected, _inv] call _fnc_adjustArray;
                        player removePrimaryWeaponItem _playerItemSelected;};
                case (_playerItemSelected isEqualTo(secondaryWeapon player)): {{if !(_x isEqualTo "") then {
                                _combinedWeight = _combinedWeight + getNumber(missionConfigFile >> "CfgWeights" >> (_x) >> "weight");};}
                        forEach(secondaryWeaponItems player); {if !(_x isEqualTo "") then {
                                _combinedWeight = _combinedWeight + getNumber(missionConfigFile >> "CfgWeights" >> (_x) >> "weight");};}
                        forEach(secondaryWeaponMagazine player);
                        if ((_currentWeight + _combinedWeight) > _totalWeight) exitWith {
                            ["The vehicle is either full or cannot hold that much.", "basic"] spawn AP_fnc_handleMessage;}; {
                            _inv = [_x, _inv] call _fnc_adjustArray;}
                        forEach(secondaryWeaponItems player); {_inv = [_x, _inv] call _fnc_adjustArray;}
                        forEach(secondaryWeaponMagazine player);
                        _inv = [_playerItemSelected, _inv] call _fnc_adjustArray;
                        player removeWeaponGlobal _playerItemSelected;};
                case ((_playerItemSelected in (secondaryWeaponItems player)) || (_playerItemSelected in (secondaryWeaponMagazine player))):
                    {if ((_currentWeight + _combinedWeight) > _totalWeight) exitWith {
                            ["The vehicle is either full or cannot hold that much.", "basic"] spawn AP_fnc_handleMessage;};
                        _inv = [_playerItemSelected, _inv] call _fnc_adjustArray;
                        player removeSecondaryWeaponItem _playerItemSelected;};
                case (_playerItemSelected isEqualTo(handgunWeapon player)): {{if !(_x isEqualTo "") then {
                                _combinedWeight = _combinedWeight + getNumber(missionConfigFile >> "CfgWeights" >> (_x) >> "weight");};}
                        forEach(handgunItems player); {if !(_x isEqualTo "") then {
                                _combinedWeight = _combinedWeight + getNumber(missionConfigFile >> "CfgWeights" >> (_x) >> "weight");};}
                        forEach(handgunMagazine player);
                        if ((_currentWeight + _combinedWeight) > _totalWeight) exitWith {
                            ["The vehicle is either full or cannot hold that much.", "basic"] spawn AP_fnc_handleMessage;}; {
                            _inv = [_x, _inv] call _fnc_adjustArray;}
                        forEach(handgunItems player); {_inv = [_x, _inv] call _fnc_adjustArray;}
                        forEach(handgunMagazine player);
                        _inv = [_playerItemSelected, _inv] call _fnc_adjustArray;
                        player removeWeaponGlobal _playerItemSelected;};
                case ((_playerItemSelected in (handgunItems player)) || (_playerItemSelected in (handgunMagazine player))): {
                        if ((_currentWeight + _combinedWeight) > _totalWeight) exitWith {
                            ["The vehicle is either full or cannot hold that much.", "basic"] spawn AP_fnc_handleMessage;};
                        _inv = [_playerItemSelected, _inv] call _fnc_adjustArray;
                        player removeHandgunItem _playerItemSelected;};
                case (_playerItemSelected isEqualTo(headgear player)): {if ((_currentWeight + _combinedWeight) > _totalWeight) exitWith {
                            ["The vehicle is either full or cannot hold that much.", "basic"] spawn AP_fnc_handleMessage;};
                        _inv = [_playerItemSelected, _inv] call _fnc_adjustArray;
                        removeHeadgear player;};
                case (_playerItemSelected isEqualTo(goggles player)): {if ((_currentWeight + _combinedWeight) > _totalWeight) exitWith {
                            ["The vehicle is either full or cannot hold that much.", "basic"] spawn AP_fnc_handleMessage;};
                        _inv = [_playerItemSelected, _inv] call _fnc_adjustArray;
                        removeGoggles player;};
                case (_playerItemSelected in (assignedItems player)): {if ((_currentWeight + _combinedWeight) > _totalWeight) exitWith {
                            ["The vehicle is either full or cannot hold that much.", "basic"] spawn AP_fnc_handleMessage;};
                        _inv = [_playerItemSelected, _inv] call _fnc_adjustArray;
                        if (_playerItemSelected in ["Binocular", "Rangefinder"]) then {player removeWeapon _playerItemSelected;} else {
                            player unassignItem _playerItemSelected;
                            player removeItem _playerItemSelected;};};
                case (_playerItemSelected isEqualTo(uniform player)): {private _uniformItems = uniformItems player;
                        if (count _uniformItems > 0) then {{
                                _combinedWeight = _combinedWeight + getNumber(missionConfigFile >> "CfgWeights" >> (_x) >> "weight");}
                            forEach _uniformItems;};
                        if ((_currentWeight + _combinedWeight) > _totalWeight) exitWith {
                            ["The vehicle is either full or cannot hold that much.", "basic"] spawn AP_fnc_handleMessage;};
                        if (count _uniformItems > 0) then {{_inv = [_x, _inv] call _fnc_adjustArray;}
                            forEach _uniformItems;};
                        _inv = [_playerItemSelected, _inv] call _fnc_adjustArray;
                        removeUniform player;};
                case (_playerItemSelected isEqualTo(vest player)): {private _vestItems = vestItems player;
                        if (count _vestItems > 0) then {{
                                _combinedWeight = _combinedWeight + getNumber(missionConfigFile >> "CfgWeights" >> (_x) >> "weight");}
                            forEach _vestItems;};
                        if ((_currentWeight + _combinedWeight) > _totalWeight) exitWith {
                            ["The vehicle is either full or cannot hold that much.", "basic"] spawn AP_fnc_handleMessage;};
                        if (count _vestItems > 0) then {{_inv = [_x, _inv] call _fnc_adjustArray;}
                            forEach _vestItems;};
                        _inv = [_playerItemSelected, _inv] call _fnc_adjustArray;
                        removeVest player;};
                case (_playerItemSelected isEqualTo(backpack player)): {private _backpackItems = backpackItems player;
                        // owner 2026-06-14: backpackItems EXCLUDES weapons, but removeBackpackGlobal (below)
                        // deletes the bag AND its weapon cargo -> storing a backpack with a weapon in it (e.g.
                        // an ADR) DESTROYED the weapon. Flatten each cargo weapon + attachments + loaded mags
                        // (disjoint from backpackItems' loose items) so they store with the bag instead.
                        {
                            _x params [["_wpn", ""], ["_acc1", ""], ["_acc2", ""], ["_acc3", ""], ["_wmag1", []], ["_wmag2", []], ["_acc4", ""]];
                            if (_wpn isEqualType "" && {_wpn != ""}) then { _backpackItems pushBack _wpn; };
                            { if (_x isEqualType "" && {_x != ""}) then { _backpackItems pushBack _x; }; } forEach [_acc1, _acc2, _acc3, _acc4];
                            if (_wmag1 isEqualType [] && {count _wmag1 > 0} && {(_wmag1 select 0) isEqualType ""}) then { _backpackItems pushBack (_wmag1 select 0); };
                            if (_wmag2 isEqualType [] && {count _wmag2 > 0} && {(_wmag2 select 0) isEqualType ""}) then { _backpackItems pushBack (_wmag2 select 0); };
                        } forEach (weaponsItemsCargo (unitBackpack player));
                        if (count _backpackItems > 0) then {{
                                _combinedWeight = _combinedWeight + getNumber(missionConfigFile >> "CfgWeights" >> (_x) >> "weight");}
                            forEach _backpackItems;};
                        if ((_currentWeight + _combinedWeight) > _totalWeight) exitWith {
                            ["The vehicle is either full or cannot hold that much.", "basic"] spawn AP_fnc_handleMessage;};
                        if (count _backpackItems > 0) then {{_inv = [_x, _inv] call _fnc_adjustArray;}
                            forEach _backpackItems;};
                        _inv = [_playerItemSelected, _inv] call _fnc_adjustArray;
                        removeBackpackGlobal player;};
                default {if !(_playerItemSelected in (itemsWithMagazines player)) exitWith {};
                    if ((_currentWeight + _combinedWeight) > _totalWeight) exitWith {
                        ["The vehicle is either full or cannot hold that much.", "basic"] spawn AP_fnc_handleMessage;};
                    _inv = [_playerItemSelected, _inv] call _fnc_adjustArray;
                    player removeItem _playerItemSelected;};};};} else {if ((call AP_adminLevel) <= 2) exitWith {closeDialog 0;};
        for "_i"
        from 1 to _quantity do {_inv = [_playerItemSelected, _inv] call _fnc_adjustArray;};};
    private _finalWeight = _inv call AP_fnc_physicalInventoryWeight;
    AP_trunk_vehicle setVariable["AP_pinv", [_inv, _finalWeight], true];
    // owner 2026-06-16 (#288 DISCONNECT-DUPE, CLANKR HIGH): persist the player's gear NOW that the physical
    // item was `player removeItem`'d above. The VIRTUAL-item branch already saveGear's (~line 107) but this
    // PHYSICAL branch did not -> the DB *_gear row still held the just-stored item, so "store physical item
    // -> alt+F4 -> reconnect" gave it back WHILE the container kept its copy (AP_pinv is global + the
    // disconnect handler force-saves it) = dupe. Mirror fn_onPutItem's proven physical-store save (side-aware
    // via ClupdatePartial mode 3, so vehicle-trunk stores by cops/medics are covered too).
    [false] call AP_fnc_saveGear;
    [3] call AP_fnc_ClupdatePartial;
    [] call AP_fnc_suiteStorageSync;   // suite crate is client-local: persist it AFTER the gear that lost the item
    if !(AP_adminForce) then {[AP_trunk_vehicle, AP_is_virtual] call AP_fnc_refreshInventory;} else {
        [AP_trunk_vehicle, false] call AP_fnc_refreshAdminInventory;};};