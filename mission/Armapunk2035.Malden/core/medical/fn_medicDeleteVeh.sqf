params[["_vehicle", objNull, [objNull]]];
if (alive _vehicle) exitWith {["The vehicle you are trying to clear must be destroyed!", "basic"] spawn AP_fnc_handleMessage;};
if (AP_action_in_use) exitWith {["You are currently already doing something!", "basic"] spawn AP_fnc_handleMessage;};
if !(_vehicle isEqualTo cursorObject) exitWith {};
private _vehicleName = getText(configFile >> "CfgVehicles" >> (typeOf _vehicle) >> "displayName");
private _payout =
if (typeOf _vehicle in ["C_Kart_01_Blu_F", " C_Kart_01_Fuel_F", "C_Kart_01_Red_F", "C_Kart_01_Vrana_F", "B_Quadbike_01_F", "I_Quadbike_01_F", "C_Quadbike_01_black_F", "C_Rubberboat", "B_Boat_Transport_01_F"]) then {
    50} else {500};
AP_action_in_use = true;
private _text = format["Clearing %1 Wreckage", _vehicleName];
5 cutRsc["AP_progress", "PLAIN"];
private _ui = uiNameSpace getVariable "AP_progress";
private _progress = _ui displayCtrl 38201;
private _pgText = _ui displayCtrl 38202;
_pgText ctrlSetText format["%2 (1%1)...", "%", _text];
_progress progressSetPosition 0.01;
private _cP = 0.01;
private _success = false;
private _pos = getPos player;
for "_i"
from 0 to 1 step 0 do {uiSleep 0.2;
    _cP = _cP + 0.02;
    _progress progressSetPosition _cP;
    _pgText ctrlSetText format["%3 (%1%2)...", round(_cP * 100), "%", _text];
    if (player distance _pos > 4 || AP_isDowned || player getVariable["AP_restrained", false] || !alive player || speed player > 2) exitWith {};
    if !(AP_action_in_use) exitWith {};
    if !(isNull objectParent player) exitWith {};
    if (_cP >= 1) exitWith {_success = true;};}; 5 cutText["", "PLAIN"];
AP_action_in_use = false;
if !(_success) exitWith {};
[format["You have removed the wreckage of a %1", _vehicleName], "basic"] spawn AP_fnc_handleMessage;
AP_side_exp = AP_side_exp + 50;
25 call AP_fnc_medicEarn;   // TT prestige
["action", "removewreck", 1] call AP_fnc_handleQuest;
// Silent Partner board: "Housekeeping". A Trauma Team verb feeding a civ contract
// is deliberate -- the Administrator pays for wrecks to stop existing and does not
// ask who is holding the tow controls. aq_fnc_event is side-agnostic; the TEMPLATE
// carries side = "civ", so a medic firing this simply moves no civ quest of theirs.
["action", "removewreck", 1] call aq_fnc_event;

// find objects
_objects = attachedObjects _vehicle;

// check if vehicle has objects or not
 {
    // delete those objects
    deleteVehicle _x;} forEach _objects;

deleteVehicle _vehicle;
if (805 in AP_completedLifetimeQuests) then {AP_atmcash = (round(AP_atmcash + _payout)) max 0;
    AP_atmcashCacheB = ((AP_atmcash / 4) + 11);};