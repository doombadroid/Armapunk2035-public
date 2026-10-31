params[["_vehicle", objNull, [objNull]], ["_sirenType", "", [""]], ["_sirenObject", objNull, [objNull]], ["_driver", objNull, [objNull]]];
if (isNull _vehicle || _sirenType isEqualTo "") exitWith {};
if (isNil {_vehicle getVariable "AP_siren"}) exitWith {};
// SirenMaxSecHeavy is the same .ogg as SirenMaxSec at a higher CfgSounds volume, so it shares the
// 3.47 loop length. This switch has no default arm -- an id that matches no case leaves _length nil,
// uiSleep throws, and the thread dies after a single say3D, i.e. the siren plays exactly one cycle
// and then goes quiet with nothing in game to explain it. Any new siren id needs a case here.
private _length =
switch (_sirenType) do {case "SirenMaxSec": {3.47}; case "SirenMaxSecHeavy": {3.47}; case "SirenWail": {4.61}; case "SirenYelp": {6.35};
        case "SirenPhaser": {7.18};
        case "siren2": {13.775}}; while {!isNull _vehicle && !isNull(driver _vehicle) && alive _vehicle}
do {_sirenObject say3D[_sirenType, 650];
    uiSleep _length;}; if (_driver isEqualTo player) then {if !(isNull AP_siren_obj) then {deleteVehicle AP_siren_obj;
        if (_vehicle getVariable["AP_siren", false]) then {_vehicle setVariable["AP_siren", false, true];};};};