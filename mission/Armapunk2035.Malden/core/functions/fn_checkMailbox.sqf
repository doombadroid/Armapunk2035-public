if (AP_lastCompCheck >= time) exitWith {
    ["You can only check your mailbox every 10 minutes. Try again later.", "basic"] spawn AP_fnc_handleMessage;};
private _restartTime =
if (isNil "serverStartTime") then {round((14400 - serverTime) / 60)} else {round((serverCycleLength - (serverTime - serverStartTime)) / 60)
};
if (_restartTime <= 5) exitWith {
    ["You cannot check your mailbox within 5 minutes of a restart. Try again after restart.", "basic"] spawn AP_fnc_handleMessage;}; [
    [player, getPlayerUID player], "APS_fnc_processMailbox", 2] spawn AP_fnc_MP;
AP_lastCompCheck = time + 600;