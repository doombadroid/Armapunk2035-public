params[["_cop", objNull, [objNull]]];
if (isNull _cop) exitWith {};
private _licenses = ""; {if (missionNamespace getVariable(_x select 0) && _x select 1 == "civ") then {
        _licenses = _licenses + (["varToStr", _x select 0] call AP_fnc_licenseCfg) + "<br/>";};}
forEach AP_licenses;
if (_licenses isEqualTo "") then {_licenses = "No Licenses";}; [
    [profileName, _licenses], "AP_fnc_licensesRead", _cop, false] spawn AP_fnc_MP;