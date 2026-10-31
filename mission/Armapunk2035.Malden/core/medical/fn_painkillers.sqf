params[["_target", objNull, [objNull]]];
private _unit = cursorObject;
if (_target isEqualTo player) then {_unit = player;};
if (isNull _unit || !(_unit isKindOf "CAManBase")) exitWith {};
if (_unit isEqualTo player) then {[0] call AP_fnc_setPain;
    titleText["You consume pain killers.", "PLAIN"];} else {};