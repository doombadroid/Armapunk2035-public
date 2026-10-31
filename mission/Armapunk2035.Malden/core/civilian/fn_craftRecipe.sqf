disableSerialization;
if (isNull(findDisplay 1800)) exitWith {};
params[["_sell", true, [true]]];
private _className = lbData[1850, lbCurSel 1850];
private _recipe = [_className] call AP_fnc_recipeDetail;
private _762 = ["srifle_DMR_01_F", "srifle_EBR_F", "srifle_DMR_03_khaki_F", "srifle_DMR_03_multicam_F", "srifle_DMR_03_tan_F", "srifle_DMR_03_woodland_F", "srifle_DMR_06_olive_F", "srifle_DMR_06_camo_F", "arifle_SPAR_03_snd_F", "arifle_SPAR_03_khk_F", "arifle_AK12_F", "arifle_AKM_F"];
if (_classname in _762 and!(license_civ_rebel) && !(_sell)) exitWith {
    ["Crafting a 7.62mm rifle requires a rebel license.", "basic"] spawn AP_fnc_handleMessage};
if (_classname in ["B_MRAP_01_F", "arifle_MX_F", "arifle_MX_khk_F"] and!(license_civ_bounty) && !(_sell)) exitWith {
    ["Crafting this requires a bounty hunter license.", "basic"] spawn AP_fnc_handleMessage};
if ((AP_gang_data param[0, -3]) isEqualTo(panagia_flag getVariable["AP_turf_data", []] param[0, -2])) then {{
        _x params["_item", "_amount"];
        _x set[1, ceil(_amount * 0.75)];}
    forEach _recipe;};
private _isQuest491 = ((491 in AP_completedLifetimeQuests) && (_classname in ["B_MRAP_01_F", "O_MRAP_02_F"]));
private _isQuest492 = ((492 in AP_completedLifetimeQuests) && ((([_classname] call BIS_fnc_itemType) param[1, "Gun"]) in ["AssaultRifle", "Handgun", "Launcher", "MachineGun", "Shotgun", "SubmachineGun", "SniperRifle", "Rifle"]));
if (_isQuest491 || _isQuest492) then {{_x params["_item", "_amount"];
        private _toReduce =
        switch (true) do {case ((491 in AP_completedLifetimeQuests) && (_isQuest491)): {0.90};
            case ((492 in AP_completedLifetimeQuests) && (_isQuest492)): {0.90};
            default {1};}; _x set[1, ceil(_amount * _toReduce)];}
    forEach _recipe;};
private _isQuest490 = ((490 in AP_completedLifetimeQuests) && (_classname isKindOf "Air"));
if (_isQuest490) then {{_x params["_item", "_amount"];
        if (_item == "AP_cash") then {private _toReduce =
            switch (true) do {case ((490 in AP_completedLifetimeQuests) && (_isQuest490)): {0.90};
                default {1};}; _x set[1, ceil(_amount * _toReduce)];};}
    forEach _recipe;};
private _missingItem = !(_recipe findIf {(missionNamespace getVariable(_x select 0)) < (_x select 1)}
isEqualTo - 1);
if (_missingItem) exitWith {["You do not have the materials required to craft this item.", "basic"] spawn AP_fnc_handleMessage;};
private _cashRequired = (_recipe param[_recipe findIf {(_x select 0) isEqualTo "AP_cash"}, 0]) param[1, 0];
_cashRequired =
if ((490 in AP_completedLifetimeQuests) && (_className isKindOf "Air")) then {_cashRequired * 0.90} else {_cashRequired};
if (AP_cash < _cashRequired) exitWith {["You do not have enough cash to produce this item.", "basic"] spawn AP_fnc_handleMessage};
if (isClass(configFile >> "CfgMagazines" >> _className) && {!(player canAdd _className)}) exitWith {
    ["You don't have enough room for this.", "basic"] spawn AP_fnc_handleMessage};
if (isClass(configFile >> "CfgWeapons" >> _className) && ("optic" in _classname) && {!(player canAdd _className)}) exitWith {
    ["You don't have enough room for this.", "basic"] spawn AP_fnc_handleMessage};
