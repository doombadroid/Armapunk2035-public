/*
    File: fn_dynamicMapVehicleFix.sqf  (AP_fnc_dynamicMapVehicleFix)
    Track the vehicle the player last got into. AP_fnc_mapTick holds map objects near
    AP_dynamicMap_lastVehicle instead of streaming them out, so a car left at the edge of a
    town does not lose the town under it. Forgets the vehicle once it is gone, dead, or driven
    by somebody else. (The Altis-era version also required two named zones; mapdb retired zones.)
    Spawned from evh/fn_getInMan.sqf.
*/
params [["_vehicle", objNull, [objNull]]];
if (isNull _vehicle) exitWith {};
profileNamespace setVariable ["AP_dynamicMap_lastVehicleID", floor (random 9999)];
private _randomID = profileNamespace getVariable ["AP_dynamicMap_lastVehicleID", -1];
while {_vehicle isEqualTo AP_dynamicMap_lastVehicle} do {
    if (isNull _vehicle) exitWith { AP_dynamicMap_lastVehicle = objNull };
    if !(alive _vehicle) exitWith { AP_dynamicMap_lastVehicle = objNull };
    if !(_randomID isEqualTo (profileNamespace getVariable ["AP_dynamicMap_lastVehicleID", -1])) exitWith {};
    if (!(isNull driver _vehicle) && {!(driver _vehicle isEqualTo player)} && {alive (driver _vehicle)}) exitWith {
        AP_dynamicMap_lastVehicle = objNull };
    uiSleep 5;
};
