if !(AP_isMaxTac) exitWith {};
if !(SRV_MAXTACrequested) exitWith {["Sorry, MaxTac officers are not needed at this time.", "basic"] spawn AP_fnc_handleMessage;};
if ((SRV_activeMAXTAC select 1) >= (SRV_activeMAXTAC select 0)) exitWith {
    ["Sorry, all the slots available for the MaxTac deployment have been filled.", "basic"] spawn AP_fnc_handleMessage;};
["action", "reportmaxtac", 1] spawn AP_fnc_handleQuest; [[player], "APS_fnc_registerMaxTac", 2] call AP_fnc_MP;