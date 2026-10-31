params[["_vehicle", objNull, [objNull]]];
if (isNull _vehicle) exitWith {};
if !(_vehicle isKindOf "Car" || _vehicle isKindOf "Air" || _vehicle isKindOf "Ship" || _vehicle isKindOf "Tank") exitWith {};
private _owners = _vehicle getVariable "AP_vehOwners";
if (isNil {_owners
} && !(_vehicle isKindOf "Car" || _vehicle isKindOf "Air" || _vehicle isKindOf "Ship" || _vehicle isKindOf "Tank")) exitWith {
    ["This vehicle has no information, it was probably spawned in through cheats. Deleting vehicle.", "basic"] spawn AP_fnc_handleMessage;
    deleteVehicle _vehicle;};
["Searching Vehicle....", "basic"] spawn AP_fnc_handleMessage;
uiSleep 3;
if (player distance _vehicle > 10 || !alive player || !alive _vehicle) exitWith {
    ["Couldn't search the vehicle", "basic"] spawn AP_fnc_handleMessage;};
private _owners = [_owners] call AP_fnc_vehicleOwners;
if (_owners == "any<br/>") then {_owners = "No owners, impound it<br/>";};
[format["<t color='#FF0000' align='center'><t size='1.5'>Vehicle Info</t></t><br/><t color='#FFD700'><t size='1.25' align='center'>Owners</t></t><br/> <t align='center'>%1</t>", _owners], "basic"] spawn AP_fnc_handleMessage;