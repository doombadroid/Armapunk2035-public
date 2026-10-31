if !(params[["_startPos", [], [[]]
], ["_missileType", "", [""]], ["_missileSpeed", 0, [0]], ["_target", objNull, [objNull]], ["_radius", 0, [0]]]) exitWith {
    diag_log "Missile Launch Failed at params";};
if (AP_missileActive) exitWith {};
AP_missileActive = true;
for "_i"
from 1 to 15 do {if !(isNull objectParent player) then {playSound "missileLocking";};
    if (_target distance2d _startPos > _radius) exitWith {};
    uiSleep 0.4;}; if (_target distance2d _startPos > _radius) exitWith {uiSleep 2;
    AP_missileActive = false;};
private _missile = _missileType createVehicle _startPos;
_missile setPos _startPos;
private _maxDuration = time + 17;
private _playSound = 0;
[_missile, _maxDuration] spawn {params["_missile", "_maxDuration"];
    private _flare = objNull;
    while {alive _missile}
    do {if (time > _this select 1 || isNull _missile) exitWith {};
        _flare = "CMflare_Chaff_Ammo"
        createVehicle getPos(_missile);
        _flare attachTo[_missile, [0, 0, 0]];
        uiSleep 3;
        deleteVehicle _flare;};};
while {alive _missile}
do {private _targetPosition = getPosASL _target;
    private _missilePosition = getPosASL _missile;
    if (!(lineIntersects[_targetPosition, _missilePosition, _target, _missile]) && !(terrainIntersect[getPosATL _missile, getPosATL _target])) then {
        _targetPosition set[2, ((_targetPosition select 2) + 1)];} else {_targetPosition set[2, ((_targetPosition select 2) + 175)];};
    private _targetDistance = _missilePosition distance _targetPosition;
    private _travelTime = _targetDistance / _missileSpeed;
    private _relDirHor = _missilePosition getDir _targetPosition;
    _missile setDir _relDirHor;
    private _relDirVer = asin(((_missilePosition select 2) - (_targetPosition select 2)) / (_target distance _missile));
    _relDirVer = (_relDirVer * -1);
    [_missile, _relDirVer, 0] call BIS_fnc_setPitchBank;
    private _missileNewVelocity = [((_targetPosition select 0) - (_missilePosition select 0)) / _travelTime, ((_targetPosition select 1) - (_missilePosition select 1)) / _travelTime, ((_targetPosition select 2) - (_missilePosition select 2)) / _travelTime];
    _missile setVelocity _missileNewVelocity;
    if (time > _maxDuration) exitWith {};
    _playSound = _playSound + 1;
    if (_playSound isEqualTo 2) then {if !(isNull objectParent player) then {playSound "missileLocked";};};
    if (_playSound >= 2) then {_playSound = 0;};
    if (_target distance2d _startPos > (_radius * 1.1)) exitWith {uiSleep 4;};
    uiSleep 0.07;}; if !(isNull _missile) then {deleteVehicle _missile;};
AP_missileActive = false;