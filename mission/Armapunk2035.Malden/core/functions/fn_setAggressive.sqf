params[["_unit", objNull, [objNull]], ["_recursive", false, [false]]];
if (group _unit isEqualTo group player) exitWith {};
private _lastTime = _unit getVariable["AP_aggressive", 0];
_unit setVariable["AP_aggressive", time];
if (_lastTime < (time - 10) && !(_recursive)) then {private _toSend = (units player - [player]) select {player distance _x <= 2000};
    if !(isNull _unit) then {[[_unit, true], "AP_fnc_setAggressive", _toSend, false, false] spawn AP_fnc_MP;};}; {
    if (_unit distance _x < 2000) then {_x setVariable["AP_aggressive", time];};}
forEach units _unit;