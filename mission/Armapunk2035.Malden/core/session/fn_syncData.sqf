if (isNil "AP_session_time") then {AP_session_time = false};
if (AP_session_time) exitWith {
    ["You have already used the sync option, you can only use this feature once every 5 minutes.", "basic"] spawn AP_fnc_handleMessage};
[] call AP_fnc_ClupdateRequest;
["Syncing player information to the server. Please wait up to 20 seconds before leaving.", "basic"] spawn AP_fnc_handleMessage;
[] spawn {AP_session_time = true;
    uiSleep(5 * 60);
    AP_session_time = false;};