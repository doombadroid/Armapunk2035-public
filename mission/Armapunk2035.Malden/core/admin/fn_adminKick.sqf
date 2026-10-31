/*
    LooneyBin (owner, 2026-06-11): admin-menu KICK. Target = selection in the admin player list
    (12901). Server re-verifies the caller's admin level (APS_fnc_adminKickBan).
*/
if ((call AP_adminLevel) < 3) exitWith {["Kick is restricted to Admin+ (level 3).", "basic"] spawn AP_fnc_handleMessage;};
if ((lbCurSel 12901) isEqualTo -1) exitWith {["Select a player first.", "basic"] spawn AP_fnc_handleMessage;};
private _unit = missionNamespace getVariable [lbData [12901, lbCurSel 12901], objNull];
if (isNull _unit || {_unit isEqualTo player}) exitWith {};
private _confirm = [format ["Kick %1 from the server?", name _unit], "Kick Player", "Kick", "Cancel"] call BIS_fnc_guiMessage;
if !(_confirm) exitWith {};
[[getPlayerUID _unit, name _unit, false, player], "APS_fnc_adminKickBan", 2] spawn AP_fnc_MP;
[format ["Kick sent for %1.", name _unit], "basic"] spawn AP_fnc_handleMessage;