private _itemType =
switch (true) do {case (_className isKindOf["Rifle", configFile >> "CfgWeapons"]): {
            [!((primaryWeapon player) isEqualTo ""), "primary weapon"]};
    case (_className isKindOf["Launcher", configFile >> "CfgWeapons"]): {[!((secondaryWeapon player) isEqualTo ""), "secondary weapon"]};
    case (_className isKindOf["Pistol", configFile >> "CfgWeapons"]): {[!((handgunWeapon player) isEqualTo ""), "handgun"]};
    case (_className isKindOf["Vest_Camo_Base", configFile >> "CfgWeapons"]): {[!((vest player) isEqualTo ""), "vest"]};
    case (_className isKindOf["Vest_NoCamo_Base", configFile >> "CfgWeapons"]): {[!((vest player) isEqualTo ""), "vest"]};
    default {[false, ""]};}; private _dlcInfo = getAssetDLCInfo[_classname, configFile >> "CfgVehicles"];
private _action1 = true;
if (!(_classname isKindOf "Car" || _classname isKindOf "Ship" || _classname isKindOf "Air") && _dlcInfo select 0 && !(_dlcInfo select 1)) then {
    _action1 = [format["You need the %1 DLC in order to re-equip this weapon if you place it on the ground or into a vehicle/crate. Purchase anyway?", _dlcInfo select 5], "DLC Item Confirmation", "Yes", "No"] call BIS_fnc_guiMessage;
};
if !(_action1) exitWith {closeDialog 0};
private _action2 = true;
private _action2 =
if (_itemType select 0 && !(_sell)) then {
    [format["You already have a %1 equipped, crafting another will replace it. Craft anyway?", _itemType select 1], "Duplicate Item Warning", "Yes", "No"] call BIS_fnc_guiMessage;
} else {true};
if !(_action2) exitWith {closeDialog 0};
if (isClass(configFile >> "CfgVehicles" >> _className) && !(_sell) && {AP_garageCount >= call AP_maxGarageVeh}) exitWith {
    closeDialog 0;
    [format["You cannot craft more vehicles of this type into your garage until you sell (or crash) existing vehicles! The current maximum is %1 vehicles per garage.", call AP_maxGarageVeh], "basic"] spawn AP_fnc_handleMessage;
};
private _blockedSpawn = false;
if (isClass(configFile >> "CfgVehicles" >> _className)) then {
    private _markers = ["veh_sp_84", "veh_sp_85", "veh_sp_86", "veh_sp_91", "veh_sp_92", "veh_sp_93", "veh_sp_94", "veh_sp_96"];
    private _spawnPoint = _markers param[_markers findIf {
        nearestObjects[getMarkerPos _x, ["Car", "Ship"], 5] isEqualTo[] && nearestObjects[getMarkerPos _x, ["Air"], 14] isEqualTo[] && ((player distance2D(getMarkerPos _x) <= 100))
    }, ""];
    if (_spawnPoint isEqualTo "") exitWith {
        ["There is a vehicle currently blocking the spawn point(s).", "basic"] spawn AP_fnc_handleMessage;
        closeDialog 0;
        _blockedSpawn = true;};};
if (_blockedSpawn) exitWith {};
AP_cash = AP_cash - _cashRequired;
AP_cashCacheB = ((AP_cash / 4) + 9);
[0] call AP_fnc_ClupdatePartial; {_x params["_item", "_amount"];
    if !(_item isEqualTo "AP_cash") then {[false, ["getShortName", _item] call AP_fnc_virtItemCfg, _amount] call AP_fnc_handleInv;};}
