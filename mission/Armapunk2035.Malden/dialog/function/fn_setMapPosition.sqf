disableSerialization;
params[["_control", controlNull, [controlNull]], ["_time", 1, [0]], ["_zoom", 0.1, [0]], ["_position", [], [[]]]];
if (isNull _control || count _position isEqualTo 0) exitWith {};
_control ctrlMapAnimAdd[_time, _zoom, _position];
ctrlMapAnimCommit _control;