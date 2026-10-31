disableSerialization;
// DECK ROUTE: net id as a param; the PRICE is always re-derived from the vehicle
// config row, never taken from the page.
params [["_deckNet", "", [""]]];
private _fromDeck = _deckNet isNotEqualTo "";
if (!_fromDeck && {(lbCurSel 39402) isEqualTo - 1}) exitWith {["You didn't select a vehicle to chop.", "basic"] spawn AP_fnc_handleMessage;};
private "_price"; private "_vehicle";
if (_fromDeck) then {
    _vehicle = _deckNet;
    private _o = objectFromNetId _deckNet;
    private _row = ["getVehicleRow", "", typeOf _o] call AP_fnc_vehicleConfig;
    private _side = switch (_o getVariable ["AP_side", -1]) do { case "cop": {1}; case "med": {2}; default {0} };
    _price = if ((_row select 8) isEqualType []) then {(_row select 8) select _side} else {_row select 8};
} else {
    _price = lbValue[39402, lbCurSel 39402];
    _vehicle = lbData[39402, lbCurSel 39402];
};
_vehicle = objectFromNetId _vehicle;
if (player distance(_vehicle) > 25) exitWith {["The vehicle is too far away.", "basic"] spawn AP_fnc_handleMessage;};
if (isNull _vehicle) exitWith {["Null vehicle.", "basic"] spawn AP_fnc_handleMessage;};
if !(_vehicle getVariable["AP_canChop", true]) exitWith {
    ["You cannot chop this vehicle as it's not registered with the DMV!", "basic"] spawn AP_fnc_handleMessage;};
if !((_vehicle getVariable["AP_side", ""] in ["civ", "cop"]) || {(_vehicle getVariable["AP_dbInfo",[]]) param [2, false] isEqualTo true}) exitWith {   // owner 2026-06-21 (#477): also allow GANG vehicles (AP_dbInfo[2]==true) even if AP_side is unstamped
    ["This vehicle cannot be chopped.", "basic"] spawn AP_fnc_handleMessage;};
if (_vehicle getVariable["AP_gettingClaimed", false]) exitWith {
    ["You can't chop this vehicle while it's being claimed.", "basic"] spawn AP_fnc_handleMessage;};
if (_vehicle getVariable["AP_gettingChopped", false]) exitWith {
    ["This vehicle is already being chopped.", "basic"] spawn AP_fnc_handleMessage;};
if (typeOf _vehicle isEqualTo "I_Plane_Fighter_04_F") exitWith {
    ["This air vehicle cannot be claimed.", "basic"] spawn AP_fnc_handleMessage;};
_vehicle setVariable["AP_gettingChopped", true, true];
closeDialog 0;
disableSerialization;
5 cutRsc["AP_progress", "PLAIN"];
private _ui = uiNamespace getVariable "AP_progress";
private _text = "Chopping vehicle...";
private _progress = _ui displayCtrl 38201;
private _pgText = _ui displayCtrl 38202;
_pgText ctrlSetText format["%2 (1%1)...", "%", _text];
_progress progressSetPosition 0.01;
private _cP = 0.01;
AP_action_in_use = true;
private _success = false;
private _startPos = getPosASL player;
for "_i"
from 0 to 1 step 0 do {uiSleep 0.3;
    _cP = _cP + 0.01;
    _progress progressSetPosition _cP;
    _pgText ctrlSetText format["%3 (%1%2)...", round(_cP * 100), "%", _text];
    if !(alive player) exitWith {};
    if !(alive _vehicle) exitWith {};
    if !(isNull objectParent player) exitWith {};
    if (player distance2D _startPos > 2) exitWith {};
    if (player distance2D _vehicle > 22) exitWith {};
    if (player getVariable["AP_downed", false]) exitWith {};
    if (player getVariable["AP_surrendered", false]) exitWith {};
    if (player getVariable["AP_restrained", false]) exitWith {};
    if !(AP_action_in_use) exitWith {};
    if (_cp >= 1) exitWith {_success = true;};}; 5 cutText["", "PLAIN"];
AP_action_in_use = false;
_vehicle setVariable["AP_gettingChopped", false, true];
if !(_success) exitWith {["The chopping process was interrupted.", "basic"] spawn AP_fnc_handleMessage;};
private _price2 = AP_cash + _price; [[player, _vehicle, _price, _price2], "APS_fnc_srvChopShopSell", false, false] spawn AP_fnc_MP; [
    [getPlayerUID player, "AP_choptrace", time], "APS_fnc_varPersist", 2] spawn AP_fnc_MP;
AP_lastPersistVar = ["AP_choptrace", (time + 30)];
[] spawn {private _time = time;
    waitUntil {uiSleep 1;
        (AP_cash isEqualTo 0) || ((time - _time) > 200)};
    if (AP_cash isEqualTo 0) then {[[getPlayerUID player, "AP_choptrace", -1000], "APS_fnc_varPersist", 2] spawn AP_fnc_MP;};};
["vehchop", 1] call AP_fnc_statArrUpdate;
["The chop shop has consumed the vehicle!", "basic"] spawn AP_fnc_handleMessage;
if (_vehicle getVariable["AP_side", ""] == "cop") then {if (typeOf _vehicle isEqualTo "C_Hatchback_01_sport_F") then {
        ["chop", "cophatchback", 1] call AP_fnc_handleQuest;};
    if (typeOf _vehicle isEqualTo "B_Heli_Light_01_F") then {["chop", "cophummingbird", 1] call AP_fnc_handleQuest;};
    if (typeOf _vehicle isEqualTo "O_MRAP_02_F") then {["chop", "copifrit", 1] call AP_fnc_handleQuest;};};
if (_vehicle getVariable["AP_side", ""] == "civ") then {if (typeOf _vehicle isEqualTo "O_Heli_Light_02_unarmed_F") then {
        ["chop", "civorca", 1] call AP_fnc_handleQuest;};
    if (typeOf _vehicle isEqualTo "O_MRAP_02_F") then {["chop", "civifrit", 1] call AP_fnc_handleQuest;};
    if (typeOf _vehicle isEqualTo "O_Heli_Light_02_unarmed_F") then {["chop", "orcalifetime", 1] call AP_fnc_handleQuest;};};