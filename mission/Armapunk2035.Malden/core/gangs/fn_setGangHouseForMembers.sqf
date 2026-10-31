params[["_house", objNull, [objNull]], ["_gangID", -1, [0]]];
if (isNull _house || !(_gangID isEqualTo(AP_gang_data param[0, -5]))) exitWith {};
AP_gangBuilding = [_house, getPosATL _house];
AP_gang_data set[3, getPosATL _house];
deleteMarkerLocal AP_gangBldgMark;
deleteMarkerLocal (format ["phouse_gang_%1", _gangID]);
// owner 2026-06-17 (#324): unified marker name `phouse_gang_<gangID>` across all three paths (this live-set,
// the leader's fn_setGangHouse, and the relog fn_initGang) so they always replace -- never orphan -- each other.
private _marker = createMarkerLocal[format["phouse_gang_%1", _gangID], getPosATL _house];
_marker setMarkerTextLocal "Gang Building";
_marker setMarkerColorLocal "ColorGreen";
_marker setMarkerTypeLocal "mil_end";
AP_gangBldgMark = _marker;
["Your gang leader has set a gang house.", "basic"] spawn AP_fnc_handleMessage;