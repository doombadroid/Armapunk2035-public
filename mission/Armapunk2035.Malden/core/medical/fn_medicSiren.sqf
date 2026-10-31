params[["_vehicle", objNull, [objNull]], ["_sirenType", "", [""]], ["_sirenObject", objNull, [objNull]], ["_driver", objNull, [objNull]]];
if (isNull _vehicle || _sirenType isEqualTo "") exitWith {};
if (isNil {_vehicle getVariable "AP_siren"}) exitWith {};
private _length =
switch (_sirenType) do {case "medicWail": {5.5688};
        case "medicYelp": {3.914};
        case "medicQwail": {14.895};}; while {!isNull _vehicle && !isNull(driver _vehicle) && alive _vehicle}
do {_sirenObject say3D[_sirenType, 650];
    uiSleep _length;}; if (_driver isEqualTo player) then {if !(isNull AP_siren_obj) then {deleteVehicle AP_siren_obj;
        _vehicle setVariable["AP_siren", false, true];};};