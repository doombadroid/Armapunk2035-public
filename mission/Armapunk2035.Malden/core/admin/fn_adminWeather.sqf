params[["_function", "", [""]]];
if (_function isEqualTo "") exitWith {};
if ((call AP_adminLevel) <= 3) exitWith {["Insufficient Permissions", "basic"] spawn AP_fnc_handleMessage;};
private _action = ["You are about to set/change the server weather. Are you sure?", "Weather change", "Confirm", "Cancel"] call BIS_fnc_guiMessage;
if (_action) then {[_function] remoteExec["APS_fnc_changeWeather", 2]} else {
    ["Weather adjustment canceled.", "basic"] spawn AP_fnc_handleMessage;};