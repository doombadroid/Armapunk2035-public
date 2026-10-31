if (AP_session_completed) exitWith {};
AP_loadingScreenStatus = "The Server Didn't Find Any Info Matching Your UID. Sending Request To Add You..."; [
    [player, getPlayerUID player, profileName], "DB_fnc_insertRequest", false, false] spawn AP_fnc_MP;