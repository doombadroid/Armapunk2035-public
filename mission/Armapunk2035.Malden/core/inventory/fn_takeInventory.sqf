#include "..\..\macro.h"
// DECK ROUTE (UI overhaul 2026-08-26): the deck TRUNK app passes item + qty as
// parameters; the native dialog path still reads its own controls. One copy of
// the transfer logic -- this is CLANKR's most-watched surface and a second copy
// is how dupes are born.
// _deckMax: the caller's own ceiling for a PHYSICAL take -- how many of this class the
// container actually holds. The physical branch below used to read that from TrunkMenu's
// listbox (`lbValue[4502, lbCurSel 4502]`, the value fn_refreshInventory:192 writes), which
// only exists while dialog 4500 is open. Off that dialog the read yields 0, the clamp below
// sets _quantity to 0, and `for "_i" from 1 to 0` runs ZERO iterations -- so every physical
// take through the deck app and the web STORAGE screen was a silent no-op. -1 means "no
// ceiling supplied": a caller that has not been updated keeps the old listbox read and the
// old behaviour exactly, rather than newly clamping itself to -1.
params [["_deckItem", "", [""]], ["_deckQty", "", [""]], ["_deckMax", -1, [0]]];
private["_diff", "_mods", "_trunk", "_itemClass"];
disableSerialization;
if (isNull AP_trunk_vehicle OR!alive AP_trunk_vehicle) exitWith {};
if (!alive player) exitwith {if (isNull (findDisplay 937500)) then {closeDialog 0;};};
private _fromDeck = _deckItem isNotEqualTo "";
if (!_fromDeck && {(lbCurSel 4502) == -1}) exitWith {["You did not select anything.", "basic"] spawn AP_fnc_handleMessage;};
private _fnc_updatePhysicalTrunk = {params["_trunkObj", "_items"];
    private _weight = _items call AP_fnc_physicalInventoryWeight;
    _trunkObj setVariable["AP_pinv", [_items, _weight], true];};
private _trunkItemSelected = if (_fromDeck) then {_deckItem} else {getSelData(4502)};
private _quantity = if (_fromDeck) then {_deckQty} else {ctrlText 4505};
if (_trunkItemSelected isEqualTo "") exitWith {["You didn't select anything.", "basic"] spawn AP_fnc_handleMessage;};
if !([_quantity] call AP_fnc_isNumber) exitWith {["Invalid Number format.", "basic"] spawn AP_fnc_handleMessage;};
_quantity = parseNumber _quantity;
if (_quantity isEqualTo 0) exitWith {["You need to enter an amount to take!", "basic"] spawn AP_fnc_handleMessage;};
if (_quantity < 1) exitWith {["You can't enter anything below one!", "basic"] spawn AP_fnc_handleMessage;};
private _vehPos = getPos AP_trunk_vehicle;
private _playerPos = getPos player;
// owner 2026-07-03: skip when INSIDE the vehicle + size-aware on-foot reach (big airframe -> pilot/edge
// >10m from CENTER wrongly tripped "too far away"). See fn_storeInventory.
if ((vehicle player) isNotEqualTo AP_trunk_vehicle && {_vehPos distance _playerPos > (10 + 0.5 * (sizeOf typeOf AP_trunk_vehicle))}) exitWith {
    closeDialog 0;
    ["You are too far away!", "basic"] spawn AP_fnc_handleMessage;};
