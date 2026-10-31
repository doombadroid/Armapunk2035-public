if (AP_session_completed) exitWith {};
AP_loadingScreenStatus = format["Sending Server Request For %1 (%2)", profileNameSteam, profileName]; [
    [player, playerSide], "DB_fnc_queryRequest", false, false] call AP_fnc_MP;