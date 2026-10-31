params[["_house", objNull, [objNull]], ["_rgb", [], [[]]]];
if (isNull _house) exitWith {};
if !(_house isKindOf "House_F") exitWith {};
private _enable = isNull(_house getVariable["AP_lightSource", objNull]); [
    [_house, _enable, _rgb], "AP_fnc_lightHouse", -2] spawn AP_fnc_MP;