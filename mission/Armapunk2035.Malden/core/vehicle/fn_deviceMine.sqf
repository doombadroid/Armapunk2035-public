#include "..\..\macro.h"
if (scriptAvailable(5)) exitWith {["Wait a bit before attempting to start gathering again.", "basic"] spawn AP_fnc_handleMessage;};
params[["_vehicle", objNull, [objNull]]];
if (isNull _vehicle) exitWith {};
if (_vehicle getVariable["AP_mentalTruck", false]) exitWith {
    ["This action is currently disabled for the loony bin truck.", "basic"] spawn AP_fnc_handleMessage;};
if !(objNull isEqualTo(_vehicle getVariable["AP_mining", objNull])) exitWith {
    ["This vehicle is already mining", "basic"] spawn AP_fnc_handleMessage;};
closeDialog 0;
AP_action_in_use = true;
if (((_vehicle getVariable["AP_vinv", [[], 0]]) select 1) >= (_vehicle getVariable["AP_vcap", 100])) exitWith {
    ["The vehicle is full", "basic"] spawn AP_fnc_handleMessage;
    AP_action_in_use = false;};
private _zone = "";
private _resourceZones = ["apple_1", "apple_2", "apple_4", "apple_5", "peaches_2", "peaches_3", "peaches_4", "illegal_marker_2_0", "illegal_marker_3_0", "illegal_marker_8_0", "rock_1", "rock_2", "rock_3", "oil_1", "oil_2", "oil_3", "salt_1", "tobacco_1", "fentanyl_1", "vineyard_1"];
private _dbInfo = _vehicle getVariable["AP_dbInfo", []];
// markerType test: a field the map has not placed has no marker and reads as [0,0,0], which put every
// unplaced field inside the device's 290 m reach at the map's SW corner. See fn_gather.
private _zone = _resourceZones param[_resourceZones findIf {markerType _x isNotEqualTo "" && {player distance(getMarkerPos _x) < 290}}, ""];
if (_zone isEqualTo "") exitWith {["You are not near a resource field.", "basic"] spawn AP_fnc_handleMessage;
    AP_action_in_use = false;};
private _gatherArray =
switch (true) do {    case (_zone isEqualTo "illegal_marker_2_0"): {["smashpowder", 150];};
    case (_zone isEqualTo "illegal_marker_3_0"): {["sparkdust", 150];};
    case (_zone isEqualTo "tobacco_1"): {["tobaccou", 150];};
    case (_zone isEqualTo "fentanyl_1"): {["boost", 150];};
    case (_zone isEqualTo "vineyard_1"): {["grapes", 100];};
    case (_zone find "rock" != -1): {["redshift", 150];};
    case (_zone find "oil" != -1): {["toxicslurry", 150];};
    case (_zone find "salt" != -1): {["salt", 150];};
    case (_zone find "apple" != -1): {["apple", 50];};
    case (_zone find "peaches" != -1): {["peach", 50];};
    default {""};}; _gatherArray params["_item", "_distance"];
// owner 2026-06-16 (#264): the zone is matched within 290m (line ~23) but each resource has a tighter
// _distance (50/150m). Standing between _distance and 290m fell into this exit -- which DIDN'T reset
// AP_action_in_use (still TRUE from line 14), unlike every other early-exit above. A stuck action-lock =
// "started gathering just outside the zone, now I can't interact with anything." Release the lock + tell them.
if (player distance(getMarkerPos _zone) > _distance) exitWith {AP_action_in_use = false;
    ["You're too far from the resource field -- move closer to gather.", "basic"] spawn AP_fnc_handleMessage;};
AP_action_in_use = false;
if (isEngineOn _vehicle) exitWith {titleText["The vehicle must be turned off before mining.", "PLAIN"];};
if !(objNull isEqualTo(_vehicle getVariable["AP_mining", objNull])) exitWith {
    ["This vehicle is already mining", "basic"] spawn AP_fnc_handleMessage;};
if (AP_gatheringDevice) exitWith {["You can only operate one gathering device at a time.", "basic"] spawn AP_fnc_handleMessage;};
AP_gatheringDevice = true;
uiSleep(random 1);
_vehicle setVariable["AP_mining", player, true];
private _toSend = (allPlayers - [allDeadMen]) select {(_x distance player) <= 2000}; [
    [_vehicle], "AP_fnc_soundDevice", _toSend, false, false] spawn AP_fnc_MP;
