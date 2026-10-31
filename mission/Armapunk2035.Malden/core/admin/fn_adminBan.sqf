/*
    LooneyBin (owner, 2026-06-11): admin-menu BAN (permanent; bans table, enforced at connect).
    Senior Admin (level 4) only. Server re-verifies (APS_fnc_adminKickBan).
*/
if ((call AP_adminLevel) < 4) exitWith {["Ban is restricted to Senior Admin (level 4).", "basic"] spawn AP_fnc_handleMessage;};
if ((lbCurSel 12901) isEqualTo -1) exitWith {["Select a player first.", "basic"] spawn AP_fnc_handleMessage;};
private _unit = missionNamespace getVariable [lbData [12901, lbCurSel 12901], objNull];
if (isNull _unit || {_unit isEqualTo player}) exitWith {};
private _confirm = [format ["PERMANENTLY BAN %1?", name _unit], "Ban Player", "BAN", "Cancel"] call BIS_fnc_guiMessage;
if !(_confirm) exitWith {};
[[getPlayerUID _unit, name _unit, true, player], "APS_fnc_adminKickBan", 2] spawn AP_fnc_MP;
[format ["Ban sent for %1.", name _unit], "basic"] spawn AP_fnc_handleMessage;