forEach _recipe;
// RESOURCE RIGS: sentinel outputs, not config classes -- every isKindOf below
// is false for them, so they would fall through to the weapon branch and hand
// out a garbage item. Resolve them here, AFTER the material consume (the
// Factory's existing trust model, unchanged): the server spawns the flatbed,
// adopts the rig identity, and persists it through the same vehicleCreate
// pipe every bought vehicle rides.
if (_classname in ["rig_extractor", "rig_processor"]) exitWith {
    private _markers = ["veh_sp_84", "veh_sp_85", "veh_sp_86", "veh_sp_91", "veh_sp_92", "veh_sp_93", "veh_sp_94", "veh_sp_96"];
    private _spawnPoint = _markers param [_markers findIf {
        nearestObjects [getMarkerPos _x, ["Car", "Ship"], 5] isEqualTo [] && nearestObjects [getMarkerPos _x, ["Air"], 14] isEqualTo [] && ((player distance2D (getMarkerPos _x)) <= 100)
    }, ""];
    if (_spawnPoint isEqualTo "") exitWith {
        // materials are gone and the pad is blocked -- refund rather than eat them
        { _x params ["_item", "_amount"];
          if !(_item isEqualTo "AP_cash") then {[true, ["getShortName", _item] call AP_fnc_virtItemCfg, _amount] call AP_fnc_handleInv;}; } forEach _recipe;
        ["There is a vehicle blocking the spawn point(s) -- materials returned.", "basic"] spawn AP_fnc_handleMessage;
        closeDialog 0;
    };
    private _kind = ["processor", "extractor"] select (_classname isEqualTo "rig_extractor");
    [["craft", [player, _kind, getMarkerPos _spawnPoint, markerDir _spawnPoint]], "APS_fnc_rigSRV", 2] spawn AP_fnc_MP;
    ["vehiclescrafted", 1] call AP_fnc_statArrUpdate;
    [format ["The factory has assembled your %1. It is parked outside -- the deck's RIG CONSOLE controls it.",
        ["Resource Processor", "Resource Extractor"] select (_classname isEqualTo "rig_extractor")], "basic"] spawn AP_fnc_handleMessage;
    [["-CRAFTING-", player, (profileName), format ["crafted a %1 at POS: %2", _kind, getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
    closeDialog 0;
};
switch (true) do {case (_classname isKindOf "Car" || _classname isKindOf "Ship" || _classname isKindOf "Air"): {
            ["vehiclescrafted", 1] call AP_fnc_statArrUpdate;};
    case (_className isKindOf["Rifle", configFile >> "CfgWeapons"]): {["weaponscrafted", 1] call AP_fnc_statArrUpdate;};
    case (_className isKindOf["Launcher", configFile >> "CfgWeapons"]): {["weaponscrafted", 1] call AP_fnc_statArrUpdate;};
    case (_className isKindOf["Pistol", configFile >> "CfgWeapons"]): {["weaponscrafted", 1] call AP_fnc_statArrUpdate;};
}; switch (true) do {case (_className isKindOf "Air"): {["craft", "air", 1] call AP_fnc_handleQuest;};
    case (_className in ["B_MRAP_01_F", "O_MRAP_02_F"]): {["craft", "armor", 1] call AP_fnc_handleQuest;};
    case (_className in _762): {["craft", "762guns", 1] call AP_fnc_handleQuest;};
}; private _blackMarket = ["B_G_Offroad_01_F", "B_G_Offroad_01_armed_F", "O_MRAP_02_F", "I_MRAP_03_F", "I_Heli_light_03_unarmed_F", "O_Heli_Light_02_unarmed_F", "30Rnd_65x39_caseless_green", "20Rnd_762x51_Mag", "arifle_Katiba_F", "arifle_Katiba_C_F", "LMG_Mk200_F", "srifle_DMR_01_F", "srifle_EBR_F", "srifle_DMR_03_khaki_F", "srifle_DMR_03_multicam_F", "srifle_DMR_03_tan_F", "srifle_DMR_03_woodland_F", "srifle_DMR_06_olive_F", "srifle_DMR_06_camo_F", "arifle_AKM_F", "arifle_AK12_F", "arifle_SPAR_03_khk_F", "arifle_SPAR_03_snd_F", "LMG_03_F", "30Rnd_762x39_Mag_F"];
if (_sell) exitWith {private _weaponPrices = AP_factory_prices;
    // owner 2026-07-17: the factory-price table is the PRIMARY sell value now (weapons/vests/optics AND the
    // black-market vehicles listed there). A vehicle NOT in the table falls back to its vehicleConfig price.
    private _price = (_weaponPrices param[_weaponPrices findIf {_className in _x}, 0]) param[1, 0];
    if (_price isEqualTo 0 && {isClass(configFile >> "CfgVehicles" >> _className)}) then {
        _price = ["getVehicleRowParsed", "", _className] call AP_fnc_vehicleConfig select 7;};
    // owner 2026-07-17: items with NO sale price cannot be sold back to the market -- forces player-to-player trade.
    if (_price isEqualTo 0) exitWith {
        ["This item has no market value -- it can't be sold back to the market. Trade it player-to-player.", "basic"] spawn AP_fnc_handleMessage;
        closeDialog 0;};
    _price = _price * 0.65;
    if (_className in _blackMarket) then {private _gangID = AP_gang_data param[0, -25];
        private _flagID = (arms_flag getVariable["AP_capData", []]) param[0, -1];
        private _cartelText = "";
        if !(_flagID isEqualTo _gangID) then {private _cut = floor(_price * 0.15); [
                [0, 0, _cut], "APS_fnc_cartelSRV", false, false] spawn AP_fnc_MP;
            _price = _price - _cut;
            _cartelText = format["A $%1 cut has been taken by the Arms Cartel.", [_cut] call AP_fnc_numberText];};
        AP_cash = AP_cash + _price;
        AP_cashCacheB = ((AP_cash / 4) + 9);
        [0] call AP_fnc_ClupdatePartial;
        [format["You have sold the produced item for the current market value of $%1. The funds have been given to you on hand. %2", [_price] call AP_fnc_numberText, _cartelText], "basic"] spawn AP_fnc_handleMessage;
        closeDialog 0;} else {AP_atmcash = AP_atmcash + _price;
        AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
        [1] call AP_fnc_ClupdatePartial;
        [format["You have produced the selected item for the current market value of $%1. The funds have been deposited into your bank account.", [_price] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
        closeDialog 0;}; [
        ["-CRAFTING-", player, (profileName), format["crafted a %1 and sold it for $%2 at POS: %3", _className, [_price] call AP_fnc_numberText, getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
};
if (isClass(configFile >> "CfgMagazines" >> _className)) exitWith {player addMagazine _className;
    [format["The factory has produced a %1 with your materials. You have received the item.", getText(configFile >> "CfgMagazines" >> _className >> "displayName")], "basic"] spawn AP_fnc_handleMessage;
};
if (isClass(configFile >> "CfgVehicles" >> _className)) then {
    private _markers = ["veh_sp_84", "veh_sp_85", "veh_sp_86", "veh_sp_91", "veh_sp_92", "veh_sp_93", "veh_sp_94", "veh_sp_96"];
    private _spawnPoint = _markers param[_markers findIf {
        nearestObjects[getMarkerPos _x, ["Car", "Ship"], 5] isEqualTo[] && nearestObjects[getMarkerPos _x, ["Air"], 14] isEqualTo[] && ((player distance2D(getMarkerPos _x) <= 100))
    }, ""];
    if (_spawnPoint isEqualTo "") exitWith {
        ["There is a vehicle currently blocking the spawn point(s).", "basic"] spawn AP_fnc_handleMessage;
        closeDialog 0};
    private _plb_pos = getMarkerPos _spawnPoint;
    _plb_pos set[2, (_plb_pos select 2) + 1.5];
    private _vehicle = createVehicle[_classname, [random 999, random 999, 999], [], 0, "CAN_COLLIDE"];
    waitUntil {!isNil "_vehicle" && {!isNull _vehicle}};
    _vehicle lock true;
    _vehicle allowDamage false;
    _vehicle setDir(markerDir _spawnPoint);
    _vehicle setPos _plb_pos;
    _vehicle setVectorUp(surfaceNormal(_plb_pos));
    private _skinID = lbValue[1804, lbCurSel 1804];
    if (isNil "_skinID") then {_skinID = -1};
    [_vehicle, [0, 0, 0, 0], _skinID, "", [0, 1], false] spawn AP_fnc_prepareVehicle;   // owner 2026-06-13: full fuel on spawn (was 0.5)
    [format["The factory has produced a %1 with your materials. You have received the keys and it is now parked outside.", getText(configFile >> "CfgVehicles" >> _className >> "displayName")], "basic"] spawn AP_fnc_handleMessage;
    [[player, _vehicle, getPlayerUID player, "civ", _skinID, 0], "APS_fnc_vehicleCreate", 2] spawn AP_fnc_MP;
    [6] call AP_fnc_ClupdatePartial;
    if (_className in _blackMarket && _classname != "B_G_Offroad_01_F") then {[10, true] call AP_fnc_addInfamy;}; [
        ["-CRAFTING-", player, (profileName), format["crafted a %1 to keep at POS: %2", getText(configFile >> "CfgVehicles" >> _className >> "displayName"), getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
} else {if ("optic" in _classname) then {player addItem _classname;} else {[_className, true, false, true, false] call AP_fnc_handleItem;
    };
    [format["The factory has produced a %1 with your materials. You have received the item.", getText(configFile >> "CfgWeapons" >> _className >> "displayName")], "basic"] spawn AP_fnc_handleMessage;
    if (_className in _blackMarket && !(_className in ["30Rnd_762x39_Mag_F", "20Rnd_762x51_Mag", "30Rnd_65x39_caseless_green"])) then {
        [5, true] call AP_fnc_addInfamy;}; [
        ["-CRAFTING-", player, (profileName), format["crafted a %1 to keep at POS: %2", getText(configFile >> "CfgWeapons" >> _className >> "displayName"), getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
};
closeDialog 0;