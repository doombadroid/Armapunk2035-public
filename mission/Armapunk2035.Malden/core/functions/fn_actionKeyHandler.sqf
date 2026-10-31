#include "..\..\macro.h"
if (scriptAvailable(0.5)) exitWith {};
private "_handle";
private _curTarget = cursorObject;
if (AP_action_in_use) exitWith {};
if (AP_interrupted) exitWith {AP_interrupted = false;};
if (player distance _curTarget > 20) exitWith {};
private _isWater = surfaceIsWater(getPosASL player);
if (isNull _curTarget) exitWith {if (_isWater) then {private _fish = (nearestObjects[player, ["Fish_Base_F"], 3]) select 0;
        if (!isNil "_fish") then {[_fish] call AP_fnc_catchFish;};} else {
        if (AP_effSide isEqualTo civilian && !AP_action_gathering) then {if (surfaceIsWater position player) then {
                _handle = [] spawn AP_fnc_gatherWater;} else {_handle = [] spawn AP_fnc_gather;};
            waitUntil {scriptDone _handle};
            AP_action_gathering = false;};};};
if (_curTarget isKindOf "House_F" && {player distance _curTarget < 20}) exitWith {[_curTarget] call AP_fnc_houseMenu;};
if (dialog) exitWith {};
if (vehicle player != player) exitWith {};
// LooneyBin: do the revive BEFORE taking the 60s action lock. revivePlayer's own guard exits on
// AP_action_in_use, so setting the lock first made every windows-key revive silently fail -- the medic
// then re-pressed and hit revivePlayer's 3s "Wait a bit before attempting to revive again" throttle.
if (AP_inv_defib > 0 && _curTarget isKindOf "CAManBase" && !(alive _curTarget) && _curTarget getVariable["AP_revivable", false] && (98 in AP_side_talents || !(AP_effSide isEqualTo west))) exitWith {
    [_curTarget] call AP_fnc_revivePlayer;};
AP_action_in_use = true;
[] spawn {uiSleep 60;
    AP_action_in_use = false;};
if (isPlayer _curTarget && _curTarget isKindOf "CAManBase" && player distance _curTarget < 6) then {
    if ((_curTarget getVariable["AP_restrained", false]) && !dialog && AP_effSide isEqualTo west) then {
        [_curTarget] call AP_fnc_copInteractionMenu;};} else {private _isVehicle =
    if ((_curTarget isKindOf "landVehicle") || (_curTarget isKindOf "Ship") || (_curTarget isKindOf "Air")) then {true} else {false};
    private _miscItems = ["Land_BottlePlastic_V1_F", "Land_TacticalBacon_F", "Land_Can_V3_F", "Land_CanisterFuel_F", "Land_Suitcase_F"];
    private _animalTypes = ["Salema_F", "Ornate_random_F", "Mackerel_F", "Tuna_F", "Mullet_F", "CatShark_F", "Turtle_F"];
    if (_isVehicle) then {if (!dialog) then {if (player distance _curTarget < ((boundingBox _curTarget select 1) select 0) + 2) then {
                [_curTarget] call AP_fnc_vInteractionMenu;};};} else {if ((typeOf _curTarget) in _animalTypes) then {
            if ((typeOf _curTarget) == "Turtle_F" && !alive _curTarget && ({player distance getMarkerPos format["turtle_%1", _x] < 310}
            count[1, 2, 3] > 0)) then {_handle = [_curTarget] spawn AP_fnc_catchTurtle;
                waitUntil {scriptDone _handle};} else {_handle = [_curTarget] spawn AP_fnc_catchFish;
                waitUntil {scriptDone _handle};};} else {if ((typeOf _curTarget) in _miscItems) then {
                _handle = [_curTarget] spawn AP_fnc_menuPickupItems;
                waitUntil {scriptDone _handle};};};};};