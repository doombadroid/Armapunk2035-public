params[["_unit", objNull, [objNull]], ["_container", objNull, [objNull]], ["_item", "", [""]]];
if (AP_laser_inprogress) exitWith {deleteVehicle _container};
if (isNull _unit || _item isEqualTo "") exitWith {};
if (AP_eviSpawn || AP_activeMAXTAC) exitWith {};
if (AP_effSide isEqualTo independent) exitWith {};
if (typeOf _container == "GroundWeaponHolder") then {[[_container, 450], "APS_fnc_setCleanTime", 2] spawn AP_fnc_MP;}; [
    ["-STOREDITEM-", player, profileName, format["Stored %1 in %2 :: %3 - %4 - %5 - %6", _item, typeOf _container, getWeaponCargo _container, getItemCargo _container, getBackpackCargo _container, getMagazineCargo _container]], "APS_fnc_logIt", false] call AP_fnc_MP;
[false] call AP_fnc_saveGear;
[3] call AP_fnc_ClupdatePartial;