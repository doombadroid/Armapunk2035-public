params[["_vehicle", objNull, [objNull]]];
if !(_vehicle isKindOf "Air" || _vehicle isKindOf "Ship" || _vehicle isKindOf "LandVehicle") exitWith {
    ["You cannot add a tracking unit to this.", "basic"] spawn AP_fnc_handleMessage};
if (player distance _vehicle > 7) exitWith {["You need to be within 7 meters!", "basic"] spawn AP_fnc_handleMessage};
if (_vehicle in AP_trackedVehicles) exitWith {["You are already tracking this vehicle.", "basic"] spawn AP_fnc_handleMessage};
if !([false, "tracker", 1] call AP_fnc_handleInv) exitWith {};
if !(isNull objectParent player) exitWith {["You cannot perform this action from within a vehicle.", "basic"] spawn AP_fnc_handleMessage
};
if (isWeaponDeployed player) exitWith {
    ["You probably need your hands free to attach a tracker to this.", "basic"] spawn AP_fnc_handleMessage};
if (player getVariable["AP_surrendered", false]) exitWith {
    ["You probably need your hands free to attach a tracker to this.", "basic"] spawn AP_fnc_handleMessage};
closeDialog 0;
AP_action_in_use = true;
player playMove "AinvPknlMstpSnonWnonDnon_medic_1";
uiSleep 1.5;
AP_action_in_use = false;
if (player distance _vehicle > 7) exitWith {titleText["You are not in range!", "PLAIN"]};
AP_trackedVehicles pushBack _vehicle;
private _trackedPlayers = _vehicle getVariable["AP_vehicleTrackers", []];
_trackedPlayers pushBack[AP_effSide, getPlayerUID player];
_vehicle setVariable["AP_vehicleTrackers", _trackedPlayers, true];
titleText["You have attached a tracking device to this vehicle.", "PLAIN"];
AP_side_exp = AP_side_exp + 15;
["action", "applytracker", 1] call AP_fnc_handleQuest;