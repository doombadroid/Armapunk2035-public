#include "..\..\macro.h"
/*
    Re-plumbed 2026-08-12 for the web deck. Item and amount used to come only from
    dialog 361000's controls, so only that dialog could drop anything.

        [] spawn AP_fnc_dropItem;                  // native, unchanged
        ["apple", 3] spawn AP_fnc_dropItem;        // deck

    Every guard below is untouched: the spam limiter, the processing/underwater/
    in-vehicle rules and the 3-second transfer cooldown.
*/
params [["_itemIn", "", [""]], ["_qtyIn", -1, [0]]];
if (scriptAvailable(2)) exitWith {["Please don't spam item drops!", "basic"] spawn AP_fnc_handleMessage;};
if ((AP_is_processing) && (AP_action_in_use)) exitWith {
    ["You cannot drop items while processing!", "basic"] spawn AP_fnc_handleMessage;
    true};
if (((getPosASL player) select 2) < 0) exitWith {["You cannot drop items while under water!", "basic"] spawn AP_fnc_handleMessage;
    true};
if (((time - AP_last_transfer) < 3)) exitWith {
    ["You can only drop items once per 3 seconds. Try dropping more at a time.", "basic"] spawn AP_fnc_handleMessage;
    true};
if (!(isNull objectParent player) && !(objectParent player isKindOf "Ship")) exitWith {
    ["You cannot drop items from inside a vehicle!", "basic"] spawn AP_fnc_handleMessage;
    true};
if (player getVariable["AP_restrained", false]) exitWith {
    ["You cannot drop items while restrained!", "basic"] spawn AP_fnc_handleMessage;
    true};
if (isOnRoad player && ((AP_is_arrested select 0) isEqualTo 0)) exitWith {
    ["Littering on the road is not acceptable!", "basic"] spawn AP_fnc_handleMessage;
    true};
private _nearbyCases = {!((_x getVariable["AP_droppedItems", []]) isEqualTo[]) && (isNull(_x getVariable["AP_inUse", objNull]))}
count(nearestObjects[player, [], 4]);
if (_nearbyCases >= 3) exitWith {
    ["Please make a suitcase pile elsewhere or wait for a nearby case to not be in use by other people.", "basic"] spawn AP_fnc_handleMessage;
    true};
private _shortName = if (_itemIn isNotEqualTo "") then { _itemIn } else { lbData[361001, lbCurSel 361001] };
private _playerTypedDropAmount = if (_qtyIn >= 0) then { _qtyIn } else { parseNumber(ctrlText 361002) };
private _itemMax = missionNamespace getVariable(format["AP_inv_%1", _shortName]);
if (isNil "_itemMax") exitWith {["You can't drop this item!", "basic"] spawn AP_fnc_handleMessage;};
if (_shortName isEqualTo "") exitWith {["You need to select an item to drop.", "basic"] spawn AP_fnc_handleMessage;};
// gift boxes + newdrachma: APS_fnc_createItem refuses them from any client (2026-09-26), so refuse here, before the decrement
if (_shortName in ["humanscalp", "giftAdmin", "giftHallo", "giftXmas", "newdrachma"]) exitWith {["You cannot drop this item.", "basic"] spawn AP_fnc_handleMessage;};
IF!([str _playerTypedDropAmount] call AP_fnc_isNumber) exitWith {["You must enter a round number.", "basic"] spawn AP_fnc_handleMessage
};
if (_playerTypedDropAmount <= 0) exitWith {};
if (_playerTypedDropAmount > _itemMax) then {
    [format["You attempted to drop %1, but you only had %2 so that has been dropped instead", _playerTypedDropAmount, _itemMax], "basic"] spawn AP_fnc_handleMessage;
    _playerTypedDropAmount = _itemMax;};
private _action = true;
if ((AP_is_arrested select 0) isEqualTo 1) then {
    _action = ["Dropping this item while in jail will delete it. Are you sure?", "Delete Item", "Yes", "No"] call BIS_fnc_guiMessage;};
if !(_action) exitWith {}; [
    ["-ITEMDROPPED-", player, profileName, format["dropped %1 %2, Position: %3.", _playerTypedDropAmount, ["getName", _shortName] call AP_fnc_virtItemCfg, getPosATL player]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
missionNamespace setVariable[format["AP_inv_%1", _shortName], _itemMax - _playerTypedDropAmount];
[false] call AP_fnc_saveGear;
[3] call AP_fnc_ClupdatePartial;
if ((AP_is_arrested select 0) isEqualTo 0) then {private _pos =
    if (objectParent player isKindOf "Ship") then {(objectParent player) modelToWorld[0, -8, -1]} else {getPosASL player}; [[[
                [_shortName, _playerTypedDropAmount]], _pos, "Land_Suitcase_F"], "APS_fnc_createItem", 2] spawn AP_fnc_MP;};

[] call AP_fnc_calWeight;
// The native phone shell went in ce1f5e23 and took fn_p_updateMenu with it; this call
// survived and threw on every drop. Nothing replaces it -- 361000 is not a dialog any
// file declares, so findDisplay returned null and the function exited on its second line.