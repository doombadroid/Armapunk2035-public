params[["_value", 0, [0]], ["_showText", false, [false]]];

if (!license_civ_rebel) exitWith {};
private _amount = floor(_value);
AP_infamy_exp = AP_infamy_exp + _amount;
[22] call AP_fnc_ClupdatePartial;
if (_showText) then {systemChat format["You've earned %1 infamy.", _amount];};