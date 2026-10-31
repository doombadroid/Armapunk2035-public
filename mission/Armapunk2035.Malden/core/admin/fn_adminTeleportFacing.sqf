if ((call AP_adminLevel) <= 1) exitWith {};
_distance = 10;
_player = player;
_dir = getdir _player;
if (surfaceIsWater position _player) then {_pos = getPosASL _player;
    _pos = [(_pos select 0) + _distance * sin(_dir), (_pos select 1) + _distance * cos(_dir), (_pos select 2)];
    _player setPosASL _pos;} else {_pos = getPosATL _player;
    _pos = [(_pos select 0) + _distance * sin(_dir), (_pos select 1) + _distance * cos(_dir), (_pos select 2)];
    _player setPosATL _pos;};