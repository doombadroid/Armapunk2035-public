#include "..\..\..\macro.h"
if (scriptAvailable(5)) exitWith {["You spam this action...", "basic"] spawn AP_fnc_handleMessage;};
params[["_type", "", [""]], ["_controlData", [], [[]]]];
private _plb_display = findDisplay 39400;
if (isNull _plb_display) exitWith {};
private _filterList = _plb_display displayCtrl 39402;
private _mainListGroup = _plb_display displayCtrl 39404;
private _mainItemList = _mainListGroup controlsGroupCtrl 1000;
private _mainItemListBackground = _mainListGroup controlsGroupCtrl 1003;
private _sideListGroup = _plb_display displayCtrl 39405;
private _sideItemList = _sideListGroup controlsGroupCtrl 1000;
private _sideItemListButton = _sideListGroup controlsGroupCtrl 1001;
private _deleteButton = _sideListGroup controlsGroupCtrl 1005;
private _saveButton = _sideListGroup controlsGroupCtrl 1004; {_x ctrlEnable false;}
forEach[_deleteButton, _saveButton, _sideItemListButton];
private _indexValZero = (_sideItemList lnbValue[lbCurSel _sideItemList, 0]);
private _indexValOne = (_sideItemList lnbValue[lbCurSel _sideItemList, 1]);
private _message =
if (_indexValZero isEqualTo - 4) then {"Are you sure you want to save your current loadout to an empty slot?"} else {
    "Are you sure you want to update the selected loadout with your current loadout?"};
private _action = [_message, "Loadout Save Confirmation", "Continue", "Cancel"] call BIS_fnc_guiMessage;
if !(_action) exitWith {};
["<t align='center'>Enter desired loadout name.</t>", "Loadout Name", "Submit"] call AP_fnc_inputMenu;
if (AP_input_response isEqualTo "") exitWith {["You failed to enter a name.", ""] spawn AP_fnc_handleMessage;};
private _loadoutName = AP_input_response;
AP_input_response = "";
if (((_loadoutName find "call ") != -1) || ((_loadoutName find "spawn ") != -1) || ((_loadoutName find "execVM") != -1) || ((_loadoutName find "_fnc_") != -1)) exitWith {
    ["Invalid loadout name. Please try again.", "basic"] spawn AP_fnc_handleMessage};
private _length = count(toArray _loadoutName);
private _chrByte = toArray _loadoutName;
private _allowed = toArray("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_ ");
if (_length < 3) exitWith {["The minimum character limit for a loadout name is 3.", "basic"] spawn AP_fnc_handleMessage;};
if (_length > 20) exitWith {["The maximum character limit for a loadout name is 20.", "basic"] spawn AP_fnc_handleMessage;};
private _badChar = false; {if (!(_x in _allowed)) exitWith {_badChar = true;};}
forEach _chrByte;
if (_badChar) exitWith {["Your loadout name contains unsupported characters!", "basic"] spawn AP_fnc_handleMessage;};
private _loadout = getUnitLoadout player;
private _virtualInv = [_type] call AP_fnc_getVirtualInv;
private _loadoutPrice = [_type, _loadout, _virtualInv, true] call AP_fnc_getLoadoutPrice;
private _skins = [AP_uniformBackpack_skins select 0, AP_uniformBackpack_skins select 1]; {if (isNil "_x") then {
        _skins set[_forEachIndex, -1];};}
forEach _skins;
if (_loadoutPrice isEqualTo - 1) exitWith {};
if (AP_carryWeight > 90) exitWith {["The maximum virtual weight for a loadout is 90.", "basic"] spawn AP_fnc_handleMessage;};
if (_indexValZero isEqualTo - 4 && {(AP_loadoutHolder findIf {(_x isNotEqualTo []) && {(_x select 1) isEqualTo _type} && {(_x select 2) isEqualTo _loadoutName}}) != -1}) exitWith {
    [format["You already have a loadout named '%1'. Choose a different name, or update the existing one.", _loadoutName], "basic"] spawn AP_fnc_handleMessage;
    closeDialog 0;
    waitUntil { !dialog };
    [nil, nil, nil, _type] spawn AP_fnc_loadoutMenu;};
if (_indexValZero isEqualTo - 4) then {private _uniqueID = round(serverTime); [
        [2, getPlayerUID player, _uniqueID, AP_effSide, _type, _loadoutName, _loadout, _virtualInv, _skins], "APS_fnc_handleLoadouts", 2] call AP_fnc_MP;
    AP_loadoutHolder set[_indexValOne, [_uniqueID, _type, _loadoutName, _loadout, _virtualInv, _skins]];
    [format["You have successfully added the %1 loadout!", _loadoutName], "basic"] spawn AP_fnc_handleMessage;};
if (_indexValZero isEqualTo - 3 || (_indexValZero >= 0 && _indexValZero <= 7)) then {
    private _uniqueID = ((AP_loadoutHolder select _indexValZero) select 0); [
        [3, getPlayerUID player, _uniqueID, AP_effSide, _type, _loadoutName, _loadout, _virtualInv, _skins], "APS_fnc_handleLoadouts", 2] call AP_fnc_MP;
    AP_loadoutHolder set[_indexValZero, [_uniqueID, _type, _loadoutName, _loadout, _virtualInv, _skins]];
    [format["You have successfully created the %1 loadout!", _loadoutName], "basic"] spawn AP_fnc_handleMessage;}; [
    ["-LOADOUTSAVE-", player, (profileName), format["attempted to save loadout %1 at POS: %2 - %3 - %4", _loadoutName, getPosATL player, _loadout, _virtualInv]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
closeDialog 0;
waitUntil {!dialog};
[nil, nil, nil, _type] spawn AP_fnc_loadoutMenu;