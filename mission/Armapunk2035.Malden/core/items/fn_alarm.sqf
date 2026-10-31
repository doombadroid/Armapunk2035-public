params[["_unit", objNull, [objNull]], ["_type", "", [""]]];
if (isNull _unit || _type isEqualTo "") exitWith {};
closeDialog 0;
if (_type isEqualTo "caralarm" && !(_unit isKindOf "LandVehicle")) exitWith {
    ["This alarm system can only be installed on cars or trucks.", "basic"] spawn AP_fnc_handleMessage;};
if (_type isEqualTo "airalarm" && !(_unit isKindOf "Air")) exitWith {
    ["This alarm system can only be installed in air vehicles", "basic"] spawn AP_fnc_handleMessage;};
if (player distance _unit > 7) exitWith {["You need to be within 7 meters!", "basic"] spawn AP_fnc_handleMessage;};
if !([false, _type, 1] call AP_fnc_handleInv) exitWith {};
private _mods = _unit getVariable["AP_mods", [0, 0, 0, 0, 0, 0, 0, 0, 0]];
if ((_mods select 0) isEqualTo 1) exitWith {["This vehicle already has an alarm system.", "basic"] spawn AP_fnc_handleMessage;};
if (count _mods < 9) then {private _toAdd = 9 - (count _mods);
    for [{_x = 1}, {_x <= _toAdd}, {_x = _x + 1}] do {_mods pushBack 0;};};
AP_action_in_use = true;
player playMoveNow "AinvPknlMstpSnonWnonDnon_medic_1";
uiSleep 1.5;
AP_action_in_use = false;
if (player distance _unit > 7) exitWith {titleText["You are not in range!", "PLAIN"];};
_mods set[0, 1];
_unit setVariable["AP_mods", _mods, true];
titleText["You have installed an alarm system in this vehicle.", "PLAIN"];
private _plate = (_unit getVariable["AP_dbInfo", []]) select 1;
private _vehOwner = ((_unit getVariable["AP_vehOwners", getPlayerUID player]) select 0) select 0; [
    [player, _vehOwner, _plate], "APS_fnc_vehAddAlarm", 2] spawn AP_fnc_MP;
AP_side_exp = AP_side_exp + 30;