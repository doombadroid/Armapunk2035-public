params[["_unit", objNull, [objNull]]];
if (isNull _unit) exitWith {};
if (player distance(getMarkerPos "jail_marker2") > 70) exitWith {
    ["You can't use this outside of prison!", "basic"] spawn AP_fnc_handleMessage};
if (time - AP_last_shank < (60 * 3)) exitWith {["You can only shank someone every 3 minutes!", "basic"] spawn AP_fnc_handleMessage};
if (player distance _unit > 2) exitWith {};
if (AP_inv_shank < 1) exitWith {};
if !(_unit getVariable["AP_arrested", false]) exitWith {};
if (_unit getVariable["AP_downed", false]) exitWith {};
AP_last_shank = time;
["shank", 1] call AP_fnc_statArrUpdate;
["action", "shank", 1] spawn AP_fnc_handleQuest; [["shank", _unit], "APS_fnc_victimSRV", 2] spawn AP_fnc_MP; [
    [0, 1, 2], format["You've been shanked by %1!", [profileName] call AP_fnc_cleanName]] remoteExec["AP_fnc_broadcast", _unit];