private _time = 0;
private _maxWeight = _vehicle getVariable["AP_vcap", 100];
private _sum = 0;
private _index = 0;
private _itemWeight = 0;
private _totalGathered = 0;
private _timeDelay = 33.2;
private _amountPerCycle = 12;
for "_i"
from 0 to 1 step 0 do {if (!alive _vehicle || isNull _vehicle) exitWith {};
    if (player distance _vehicle > 10) exitWith {["You must stay near the vehicle.", "basic"] spawn AP_fnc_handleMessage;};
    if (isEngineOn _vehicle) exitWith {titleText["You cannot turn the vehicle on when mining", "PLAIN"];};
    if !(player isEqualTo(_vehicle getVariable["AP_mining", objNull])) exitWith {
        ["You can only have one device running at a time", "basic"] spawn AP_fnc_handleMessage;};
    titleText["The Device is gathering...", "PLAIN"];
    _time = time + _timeDelay;
    waitUntil {if (isEngineOn _vehicle) exitWith {titleText["You cannot turn the vehicle on when mining", "PLAIN"];
            true};
        if (player distance _vehicle > 10) exitWith {true};
        if (round(_time - time) < 1) exitWith {true};
        uiSleep 0.2;
        false};
    if (isEngineOn _vehicle) exitWith {titleText["You cannot turn the vehicle on when mining", "PLAIN"];};
    if (player distance _vehicle > 10) exitWith {["You must stay near the vehicle.", "basic"] spawn AP_fnc_handleMessage;};
    private _vehInv = _vehicle getVariable["AP_vinv", [[], 0]];
    _vehInv params["_items", "_weight"];
    _sum = [_item, _amountPerCycle, _weight, _maxWeight] call AP_fnc_calWeightDiff;
    if (_sum < 1) exitWith {titleText["The vehicle is full", "PLAIN"];};
    _itemWeight = ((["getItemWeight", _item] call AP_fnc_virtItemCfg) * _sum);
    _index = _items findIf {(_x select 0) isEqualTo _item};
    if (_index isEqualTo - 1) then {_items pushBack[_item, _sum];} else {private _oldVal = (_items select _index) select 1;
        (_items select _index) set[1, _oldVal + _sum];};
    if (fuel _vehicle isEqualTo 0) exitWith {titleText["The vehicle is out of fuel.", "PLAIN"];};
    if (local _vehicle) then {_vehicle setFuel((fuel _vehicle) - 0.02);} else {[
            [_vehicle, (fuel _vehicle) - 0.02], "AP_fnc_setFuel", _vehicle, false] spawn AP_fnc_MP;};
    if (fuel _vehicle isEqualTo 0) exitWith {titleText["Vehicle is out of fuel", "PLAIN"];};
    if !(player isEqualTo(_vehicle getVariable["AP_mining", objNull])) exitWith {
        ["You can only have one device running at a time", "basic"] spawn AP_fnc_handleMessage;};
    titleText[format["Completed cycle, the device has mined %1 %2", _sum, ["getName", _item] call AP_fnc_virtItemCfg], "PLAIN"];
    [_item, _sum] call AP_fnc_statArrUpdate;
    _totalGathered = _totalGathered + _sum;
    _vehicle setVariable["AP_vinv", [_items, _weight + _itemWeight], true];
    _sum = [_item, _amountPerCycle, _weight + _itemWeight, _maxWeight] call AP_fnc_calWeightDiff;
    if (_sum < 1) exitWith {titleText["The vehicle is full", "PLAIN DOWN"];};
    uiSleep 2;}; AP_gatheringDevice = false;
if ((_totalGathered isNotEqualTo 0) && (_dbInfo isNotEqualTo[])) then {_dbInfo params["_ownerPID", "_plate"];
    _keychainUIDs = (_vehicle getVariable["AP_vehOwners", []]); [
        ["-GATHERDEVICE-", player, profileName, format["gathered %1 %2 with a tempest device at position %3. Plate: %4. OwnerUID: %5. Keychain: %6", _totalGathered, ["getName", _item] call AP_fnc_virtItemCfg, getPosATL player, _plate, _ownerPID, _keychainUIDs]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
};
if !(player isEqualTo(_vehicle getVariable["AP_mining", objNull])) exitWith {};
_vehicle setVariable["AP_mining", objNull, true];