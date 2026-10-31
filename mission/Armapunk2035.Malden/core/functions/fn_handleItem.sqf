private["_items", "_isgun"];
params["_item", ["_bool", false, [false]], ["_ispack", false, [false]], ["_ongun", false, [false]], ["_override", false, [false]]];
private _customTexture = "";
if (isNil "_item") exitWith {};
private _ammo = 0;
if (_item isEqualType[]) then {_ammo = _item select 1;
    _item = _item select 0};
private _left = [_item, 1] call KRON_StrLeft;
if (_left == "[") then {if (_item isEqualType "") then {_item = parseSimpleArray _item;};
    if (!isNil {_item select 3}) then {_customTexture = _item select 3;};
    _item = _item select 0;};
private _isgun = false;
private _details = [_item] call AP_fnc_fetchCfgDetails;
if (_details isEqualTo[]) exitWith {};
if (_bool) then {switch ((_details select 6)) do {case "CfgGlasses": {if (_ispack) then {
                    (unitBackpack player) addItemCargoGlobal[_item, 1];} else {if (_override) then {player addItem _item;} else {
                        if (goggles player != "") then {removeGoggles player;};
                        player addGoggles _item;};};}; case "CfgVehicles": {if (backpack player != "") then {
                        _items = (backpackItems player);
                        removeBackpack player;};
                    player addBackpack _item;
                    clearAllItemsFromBackpack player;
                    if (_customTexture != "") then {[backpack player, "setBackpack", ""] call AP_fnc_clothingTextures;};
                    if (!isNil {_items}) then {{[_x, true, true, false, true] spawn AP_fnc_handleItem;}
                        forEach _items;};};
            case "CfgMagazines": {if (_ispack) then {(unitBackpack player) addMagazineCargoGlobal[_item, 1];} else {if (_ammo > 0) then {
                            player addMagazine[_item, _ammo];} else {player addMagazine _item;};};};
            case "CfgWeapons": {if ((_details select 4) in [1, 2, 4, 5, 4096]) then {if ((_details select 4) isEqualTo 4096) then {
                            if ((_details select 5) isEqualTo - 1) then {_isgun = true;};} else {_isgun = true;};};
                    if (_isgun) then {if (!_ispack && _override) exitWith {};
                        if (_item == "MineDetector") then {player addItem _item;} else {if (_ispack) then {
                                if (backpack player != "") then {(unitBackpack player) addWeaponCargoGlobal[_item, 1];};} else {
                                player addWeapon _item;
                                if ("bipod" in ((primaryWeaponItems player) select 3)) then {
                                    player removePrimaryWeaponItem((primaryWeaponItems player) select 3)};};};} else {
                        switch (_details select 5) do {case 0: {if (_ispack) then {(unitBackpack player) addItemCargoGlobal[_item, 1];
                                    } else {if (_override) then {player addItem _item;} else {if (_item in (assignedItems player)) then {
                                                player addItem _item;} else {player addItem _item;
                                                player assignItem _item;};};};};
                            case 605: {if (_ispack) then {(unitBackpack player) addItemCargoGlobal[_item, 1];} else {if (_override) then {
                                            player addItem _item;} else {if (headGear player == _item) then {} else {
                                                if (headGear player != "") then {removeHeadGear player;};
                                                player addHeadGear _item;};};};};
                            case 801: {if (_ispack) then {(unitBackpack player) addItemCargoGlobal[_item, 1];} else {if (_override) then {
                                            player addItem _item;} else {if (uniform player == _item) then {} else {
                                                if (uniform player != "") then {_items = uniformItems player;
                                                    removeUniform player;};
                                                player forceAddUniform _item;
                                                if (_customTexture != "") then {
                                                    [uniform player, "setUniform", ""] call AP_fnc_clothingTextures;} else {if !(isNil {
                                                        player getVariable["AP_customTexture", nil]}) then {
                                                        player setVariable["AP_customTexture", nil, true]};};
                                                if (!isNil {_items}) then {{[_x, true, false, false, true] spawn AP_fnc_handleItem;}
                                                    forEach _items;};};};};};
                            case 701: {if (_ispack) then {(unitBackpack player) addItemCargoGlobal[_item, 1];} else {if (_override) then {
                                            player addItem _item;} else {if (vest player == _item) then {} else {
                                                if (vest player != "") then {_items = vestItems player;
                                                    removeVest player;};
                                                player addVest _item;
                                                if (!isNil {_items}) then {{[_x, true, false, false, true] spawn AP_fnc_handleItem;}
                                                    forEach _items;};};};};};
                            case 201: {if (_ispack) then {(unitBackpack player) addItemCargoGlobal[_item, 1];} else {private["_type"];
                                        _type = [_item, 201] call AP_fnc_accType;
                                        if (_ongun) then {switch (_type) do {case 1: {player addPrimaryWeaponItem _item;};
                                                case 2: {player addSecondaryWeaponItem _item;};
                                                case 3: {player addHandgunItem _item;};
                                                default {
                                                        player addItem _item;   // owner 2026-07-04 (#339): no compatible equipped weapon -> keep the accessory in inventory instead of losing it
                                                    };};} else {if (_override) then {player addItem _item;} else {
                                                createDialog "VAS_prompt";
                                                waitUntil {!isNil {vas_prompt_choice}};
                                                if (vas_prompt_choice) then {switch (_type) do {case 1: {player addPrimaryWeaponItem _item;
                                                            };
                                                        case 2: {player addSecondaryWeaponItem _item;};
                                                        case 3: {player addHandgunItem _item;};};} else {player addItem _item;};
                                                vas_prompt_choice = nil;};};};};
                            case 301: {if (_ispack) then {(unitBackpack player) addItemCargoGlobal[_item, 1];} else {private["_type"];
                                        _type = [_item, 301] call AP_fnc_accType;
                                        if (_ongun) then {switch (_type) do {case 1: {player addPrimaryWeaponItem _item;};
                                                case 2: {player addSecondaryWeaponItem _item;};
                                                case 3: {player addHandgunItem _item;};
                                                default {
                                                        player addItem _item;   // owner 2026-07-04 (#339): no compatible equipped weapon -> keep the accessory in inventory instead of losing it
                                                    };};} else {if (_override) then {player addItem _item;} else {
                                                createDialog "VAS_prompt";
                                                waitUntil {!isNil {vas_prompt_choice}};
                                                if (vas_prompt_choice) then {switch (_type) do {case 1: {player addPrimaryWeaponItem _item;
                                                            };
                                                        case 2: {player addSecondaryWeaponItem _item;};
                                                        case 3: {player addHandgunItem _item;};};} else {player addItem _item;};
                                                vas_prompt_choice = nil;};};};};
                            case 101: {if (_ispack) then {(unitBackpack player) addItemCargoGlobal[_item, 1];} else {private["_type"];
                                        _type = [_item, 101] call AP_fnc_accType;
                                        if (_ongun) then {switch (_type) do {case 1: {player addPrimaryWeaponItem _item;};
                                                case 2: {player addSecondaryWeaponItem _item;};
                                                case 3: {player addHandgunItem _item;};
                                                default {
                                                        player addItem _item;   // owner 2026-07-04 (#339): no compatible equipped weapon -> keep the accessory in inventory instead of losing it
                                                    };};} else {if (_override) then {player addItem _item;} else {
                                                createDialog "VAS_prompt";
                                                waitUntil {!isNil {vas_prompt_choice}};
                                                if (vas_prompt_choice) then {switch (_type) do {case 1: {player addPrimaryWeaponItem _item;
                                                            };
                                                        case 2: {player addSecondaryWeaponItem _item;};
                                                        case 3: {player addHandgunItem _item;};};} else {player addItem _item;};
                                                vas_prompt_choice = nil;};};};};
                            case 621: {if (_ispack) then {(unitBackpack player) addItemCargoGlobal[_item, 1];} else {if (_override) then {
                                            player addItem _item;} else {player addItem _item;
                                            player assignItem _item;};};};
                            case 616: {if (_ispack) then {(unitBackpack player) addItemCargoGlobal[_item, 1];} else {if (_override) then {
                                            player addItem _item;} else {player addItem _item;
                                            player assignItem _item;};};};
                            default {if (_ispack) then {(unitBackpack player) addItemCargoGlobal[_item, 1];} else {player addItem _item;};
                            };};};};};} else {switch ((_details select 6)) do {case "CfgVehicles": {removeBackpack player;
            }; case "CfgMagazines": {player removeMagazine _item;};
            case "CfgGlasses": {if (_item == goggles player) then {removeGoggles player;} else {player removeItem _item;};};
            case "CfgWeapons": {if ((_details select 4) in [1, 2, 4, 5, 4096]) then {if ((_details select 4) isEqualTo 4096) then {
                            if ((_details select 5) isEqualTo - 1) then {_isgun = true;};} else {_isgun = true;};};
                    if (_isgun) then {switch (true) do {case (primaryWeapon player == _item): {_ispack = false;};
                            case (secondaryWeapon player == _item): {_ispack = false;};
                            case (handGunweapon player == _item): {_ispack = false;};
                            case (_item in assignedItems player): {_ispack = false;};
                            default {_ispack = true;};}; if (_item == "MineDetector") then {player removeItem _item;} else {
                            if (_ispack) then {_items = (backpackItems player);
                                _index = _items find _item;
                                if (_index != -1) then {_items set[_index, -1];
                                    _items = _items - [-1];};
                                clearWeaponCargo(unitBackpack player);
                                if (count _items > 0) then {{[_x, true, true, false, false] spawn AP_fnc_handleItem;}
                                    forEach _items;};} else {player removeWeapon _item;};};} else {switch ((_details select 5)) do {case 0:
                                {player unassignItem _item;
                                    player removeItem _item;};
                            case 605: {if (headGear player == _item) then {removeHeadgear player} else {player removeItem _item};};
                            case 801: {if (uniform player == _item) then {removeUniform player} else {player removeItem _item};};
                            case 701: {if (vest player == _item) then {removeVest player} else {player removeItem _item};};
                            case 621: {player unassignItem _item;
                                    player removeItem _item;};
                            case 616: {player unassignItem _item;
                                    player removeItem _item;};
                            default {switch (true) do {case (_item in (primaryWeaponItems player)): {player removePrimaryWeaponItem _item;
                                        };
                                    case (_item in (handgunItems player)): {player removeHandgunItem _item;};
                                    default {player removeItem _item;};};};};};};};};