params["_player"];
if (vehicle _player == _player) exitWith {false};
private _vehicle = (vehicle _player);
if !(_vehicle isKindOf "Air") exitWith {false};
private _cfg = configFile >> "CfgVehicles" >> typeOf _vehicle;
private _trts = _cfg >> "turrets";
private _return = false;
for "_i"
from 0 to(count _trts - 1) do {_trt = _trts select _i;
    if (getNumber(_trt >> "iscopilot") isEqualTo 1) exitWith {_return = (_vehicle turretUnit[_i] == _player);};}; _return