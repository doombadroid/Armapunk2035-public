#include "..\macro.h"
// CTRL+SHIFT+I (evh/fn_keyDownHandler.sqf) sets this and re-fires the Gear action: the native display
// 602 opens once, then the web I-screen is the default again. Consumed here so it can never stick.
if (missionNamespace getVariable ["AP_invForceNative", false]) exitWith {AP_invForceNative = false; false;};
if (AP_isActiveFirefighter) exitWith {["You can't open your inventory while actively being a firefighter"] spawn AP_fnc_handleMessage;
    true;};
if (((call AP_adminLevel) >= 3) && {AP_adminMode}) exitWith {false;};
params[["_unit", objNull, [objNull]], ["_container", objNull, [objNull]]];
// no container in view = your own gear + the ground pile: the web I-screen (INVENTORY_SPEC.md §9.2).
// true = the engine does not open display 602; fn_invOpen puts dialog 938500 up in its place.
if (isNull _container) exitWith {[objNull] spawn AP_fnc_invOpen; true;};
if (_container isKindOf "Bag_Base" && cursorTarget getVariable["AP_surrendered", false]) exitWith {false;};
if (_container isKindOf "Bag_Base" && !(cursorTarget getVariable["AP_surrendered", false]) && AP_effSide != west) exitWith {
    ["No stealing allowed!", "basic"] spawn AP_fnc_handleMessage;
    true;};
if (_container isKindOf "CAManBase") exitWith {true;};
if (_container getVariable["AP_seizing", false]) exitWith {["This vehicle is being seized."] spawn AP_fnc_handleMessage;
    true};
if (scriptAvailable(2)) exitWith {["Wait a bit before attempting to open the inventory again."] spawn AP_fnc_handleMessage;
    true};
if (AP_action_in_use) exitWith {["You're currently doing a different action..", "basic"] spawn AP_fnc_handleMessage;
    true};
if (AP_inEvent) exitWith {true;};
private _nearestCrate = nearestObject[player, "B_CargoNet_01_ammo_F"];
if (!isNull _nearestCrate && {
    _nearestCrate getVariable["AP_rebelAirDrop", false] && (player distance _nearestCrate) < 6 && AP_airDrop_last > serverTime - 600
}) exitWith {
    [format["The crate is still locked for another %1 minutes. Check back frequently!", ceil(((AP_airDrop_last + 600) - serverTime) / 60)], "basic"] spawn AP_fnc_handleMessage;
    true;};
private _nearestCrate = nearestObject[player, "Box_FIA_Ammo_F"];
if (!(isNull _nearestCrate) && (_nearestCrate getVariable["AP_ufoLoot", false]) && ((SRV_ufoCrash select 2) > serverTime - 600)) exitWith {
    [format["This radiated loot is unstable right now. Try in another %1 minutes. Check back frequently!", ceil((((SRV_ufoCrash select 2) + 600) - serverTime) / 60)], "basic"] spawn AP_fnc_handleMessage;
    true;};
private _nearestCrate = nearestObject[player, "I_E_CargoNet_01_ammo_F"];
if (!isNull _nearestCrate && {
    _nearestCrate getVariable["AP_santaLoot", false] && (player distance _nearestCrate) < 6 && (SRV_winterEvent select 1) > serverTime - 600
}) exitWith {
    [format["The crate is still locked for another %1 minutes. Check back frequently!", ceil((((SRV_winterEvent select 1) + 600) - serverTime) / 60)], "basic"] spawn AP_fnc_handleMessage;
    true;};
private _nearestCrate = nearestObject[player, "VirtualReammoBox_F"];
if (!(isNull _nearestCrate) && (SRV_loonyBinData param[4, false]) && (AP_serverId isEqualTo 1)) exitWith {
    ["This crate is locked until someone enters the right combination for the keypad!", "basic"] spawn AP_fnc_handleMessage;
    true;};
private _isVehicle = (_container isKindOf "LandVehicle" || _container isKindOf "Ship" || _container isKindOf "Air");
if (_isVehicle && !(_container in AP_vehicles) && !(AP_effSide isEqualTo west) && {(locked _container) isEqualTo 2
} && ((call AP_adminLevel) <= 3)) exitWith {
    ["You cannot access the inventory of locked vehicles. Try using lockpicks or getting the keys.", "basic"] spawn AP_fnc_handleMessage;
    AP_action_in_use = false;
    true};
private _usedBy = _container getVariable["AP_veh_in_use", objNull];
private _inUse = _usedBy isNotEqualTo objNull;
if (_inUse && !(_usedBy isEqualTo player)) exitWith {
    ["This inventory is already being used by someone.", "basic"] spawn AP_fnc_handleMessage;
    AP_action_in_use = false;
    true};
_container setVariable["AP_veh_in_use", player, true];
// The guard chain above is the whole access decision; the web I-screen replaces display 602 from here.
// AP_veh_in_use is released by fn_invBridge.sqf's Unload handler (the one releaser) and its watchdog
// closes the screen on serverRestartLock / AP_trunkLock, which is what the old 602 waiter did.
[_container] spawn AP_fnc_invOpen;
[] spawn {uiSleep 1;
    (findDisplay 49) closeDisplay 2;};
true;
