params[["_mode", -1, [0]], ["_pObj", objNull, [objNull]]];
if (_mode isEqualTo - 1 || isNull _pObj) exitWith {};
if ((call AP_adminLevel) <= 2) exitWith {["Insufficient Permissions", "basic"] spawn AP_fnc_handleMessage;};
private _action = ["You are about to adjust the server restart cycle. Are you sure?", "Server Restart Adjustment", "Confirm", "Cancel"] call BIS_fnc_guiMessage;
if (_action) then {[[_mode, _pObj, getPlayerUID player], "APS_fnc_changeServCycle", 2] spawn AP_fnc_MP;} else {
    ["Server restart adjustment canceled.", "basic"] spawn AP_fnc_handleMessage;};