params[["_target", [0, 0, 0], [[]]], ["_time", 0, [0]], ["_condition", {true
}, [{}]], ["_text", "", [""]], ["_altitude", 100, [0]], ["_radius", 200, [0]], ["_angle", random 360, [0]], ["_direction", round random 1, [0]]];
private _startTime = time;
cutText["", "BLACK OUT", 1];
uiSleep 2;
private _uavCamera = "Camera"
camCreate[10, 10, 10];
_uavCamera cameraEffect["INTERNAL", "BACK"];
cameraEffectEnableHUD true;
private _coords = [_target, _radius, _angle] call BIS_fnc_relPos;
_coords set[2, _altitude];
_uavCamera camPrepareTarget _target;
_uavCamera camPreparePos _coords;
_uavCamera camPrepareFOV 0.700;
_uavCamera camCommitPrepared 0;
_uavCamera camPreload 3;
private _ppColor = ppEffectCreate["colorCorrections", 1999];
_ppColor ppEffectEnable true;
_ppColor ppEffectAdjust[1, 1, 0, [1, 1, 1, 0], [0.8, 0.8, 0.8, 0.65], [1, 1, 1, 1.0]];
_ppColor ppEffectCommit 0;
private _ppGrain = ppEffectCreate["filmGrain", 2012];
_ppGrain ppEffectEnable true;
_ppGrain ppEffectAdjust[0.1, 1, 1, 0, 1];
_ppGrain ppEffectCommit 0;
showCinemaBorder true;
waitUntil {camPreloaded _uavCamera};
switchCamera _uavCamera;
if (sunOrMoon < 0.5) then {camUseNVG true;};
cutText["", "BLACK IN", 4];
[_uavCamera] spawn {params[["_uavCamera", objNull, [objNull]]];
    private _sound = "UAV_loop";
    private _duration = getNumber(configFile >> "CfgSounds" >> _sound >> "duration");
    while {!(isNull _uavCamera)}
    do {_uavCamera say _sound;
        uiSleep _duration;};};
[_uavCamera] spawn {params[["_uavCamera", objNull, [objNull]]];
    while {!(isNull _uavCamera)}
    do {private _sound = format["UAV_0%1", round(1 + random 8)];
        private _duration = getNumber(configFile >> "CfgSounds" >> _sound >> "duration");
        _uavCamera say _sound;
        uiSleep(_duration + (5 + random 5));};};
[_uavCamera, _target, _altitude, _radius, _angle, _direction] spawn {params[["_uavCamera", objNull, [objNull]], ["_target", [0, 0, 0], [[]]
    ], ["_altitude", 100, [0]], ["_radius", 200, [0]], ["_angle", random 360, [0]], ["_direction", round random 1, [0]]];
    while {!(isNull _uavCamera)}
    do {private _coords = [_target, _radius, _angle] call BIS_fnc_relPos;
        _coords set[2, _altitude];
        _uavCamera camPreparePos _coords;
        _uavCamera camCommitPrepared 0.5;
        waitUntil {camCommitted _uavCamera};
        _uavCamera camPreparePos _coords;
        _uavCamera camCommitPrepared 0;
        _angle =
        if (_direction == 0) then {_angle - 0.75} else {_angle + 0.75};};};
if !(_text isEqualTo "") then {private _missionStartTimeYear = systemTimeUTC select 0;
    private _missionStartTimeMonth = systemTimeUTC select 1;
    private _missionStartTimeDay = systemTimeUTC select 2;
    // owner 2026-06-25: AP_DayName was NEVER defined anywhere -> this threw "Undefined variable" every tick, KILLING
    // the cinematic thread BEFORE the waitUntil that ends the orbit + starts the game = "stuck circling" (BR/GunGame/
    // Graveyard all use this). The day-of-week was cosmetic; drop it so the cinematic completes.
    private _date = format["%1/%2/%3", _missionStartTimeMonth, _missionStartTimeDay, _missionStartTimeYear];
    _text = [[_date + " ", ""], ["", "<br/>"], [_text, ""]];
    [_text, 0.015 * safeZoneW + safeZoneX, 0.015 * safeZoneH + safeZoneY, false, "<t align = 'left' size = '1.0' font = 'PuristaLight'>%1</t>"] spawn BIS_fnc_typeText2;
};
if (_time isEqualTo 0) then {waitUntil {uiSleep 0.5;
        call _condition};} else {waitUntil {time > _startTime + _time};};
cutText["", "BLACK OUT", 1];
uiSleep 1;
_uavCamera cameraEffect["TERMINATE", "BACK"];
camUseNVG false;
camDestroy _uavCamera;
player switchCamera "INTERNAL";
cutText["", "BLACK IN", 2];
ppEffectDestroy _ppColor;
ppEffectDestroy _ppGrain;