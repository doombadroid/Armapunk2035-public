params[["_vehicle", objNull, [objNull]], ["_hornType", "", [""]]];
if (isNull _vehicle || _hornType isEqualTo "") exitWith {};
if (!isNil "AP_streamerMode" && {AP_streamerMode} && {_hornType in AP_offensiveHorns}) exitWith {};
_vehicle say3D[_hornType, 650];