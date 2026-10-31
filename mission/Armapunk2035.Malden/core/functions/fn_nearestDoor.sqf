params[["_house", objNull, [objNull]]];
if (isNull _house) exitWith {0};
private _isOtherDoor = (typeOf _house) in ["Land_City_Gate_F", "Land_Stone_Gate_F"];
if (!(_house isKindOf "House_F") && !_isOtherDoor) exitWith {0};
private _door = 0;
private _range =
if (_isOtherDoor) then {2.8} else {2.4};
private _doors = getNumber(configFile >> "CfgVehicles" >> typeOf _house >> "numberOfDoors");
for "_i"
from 1 to _doors do {private _selectionPos = _house selectionPosition format["Door_%1_trigger", _i];
    private _worldSpace = _house modelToWorld _selectionPos;
    if (player distance _worldSpace < _range) exitWith {_door = _i};}; _door ;