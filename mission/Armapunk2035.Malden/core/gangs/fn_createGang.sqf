#include "..\..\macro.h"
disableSerialization;
if !(AP_gang_data isEqualTo[]) exitWith {closeDialog 0;
    ["You must leave or disband your current gang before creating a new one!", "basic"] spawn AP_fnc_handleMessage};
if (AP_passiveModeJIP) exitWith {
    ["You cannot create a gang while in passive mode! You can disable it on your phone (Y).", "basic"] spawn AP_fnc_handleMessage;};
if (AP_atmcash < 25000) exitWith {["You don't have enough money in your bank account to create a gang.", "basic"]};
if !(([AP_my_gang, randomized_life_group_list] call AP_fnc_index) isEqualTo - 1) then {
    systemChat "You were removed from your group during the gang setup process.";
    [] call AP_fnc_leaveGroup;};
private _gangName = ctrlText(getControl(9520, 9522));
if ("call " in (toLower _gangName) || "spawn " in (toLower _gangName) || "execVM" in (toLower _gangName) || _gangName isEqualTo "") exitWith {
    ["Invalid gang name.", "basic"] spawn AP_fnc_handleMessage};
private _length = count(toArray _gangName);
if (_length < 3) exitWith {["The minimum character limit for a gang name is 3.", "basic"] spawn AP_fnc_handleMessage;};
if (_length > 25) exitWith {["The maximum character limit for a gang name is 25.", "basic"] spawn AP_fnc_handleMessage;};
if !([_gangName] call AP_fnc_isAlphanumeric) exitWith {
    ["Your gang name contains unsupported characters!", "basic"] spawn AP_fnc_handleMessage;}; [
    [player, _gangName], "APS_fnc_insertGang", 2] spawn AP_fnc_MP;
["Sending info to the server and creating the gang...", "basic"] spawn AP_fnc_handleMessage;