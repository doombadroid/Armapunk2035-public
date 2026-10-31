params[["_vehicle", objNull, [objNull]], ["_state", 2, [0, false]]];
if (isNull _vehicle) exitWith {};
_vehicle lock _state;
_vehicle enableRopeAttach(_state isEqualTo 0);