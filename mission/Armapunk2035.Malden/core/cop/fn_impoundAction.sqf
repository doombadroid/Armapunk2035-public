params[["_seize", false, [false]], ["_vehicle", objNull, [objNull]]];
if (isNull _vehicle || !(alive _vehicle || _vehicle isKindOf "Car" || _vehicle isKindOf "Air" || _vehicle isKindOf "Ship" || _vehicle isKindOf "Tank")) exitWith {};
if (AP_effSide isEqualTo independent && typeOf _vehicle in ["I_MRAP_03_F"] && !(_vehicle getVariable["AP_side", "civ"] isEqualTo "med")) exitWith {
    ["You can only impound Medic Striders.", "basic"] spawn AP_fnc_handleMessage;};
if (typeOf _vehicle in ["O_MRAP_02_F", "I_MRAP_03_F", "I_C_Offroad_02_LMG_F", "O_LSV_02_armed_F", "B_G_Offroad_01_armed_F"] && (_vehicle getVariable["AP_side", "civ"] isEqualTo "civ")) then {
    _seize = true;};
private _aggressive = allPlayers param[allPlayers findIf {_x getVariable["AP_aggressive", -300] > (time - 60)}, objNull];
if !(isNull _aggressive) exitWith {
    ["You are in (or have recently been in) combat and the garage clerk cowers in fright! Wait a few minutes and try again!", "basic"] spawn AP_fnc_handleMessage;
};
if (_seize && ((typeOf _vehicle) isEqualTo "B_MRAP_01_F") && !(call AP_copLevel >= 3)) exitWith {
    ["You must be at least a Corporal to seize this.", "basic"] spawn AP_fnc_handleMessage;};
if ((_vehicle getVariable["AP_mentalTruck", false]) && (SRV_loonyBinData param[4, false])) exitWith {
    ["The Loony Bin Truck can't be impounded/seized whilst the tomb is locked, slacker!", "basic"] spawn AP_fnc_handleMessage;};
[getItemCargo _vehicle, getWeaponCargo _vehicle, getMagazineCargo _vehicle, getBackpackCargo _vehicle] params["_vehItem", "_vehWeapon", "_vehAmmo", "_vehBackpack"];
private _countWeapons1 = count(_vehWeapon select 0);
private _countAmmo1 = count(_vehAmmo select 0);
private _exit = false;
private _sideVehicle = _vehicle getVariable["AP_side", ""];
if (_sideVehicle isEqualTo "cop") then {if !((_vehItem select 0) findIf {_x != "Toolkit" && _x != "FirstAidKit"}
    isEqualTo - 1) then {_exit = true};
    if (_vehicle getVariable["AP_vinv", [[], 0]] select 1 > 0 || !((_countWeapons1 + _countAmmo1) isEqualTo 0)) then {_exit = true};
    if !((_vehBackpack select 0) findIf {_x find "Parachute"
        isEqualTo - 1 && _x != "B_AssaultPack_cbr"}
    isEqualTo - 1) then {_exit = true};
    _seize = false;};
if (_seize && AP_effSide isEqualTo independent) exitWith {};
if (_exit) exitWith {
    ["You cannot impound a police vehicle which contains equipment. Empty the vehicle first!", "basic"] spawn AP_fnc_handleMessage;};
