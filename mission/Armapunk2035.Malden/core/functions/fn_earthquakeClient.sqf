params[["_magnitude", 1, [0]], ["_center", [0, 0, 0], [[]]]];
private _distance = player distance _center;
private _power = _magnitude;
private _duration = 20;
private _frequency = 100;
private _sound = "Earthquake_01";
private _compensation = 0;
private _fatigue = 0.2;
_fatiguedefault = getFatigue player;
switch (_magnitude) do {case 1: {_duration = 13;
            _compensation = 2;
            _frequency = 200;
            _sound = "Earthquake_01";
            _fatigue = 0.4;};
    case 2: {_duration = 20;
            _compensation = 4;
            _frequency = 50;
            _sound = "Earthquake_02";
            _fatigue = 0.6;};
    case 3: {_duration = 20;
            _compensation = 6;
            _frequency = 40;
            _sound = "Earthquake_03";
            _fatigue = 0.8;};
    case 4: {_duration = 20;
            _compensation = 7;
            _frequency = 30;
            _sound = "Earthquake_04";
            _fatigue = 1;};
    case 5: {_duration = 30;
            _compensation = 8;
            _frequency = 25;
            _sound = "Earthquake_04";
            _fatigue = 1;};
    default {_duration = 13;
        _compensation = 2;
        _frequency = 200;
        _sound = "Earthquake_01";
        _fatigue = 0.4;};}; if (_magnitude >= 3) then {playSound _sound;
    [] spawn {for "_i"
        from 0 to 2 do {playSound "air_raid";
            uiSleep 9;};};};
playSound _sound;
if !(vehicle player isKindOf "Air") then {enableCamShake true;
    "DynamicBlur"
    ppEffectEnable true;
    "DynamicBlur"
    ppEffectAdjust[_power / 2];
    "DynamicBlur"
    ppEffectCommit 1;
    uiSleep 1;
    "DynamicBlur"
    ppEffectAdjust[0];
    "DynamicBlur"
    ppEffectCommit(_duration - _compensation);
    player setFatigue _fatigue;
    addCamShake[_power, _duration, _frequency];
    [nil, 1] call BIS_fnc_dirtEffect;
    uiSleep 3.5;
    [] call AP_fnc_hudUpdate;};
uiSleep 16;
private _vectorDiff = (_center) vectorDiff(getPosASL player);
private _direction = (_vectorDiff select 0) atan2(_vectorDiff select 1);
if (_direction < 0) then {_direction = 360 + _direction};
private _compass = ["north", "north east", "east", "south east", "south", "south west", "west", "north west", "north"];
private _bearing = _compass select(round(_direction / 45));
[format["A factor %1 earthquake has been detected on the island of %2. The epicenter was reported %3 meters to the %4", _magnitude, worldName, [floor _distance] call AP_fnc_numberText, _bearing], "basic"] spawn AP_fnc_handleMessage;