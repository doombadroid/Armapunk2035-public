#include "..\..\macro.h"
/*
    Re-plumbed 2026-08-12 for the web deck: the name used to come only from the
    group dialog's edit box 2531.

        [] call AP_fnc_createGroup;                       // native, unchanged
        ["Wreckers", "hunter2"] call AP_fnc_createGroup;   // deck

    A PASSWORD IS MANDATORY AT CREATION and comes from a DIFFERENT control to the
    one fn_setGroupPass uses later (2532 here, 2551 there), so both have to be
    parameters or the deck can name a squad it cannot create.

    Every guard below is untouched -- passive mode, the 30s anti-flood cooldown,
    the length and character rules.
*/
params [["_nameIn", "", [""]], ["_passIn", "", [""]]];
private _groupName = if (_nameIn isNotEqualTo "") then { _nameIn } else { ctrlText 2531 };
private _length = count(toArray _groupName);
if !(AP_effSide isEqualTo civilian) exitWith {["Only civilians can use squads.", "basic"] spawn AP_fnc_handleMessage;};
if (AP_passiveModeJIP) exitWith {
    ["You cannot create a group while in passive mode! You can disable it on your phone (Y).", "basic"] spawn AP_fnc_handleMessage;};
// LooneyBin: parity with lock/unlock/setPass -- no cooldown meant a group-entry flood was one
// macro'd click away (every create publicVariables the whole list to everyone)
if (scriptAvailable(30)) exitWith {["Please wait a bit before creating another group!", "basic"] spawn AP_fnc_handleMessage;};
if (_groupName isEqualTo "") exitWith {["You must choose a name.", "basic"] spawn AP_fnc_handleMessage;};
if (_length < 3) exitWith {["The minimum character limit for a group name is 3.", "basic"] spawn AP_fnc_handleMessage;};
if (_length > 25) exitWith {["The maximum character limit for a group name is 25.", "basic"] spawn AP_fnc_handleMessage;};
if !([_groupName] call AP_fnc_isAlphanumeric) exitWith {
    ["Invalid character in name, characters allowed are A-z,0-9, and _", "basic"] spawn AP_fnc_handleMessage;};
private _groupPassword = if (_passIn isNotEqualTo "") then { _passIn } else { ctrlText 2532 };
if (_groupPassword isEqualTo "") exitWith {["You must choose a password for the group.", "basic"] spawn AP_fnc_handleMessage};
// LooneyBin: this check reused _length (the group NAME length) -- any 17-25 char group name was
// rejected with a bogus "password is too long" error. Measure the password itself.
if ((count (toArray _groupPassword)) > 16) exitWith {
    ["The maximum character limit for a password is 16.", "basic"] spawn AP_fnc_handleMessage;};
if !([_groupPassword] call AP_fnc_isAlphanumeric) exitWith {
    ["Invalid character in password, characters allowed are A-z,0-9, and _", "basic"] spawn AP_fnc_handleMessage;};
if (isNil {randomized_life_group_list}) exitWith {
    ["Server failed to initiate groups and gangs list.", "basic"] spawn AP_fnc_handleMessage;};
if !(randomized_life_group_list findIf {_groupName in _x}
isEqualTo - 1) exitWith {["That group name is already taken!", "basic"] spawn AP_fnc_handleMessage;};
private _group = createGroup [civilian, true];
private _left = _groupName select[0, 1];
private _mid = _groupName select[floor((count _groupName) / 2), 1];
private _right = _groupName select[((count _groupName) - 1), 1];
private _grpTag = format["%1%2%3", _left, _mid, _right];
private _countGroupTags = {(((_x select 1) getVariable["AP_grpTag", ""]) find _grpTag) >= 0}
count randomized_life_group_list;
private _grpTag =
if (_countGroupTags >= 1) then {format["[%1 (%2)] ", _grpTag, (_countGroupTags + 1)]} else {format["[%1] ", _grpTag]};
_group setVariable["AP_grpTag", _grpTag, true];
_group setGroupIdGlobal [_groupName];   // owner 2026-06-25 (Northhhhh): clean callsign (squad name) so side-chat shows the squad name, not the engine's auto group ID 
// goodchance this runs into issues down the road also doesnt address gang groups will just setup side chat correctly
randomized_life_group_list pushBack[_groupName, _group, true, getPlayerUID player, _groupPassword];
publicVariable "randomized_life_group_list";
[player] joinSilent _group;
player setRank "COLONEL";
AP_my_gang = _group;
// The native path reopens its own menu on success. A direct caller has its own
// screen already open, so popping this one would replace the UI the player is
// standing in front of -- which is exactly what happened from the web deck.
if !(isNull AP_my_gang) then {
    if (_nameIn isEqualTo "") then { ["groupMenuMain"] spawn AP_fnc_createDialog; };
    publicVariable "randomized_life_group_list";
};