if (player distance cursorTarget > 6) exitWith {};
private _vehicleData = _vehicle getVariable["AP_vehOwners", []];
if (_vehicleData isEqualTo[]) exitWith {deleteVehicle _vehicle};
private _vehicleName = getText(configFile >> "CfgVehicles" >> typeOf _vehicle >> "displayName");
private _text = "";
private _rank =
if (AP_effSide isEqualTo west) then {"MaxSec Officer "} else {"TT Medic "};
private _prompt =
if (_seize) then {"seize"} else {"impound"};
private _action = [format["Are you sure you want to %1 %2's %3?", _prompt, (_vehicleData select 0) select 1, _vehicleName], "Impound/Seize Vehicle", "Yes", "No"] call BIS_fnc_guiMessage;
if (_action) then {if (_seize) then {[
            [0, format["%1 your %2 is being seized by %3%4.", (_vehicleData select 0) select 1, _vehicleName, _rank, profileName]], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
        _text = "Seizing Vehicle";} else {[
            [0, format["%1 your %2 is being impounded by %3%4.", (_vehicleData select 0) select 1, _vehicleName, _rank, profileName]], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
        _text = "Impounding Vehicle";};
    disableSerialization;
    5 cutRsc["AP_progress", "PLAIN"];
    private _ui = uiNamespace getVariable "AP_progress";
    private _progress = _ui displayCtrl 38201;
    private _pgText = _ui displayCtrl 38202;
    _pgText ctrlSetText format["%2 (1%1)...", "%", _text];
    _progress progressSetPosition 0.01;
    private _cP = 0.01;
    AP_action_in_use = true;
    private _success = false;
    for "_i"
    from 0 to 1 step 0 do {uiSleep 0.09;
        _cP = _cP + 0.01;
        _progress progressSetPosition _cP;
        _pgText ctrlSetText format["%3 (%1%2)...", round(_cP * 100), "%", _text];
        if (player distance _vehicle > 7) exitWith {};
        if !(alive player) exitWith {};
        if !(AP_action_in_use) exitWith {};
        if (_cp >= 1) exitWith {_success = true;};}; 5 cutText["", "PLAIN"];
    AP_action_in_use = false;
    if !(_success) exitWith {};
    if !(crew _vehicle isEqualTo[]) exitWith {["The vehicle isn't empty of people!", "basic"] spawn AP_fnc_handleMessage;};
    private _type = getText(configFile >> "CfgVehicles" >> (typeOf _vehicle) >> "displayName");
    private _price =
    if (_vehicle isKindOf "Car") then {100} else {200};
    private _side =
    switch (_vehicle getVariable["AP_side", -1]) do {case "civ": {0}; case "cop": {1};
            case "med": {2};};
    ( _vehicle getVariable["AP_dbInfo", []]) params[["_uid", "", [""]], ["_plate", 0, [0]], ["_isGang", false, [false]]];
    if ((_vehicle getVariable["AP_vehIsMaxTac", false]) || (_vehicle getVariable["AP_vehIsFirefighter", false])) exitWith {
        deleteVehicle _vehicle; [
            ["-VEHIMPOUND-", player, profileName, format["impounded a %1 (%2) owned by %3.", _vehicleName, _plate, (_vehicleData select 0) select 1]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
    };
    if (_seize) then {private _vehicleOwners = _vehicle getVariable["AP_vehOwners", [[getPlayerUID player, profileName]]];
        private _evidenceTruck = (typeOf _vehicle isEqualTo "O_Truck_03_covered_F") && (((_vehicleOwners param[0, ["123", "yes"]]) param[0, "123"]) isEqualTo "000000000");
        private _vehRow = ["getVehicleRow", "", typeOf _vehicle] call AP_fnc_vehicleConfig;
        private _price =
        if ((_vehRow select 7) isEqualType[]) then {((_vehRow select 7) select _side) * 0.25;} else {(_vehRow select 7) * 0.25;};
        if (typeOf _vehicle in ["O_MRAP_02_F", "I_C_Offroad_02_LMG_F", "O_LSV_02_armed_F", "B_G_Offroad_01_armed_F", " B_T_Truck_01_ammo_F", "B_T_Truck_01_box_F", "O_T_Truck_03_repair_ghex_F", "O_T_LSV_02_armed_black_F"]) then {
            [floor(_price / 25)] spawn AP_fnc_earnPrestige;};
        [format["You have seized a %1", _type], "basic"] spawn AP_fnc_handleMessage; [
            ["-VEHSEIZE-", player, profileName, format["seized a %1 (%2) owned by %3.", _vehicleName, _plate, (_vehicleData select 0) select 1]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
        [[player, _price], "APS_fnc_copSplit", 2] spawn AP_fnc_MP; [[_vehicle, "seize"], "APS_fnc_vehicleDead", 2] spawn AP_fnc_MP;
    } else {AP_impound_inuse = true;

        // find objects
		_objects = attachedObjects _vehicle;

		// check if vehicle has objects or not
 {
			// delete those objects
			deleteVehicle _x;} forEach _objects;
        
        if (_isGang) then {[[_uid, _vehicle, player, getPlayerUID player, true], "APS_fnc_gangGarageStore", 2] spawn AP_fnc_MP;} else {[
                [_vehicle, true, player, _uid, _plate], "APS_fnc_vehicleStore", 2] spawn AP_fnc_MP;};
        ["action", "impound", 1] call AP_fnc_handleQuest;
        waitUntil {!AP_impound_inuse};
        [format["You have impounded a %1. You have received $%2 for cleaning up the streets!", _type, _price], "basic"] spawn AP_fnc_handleMessage;
        [
            ["-VEHIMPOUND-", player, profileName, format["impounded a %1 (%2) owned by %3.", _vehicleName, _plate, (_vehicleData select 0) select 1]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
        AP_atmcash = (round(AP_atmcash + _price)) max 0;
        AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
        [1] call AP_fnc_ClupdatePartial;};};