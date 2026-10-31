params[["_class", "", [""]]];
if (_class isEqualTo "") exitWith {[]};
private _config = configFile >> "CfgVehicles" >> _class;
if (!isClass _config) exitWith {[]};
private _info = [];
private _info = [_class, getNumber(_config >> "scope"), getText(_config >> "picture"), getText(_config >> "displayName"), getText(_config >> "vehicleClass"), getNumber(_config >> "side"), getText(_config >> "faction"), inheritsFrom _config, getNumber(_config >> "maxSpeed"), getNumber(_config >> "armor"), getNumber(_config >> "transportSoldier") + count("true"
configClasses(_config >> "Turrets")), getNumber(_config >> "enginePower"), getNumber(_config >> "fuelCapacity")];
_info