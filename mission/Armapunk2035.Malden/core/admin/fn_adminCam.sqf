[] call BIS_fnc_camera;
closeDialog 0; [
    ["-ADMINACTION-", player, profileName, format["entered admin camera at camera position: %1.", positionCameraToWorld[0, 0, 0]]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
waitUntil {isNull(findDisplay 314)}; [
    ["-ADMINACTION-", player, profileName, format["exited admin camera at camera position: %1.", positionCameraToWorld[0, 0, 0]]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;