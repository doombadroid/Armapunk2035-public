params[["_unit", objNull, [objNull]], ["_license", "", [""]], ["_bool", false, [true]]];
if (isNull _unit) exitWith {};
private _licenseName = ["getName", _license] call AP_fnc_licenseCfg;
private _message =
if (_license isEqualTo "bounty" && _bool) then {
    format["Do you wish to revoke %1's %2 for the remaining duration of the server cycle? This should only be used for extreme cases of license abuse! Misuse of this feature is not tolerated.", name _unit, _licenseName]
} else {format["Do you wish to revoke %1's %2?", name _unit, _licenseName]};
private _action = [_message, "Revoke License", "Yes", "No"] call BIS_fnc_guiMessage;
if !(_action) exitWith {}; [
    [format["-REVOKELICENSE(%1)-", _bool], player, (profileName), format["revoked %1's (%2) %3 - For Server Cycle: %4", name _unit, getPlayerUID _unit, _licenseName, _bool]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
[["revoke", _unit, [_license, _bool]], "APS_fnc_victimSRV", 2] spawn AP_fnc_MP;
if (_license isEqualTo "bounty" && _bool) then {AP_revokedBH pushBack getPlayerUID _unit;
    publicVariable "AP_revokedBH";
    [format["You have revoked %1's %2 for the remaining duration of the server cycle.", name _unit, _licenseName], "basic"] spawn AP_fnc_handleMessage;
    systemChat format["You have revoked %1's %2 for the remaining duration of the server cycle.", name _unit, _licenseName];} else {
    [format["You have revoked %1's %2.", name _unit, _licenseName], "basic"] spawn AP_fnc_handleMessage;
    systemChat format["You have revoked %1's %2.", name _unit, _licenseName];};