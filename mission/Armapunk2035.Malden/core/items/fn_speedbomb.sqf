private _vehicle = cursorObject;
if !(_vehicle isKindOf "LandVehicle") exitWith {["You cannot add a speed bomb to this.", "basic"] spawn AP_fnc_handleMessage;};
if (player distance _vehicle > 7) exitWith {["You need to be within 7 meters!", "basic"] spawn AP_fnc_handleMessage;};
if (player getVariable["AP_surrendered", false]) exitWith {
    ["How do you expect to arm a bomb with your hands up there!?", "basic"] spawn AP_fnc_handleMessage;};
if (_vehicle getVariable["AP_Speedbombed", false]) exitWith {
    ["This vehicle already has a speedbomb on it. More would be overkill!", "basic"] spawn AP_fnc_handleMessage;};
if !(AP_effSide isEqualTo civilian) exitWith {};
if !([false, "speedbomb", 1] call AP_fnc_handleInv) exitWith {};
closeDialog 0;
AP_action_in_use = true;
player playMoveNow "AinvPknlMstpSnonWnonDnon_medic_1";
uiSleep 3.5;   // owner 2026-06-19 (#405): arm DURING the animation, then re-validate. Previously the distance check ran
               // BEFORE this sleep, so a vehicle that drove/flew off during the 3.5s still got bombed, and the kneel
               // animation never stopped.
AP_action_in_use = false;
player switchMove "";   // stop the planting animation (playMoveNow left the planter stuck mid-kneel)
if (isNull _vehicle || {player distance _vehicle > 7}) exitWith {
    titleText["The vehicle moved too far away to arm the speedbomb!", "PLAIN"];
    [true, "speedbomb", 1] call AP_fnc_handleInv;};
titleText["You have attached an armed speed bomb to this vehicle.", "PLAIN"];
AP_side_exp = AP_side_exp + 25;
(_vehicle getVariable["AP_dbInfo", []]) params[["_vehOwner", "", [""]], ["_plate", -1, [0]]]; [
    ["-SPEEDBOMB-", player, profileName, format["attached a speedbomb to a %1, Plate: %2, belonging to %3, POS: %4.", (getText(configFile >> "CfgVehicles" >> (typeOf _vehicle) >> "displayName")), _plate, _vehOwner, getPosATL _vehicle]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
private _damageRadius = 10;
[_vehicle, _damageRadius] spawn {params["_vehicle", "_damageRadius"];
    _vehicle setVariable["AP_Speedbombed", true, true];
    waitUntil {(speed _vehicle) > 70};
    private _toSend = (allPlayers - [allDeadMen]) select {(_x distance player) <= 10}; [
        [_vehicle, "caralarm"], "AP_fnc_playSound", _toSend] spawn AP_fnc_MP;
    ["A speed bomb you planted on a vehicle has just become active!", "basic"] spawn AP_fnc_handleMessage; [
        [2, "A speed bomb has been activated on this vehicle and will detonate when your speed drops below 50km/h!"], "AP_fnc_broadcast", crew _vehicle] spawn AP_fnc_MP;
    waitUntil {(speed _vehicle) < 50}; [[2, player], "APS_fnc_wantedAdd", 2] spawn AP_fnc_MP;
    (_vehicle getVariable["AP_dbInfo", []]) params[["_vehOwner", "", [""]], ["_plate", -1, [0]]]; [
        ["-SPEEDBOMB-", player, profileName, format["detonated their speedbomb attached to a %1, Plate: %2, belonging to %3, POS: %4.", (getText(configFile >> "CfgVehicles" >> (typeOf _vehicle) >> "displayName")), _plate, _vehOwner, getPosATL _vehicle]], "APS_fnc_logIt", 2, false, false] call AP_fnc_MP;
    private _bomb = "Bo_Mk82"
    createVehicle[0, 0, 9999];
    private _plb_pos = getPosATL _vehicle;
    _bomb setPosATL _plb_pos;
    _bomb setVelocity[100, 0, 0];
    private _nearVehicles = nearestObjects[_vehicle, ["Car", "Truck", "Air", "Ship"], _damageRadius]; {private _plb_dmg = _x;
        _plb_dmg setDamage 1;}
    forEach _nearVehicles;
    private _copCount = count(allPlayers select {side _x isEqualTo west && ((_x distance _vehicle) < 15)});
    if (_copCount > 0) then {["civ_cops_speedbombed", _copCount] call AP_fnc_statArrUpdate;};
    ["A speed bomb you planted on a vehicle has DETONATED!", "basic"] spawn AP_fnc_handleMessage; [
        [0, format["A speed bomb planted by %1 has detonated!", profileName]], "AP_fnc_broadcast", -2] spawn AP_fnc_MP;
    ["speedbomb", 1] call AP_fnc_statArrUpdate;};