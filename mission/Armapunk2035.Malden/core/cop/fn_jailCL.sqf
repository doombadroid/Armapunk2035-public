params[["_unit", objNull, [objNull]]];
if (isNull _unit || !((typeOf _unit) == "Land_Bodybag_01_black_F")) exitWith {};
private _name = _unit getVariable["AP_playername", "Error"];
private _pid = _unit getVariable["AP_steamid", ""];
if (_name isEqualTo "Error" || _pid isEqualTo "") exitWith {};
if (_unit getVariable["AP_wantedAmt", 0] isEqualTo 0) exitWith {["This person was not wanted", "basic"] spawn AP_fnc_handleMessage;};
if (AP_effSide isEqualTo independent) exitWith {["You cannot arrest this body.", "basic"] spawn AP_fnc_handleMessage;};
if (AP_effSide isEqualTo civilian && !(_pid in AP_bounty_uid)) exitWith {
    ["You cannot arrest this bounty as it's not your bounty.", "basic"] spawn AP_fnc_handleMessage}; [
    [_pid], "APS_fnc_setJail", false, false] spawn AP_fnc_MP; [
    ["-ARRESTCL-", player, profileName, format["(%1) arrested combat logger %2 (%3) with a bounty of $%4", side player, _name, _pid, [_unit getVariable["AP_wantedAmt", 0]] call AP_fnc_numberText]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
[[0, 1, 2], format["You've arrested the Combat Logger, %1!", [_name] call AP_fnc_cleanName]] call AP_fnc_broadcast; [
    [_unit, player, true, false], "APS_fnc_wantedBounty", 2] spawn AP_fnc_MP;