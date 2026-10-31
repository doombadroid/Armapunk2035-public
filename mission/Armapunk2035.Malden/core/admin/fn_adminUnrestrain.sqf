if ((call AP_adminLevel) <= 1) exitWith {closeDialog 0;};
if ((lbCurSel 12901) isEqualTo - 1) exitWith {};
private _unit = lbData[12901, lbCurSel(12901)];
_unit = missionNamespace getVariable _unit;
if (isNull _unit || !((_unit getVariable["AP_adminRestrain", false]) || (_unit getVariable["AP_restrained", false]))) exitWith {}; {
    _x params["_var", "_value"];
    if (_unit getVariable[_var, true]) then {_unit setVariable[_var, _value, true];};}
forEach[["AP_adminRestrain", false], ["AP_restrained", false], ["AP_escorting", false], ["AP_transporting", false]];
detach _unit;
[format["You have un-restrained %1", name _unit], "warning"] spawn AP_fnc_handleMessage; [
    ["-ADMINACTION-", player, (profileName), format["un-restrained %1", name _unit]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;