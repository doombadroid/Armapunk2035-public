/*
    AP_fnc_floodTune -- dial the scripted plaza floodlights in-game, no repack.

        [0.2] call AP_fnc_floodTune;                      brightness only
        [0.2, [1, 0.9, 0.7]] call AP_fnc_floodTune;       brightness + colour
        [0.2, nil, [2, 0, 0.5, 1.5]] call AP_fnc_floodTune;   + attenuation [start, constant, linear, quadratic]

    Writes AP_floodLight (read by AP_fnc_mapLightAttach for lights created later) and re-applies to
    every live light in AP_mapLights at once. Prints the setting so a good value can be copied into
    the default in fn_mapLightAttach.sqf.
*/
params [["_bri", 0.35, [0]], ["_col", nil], ["_att", nil], ["_day", nil]];
private _cfg = +(missionNamespace getVariable ["AP_floodLight", [0.35, [1, 0.95, 0.85], [2, 0, 0.5, 1.5], true]]);
_cfg set [0, _bri];
if (!isNil "_col") then { _cfg set [1, _col]; };
if (!isNil "_att") then { _cfg set [2, _att]; };
if (!isNil "_day") then { _cfg set [3, _day]; };
AP_floodLight = _cfg;
private _n = 0;
{
    _x params ["", "_l"];
    if (!isNull _l) then {
        _l setLightBrightness (_cfg select 0);
        _l setLightColor (_cfg select 1);
        _l setLightAttenuation (_cfg select 2);
        _l setLightDayLight (_cfg select 3);
        _n = _n + 1;
    };
} forEach (missionNamespace getVariable ["AP_mapLights", []]);
systemChat format ["floodlights: %1 relit -- AP_floodLight = %2", _n, _cfg];
_cfg
