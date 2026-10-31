if ((call AP_adminLevel) <= 1) exitWith {closeDialog 0;};
private _isInvis = player getVariable["AP_invisOn", false];
if !(_isInvis) then {player setVariable["AP_invisOn", true, true];
    ["You are now invisible.", "basic"] spawn AP_fnc_handleMessage; [
        [player, true, call AP_adminLevel], "APS_fnc_visible", 2] spawn AP_fnc_MP; [
        ["-ADMINACTION-", player, (profileName), format["went invisible."]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;} else {
    player setVariable["AP_invisOn", false, true];
    ["You are now visible.", "basic"] spawn AP_fnc_handleMessage; [
        [player, false, call AP_adminLevel], "APS_fnc_visible", 2] spawn AP_fnc_MP; [
        ["-ADMINACTION-", player, (profileName), format["removed invisibility."]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;};