AP_inventoryInteraction = true;
if (AP_is_virtual) then {
    private _index = [_trunkItemSelected, ((AP_trunk_vehicle getVariable "AP_vinv") select 0)] call AP_fnc_index;
    private _data = AP_trunk_vehicle getVariable["AP_vinv", [[], 0]];
    private _inv = _data select 0;
    private _currentWeight = _data select 1;
    if (_index isEqualTo - 1) exitWith {};
    private _value = (_inv select _index) select 1;
    if (_quantity > _value) exitWith {["You don't have enough to withdraw that amount.", "basic"] spawn AP_fnc_handleMessage;};
    _quantity = [_trunkItemSelected, _quantity, AP_carryWeight, AP_maxWeight] call AP_fnc_calWeightDiff;
    if (_quantity isEqualTo 0) exitWith {["Your inventory is full.", "basic"] spawn AP_fnc_handleMessage;};
    private _weight = (["getItemWeight", _trunkItemSelected] call AP_fnc_virtItemCfg) * _quantity;
    if (AP_effSide isEqualTo west && !(AP_adminForce) && (AP_trunk_vehicle isKindOf "House_F")) then {
        private _illegalItems = ["getIllegalItems"] call AP_fnc_virtItemCfg;
        private _illegalIndex = _illegalItems findIf {_trunkItemSelected in _x};
        if !(_illegalIndex isEqualTo - 1) then {private _nearestVehicles = nearestObjects[_vehPos, ["Car", "Air", "Ship"], 30];
            private _nearestVehicle = _nearestVehicles param[_nearestVehicles findIf {_x getVariable["AP_side", ""] isEqualTo "cop"
            }, objNull];
            if (isNull _nearestVehicle) exitWith {
                ["There aren't any nearby Police vehicles to seize this house's illegal items into!", "basic"] spawn AP_fnc_handleMessage;
            };
            if !(alive _nearestVehicle) exitWith {
                ["You cannot seize items into a vehicle which has been destroyed!", "basic"] spawn AP_fnc_handleMessage;};
            (_nearestVehicle getVariable["AP_vinv", [[], 0]]) params["_carItems", "_carWeight"];
            private _illegalReward = _value * ((_illegalItems select _illegalIndex) select 1);
            private _copCarItemIdx = _carItems findIf {_trunkItemSelected in _x};
            if !(_copCarItemIdx isEqualTo - 1) then {private _oldValue = (_carItems select _copCarItemIdx) select 1;
                (_carItems select _copCarItemIdx) set[1, _oldValue + _value];} else {_carItems pushBack[_trunkItemSelected, _value];};
            _carWeight = _carWeight + (_value * (["getItemWeight", _trunkItemSelected] call AP_fnc_virtItemCfg));
            _nearestVehicle setVariable["AP_vinv", [_carItems, _carWeight], true];
            _inv deleteAt _index; [
                [0, format["Illegal items from a house were seized by %1%2 and $%3 worth of drugs / contraband were taken into police custody.", "MaxSec Officer ", profileName, [_illegalReward] call AP_fnc_numberText]], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
            titleText["The illegal items were seized into the nearest police vehicle. The items can be placed into evidence from any Police HQ.", "PLAIN"];
            private _newWeight = _currentWeight - (_value * (["getItemWeight", _trunkItemSelected] call AP_fnc_virtItemCfg));
            if (_newWeight < 0) then {_newWeight = 0};
            AP_trunk_vehicle setVariable["AP_vinv", [_inv, _newWeight], true];
            [AP_trunk_vehicle, AP_is_virtual] call AP_fnc_refreshInventory;} else {
            [format["This is not an illegal item, no need to seize this!"], "basic"] spawn AP_fnc_handleMessage;};} else {
        if ([true, _trunkItemSelected, _quantity] call AP_fnc_handleInv) then {if (_quantity == _value) then {_inv set[_index, -1];
                _inv = _inv - [-1];} else {_inv set[_index, [_trunkItemSelected, (_value - _quantity)]];};
            private _newWeight = _currentWeight - _weight;
            if (_newWeight < 0) then {_newWeight = 0;};
            AP_trunk_vehicle setVariable["AP_vinv", [_inv, _newWeight], true];
            // Suite: persist the crate, then the gear that now holds the item -- the two rows move together.
            if ([] call AP_fnc_suiteStorageSync) then {[false] call AP_fnc_saveGear; [3] call AP_fnc_ClupdatePartial;};
            [AP_trunk_vehicle, AP_is_virtual] call AP_fnc_refreshInventory;} else {
            ["Your inventory is full.", "basic"] spawn AP_fnc_handleMessage;};};} else {
    private _data = AP_trunk_vehicle getVariable["AP_pinv", [[], 0]];
    private _inv = _data select 0;
    private _currentWeight = _data select 1;
    private _weight = getNumber(missionConfigFile >> "CfgWeights" >> (_trunkItemSelected) >> "weight");
    _itemClass = ([_trunkItemSelected] call BIS_fnc_itemType) select 1;
    private _maxValue = if (_fromDeck && {_deckMax >= 0}) then { _deckMax } else { lbValue[4502, (lbCurSel 4502)] };
    if (AP_effSide isEqualTo west && (AP_trunk_vehicle isKindOf "House_F")) then {_quantity = 1;};
    private _pilotHelms = ["H_PilotHelmetFighter_B", "H_PilotHelmetFighter_O", "H_PilotHelmetFighter_I"];
    if (_quantity > _maxValue) then {_quantity = _maxValue};
    private _fnc_adjustArray = {params["_item", "_array"];
        private _index = -1; {if !(_index isEqualTo - 1) exitWith {};
            if (_item == (_x select 0)) exitWith {_index = _forEachIndex;};}
        forEach _array;
        if (_index isEqualTo - 1) exitWith {_array};
        if (((_array select _index) select 1) > 1) then {_array set[_index, [_item, ((_array select _index) select 1) - 1]];} else {
            _array set[_index, -1];};
        _array = _array - [-1];
        _array;};
    private _exit = false;
    for "_i"
    from 1 to _quantity do {if (_exit) exitWith {};
        switch (true) do {if (AP_effSide isEqualTo west && (AP_trunk_vehicle isKindOf "House_F")) then {private _itemCount = 1;
                private _index = -1; {if !(_index isEqualTo - 1) exitWith {};
                    if (_trunkItemSelected isEqualTo(_x select 0)) exitWith {_index = _forEachIndex;
                        _itemCount = (_x select 1);};}
                forEach _inv;
                if (_index isEqualTo - 1) exitWith {};
                _inv set[_index, -1];
                _inv = _inv - [-1];
                [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;} else {
                case (_trunkItemSelected isKindOf["Rifle", configFile >> "CfgWeapons"]): {if ((primaryWeapon player) isEqualTo "") then {
                            _inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                            [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;
                            player addWeapon _trunkItemSelected;
                            if ("bipod" in ((primaryWeaponItems player) select 3)) then {
                                player removePrimaryWeaponItem((primaryWeaponItems player) select 3)};} else {
                            if (player canAdd _trunkItemSelected) then {_inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                                [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;
                                player addItem _trunkItemSelected;} else {
                                ["You don't have enough space to hold that item!", "basic"] spawn AP_fnc_handleMessage;
                                _exit = true;};};};
                case (_trunkItemSelected isKindOf["Launcher", configFile >> "CfgWeapons"]): {
                        if ((secondaryWeapon player) isEqualTo "") then {_inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                            [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;
                            player addWeapon _trunkItemSelected;} else {if (player canAdd _trunkItemSelected) then {
                                _inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                                [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;
                                player addItem _trunkItemSelected;} else {
                                ["You don't have enough space to hold that item!", "basic"] spawn AP_fnc_handleMessage;
                                _exit = true;};};};
                case (_trunkItemSelected isKindOf["Pistol", configFile >> "CfgWeapons"]): {if ((handgunWeapon player) isEqualTo "") then {
                            _inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                            [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;
                            player addWeapon _trunkItemSelected;} else {if (player canAdd _trunkItemSelected) then {
                                _inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                                [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;
                                player addItem _trunkItemSelected;} else {
                                ["You don't have enough space to hold that item!", "basic"] spawn AP_fnc_handleMessage;
                                _exit = true;};};};
                case (_itemClass isEqualTo "Headgear"): {if ((headgear player) isEqualTo "") then {private _isNVG = false;
                            if ((!((hmd player) isEqualTo "")) && (_trunkItemSelected in _pilotHelms)) then {_isNVG = true;
                                if (player canAdd _trunkItemSelected) then {_inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                                    [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;
                                    player addItem _trunkItemSelected;} else {
                                    ["You don't have enough space to hold that item!", "basic"] spawn AP_fnc_handleMessage;
                                    _exit = true;};};
                            if (_isNVG) exitWith {};
                            _inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                            [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;
                            player addHeadgear _trunkItemSelected;} else {if (player canAdd _trunkItemSelected) then {
                                _inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                                [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;
                                player addItem _trunkItemSelected;} else {
                                ["You don't have enough space to hold that item!", "basic"] spawn AP_fnc_handleMessage;
                                _exit = true;};};};
                case (_itemClass isEqualTo "Glasses"): {if ((goggles player) isEqualTo "") then {
                            _inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                            [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;
                            player addGoggles _trunkItemSelected;} else {if (player canAdd _trunkItemSelected) then {
                                _inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                                [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;
                                player addItem _trunkItemSelected;} else {
                                ["You don't have enough space to hold that item!", "basic"] spawn AP_fnc_handleMessage;
                                _exit = true;};};};
                case (_itemClass isEqualTo "Vest"): {if ((vest player) isEqualTo "") then {
                            _inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                            [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;
                            player addVest _trunkItemSelected;} else {if (player canAdd _trunkItemSelected) then {
                                _inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                                [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;
                                player addItem _trunkItemSelected;} else {
                                ["You don't have enough space to hold that item!", "basic"] spawn AP_fnc_handleMessage;
                                _exit = true;};};};
                case (_itemClass isEqualTo "Backpack"): {if ((backpack player) isEqualTo "") then {
                            _inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                            [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;
                            player addBackpackGlobal _trunkItemSelected;} else {
                            // owner 2026-06-25 (#545 item LOSS -- bupkis: double-clicked 2 carryalls, one equipped,
                            // the other VANISHED): a player can only WEAR one backpack and a backpack CANNOT be stored
                            // as cargo (Arma doesn't nest backpacks). The old `addItem <backpack>` silently failed
                            // while the item was ALREADY removed from the container -> the 2nd backpack was lost.
                            // Reject it instead so it stays safely in the container.
                            ["You're already wearing a backpack -- you can't carry a second one.", "basic"] spawn AP_fnc_handleMessage;
                            _exit = true;};};
                case (_itemClass isEqualTo "Uniform"): {if ((uniform player) isEqualTo "") then {
                            _inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                            [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;
                            player addUniform _trunkItemSelected;} else {if (player canAdd _trunkItemSelected) then {
                                _inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                                [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;
                                player addItem _trunkItemSelected;} else {
                                ["You don't have enough space to hold that item!", "basic"] spawn AP_fnc_handleMessage;
                                _exit = true;};};};
                case (_itemClass isEqualTo "NVGoggles"): {if ((hmd player) isEqualTo "") then {private _isPilot = false;
                            if ((headgear player) in _pilotHelms) then {_isPilot = true;
                                if (player canAdd _trunkItemSelected) then {_inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                                    [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;
                                    player addItem _trunkItemSelected;} else {
                                    ["You don't have enough space to hold that item!", "basic"] spawn AP_fnc_handleMessage;
                                    _exit = true;};};
                            if (_isPilot) exitWith {};
                            _inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                            [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;
                            player addWeapon _trunkItemSelected;} else {if (player canAdd _trunkItemSelected) then {
                                _inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                                [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;
                                player addItem _trunkItemSelected;} else {
                                ["You don't have enough space to hold that item!", "basic"] spawn AP_fnc_handleMessage;
                                _exit = true;};};};
                default {private _magazineAdded = false;
                    if !(primaryWeapon player isEqualTo "") then {
                        private _weaponMagazines = getArray(configFile >> "cfgWeapons" >> primaryWeapon player >> "Magazines");
                        private _weaponItems = (primaryWeapon player) call BIS_fnc_compatibleItems;
                        if ((_trunkItemSelected in _weaponMagazines) && (count(primaryWeaponMagazine player) isEqualTo 0)) then {
                            _inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                            [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;
                            player addPrimaryWeaponItem _trunkItemSelected;
                            _magazineAdded = true;} else {private _canAttach = false; {if (_trunkItemSelected == _x) exitWith {
                                    _canAttach = true;};}
                            forEach _weaponItems;
                            if (_canAttach) then {switch (true) do {
                                    case ((["optic_", _trunkItemSelected] call BIS_fnc_inString) && (((primaryWeaponItems player) select 2) isEqualTo "")):
                                        {_inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                                            [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;
                                            player addPrimaryWeaponItem _trunkItemSelected;
                                            _magazineAdded = true;};
                                    case ((["acc_", _trunkItemSelected] call BIS_fnc_inString) && (((primaryWeaponItems player) select 1) isEqualTo "")):
                                        {_inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                                            [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;
                                            player addPrimaryWeaponItem _trunkItemSelected;
                                            _magazineAdded = true;};
                                    // owner 2026-06-19 (#328/#341/#339): re-attach bipods (slot 3) + muzzles/
                                    // suppressors (slot 0) on take -- the switch only handled optics + pointers, so a
                                    // stored bipod or suppressor never went back on the gun.
                                    case ((["bipod_", _trunkItemSelected] call BIS_fnc_inString) && (((primaryWeaponItems player) select 3) isEqualTo "")):
                                        {_inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                                            [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;
                                            player addPrimaryWeaponItem _trunkItemSelected;
                                            _magazineAdded = true;};
                                    case ((["muzzle_", _trunkItemSelected] call BIS_fnc_inString) && (((primaryWeaponItems player) select 0) isEqualTo "")):
                                        {_inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                                            [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;
                                            player addPrimaryWeaponItem _trunkItemSelected;
                                            _magazineAdded = true;};};};};};
                    if !(secondaryWeapon player isEqualTo "") then {
                        private _weaponMagazines = getArray(configFile >> "cfgWeapons" >> secondaryWeapon player >> "Magazines");
                        private _weaponItems = (secondaryWeapon player) call BIS_fnc_compatibleItems;
                        if (((_trunkItemSelected in _weaponMagazines) && (count(secondaryWeaponMagazine player) isEqualTo 0))) then {
                            _inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                            [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;
                            player addSecondaryWeaponItem _trunkItemSelected;
                            _magazineAdded = true;} else {private _canAttach = false; {if (_trunkItemSelected == _x) exitWith {
                                    _canAttach = true;};}
                            forEach _weaponItems;
                            if (_canAttach) then {switch (true) do {
                                    case ((["optic_", _trunkItemSelected] call BIS_fnc_inString) && (((secondaryWeaponItems player) select 2) isEqualTo "")):
                                        {_inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                                            [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;
                                            player addSecondaryWeaponItem _trunkItemSelected;
                                            _magazineAdded = true;};
                                    case ((["acc_", _trunkItemSelected] call BIS_fnc_inString) && (((secondaryWeaponItems player) select 1) isEqualTo "")):
                                        {_inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                                            [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;
                                            player addSecondaryWeaponItem _trunkItemSelected;
                                            _magazineAdded = true;};};};};};
                    if !(handgunWeapon player isEqualTo "") then {
                        private _weaponMagazines = getArray(configFile >> "cfgWeapons" >> handgunWeapon player >> "Magazines");
                        private _weaponItems = (handgunWeapon player) call BIS_fnc_compatibleItems;
                        if (((_trunkItemSelected in _weaponMagazines) && (count(handgunMagazine player) isEqualTo 0))) then {
                            _inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                            [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;
                            player addhandgunItem _trunkItemSelected;
                            _magazineAdded = true;} else {private _canAttach = false; {if (_trunkItemSelected == _x) exitWith {
                                    _canAttach = true;};}
                            forEach _weaponItems;
                            if (_canAttach) then {switch (true) do {
                                    case ((["optic_", _trunkItemSelected] call BIS_fnc_inString) && (((handGunItems player) select 2) isEqualTo "")):
                                        {_inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                                            [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;
                                            player addhandgunItem _trunkItemSelected;
                                            _magazineAdded = true;};
                                    case ((["acc_", _trunkItemSelected] call BIS_fnc_inString) && (((handGunItems player) select 1) isEqualTo "")):
                                        {_inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                                            [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;
                                            player addhandgunItem _trunkItemSelected;
                                            _magazineAdded = true;};};};};};
                    if !(_magazineAdded) then {if (player canAdd _trunkItemSelected) then {
                            // owner 2026-06-14: removed the "bipod" block. Bipods stored as a standalone item
                            // could be put INTO storage but never pulled back out ("You cannot use this item!")
                            // -- an old anti-dupe pairing. No longer needed; let bipods be retrieved like any item.
                            private _preInv = +_inv;
                            _inv = [_trunkItemSelected, _inv] call _fnc_adjustArray;
                            if (_preInv isEqualTo _inv) exitWith {_exit = true};
                            [AP_trunk_vehicle, _inv] call _fnc_updatePhysicalTrunk;
                            player addItem _trunkItemSelected;} else {
                            ["You don't have enough space to hold that item!", "basic"] spawn AP_fnc_handleMessage;
                            _exit = true;};};};};};};
    // 2026-09-05: persist the gear NOW that a physical item was added to the player above --
    // the exact mirror of the save fn_storeInventory's physical branch got for #288, which this
    // branch never received. Nothing saves a client's loadout server-side: the disconnect handler
    // (fn_playerDisconnected:106) force-persists the HOUSE post-take, but the player's <side>_gear
    // row is only ever written by the client. So "take physical item -> alt+F4 -> reconnect" left
    // the house row without the item and the gear row without it either = item LOSS, the mirror
    // image of #288's dupe, with the periodic gear PFH as the only thing closing the window.
    // [false] + an explicit mode 3 rather than [true]: fn_saveGear's own DB write is gated on
    // civilian-or-on-duty (fn_saveGear:57), and a cop taking gear out of a searched house must
    // persist too.
    // A suite crate is client-local, so that disconnect force-persist cannot reach it: write it first.
    [] call AP_fnc_suiteStorageSync;
    [false] call AP_fnc_saveGear;
    [3] call AP_fnc_ClupdatePartial;
    [ AP_trunk_vehicle , AP_is_virtual] call AP_fnc_refreshInventory;};