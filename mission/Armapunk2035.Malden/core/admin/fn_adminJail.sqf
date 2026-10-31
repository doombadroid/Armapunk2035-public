if ((call AP_adminLevel) <= 1) exitWith {closeDialog 0;};
if ((lbCurSel 12901) isEqualTo - 1) exitWith {["You did not select a player.", "basic"] spawn AP_fnc_handleMessage;};
private _unit = lbData[12901, lbCurSel 12901];
_unit = missionNamespace getVariable _unit;
if (isNil "_unit" || {isNull _unit} || {_unit isEqualTo player}) exitWith {};
private _action = [format["Are you sure you wish to use your adiminstrative powers to jail %1?", [name _unit] call AP_fnc_cleanName], format["Deciding the fate of %1...", [name _unit] call AP_fnc_cleanName], "JAIL HIM!", "Nevermind"] call BIS_fnc_guiMessage;
if !(_action) exitWith {}; [[57, _unit], "APS_fnc_wantedAdd", 2] spawn AP_fnc_MP; [
    [player, _unit, [true]], "APS_fnc_handleJail", 2] spawn AP_fnc_MP;