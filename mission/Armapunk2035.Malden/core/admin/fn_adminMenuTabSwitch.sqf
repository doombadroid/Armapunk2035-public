#include "..\..\macro.h"
/*
    File: fn_adminMenuTabSwitch.sqf
    Author: LoonyBin

    Description:
    Tab switcher for the LoonyBin staff/admin menu (dialog idd 12900). Shows the
    requested panel (AP_RscControlsGroup) and hides the others, colours the active
    tab, and hides the player list on the Vehicles tab (its slot is reused by the
    vehicle list panel).

    Tabs:   13001 Actions | 13003 Event Tools | 13004 Weapons & Gear | 13005 Vehicles
    Panels: 13100 Actions | 13102 Event Tools | 13103 Weapons & Gear | 13104 Vehicles
*/
params [["_activeTabID", 13001]];
disableSerialization;
private _display = findDisplay 12900;
if (isNull _display) exitWith {};

private _tabIDs   = [13001, 13003, 13004, 13005, 13006];
private _panelIDs = [13100, 13102, 13103, 13104, 13105];
private _inactiveColor = [0.118, 0.153, 0.208, 1];
private _activeColor   = [0.216, 0.910, 0.941, 1];
private _inactiveText  = [0.922, 0.937, 0.957, 1];
private _activeText    = [0.043, 0.075, 0.102, 1];
private _playerList = _display displayCtrl 12901;
 {private _tab   = _display displayCtrl _x;
    private _panel = _display displayCtrl (_panelIDs select _forEachIndex);
    if (_x isEqualTo _activeTabID) then {_tab ctrlSetBackgroundColor _activeColor;
        _tab ctrlSetTextColor _activeText;
        _panel ctrlShow true;
        // the Vehicles panel reuses the player-list slot, so hide the list there
        _playerList ctrlShow (!(_x isEqualTo 13005));} else {_tab ctrlSetBackgroundColor _inactiveColor;
        _tab ctrlSetTextColor _inactiveText;
        _panel ctrlShow false;};} forEach _tabIDs;
// lazy-build the spawner catalogues when their tabs open
if (_activeTabID isEqualTo 13004) then { ["init"] call AP_fnc_adminWeaponMenu; };
if (_activeTabID isEqualTo 13006) then { ["init"] call AP_fnc_adminClothingMenu; };
