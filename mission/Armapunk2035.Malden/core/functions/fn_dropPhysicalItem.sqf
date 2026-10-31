params[["_classname", "", [""]], ["_count", 0, [0]], ["_player", objNull, [objNull]], ["_holder", objNull, [objNull]], ["_saveGear", false, [false]]];
if (_classname isEqualTo "ejectItems") exitWith {private _containerObject = _player; {_itemClassname = _x;
        _holder = nearestObject[player, "groundWeaponHolder"];
        if ((typeName _itemClassname) isEqualTo "STRING") then {[_x, 1, player, _holder] call AP_fnc_dropPhysicalItem;} else {{
                if ((_x isNotEqualTo "") && ((typeName _x) isEqualTo "STRING")) then {
                    [_x, 1, player, _holder] call AP_fnc_dropPhysicalItem;};}
            forEach _itemClassname;};}
    forEach((magazineCargo _containerObject) + (itemCargo _containerObject) + (weaponsItemsCargo _containerObject));
    clearWeaponCargo _containerObject;
    clearMagazineCargo _containerObject;
    clearBackpackCargo _containerObject;
    clearItemCargo _containerObject;};
if !(isNull _holder) then {private _distance = _player distance2D _holder;
    if (_distance > 5) then {_holder = createVehicle["groundWeaponHolder", getPosATL _player, [], 0, "can_collide"];};} else {
    _holder = createVehicle["groundWeaponHolder", getPosATL _player, [], 0, "can_collide"];};
private _itemClass = ([_classname] call BIS_fnc_itemType) select 1;
switch _itemClass do {case "Backpack": {_holder addBackpackCargoGlobal[_classname, _count];}; default {
            if ((_itemClass isKindOf["Rifle", configFile >> "CfgWeapons"]) || (_itemClass isKindOf["Launcher", configFile >> "CfgWeapons"]) || (_itemClass isKindOf["Pistol", configFile >> "CfgWeapons"])) then {
                _holder addWeaponCargoGlobal[_classname, _count];} else {_holder addItemCargoGlobal[_classname, _count];};};
}; if (_saveGear) then {[true] call AP_fnc_saveGear;};