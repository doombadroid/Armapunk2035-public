params[["_tierIndex", 0, [0]]];
AP_loginBonusData params["_playerUID", "_consecutiveDays", "_needsGift", "_wipeProgress"];
if (_playerUID isNotEqualTo(getPlayerUID player)) exitWith {};
if !(_needsGift) exitWith {
    [format["You have no login bonus loot at the moment! You have been playing everyday for the past %1 day(s)", AP_loginBonusData param[1, 0]], "basic"] spawn AP_fnc_handleMessage;
};
(["getTierData", _tierIndex] call AP_fnc_loginBonusCfg) params["_tierIDX", "_lootArray", "_isVirtual", "_isPhysical", "_isVehicle", "_isWeapon"];
_lootArray params["_itemClassname", "_itemCount"];
private _rewardString = "";
private _carClaim = false;   // giveCar IS the claim; sending updatePlayerData as well would race it and could eat the car
switch (true) do {case (_isVirtual): {if (_itemClassname in ["money", "newdrachma"]) then {
                if (_itemClassname isEqualTo "newdrachma") then {
                    // NEW DRACHMA: config amount is native ND. The SERVER pays it off the claim below
                    // (APS_fnc_loginBonusSRV "updatePlayerData" -> ndCreditSrv), from its own tier row.
                    _rewardString = format["You were awarded %1 New Drachma directly into your wallet", [_itemCount] call AP_fnc_ndText];} else {
                    _rewardString = format["You were awarded $%1 Cold, Hard Cash directly into your bank account", [_itemCount] call AP_fnc_numberText, (["getName", _itemClassname] call AP_fnc_virtItemCfg)];
                    AP_atmcash = AP_atmcash + _itemCount;
                    AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
                    [1] call AP_fnc_ClupdatePartial;};} else {
                private _totalWeightLeftToCarry = [_itemClassname, _itemCount, AP_carryWeight, AP_maxWeight] call AP_fnc_calWeightDiff;
                _rewardString = format["You were awarded %1 %2", [_itemCount] call AP_fnc_numberText, (["getName", _itemClassname] call AP_fnc_virtItemCfg)];
                if (_totalWeightLeftToCarry <= 0) then {
                    [format["You could not hold all these items, they have been dropped on the ground near your feet!"], "basic"] spawn AP_fnc_handleMessage;
                    private _pos =
                    if (objectParent player isKindOf "Ship") then {(objectParent player) modelToWorld[0, -8, -1]} else {getPosASL player}; [
                        [[[_itemClassname, _itemCount]], _pos, "Land_Suitcase_F"], "APS_fnc_createItem", 2] spawn AP_fnc_MP;} else {
                    if ([true, _itemClassname, _itemCount] call AP_fnc_handleInv) then {};};};};
    case (_isPhysical): {_rewardString = format["You were awarded a %1", (([_itemClassname] call AP_fnc_fetchCfgDetails) param[1, ""])];
            private _holder = nearestObject[player, "groundWeaponHolder"];
            [_itemClassname, _itemCount, player, _holder] call AP_fnc_dropPhysicalItem;
            [format["Your loot has been dropped on the ground."], "basic"] spawn AP_fnc_handleMessage;};
    case (_isWeapon): {_rewardString = format["You were awarded a %1", (([_itemClassname] call AP_fnc_fetchCfgDetails) param[1, ""])];
            private _weaponType =
            switch (true) do {case (_itemClassname isKindOf["Rifle", configFile >> "CfgWeapons"]): {
                        [!((primaryWeapon player) isEqualTo ""), "primary weapon"]};
                case (_itemClassname isKindOf["Launcher", configFile >> "CfgWeapons"]): {
                        [!((secondaryWeapon player) isEqualTo ""), "secondary weapon"]};
                case (_itemClassname isKindOf["Pistol", configFile >> "CfgWeapons"]): {[!((handgunWeapon player) isEqualTo ""), "handgun"]
                    };
                default {[false, ""]};}; private _action =
            if ((_itemCount isEqualTo 1) && (_weaponType param[0, false])) then {
                [format["You already have a %1 equipped, gathering another will replace it. Gather anyway?", _weaponType select 1], "Duplicate Item Warning", "Yes", "No"] call BIS_fnc_guiMessage;
            } else {true};
            private _weaponAttachmentsArray = _lootArray param[2, []];
            private _weaponAmmoArray = _lootArray param[3, []];
            if (_action && (_itemCount isEqualTo 1) && (_weaponAmmoArray isEqualTo[]) && (count _weaponAttachmentsArray isEqualTo 1)) then {
                player addWeapon _itemClassname; {player addWeaponItem[_itemClassname, _x]}
                forEach _weaponAttachmentsArray;
                [format["Your weapon has been given into your hands!"], "basic"] spawn AP_fnc_handleMessage;} else {
                private _holder = nearestObject[player, "groundWeaponHolder"];
                [_itemClassname, _itemCount, player, _holder] call AP_fnc_dropPhysicalItem;
                if (_weaponAttachmentsArray isNotEqualTo[]) then {{private _holder = nearestObject[player, "groundWeaponHolder"];
                        [_x, 1, player, _holder] call AP_fnc_dropPhysicalItem;}
                    forEach _weaponAttachmentsArray;};
                if (_weaponAmmoArray isNotEqualTo[]) then {{private _holder = nearestObject[player, "groundWeaponHolder"];
                        [_x param[0, ""], _x param[1, 0], player, _holder] call AP_fnc_dropPhysicalItem;}
                    forEach _weaponAmmoArray;};
                [format["Your loot and all its content have fallen to the floor!"], "basic"] spawn AP_fnc_handleMessage;};};
    case (_isVehicle): {AP_garageCount = -1; [[getPlayerUID player, AP_effSide, player], "APS_fnc_garageCount", 2] spawn AP_fnc_MP;
            uiSleep 3;
            if (AP_garageCount >= (call AP_maxGarageVeh)) then {
                private _vehSellPrice = (["getVehicleRowParsed", "", _itemClassname] call AP_fnc_vehicleConfig) param[8, 5000];
                AP_atmcash = AP_atmcash + _vehSellPrice;
                AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
                [1] call AP_fnc_ClupdatePartial;
                _rewardString = format["Since you had too many vehicles in your garage. You were given $%1 as compensation into your bank account", [_vehSellPrice] call AP_fnc_numberText];
            } else {
                _rewardString = format["You were awarded a fancy brand new %1!", ([_itemClassname] call AP_fnc_fetchCfgDetails) param[1, ""]];
                [["giveCar", [getPlayerUID player, player, _itemClassname]], "APS_fnc_loginBonusSRV", 2] spawn AP_fnc_MP;
                _carClaim = true;};};
    default {};
}; private _formatString = format["%1. Thank you for playing everyday for the past %2 day(s)", _rewardString, (AP_loginBonusData param[1, 0])];
[_formatString, "login_bonus"] spawn AP_fnc_handleMessage; [
    ["-LOGINBONUS-", player, profileName, format["Retrieved a login bonus, Loot: %1, Played for %2 Day(s), POS: %3", _lootArray, (AP_loginBonusData param[1, 0]), getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
player switchMove "";
AP_loginBonusData set[2, false];
["loginbonusopened", 1] call AP_fnc_statArrUpdate;
if (!_carClaim) then {[
    ["updatePlayerData", [getPlayerUID player, (AP_loginBonusData param[1, 0])]], "APS_fnc_loginBonusSRV", 2] spawn AP_fnc_MP;};

// owner 2026-07-19: re-baseline the inventory monitor after a login-bonus grant. Weapon/physical/vehicle rewards
// add items OUTSIDE handleInv (addWeapon / dropPhysicalItem / garage), leaving AP_invMonitor out of balance so
// the [3] item-count anti-cheat false-flags the legit reward in a burst (every code-3 DONG on GrimReaper followed
// a login bonus). Resync to the current virtual total -- same idiom as fn_dropItems / fn_ClupdateRequest.
private _invMonTotal = 0;
{ _invMonTotal = _invMonTotal + (missionNamespace getVariable [_x, 0]); } forEach AP_invMonVars;
AP_invMonitor = _invMonTotal + AP_invRVar;