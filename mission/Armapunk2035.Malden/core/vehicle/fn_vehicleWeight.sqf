params[["_vehicle", objNull, [objNull]], ["_virtual", false, [false]]];
if (isNull _vehicle) exitWith {};
private _weight = -1;
private _used = (_vehicle getVariable "AP_vinv") select 1;
_weight =
if (_vehicle isKindOf "House_F") then {if (_virtual) then {_vehicle getVariable["AP_vcap", 0];} else {
        _vehicle getVariable["AP_phys_cap", 0];};} else {if (_virtual) then {_vehicle getVariable["AP_vcap", 0];} else {
        ["getPhysCap", "", typeOf _vehicle] call AP_fnc_vehicleConfig;};};
if (isNil "_used") then {_used = 0};
[_weight, _used];