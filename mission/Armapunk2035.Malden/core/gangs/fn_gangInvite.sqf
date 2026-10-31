#include "..\..\macro.h"
params[["_inviter", objNull, [objNull]], ["_name", "", [""]], ["_gangData", [], [[]]], ["_gangTalentsXP", [], [[]]], "_gangHouse"];
if (_name isEqualTo "" || _gangData isEqualTo[]) exitWith {};
if !(AP_gang_data isEqualTo[]) exitWith {};
if !(AP_effSide isEqualTo civilian) exitWith {};
if (AP_gangInvitesIgnored) exitWith {};
private _gangID = _gangData select 0;
private _gangName = _gangData select 1;
private _action = [format["%1 has invited you to a gang called %2<br/>If you accept the invitation you will be a part of their gang and will have access to the gang house where you can spawn and utilize other features.", _name, _gangName], "Gang Invitation", "Accept", "Decline"] call BIS_fnc_guiMessage;
if (_action) then {if (AP_passiveModeJIP) exitWith {
        ["You cannot join a gang while in passive mode! You can disable it on your phone (Y).", "basic"] spawn AP_fnc_handleMessage;}; [
        [player, 0, _gangID, _gangName, _inviter, 5, _name], "APS_fnc_updateGangMem", 2] spawn AP_fnc_MP;
    AP_gang_data = [_gangID, _gangName, 5, _gangData param[3, [0, 0, 0]]];
    AP_gang_talents = _gangTalentsXP select 0;
    AP_gang_exp = _gangTalentsXP select 1;
    AP_gangBuilding = _gangHouse;
    if !(_gangHouse isEqualTo[objNull, []]) then {
        private _marker = createMarkerLocal[format["phouse_%1%2", _gangID, (_gangHouse select 0) getVariable["AP_homeOwner", ""]], getPosATL(_gangHouse select 0)];
        _marker setMarkerTextLocal "Gang Building";
        _marker setMarkerColorLocal "ColorGreen";
        _marker setMarkerTypeLocal "mil_end";
        AP_gangBldgMark = _marker;};
    player setVariable["gang_data", AP_gang_data, true];
    if (([AP_my_gang, randomized_life_group_list] call AP_fnc_index) isEqualTo - 1) then {
        private _newGroup = allGroups param[allGroups findIf {_x getVariable["gang_id", -5] isEqualTo(AP_gang_data select 0)}, grpNull];
        if !(isNull _newGroup) then {[player] join _newGroup;} else {
            // owner 2026-06-14: move to a FRESH solo group before tagging (like fn_initGang). Tagging the
            // CURRENT group polluted the SHARED default civ slot-group with gang_id, which leaked tac pings
            // (and group HUD) to every ungrouped player in it.
            [player] join grpNull;
            uiSleep 0.35;
            _newGroup = group player;
            _newGroup setVariable["gang_id", AP_gang_data select 0, true];
            _newGroup setVariable["gang_name", AP_gang_data select 1, true]; [
                [AP_gang_data select 0, "", _newGroup], "APS_fnc_setGangTagSRV", 2] spawn AP_fnc_MP;};
        [] spawn {uiSleep 0.5;
            private _units = (units group player) apply {getPlayerUID _x}; [
                ["-GANGGRP-", player, profileName, format["joined the gang group: %1(%3). Members: %2", AP_gang_data select 1, _units, AP_gang_data select 0]], "APS_fnc_logIt", 2] call AP_fnc_MP;
        };} else {
        ["You were not placed into your gangs default group because you are currently in a group. To join the gang group leave your current group.", "basic"] spawn AP_fnc_handleMessage;
    };} else {["Gang invite declined.", "basic"] spawn AP_fnc_handleMessage;};