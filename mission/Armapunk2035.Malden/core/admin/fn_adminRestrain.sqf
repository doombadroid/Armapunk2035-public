if ((call AP_adminLevel) <= 1) exitWith {closeDialog 0;};
private _unit = lbData[12901, lbCurSel(12901)];
_unit = missionNamespace getVariable _unit;
if (isNil "_unit") exitwith {};
if (isNull _unit) exitWith {};
if !(isPlayer _unit) exitWith {};
private _action = false;
if (_unit isEqualTo player) then {
    _action = ["Are you sure you want to admin restrain yourself?", "Admin Restrain Self", "Yes", "No"] call BIS_fnc_guiMessage;};
if (_action || !(_unit isEqualTo player)) then {if (_unit getVariable["AP_adminRestrain", false]) exitWith {}; [   // via the server: APS_fnc_victimSRV re-reads adminlevel, sets the flags, forwards AP_fnc_unitRestrain
        ["adminRestrain", _unit], "APS_fnc_victimSRV", 2, false] spawn AP_fnc_MP;
    [format["You have restrained %1", name _unit], "warning"] spawn AP_fnc_handleMessage; [
        ["-ADMINACTION-", player, (profileName), format["Restrained %1", name _unit]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
};